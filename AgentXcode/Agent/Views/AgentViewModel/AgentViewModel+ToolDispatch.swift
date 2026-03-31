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

// MARK: - Tool Dispatch Table

extension AgentViewModel {

    /// Dispatch a tool call by name. Returns the handler result.
    func dispatchTool(
        name: String,
        input: [String: Any],
        ctx: ToolContext,
        commandsRun: inout [String],
        toolResults: inout [[String: Any]]
    ) async -> ToolHandlerResult {

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
            commandsRun: &commandsRun,
            toolResults: &toolResults
        ) {
            return .alreadyAppended
        }

        // Web tools — checked by prefix
        if name.hasPrefix("web_") || name == "web" {
            let webResult = await handleMainWebTool(name: name, input: input)
            appendLog(String(webResult.prefix(500)))
            flushLog()
            return .handled(webResult)
        }

        // Dispatch table lookup
        let result = await dispatchByName(name: name, input: input, ctx: ctx, commandsRun: &commandsRun)

        switch result {
        case .handled(let output):
            toolResults.append(["type": "tool_result", "tool_use_id": ctx.toolId, "content": output])
        case .alreadyAppended, .taskComplete:
            break
        case .notHandled:
            // Fallback: route through executeNativeTool
            let output = await executeNativeTool(name, input: input)
            appendLog(output)
            flushLog()
            toolResults.append(["type": "tool_result", "tool_use_id": ctx.toolId, "content": output])
        }

        return result
    }

    /// Name-based dispatch — the core lookup.
    private func dispatchByName(
        name: String,
        input: [String: Any],
        ctx: ToolContext,
        commandsRun: inout [String]
    ) async -> ToolHandlerResult {
        switch name {

        // NOTE: write_file, edit_file, create_diff, apply_diff, undo_edit, read_file, diff_and_apply
        // are all handled by handleFileTool() above — no case needed here.

        // MARK: - Process-based tools

        case "list_files":
            let pattern = input["pattern"] as? String ?? "*"
            let path = input["path"] as? String
            if let pathErr = Self.checkPath(path) {
                appendLog(pathErr)
                return .handled(pathErr)
            }
            let resolvedPath = path ?? ctx.projectFolder
            let displayPath = CodingService.trimHome(resolvedPath)
            appendLog("🔍 $ find \(displayPath) -name '\(pattern)'")
            flushLog()
            let cmd = CodingService.buildListFilesCommand(pattern: pattern, path: path)
            let result = await executeViaUserAgent(command: cmd, silent: true)
            guard !Task.isCancelled else { return .handled("cancelled") }
            let raw = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            let formatted = raw.isEmpty ? "No files matching '\(pattern)'" : CodingService.formatFileTree(raw)
            appendLog(formatted)
            flushLog()
            let output = raw.isEmpty ? formatted : "[project folder: \(displayPath)] paths are relative to project folder\n\(formatted)"
            return .handled(output)

        case "search_files":
            let pattern = input["pattern"] as? String ?? ""
            let path = input["path"] as? String
            let include = input["include"] as? String
            if let pathErr = Self.checkPath(path) {
                appendLog(pathErr)
                return .handled(pathErr)
            }
            let resolvedSearch = path ?? ctx.projectFolder
            let displaySearch = CodingService.trimHome(resolvedSearch)
            appendLog("🔍 $ grep -rn '\(pattern)' \(displaySearch)\(include.map { " --include=\($0)" } ?? "")")
            flushLog()
            let cmd = CodingService.buildSearchFilesCommand(pattern: pattern, path: path, include: include)
            let result = await executeViaUserAgent(command: cmd)
            guard !Task.isCancelled else { return .handled("cancelled") }
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "No matches for '\(pattern)'" : "[project folder: \(displaySearch)] paths are relative to project folder\n\(result.output)"
            return .handled(output)

        case "read_dir":
            let path = input["path"] as? String ?? ctx.projectFolder
            if let pathErr = Self.checkPath(path) {
                appendLog(pathErr)
                return .handled(pathErr)
            }
            let displayPath = CodingService.trimHome(path)
            let detail = (input["detail"] as? String ?? "slim") == "more"
            appendLog("📂 \(displayPath)")
            flushLog()
            let dir = CodingService.shellEscape(path)
            let cmd = detail
                ? "ls -la \(dir) 2>/dev/null"
                : "cd \(dir) && find . -maxdepth 1 -not -name '.*' 2>/dev/null | sed 's|^\\./||' | sort"
            let result = await executeViaUserAgent(command: cmd, silent: !detail)
            guard !Task.isCancelled else { return .handled("cancelled") }
            let raw = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            let output = raw.isEmpty ? "Directory not found or empty" : "[project folder: \(displayPath)]\n\(raw)"
            return .handled(output)

        case "if_to_switch":
            let filePath = input["file_path"] as? String ?? ""
            appendLog("🔄 if→switch: \(filePath)")
            let output = await Self.offMain { CodingService.convertIfToSwitch(path: filePath) }
            appendLog(output)
            return .handled(output)

        case "extract_function":
            let filePath = input["file_path"] as? String ?? ""
            let funcName = input["function_name"] as? String ?? ""
            let newFile = input["new_file"] as? String ?? ""
            appendLog("📦 Extract: \(funcName) → \(newFile)")
            let output = await Self.offMain { CodingService.extractFunctionToFile(sourcePath: filePath, functionName: funcName, newFileName: newFile) }
            appendLog(output)
            return .handled(output)

        // MARK: - Plan & Project tools

        case "plan_mode":
            let output = await executeNativeTool(name, input: input)
            appendLog(output); flushLog()
            return .handled(output)

        case "project_folder":
            let output = await executeNativeTool(name, input: input)
            appendLog(output); flushLog()
            return .handled(output)

        case "coding_mode":
            let output = await executeNativeTool(name, input: input)
            appendLog(output); flushLog()
            return .handled(output)

        case "list_tools":
            let output = await executeNativeTool(name, input: input)
            appendLog(output); flushLog()
            return .handled(output)

        case "web_search":
            let query = input["query"] as? String ?? ""
            appendLog("Web search: \(query)")
            flushLog()
            let output = await Self.performWebSearchForTask(query: query, apiKey: ctx.tavilyAPIKey, provider: ctx.selectedProvider)
            appendLog(Self.preview(output, lines: 5))
            return .handled(output)

        case "conversation":
            let output = await executeNativeTool(name, input: input)
            appendLog(output); flushLog()
            return .handled(output)

        case "send_message":
            let output = await executeNativeTool(name, input: input)
            appendLog(output); flushLog()
            return .handled(output)

        case "memory":
            let output = await executeNativeTool(name, input: input)
            appendLog(output); flushLog()
            return .handled(output)

        default:
            // Let the caller try executeNativeTool as fallback
            return .notHandled
        }
    }
}
