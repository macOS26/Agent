import AgentLLM
import AgentAudit
@preconcurrency import Foundation
import AgentTools
import AppKit

// MARK: - Codex OAuth Service
//
// Uses ChatGPT-subscription OAuth tokens (from `codex login` → ~/.codex/auth.json)
// to talk to https://chatgpt.com/backend-api/codex/responses — the same endpoint
// the official OpenAI Codex CLI uses. This is the Responses API shape, NOT
// /v1/chat/completions. See docs/CODEX_OAUTH_RESEARCH.md for the full comparison
// against Agent!'s Claude OAuth path.
//
// Phase 1 (this file): auth plumbing + non-streaming text + tool_use end-to-end.
// Streaming is implemented by awaiting the full response and delivering it as
// one delta — real SSE parsing for `response.output_text.delta` events is a TODO.

// MARK: Auth file on disk

struct CodexAuthFile {
    var accessToken: String
    var idToken: String?
    var refreshToken: String
    var accountId: String
    var lastRefresh: Date?

    /// Read ~/.codex/auth.json. Returns nil if missing or malformed.
    static func load() -> CodexAuthFile? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any],
              let access = tokens["access_token"] as? String,
              let refresh = tokens["refresh_token"] as? String,
              let account = tokens["account_id"] as? String
        else { return nil }
        let id = tokens["id_token"] as? String
        let last = (root["last_refresh"] as? String).flatMap(Self.parseISO8601)
        return CodexAuthFile(
            accessToken: access,
            idToken: id,
            refreshToken: refresh,
            accountId: account,
            lastRefresh: last
        )
    }

    /// Persist updated tokens back to ~/.codex/auth.json so the Codex CLI
    /// and Agent! stay in sync after a refresh.
    func save() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent(".codex/auth.json")
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            root = existing
        }
        var tokens: [String: Any] = root["tokens"] as? [String: Any] ?? [:]
        tokens["access_token"] = accessToken
        tokens["refresh_token"] = refreshToken
        tokens["account_id"] = accountId
        if let id = idToken { tokens["id_token"] = id }
        root["tokens"] = tokens
        if let last = lastRefresh {
            root["last_refresh"] = Self.formatISO8601(last)
        }
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private static func parseISO8601(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    private static func formatISO8601(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }
}

// MARK: JWT claim extractor

enum CodexJWT {
    /// Decode the middle segment of a JWT and return the claims dict.
    /// Returns nil for malformed tokens.
    static func claims(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return nil }
        let payload = String(parts[1])
        guard let data = base64URLDecode(payload),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    /// Extract chatgpt_account_id from the nested `https://api.openai.com/auth`
    /// claim. Falls back to the top-level `account_id` from auth.json when
    /// the JWT is opaque or shape has shifted.
    static func accountId(_ jwt: String) -> String? {
        guard let c = claims(jwt),
              let auth = c["https://api.openai.com/auth"] as? [String: Any]
        else { return nil }
        return auth["chatgpt_account_id"] as? String
    }

    /// Expiry timestamp from the `exp` claim (seconds since epoch).
    static func expiry(_ jwt: String) -> Date? {
        guard let c = claims(jwt), let exp = c["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    private static func base64URLDecode(_ s: String) -> Data? {
        var b = s.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        b += String(repeating: "=", count: (4 - b.count % 4) % 4)
        return Data(base64Encoded: b)
    }
}

// MARK: Token refresh

enum CodexAuthRefresher {
    /// OpenAI's published client_id for the Codex CLI. Public (PKCE).
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let tokenURL = URL(string: "https://auth.openai.com/oauth/token") ?? URL(filePath: "/")

    /// Exchange the refresh token for a new access token. Writes the fresh
    /// tokens back to ~/.codex/auth.json so the Codex CLI stays in sync.
    nonisolated static func refresh(_ auth: CodexAuthFile) async throws -> CodexAuthFile {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": auth.refreshToken,
            "client_id": clientID,
            "scope": "openid profile email offline_access"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AgentError.invalidResponse
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = obj["access_token"] as? String
        else { throw AgentError.invalidResponse }
        let refresh = (obj["refresh_token"] as? String) ?? auth.refreshToken
        let id = (obj["id_token"] as? String) ?? auth.idToken
        var updated = CodexAuthFile(
            accessToken: access,
            idToken: id,
            refreshToken: refresh,
            accountId: auth.accountId,
            lastRefresh: Date()
        )
        // Re-extract account ID from the fresh JWT when available.
        if let freshAccount = CodexJWT.accountId(access) { updated.accountId = freshAccount }
        try? updated.save()
        return updated
    }

    /// Returns a valid access token, refreshing if within 5 min of expiry.
    nonisolated static func validAuth() async throws -> CodexAuthFile {
        guard let current = CodexAuthFile.load() else {
            throw AgentError.noAPIKey
        }
        if let expiry = CodexJWT.expiry(current.accessToken),
           expiry.timeIntervalSinceNow < 5 * 60
        {
            return try await refresh(current)
        }
        return current
    }
}

// MARK: Patch applier — Codex freeform grammar

/// Applies Codex's "*** Begin Patch" freeform patch format. Supports:
/// - `*** Add File: <path>` followed by `+` prefixed content lines
/// - `*** Delete File: <path>`
/// - `*** Update File: <path>` with `@@` hunk markers and `+ /- / ` prefixed lines
/// - `*** Move File: <from>` with `*** To: <to>`
/// Relative paths are resolved against `baseFolder` (the project folder).
enum CodexPatchApplier {

    struct Result: Sendable {
        let summary: String
        let files: [String]
    }

    static func apply(patch: String, baseFolder: String) -> Result {
        let lines = patch.components(separatedBy: "\n")
        var idx = 0
        var files: [String] = []
        var notes: [String] = []

        // Skip any preamble before *** Begin Patch
        while idx < lines.count, !lines[idx].hasPrefix("*** Begin Patch") { idx += 1 }
        if idx < lines.count { idx += 1 } // consume Begin Patch

        while idx < lines.count {
            let line = lines[idx]
            if line.hasPrefix("*** End Patch") { break }

            if let path = stripPrefix(line, "*** Add File: ") {
                let (body, consumed) = readAddBody(lines, start: idx + 1)
                let full = resolvePath(path, base: baseFolder)
                do {
                    try FileManager.default.createDirectory(
                        at: URL(fileURLWithPath: full).deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try body.write(toFile: full, atomically: true, encoding: .utf8)
                    files.append(path)
                    notes.append("+ \(path) (\(body.components(separatedBy: "\n").count) lines)")
                } catch {
                    notes.append("! failed to add \(path): \(error.localizedDescription)")
                }
                idx = consumed
                continue
            }

            if let path = stripPrefix(line, "*** Delete File: ") {
                let full = resolvePath(path, base: baseFolder)
                if (try? FileManager.default.removeItem(atPath: full)) != nil {
                    files.append(path)
                    notes.append("- \(path)")
                } else {
                    notes.append("! failed to delete \(path)")
                }
                idx += 1
                continue
            }

            if let path = stripPrefix(line, "*** Update File: ") {
                let (updated, consumed, ok) = applyUpdate(lines, start: idx + 1, path: path, base: baseFolder)
                if ok {
                    files.append(path)
                    notes.append("~ \(path)")
                } else {
                    notes.append("! failed to update \(path): \(updated)")
                }
                idx = consumed
                continue
            }

            if let from = stripPrefix(line, "*** Move File: ") {
                // Expect next line to be "*** To: <dest>"
                var dest: String?
                if idx + 1 < lines.count, let to = stripPrefix(lines[idx + 1], "*** To: ") {
                    dest = to
                }
                if let to = dest {
                    let src = resolvePath(from, base: baseFolder)
                    let dst = resolvePath(to, base: baseFolder)
                    if (try? FileManager.default.moveItem(atPath: src, toPath: dst)) != nil {
                        files.append(from)
                        files.append(to)
                        notes.append("mv \(from) → \(to)")
                    } else {
                        notes.append("! failed to move \(from) → \(to)")
                    }
                    idx += 2
                    continue
                }
            }

            idx += 1
        }

        let summary = notes.isEmpty ? "Patch applied (no changes detected)." : notes.joined(separator: "\n")
        return Result(summary: summary, files: Array(Set(files)))
    }

    private static func stripPrefix(_ line: String, _ prefix: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    private static func resolvePath(_ path: String, base: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") { return expanded }
        return (base as NSString).appendingPathComponent(expanded)
    }

    /// Read `+`-prefixed body lines after an Add File directive. Stops at the
    /// next `*** ` directive or End Patch.
    private static func readAddBody(_ lines: [String], start: Int) -> (body: String, nextIdx: Int) {
        var body: [String] = []
        var i = start
        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("*** ") { break }
            if line.hasPrefix("+") {
                body.append(String(line.dropFirst()))
            } else if line.isEmpty {
                body.append("")
            } else {
                body.append(line)
            }
            i += 1
        }
        return (body.joined(separator: "\n"), i)
    }

    /// Apply `@@` / `+` / `-` / ` ` hunks to an existing file. Reads the file,
    /// walks hunks sequentially, and writes back atomically.
    private static func applyUpdate(_ lines: [String], start: Int, path: String, base: String)
        -> (msg: String, nextIdx: Int, ok: Bool)
    {
        let full = resolvePath(path, base: base)
        guard var source = try? String(contentsOfFile: full, encoding: .utf8) else {
            // Advance past this block to not stall the outer loop
            var i = start
            while i < lines.count, !lines[i].hasPrefix("*** ") { i += 1 }
            return ("file not readable", i, false)
        }
        var sourceLines = source.components(separatedBy: "\n")
        var i = start
        var cursor = 0 // index into sourceLines

        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("*** ") { break }

            if line.hasPrefix("@@") {
                // Skip — we scan for context matches instead of parsing ranges.
                i += 1
                continue
            }

            if line.hasPrefix("+") {
                let inserted = String(line.dropFirst())
                sourceLines.insert(inserted, at: min(cursor, sourceLines.count))
                cursor += 1
            } else if line.hasPrefix("-") {
                let removed = String(line.dropFirst())
                // Find match at or after cursor
                if let found = sourceLines[cursor..<sourceLines.count].firstIndex(of: removed) {
                    sourceLines.remove(at: found)
                    cursor = found
                } else {
                    return ("context mismatch on removal: '\(removed.prefix(60))'", i, false)
                }
            } else if line.hasPrefix(" ") {
                let context = String(line.dropFirst())
                if let found = sourceLines[cursor..<sourceLines.count].firstIndex(of: context) {
                    cursor = found + 1
                } else {
                    return ("context mismatch: '\(context.prefix(60))'", i, false)
                }
            }
            i += 1
        }

        source = sourceLines.joined(separator: "\n")
        do {
            try source.write(toFile: full, atomically: true, encoding: .utf8)
            return ("ok", i, true)
        } catch {
            return (error.localizedDescription, i, false)
        }
    }
}

// MARK: Login launcher

enum CodexLoginLauncher {
    /// Find the `codex` CLI binary. Checks PATH plus a few common install
    /// locations so the button still works when the user's GUI shell hasn't
    /// inherited their interactive PATH (a frequent macOS papercut).
    static func codexBinary() -> String? {
        let candidates = [
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
            "\(NSHomeDirectory())/.nvm/versions/node/v22/bin/codex",
            "\(NSHomeDirectory())/.npm-global/bin/codex",
            "\(NSHomeDirectory())/.bun/bin/codex"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    /// Open Terminal.app with `codex login` pre-typed so the user can watch
    /// the PKCE browser flow and come back. Falls back to opening
    /// https://developers.openai.com/codex/auth if the CLI isn't installed.
    @MainActor
    static func launch() {
        let binary = codexBinary()
        let command: String
        if let bin = binary {
            command = "clear; echo '── codex login ──'; \(bin) login; echo; echo 'Close this window when done.'"
        } else {
            command = "clear; echo 'codex CLI not found. Install with:'; echo '  brew install codex'; echo '  # or: npm install -g @openai/codex'; echo; read -n 1 -s"
        }
        let script = """
        tell application "Terminal"
            activate
            do script "\(command.replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """
        if let apple = NSAppleScript(source: script) {
            var err: NSDictionary?
            apple.executeAndReturnError(&err)
        }
    }
}

// MARK: Main service

@MainActor
final class CodexService {
    let model: String
    let historyContext: String
    let userHome: String
    let userName: String
    let projectFolder: String
    let maxTokens: Int
    var temperature: Double = 0.2
    var compactTools: Bool = false

    /// Reasoning effort sent to gpt-5.x models. Valid values per the /models
    /// endpoint: "low" | "medium" | "high" | "xhigh". Default "high" because
    /// Agent! is a coding agent and coding quality benefits disproportionately
    /// from deeper reasoning. Server default is "medium" if omitted.
    var reasoningEffort: String = "high"

    private static let endpointURL = URL(
        string: "https://chatgpt.com/backend-api/codex/responses"
    ) ?? URL(filePath: "/")

    /// Client version string the Codex backend requires. Sent as both a
    /// `?client_version=` query parameter and in the `User-Agent` header —
    /// without these, /models returns 400 and /responses may reject the body.
    /// Bump to match the published Codex CLI version periodically.
    /// `nonisolated` so it's reachable from `performRequest` (off main actor).
    nonisolated static let clientVersion = "1.0.0"
    nonisolated static let userAgent = "codex_cli_rs/1.0.0"

    /// OpenAI's published identity instruction. Codex's OAuth gate rejects
    /// requests whose `instructions` don't start with this exact prefix —
    /// mirrors Anthropic's `claudeCodeIdentityPrompt` requirement.
    static let codexIdentityPrompt =
        "You are Codex, based on GPT-5. You are running as a coding agent in the Codex CLI on a user's computer."

    init(
        model: String,
        historyContext: String = "",
        projectFolder: String = "",
        maxTokens: Int = 0
    ) {
        self.model = model
        self.historyContext = historyContext
        self.projectFolder = projectFolder
        self.maxTokens = maxTokens
        self.userHome = FileManager.default.homeDirectoryForCurrentUser.path
        self.userName = NSUserName()
    }

    /// Full `instructions` string sent to /responses. Starts with the
    /// Codex identity line (required by the OAuth gate), then Agent!'s
    /// base system prompt, then optional project folder and history.
    var instructions: String {
        var s = Self.codexIdentityPrompt + "\n\n"
        s += SystemPromptService.shared.prompt(
            for: .openAI,
            userName: userName,
            userHome: userHome,
            projectFolder: projectFolder
        )
        if !projectFolder.isEmpty {
            s = "CURRENT PROJECT FOLDER: \(projectFolder)\n\n" + s
        }
        if !historyContext.isEmpty { s += historyContext }
        s += MemoryStore.shared.contextBlock
        return s
    }

    /// Build the `input` array for /responses. Converts Agent!'s
    /// `[{role, content}]` message stream into Responses items. Tool-use
    /// and tool-result blocks are converted to `function_call` /
    /// `function_call_output` items per the Responses schema.
    nonisolated static func buildInput(_ messages: [[String: Any]]) -> [[String: Any]] {
        var out: [[String: Any]] = []
        for msg in messages {
            guard let role = msg["role"] as? String else { continue }
            if let text = msg["content"] as? String {
                out.append([
                    "type": "message",
                    "role": role,
                    "content": [["type": role == "assistant" ? "output_text" : "input_text", "text": text]]
                ])
                continue
            }
            guard let blocks = msg["content"] as? [[String: Any]] else { continue }
            // Split blocks: text/image → message item; tool_use → function_call; tool_result → function_call_output
            var messageBlocks: [[String: Any]] = []
            for block in blocks {
                let type = block["type"] as? String ?? ""
                switch type {
                case "text":
                    messageBlocks.append([
                        "type": role == "assistant" ? "output_text" : "input_text",
                        "text": block["text"] as? String ?? ""
                    ])
                case "image":
                    if let src = block["source"] as? [String: Any],
                       let mime = src["media_type"] as? String,
                       let data = src["data"] as? String
                    {
                        messageBlocks.append([
                            "type": "input_image",
                            "image_url": "data:\(mime);base64,\(data)"
                        ])
                    }
                case "tool_use":
                    if let id = block["id"] as? String,
                       let name = block["name"] as? String
                    {
                        let input = block["input"] as? [String: Any] ?? [:]
                        let args = (try? JSONSerialization.data(withJSONObject: input))
                            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                        out.append([
                            "type": "function_call",
                            "call_id": id,
                            "name": name,
                            "arguments": args
                        ])
                    }
                case "tool_result":
                    let content: String
                    if let s = block["content"] as? String {
                        content = s
                    } else if let arr = block["content"] as? [[String: Any]] {
                        content = arr.compactMap { ($0["text"] as? String) }.joined(separator: "\n")
                    } else {
                        content = ""
                    }
                    out.append([
                        "type": "function_call_output",
                        "call_id": block["tool_use_id"] as? String ?? "",
                        "output": content
                    ])
                default:
                    continue
                }
            }
            if !messageBlocks.isEmpty {
                out.append([
                    "type": "message",
                    "role": role,
                    "content": messageBlocks
                ])
            }
        }
        return out
    }

    /// Convert Agent!'s Anthropic-shaped tool definitions into Responses API
    /// `function` tools. Responses expects `{type:"function", name, parameters}`
    /// at the top level — NOT nested under `function:` like chat/completions.
    /// Filters out cross-provider web_search variants in favor of Codex's
    /// native `{type:"web_search"}` (billed against the ChatGPT subscription,
    /// runs server-side with URL annotations).
    nonisolated static func buildTools(_ anthropicTools: [[String: Any]]) -> [[String: Any]] {
        var tools: [[String: Any]] = anthropicTools.compactMap { t in
            guard let name = t["name"] as? String else { return nil }
            // Skip every web_search variant — Codex's native one is added below.
            if (t["type"] as? String) == "web_search_20250305" { return nil }
            if name == "web_search" { return nil }
            var out: [String: Any] = [
                "type": "function",
                "name": name,
                "description": t["description"] as? String ?? ""
            ]
            if let schema = t["input_schema"] as? [String: Any] {
                out["parameters"] = schema
            } else {
                out["parameters"] = ["type": "object", "properties": [:]]
            }
            return out
        }
        // Codex-native tools (apply_patch + web_search) appended last.
        tools.append(contentsOf: codexNativeTools())
        return tools
    }

    /// Codex-native tools appended to every request.
    /// - `web_search` — server-side hosted tool (no params, no handler on our
    ///   side). Model emits `response.web_search_call.*` events; search
    ///   happens on ChatGPT's backend; results are woven into the streaming
    ///   text via URL annotations. Billed under the ChatGPT subscription.
    /// - `apply_patch` — freeform patch grammar; dispatched locally to
    ///   `CodexPatchApplier` via `handleFileTool`.
    nonisolated static func codexNativeTools() -> [[String: Any]] {
        [
            ["type": "web_search"],
            [
                "type": "function",
                "name": "apply_patch",
                "description": "Apply a patch in Codex's freeform grammar. Prefer this over edit_file for multi-file or multi-hunk changes. The `patch` field starts with '*** Begin Patch' and ends with '*** End Patch'; supports *** Add File, *** Update File, *** Delete File, and *** Move File directives with +/- prefixed lines.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "patch": [
                            "type": "string",
                            "description": "Complete patch document in the *** Begin Patch / *** End Patch grammar."
                        ]
                    ],
                    "required": ["patch"],
                    "additionalProperties": false
                ]
            ]
        ]
    }

    /// Parse a /responses reply back into Agent!'s Anthropic-shaped content
    /// array so the rest of TaskExecution can consume it unchanged.
    nonisolated static func parseResponse(_ obj: [String: Any]) -> (content: [[String: Any]], stopReason: String, inputTokens: Int, outputTokens: Int) {
        var content: [[String: Any]] = []
        if let outputs = obj["output"] as? [[String: Any]] {
            for item in outputs {
                let type = item["type"] as? String ?? ""
                if type == "message", let blocks = item["content"] as? [[String: Any]] {
                    for b in blocks {
                        if let t = b["text"] as? String, !t.isEmpty {
                            content.append(["type": "text", "text": t])
                        }
                    }
                } else if type == "function_call" {
                    let name = item["name"] as? String ?? ""
                    let id = item["call_id"] as? String ?? item["id"] as? String ?? ""
                    let argsStr = item["arguments"] as? String ?? "{}"
                    let argsData = argsStr.data(using: .utf8) ?? Data()
                    let input = (try? JSONSerialization.jsonObject(with: argsData)) as? [String: Any] ?? [:]
                    content.append([
                        "type": "tool_use",
                        "id": id,
                        "name": name,
                        "input": input
                    ])
                }
            }
        }
        let stop = (obj["status"] as? String) ?? "end_turn"
        let usage = obj["usage"] as? [String: Any]
        let inTok = (usage?["input_tokens"] as? Int) ?? 0
        let outTok = (usage?["output_tokens"] as? Int) ?? 0
        return (content, stop, inTok, outTok)
    }

    /// Stream a request to /responses. The Codex backend is streaming-only
    /// (`stream:false` → 400 "Stream must be set to true"), so this is the
    /// only entry point. Parses SSE events live and dispatches text deltas
    /// to `onDelta`; accumulates the full Anthropic-shaped content for
    /// return when the stream ends.
    func sendStreaming(
        messages: [[String: Any]],
        activeGroups: Set<String>? = nil,
        onDelta: @MainActor @Sendable @escaping (String) -> Void
    ) async throws
        -> (content: [[String: Any]], stopReason: String, inputTokens: Int, outputTokens: Int)
    {
        let auth = try await CodexAuthRefresher.validAuth()
        let toolDefs = AgentTools.claudeFormat(
            activeGroups: activeGroups,
            compact: compactTools,
            projectFolder: projectFolder
        )
        var body: [String: Any] = [
            "model": model.isEmpty ? "gpt-5" : model,
            "instructions": instructions,
            "input": Self.buildInput(messages),
            "store": false,
            "stream": true,
            // `summary: "auto"` makes the backend emit
            // `response.reasoning_summary_text.delta` events; without it the
            // model reasons silently and nothing visible streams during the
            // thinking phase.
            "reasoning": ["effort": reasoningEffort, "summary": "auto"]
        ]
        if maxTokens > 0 { body["max_output_tokens"] = maxTokens }
        let tools = Self.buildTools(toolDefs)
        if !tools.isEmpty { body["tools"] = tools }
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let urlWithVersion = URL(
            string: Self.endpointURL.absoluteString + "?client_version=\(Self.clientVersion)"
        ) ?? Self.endpointURL
        return try await Self.streamRequest(
            bodyData: bodyData,
            auth: auth,
            url: urlWithVersion,
            onDelta: onDelta
        )
    }

    /// Compatibility `send` — same shape as ClaudeService, internally streams
    /// with a no-op delta callback and returns the accumulated content.
    func send(
        messages: [[String: Any]],
        activeGroups: Set<String>? = nil
    ) async throws
        -> (content: [[String: Any]], stopReason: String, inputTokens: Int, outputTokens: Int)
    {
        try await sendStreaming(
            messages: messages,
            activeGroups: activeGroups,
            onDelta: { _ in }
        )
    }

    /// Fetch the live model list from the Codex OAuth endpoint. The set varies
    /// by ChatGPT subscription tier — Plus / Pro / Business / Edu / Enterprise
    /// each expose different models — so we never hardcode.
    /// Fetched model metadata. `contextWindow` comes from the `/models` response
    /// so `ThinkingIndicatorView` can show the correct token ceiling per model.
    struct ModelInfo: Sendable {
        public let id: String
        public let display: String
        public let contextWindow: Int
    }

    nonisolated static func fetchModels() async throws -> [ModelInfo] {
        let auth = try await CodexAuthRefresher.validAuth()
        let url = URL(string: "https://chatgpt.com/backend-api/codex/models?client_version=\(clientVersion)") ?? URL(filePath: "/")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.accountId, forHTTPHeaderField: "chatgpt-account-id")
        request.setValue("responses=v1", forHTTPHeaderField: "OpenAI-Beta")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            AuditLog.log(.api, "Codex /models \((response as? HTTPURLResponse)?.statusCode ?? -1): \(body.prefix(500))")
            throw AgentError.invalidResponse
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = obj["models"] as? [[String: Any]]
        else { throw AgentError.invalidResponse }
        // Shape: { "models": [ { "slug": "gpt-5.2", "display_name": "gpt-5.2", "visibility": "list", ... } ] }
        // Filter to visible models only.
        return items.compactMap { item -> ModelInfo? in
            guard let slug = item["slug"] as? String else { return nil }
            if let vis = item["visibility"] as? String, vis == "hidden" { return nil }
            let display = (item["display_name"] as? String) ?? slug
            let ctx = (item["context_window"] as? Int) ?? 0
            return ModelInfo(id: slug, display: display, contextWindow: ctx)
        }
    }

    /// Translate a raw Codex error body into a message the user can act on.
    /// Handles the common cases (free-tier usage limit, 5-hour window, 401
    /// revoked token). Falls back to the raw JSON `error.message`.
    nonisolated static func friendlyError(status: Int, body: String) -> String {
        let data = body.data(using: .utf8) ?? Data()
        let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let err = (parsed?["error"] as? [String: Any]) ?? parsed ?? [:]
        let type = (err["type"] as? String) ?? ""
        let raw = (err["message"] as? String) ?? (err["detail"] as? String) ?? body.prefix(200).description
        if type == "usage_limit_reached" {
            let plan = (err["plan_type"] as? String) ?? "current"
            let resets = (err["resets_in_seconds"] as? Int) ?? 0
            let resetsDays = Double(resets) / 86400.0
            let resetsHuman = resets > 0
                ? String(format: "~%.1f days", resetsDays)
                : "unknown"
            return "ChatGPT \(plan) plan usage limit reached. Resets in \(resetsHuman). Upgrade at https://chatgpt.com/explore/plus or wait."
        }
        if status == 401 { return "Unauthorized — sign in again (click Sign In in the Codex settings panel)." }
        if status == 429 { return "Rate limited by Codex. \(raw)" }
        return raw
    }

    /// Outer streamer that handles 401 auto-refresh. Only retries on 401
    /// (token revoked server-side) — 429 / 400 / 500 propagate as-is with the
    /// server's error message intact.
    nonisolated private static func streamRequest(
        bodyData: Data,
        auth: CodexAuthFile,
        url: URL,
        onDelta: @MainActor @Sendable @escaping (String) -> Void
    ) async throws -> (content: [[String: Any]], stopReason: String, inputTokens: Int, outputTokens: Int) {
        do {
            return try await streamRequestAttempt(bodyData: bodyData, auth: auth, url: url, onDelta: onDelta)
        } catch let AgentError.apiError(status, _) where status == 401 {
            // 401 only — force-refresh access token and retry once.
            guard let current = CodexAuthFile.load() else { throw AgentError.noAPIKey }
            let fresh = try await CodexAuthRefresher.refresh(current)
            return try await streamRequestAttempt(bodyData: bodyData, auth: fresh, url: url, onDelta: onDelta)
        }
    }

    /// SSE event types emitted by the Codex /responses stream. We handle
    /// output_text deltas (assistant text), function_call argument deltas
    /// (tool use), and the final `response.completed` event (usage counts).
    nonisolated private static func streamRequestAttempt(
        bodyData: Data,
        auth: CodexAuthFile,
        url: URL,
        onDelta: @MainActor @Sendable @escaping (String) -> Void
    ) async throws -> (content: [[String: Any]], stopReason: String, inputTokens: Int, outputTokens: Int) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.accountId, forHTTPHeaderField: "chatgpt-account-id")
        request.setValue("responses=v1", forHTTPHeaderField: "OpenAI-Beta")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = bodyData
        request.timeoutInterval = 300

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw AgentError.invalidResponse }
        guard http.statusCode == 200 else {
            var errBody = ""
            for try await line in bytes.lines { errBody += line + "\n"; if errBody.count > 1200 { break } }
            AuditLog.log(.api, "Codex API \(http.statusCode): \(errBody.prefix(800))")
            let friendly = Self.friendlyError(status: http.statusCode, body: errBody)
            throw AgentError.apiError(statusCode: http.statusCode, message: friendly)
        }

        // Assistant text accumulated per output item (keyed by item_id).
        var textByItem: [String: String] = [:]
        // Tool-use items: id → (name, accumulated arg JSON string).
        var toolByItem: [String: (name: String, args: String, callId: String)] = [:]
        // Preserves emission order so tool_use and text blocks come out the way the model produced them.
        var itemOrder: [String] = []
        var itemKind: [String: String] = [:] // "text" | "tool_use" | "thinking"
        // Reasoning / thinking summary (when model runs reasoning). Emitted first
        // so the UI can display it above the final text, matching Claude's block order.
        var thinking = ""
        var stopReason = "end_turn"
        var inputTokens = 0
        var outputTokens = 0

        for try await rawLine in bytes.lines {
            // SSE framing: `event: <name>` followed by `data: <json>`, blank line delimits.
            // URLSession.bytes.lines already splits on \n, so we only care about `data:` lines.
            guard rawLine.hasPrefix("data:") else { continue }
            let json = String(rawLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            guard !json.isEmpty, json != "[DONE]",
                  let data = json.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = obj["type"] as? String
            else { continue }

            switch type {
            case "response.output_item.added":
                guard let item = obj["item"] as? [String: Any],
                      let id = item["id"] as? String else { continue }
                let kind = item["type"] as? String ?? ""
                if kind == "message" {
                    textByItem[id] = ""
                    if itemKind[id] == nil { itemOrder.append(id); itemKind[id] = "text" }
                } else if kind == "function_call" {
                    let name = item["name"] as? String ?? ""
                    let callId = (item["call_id"] as? String) ?? id
                    toolByItem[id] = (name, "", callId)
                    if itemKind[id] == nil { itemOrder.append(id); itemKind[id] = "tool_use" }
                }

            case "response.output_text.delta":
                guard let itemId = obj["item_id"] as? String,
                      let delta = obj["delta"] as? String else { continue }
                textByItem[itemId, default: ""] += delta
                if itemKind[itemId] == nil { itemOrder.append(itemId); itemKind[itemId] = "text" }
                await MainActor.run { onDelta(delta) }

            case "response.function_call_arguments.delta":
                guard let itemId = obj["item_id"] as? String,
                      let delta = obj["delta"] as? String else { continue }
                toolByItem[itemId, default: ("", "", itemId)].args += delta

            case "response.reasoning_summary_text.delta", "response.reasoning_text.delta":
                // Reasoning summary streamed during thinking. Pipe through
                // onDelta so it shows live in LLM Output (the user wants to see
                // the model reasoning, not a blank screen for 30s), AND
                // accumulate into a final `thinking` content block so task
                // history retains it separately from the visible reply.
                if let delta = obj["delta"] as? String {
                    thinking += delta
                    await MainActor.run { onDelta(delta) }
                }

            case "response.web_search_call.in_progress":
                await MainActor.run { onDelta("\n🔍 web_search…") }

            case "response.web_search_call.completed":
                await MainActor.run { onDelta(" done\n") }

            case "response.completed":
                stopReason = "end_turn"
                if let resp = obj["response"] as? [String: Any],
                   let usage = resp["usage"] as? [String: Any]
                {
                    inputTokens = (usage["input_tokens"] as? Int) ?? 0
                    outputTokens = (usage["output_tokens"] as? Int) ?? 0
                }

            case "response.failed", "response.incomplete":
                if let resp = obj["response"] as? [String: Any],
                   let err = resp["error"] as? [String: Any],
                   let msg = err["message"] as? String
                {
                    AuditLog.log(.api, "Codex stream \(type): \(msg)")
                }
                stopReason = "error"

            default:
                continue
            }
        }

        var content: [[String: Any]] = []
        if !thinking.isEmpty {
            content.append(["type": "thinking", "thinking": thinking])
        }
        for id in itemOrder {
            if itemKind[id] == "text", let text = textByItem[id], !text.isEmpty {
                content.append(["type": "text", "text": text])
            } else if itemKind[id] == "tool_use", let tool = toolByItem[id] {
                let argData = tool.args.data(using: .utf8) ?? Data("{}".utf8)
                let input = (try? JSONSerialization.jsonObject(with: argData)) as? [String: Any] ?? [:]
                content.append([
                    "type": "tool_use",
                    "id": tool.callId,
                    "name": tool.name,
                    "input": input
                ])
            }
        }
        if content.contains(where: { ($0["type"] as? String) == "tool_use" }) {
            stopReason = "tool_use"
        }
        return (content, stopReason, inputTokens, outputTokens)
    }
}
