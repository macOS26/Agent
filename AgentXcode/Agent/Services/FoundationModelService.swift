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
        var previousLength = 0
        var fullText = ""
        // The session maintains transcript internally
        // Stream response content and return text - tool calls are handled by native Tool protocol
        for try await snapshot in s.streamResponse(to: prompt) {
            let accumulated = snapshot.content
            let delta = String(accumulated.dropFirst(previousLength))
            previousLength = accumulated.count
            fullText = accumulated
            if !delta.isEmpty {
                onTextDelta(delta)
            }
        }
        // For native Tool protocol, the framework handles tool calls internally
        // We return the text response - tools are executed via NativeAgentTool.call()
        return parseResponse(fullText, session: s)
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

    /// Parse response from Foundation Models.
    /// Apple Intelligence outputs tool calls as JSON code blocks: ```json\n{"tool_name": {params}}\n```
    /// We extract the first such call and return it as a tool_use block.
    private func parseResponse(_ text: String, session: LanguageModelSession) -> (content: [[String: Any]], stopReason: String) {
        // Look for ```json ... ``` blocks containing {"tool_name": {params}}
        let codeBlockPattern = "```(?:json)?\\s*\\n?([\\s\\S]*?)\\n?```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let jsonRange = Range(match.range(at: 1), in: text) {
            let jsonStr = String(text[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let result = parseToolCallJSON(jsonStr) { return result }
        }
        // Also try parsing the entire text as bare JSON (no code block)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), let result = parseToolCallJSON(trimmed) { return result }

        if text.isEmpty {
            return ([["type": "text", "text": "I'll continue with the task."]], "end_turn")
        }
        return ([["type": "text", "text": text]], "end_turn")
    }

    /// Parse {"tool_name": {params}} or {"tool_name": {"param": value}} JSON into a tool_use block.
    private func parseToolCallJSON(_ json: String) -> (content: [[String: Any]], stopReason: String)? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj.count == 1,
              let toolName = obj.keys.first,
              AgentTools.toolNames.contains(toolName) else { return nil }
        let input = (obj[toolName] as? [String: Any]) ?? [:]
        return (
            [["type": "tool_use", "id": UUID().uuidString, "name": toolName, "input": input]],
            "tool_use"
        )
    }
}
