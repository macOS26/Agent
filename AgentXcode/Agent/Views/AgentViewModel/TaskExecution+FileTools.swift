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

        // MARK: edit_file — uses CodingService for replacement logic, D1F for preview
        if name == "edit_file" {
            let filePath = input["file_path"] as? String ?? ""
            let oldString = input["old_string"] as? String ?? ""
            let newString = input["new_string"] as? String ?? ""
            let replaceAll = input["replace_all"] as? Bool ?? false
            let context = input["context"] as? String
            appendLog("📝 Edit: \(filePath)")
            let expandedEdit = (filePath as NSString).expandingTildeInPath

            // Single read from disk
            guard let data = FileManager.default.contents(atPath: expandedEdit),
                  let originalContent = String(data: data, encoding: .utf8) else {
                let err = "Error: cannot read \(filePath)"
                appendLog(err)
                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                return true
            }

            // Use CodingService for the replacement (handles fuzzy match, context, etc.)
            let output = await Self.offMain { CodingService.editFile(path: filePath, oldString: oldString, newString: newString, replaceAll: replaceAll, context: context) }

            if !output.hasPrefix("Error") {
                DiffStore.shared.recordEdit(filePath: expandedEdit, originalContent: originalContent)

                // D1F preview from old → new (fast, no extra file read)
                let diff = MultiLineDiff.createDiff(source: oldString, destination: newString, includeMetadata: true)
                var d1f = MultiLineDiff.displayDiff(diff: diff, source: oldString, format: .ai)
                if d1f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    d1f = "❌ " + oldString + "\n" + "✅ " + newString
                }
                appendLog(d1f)
            }
            appendLog(output)
            commandsRun.append("edit_file: \(filePath)")
            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
            return true
        }

        // MARK: create_diff — reads file from disk, requires line range
        if name == "create_diff" {
            let filePath = input["file_path"] as? String ?? ""
            let destination = input["destination"] as? String ?? ""
            guard let startLine = input["start_line"] as? Int,
                  let endLine = input["end_line"] as? Int else {
                let err = "Error: start_line and end_line are required. Use read_file first to find the line numbers, then specify the range to edit."
                appendLog(err)
                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                return true
            }

            let expanded = (filePath as NSString).expandingTildeInPath
            guard let data = FileManager.default.contents(atPath: expanded),
                  let fullText = String(data: data, encoding: .utf8) else {
                let err = "Error: cannot read \(filePath)"
                appendLog(err)
                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                return true
            }

            let lines = fullText.components(separatedBy: "\n")
            let s = max(startLine - 1, 0)
            let e = min(endLine, lines.count)
            let source = lines[s..<e].joined(separator: "\n")

            let algorithm = CodingService.selectDiffAlgorithm(source: source, destination: destination)
            let diff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: algorithm, includeMetadata: true, sourceStartLine: startLine - 1)
            let d1f = MultiLineDiff.displayDiff(diff: diff, source: source, format: .ai)
            let diffId = DiffStore.shared.store(diff: diff, source: source)
            resetStreamCounters()
            appendLog(d1f)
            appendLog("📝 Created diff for \(filePath) (lines \(startLine)-\(endLine))")
            commandsRun.append("create_diff: \(filePath)")
            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "diff_id: \(diffId.uuidString)\n\n\(d1f)"])
            return true
        }

        // MARK: apply_diff — reads file from disk, applies stored diff
        if name == "apply_diff" {
            let filePath = input["file_path"] as? String ?? ""
            let diffIdStr = input["diff_id"] as? String ?? ""
            let asciiDiff = input["diff"] as? String ?? ""
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
                // Safety: reject diffs that would dramatically shrink the file
                if source.count > 200 && patched.count < source.count / 2 {
                    let err = "Error: diff rejected — would shrink file from \(source.count) to \(patched.count) chars. Likely truncated. Use start_line/end_line with diff_and_apply instead."
                    appendLog(err)
                    toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                    return true
                }
                try patched.write(to: URL(fileURLWithPath: expandedPath), atomically: true, encoding: .utf8)
                // Track the apply for UUID-based undo
                if let uuid = UUID(uuidString: diffIdStr) {
                    DiffStore.shared.recordApply(diffId: uuid, filePath: expandedPath, originalContent: source)
                } else {
                    DiffStore.shared.recordEdit(filePath: expandedPath, originalContent: source)
                }
                // Use the library's verification
                let verifyDiff = MultiLineDiff.createDiff(source: source, destination: patched, includeMetadata: true)
                let verified = MultiLineDiff.verifyDiff(verifyDiff)
                let display = MultiLineDiff.displayDiff(diff: verifyDiff, source: source, format: .ai)
                appendLog(display)
                let newLineCount = patched.components(separatedBy: "\n").count
                appendLog("📝 Applied diff to \(filePath) [verified: \(verified)] (\(newLineCount) lines)")
                // Invalidate all pending diffs for this file — line numbers have shifted
                DiffStore.shared.invalidateDiffs(for: expandedPath)
                commandsRun.append("apply_diff: \(filePath)")
                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "Applied diff to \(filePath) [verified: \(verified)] — file now has \(newLineCount) lines. Any pending diffs for this file are invalidated. Re-read the file before making more edits.\n\n\(display)"])
            } catch {
                let err = "Error applying diff: \(error.localizedDescription)"
                appendLog(err)
                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
            }
            return true
        }

        // MARK: undo_edit — uses diff_id UUID or falls back to file path
        if name == "undo_edit" {
            let filePath = input["file_path"] as? String ?? ""
            let diffIdStr = input["diff_id"] as? String
            let expandedUndo = (filePath as NSString).expandingTildeInPath

            // Try UUID-based undo first (uses D1F library's createUndoDiff)
            if let idStr = diffIdStr, let uuid = UUID(uuidString: idStr),
               let stored = DiffStore.shared.retrieve(uuid) {
                // Use D1F's built-in undo: create reverse diff from metadata
                if let undoDiff = MultiLineDiff.createUndoDiff(from: stored.diff) {
                    let currentPath = (filePath.isEmpty ? DiffStore.shared.lastAppliedDiffId(for: expandedUndo).flatMap { DiffStore.shared.retrieve($0) }.map { _ in expandedUndo } ?? expandedUndo : expandedUndo)
                    guard let data = FileManager.default.contents(atPath: currentPath),
                          let current = String(data: data, encoding: .utf8) else {
                        let err = "Error: cannot read \(filePath)"
                        appendLog(err)
                        toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                        return true
                    }
                    do {
                        let restored = try MultiLineDiff.applyDiff(to: current, diff: undoDiff)
                        try restored.write(to: URL(fileURLWithPath: currentPath), atomically: true, encoding: .utf8)
                        DiffStore.shared.popLastApplied(for: currentPath)
                        let display = MultiLineDiff.displayDiff(diff: undoDiff, source: current, format: .ai)
                        appendLog(display)
                        appendLog("↩️ Undo applied (diff_id: \(idStr))")
                        commandsRun.append("undo_edit: \(filePath)")
                        toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "Undo applied for diff_id \(idStr)\n\n\(display)"])
                        return true
                    } catch {
                        appendLog("D1F undo failed: \(error.localizedDescription), falling back to edit history")
                    }
                }
            }

            // Fallback: file-path-based undo from edit history
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

        // MARK: diff_and_apply — same as create_diff + apply_diff in one call, no shortcuts
        if name == "diff_and_apply" {
            let filePath = input["file_path"] as? String ?? ""
            let destination = input["destination"] as? String ?? ""
            let startLine = input["start_line"] as? Int
            let endLine = input["end_line"] as? Int
            let rangeNote = (startLine != nil && endLine != nil) ? " (lines \(startLine!)-\(endLine!))" : ""

            let expanded = (filePath as NSString).expandingTildeInPath
            guard let data = FileManager.default.contents(atPath: expanded),
                  let fullText = String(data: data, encoding: .utf8) else {
                let err = "Error: cannot read \(filePath)"
                appendLog(err)
                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                return true
            }

            // Step 1: Extract source section (same as create_diff)
            let source: String
            if let sl = startLine, let el = endLine {
                let lines = fullText.components(separatedBy: "\n")
                let s = max(sl - 1, 0)
                let e = min(el, lines.count)
                source = lines[s..<e].joined(separator: "\n")
            } else {
                source = fullText
            }

            if source == destination {
                let err = "Error: source and destination are identical"
                appendLog(err)
                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                return true
            }

            // Step 2: Create diff with full metadata (same as create_diff)
            let algorithm = CodingService.selectDiffAlgorithm(source: source, destination: destination)
            let diff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: algorithm, includeMetadata: true, sourceStartLine: startLine.map { $0 - 1 })
            let diffId = DiffStore.shared.store(diff: diff, source: source)

            // Step 3: Apply diff (same as apply_diff)
            do {
                let patched = try MultiLineDiff.applyDiff(to: source, diff: diff)

                // Safety check
                if fullText.count > 200 && patched.count < source.count / 2 {
                    let err = "Error: diff rejected — would shrink section from \(source.count) to \(patched.count) chars. Likely truncated."
                    appendLog(err)
                    toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                    return true
                }

                // Splice back into full file if line range was used
                let finalContent: String
                if let sl = startLine, let el = endLine {
                    var allLines = fullText.components(separatedBy: "\n")
                    let s = max(sl - 1, 0)
                    let e = min(el, allLines.count)
                    allLines.replaceSubrange(s..<e, with: patched.components(separatedBy: "\n"))
                    finalContent = allLines.joined(separator: "\n")
                } else {
                    finalContent = patched
                }

                try finalContent.write(to: URL(fileURLWithPath: expanded), atomically: true, encoding: .utf8)

                // Record for UUID-based undo
                DiffStore.shared.recordApply(diffId: diffId, filePath: expanded, originalContent: fullText)

                // Verify (same as apply_diff)
                let verifyDiff = MultiLineDiff.createDiff(source: source, destination: patched, includeMetadata: true)
                let verified = MultiLineDiff.verifyDiff(verifyDiff)
                let display = MultiLineDiff.displayDiff(diff: verifyDiff, source: source, format: .ai)
                let newLineCount = finalContent.components(separatedBy: "\n").count
                appendLog(display)
                appendLog("📝 Diff+Apply: \(filePath)\(rangeNote) [verified: \(verified)] (\(newLineCount) lines)")
                // Invalidate all pending diffs for this file — line numbers have shifted
                DiffStore.shared.invalidateDiffs(for: expanded)
                commandsRun.append("diff_and_apply: \(filePath)")
                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "Applied diff to \(filePath)\(rangeNote) [verified: \(verified)] — file now has \(newLineCount) lines. Re-read the file before making more edits. diff_id: \(diffId.uuidString)\n\n\(display)"])
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