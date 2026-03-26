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
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )

        case "write_file":
            let filePath = input["file_path"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            tab.appendLog("📝 Write: \(filePath)")
            let output = await Self.offMain { CodingService.writeFile(path: filePath, content: content) }
            tab.appendLog(output)
            let lang = Self.langFromPath(filePath)
            tab.appendLog(Self.codeFence(Self.preview(content, lines: readFilePreviewLines), language: lang))
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
                d1f = "❌" + oldString + "\n" + "✅" + newString
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
            var source = input["source"] as? String ?? ""
            let destination = input["destination"] as? String ?? ""
            if let fp = input["file_path"] as? String, !fp.isEmpty {
                let expanded = (fp as NSString).expandingTildeInPath
                if let data = FileManager.default.contents(atPath: expanded),
                   let text = String(data: data, encoding: .utf8) {
                    source = text
                }
            }
            let diff = MultiLineDiff.createDiff(source: source, destination: destination, includeMetadata: true)
            let d1f = MultiLineDiff.displayDiff(diff: diff, source: source, format: .ai)
            let diffId = DiffStore.shared.store(diff: diff, source: source)
            tab.appendOutput(d1f + "\n")
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": "diff_id: \(diffId.uuidString)\n\n\(d1f)"],
                isComplete: false
            )

        case "apply_diff":
            let filePath = input["file_path"] as? String ?? ""
            let diffIdStr = input["diff_id"] as? String ?? ""
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
                let patched: String
                if let uuid = UUID(uuidString: diffIdStr),
                   let stored = DiffStore.shared.retrieve(uuid) {
                    patched = try MultiLineDiff.applyDiff(to: source, diff: stored.diff)
                } else if !asciiDiff.isEmpty {
                    patched = try MultiLineDiff.applyASCIIDiff(to: source, asciiDiff: asciiDiff)
                } else {
                    throw DiffError.invalidDiff
                }
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
            let tabFolder = Self.resolvedWorkingDirectory(tab.projectFolder.isEmpty ? projectFolder : tab.projectFolder)
            let cmd = CodingService.buildListFilesCommand(pattern: pattern, path: path)
            let result = await executeForTab(command: cmd, projectFolder: tabFolder)
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
            let tabFolder = Self.resolvedWorkingDirectory(tab.projectFolder.isEmpty ? projectFolder : tab.projectFolder)
            let cmd = CodingService.buildSearchFilesCommand(pattern: pattern, path: path, include: include)
            let result = await executeForTab(command: cmd, projectFolder: tabFolder)
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
