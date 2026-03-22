@preconcurrency import Foundation
import MCPClient

// MARK: - Helper Functions

extension AgentViewModel {
    
    /// Convert Any to JSONValue, handling arrays and nested objects recursively.
    static func toJSONValue(_ value: Any) -> JSONValue {
        if let s = value as? String { return .string(s) }
        if let i = value as? Int { return .int(i) }
        if let d = value as? Double { return .double(d) }
        if let b = value as? Bool { return .bool(b) }
        if let arr = value as? [Any] { return .array(arr.map { toJSONValue($0) }) }
        if let dict = value as? [String: Any] { return .object(dict.mapValues { toJSONValue($0) }) }
        return .string(String(describing: value))
    }
    
    /// Generate a short name for auto-saving an AppleScript from its source.
    /// Uses the first meaningful words from the script, capped at 40 chars.
    static func autoScriptName(from source: String) -> String {
        let clean = source
            .replacingOccurrences(of: "tell application", with: "")
            .replacingOccurrences(of: "display dialog", with: "dialog")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = clean.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "_")
        let name = words.prefix(40)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        return name.isEmpty ? "untitled_\(Int(Date().timeIntervalSince1970))" : String(name)
    }
    
    /// Show first N lines of output, then "..." if there's more.
    static func preview(_ text: String, lines count: Int) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count <= count { return text.trimmingCharacters(in: .newlines) }
        return lines.prefix(count).joined(separator: "\n") + "\n..."
    }
    
    /// Wrap text in a markdown code fence with language tag for syntax highlighting.
    static func codeFence(_ text: String, language: String = "") -> String {
        "```\(language)\n\(text.trimmingCharacters(in: .newlines))\n```"
    }
    
    /// Guess language from file extension for syntax highlighting.
    static func langFromPath(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "python"
        case "js", "jsx": return "javascript"
        case "ts", "tsx": return "typescript"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "c", "h": return "c"
        case "cpp", "cc", "cxx", "hpp": return "cpp"
        case "m", "mm": return "objc"
        case "java": return "java"
        case "kt": return "kotlin"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "sql": return "sql"
        case "sh", "bash", "zsh": return "bash"
        case "html", "htm": return "html"
        case "css": return "css"
        case "xml", "plist": return "xml"
        default: return ""
        }
    }
    
    /// Validate that a path exists. Returns an error string if invalid, nil if OK.
    static func checkPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            return "Error: path does not exist: \(path) — check for typos"
        }
        return nil
    }
    
    /// Extract user-directory paths from a shell command for preflight validation.
    /// Catches typos like "/Users/foo/Documets/..." before running the command.
    /// Resolve project folder to a directory (strip filename if path points to a file).
    static func resolvedWorkingDirectory(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            return isDir.boolValue ? path : (path as NSString).deletingLastPathComponent
        }
        // Path doesn't exist yet — treat as directory
        return path
    }
    
    /// Set `PWD` for a shell command when a project folder is set.
    /// Skips if the command already starts with `cd `.
    static func prependWorkingDirectory(_ command: String, projectFolder: String) -> String {
        guard !projectFolder.isEmpty else { return command }
        let dir = resolvedWorkingDirectory(projectFolder)
        guard !dir.isEmpty, dir != "/" else { return command }
        if command.hasPrefix("cd ") { return command }
        let escaped = dir.replacingOccurrences(of: "'", with: "'\\''")
        return "export PWD='\(escaped)'; \(command)"
    }
    
    /// Extract the target directory from a command starting with `cd `.
    /// Resolves relative paths against the current project folder.
    static func extractCdTarget(_ command: String, relativeTo base: String) -> String? {
        guard command.hasPrefix("cd ") else { return nil }
        let afterCd = String(command.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        guard !afterCd.isEmpty else { return nil }
        // Extract path before any && or ;
        let path: String
        if let r = afterCd.range(of: "&&") {
            path = String(afterCd[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        } else if let r = afterCd.range(of: ";") {
            path = String(afterCd[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        } else {
            path = afterCd
        }
        // Strip surrounding quotes
        var cleaned = path
        if (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) ||
           (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        guard !cleaned.isEmpty else { return nil }
        // Expand ~
        if cleaned.hasPrefix("~/") || cleaned == "~" {
            cleaned = (cleaned as NSString).expandingTildeInPath
        }
        // Resolve relative paths against current project folder
        if !cleaned.hasPrefix("/") {
            let baseDir = resolvedWorkingDirectory(base)
            if !baseDir.isEmpty {
                cleaned = (baseDir as NSString).appendingPathComponent(cleaned)
            }
        }
        // Standardize (resolve .., .)
        cleaned = (cleaned as NSString).standardizingPath
        return cleaned
    }
    
    static func preflightCommand(_ command: String) -> String? {
        // Match paths under /Users/ or ~/ — most common source of typos
        guard let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)(/Users/[^\s'";&|><$]+|~/[^\s'";&|><$]+)"#
        ) else { return nil }
        let nsCmd = command as NSString
        let matches = regex.matches(in: command, range: NSRange(location: 0, length: nsCmd.length))
        for match in matches {
            var path = nsCmd.substring(with: match.range(at: 1))
                .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            // Strip trailing wildcards/globs for directory validation (e.g. /path/to/*)
            while path.hasSuffix("*") || path.hasSuffix("?") {
                path = String(path.dropLast())
            }
            if path.hasSuffix("/") { path = String(path.dropLast()) }
            guard !path.isEmpty else { continue }
            let expanded = (path as NSString).expandingTildeInPath
            if !FileManager.default.fileExists(atPath: expanded) {
                return "Error: path does not exist: \(path) — check for typos in the path"
            }
        }
        return nil
    }

    // MARK: - Command Watchdog

    static let deletionLimitOptions: [Int] = [0, 5, 10, 15, 20, 25]

    /// Checks a shell command for catastrophic or excessive file deletion.
    static func watchdogCheck(_ command: String, isPrivileged: Bool, deletionLimit: Int) -> String? {
        let lower: String = command.lowercased()
        let separators: CharacterSet = CharacterSet(charactersIn: ";|&")
        let subCommands: [String] = lower.components(separatedBy: separators)

        for sub in subCommands {
            let trimmed: String = sub.trimmingCharacters(in: .whitespaces)
            guard let rmRange = trimmed.range(of: "rm ") else { continue }
            let targets: [String] = extractRmTargets(trimmed, rmRange: rmRange)
            if targets.isEmpty { continue }

            if let err = checkCatastrophic(targets) { return err }
            if isPrivileged, let err = checkRootRestriction(targets) { return err }
            if !isPrivileged, let err = checkBulkDeletion(trimmed, rmRange: rmRange, targets: targets, limit: deletionLimit) { return err }
        }
        return nil
    }

    /// Extract non-flag target paths from an rm command.
    private static func extractRmTargets(_ sub: String, rmRange: Range<String.Index>) -> [String] {
        let afterRm: String = String(sub[rmRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        let parts: [String] = afterRm.components(separatedBy: .whitespaces)
        let targets: [String] = parts.filter { !$0.isEmpty && !$0.hasPrefix("-") }
        return targets
    }

    /// Block rm / and rm ~ (catastrophic deletion).
    private static func checkCatastrophic(_ targets: [String]) -> String? {
        let home: String = NSHomeDirectory().lowercased()
        for target in targets {
            let expanded: String
            if target == "~" {
                expanded = NSHomeDirectory()
            } else {
                expanded = (target as NSString).expandingTildeInPath
            }
            if expanded == "/" || target == "/" {
                return "WATCHDOG BLOCKED: refusing to delete root filesystem (/). This is a catastrophic operation."
            }
            if expanded.lowercased() == home || target == "~" {
                return "WATCHDOG BLOCKED: refusing to delete home directory (~). This is a catastrophic operation."
            }
        }
        return nil
    }

    /// Root daemon can only rm cache/tmp files.
    private static func checkRootRestriction(_ targets: [String]) -> String? {
        for target in targets {
            let expanded: String = (target as NSString).expandingTildeInPath.lowercased()
            let ok: Bool = expanded.contains("/cache")
                || expanded.contains("/caches")
                || expanded.contains("/tmp")
                || expanded.contains("/temp")
                || expanded.hasPrefix("/tmp")
                || expanded.hasPrefix("/var/tmp")
                || expanded.hasPrefix("/private/tmp")
                || expanded.hasPrefix("/private/var/folders")
            if !ok {
                return "WATCHDOG BLOCKED: root (daemon) is only allowed to remove cache or tmp files. Target: \(target)"
            }
        }
        return nil
    }

    /// Enforce file-count threshold for user rm commands.
    private static func checkBulkDeletion(_ sub: String, rmRange: Range<String.Index>, targets: [String], limit: Int) -> String? {
        guard limit >= 0 else { return nil }
        let afterRm: String = String(sub[rmRange.upperBound...])
        let hasRecursive: Bool = afterRm.contains("-r") || afterRm.contains("-R")
        let hasWildcard: Bool = afterRm.contains("*") || afterRm.contains("?")

        if hasRecursive || hasWildcard {
            for target in targets {
                let expanded: String = (target as NSString).expandingTildeInPath
                let fileCount: Int = countFilesAtPath(expanded, hasWildcard: hasWildcard)
                if fileCount > limit {
                    return "WATCHDOG BLOCKED: rm would affect ~\(fileCount) files, exceeding the limit of \(limit). Adjust in Options if intended."
                }
            }
        }
        if targets.count > limit {
            return "WATCHDOG BLOCKED: rm targets \(targets.count) files, exceeding the limit of \(limit). Adjust in Options if intended."
        }
        return nil
    }

    /// Count files at a path for watchdog threshold checks.
    private static func countFilesAtPath(_ path: String, hasWildcard: Bool) -> Int {
        let fm: FileManager = FileManager.default
        var isDir: ObjCBool = false

        if hasWildcard {
            let parent: String = (path as NSString).deletingLastPathComponent
            guard fm.fileExists(atPath: parent, isDirectory: &isDir), isDir.boolValue else { return 0 }
            let contents: [String]? = try? fm.contentsOfDirectory(atPath: parent)
            return contents?.count ?? 0
        }

        if fm.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue {
                guard let enumerator = fm.enumerator(atPath: path) else { return 0 }
                var count: Int = 0
                while enumerator.nextObject() != nil {
                    count += 1
                    if count > 10_000 { return count }
                }
                return count
            }
            return 1
        }
        return 0
    }

    // MARK: - Plan Mode

    private static let planFileName: String = "planning_mode_.md"

    /// Resolve the plan file path inside the project folder (or home).
    private static func planFilePath(_ projectFolder: String) -> String {
        let base: String = projectFolder.isEmpty ? NSHomeDirectory() : resolvedWorkingDirectory(projectFolder)
        return (base as NSString).appendingPathComponent(planFileName)
    }

    /// Handle plan_mode tool calls: create, update, or read a markdown plan file.
    static func handlePlanMode(action: String, input: [String: Any], projectFolder: String) -> String {
        let path: String = planFilePath(projectFolder)
        let fm: FileManager = FileManager.default

        switch action.lowercased() {
        case "create":
            guard let title = input["title"] as? String, !title.isEmpty else {
                return "Error: title is required for plan_mode create"
            }
            guard let stepsRaw = input["steps"] as? String, !stepsRaw.isEmpty else {
                return "Error: steps is required for plan_mode create"
            }
            let steps: [String] = stepsRaw.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            var md: String = "# \(title)\n\n"
            for (i, step) in steps.enumerated() {
                let num: Int = i + 1
                md += "- [ ] \(num). \(step)\n"
            }
            md += "\n---\n*Status: \(steps.count) steps pending*\n"
            do {
                try md.write(toFile: path, atomically: true, encoding: .utf8)
                return "Plan created: \(title) (\(steps.count) steps)\nFile: \(path)"
            } catch {
                return "Error writing plan: \(error.localizedDescription)"
            }

        case "update":
            guard let stepNum = input["step"] as? Int, stepNum > 0 else {
                return "Error: step number is required for plan_mode update"
            }
            guard let status = input["status"] as? String else {
                return "Error: status is required for plan_mode update (in_progress, completed, failed)"
            }
            guard fm.fileExists(atPath: path),
                  let data = fm.contents(atPath: path),
                  let content = String(data: data, encoding: .utf8) else {
                return "Error: no plan file found. Use plan_mode create first."
            }

            let marker: String
            switch status.lowercased() {
            case "in_progress": marker = "- [⏳]"
            case "completed": marker = "- [x]"
            case "failed": marker = "- [❌]"
            default: return "Error: invalid status. Use in_progress, completed, or failed."
            }

            var lines: [String] = content.components(separatedBy: "\n")
            let target: String = "\(stepNum)."
            var found: Bool = false
            for i in 0..<lines.count {
                let trimmed: String = lines[i].trimmingCharacters(in: .whitespaces)
                if trimmed.contains(target) && (trimmed.hasPrefix("- [") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [⏳]") || trimmed.hasPrefix("- [❌]")) {
                    // Replace the checkbox portion
                    if let bracketEnd = lines[i].range(of: "] ") {
                        let rest: String = String(lines[i][bracketEnd.upperBound...])
                        let indent: String = String(lines[i].prefix(while: { $0 == " " || $0 == "\t" }))
                        lines[i] = "\(indent)\(marker) \(rest)"
                        found = true
                        break
                    }
                }
            }

            guard found else {
                return "Error: step \(stepNum) not found in plan."
            }

            // Update status summary
            let completed: Int = lines.filter { $0.contains("- [x]") }.count
            let inProgress: Int = lines.filter { $0.contains("- [⏳]") }.count
            let failed: Int = lines.filter { $0.contains("- [❌]") }.count
            let total: Int = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("- [") }.count
            let pending: Int = total - completed - inProgress - failed

            // Replace or append status line
            if let statusIdx = lines.firstIndex(where: { $0.hasPrefix("*Status:") }) {
                lines[statusIdx] = "*Status: \(completed) done, \(inProgress) in progress, \(failed) failed, \(pending) pending*"
            }

            let updated: String = lines.joined(separator: "\n")
            do {
                try updated.write(toFile: path, atomically: true, encoding: .utf8)
                return "Step \(stepNum) → \(status)"
            } catch {
                return "Error writing plan: \(error.localizedDescription)"
            }

        case "read":
            guard fm.fileExists(atPath: path),
                  let data = fm.contents(atPath: path),
                  let content = String(data: data, encoding: .utf8) else {
                return "No plan file found. Use plan_mode create to start a plan."
            }
            return content

        default:
            return "Error: invalid action '\(action)'. Use create, update, or read."
        }
    }
}