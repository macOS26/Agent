import FoundationModels
import Foundation

/// On-device language model provider using Apple's Foundation Models framework.
/// Requires macOS 26.0+ with Apple Intelligence enabled.
/// Uses native Tool protocol for structured tool calling.
@MainActor
final class FoundationModelService {
    let historyContext: String
    let userHome: String
    let userName: String
    let projectFolder: String

    private(set) var session: LanguageModelSession?

    /// Call to force a new session (e.g. after prompt changes).
    func resetSession() { session = nil }

    // MARK: - Enabled Tools

    /// Names of tools currently enabled for Apple Intelligence (shown in activity log).
    var enabledToolNames: [String] {
        let prefs = ToolPreferencesService.shared
        return AgentTools.tools(for: .foundationModel)
            .filter { prefs.isEnabled(.foundationModel, $0.name) }
            .map { $0.name }
    }

    // MARK: - Availability

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    static var unavailabilityReason: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return ""
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence is not enabled in System Settings."
            case .deviceNotEligible:
                return "This device is not eligible for Apple Intelligence."
            case .modelNotReady:
                return "Apple Intelligence model is downloading or not ready."
            @unknown default:
                return "Apple Intelligence is not available."
            }
        }
    }

    // MARK: - Init

    init(historyContext: String = "", projectFolder: String = "") {
        self.historyContext = historyContext
        self.userHome = FileManager.default.homeDirectoryForCurrentUser.path
        self.userName = NSUserName()
        self.projectFolder = projectFolder
    }

    // MARK: - Session

    private func ensureSession() -> LanguageModelSession {
        if let s = session { return s }

        let instructions = AgentTools.compactSystemPrompt(userName: userName, userHome: userHome)
        print("=== Apple AI System Prompt ===\n\(instructions)\n=== End (\(instructions.count) chars) ===")

        // Load one native tool — Foundation Models injects its schema automatically (no TOOLS: in prompt needed).
        let shellTool = NativeShellTool(projectFolder: projectFolder)
        let s = LanguageModelSession(model: .default, tools: [shellTool], instructions: Instructions(instructions))
        session = s
        return s
    }

    // MARK: - Send (non-streaming)

    func send(messages: [[String: Any]]) async throws -> (content: [[String: Any]], stopReason: String) {
        let s = ensureSession()
        let prompt = extractLastUserPrompt(from: messages)
        guard !prompt.isEmpty else {
            return ([["type": "text", "text": "(empty prompt)"]], "end_turn")
        }
        do {
            let response = try await s.respond(to: prompt)
            return parseResponse(response.content, session: s)
        } catch {
            self.session = nil
            let msg = error.localizedDescription.lowercased()
            if msg.contains("unsafe") || msg.contains("guardrail") || msg.contains("policy") || msg.contains("safety") {
                let notice = "Apple Intelligence blocked this request due to its built-in safety filters. Try using Claude or Ollama for script execution tasks."
                return ([["type": "text", "text": notice]], "end_turn")
            }
            throw error
        }
    }

    // MARK: - Streaming

    func sendStreaming(
        messages: [[String: Any]],
        onTextDelta: @escaping @Sendable (String) -> Void
    ) async throws -> (content: [[String: Any]], stopReason: String) {
        let s = ensureSession()
        let prompt = extractLastUserPrompt(from: messages)
        guard !prompt.isEmpty else {
            return ([["type": "text", "text": "(empty prompt)"]], "end_turn")
        }
        var fullText = ""
        do {
            for try await snapshot in s.streamResponse(to: prompt) {
                fullText = snapshot.content
            }
        } catch {
            self.session = nil
            // Check for safety/guardrail violation — surface a friendly message instead of an error
            let msg = error.localizedDescription.lowercased()
            if msg.contains("unsafe") || msg.contains("guardrail") || msg.contains("policy") || msg.contains("safety") {
                let notice = "Apple Intelligence blocked this request due to its built-in safety filters. Try using Claude or Ollama for script execution tasks."
                onTextDelta(notice)
                return ([["type": "text", "text": notice]], "end_turn")
            }
            throw error
        }
        // Parse first. If it's a tool call, emit any text written before it.
        let result = parseResponse(fullText, session: s)
        if result.stopReason == "tool_use" {
            let pre = textBeforeFirstToolCall(fullText)
            if !pre.isEmpty {
                onTextDelta(normalizeNewlines(pre) + "\n")
            } else if let toolUse = result.content.first,
                      toolUse["name"] as? String == "task_complete",
                      let input = toolUse["input"] as? [String: Any],
                      let summary = input["summary"] as? String, !summary.isEmpty {
                // Model wrote no text — surface the summary so the user sees a response
                onTextDelta(summary)
            }
        } else {
            onTextDelta(normalizeNewlines(fullText))
        }
        return result
    }

    // MARK: - Helpers

    /// Collapse two or more consecutive newlines into one to avoid double-spaced output.
    private func normalizeNewlines(_ text: String) -> String {
        // Replace 2+ newlines with a single newline
        let pattern = try? NSRegularExpression(pattern: "\\n{2,}")
        return pattern?.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "\n"
        ) ?? text
    }

    /// Prefix injected into every user message so Apple Intelligence sees the project folder
    /// immediately in context (system prompt alone is often ignored due to small context window).
    private var projectFolderPrefix: String {
        guard !projectFolder.isEmpty else { return "" }
        return "PROJECT FOLDER: \(projectFolder) — cd here before running any shell commands.\n\n"
    }

    /// Extract only the last user message — the session maintains prior turns internally.
    /// Tool results are formatted as plain text so the on-device model understands them.
    private func extractLastUserPrompt(from messages: [[String: Any]]) -> String {
        for msg in messages.reversed() {
            guard let role = msg["role"] as? String, role == "user" else { continue }
            if let text = msg["content"] as? String { return projectFolderPrefix + text }
            if let blocks = msg["content"] as? [[String: Any]] {
                let isToolResults = blocks.first?["type"] as? String == "tool_result"
                if isToolResults {
                    // Format tool results naturally — Foundation Models doesn't understand UUIDs
                    let output = blocks.compactMap { block -> String? in
                        block["content"] as? String
                    }.joined(separator: "\n")
                    return "The command output was:\n\(output)\n\nNow reply in English with this information, then call task_complete."
                }
                let text = blocks.compactMap { block -> String? in
                    guard block["type"] as? String == "text" else { return nil }
                    return block["text"] as? String
                }.joined(separator: "\n")
                return projectFolderPrefix + text
            }
        }
        return ""
    }

    /// Returns any text appearing before the first tool call (code block or text-format).
    private func textBeforeFirstToolCall(_ text: String) -> String {
        var earliest: String.Index? = nil
        // Check for code block marker
        if let r = text.range(of: "```") { earliest = r.lowerBound }
        // Check for text-format tool names (tool_name {)
        for toolName in AgentTools.toolNames {
            guard let r = text.range(of: toolName) else { continue }
            if earliest == nil || r.lowerBound < earliest! { earliest = r.lowerBound }
        }
        guard let idx = earliest else { return "" }
        return String(text[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse response from Foundation Models. Supports three output formats the model may use:
    /// 1. ```json\n{"tool_name": {params}}\n``` — JSON code block
    /// 2. {"tool_name": {params}}              — bare JSON object
    /// 3. tool_name {"param": value}           — plain text format
    private func parseResponse(_ text: String, session: LanguageModelSession) -> (content: [[String: Any]], stopReason: String) {
        // Format 1: ```json ... ``` code block
        let codeBlockPattern = "```(?:json)?\\s*\\n?([\\s\\S]*?)\\n?```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let jsonRange = Range(match.range(at: 1), in: text) {
            let jsonStr = String(text[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let result = parseWrappedJSON(jsonStr) { return result }
        }
        // Format 2: bare {"tool_name": {params}}
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), let result = parseWrappedJSON(trimmed) { return result }
        // Format 3: tool_name {"param": value}
        if let result = parseTextFormat(text) { return result }

        if text.isEmpty {
            return ([["type": "text", "text": "I'll continue with the task."]], "end_turn")
        }
        return ([["type": "text", "text": text]], "end_turn")
    }

    /// Parse {"tool_name": {params}} — the outer key is the tool name.
    private func parseWrappedJSON(_ json: String) -> (content: [[String: Any]], stopReason: String)? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj.count == 1,
              let toolName = obj.keys.first,
              AgentTools.toolNames.contains(toolName) else { return nil }
        let input = (obj[toolName] as? [String: Any]) ?? [:]
        return toolUseResult(name: toolName, input: input)
    }

    /// Parse plain text format: tool_name {"param": value, ...} or bare tool_name / tool_name.
    private func parseTextFormat(_ text: String) -> (content: [[String: Any]], stopReason: String)? {
        for toolName in AgentTools.toolNames {
            guard let nameRange = text.range(of: toolName) else { continue }
            let afterName = text[nameRange.upperBound...].trimmingCharacters(in: .whitespaces)
            if afterName.hasPrefix("{") {
                // Has JSON args — extract matching braces
                var depth = 0
                var end = afterName.startIndex
                for (i, ch) in afterName.enumerated() {
                    if ch == "{" { depth += 1 } else if ch == "}" { depth -= 1 }
                    if depth == 0 { end = afterName.index(afterName.startIndex, offsetBy: i); break }
                }
                let jsonStr = String(afterName[afterName.startIndex...end])
                if let data = jsonStr.data(using: .utf8),
                   let input = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return toolUseResult(name: toolName, input: input)
                }
            } else {
                // No JSON args (e.g. "task_complete." or "task_complete") — call with empty input
                let nextChar = afterName.first
                if nextChar == nil || nextChar == "." || nextChar == "\n" || nextChar == " " {
                    return toolUseResult(name: toolName, input: [:])
                }
            }
        }
        return nil
    }

    private func toolUseResult(name: String, input: [String: Any]) -> (content: [[String: Any]], stopReason: String) {
        ([["type": "tool_use", "id": UUID().uuidString, "name": name, "input": input]], "tool_use")
    }
}

// MARK: - Native Shell Tool

/// Arguments the model generates when calling execute_user_command.
@Generable
private struct ShellCommandArgs {
    @Guide(description: "The bash shell command to run as the current user")
    var command: String
}

/// Native Foundation Models tool: runs a shell command in-process.
/// Foundation Models injects its schema into the session automatically — no TOOLS: list needed in the prompt.
private struct NativeShellTool: Tool {
    typealias Arguments = ShellCommandArgs
    typealias Output = AgentToolOutput

    let name = "execute_user_command"
    let description = "Execute a bash shell command as the current user. Use for ls, pwd, git, file operations, etc."
    let projectFolder: String

    func call(arguments: ShellCommandArgs) async throws -> AgentToolOutput {
        var cmd = arguments.command
        if !projectFolder.isEmpty && !cmd.hasPrefix("cd ") {
            let escaped = projectFolder.replacingOccurrences(of: "'", with: "'\\''")
            cmd = "cd '\(escaped)' && \(cmd)"
        }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", cmd]
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let result = output.isEmpty ? "(no output, exit \(process.terminationStatus))" : output
        print("🔧 [Apple AI] $ \(arguments.command)\n\(result)")
        return AgentToolOutput(result: result)
    }
}
