import Foundation

/// Pure file operations for coding tools — no shell, no escaping issues.
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

    // MARK: - List Files (glob)

    /// Find files matching a glob pattern under a directory.
    static func listFiles(pattern: String, path: String?) -> String {
        let baseDir = (path ?? FileManager.default.currentDirectoryPath) as NSString
        let basePath = baseDir.expandingTildeInPath

        // Use /usr/bin/find for glob matching since Foundation doesn't have native glob
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        process.arguments = [basePath, "-name", pattern, "-not", "-path", "*/.*", "-not", "-path", "*/.build/*"]
        process.currentDirectoryURL = URL(fileURLWithPath: basePath)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "Error: \(error.localizedDescription)"
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        let files = output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .sorted()

        if files.isEmpty {
            return "No files matching '\(pattern)' in \(basePath)"
        }

        var result = "Found \(files.count) file(s):\n"
        for file in files.prefix(200) {
            result += "\(file)\n"
        }
        if files.count > 200 {
            result += "... (\(files.count - 200) more)"
        }
        return result
    }

    // MARK: - Search Files (grep)

    /// Search file contents by regex pattern.
    static func searchFiles(pattern: String, path: String?, include: String?) -> String {
        let baseDir = (path ?? FileManager.default.currentDirectoryPath) as NSString
        let basePath = baseDir.expandingTildeInPath

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        var args = ["-rn", "--color=never"]

        if let include {
            args += ["--include=\(include)"]
        }

        // Exclude common noise
        args += ["--exclude-dir=.git", "--exclude-dir=.build", "--exclude-dir=node_modules",
                 "--exclude-dir=DerivedData"]
        args += [pattern, basePath]

        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "Error: \(error.localizedDescription)"
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

        if lines.isEmpty {
            return "No matches for '\(pattern)' in \(basePath)"
        }

        var result = "Found \(lines.count) match(es):\n"
        for line in lines.prefix(100) {
            result += "\(line)\n"
        }
        if lines.count > 100 {
            result += "... (\(lines.count - 100) more matches)"
        }
        return result
    }

    // MARK: - Git Operations

    /// Run a git command and return its output.
    private static func runGit(_ args: [String], in directory: String? = nil) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args

        if let dir = directory {
            process.currentDirectoryURL = URL(fileURLWithPath: (dir as NSString).expandingTildeInPath)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, "Error: \(error.localizedDescription)")
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        var output = String(data: stdoutData, encoding: .utf8) ?? ""
        let errStr = String(data: stderrData, encoding: .utf8) ?? ""
        if !errStr.isEmpty {
            if !output.isEmpty { output += "\n" }
            output += errStr
        }

        return (process.terminationStatus, output)
    }

    /// Git status: branch, staged, unstaged, untracked.
    static func gitStatus(path: String?) -> String {
        let dir = path ?? FileManager.default.currentDirectoryPath
        let branch = runGit(["branch", "--show-current"], in: dir)
        let status = runGit(["status", "--short"], in: dir)

        var result = "Branch: \(branch.output.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        if status.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result += "Working tree clean"
        } else {
            result += status.output
        }
        return result
    }

    /// Git diff: show changes. Supports staged, unstaged, or between refs.
    static func gitDiff(path: String?, staged: Bool, target: String?) -> String {
        let dir = path ?? FileManager.default.currentDirectoryPath
        var args = ["diff", "--stat", "-p"]
        if staged {
            args.append("--cached")
        }
        if let target {
            args.append(target)
        }
        let result = runGit(args, in: dir)

        if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return staged ? "No staged changes" : "No changes"
        }

        // Truncate very large diffs
        if result.output.count > 50_000 {
            return String(result.output.prefix(50_000)) + "\n...(diff truncated)"
        }
        return result.output
    }

    /// Git log: recent commit history.
    static func gitLog(path: String?, count: Int?) -> String {
        let dir = path ?? FileManager.default.currentDirectoryPath
        let n = min(count ?? 20, 100)
        let result = runGit(["log", "--oneline", "--no-decorate", "-\(n)"], in: dir)

        if result.status != 0 {
            return "Error: \(result.output)"
        }
        return result.output
    }

    /// Git commit: stage specified files (or all) and commit.
    static func gitCommit(path: String?, message: String, files: [String]?) -> String {
        let dir = path ?? FileManager.default.currentDirectoryPath

        // Stage files
        if let files, !files.isEmpty {
            let addResult = runGit(["add"] + files, in: dir)
            if addResult.status != 0 {
                return "Error staging files: \(addResult.output)"
            }
        } else {
            let addResult = runGit(["add", "-A"], in: dir)
            if addResult.status != 0 {
                return "Error staging: \(addResult.output)"
            }
        }

        // Check there's something to commit
        let status = runGit(["diff", "--cached", "--quiet"], in: dir)
        if status.status == 0 {
            return "Nothing to commit (no staged changes)"
        }

        // Commit
        let result = runGit(["commit", "-m", message], in: dir)
        if result.status != 0 {
            return "Commit failed: \(result.output)"
        }
        return result.output
    }

    /// Git diff-patch: apply a unified diff patch to a file.
    static func gitApplyPatch(path: String?, patch: String) -> String {
        let dir = path ?? FileManager.default.currentDirectoryPath

        // Write patch to temp file
        let tempPath = NSTemporaryDirectory() + "agent_patch_\(UUID().uuidString).patch"
        do {
            try patch.write(toFile: tempPath, atomically: true, encoding: .utf8)
        } catch {
            return "Error writing patch: \(error.localizedDescription)"
        }
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let result = runGit(["apply", "--verbose", tempPath], in: dir)
        if result.status != 0 {
            return "Patch failed: \(result.output)"
        }
        return result.output.isEmpty ? "Patch applied successfully" : result.output
    }

    /// Git create branch and optionally switch to it.
    static func gitBranch(path: String?, name: String, checkout: Bool) -> String {
        let dir = path ?? FileManager.default.currentDirectoryPath

        if checkout {
            let result = runGit(["checkout", "-b", name], in: dir)
            return result.status == 0
                ? "Created and switched to branch '\(name)'"
                : "Error: \(result.output)"
        } else {
            let result = runGit(["branch", name], in: dir)
            return result.status == 0
                ? "Created branch '\(name)'"
                : "Error: \(result.output)"
        }
    }
}
