@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log
import Cocoa

extension AgentViewModel {

    /// Handle FileManager tool calls for tab tasks.
    func handleTabFileManagerTool(
        tab: ScriptTab, name: String, input: [String: Any], toolId: String
    ) async -> TabToolResult {

        switch name {
        case "read_file":
            let filePath = input["file_path"] as? String ?? ""
            let offset = input["offset"] as? Int
            let limit = input["limit"] as? Int
            tab.appendLog("📖 Read: \(filePath)")
            let output = await Self.offMain { CodingService.readFile(path: filePath, offset: offset, limit: limit) }
            let lang = Self.langFromPath(filePath)
            tab.appendLog(Self.codeFence(Self.preview(output, lines: readFilePreviewLines), language: lang))
            tab.flush()
            // For large files without offset/limit, truncate and guide model to use pagination
            let lineCount = output.components(separatedBy: "\n").count
            let maxLines = 200
            let toolOutput: String
            if lineCount > maxLines && offset == nil && limit == nil {
                let preview = output.components(separatedBy: "\n").prefix(maxLines).joined(separator: "\n")
                toolOutput = preview + "\n\n--- FILE HAS \(lineCount) LINES (showing first \(maxLines)) ---\nUse read_file with offset and limit to read specific sections. Example: offset: 200, limit: 100"
            } else {
                toolOutput = output
            }
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": toolOutput],
                isComplete: false
            )

        case "write_file":
            let filePath = input["file_path"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            tab.appendLog("📝 Write: \(filePath)")
            let output = await Self.offMain { CodingService.writeFile(path: filePath, content: content) }
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )

        case "edit_file":
            let filePath = input["file_path"] as? String ?? ""
            let oldString = input["old_string"] as? String ?? ""
            let newString = input["new_string"] as? String ?? ""
            let replaceAll = input["replace_all"] as? Bool ?? false
            tab.appendLog("📝 Edit: \(filePath)")
            let output = await Self.offMain { CodingService.editFile(path: filePath, oldString: oldString, newString: newString, replaceAll: replaceAll) }
            let diff = MultiLineDiff.createDiff(source: oldString, destination: newString, includeMetadata: true)
            var d1f = MultiLineDiff.displayDiff(diff: diff, source: oldString, format: .ai)
            if d1f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                d1f = "❌ " + oldString + "\n" + "✅ " + newString
            }
            var diffLog = d1f
            if let meta = diff.metadata, let startLine = meta.sourceStartLine {
                diffLog += "\n📍 Changes start at line \(startLine + 1)"
                if let total = meta.sourceTotalLines {
                    diffLog += " (of \(total) lines)"
                }
            }
            tab.appendOutput(diffLog + "\n")
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )

        case "create_diff":
            let source = input["source"] as? String ?? ""
            let destination = input["destination"] as? String ?? ""
            let diff = MultiLineDiff.createDiff(source: source, destination: destination, includeMetadata: true)
            let d1f = MultiLineDiff.displayDiff(diff: diff, source: source, format: .ai)
            let summary = MultiLineDiff.generateDiffSummary(source: source, destination: destination)
            var result = d1f + "\n\n" + summary
            if let meta = diff.metadata, let startLine = meta.sourceStartLine {
                result += "\n📍 Changes start at line \(startLine + 1)"
            }
            tab.appendOutput(result + "\n")
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": result],
                isComplete: false
            )

        case "apply_diff":
            let filePath = input["file_path"] as? String ?? ""
            let asciiDiff = input["diff"] as? String ?? ""
            tab.appendLog("📝 Apply D1F diff: \(filePath)")
            let expandedPath = (filePath as NSString).expandingTildeInPath
            guard let data = FileManager.default.contents(atPath: expandedPath),
                  let source = String(data: data, encoding: .utf8) else {
                let err = "Error: cannot read \(filePath)"
                tab.appendLog(err)
                tab.flush()
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": err],
                    isComplete: false
                )
            }
            do {
                let patched = try MultiLineDiff.applyASCIIDiff(to: source, asciiDiff: asciiDiff)
                try patched.write(to: URL(fileURLWithPath: expandedPath), atomically: true, encoding: .utf8)
                let verifyDiff = MultiLineDiff.createAndDisplayDiff(source: source, destination: patched, format: .ai)
                tab.appendOutput(verifyDiff + "\n")
                let output = "Applied diff to \(filePath)"
                tab.appendLog(output)
                tab.flush()
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                    isComplete: false
                )
            } catch {
                let err = "Error applying diff: \(error.localizedDescription)"
                tab.appendLog(err)
                tab.flush()
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": err],
                    isComplete: false
                )
            }

        case "list_files":
            let pattern = input["pattern"] as? String ?? "*"
            let path = input["path"] as? String
            tab.appendLog("🔍 $ find \(path ?? "~") -name '\(pattern)'")
            tab.flush()
            let cmd = CodingService.buildListFilesCommand(pattern: pattern, path: path)
            let result = await executeForTab(command: cmd)
            guard !Task.isCancelled else { return TabToolResult(toolResult: nil, isComplete: false) }
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "No files matching '\(pattern)'" : result.output
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )

        case "search_files":
            let pattern = input["pattern"] as? String ?? ""
            let path = input["path"] as? String
            let include = input["include"] as? String
            tab.appendLog("🔍 $ grep -rn '\(pattern)' \(path ?? "~")")
            tab.flush()
            let cmd = CodingService.buildSearchFilesCommand(pattern: pattern, path: path, include: include)
            let result = await executeForTab(command: cmd)
            guard !Task.isCancelled else { return TabToolResult(toolResult: nil, isComplete: false) }
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "No matches for '\(pattern)'" : result.output
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )

        default:
        let output = await executeNativeTool(name, input: input)
        tab.appendLog(output); tab.flush()
        return tabResult(output, toolId: toolId)
        }
    }
}
