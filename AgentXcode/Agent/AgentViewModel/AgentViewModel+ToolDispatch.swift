import Foundation
import AgentTools

/// Context passed to every tool handler during task execution.
struct ToolContext {
    let toolId: String
    let projectFolder: String
    let selectedProvider: APIProvider
    let tavilyAPIKey: String
}

/// Result from a tool handler.
enum ToolHandlerResult {
    /// Tool was handled, append this content to toolResults.
    case handled(String)
    /// Tool was handled, result already appended to toolResults (for handlers that need custom format).
    case alreadyAppended
    /// Tool was not recognized by this handler.
    case notHandled
    /// Task is complete, stop execution.
    case taskComplete(String)
}

/// Tool handler function type — takes name, input, context; returns result.
typealias ToolHandler = @MainActor (AgentViewModel, String, [String: Any], ToolContext) async -> ToolHandlerResult

// MARK: - Tool Dispatch Table

extension AgentViewModel {

    /// The dispatch table — maps tool names to handler functions.
    /// Built once lazily via `buildDispatchTable()`. Extensions can register additional handlers.
    @MainActor static var toolDispatchTable: [String: ToolHandler] = buildDispatchTable()

    /// Build the base dispatch table. Called once.
    @MainActor private static func buildDispatchTable() -> [String: ToolHandler] {
        var table: [String: ToolHandler] = [:]

        // Process-based tools
        table["list_files"] = handleListFiles
        table["search_files"] = handleSearchFiles
        table["read_dir"] = handleReadDir
        table["if_to_switch"] = handleIfToSwitch
        table["extract_function"] = handleExtractFunction

        // Plan & project tools — delegate to executeNativeTool
        for name in ["plan_mode", "project_folder", "coding_mode", "mode", "list_tools", "conversation", "send_message", "memory"] {
            table[name] = handleNativeTool
        }

        // Web search
        table["web_search"] = handleWebSearch

        return table
    }

    /// Register a tool handler at runtime.
    @MainActor static func registerToolHandler(_ name: String, handler: @escaping ToolHandler) {
        toolDispatchTable[name] = handler
    }

    /// Read-only tools safe for parallel execution — no filesystem writes, no UI actions, no state changes.
    static let readOnlyTools: Set<String> = [
        // File reading
        "read_file", "list_files", "search_files", "read_dir",
        // Git reading
        "git_status", "git_diff", "git_log", "git_diff_patch",
        // Accessibility reading
        "ax_list_windows", "ax_get_properties", "ax_find_element", "ax_get_children",
        "ax_get_focused_element", "ax_read_focused", "ax_get_window_frame", "ax_get_audit_log",
        "ax_inspect_element", "ax_open_app", "ax_screenshot",
        // Xcode reading
        "xcode_list_projects",
        // Other read-only
        "list_tools", "web_search", "google_search", "list_agents", "read_agent", "lookup_sdef",
    ]

    /// Pre-computed results from parallel shell execution. Cleared after use.
    @MainActor static var precomputedResults: [String: String]?

    /// Build a shell command for a read-only tool (runs off MainActor).
    nonisolated static func buildReadOnlyCommand(name: String, input: [String: Any], projectFolder: String) -> String {
        let pf = projectFolder.isEmpty ? NSHomeDirectory() : projectFolder
        switch name {
        case "read_file":
            let path = input["file_path"] as? String ?? ""
            guard !path.isEmpty else { return "" }
            return "cat \(Self.shellEscape(path))"
        case "list_files":
            let pattern = input["pattern"] as? String ?? "*"
            let path = input["path"] as? String ?? pf
            return "find \(Self.shellEscape(path)) -maxdepth 5 -name \(Self.shellEscape(pattern)) -not -path '*/.*' 2>/dev/null | head -200"
        case "search_files":
            let pattern = input["pattern"] as? String ?? ""
            let path = input["path"] as? String ?? pf
            guard !pattern.isEmpty else { return "" }
            return "grep -rn \(Self.shellEscape(pattern)) \(Self.shellEscape(path)) --include='*.swift' --include='*.py' --include='*.js' --include='*.ts' 2>/dev/null | head -100"
        case "read_dir":
            let path = input["path"] as? String ?? pf
            return "ls -la \(Self.shellEscape(path)) 2>/dev/null"
        case "git_status":
            return "git status --short 2>/dev/null"
        case "git_diff":
            return "git diff 2>/dev/null | head -500"
        case "git_log":
            let count = input["count"] as? Int ?? 10
            return "git log --oneline -\(count) 2>/dev/null"
        case "git_diff_patch":
            return "git diff 2>/dev/null"
        default:
            return ""
        }
    }

    nonisolated private static func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Cache for read-only tool results within a task. Cleared on new task.
    @MainActor static var toolResultCache: [String: String] = [:]

    /// Clear tool result cache — call at start of each task.
    @MainActor static func clearToolCache() {
        toolResultCache.removeAll()
    }

    /// Build cache key from tool name + input.
    private static func cacheKey(name: String, input: [String: Any]) -> String {
        let inputStr = (try? JSONSerialization.data(withJSONObject: input, options: .sortedKeys)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return "\(name):\(inputStr)"
    }

    /// Dispatch a tool call by name. Returns the handler result.
    func dispatchTool(
        name: String,
        input rawInput: [String: Any],
        ctx: ToolContext,
        toolResults: inout [[String: Any]]
    ) async -> ToolHandlerResult {
        // Normalize empty path/file_path to nil so handlers fall back to project folder
        var input = rawInput
        if let p = input["path"] as? String, p.isEmpty { input["path"] = nil }
        if let p = input["file_path"] as? String, p.isEmpty { input["file_path"] = nil }

        // Cache hit for read-only tools — return cached result instantly
        if Self.readOnlyTools.contains(name) {
            let key = Self.cacheKey(name: name, input: input)
            if let cached = Self.toolResultCache[key] {
                appendLog("(cached)")
                toolResults.append(["type": "tool_result", "tool_use_id": ctx.toolId, "content": cached])
                return .handled(cached)
            }
        }

        // MCP tools (mcp_ServerName_toolName) — checked first by prefix
        if name.hasPrefix("mcp_") {
            if await handleMCPTool(
                name: name, input: input, toolId: ctx.toolId,
                appendLog: { @MainActor [weak self] msg in self?.appendLog(msg) },
                flushLog: { @MainActor [weak self] in self?.flushLog() },
                toolResults: &toolResults
            ) {
                return .alreadyAppended
            }
        }

        // Pure file I/O tools (consolidated handler)
        if await handleFileTool(
            name: name, input: input, toolId: ctx.toolId,
            appendLog: { [weak self] msg in Task { @MainActor in self?.appendLog(msg) } },
            appendRawOutput: { [weak self] msg in Task { @MainActor in self?.appendLog(msg) } },
            toolResults: &toolResults
        ) {
            return .alreadyAppended
        }

        // Web tools — checked by prefix
        if name.hasPrefix("web_") || name == "web" {
            let webResult = await handleMainWebTool(name: name, input: input)
            appendLog(String(webResult.prefix(500)))
            flushLog()
            toolResults.append(["type": "tool_result", "tool_use_id": ctx.toolId, "content": webResult])
            return .alreadyAppended
        }

        // Dictionary lookup — O(1)
        if let handler = Self.toolDispatchTable[name] {
            let result = await handler(self, name, input, ctx)
            switch result {
            case .handled(let output):
                toolResults.append(["type": "tool_result", "tool_use_id": ctx.toolId, "content": output])
            case .alreadyAppended, .taskComplete, .notHandled:
                break
            }
            return result
        }

        // Fallback: route through executeNativeTool
        let output = await executeNativeTool(name, input: input)
        appendLog(output)
        flushLog()
        toolResults.append(["type": "tool_result", "tool_use_id": ctx.toolId, "content": output])

        // Cache read-only tool results for reuse within this task
        if Self.readOnlyTools.contains(name) {
            let key = Self.cacheKey(name: name, input: input)
            Self.toolResultCache[key] = output
        }

        return .handled(output)
    }

    // MARK: - Handler Implementations

    private static func handleNativeTool(_ vm: AgentViewModel, _ name: String, _ input: [String: Any], _ ctx: ToolContext) async -> ToolHandlerResult {
        let output = await vm.executeNativeTool(name, input: input)
        vm.appendLog(output); vm.flushLog()
        return .handled(output)
    }

    private static func handleListFiles(_ vm: AgentViewModel, _ name: String, _ input: [String: Any], _ ctx: ToolContext) async -> ToolHandlerResult {
        let pattern = input["pattern"] as? String ?? "*"
        let path = input["path"] as? String
        if let pathErr = Self.checkPath(path) { vm.appendLog(pathErr); return .handled(pathErr) }
        let resolvedPath = path ?? ctx.projectFolder
        let displayPath = CodingService.trimHome(resolvedPath)
        vm.appendLog("🔍 $ find \(displayPath) -name '\(pattern)'"); vm.flushLog()
        let cmd = CodingService.buildListFilesCommand(pattern: pattern, path: path)
        let result = await vm.executeViaUserAgent(command: cmd, workingDirectory: resolvedPath, silent: true)
        guard !Task.isCancelled else { return .handled("cancelled") }
        let raw = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatted = raw.isEmpty ? "No files matching '\(pattern)'" : CodingService.formatFileTree(raw)
        vm.appendLog(formatted); vm.flushLog()
        return .handled(raw.isEmpty ? formatted : "[project folder: \(displayPath)] paths are relative to project folder\n\(formatted)")
    }

    private static func handleSearchFiles(_ vm: AgentViewModel, _ name: String, _ input: [String: Any], _ ctx: ToolContext) async -> ToolHandlerResult {
        let pattern = input["pattern"] as? String ?? ""
        let path = input["path"] as? String
        let include = input["include"] as? String
        if let pathErr = Self.checkPath(path) { vm.appendLog(pathErr); return .handled(pathErr) }
        let resolvedSearch = path ?? ctx.projectFolder
        let displaySearch = CodingService.trimHome(resolvedSearch)
        vm.appendLog("🔍 $ grep -rn '\(pattern)' \(displaySearch)\(include.map { " --include=\($0)" } ?? "")"); vm.flushLog()
        let cmd = CodingService.buildSearchFilesCommand(pattern: pattern, path: path, include: include)
        let result = await vm.executeViaUserAgent(command: cmd)
        guard !Task.isCancelled else { return .handled("cancelled") }
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No matches for '\(pattern)'" : "[project folder: \(displaySearch)] paths are relative to project folder\n\(result.output)"
        return .handled(output)
    }

    private static func handleReadDir(_ vm: AgentViewModel, _ name: String, _ input: [String: Any], _ ctx: ToolContext) async -> ToolHandlerResult {
        let path = input["path"] as? String ?? ctx.projectFolder
        if let pathErr = Self.checkPath(path) { vm.appendLog(pathErr); return .handled(pathErr) }
        let displayPath = CodingService.trimHome(path)
        let detail = (input["detail"] as? String ?? "slim") == "more"
        vm.appendLog("📂 \(displayPath)"); vm.flushLog()
        let cmd = detail ? "ls -la . 2>/dev/null" : "find . -maxdepth 1 -not -name '.*' 2>/dev/null | sed 's|^\\./||' | sort"
        let result = await vm.executeViaUserAgent(command: cmd, workingDirectory: path, silent: !detail)
        guard !Task.isCancelled else { return .handled("cancelled") }
        let raw = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return .handled(raw.isEmpty ? "Directory not found or empty" : "[project folder: \(displayPath)]\n\(raw)")
    }

    private static func handleIfToSwitch(_ vm: AgentViewModel, _ name: String, _ input: [String: Any], _ ctx: ToolContext) async -> ToolHandlerResult {
        let filePath = input["file_path"] as? String ?? ""
        vm.appendLog("🔄 if→switch: \(filePath)")
        let output = await Self.offMain { CodingService.convertIfToSwitch(path: filePath) }
        vm.appendLog(output)
        return .handled(output)
    }

    private static func handleExtractFunction(_ vm: AgentViewModel, _ name: String, _ input: [String: Any], _ ctx: ToolContext) async -> ToolHandlerResult {
        let filePath = input["file_path"] as? String ?? ""
        let funcName = input["function_name"] as? String ?? ""
        let newFile = input["new_file"] as? String ?? ""
        vm.appendLog("📦 Extract: \(funcName) → \(newFile)")
        let output = await Self.offMain { CodingService.extractFunctionToFile(sourcePath: filePath, functionName: funcName, newFileName: newFile) }
        vm.appendLog(output)
        return .handled(output)
    }

    private static func handleWebSearch(_ vm: AgentViewModel, _ name: String, _ input: [String: Any], _ ctx: ToolContext) async -> ToolHandlerResult {
        let query = input["query"] as? String ?? ""
        vm.appendLog("Web search: \(query)"); vm.flushLog()
        let output = await Self.performWebSearchForTask(query: query, apiKey: ctx.tavilyAPIKey, provider: ctx.selectedProvider)
        vm.appendLog(Self.preview(output, lines: 5))
        return .handled(output)
    }
}
