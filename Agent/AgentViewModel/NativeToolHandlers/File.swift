
@preconcurrency import Foundation
import AgentTools
import AgentMCP
import AgentD1F
import AgentSwift
import AgentAccess
import Cocoa

// MARK: - Native Tool Handler — File Operations

/// Tracks the last edit attempt per tab to detect and reject consecutive duplicate edits.
/// Prevents the LLM from retrying the exact same old_string on the exact same file — a sign
/// it's stuck in a loop. The guard fires at the dispatch layer (code-level, not prompt-only).
struct LastEditAttempt: @unchecked Sendable {
    let filePath: String
    let oldString: String
}

/// Tracks how many times a file has been read per tab. Enforces a limit that resets on edit.
/// Base limit: 3 reads. Each edit grants additional reads: 1st edit → 2 more, 2nd edit → 1 more.
/// After that, the file is blocked from further reads until another edit occurs.
struct FileReadCount: @unchecked Sendable {
    var readCount: Int = 0
    var editCount: Int = 0

    /// Maximum reads allowed given the number of edits made to this file.
    /// 0 edits → 3 reads, 1 edit → 5 reads, 2 edits → 6 reads, N edits → 4 + N reads.
    /// Every edit grants at least 1 additional read so the LLM can always verify its edit.
    var maxReads: Int {
        switch editCount {
        case 0: return 3
        case 1: return 5
        case 2: return 6
        default: return 4 + editCount
        }
    }
}

/// Snapshot of the last successful read_file emission for a (tab, path, offset, limit).
/// Used to dedup: if the file's mtime+size are unchanged since we last emitted bytes for
/// this exact request, the model has already seen the content in this conversation —
/// don't re-emit. This is the tool-level cure for the "read the same file 20 times" spiral.
struct LastReadEmission: @unchecked Sendable {
    let mtime: Date
    let size: Int64
}

extension AgentViewModel {

    /// State for duplicate edit detection — keyed by tab UUID string.
    private static var _lastEditAttempts: [String: LastEditAttempt] = [:]
    private static let _lastEditLock = NSLock()

    private static func checkDuplicateEdit(tabID: UUID, filePath: String, oldString: String) -> Bool {
        _lastEditLock.lock()
        defer { _lastEditLock.unlock() }
        let key = tabID.uuidString
        let last = _lastEditAttempts[key]
        _lastEditAttempts[key] = LastEditAttempt(filePath: filePath, oldString: oldString)
        guard let last else { return false }
        return last.filePath == filePath && last.oldString == oldString
    }

    /// Read-count tracking per (tab, file) — keyed by "\(tabUUID):\(normalizedPath)"
    private static var _readCounts: [String: FileReadCount] = [:]
    private static let _readCountLock = NSLock()

    /// Check if a read is allowed. Increments the counter. Returns nil if allowed, or an error string if blocked.
    private static func checkAndIncrementReadCount(tabID: UUID, filePath: String) -> String? {
        _readCountLock.lock()
        defer { _readCountLock.unlock() }
        let key = "\(tabID.uuidString):\(filePath)"
        var entry = _readCounts[key] ?? FileReadCount()
        if entry.readCount >= entry.maxReads {
            return """
                ⛔ Read limit reached for this file (\(entry.readCount) reads, \(entry.editCount) edits). \
                You have read this file too many times without making progress. \
                Recovery: edit the file first (edit_file, diff_apply, write_file), then you can read it again. \
                If you're stuck, explain what you need and ask for help instead of re-reading.
                """
        }
        entry.readCount += 1
        let remaining = entry.maxReads - entry.readCount
        _readCounts[key] = entry
        if remaining <= 1 {
            return "⚠️ Read limit warning: \(remaining) read(s) remaining for this file before you must edit it. (\(entry.readCount)/\(entry.maxReads))"
        }
        return nil // allowed, no warning
    }

    /// Reset read count for a file when it's edited — grants additional reads.
    /// Also clears the dedup cache for this file (content is now stale) AND
    /// resets the cross-file "reads since last edit" counter for this tab —
    /// editing is the signal that the model is acting on what it's read.
    private static func recordFileEdit(tabID: UUID, filePath: String) {
        _readCountLock.lock()
        defer { _readCountLock.unlock() }
        let key = "\(tabID.uuidString):\(filePath)"
        var entry = _readCounts[key] ?? FileReadCount()
        entry.editCount += 1
        _readCounts[key] = entry
        _lastReadEmissions.removeValue(forKey: "\(tabID.uuidString):\(filePath)")
        _readsSinceEditByTab[tabID.uuidString] = 0
    }

    /// Clear read counts for a tab (called when the tab's conversation resets).
    static func clearReadCountsForTab(tabID: UUID) {
        _readCountLock.lock()
        defer { _readCountLock.unlock() }
        let prefix = tabID.uuidString + ":"
        _readCounts = _readCounts.filter { !$0.key.hasPrefix(prefix) }
        _lastReadEmissions = _lastReadEmissions.filter { !$0.key.hasPrefix(prefix) }
        _readsSinceEditByTab.removeValue(forKey: tabID.uuidString)
    }

    /// Cross-file counter: how many distinct content-bearing reads have happened
    /// in this tab since the last edit. Per-file counter catches "3 reads of the
    /// same file"; this catches "read 7 different files without acting on any."
    /// Reset on any edit (recordFileEdit) and on tab reset.
    private static var _readsSinceEditByTab: [String: Int] = [:]

    /// Threshold for the cross-file read-without-edit guard. Tuned to allow
    /// genuine orientation (read ~5 files to understand the area) but stop the
    /// "read everything then read it again" spiral.
    private static let readsWithoutEditThreshold = 6

    /// Increment the cross-file counter and return a hard-stop message if the
    /// threshold is exceeded. Call AFTER the dedup check — dedup hits don't
    /// count (they emit no new content).
    private static func checkConsecutiveReadsWithoutEdit(tabID: UUID) -> String? {
        _readCountLock.lock()
        defer { _readCountLock.unlock() }
        let key = tabID.uuidString
        let next = (_readsSinceEditByTab[key] ?? 0) + 1
        _readsSinceEditByTab[key] = next
        guard next > readsWithoutEditThreshold else { return nil }
        return """
            🛑 STOP — \(next) file reads in a row without a single edit. \
            Continued reading is forbidden until you ACT. \
            Recovery: pick the single most likely file and call edit_file, \
            write_file, apply_diff, or diff_and_apply NOW — or call \
            task_complete and honestly report what is still unknown. \
            Another read_file, list_files, or search_files call without an \
            edit in between is a contract violation.
            """
    }

    /// Dedup cache: keyed by "\(tabUUID):\(expandedPath)". Any second read of the
    /// same file (regardless of offset/limit) hits this cache as long as the file
    /// hasn't changed — the rule is "you already read this file."
    private static var _lastReadEmissions: [String: LastReadEmission] = [:]

    private static func dedupKey(tabID: UUID, expandedPath: String) -> String {
        "\(tabID.uuidString):\(expandedPath)"
    }

    private static func fileStat(_ path: String) -> (mtime: Date, size: Int64)? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let mtime = attrs[.modificationDate] as? Date,
              let size = attrs[.size] as? NSNumber
        else { return nil }
        return (mtime, size.int64Value)
    }

    /// If we've already read this file in this conversation AND it hasn't changed
    /// (mtime+size match), return a stub telling the model exactly that. Applies
    /// regardless of offset/limit — re-reading any range of an unchanged file is
    /// redundant. Returns nil on first read or if the file has changed.
    /// Does NOT consume a read-count slot — dedup hits are no-ops.
    private static func dedupRead(tabID: UUID, expandedPath: String) -> String? {
        _readCountLock.lock()
        defer { _readCountLock.unlock() }
        let key = dedupKey(tabID: tabID, expandedPath: expandedPath)
        guard let last = _lastReadEmissions[key],
              let stat = fileStat(expandedPath),
              stat.mtime == last.mtime,
              stat.size == last.size
        else { return nil }
        return """
            You already read this file in this conversation and it has not changed since. \
            Use the prior read_file tool_result for \(expandedPath) — do not re-read it. \
            If you need to act on what you read, call edit_file / write_file / apply_diff now. \
            (This cache is cleared automatically the moment you edit the file.)
            """
    }

    /// Record a successful read so the next read of the same file is deduped.
    private static func recordReadEmission(tabID: UUID, expandedPath: String) {
        _readCountLock.lock()
        defer { _readCountLock.unlock() }
        guard let stat = fileStat(expandedPath) else { return }
        let key = dedupKey(tabID: tabID, expandedPath: expandedPath)
        _lastReadEmissions[key] = LastReadEmission(mtime: stat.mtime, size: stat.size)
    }

    /// / Handles file CRUD, diff, list/search, backup/restore, symbol search, / and refactor_rename tool calls. Returns
    /// `nil` if the name is not a / file-group tool so the main dispatcher can fall through.
    func handleFileNativeTool(name: String, input: [String: Any]) async -> String? {
        let pf = projectFolder
        switch name {
        // File operations
        case "read_file":
            let path = input["file_path"] as? String ?? ""
            guard !path.isEmpty else {
                return """
                    Error: file_path is required for read_file. \
                    Pass an absolute path like file_path:"/Users/...". \
                    Use file_manager(action:"list", path:...) to see \
                    what files exist if you don't know the path.
                    """
            }
            let expanded = (path as NSString).expandingTildeInPath
            let tabID = selectedTabId ?? Self.mainTabID
            let offset = input["offset"] as? Int
            let limit = input["limit"] as? Int
            // (1) Dedup: any second read of an unchanged file → stub, free.
            if let dedup = Self.dedupRead(tabID: tabID, expandedPath: expanded) {
                return dedup
            }
            // (2) Cross-file loop guard: stop "read 7 different files in a row" pathology.
            if let stop = Self.checkConsecutiveReadsWithoutEdit(tabID: tabID) {
                return stop
            }
            // (3) Per-file counter: 3 reads of the same file before requiring an edit.
            if let blocked = Self.checkAndIncrementReadCount(tabID: tabID, filePath: expanded) {
                return blocked
            }
            // Delegate to CodingService.readFile which returns line-numbered output and gives a clear 'file not found'
            // error with a list-files suggestion when the path is wrong. Honors offset+limit (1-based offset).
            let result = await Self.offMain {
                CodingService.readFile(path: path, offset: offset, limit: limit)
            }
            // Only record on a real read — not on a "file not found" error path.
            if !result.hasPrefix("Error") {
                Self.recordReadEmission(tabID: tabID, expandedPath: expanded)
            }
            return result
        // copy_image — copy a PNG/JPEG between any of {file path, clipboard, chat attachment}.
        //   source: absolute path | "clipboard" | "chat" | "chat:<index>" (0-based)
        //   dest:   absolute path | "clipboard" (default if omitted)
        case "copy_image":
            let src = (input["source"] as? String ?? input["file_path"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let destRaw = (input["dest"] as? String ?? input["destination"] as? String ?? "clipboard").trimmingCharacters(in: .whitespaces)
            return await handleCopyImage(source: src, destination: destRaw)
        case "write_file":
            var path = input["file_path"] as? String ?? ""
            guard !path.isEmpty else { return "Error: file_path is required for write_file. Recovery: pass file_path:\"/path/to/file\"." }
            if !path.hasPrefix("/") && !path.hasPrefix("~") && !pf.isEmpty {
                path = (pf as NSString).appendingPathComponent(path)
            }
            let content = input["content"] as? String ?? ""
            guard !content.isEmpty else { return "Error: content is required for write_file (empty content would truncate the file). Recovery: pass content:\"...\"." }
            let tabID = selectedTabId ?? Self.mainTabID
            FileBackupService.shared.backup(filePath: path, tabID: tabID)
            Self.recordFileEdit(tabID: tabID, filePath: (path as NSString).expandingTildeInPath)
            let url = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            do { try content.write(to: url, atomically: true, encoding: .utf8); return "Wrote \(path)" }
            catch { return "Error writing \(path): \(error.localizedDescription). Recovery: check path is writable or use file(action:\"list\") to verify the directory." }
        // MARK: edit_file — delegate to CodingService.editFile (d1f-powered with line-ending normalization, fuzzy
        // whitespace match, context disambiguation, and round-trip verification). The duplicate edit_file logic that lived here had none of those safeguards and was the source of most "old_string not found" errors when the LLM had a slightly-stale snapshot of the file.
        case "edit_file":
            var path = input["file_path"] as? String ?? ""
            guard !path.isEmpty else { return "Error: file_path is required for edit_file" }
            // Resolve relative paths against project folder
            if !path.hasPrefix("/") && !path.hasPrefix("~") && !pf.isEmpty {
                path = (pf as NSString).appendingPathComponent(path)
            }
            let expanded = (path as NSString).expandingTildeInPath
            // Basename search if file not found — same as read_file
            if !FileManager.default.fileExists(atPath: expanded) {
                let candidates = CodingService.findFilesByBasename(originalPath: expanded, maxResults: 5)
                if !candidates.isEmpty {
                    let list = candidates.map { "  \($0)" }.joined(separator: "\n")
                    return "Error: file not found: \(path)\nFound:\n\(list)\nRecovery: re-call with the correct path."
                }
                return "Error: file not found: \(path). Recovery: use file(action:\"list\") to find the file."
            }
            let old = input["old_string"] as? String ?? ""
            guard !old.isEmpty else { return "Error: old_string is required for edit_file. Recovery: read the file first, copy the exact text to replace." }
            let new = input["new_string"] as? String ?? ""
            let replaceAll = input["replace_all"] as? Bool ?? false
            let context = input["context"] as? String
            let tabID = selectedTabId ?? Self.mainTabID
            // Duplicate edit rejection — if the exact same (file, old_string) pair was attempted
            // on the previous turn, the LLM is stuck in a loop. Reject at the code level.
            if Self.checkDuplicateEdit(tabID: tabID, filePath: expanded, oldString: old) {
                return "Error: Duplicate edit rejected — you just tried the exact same old_string on this file and it failed. Recovery: re-read the file to get fresh content, then use a different old_string or try diff_and_apply with start_line/end_line instead."
            }
            FileBackupService.shared.backup(filePath: expanded, tabID: tabID)
            Self.recordFileEdit(tabID: tabID, filePath: expanded)
            return await Self.offMain {
                CodingService.editFile(path: expanded, oldString: old, newString: new, replaceAll: replaceAll, context: context)
            }
        // MARK: create_diff
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
            return "diff_id: \(diffId.uuidString)\n\n\(d1f)"
        // MARK: apply_diff
        case "apply_diff":
            let path = input["file_path"] as? String ?? ""
            let diffIdStr = input["diff_id"] as? String ?? ""
            let asciiDiff = input["diff"] as? String ?? ""
            let expanded = (path as NSString).expandingTildeInPath
            guard let data = FileManager.default.contents(atPath: expanded),
                  let source = String(data: data, encoding: .utf8) else { return "Error: cannot read \(path). Recovery: use file(action:\"list\") to verify the file exists." }
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
                try patched.write(to: URL(fileURLWithPath: expanded), atomically: true, encoding: .utf8)
                Self.recordFileEdit(tabID: selectedTabId ?? Self.mainTabID, filePath: expanded)
                let verifyDiff = MultiLineDiff.createAndDisplayDiff(source: source, destination: patched, format: .ai)
                return "Applied diff to \(path)\n\n\(verifyDiff)"
            } catch {
                return "Error applying diff: \(error.localizedDescription). Recovery: re-read the file and create a new diff."
            }
        // List/search files (via User LaunchAgent - no TCC required)
        case "list_files":
            let rawPat = input["pattern"] as? String ?? "*.swift"
            // Reject wildcard-only patterns — too broad, suggest specific extension
            if rawPat == "*" || rawPat == "*.*" || rawPat.isEmpty {
                return "Error: pattern too broad. Recovery: use an extension like pattern:\"*.swift\" or pattern:\"*.xcodeproj\". For directories use read_dir."
            }
            let pat = CodingService.shellEscape(rawPat)
            let rawDir = input["path"] as? String ?? pf
            let displayDir = CodingService.trimHome(rawDir)
            let findCmd =
                "find . -maxdepth 8 \\( -type f -o -type d \\) -name \(pat)"
                + " ! -path '*/.*' ! -path '*/.build/*'"
                + " ! -path '*/.git/*' ! -path '*/.swiftpm/*'"
                + " ! -name '.DS_Store' ! -name '*.xcuserstate'"
                + " 2>/dev/null | sed 's|^\\./||' | sort | head -100"
            let result = await executeViaUserAgent(
                command: findCmd,
                workingDirectory: rawDir, silent: true)
            let raw = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty {
                return "No files found"
            }
            return """
                [project folder: \(displayDir)] \
                paths are relative to project folder
                \(CodingService.formatFileTree(raw))
                """
        case "search_files":
            let pat = CodingService.shellEscape(input["pattern"] as? String ?? "")
            let rawDir = input["path"] as? String ?? pf
            let displayDir = CodingService.trimHome(rawDir)
            let escapedDir = CodingService.shellEscape(rawDir)
            let result = await executeViaUserAgent(command: "grep -rn \(pat) \(escapedDir) 2>/dev/null | head -50")
            if result.output.isEmpty {
                return "No matches"
            }
            return """
                [project folder: \(displayDir)] \
                paths are relative to project folder
                \(result.output)
                """
        case "read_dir":
            let rawDir = input["path"] as? String ?? pf
            let displayDir = CodingService.trimHome(rawDir)
            let detail = (input["detail"] as? String ?? "slim") == "more"
            let cmd = detail
                ? "ls -la . 2>/dev/null"
                : "find . -maxdepth 1 -not -name '.*' 2>/dev/null | sed 's|^\\./||' | sort"
            let result = await executeViaUserAgent(command: cmd, workingDirectory: rawDir, silent: !detail)
            let raw = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? "Directory not found or empty" : "[project folder: \(displayDir)]\n\(raw)"
        case "mkdir":
            let rawPath = input["path"] as? String ?? ""
            guard !rawPath.isEmpty else { return "Error: path is required for mkdir. Recovery: pass path:\"/dir/to/create\"." }
            let stripped = rawPath.hasPrefix("./") ? String(rawPath.dropFirst(2)) : rawPath
            let resolved = stripped.hasPrefix("/") || stripped.hasPrefix("~")
                ? (stripped as NSString).expandingTildeInPath
                : (pf as NSString).appendingPathComponent(stripped)
            let escaped = CodingService.shellEscape(resolved)
            let result = await executeViaUserAgent(command: "mkdir -p \(escaped) && echo 'Created: \(resolved)'")
            let out = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if out.hasPrefix("Created:") {
                projectFolder = resolved
                return "\(out)\nProject folder set to: \(resolved)"
            }
            return out.isEmpty ? "Error creating directory" : out
        case "if_to_switch":
            let filePath = input["file_path"] as? String ?? ""
            return await Self.offMain { CodingService.convertIfToSwitch(path: filePath) }
        case "extract_function":
            let filePath = input["file_path"] as? String ?? ""
            let funcName = input["function_name"] as? String ?? ""
            let newFile = input["new_file"] as? String ?? ""
            return await Self.offMain {
                CodingService.extractFunctionToFile(
                    sourcePath: filePath,
                    functionName: funcName,
                    newFileName: newFile)
            }
        case "symbol_search":
            let query = input["query"] as? String ?? ""
            let path = input["path"] as? String ?? pf
            let exact = input["exact"] as? Bool ?? false
            guard !query.isEmpty else { return "Error: query is required" }
            let results = SymbolSearchService.search(query: query, in: path, exactMatch: exact)
            if results.isEmpty { return "No symbols found matching '\(query)'" }
            return results.prefix(50).map { r in
                "\(r.kind) \(r.name) — \(r.filePath):\(r.line)\n  \(r.signature)"
            }.joined(separator: "\n")
        // AST-based multi-file rename using Swift-Syntax
        case "refactor_rename":
            let oldName = input["old_name"] as? String ?? ""
            let newName = input["new_name"] as? String ?? ""
            let path = input["path"] as? String ?? pf
            guard !oldName.isEmpty && !newName.isEmpty else { return "Error: old_name and new_name required." }
            // Find all occurrences using symbol search
            let occurrences = SymbolSearchService.search(query: oldName, in: path, exactMatch: true)
            if occurrences.isEmpty { return "No symbols found matching '\(oldName)'" }
            // Perform rename across all files
            var renamedFiles: Set<String> = []
            var errors: [String] = []
            for occ in occurrences {
                let filePath = occ.filePath
                guard let data = FileManager.default.contents(atPath: filePath),
                      var content = String(data: data, encoding: .utf8) else { continue }
                let before = content
                // Word-boundary replacement to avoid partial matches
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: oldName))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    content = regex.stringByReplacingMatches(
                        in: content,
                        range: NSRange(content.startIndex..., in: content),
                        withTemplate: newName)
                }
                if content != before {
                    FileBackupService.shared.backup(filePath: filePath, tabID: selectedTabId ?? Self.mainTabID)
                    do {
                        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
                        renamedFiles.insert((filePath as NSString).lastPathComponent)
                    } catch {
                        errors.append("\(filePath): \(error.localizedDescription)")
                    }
                }
            }
            if renamedFiles.isEmpty && errors.isEmpty { return "No changes needed — '\(oldName)' not found in source files." }
            var result = "Renamed '\(oldName)' → '\(newName)' in \(renamedFiles.count) file(s):\n"
            result += renamedFiles.sorted().joined(separator: "\n")
            if !errors.isEmpty { result += "\n\nErrors:\n" + errors.joined(separator: "\n") }
            return result
        // undo_edit
        case "undo_edit":
            let fp = input["file_path"] as? String ?? ""
            let expanded = (fp as NSString).expandingTildeInPath
            guard let original = DiffStore.shared.lastEdit(for: expanded) else {
                return "Error: no edit history for \(fp). Recovery: call file(action:\"restore\", file_path:\"\(fp)\") to recover the most recent FileBackupService snapshot, or git checkout if the file is in a repo."
            }
            let result = CodingService.undoEdit(path: fp, originalContent: original)
            if !result.hasPrefix("Error") { DiffStore.shared.clearEditHistory(for: expanded) }
            return result
        // restore_file — recover the most recent FileBackupService snapshot for a file
        case "restore_file":
            let fp = input["file_path"] as? String ?? ""
            let backupName = input["backup"] as? String
            let expanded = (fp as NSString).expandingTildeInPath
            let fileName = (expanded as NSString).lastPathComponent
            let tabID = selectedTabId ?? Self.mainTabID
            let backups = FileBackupService.shared.listBackups(tabID: tabID)
                .filter { $0.original == fileName }
            if let explicit = backupName {
                guard let match = backups.first(where: { ($0.backup as NSString).lastPathComponent == explicit }) else {
                    return "Error: backup '\(explicit)' not found for \(fileName). Recovery: call file(action:\"list_backups\", file_path:\"\(fp)\") to see available backups."
                }
                if FileBackupService.shared.restore(backupPath: match.backup, to: expanded) {
                    return "Restored \(fileName) from \(explicit)."
                }
                return "Error: failed to restore from \(explicit). Recovery: try a different backup via file(action:\"list_backups\", file_path:\"\(fp)\")."
            }
            guard let latest = backups.first else {
                return "Error: no backups found for \(fileName). Recovery: file backups are tab-scoped and 1-week TTL — try undo_edit if the change was very recent, or git checkout if the file is in a repo."
            }
            if FileBackupService.shared.restore(backupPath: latest.backup, to: expanded) {
                return "Restored \(fileName) from latest backup (\(latest.date))."
            }
            return "Error: failed to restore latest backup of \(fileName). Recovery: call file(action:\"list_backups\", file_path:\"\(fp)\") to see other backups, or use undo_edit if recent."
        // list_file_backups — show what's in the FileBackupService TTL store for this tab
        case "list_file_backups":
            let fp = input["file_path"] as? String ?? ""
            let expanded = (fp as NSString).expandingTildeInPath
            let fileName = (expanded as NSString).lastPathComponent
            let tabID = selectedTabId ?? Self.mainTabID
            let backups = FileBackupService.shared.listBackups(tabID: tabID)
                .filter { fileName.isEmpty || $0.original == fileName }
            if backups.isEmpty {
                return fileName.isEmpty
                    ? "No file backups in this tab."
                    : "No backups found for \(fileName)."
            }
            return backups.map { "\(($0.backup as NSString).lastPathComponent)  (\($0.date))" }.joined(separator: "\n")
        // diff_and_apply
        case "diff_and_apply":
            let fp = input["file_path"] as? String ?? ""
            // Back up before diff_and_apply
            FileBackupService.shared.backup(filePath: fp, tabID: selectedTabId ?? Self.mainTabID)
            let dest = input["destination"] as? String ?? ""
            let source = input["source"] as? String
            let startLine = input["start_line"] as? Int
            let endLine = input["end_line"] as? Int
            let result = CodingService.diffAndApply(path: fp, source: source, destination: dest, startLine: startLine, endLine: endLine)
            if !result.output.hasPrefix("Error") && !result.output.hasPrefix("❌") {
                Self.recordFileEdit(tabID: selectedTabId ?? Self.mainTabID, filePath: (fp as NSString).expandingTildeInPath)
            }
            return result.output
        default:
            return nil
        }
    }

    /// Resolve `source` to an NSImage. Accepts "clipboard", "chat[:index]", or a file path.
    private func resolveImageSource(_ source: String) -> (image: NSImage?, label: String) {
        let s = source.lowercased()
        if s == "clipboard" || s == "pasteboard" {
            let img = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage
            return (img, "clipboard")
        }
        if s == "chat" || s.hasPrefix("chat:") {
            var idx = 0
            if let colon = s.firstIndex(of: ":") {
                let tail = String(s[s.index(after: colon)...])
                idx = Int(tail) ?? 0
            }
            let imgs = selectedTabId.flatMap { tab(for: $0) }?.taskScopeImages ?? taskScopeImages
            guard imgs.indices.contains(idx) else {
                return (nil, "chat[\(idx)] (have \(imgs.count))")
            }
            return (imgs[idx], "chat[\(idx)]")
        }
        // Treat as a file path
        var path = (source as NSString).expandingTildeInPath
        if !path.hasPrefix("/"), !projectFolder.isEmpty {
            path = (projectFolder as NSString).appendingPathComponent(path)
        }
        guard FileManager.default.fileExists(atPath: path) else { return (nil, path) }
        return (NSImage(contentsOfFile: path), path)
    }

    /// Write an NSImage out to destination: clipboard or a file path (PNG/JPEG by extension).
    private func writeImage(_ image: NSImage, to destination: String) -> String {
        let d = destination.lowercased()
        if d == "clipboard" || d == "pasteboard" {
            NSPasteboard.general.clearContents()
            let ok = NSPasteboard.general.writeObjects([image])
            if ok { return "" }
            return "Error: clipboard write failed. Recovery: retry, or write to a file path instead of 'clipboard'."
        }
        var destPath = (destination as NSString).expandingTildeInPath
        if !destPath.hasPrefix("/"), !projectFolder.isEmpty {
            destPath = (projectFolder as NSString).appendingPathComponent(destPath)
        }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return "Error: could not encode source image. Recovery: try a different source or destination."
        }
        let ext = (destPath as NSString).pathExtension.lowercased()
        let fileType: NSBitmapImageRep.FileType = (ext == "jpg" || ext == "jpeg") ? .jpeg : .png
        guard let data = rep.representation(using: fileType, properties: [:]) else {
            return "Error: encoding as \(fileType == .jpeg ? "JPEG" : "PNG") failed. Recovery: use a .png or .jpg extension on dest."
        }
        let url = URL(fileURLWithPath: destPath)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try data.write(to: url)
            return ""
        } catch {
            return "Error writing to \(destPath): \(error.localizedDescription). Recovery: check the directory is writable."
        }
    }

    /// copy_image dispatch body — used by the native-tool handler above. Returns a human-readable status string.
    func handleCopyImage(source: String, destination: String) async -> String {
        guard !source.isEmpty else {
            return "Error: source is required for copy_image. Pass source:\"clipboard\" | \"chat\" | \"chat:0\" | \"/abs/path.png\"."
        }
        let (img, srcLabel) = resolveImageSource(source)
        guard let image = img else {
            return "Error: no image available at \(srcLabel). Recovery: for source=\"clipboard\" copy an image first; for source=\"chat\" attach a screenshot; for a file path verify it exists and is PNG/JPEG."
        }
        let writeErr = writeImage(image, to: destination)
        if !writeErr.isEmpty { return writeErr }
        let destLabel = (destination.lowercased() == "clipboard" || destination.lowercased() == "pasteboard") ? "clipboard" : destination
        return "Copied image from \(srcLabel) to \(destLabel)."
    }
}
