@preconcurrency import Foundation
import MultiLineDiff
import os.log

private let fileLog = Logger(subsystem: AppConstants.subsystem, category: "FileTools")

// MARK: - File I/O Tool Execution
extension AgentViewModel {

    /// Handles file I/O tool calls.
    /// Returns nil if this is not a file tool call.
    @MainActor
    func handleFileTool(
        name: String,
        input: [String: Any],
        toolId: String,
        appendLog: @escaping @Sendable (String) -> Void,
        appendRawOutput: @escaping @Sendable (String) -> Void,
        commandsRun: inout [String],
        toolResults: inout [[String: Any]]
    ) async -> Bool {
        // MARK: read_file
        if name == "read_file" {
            let filePath = input["file_path"] as? String ?? ""
            let offset = input["offset"] as? Int
            let limit = input["limit"] as? Int
            appendLog("📖 Read: \(filePath)")
            let output = await Self.offMain { CodingService.readFile(path: filePath, offset: offset, limit: limit) }
            let lang = Self.langFromPath(filePath)
            appendLog(Self.codeFence(Self.preview(output, lines: readFilePreviewLines), language: lang))
            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
            return true
        }

        // MARK: write_file
        if name == "write_file" {
            let filePath = input["file_path"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            appendLog("📝 Write: \(filePath)")
            let output = await Self.offMain { CodingService.writeFile(path: filePath, content: content) }
            appendLog(output)
            commandsRun.append("write_file: \(filePath)")
            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
            return true
        }

        // MARK: edit_file
        if name == "edit_file" {
            let filePath = input["file_path"] as? String ?? ""
            let oldString = input["old_string"] as? String ?? ""
            let newString = input["new_string"] as? String ?? ""
            let replaceAll = input["replace_all"] as? Bool ?? false
            appendLog("📝 Edit: \(filePath)")

            let output = await Self.offMain { CodingService.editFile(path: filePath, oldString: oldString, newString: newString, replaceAll: replaceAll) }

            // Show D1F pretty diff with metadata
            let diff = MultiLineDiff.createDiff(source: oldString, destination: newString, includeMetadata: true)
            var d1f = MultiLineDiff.displayDiff(diff: diff, source: oldString, format: .ai)
            // displayDiff can be empty for single-line character changes — show lines directly
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
            appendRawOutput(diffLog + "\n")

            appendLog(output)
            commandsRun.append("edit_file: \(filePath)")
            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
            return true
        }

        // MARK: create_diff
        if name == "create_diff" {
            let source = input["source"] as? String ?? ""
            let destination = input["destination"] as? String ?? ""
            let diff = MultiLineDiff.createDiff(source: source, destination: destination, includeMetadata: true)
            let d1f = MultiLineDiff.displayDiff(diff: diff, source: source, format: .ai)
            let summary = MultiLineDiff.generateDiffSummary(source: source, destination: destination)
            var result = d1f + "\n\n" + summary
            if let meta = diff.metadata, let startLine = meta.sourceStartLine {
                result += "\n📍 Changes start at line \(startLine + 1)"
            }
            appendRawOutput(result + "\n")
            commandsRun.append("create_diff")
            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": result])
            return true
        }

        // MARK: apply_diff
        if name == "apply_diff" {
            let filePath = input["file_path"] as? String ?? ""
            let asciiDiff = input["diff"] as? String ?? ""
            appendLog("📝 Apply D1F diff: \(filePath)")
            let expandedPath = (filePath as NSString).expandingTildeInPath
            guard let data = FileManager.default.contents(atPath: expandedPath),
                  let source = String(data: data, encoding: .utf8) else {
                let err = "Error: cannot read \(filePath)"
                appendLog(err)
                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                return true
            }
            do {
                let patched = try MultiLineDiff.applyASCIIDiff(to: source, asciiDiff: asciiDiff)
                try patched.write(to: URL(fileURLWithPath: expandedPath), atomically: true, encoding: .utf8)
                let verifyDiff = MultiLineDiff.createAndDisplayDiff(source: source, destination: patched, format: .ai)
                appendRawOutput(verifyDiff + "\n")
                let output = "Applied diff to \(filePath)"
                appendLog(output)
                commandsRun.append("apply_diff: \(filePath)")
                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
            } catch {
                let err = "Error applying diff: \(error.localizedDescription)"
                appendLog(err)
                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
            }
            return true
        }

        return false
    }
}