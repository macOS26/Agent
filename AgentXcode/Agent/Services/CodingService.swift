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
        // Exclude large non-project dirs that cause XPC timeouts when searching ~/
        return "find \(dir) -maxdepth 8 -name \(pat)"
            + " -not -path '*/.*'"
            + " -not -path '*/.build/*'"
            + " -not -path '*/Library/*'"
            + " -not -path '*/Movies/*'"
            + " -not -path '*/Music/*'"
            + " -not -path '*/Pictures/*'"
            + " -not -path '*/DerivedData/*'"
            + " 2>/dev/null | head -200 | sort"
    }

    static func buildSearchFilesCommand(pattern: String, path: String?, include: String?) -> String {
        let dir = shellEscape(path ?? defaultDir)
        let pat = shellEscape(pattern)
        var cmd = "grep -rn --color=never"
        if let include {
            cmd += " --include=\(shellEscape(include))"
        }
        cmd += " --exclude-dir=.git --exclude-dir=.build --exclude-dir=node_modules --exclude-dir=DerivedData --exclude-dir=Library --exclude-dir=Movies --exclude-dir=Music --exclude-dir=Pictures"
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

    // MARK: - Split File

    /// Split a Swift file into separate files by top-level declarations.
    /// Each extension, class, struct, enum, or top-level func becomes its own file.
    /// Returns a summary of created files.
    static func splitFile(path: String, deleteOriginal: Bool = false) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        guard let data = FileManager.default.contents(atPath: expanded),
              let source = String(data: data, encoding: .utf8) else {
            return "Error: cannot read \(path)"
        }

        let lines = source.components(separatedBy: "\n")
        let baseName = (expanded as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let dir = (expanded as NSString).deletingLastPathComponent

        // Collect import lines and top-level comments before first declaration
        var imports = [String]()
        var headerComments = [String]()
        var declarations: [(name: String, startLine: Int, lines: [String])] = []
        var currentDecl: (name: String, startLine: Int, lines: [String])?
        var braceDepth = 0
        var inHeader = true

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Collect imports
            if trimmed.hasPrefix("import ") {
                imports.append(line)
                inHeader = false
                continue
            }

            // Collect header comments before any declaration
            if inHeader && (trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") || trimmed.isEmpty) {
                headerComments.append(line)
                continue
            }
            inHeader = false

            // Detect top-level declaration start (brace depth == 0)
            if braceDepth == 0 {
                let isDecl = trimmed.hasPrefix("extension ") || trimmed.hasPrefix("class ") ||
                             trimmed.hasPrefix("struct ") || trimmed.hasPrefix("enum ") ||
                             trimmed.hasPrefix("@") || trimmed.hasPrefix("public extension ") ||
                             trimmed.hasPrefix("public class ") || trimmed.hasPrefix("public struct ") ||
                             trimmed.hasPrefix("public enum ") || trimmed.hasPrefix("final class ") ||
                             trimmed.hasPrefix("private extension ") || trimmed.hasPrefix("internal extension ") ||
                             trimmed.hasPrefix("// MARK:")

                if isDecl && !trimmed.hasPrefix("// MARK:") {
                    // Save previous declaration
                    if let decl = currentDecl {
                        declarations.append(decl)
                    }
                    // Extract declaration name
                    let declName = extractDeclName(trimmed)
                    currentDecl = (name: declName, startLine: i + 1, lines: [line])
                } else if isDecl && trimmed.hasPrefix("// MARK:") {
                    // MARK comments attach to the next declaration
                    if currentDecl != nil {
                        currentDecl?.lines.append(line)
                    } else {
                        currentDecl = (name: "Header", startLine: i + 1, lines: [line])
                    }
                } else if currentDecl != nil {
                    currentDecl?.lines.append(line)
                }
            } else {
                currentDecl?.lines.append(line)
            }

            // Track brace depth
            braceDepth += line.filter({ $0 == "{" }).count
            braceDepth -= line.filter({ $0 == "}" }).count
            braceDepth = max(0, braceDepth)
        }

        // Save last declaration
        if let decl = currentDecl {
            declarations.append(decl)
        }

        guard !declarations.isEmpty else {
            return "No top-level declarations found in \(path)"
        }

        // If only one declaration, nothing to split
        if declarations.count == 1 {
            return "File has only 1 top-level declaration — nothing to split."
        }

        let fm = FileManager.default
        let importBlock = imports.joined(separator: "\n")
        var createdFiles: [String] = []

        for (index, decl) in declarations.enumerated() {
            let suffix = sanitizeDeclName(decl.name)
            let fileName: String
            if index == 0 && decl.name == "Header" {
                continue // Skip standalone header comments
            }
            fileName = "\(baseName)+\(suffix).swift"
            let filePath = (dir as NSString).appendingPathComponent(fileName)

            var content = importBlock + "\n\n"
            content += decl.lines.joined(separator: "\n")
            content += "\n"

            do {
                try content.write(toFile: filePath, atomically: true, encoding: .utf8)
                let lineCount = decl.lines.count
                createdFiles.append("\(fileName) (\(lineCount) lines, starting at line \(decl.startLine))")
            } catch {
                createdFiles.append("Error writing \(fileName): \(error.localizedDescription)")
            }
        }

        if deleteOriginal {
            try? fm.removeItem(atPath: expanded)
            createdFiles.append("Deleted original: \((expanded as NSString).lastPathComponent)")
        }

        return "Split \(baseName).swift into \(createdFiles.count) files:\n" + createdFiles.joined(separator: "\n")
    }

    /// Extract a clean declaration name from a line like "extension AgentViewModel {"
    private static func extractDeclName(_ line: String) -> String {
        let tokens = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        // Skip modifiers: public, private, internal, final, @MainActor, etc.
        let skipPrefixes = ["public", "private", "internal", "final", "open", "@MainActor", "@Observable", "@objc", "@available", "@preconcurrency"]
        var nameIndex = 0
        for (i, token) in tokens.enumerated() {
            if skipPrefixes.contains(where: { token.hasPrefix($0) }) {
                continue
            }
            // The keyword (extension, class, struct, enum)
            if ["extension", "class", "struct", "enum", "protocol", "actor"].contains(token) {
                nameIndex = i + 1
                break
            }
            nameIndex = i
            break
        }
        if nameIndex < tokens.count {
            return tokens[nameIndex]
                .replacingOccurrences(of: "{", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        return "Part\(line.hashValue & 0xFFFF)"
    }

    /// Sanitize a declaration name for use as a filename suffix
    private static func sanitizeDeclName(_ name: String) -> String {
        let clean = name.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined()
        return clean.isEmpty ? "Part" : clean
    }
}
