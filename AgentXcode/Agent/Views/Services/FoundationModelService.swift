import FoundationModels
import Foundation

/// On-device language model provider using Apple's Foundation Models framework.
/// 
/// This service provides Apple Intelligence for LoRA adapter training. Apple Intelligence
/// captures response patterns that can be exported as JSONL training data, then used to
/// create .fmadapter files that enhance other LLM providers.
///
/// Note: Apple Intelligence is NOT directly selectable as a task-execution LLM due to
/// its limited context window. Instead:
/// 1. Use Claude/Ollama/etc. for actual task execution
/// 2. Use Apple Intelligence for LoRA training data generation
/// 3. Apply trained adapters to enhance responses from other providers
///
/// Requires macOS 26.0+ with Apple Intelligence enabled.
@MainActor
final class FoundationModelService {
    let historyContext: String
    let userHome: String
    let userName: String
    let projectFolder: String

    private(set) var session: LanguageModelSession?

    /// Timeout for Apple Intelligence calls (seconds). Short timeout to skip quickly if unavailable.
    private static let responseTimeout: TimeInterval = 5

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
        // Always create a fresh session — the on-device model's small context
        // gets polluted by prior turns, causing it to skip tools.
        NativeToolContext.projectFolder = projectFolder
        var instructions = SystemPromptService.shared.prompt(for: .foundationModel, userName: userName, userHome: userHome, projectFolder: projectFolder)

        // Note active LoRA adapter in instructions
        let lora = LoRAAdapterManager.shared
        if lora.isLoaded {
            instructions += "\n[LoRA adapter '\(lora.adapterName)' is active]"
        }

        print("=== Apple AI System Prompt ===\n\(instructions)\n=== End (\(instructions.count) chars) ===")

        let tools = makeEnabledNativeTools()
        // The adapter asset is ready for when Apple's session API supports the adapter: parameter.
        let s = LanguageModelSession(model: .default, tools: tools, instructions: Instructions(instructions))
        session = s
        return s
    }

    /// All properly-typed native tools keyed by name.
    /// Uses @Generable argument structs so the on-device model understands the schemas.
    /// Core tools only — Apple AI's tiny context can't handle many tools.
    /// Keep this list small for reliable tool calling.
    private static let allNativeTools: [String: any Tool] = {
        let tools: [any Tool] = [
            NativeShellTool(),
            NativeTaskCompleteTool(),
        ]
        return Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
    }()

    @MainActor
    private func makeEnabledNativeTools() -> [any Tool] {
        let prefs = ToolPreferencesService.shared
        let enabledDefs = AgentTools.tools(for: .foundationModel)
            .filter { prefs.isEnabled(.foundationModel, $0.name) }
        var tools: [any Tool] = []
        for def in enabledDefs {
            if let native = Self.allNativeTools[def.name] {
                // Prefer properly-typed @Generable tool
                tools.append(native)
            } else {
                // Fall back to dynamic wrapper for tools without native impl
                tools.append(NativeAgentTool(toolDef: def))
            }
        }
        print("🔧 [Apple AI] Loaded \(tools.count) native tools: \(tools.map { $0.name }.sorted().joined(separator: ", "))")
        return tools
    }

    // MARK: - Send (non-streaming)

    func send(messages: [[String: Any]]) async throws -> (content: [[String: Any]], stopReason: String) {
        let s = ensureSession()
        let prompt = extractLastUserPrompt(from: messages)
        guard !prompt.isEmpty else {
            return ([["type": "text", "text": "(empty prompt)"]], "end_turn")
        }
        
        // Use timeout wrapper to prevent hanging
        do {
            let content: String = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    let response = try await s.respond(to: prompt)
                    return response.content
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(Self.responseTimeout))
                    throw CancellationError()
                }
                guard let result = try await group.next() else {
                    throw CancellationError()
                }
                group.cancelAll()
                return result
            }
            return parseResponse(content, session: s)
        } catch {
            self.session = nil
            let msg = error.localizedDescription.lowercased()
            // Timeout — skip Apple Intelligence
            if error is CancellationError {
                print("🔧 [Apple AI] Timed out after \(Self.responseTimeout)s — skipping")
                return ([["type": "text", "text": "Apple Intelligence timed out. Please try again."]], "end_turn")
            }
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

        // Use timeout wrapper to prevent hanging
        do {
            fullText = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    var latest = ""
                    for try await snapshot in s.streamResponse(to: prompt) {
                        latest = snapshot.content
                    }
                    return latest
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(Self.responseTimeout))
                    throw CancellationError()
                }
                guard let result = try await group.next() else {
                    throw CancellationError()
                }
                group.cancelAll()
                return result
            }
        } catch {
            self.session = nil
            let msg = error.localizedDescription.lowercased()
            // Timeout — skip Apple Intelligence
            if error is CancellationError {
                print("🔧 [Apple AI] Timed out after \(Self.responseTimeout)s — skipping")
                onTextDelta("Apple Intelligence timed out. Please try again.")
                return ([["type": "text", "text": "Apple Intelligence timed out. Please try again."]], "end_turn")
            }
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
            } else {
                // Blank response with tool call — provide fallback message
                onTextDelta("Processing your request...")
            }
        } else if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Blank response — provide fallback to avoid empty messages
            onTextDelta("I'll continue with the task.")
        } else {
            onTextDelta(normalizeNewlines(fullText))
        }
        return result
    }

    // MARK: - Helpers

    /// Fix newlines: convert literal \n to real newlines, then collapse 2+ into one.
    private func normalizeNewlines(_ text: String) -> String {
        // Apple AI often writes literal \n instead of actual newlines
        var fixed = text.replacingOccurrences(of: "\\n", with: "\n")
        // Also fix literal \t
        fixed = fixed.replacingOccurrences(of: "\\t", with: "\t")
        // Collapse 2+ newlines into one
        let pattern = try? NSRegularExpression(pattern: "\\n{2,}")
        return pattern?.stringByReplacingMatches(
            in: fixed, range: NSRange(fixed.startIndex..., in: fixed), withTemplate: "\n"
        ) ?? fixed
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
            } else if afterName.hasPrefix("(") {
                // Python-style kwargs: task_complete(summary="Done")
                if let closeIdx = afterName.firstIndex(of: ")") {
                    let inner = afterName[afterName.index(after: afterName.startIndex)..<closeIdx]
                    var input: [String: Any] = [:]
                    for part in inner.split(separator: ",") {
                        let kv = part.split(separator: "=", maxSplits: 1)
                        if kv.count == 2 {
                            let key = kv[0].trimmingCharacters(in: .whitespaces)
                            var val = kv[1].trimmingCharacters(in: .whitespaces)
                            // Strip quotes
                            if (val.hasPrefix("\"") && val.hasSuffix("\"")) ||
                               (val.hasPrefix("'") && val.hasSuffix("'")) {
                                val = String(val.dropFirst().dropLast())
                            }
                            input[key] = val
                        }
                    }
                    return toolUseResult(name: toolName, input: input)
                }
            } else {
                // No args (e.g. "task_complete." or "task_complete") — call with empty input
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

// MARK: - Shared State for Native Tools

/// Shared state for native Foundation Models tools.
enum NativeToolContext {
    @MainActor static var projectFolder: String = ""
    /// Set when task_complete is called via native tool — the task loop checks this after each iteration.
    @MainActor static var taskCompleteSummary: String?
    /// Last tool output — so task_complete can include it if the model just says "Done".
    @MainActor static var lastToolOutput: String = ""
    /// Counts tool calls per session turn to prevent infinite loops.
    @MainActor static var toolCallCount = 0
    /// Max tool calls before forcing task_complete.
    static let maxToolCalls = 50
    /// Handler that routes tool calls to real execution (set by ViewModel before task starts).
    nonisolated(unsafe) static var toolHandler: (@Sendable (String, sending [String: Any]) async -> String)?
    /// Apple AI is a translator/mediator — skip all tool execution.
    @MainActor static var mediatorMode = true
}

// MARK: - Native Shell Tool

/// Arguments the model generates when calling execute_agent_command.
@Generable
private struct ShellCommandArgs {
    @Guide(description: "Shell command")
    var command: String
}

/// Native Foundation Models tool: runs a shell command in-process.
/// Foundation Models injects its schema into the session automatically — no TOOLS: list needed in the prompt.
private struct NativeShellTool: Tool {
    typealias Arguments = ShellCommandArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.executeAgentCommand
    let description = "Run a shell command"

    func call(arguments: ShellCommandArgs) async throws -> AgentToolOutput {
        var cmd = arguments.command.asciiQuotes
        let pf = await NativeToolContext.projectFolder
        if !pf.isEmpty && !cmd.hasPrefix("cd ") {
            let escaped = pf.replacingOccurrences(of: "'", with: "'\\''")
            cmd = "cd '\(escaped)' && \(cmd)"
        }
        let result = nativeShellRun(cmd)
        print("🔧 [Apple AI] $ \(arguments.command)\n\(result)")
        await MainActor.run { NativeToolContext.lastToolOutput = "$ \(arguments.command)\n\(result)" }
        return AgentToolOutput(result: result)
    }
}

private struct NativeTaskCompleteTool: Tool {
    typealias Arguments = TaskCompleteArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.taskComplete
    let description = "Mark task done"

    func call(arguments: TaskCompleteArgs) async throws -> AgentToolOutput {
        await MainActor.run {
            let lastOutput = NativeToolContext.lastToolOutput
            if !lastOutput.isEmpty && (arguments.summary == "Done" || arguments.summary.count < 10) {
                // Model gave a lazy summary — include the actual tool output
                NativeToolContext.taskCompleteSummary = lastOutput
            } else {
                NativeToolContext.taskCompleteSummary = arguments.summary
            }
            NativeToolContext.lastToolOutput = ""
        }
        return AgentToolOutput(result: "Task complete: \(arguments.summary)")
    }
}







// Shell helpers moved to FoundationModelHelpers.swift
