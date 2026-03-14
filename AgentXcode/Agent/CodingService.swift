import Foundation

/// Pure file operations for coding tools — no shell, no Process, no escaping issues.
/// Process-based tools (list, search, git) route through UserService XPC instead.
enum CodingService {

    // MARK: - Read File

    /// Read file contents with line numbers (like `cat -n`).
    /// - Parameters:
    ///   - path: Absolute file path
    ///   - offset: 1-based line to start from (default 1)
    ///   - limit: Max lines to return (default 2000)
    static func readFile(path: String, offset: Int?, limit: Int?) -> String {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return "Error: file not found: \(path)"
        }

        // Check if it's a directory
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        if isDir.boolValue {
            return "Error: path is a directory, not a file: \(path)"
        }

        guard let data = FileManager.default.contents(atPath: url.path),
              let content = String(data: data, encoding: .utf8) else {
            return "Error: could not read file (binary or encoding issue): \(path)"
        }

        let lines = content.components(separatedBy: "\n")
        let startLine = max((offset ?? 1) - 1, 0)
        let maxLines = limit ?? 2000

        guard startLine < lines.count else {
            return "Error: offset \(startLine + 1) exceeds file length (\(lines.count) lines)"
        }

        let endLine = min(startLine + maxLines, lines.count)
        let slice = lines[startLine..<endLine]
        let lineNumWidth = String(endLine).count

        var result = ""
        for (i, line) in slice.enumerated() {
            let num = String(startLine + i + 1).padding(toLength: lineNumWidth, withPad: " ", startingAt: 0)
            result += "\(num)\t\(line)\n"
        }

        if endLine < lines.count {
            result += "... (\(lines.count - endLine) more lines)"
        }

        return result
    }

    // MARK: - Write File

    /// Create or overwrite a file.
    static func writeFile(path: String, content: String) -> String {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)

        // Create parent directories if needed
        let parent = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        } catch {
            return "Error: could not create directory \(parent.path): \(error.localizedDescription)"
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            let lines = content.components(separatedBy: "\n").count
            return "Wrote \(lines) lines to \(url.path)"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Edit File (exact string replacement)

    /// Replace exact text in a file. The old_string must be unique unless replace_all is true.
    static func editFile(path: String, oldString: String, newString: String, replaceAll: Bool) -> String {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return "Error: file not found: \(path)"
        }

        guard let data = FileManager.default.contents(atPath: url.path),
              var content = String(data: data, encoding: .utf8) else {
            return "Error: could not read file: \(path)"
        }

        guard oldString != newString else {
            return "Error: old_string and new_string are identical"
        }

        let occurrences = content.components(separatedBy: oldString).count - 1

        if occurrences == 0 {
            // Try to give a helpful hint
            let trimmed = oldString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && content.contains(trimmed) {
                return "Error: old_string not found (exact match). A similar string exists — check whitespace/indentation."
            }
            return "Error: old_string not found in \(path)"
        }

        if !replaceAll && occurrences > 1 {
            return "Error: old_string appears \(occurrences) times. Provide more context to make it unique, or set replace_all=true."
        }

        if replaceAll {
            content = content.replacingOccurrences(of: oldString, with: newString)
        } else {
            // Replace first occurrence only
            if let range = content.range(of: oldString) {
                content.replaceSubrange(range, with: newString)
            }
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            let label = replaceAll ? "\(occurrences) occurrence(s)" : "1 occurrence"
            return "Replaced \(label) in \(url.path)"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Shell Command Builders (testable, executed via UserService XPC)

    /// Default directory for tools when no path is provided.
    static let defaultDir = FileManager.default.homeDirectoryForCurrentUser.path

    /// Shell-escape a string using single quotes (POSIX safe).
    static func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func buildListFilesCommand(pattern: String, path: String?) -> String {
        let dir = shellEscape(path ?? defaultDir)
        let pat = shellEscape(pattern)
        return "find \(dir) -maxdepth 10 -name \(pat) -not -path '*/.*' -not -path '*/.build/*' 2>/dev/null | sort | head -200"
    }

    static func buildSearchFilesCommand(pattern: String, path: String?, include: String?) -> String {
        let dir = shellEscape(path ?? defaultDir)
        let pat = shellEscape(pattern)
        var cmd = "grep -rn --color=never"
        if let include {
            cmd += " --include=\(shellEscape(include))"
        }
        cmd += " --exclude-dir=.git --exclude-dir=.build --exclude-dir=node_modules --exclude-dir=DerivedData"
        cmd += " \(pat) \(dir) 2>/dev/null | head -100"
        return cmd
    }

    static func buildGitStatusCommand(path: String?) -> String {
        let dir = shellEscape(path ?? defaultDir)
        return "cd \(dir) && echo \"Branch: $(git branch --show-current)\" && git status --short"
    }

    static func buildGitDiffCommand(path: String?, staged: Bool, target: String?) -> String {
        let dir = shellEscape(path ?? defaultDir)
        var cmd = "cd \(dir) && git diff --stat -p"
        if staged { cmd += " --cached" }
        if let target { cmd += " \(shellEscape(target))" }
        return cmd
    }

    static func buildGitLogCommand(path: String?, count: Int?) -> String {
        let dir = shellEscape(path ?? defaultDir)
        let n = min(count ?? 20, 100)
        return "cd \(dir) && git log --oneline --no-decorate -\(n)"
    }

    static func buildGitCommitCommand(path: String?, message: String, files: [String]?) -> String {
        let dir = shellEscape(path ?? defaultDir)
        var cmd = "cd \(dir)"
        if let files, !files.isEmpty {
            let escaped = files.map { shellEscape($0) }.joined(separator: " ")
            cmd += " && git add \(escaped)"
        } else {
            cmd += " && git add -A"
        }
        cmd += " && git diff --cached --quiet && echo 'Nothing to commit (no staged changes)' || git commit -m \(shellEscape(message))"
        return cmd
    }

    static func buildGitBranchCommand(path: String?, name: String, checkout: Bool) -> String {
        let dir = shellEscape(path ?? defaultDir)
        if checkout {
            return "cd \(dir) && git checkout -b \(shellEscape(name))"
        } else {
            return "cd \(dir) && git branch \(shellEscape(name))"
        }
    }
}
