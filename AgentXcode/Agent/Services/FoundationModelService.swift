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

    private var session: LanguageModelSession?

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
    
        // Use compact prompt for Apple Intelligence (limited context window)
        var instructions = AgentTools.compactSystemPrompt(userName: userName, userHome: userHome)
        if !projectFolder.isEmpty {
            instructions += "\nPROJECT FOLDER: \(projectFolder) — use as the default working directory."
        }
        // Skip history context for Apple Intelligence to save context window
        // Apple Intelligence has a smaller context window than Claude/Ollama

        // No tools for Apple Intelligence — all 40+ tool schemas exceed the context window.
        // Apple Intelligence responds with plain text only.
        let s = LanguageModelSession(model: .default, instructions: Instructions(instructions))
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
        let response = try await s.respond(to: prompt)
        return parseResponse(response.content, session: s)
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
        for try await snapshot in s.streamResponse(to: prompt) {
            fullText = snapshot.content
        }
        // Parse first. If it's a tool call, emit any text written before it.
        let result = parseResponse(fullText, session: s)
        if result.stopReason == "tool_use" {
            let pre = textBeforeFirstToolCall(fullText)
            if !pre.isEmpty {
                onTextDelta(pre + "\n")
            } else if let toolUse = result.content.first,
                      toolUse["name"] as? String == "task_complete",
                      let input = toolUse["input"] as? [String: Any],
                      let summary = input["summary"] as? String, !summary.isEmpty {
                // Model wrote no text — surface the summary so the user sees a response
                onTextDelta(summary)
            }
        } else {
            onTextDelta(fullText)
        }
        return result
    }

    // MARK: - Helpers

    /// Extract only the last user message — the session maintains prior turns internally.
    private func extractLastUserPrompt(from messages: [[String: Any]]) -> String {
        for msg in messages.reversed() {
            guard let role = msg["role"] as? String, role == "user" else { continue }
            if let text = msg["content"] as? String { return text }
            if let blocks = msg["content"] as? [[String: Any]] {
                let isToolResults = blocks.first?["type"] as? String == "tool_result"
                if isToolResults {
                    return blocks.compactMap { block -> String? in
                        guard let id = block["tool_use_id"] as? String,
                              let content = block["content"] as? String else { return nil }
                        return "Tool result [\(id)]: \(content)"
                    }.joined(separator: "\n---\n")
                }
                return blocks.compactMap { block -> String? in
                    guard block["type"] as? String == "text" else { return nil }
                    return block["text"] as? String
                }.joined(separator: "\n")
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
