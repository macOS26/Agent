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
            let lang = Self.langFromPath(filePath)
            appendLog(Self.codeFence(Self.preview(content, lines: readFilePreviewLines), language: lang))
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
            let context = input["context"] as? String
            appendLog("📝 Edit: \(filePath)")
            let expandedEdit = (filePath as NSString).expandingTildeInPath
            let originalEdit: String? = await Self.offMain {
                guard let data = FileManager.default.contents(atPath: expandedEdit),
                      let text = String(data: data, encoding: .utf8) else { return nil }
                return text
            }
            let output = await Self.offMain { CodingService.editFile(path: filePath, oldString: oldString, newString: newString, replaceAll: replaceAll, context: context) }
            if !output.hasPrefix("Error"), let orig = originalEdit {
                DiffStore.shared.recordEdit(filePath: expandedEdit, originalContent: orig)
            }
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
            appendRawOutput(diffLog + "\n")
            appendLog(output)
            commandsRun.append("edit_file: \(filePath)")
            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
            return true
        }

        // MARK: create_diff
        if name == "create_diff" {
            var source = input["source"] as? String ?? ""
            let destination = input["destination"] as? String ?? ""
            let startLine = input["start_line"] as? Int
            let endLine = input["end_line"] as? Int
            if let fp = input["file_path"] as? String, !fp.isEmpty {
                let expanded = (fp as NSString).expandingTildeInPath
                if let data = FileManager.default.contents(atPath: expanded),
                   let text = String(data: data, encoding: .utf8) {
                    if let sl = startLine, let el = endLine {
                        let lines = text.components(separatedBy: "\n")
                        let s = max(sl - 1, 0)
                        let e = min(el, lines.count)
                        source = lines[s..<e].joined(separator: "\n")
                    } else {
                        source = text
                    }
                }
            }
            let algorithm = CodingService.selectDiffAlgorithm(source: source, destination: destination)
            let diff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: algorithm, includeMetadata: true, sourceStartLine: startLine.map { $0 - 1 })
            let d1f = MultiLineDiff.displayDiff(diff: diff, source: source, format: .ai)
            let diffId = DiffStore.shared.store(diff: diff, source: source)
            appendRawOutput(d1f + "\n")
            commandsRun.append("create_diff")
            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "diff_id: \(diffId.uuidString)\n\n\(d1f)"])
            return true
        }

        // MARK: apply_diff
        if name == "apply_diff" {
            let filePath = input["file_path"] as? String ?? ""
            let diffIdStr = input["diff_id"] as? String ?? ""
            let asciiDiff = input["diff"] as? String ?? ""
            appendLog("📝 Apply diff: \(filePath)")
            let expandedPath = (filePath as NSString).expandingTildeInPath
            guard let data = FileManager.default.contents(atPath: expandedPath),
                  let source = String(data: data, encoding: .utf8) else {
                let err = "Error: cannot read \(filePath)"
                appendLog(err)
                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                return true
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
                DiffStore.shared.recordEdit(filePath: expandedPath, originalContent: source)
                let verifyResult = MultiLineDiff.createDiff(source: source, destination: patched, includeMetadata: true)
                let verified = MultiLineDiff.verifyDiff(verifyResult)
                let verifyDiff = MultiLineDiff.displayDiff(diff: verifyResult, source: source, format: .ai)
                appendRawOutput(verifyDiff + "\n")
                let output = "Applied diff to \(filePath) [verified: \(verified)]"
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

        // MARK: undo_edit
        if name == "undo_edit" {
            let filePath = input["file_path"] as? String ?? ""
            let expandedUndo = (filePath as NSString).expandingTildeInPath
            guard let original = DiffStore.shared.lastEdit(for: expandedUndo) else {
                let err = "Error: no edit history for \(filePath)"
                appendLog(err)
                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                return true
            }
            appendLog("↩️ Undo: \(filePath)")
            let output = await Self.offMain { CodingService.undoEdit(path: filePath, originalContent: original) }
            if !output.hasPrefix("Error") { DiffStore.shared.clearEditHistory(for: expandedUndo) }
            appendLog(output)
            commandsRun.append("undo_edit: \(filePath)")
            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
            return true
        }

        // MARK: diff_and_apply
        if name == "diff_and_apply" {
            let filePath = input["file_path"] as? String ?? ""
            let source = input["source"] as? String
            let destination = input["destination"] as? String ?? ""
            let startLine = input["start_line"] as? Int
            let endLine = input["end_line"] as? Int
            let rangeNote = (startLine != nil && endLine != nil) ? " (lines \(startLine!)-\(endLine!))" : ""
            appendLog("📝 Diff+Apply: \(filePath)\(rangeNote)")
            let expandedDA = (filePath as NSString).expandingTildeInPath
            let originalDA: String? = await Self.offMain {
                guard let data = FileManager.default.contents(atPath: expandedDA),
                      let text = String(data: data, encoding: .utf8) else { return nil }
                return text
            }
            let result = await Self.offMain { CodingService.diffAndApply(path: filePath, source: source, destination: destination, startLine: startLine, endLine: endLine) }
            if !result.output.hasPrefix("Error"), let orig = originalDA {
                DiffStore.shared.recordEdit(filePath: expandedDA, originalContent: orig)
            }
            if !result.display.isEmpty { appendRawOutput(result.display + "\n") }
            appendLog(result.output)
            commandsRun.append("diff_and_apply: \(filePath)")
            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": result.output])
            return true
        }

        return false
    }
}