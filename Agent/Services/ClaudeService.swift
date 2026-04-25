import AgentLLM
import AgentAudit
@preconcurrency import Foundation
import AgentTools

@MainActor
final class ClaudeService {
    let apiKey: String
    let model: String
    let endpointURL: URL

    private static let defaultBaseURL = URL(string: "https://api.anthropic.com/v1/messages") ?? URL(filePath: "/")
    private static let apiVersion = "2023-06-01"
    private let isLocalEndpoint: Bool
    /// True only when the endpoint host is localhost — gates the compact-prompt fallback.
    /// Why: LM Studio runs on tiny context windows so we shrink the system prompt;
    /// remote Anthropic-compat proxies (OpenRouter) have full Claude context, so they should get the full prompt.
    private let isLocalhostEndpoint: Bool

    // MARK: - Rate Limit Tracking
    // Anthropic 429/529 → capture Retry-After, pad next request. Mirrors OpenAICompatibleService pattern, separate dict for independent tracking.
    private static var retryAfterUntil: CFAbsoluteTime = 0

    /// Wait if needed to respect Retry-After backoff from a previous 429/529.
    private static func enforceRateLimit() async {
        let now = CFAbsoluteTimeGetCurrent()
        if retryAfterUntil > now {
            let wait = retryAfterUntil - now
            try? await Task.sleep(for: .seconds(wait))
        }
    }

    /// Record Retry-After from 429/529. @MainActor because static var is owned by this @MainActor class; called from nonisolated via `await MainActor.run`.
    static func recordRetryAfter(_ seconds: Double) {
        retryAfterUntil = CFAbsoluteTimeGetCurrent() + seconds
    }

    /// Parse Retry-After header. Integer seconds per RFC 7231 §7.1.3. Returns 0 if missing/unparseable; capped at 5 min.
    nonisolated static func parseRetryAfter(_ headerValue: String?) -> Double {
        guard let v = headerValue?.trimmingCharacters(in: .whitespaces),
              !v.isEmpty,
              let seconds = Double(v) else { return 0 }
        return min(seconds, 300)
    }

    let historyContext: String
    let userHome: String
    let userName: String
    let projectFolder: String
    /// Max output tokens. 0 = use default (16384). Claude API requires this field.
    let maxTokens: Int

    init(
        apiKey: String,
        model: String,
        historyContext: String = "",
        projectFolder: String = "",
        baseURL: String? = nil,
        maxTokens: Int = 0
    ) {
        self.apiKey = apiKey
        self.model = model
        self.endpointURL = baseURL.flatMap { URL(string: $0) } ?? Self.defaultBaseURL
        self.isLocalEndpoint = baseURL != nil
        let host = self.endpointURL.host ?? ""
        self.isLocalhostEndpoint = baseURL != nil
            && (host == "localhost" || host == "127.0.0.1" || host == "::1")
        self.maxTokens = maxTokens
        self.historyContext = historyContext
        self.userHome = FileManager.default.homeDirectoryForCurrentUser.path
        self.userName = NSUserName()
        self.projectFolder = projectFolder
    }

    /// When set, overrides the full system prompt (used for coding mode iterations 2+)
    var overrideSystemPrompt: String?

    var systemPrompt: String {
        if let override = overrideSystemPrompt { return override }
        if isLocalhostEndpoint {
            // Local Claude-protocol endpoints (LM Studio) bypass SystemPromptService — wrap with anti-hallucination rules to match other providers.
            return SystemPromptService.wrapWithRules(
                AgentTools.compactSystemPrompt(userName: userName, userHome: userHome, projectFolder: projectFolder)
            )
        }
        var prompt = SystemPromptService.shared.prompt(for: .claude, userName: userName, userHome: userHome, projectFolder: projectFolder)
        if !projectFolder.isEmpty {
            prompt =
                "CURRENT PROJECT FOLDER: \(projectFolder)\n"
                    + "Always cd to this directory before running any "
                    + "shell commands. Use it as the default for all file "
                    + "operations. You may go outside it when needed.\n\n" +
                prompt
        }
        if !historyContext.isEmpty {
            prompt += historyContext
        }
        prompt += MemoryStore.shared.contextBlock
        return prompt
    }

    func tools(activeGroups: Set<String>? = nil, compact: Bool = false) -> [[String: Any]] {
        // No mode-based narrowing — every user-enabled tool flows through.
        // Local endpoints with tight context windows can disable groups via the UI.
        var t = AgentTools.claudeFormat(activeGroups: activeGroups, compact: compact, projectFolder: projectFolder)
        // Only add native web_search for real Anthropic API — remove Tavily duplicate first
        if !isLocalEndpoint {
            t.removeAll { ($0["name"] as? String) == "web_search" }
            t.append([
                "type": "web_search_20250305",
                "name": "web_search"
            ])
        }
        return t
    }

    /// Strip orphan `tool_result` blocks (no matching `tool_use` in the prior
    /// assistant message). Anthropic returns 400 on these. Also drop user messages
    /// that become empty after stripping. Mirrors the logic in MessageSanitizer
    /// but runs at the request boundary so stale state can't reach the API.
    private func stripOrphanToolResults(_ messages: [[String: Any]]) -> [[String: Any]] {
        var result = messages
        var i = 0
        while i < result.count {
            guard (result[i]["role"] as? String) == "user",
                  var blocks = result[i]["content"] as? [[String: Any]]
            else { i += 1; continue }

            var validIds = Set<String>()
            if i > 0,
               (result[i - 1]["role"] as? String) == "assistant",
               let prev = result[i - 1]["content"] as? [[String: Any]]
            {
                for block in prev where (block["type"] as? String) == "tool_use" {
                    if let id = block["id"] as? String { validIds.insert(id) }
                }
            }

            var changed = false
            blocks.removeAll { block in
                guard (block["type"] as? String) == "tool_result",
                      let id = block["tool_use_id"] as? String
                else { return false }
                if validIds.contains(id) { return false }
                changed = true
                return true
            }
            if changed {
                if blocks.isEmpty {
                    result.remove(at: i)
                    continue
                }
                result[i]["content"] = blocks
            }
            i += 1
        }
        return result
    }

    /// Prepend project folder to the last user message so it's always visible in context.
    private func withFolderPrefix(_ messages: [[String: Any]]) -> [[String: Any]] {
        guard !projectFolder.isEmpty else { return messages }
        let prefix = "PROJECT FOLDER: \(projectFolder)\n"
        var result = messages
        for i in stride(from: result.count - 1, through: 0, by: -1) {
            guard result[i]["role"] as? String == "user" else { continue }
            if let text = result[i]["content"] as? String {
                result[i]["content"] = prefix + text
            } else if var blocks = result[i]["content"] as? [[String: Any]],
                      let first = blocks.first, first["type"] as? String == "text",
                      let existing = first["text"] as? String
            {
                blocks[0]["text"] = prefix + existing
                result[i]["content"] = blocks
            }
            break
        }
        return result
    }

    var temperature: Double = 0.2
    var compactTools: Bool = false

    func send(
        messages: [[String: Any]],
        activeGroups: Set<String>? = nil
    ) async throws
        -> (content: [[String: Any]], stopReason: String, inputTokens: Int, outputTokens: Int)
    {
        guard isLocalEndpoint || !apiKey.isEmpty else { throw AgentError.noAPIKey }
        await Self.enforceRateLimit()

        let systemBlock: Any = isLocalEndpoint ? systemPrompt : Self.buildSystemBlock(
            systemPrompt: systemPrompt,
            credential: apiKey
        )

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens > 0 ? maxTokens : 16384,
            "temperature": temperature,
            "system": systemBlock,
            "messages": withFolderPrefix(stripOrphanToolResults(messages))
        ]
        // Only include tools for real Anthropic API
        if !isLocalEndpoint {
            var toolDefs = tools(activeGroups: activeGroups, compact: compactTools)
            // Mark last tool with cache_control for prompt caching
            if !toolDefs.isEmpty {
                toolDefs[toolDefs.count - 1]["cache_control"] = ["type": "ephemeral"]
            }
            body["tools"] = toolDefs
        }

        // Serialize on main actor, then offload network I/O + parsing. .sortedKeys produces byte-stable JSON regardless of dict iteration order — required for prefix caching to hit.
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return try await Self.performRequest(
            bodyData: bodyData,
            apiKey: apiKey,
            apiVersion: Self.apiVersion,
            url: endpointURL
        )
    }

    /// Strip every whitespace / control character from a pasted credential.
    /// Terminals visually wrap long OAuth tokens across multiple lines; depending
    /// on the emulator and copy method, the paste can include `\n`, `\r`, spaces,
    /// or tabs. A bearer credential with any of those embedded breaks the
    /// `Authorization` header (Anthropic rejects with 401, and rapid rejections
    /// can cascade into 429 rate-limit responses per IP / account).
    nonisolated static func sanitizedCredential(_ raw: String) -> String {
        raw.unicodeScalars
            .filter { !CharacterSet.whitespacesAndNewlines.contains($0)
                    && !CharacterSet.controlCharacters.contains($0) }
            .map { String($0) }
            .joined()
    }

    /// True when `credential` is a Claude Code OAuth token (from
    /// `claude setup-token`) rather than a standard API key. OAuth tokens
    /// start with `sk-ant-oat01-`; API keys start with `sk-ant-api…`.
    nonisolated static func isOAuthToken(_ credential: String) -> Bool {
        sanitizedCredential(credential).hasPrefix("sk-ant-oat01-")
    }

    /// Claude Code's identity system prompt. OAuth tokens minted by
    /// `claude setup-token` are gated at the API to requests whose first
    /// system block is this string; anything else 429s immediately with a
    /// bare `"message":"Error"` body (no Retry-After). API-key requests
    /// skip this block — only Agent's own prompt goes through.
    nonisolated static let claudeCodeIdentityPrompt =
        "You are Claude Code, Anthropic's official CLI for Claude."

    /// Build the `system` array. For OAuth credentials, prepend the Claude
    /// Code identity block so the request passes Anthropic's OAuth gate.
    /// Agent's real system prompt follows, still marked for prompt caching.
    nonisolated static func buildSystemBlock(
        systemPrompt: String,
        credential: String
    ) -> [[String: Any]] {
        if isOAuthToken(credential) {
            return [
                ["type": "text", "text": claudeCodeIdentityPrompt],
                ["type": "text", "text": systemPrompt, "cache_control": ["type": "ephemeral"]]
            ]
        }
        return [
            ["type": "text", "text": systemPrompt, "cache_control": ["type": "ephemeral"]]
        ]
    }

    /// Apply the correct auth headers for either an API key or an OAuth token.
    /// OAuth tokens use `Authorization: Bearer` + the `oauth-2025-04-20` beta
    /// header (alongside prompt-caching); API keys use `x-api-key`.
    nonisolated private static func applyAuthHeaders(
        on request: inout URLRequest,
        credential: String,
        apiVersion: String
    ) {
        let clean = sanitizedCredential(credential)
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if clean.hasPrefix("sk-ant-oat01-") {
            request.setValue("Bearer \(clean)", forHTTPHeaderField: "Authorization")
            // Both beta flags — OAuth auth AND prompt caching — in a single
            // comma-separated header value.
            request.setValue(
                "oauth-2025-04-20,prompt-caching-2024-07-31",
                forHTTPHeaderField: "anthropic-beta"
            )
        } else if clean.hasPrefix("sk-or-") {
            // OpenRouter Anthropic-compat endpoint — wants Bearer auth, no Anthropic beta headers.
            request.setValue("Bearer \(clean)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue(clean, forHTTPHeaderField: "x-api-key")
            request.setValue("prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")
        }
    }

    /// Network I/O and response parsing off the main thread
    nonisolated private static func performRequest(
        bodyData: Data, apiKey: String, apiVersion: String, url: URL
    ) async throws -> (content: [[String: Any]], stopReason: String, inputTokens: Int, outputTokens: Int) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuthHeaders(on: &request, credential: apiKey, apiVersion: apiVersion)
        request.httpBody = bodyData
        request.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // 429 = rate limit, 529 = Anthropic "Overloaded". Both include Retry-After header (integer seconds); record it so next call's enforceRateLimit pads the wait. Default 30s if header missing.
            if httpResponse.statusCode == 429 || httpResponse.statusCode == 529 {
                let header = httpResponse.value(forHTTPHeaderField: "Retry-After")
                let parsed = Self.parseRetryAfter(header)
                let waitSeconds = parsed > 0 ? parsed : 30
                await MainActor.run {
                    Self.recordRetryAfter(waitSeconds)
                }
            }
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AgentError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let stopReason = json["stop_reason"] as? String else
        {
            throw AgentError.invalidResponse
        }

        let usage = json["usage"] as? [String: Any]
        let inputTokens = usage?["input_tokens"] as? Int ?? 0
        let outputTokens = usage?["output_tokens"] as? Int ?? 0

        return (content, stopReason, inputTokens, outputTokens)
    }

    // MARK: - Streaming

    func sendStreaming(
        messages: [[String: Any]],
        activeGroups: Set<String>? = nil,
        onTextDelta: @escaping @Sendable (String) -> Void
    ) async throws -> (content: [[String: Any]], stopReason: String, inputTokens: Int, outputTokens: Int) {
        guard isLocalEndpoint || !apiKey.isEmpty else { throw AgentError.noAPIKey }
        await Self.enforceRateLimit()

        let systemBlock: Any = isLocalEndpoint ? systemPrompt : Self.buildSystemBlock(
            systemPrompt: systemPrompt,
            credential: apiKey
        )

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens > 0 ? maxTokens : 16384,
            "system": systemBlock,
            "messages": withFolderPrefix(stripOrphanToolResults(messages)),
            "stream": true
        ]
        if !isLocalEndpoint {
            var toolDefs = tools(activeGroups: activeGroups, compact: compactTools)
            if !toolDefs.isEmpty {
                toolDefs[toolDefs.count - 1]["cache_control"] = ["type": "ephemeral"]
            }
            body["tools"] = toolDefs
        }

        // .sortedKeys for byte-stable prefix caching — see send() for rationale.
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return try await Self.performStreamingRequest(
            bodyData: bodyData,
            apiKey: apiKey,
            apiVersion: Self.apiVersion,
            url: endpointURL,
            onTextDelta: onTextDelta
        )
    }

    nonisolated private static func performStreamingRequest(
        bodyData: Data, apiKey: String, apiVersion: String, url: URL,
        onTextDelta: @escaping @Sendable (String) -> Void
    ) async throws -> (content: [[String: Any]], stopReason: String, inputTokens: Int, outputTokens: Int) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuthHeaders(on: &request, credential: apiKey, apiVersion: apiVersion)
        request.httpBody = bodyData
        request.timeoutInterval = llmAPITimeout

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // 429/529 Retry-After capture — see performRequest for rationale.
            if httpResponse.statusCode == 429 || httpResponse.statusCode == 529 {
                let header = httpResponse.value(forHTTPHeaderField: "Retry-After")
                let parsed = Self.parseRetryAfter(header)
                let waitSeconds = parsed > 0 ? parsed : 30
                await MainActor.run {
                    Self.recordRetryAfter(waitSeconds)
                }
            }
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorBody = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AgentError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        var contentBlocks: [[String: Any]] = []
        var currentTextBlock = ""
        var currentToolId = ""
        var currentToolName = ""
        var currentToolJson = ""
        var stopReason = ""
        var inToolUse = false
        var inServerToolUse = false
        var pendingServerResult: [String: Any]?
        var inputTokens = 0
        var outputTokens = 0

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            guard let data = jsonStr.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String else { continue }

            switch type {
            case "message_start":
                if let message = event["message"] as? [String: Any],
                   let usage = message["usage"] as? [String: Any]
                {
                    inputTokens = usage["input_tokens"] as? Int ?? 0
                    // Track prompt cache metrics
                    let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                    let cacheCreation = usage["cache_creation_input_tokens"] as? Int ?? 0
                    if cacheRead > 0 || cacheCreation > 0 {
                        Task { @MainActor in
                            TokenUsageStore.shared.recordCacheMetrics(read: cacheRead, creation: cacheCreation)
                        }
                    }
                }

            case "content_block_start":
                if let block = event["content_block"] as? [String: Any],
                   let blockType = block["type"] as? String
                {
                    if blockType == "text" {
                        currentTextBlock = ""
                        inToolUse = false
                        inServerToolUse = false
                    } else if blockType == "tool_use" {
                        currentToolId = block["id"] as? String ?? ""
                        currentToolName = block["name"] as? String ?? ""
                        currentToolJson = ""
                        inToolUse = true
                        inServerToolUse = false
                    } else if blockType == "server_tool_use" {
                        currentToolId = block["id"] as? String ?? ""
                        currentToolName = block["name"] as? String ?? ""
                        currentToolJson = ""
                        inToolUse = true
                        inServerToolUse = true
                    } else if blockType == "web_search_tool_result" {
                        pendingServerResult = block
                    }
                }

            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   let deltaType = delta["type"] as? String
                {
                    if deltaType == "text_delta", let text = delta["text"] as? String {
                        currentTextBlock += text
                        onTextDelta(text)
                    } else if deltaType == "input_json_delta", let json = delta["partial_json"] as? String {
                        currentToolJson += json
                    }
                }

            case "content_block_stop":
                if inToolUse {
                    let input: [String: Any]
                    if let parsed = try? JSONSerialization.jsonObject(with: Data(currentToolJson.utf8)) as? [String: Any] {
                        input = parsed
                    } else {
                        AuditLog.log(
                            .api,
                            "[ClaudeService] Failed to parse tool args for \(currentToolName): \(currentToolJson.prefix(200))"
                        )
                        input = [:]
                    }
                    let blockType = inServerToolUse ? "server_tool_use" : "tool_use"
                    contentBlocks.append([
                        "type": blockType,
                        "id": currentToolId,
                        "name": currentToolName,
                        "input": input
                    ])
                    currentToolName = ""
                    currentToolId = ""
                    currentToolJson = ""
                    inToolUse = false
                    inServerToolUse = false
                } else if let result = pendingServerResult {
                    contentBlocks.append(result)
                    pendingServerResult = nil
                } else if !currentTextBlock.isEmpty {
                    contentBlocks.append(["type": "text", "text": currentTextBlock])
                    currentTextBlock = ""
                }

            case "message_delta":
                if let delta = event["delta"] as? [String: Any],
                   let reason = delta["stop_reason"] as? String
                {
                    stopReason = reason
                }
                if let usage = event["usage"] as? [String: Any] {
                    outputTokens = usage["output_tokens"] as? Int ?? outputTokens
                }

            default:
                break
            }
        }

        return (contentBlocks, stopReason, inputTokens, outputTokens)
    }
}
