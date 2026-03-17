import FoundationModels
import Foundation

/// On-device language model provider using Apple's Foundation Models framework.
/// Requires macOS 26.0+ with Apple Intelligence enabled.
/// The session persists for the lifetime of a task so context accumulates across iterations.
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

        var instructions = AgentTools.systemPrompt(userName: userName, userHome: userHome)
        if !projectFolder.isEmpty {
            instructions += "\nPROJECT FOLDER: \(projectFolder) — use as the default working directory for commands and file operations."
        }
        if !historyContext.isEmpty {
            instructions += historyContext
        }
        instructions += """

TOOL USE FORMAT: When you need to call a tool, output the exact tool name followed immediately by a JSON object on the same line. One tool call per response. Do not wrap in markdown.
Example: execute_user_command {"command": "ls -la /tmp"}
"""
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
        return parseResponse(response.content)
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
        for try await snapshot in s.streamResponse(to: prompt) {
            let accumulated = snapshot.content
            let delta = String(accumulated.dropFirst(previousLength))
            previousLength = accumulated.count
            fullText = accumulated
            if !delta.isEmpty {
                onTextDelta(delta)
            }
        }
        return parseResponse(fullText)
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

    /// Parse a tool call embedded in plain text. Mirrors OllamaService text-based parsing.
    private func parseResponse(_ text: String) -> (content: [[String: Any]], stopReason: String) {
        let toolNames = [
            "read_file", "write_file", "edit_file", "list_files", "search_files",
            "git_status", "git_diff", "git_log", "git_commit", "git_diff_patch", "git_branch",
            "apple_event_query", "lookup_sdef", "run_applescript",
            "execute_user_command", "execute_command", "task_complete",
            "list_agent_scripts", "read_agent_script", "create_agent_script",
            "update_agent_script", "run_agent_script", "delete_agent_script",
            "xcode_build", "xcode_run", "xcode_list_projects",
            "xcode_select_project", "xcode_grant_permission"
        ]

        for toolName in toolNames {
            guard let nameRange = text.range(of: toolName) else { continue }
            let afterName = String(text[nameRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard afterName.hasPrefix("{") else { continue }
            guard let jsonEnd = findJSONObjectEnd(in: afterName) else { continue }
            let jsonStr = String(afterName[..<jsonEnd])
            guard let jsonData = jsonStr.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

            let beforeText = String(text[..<nameRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            var blocks: [[String: Any]] = []
            if !beforeText.isEmpty {
                blocks.append(["type": "text", "text": beforeText])
            }
            blocks.append([
                "type": "tool_use",
                "id": UUID().uuidString,
                "name": toolName,
                "input": parsed
            ])
            return (blocks, "tool_use")
        }

        if text.isEmpty {
            return ([["type": "text", "text": "I'll continue with the task."]], "end_turn")
        }
        return ([["type": "text", "text": text]], "end_turn")
    }

    /// Find the String.Index after the closing `}` of the outermost JSON object.
    private func findJSONObjectEnd(in text: String) -> String.Index? {
        var depth = 0
        var inString = false
        var escape = false
        for idx in text.indices {
            let c = text[idx]
            if escape { escape = false; continue }
            if c == "\\" && inString { escape = true; continue }
            if c == "\"" { inString.toggle(); continue }
            if !inString {
                if c == "{" { depth += 1 }
                else if c == "}" {
                    depth -= 1
                    if depth == 0 { return text.index(after: idx) }
                }
            }
        }
        return nil
    }
}
