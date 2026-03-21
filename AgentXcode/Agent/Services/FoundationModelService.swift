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
        var instructions = SystemPromptService.shared.prompt(for: .foundationModel, userName: userName, userHome: userHome)

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
            NativeAppleScriptTool(),
            NativeReadFileTool(),
            NativeWriteFileTool(),
            NativeEditFileTool(),
            NativeListFilesTool(),
            NativeSearchFilesTool(),
            NativeTaskCompleteTool(),
            NativeGitStatusTool(),
            NativeGitCommitTool(),
            NativeGitLogTool(),
            NativeGitDiffTool(),
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
    static let maxToolCalls = 5
    /// Handler that routes tool calls to real execution (set by ViewModel before task starts).
    nonisolated(unsafe) static var toolHandler: (@Sendable (String, sending [String: Any]) async -> String)?
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

// MARK: - Additional @Generable Arg Structs

@Generable
private struct AppleScriptArgs {
    @Guide(description: "AppleScript code")
    var source: String
}

@Generable
private struct OsaScriptArgs {
    @Guide(description: "AppleScript code")
    var script: String
}

@Generable
private struct ReadFileArgs {
    @Guide(description: "File path")
    var file_path: String
    @Guide(description: "Start line")
    var offset: Int?
    @Guide(description: "Max lines")
    var limit: Int?
}

@Generable
private struct WriteFileArgs {
    @Guide(description: "File path")
    var file_path: String
    @Guide(description: "File content")
    var content: String
}

@Generable
private struct EditFileArgs {
    @Guide(description: "File path")
    var file_path: String
    @Guide(description: "Text to find")
    var old_string: String
    @Guide(description: "Replacement")
    var new_string: String
    @Guide(description: "Replace all")
    var replace_all: Bool?
}

@Generable
private struct GlobArgs {
    @Guide(description: "Glob pattern")
    var pattern: String
    @Guide(description: "Directory")
    var path: String?
}

@Generable
private struct SearchArgs {
    @Guide(description: "Regex pattern")
    var pattern: String
    @Guide(description: "Directory")
    var path: String?
    @Guide(description: "File filter")
    var include: String?
}

@Generable
private struct TaskCompleteArgs {
    @Guide(description: "Summary")
    var summary: String
}

@Generable
private struct GitRepoArgs {
    @Guide(description: "Repo path")
    var path: String?
}

@Generable
private struct GitCommitArgs {
    @Guide(description: "Repo path")
    var path: String?
    @Guide(description: "Message")
    var message: String
}

@Generable
private struct GitLogArgs {
    @Guide(description: "Repo path")
    var path: String?
    @Guide(description: "Count")
    var count: Int?
}

@Generable
private struct GitDiffArgs {
    @Guide(description: "Repo path")
    var path: String?
    @Guide(description: "Staged only")
    var staged: Bool?
    @Guide(description: "Target branch")
    var target: String?
}

// MARK: - Additional Native Tool Implementations

private struct NativeAppleScriptTool: Tool {
    typealias Arguments = AppleScriptArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.runApplescript
    let description = "Run AppleScript. Example: display dialog \"Hello\""

    func call(arguments: AppleScriptArgs) async throws -> AgentToolOutput {
        let source = arguments.source.appleScriptSanitized
        let result = await MainActor.run { () -> String in
            var errorDict: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                return "Error: Could not create NSAppleScript"
            }
            let output = script.executeAndReturnError(&errorDict)
            if let err = errorDict { return "AppleScript error: \(err)" }
            return output.stringValue ?? "(no output)"
        }
        print("🔧 [Apple AI] run_applescript\n\(result)")
        return AgentToolOutput(result: result)
    }
}

private struct NativeOsaScriptTool: Tool {
    typealias Arguments = OsaScriptArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.runOsascript
    let description = "Run osascript. Example: say \"hello\""

    func call(arguments: OsaScriptArgs) async throws -> AgentToolOutput {
        let result = nativeShellRun("/usr/bin/osascript", args: ["-e", arguments.script.appleScriptSanitized])
        print("🔧 [Apple AI] run_osascript\n\(result)")
        return AgentToolOutput(result: result)
    }
}

@Generable
private struct JXAArgs {
    @Guide(description: "JavaScript for Automation source code")
    var source: String
}

private struct NativeJXATool: Tool {
    typealias Arguments = JXAArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.executeJavascript
    let description = "Run JavaScript for Automation (JXA). Example: var app = Application('Finder'); app.selection()"

    func call(arguments: JXAArgs) async throws -> AgentToolOutput {
        let result = nativeShellRun("/usr/bin/osascript", args: ["-l", "JavaScript", "-e", arguments.source])
        print("🔧 [Apple AI] execute_javascript\n\(result)")
        return AgentToolOutput(result: result)
    }
}

private struct NativeReadFileTool: Tool {
    typealias Arguments = ReadFileArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.readFile
    let description = "Read a file"

    func call(arguments: ReadFileArgs) async throws -> AgentToolOutput {
        guard let data = FileManager.default.contents(atPath: arguments.file_path),
              let content = String(data: data, encoding: .utf8) else {
            return AgentToolOutput(result: "Error: Could not read \(arguments.file_path)")
        }
        let lines = content.components(separatedBy: "\n")
        let start = max(0, (arguments.offset ?? 1) - 1)
        let end = min(start + (arguments.limit ?? 2000), lines.count)
        let numbered = lines[start..<end].enumerated()
            .map { "\($0.offset + start + 1)\t\($0.element)" }
        return AgentToolOutput(result: numbered.joined(separator: "\n"))
    }
}

private struct NativeWriteFileTool: Tool {
    typealias Arguments = WriteFileArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.writeFile
    let description = "Write a file"

    func call(arguments: WriteFileArgs) async throws -> AgentToolOutput {
        let url = URL(fileURLWithPath: arguments.file_path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        do {
            try arguments.content.write(to: url, atomically: true, encoding: .utf8)
            return AgentToolOutput(result: "Wrote \(arguments.content.components(separatedBy: "\n").count) lines to \(arguments.file_path)")
        } catch {
            return AgentToolOutput(result: "Error: \(error.localizedDescription)")
        }
    }
}

private struct NativeEditFileTool: Tool {
    typealias Arguments = EditFileArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.editFile
    let description = "Edit a file"

    func call(arguments: EditFileArgs) async throws -> AgentToolOutput {
        guard let data = FileManager.default.contents(atPath: arguments.file_path),
              let content = String(data: data, encoding: .utf8) else {
            return AgentToolOutput(result: "Error: Could not read \(arguments.file_path)")
        }
        
        let oldString = arguments.old_string
        let newString = arguments.new_string
        
        // Check for identical strings
        guard oldString != newString else {
            return AgentToolOutput(result: "Error: old_string and new_string are identical - no changes needed")
        }
        
        // Count occurrences
        let occurrences = content.components(separatedBy: oldString).count - 1
        
        // Check if old_string exists
        if occurrences == 0 {
            // Try to give a helpful hint about whitespace differences
            let trimmed = oldString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && content.contains(trimmed) {
                return AgentToolOutput(result: "Error: old_string not found (exact match). A similar string exists in \(arguments.file_path) — check whitespace/indentation differences.")
            }
            return AgentToolOutput(result: "Error: old_string not found in \(arguments.file_path)")
        }
        
        // Check for multiple occurrences when replace_all not set
        if arguments.replace_all != true && occurrences > 1 {
            return AgentToolOutput(result: "Error: old_string appears \(occurrences) times in \(arguments.file_path). Provide more context to make it unique, or set replace_all=true.")
        }
        
        let newContent: String
        if arguments.replace_all == true {
            newContent = content.replacingOccurrences(of: oldString, with: newString)
        } else {
            guard let range = content.range(of: oldString) else {
                return AgentToolOutput(result: "Error: old_string not found in \(arguments.file_path)")
            }
            newContent = content.replacingCharacters(in: range, with: newString)
        }
        do {
            try newContent.write(to: URL(fileURLWithPath: arguments.file_path), atomically: true, encoding: .utf8)
            let label = arguments.replace_all == true ? "\(occurrences) occurrences" : "1 occurrence"
            return AgentToolOutput(result: "Replaced \(label) in \(arguments.file_path)")
        } catch {
            return AgentToolOutput(result: "Error: \(error.localizedDescription)")
        }
    }
}

private struct NativeListFilesTool: Tool {
    typealias Arguments = GlobArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.listFiles
    let description = "Find files by pattern"

    func call(arguments: GlobArgs) async throws -> AgentToolOutput {
        let pf = await NativeToolContext.projectFolder
        let base = arguments.path ?? pf
        let dir = base.isEmpty ? FileManager.default.homeDirectoryForCurrentUser.path : base
        let esc = dir.shellEscaped
        let pat = arguments.pattern.shellEscaped
        let cmd = "find \(esc) -name \(pat) ! -path '*/.build/*' ! -path '*/.git/*' 2>/dev/null | sort | head -100"
        return AgentToolOutput(result: nativeShellRun(cmd))
    }
}

private struct NativeSearchFilesTool: Tool {
    typealias Arguments = SearchArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.searchFiles
    let description = "Search file contents"

    func call(arguments: SearchArgs) async throws -> AgentToolOutput {
        let pf = await NativeToolContext.projectFolder
        let base = arguments.path ?? pf
        let dir = base.isEmpty ? FileManager.default.homeDirectoryForCurrentUser.path : base
        let esc = dir.shellEscaped
        let pat = arguments.pattern.shellEscaped
        var cmd = "grep -rn \(pat) \(esc)"
        if let include = arguments.include { cmd += " --include=\(include.shellEscaped)" }
        cmd += " 2>/dev/null | head -50"
        return AgentToolOutput(result: nativeShellRun(cmd))
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

private struct NativeGitStatusTool: Tool {
    typealias Arguments = GitRepoArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.gitStatus
    let description = "Git status"

    func call(arguments: GitRepoArgs) async throws -> AgentToolOutput {
        let pf = await NativeToolContext.projectFolder
        let dir = (arguments.path ?? pf).orProjectFolder(pf)
        return AgentToolOutput(result: nativeShellRun("cd \(dir.shellEscaped) && git status"))
    }
}

private struct NativeGitCommitTool: Tool {
    typealias Arguments = GitCommitArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.gitCommit
    let description = "Git commit"

    func call(arguments: GitCommitArgs) async throws -> AgentToolOutput {
        let pf = await NativeToolContext.projectFolder
        let dir = (arguments.path ?? pf).orProjectFolder(pf)
        let msg = arguments.message.shellEscaped
        return AgentToolOutput(result: nativeShellRun("cd \(dir.shellEscaped) && git add -A && git commit -m \(msg)"))
    }
}

private struct NativeGitLogTool: Tool {
    typealias Arguments = GitLogArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.gitLog
    let description = "Git log"

    func call(arguments: GitLogArgs) async throws -> AgentToolOutput {
        let pf = await NativeToolContext.projectFolder
        let dir = (arguments.path ?? pf).orProjectFolder(pf)
        let n = arguments.count ?? 20
        return AgentToolOutput(result: nativeShellRun("cd \(dir.shellEscaped) && git log --oneline -\(n)"))
    }
}

private struct NativeGitDiffTool: Tool {
    typealias Arguments = GitDiffArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.gitDiff
    let description = "Git diff"

    func call(arguments: GitDiffArgs) async throws -> AgentToolOutput {
        let pf = await NativeToolContext.projectFolder
        let dir = (arguments.path ?? pf).orProjectFolder(pf)
        var cmd = "cd \(dir.shellEscaped) && git diff"
        if arguments.staged == true { cmd += " --staged" }
        if let target = arguments.target { cmd += " \(target)" }
        return AgentToolOutput(result: nativeShellRun(cmd))
    }
}

@Generable
private struct NoArgs {}

private struct NativeListNativeToolsTool: Tool {
    typealias Arguments = NoArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.listNativeTools
    let description = "List all enabled native tools."

    func call(arguments: NoArgs) async throws -> AgentToolOutput {
        let lines: [String] = await MainActor.run {
            let prefs = ToolPreferencesService.shared
            return AgentTools.tools(for: .foundationModel)
                .filter { prefs.isEnabled(.foundationModel, $0.name) }
                .sorted(by: { $0.name < $1.name })
                .map { $0.name }
        }
        return AgentToolOutput(result: lines.joined(separator: "\n"))
    }
}

private struct NativeListMCPToolsTool: Tool {
    typealias Arguments = NoArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.listMcpTools
    let description = "List all enabled MCP tools."

    func call(arguments: NoArgs) async throws -> AgentToolOutput {
        let result: String = await MainActor.run {
            let mcpService = MCPService.shared
            let enabled = mcpService.discoveredTools
                .filter { mcpService.isToolEnabled(serverName: $0.serverName, toolName: $0.name) }
                .sorted(by: { $0.name < $1.name })
            if enabled.isEmpty {
                return "No MCP tools enabled."
            }
            return enabled.map { "mcp_\($0.serverName)_\($0.name)" }.joined(separator: "\n")
        }
        return AgentToolOutput(result: result)
    }
}

// MARK: - Saved AppleScript Tools

@Generable
private struct AppleScriptNameArgs {
    @Guide(description: "Script name")
    var name: String
}

@Generable
private struct SaveAppleScriptArgs {
    @Guide(description: "Script name")
    var name: String
    @Guide(description: "AppleScript source")
    var source: String
}

private struct NativeListAppleScriptsTool: Tool {
    typealias Arguments = NoArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.listAppleScripts
    let description = "List saved AppleScripts"

    func call(arguments: NoArgs) async throws -> AgentToolOutput {
        let result: String = await MainActor.run {
            let scripts = ScriptService().listAppleScripts()
            return scripts.isEmpty ? "No saved AppleScripts" : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
        }
        return AgentToolOutput(result: result)
    }
}

private struct NativeRunAppleScriptTool: Tool {
    typealias Arguments = AppleScriptNameArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.runAppleScript
    let description = "Run a saved AppleScript by name"

    func call(arguments: AppleScriptNameArgs) async throws -> AgentToolOutput {
        let result: String = await MainActor.run {
            guard let source = ScriptService().readAppleScript(name: arguments.name) else {
                return "Error: '\(arguments.name)' not found. Use list_apple_scripts first."
            }
            var err: NSDictionary?
            guard let script = NSAppleScript(source: source) else { return "Error creating script" }
            let out = script.executeAndReturnError(&err)
            if let e = err { return "AppleScript error: \(e)" }
            return out.stringValue ?? "(no output)"
        }
        return AgentToolOutput(result: result)
    }
}

private struct NativeSaveAppleScriptTool: Tool {
    typealias Arguments = SaveAppleScriptArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.saveAppleScript
    let description = "Save an AppleScript for reuse"

    func call(arguments: SaveAppleScriptArgs) async throws -> AgentToolOutput {
        let result: String = await MainActor.run {
            ScriptService().saveAppleScript(name: arguments.name, source: arguments.source)
        }
        return AgentToolOutput(result: result)
    }
}

private struct NativeDeleteAppleScriptTool: Tool {
    typealias Arguments = AppleScriptNameArgs
    typealias Output = AgentToolOutput

    let name = AgentTools.Name.deleteAppleScript
    let description = "Delete a saved AppleScript"

    func call(arguments: AppleScriptNameArgs) async throws -> AgentToolOutput {
        let result: String = await MainActor.run {
            ScriptService().deleteAppleScript(name: arguments.name)
        }
        return AgentToolOutput(result: result)
    }
}

// MARK: - Shell helpers

/// Run a bash command string, returning combined stdout+stderr.
private func nativeShellRun(_ cmd: String) -> String {
    let p = Process()
    let pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: "/bin/bash")
    p.arguments = ["-c", cmd]
    p.standardOutput = pipe
    p.standardError = pipe
    try? p.run()
    p.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return out.isEmpty ? "(no output, exit \(p.terminationStatus))" : out
}

/// Run a specific executable with arguments, returning combined stdout+stderr.
private func nativeShellRun(_ exe: String, args: [String]) -> String {
    let p = Process()
    let pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: exe)
    p.arguments = args
    p.standardOutput = pipe
    p.standardError = pipe
    try? p.run()
    p.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return out.isEmpty ? "(no output, exit \(p.terminationStatus))" : out
}

private extension String {
    /// Single-quote shell escape: wraps the string in single quotes, escaping any embedded single quotes.
    var shellEscaped: String { "'\(replacingOccurrences(of: "'", with: "'\\''"))'" }

    /// Returns self if non-empty, otherwise returns the given fallback.
    func orProjectFolder(_ fallback: String) -> String { isEmpty ? fallback : self }

    /// Replace Unicode smart/curly quotes and apostrophes with plain ASCII equivalents.
    /// Apple Intelligence often generates these in code strings, which break NSAppleScript / osascript / bash.
    var asciiQuotes: String {
        self
            .replacingOccurrences(of: "\u{201C}", with: "\"")  // " LEFT DOUBLE QUOTATION MARK
            .replacingOccurrences(of: "\u{201D}", with: "\"")  // " RIGHT DOUBLE QUOTATION MARK
            .replacingOccurrences(of: "\u{2018}", with: "'")   // ' LEFT SINGLE QUOTATION MARK
            .replacingOccurrences(of: "\u{2019}", with: "'")   // ' RIGHT SINGLE QUOTATION MARK
            .replacingOccurrences(of: "\u{2032}", with: "'")   // ′ PRIME (sometimes used as apostrophe)
    }

    /// Sanitize a string for use as AppleScript source.
    /// Fixes smart quotes AND removes backslash-escaping that the model adds (\" → ").
    /// AppleScript uses raw unquoted " for string literals — backslash escapes are invalid syntax.
    var appleScriptSanitized: String {
        asciiQuotes
            .replacingOccurrences(of: "\\\"", with: "\"")  // \" → "  (model over-escapes quotes)
            .replacingOccurrences(of: "\\'", with: "'")     // \' → '
    }
}
