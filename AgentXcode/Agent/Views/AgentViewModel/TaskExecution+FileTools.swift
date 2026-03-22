import Foundation
import MultiLineDiff
import os.log

private let fileLog = Logger(subsystem: "Agent.app.toddbruss", category: "FileTools")

// MARK: - File Operation Tools (for Native Tool Handler)
extension AgentViewModel {

    // MARK: - Native File Tool Handlers
    
    /// Handle read_file tool for native tools
    func handleReadFile(input: [String: Any]) async -> String {
        let filePath = input["file_path"] as? String ?? ""
        let offset = input["offset"] as? Int
        let limit = input["limit"] as? Int
        
        return await Self.offMain {
            return CodingService.readFile(path: filePath, offset: offset, limit: limit)
        }
    }
    
    /// Handle write_file tool for native tools
    func handleWriteFile(input: [String: Any]) async -> String {
        let filePath = input["file_path"] as? String ?? ""
        let content = input["content"] as? String ?? ""
        
        return await Self.offMain {
            return CodingService.writeFile(path: filePath, content: content)
        }
    }
    
    /// Handle edit_file tool for native tools
    func handleEditFile(input: [String: Any]) async -> String {
        let filePath = input["file_path"] as? String ?? ""
        let oldString = input["old_string"] as? String ?? ""
        let newString = input["new_string"] as? String ?? ""
        let replaceAll = input["replace_all"] as? Bool ?? false
        
        return await Self.offMain {
            CodingService.editFile(path: filePath, oldString: oldString, newString: newString, replaceAll: replaceAll)
        }
    }
    
    // MARK: - Helper Functions
    
    /// Get language from file path for syntax highlighting
    nonisolated static func langFromPath(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "python"
        case "js": return "javascript"
        case "ts": return "typescript"
        case "java": return "java"
        case "kt": return "kotlin"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "c": return "c"
        case "cpp", "cc", "cxx": return "cpp"
        case "h": return "c"
        case "hpp": return "cpp"
        case "m": return "objc"
        case "mm": return "objc"
        case "sh", "bash": return "bash"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "md": return "markdown"
        case "html": return "html"
        case "css": return "css"
        case "sql": return "sql"
        default: return ""
        }
    }
    
    /// Preview text with line limit
    nonisolated static func preview(_ text: String, lines: Int) -> String {
        let allLines = text.components(separatedBy: "\n")
        if allLines.count <= lines {
            return text
        }
        return allLines.prefix(lines).joined(separator: "\n") + "\n... (\(allLines.count) lines total)"
    }
    
    /// Create code fence for syntax highlighting
    nonisolated static func codeFence(_ code: String, language: String) -> String {
        let lang = language.isEmpty ? "" : language
        return "```\(lang)\n\(code)\n```"
    }
}

// MARK: - Coding Service Helper (file operations)
enum CodingService {
    /// Read file contents with line numbers
    static func readFile(path: String, offset: Int?, limit: Int?) -> String {
        let expandedPath = (path as NSString).expandingTildeInPath
        
        guard let data = FileManager.default.contents(atPath: expandedPath) else {
            return "Error: cannot read \(path)"
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            return "Error: file is not valid UTF-8"
        }
        
        let lines = content.components(separatedBy: "\n")
        let startLine = max(1, (offset ?? 1))
        let maxLines = limit ?? 2000
        
        let startIdx = startLine - 1
        let endIdx = min(startIdx + maxLines, lines.count)
        
        if startIdx >= lines.count {
            return "Error: offset \(startLine) exceeds file length (\(lines.count) lines)"
        }
        
        let resultLines = lines[startIdx..<endIdx]
        var result = resultLines.enumerated().map { (idx, line) in
            "\(startLine + idx): \(line)"
        }.joined(separator: "\n")
        
        if endIdx < lines.count {
            result += "\n... (\(lines.count) lines total, showing lines \(startLine)-\(startLine + endIdx - startIdx - 1))"
        }
        
        return result
    }
    
    /// Write file contents
    static func writeFile(path: String, content: String) -> String {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        
        // Create parent directories if needed
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return "Wrote \(path)"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    /// Edit file by replacing exact string match
    static func editFile(path: String, oldString: String, newString: String, replaceAll: Bool) -> String {
        let expandedPath = (path as NSString).expandingTildeInPath
        
        guard oldString != newString else {
            return "Error: old_string and new_string are identical - no changes needed"
        }
        
        guard let data = FileManager.default.contents(atPath: expandedPath),
              let content = String(data: data, encoding: .utf8) else {
            return "Error: cannot read \(path)"
        }
        
        let occurrences = content.components(separatedBy: oldString).count - 1
        
        if occurrences == 0 {
            let trimmed = oldString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && content.contains(trimmed) {
                return "Error: old_string not found (exact match). A similar string exists in \(path) — check whitespace/indentation."
            }
            return "Error: old_string not found in \(path)"
        }
        
        if !replaceAll && occurrences > 1 {
            return "Error: old_string appears \(occurrences) times in \(path). Provide more context to make it unique, or set replace_all=true."
        }
        
        let updated: String
        if replaceAll {
            updated = content.replacingOccurrences(of: oldString, with: newString)
        } else {
            guard let range = content.range(of: oldString) else {
                return "Error: old_string not found in \(path)"
            }
            updated = content.replacingCharacters(in: range, with: newString)
        }
        
        do {
            try updated.write(to: URL(fileURLWithPath: expandedPath), atomically: true, encoding: .utf8)
            
            // Show D1F diff
            let diff = MultiLineDiff.createDiff(source: oldString, destination: newString, includeMetadata: true)
            var d1f = MultiLineDiff.displayDiff(diff: diff, source: oldString, format: .ai)
            if d1f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                d1f = "❌ " + oldString + "\n" + "✅ " + newString
            }
            let label = replaceAll ? "\(occurrences) occurrences" : "1 occurrence"
            var result = "Replaced \(label) in \(path)\n\n\(d1f)"
            if let meta = diff.metadata, let startLine = meta.sourceStartLine {
                result += "\n📍 Changes start at line \(startLine + 1)"
                if let total = meta.sourceTotalLines {
                    result += " (of \(total) lines)"
                }
            }
            return result
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    /// Build list files command
    static func buildListFilesCommand(pattern: String, path: String?) -> String {
        let dir = path ?? FileManager.default.homeDirectoryForCurrentUser.path
        return "find '\(dir)' -name '\(pattern)' ! -path '*/.build/*' ! -path '*/.git/*' 2>/dev/null | sort | head -100"
    }
    
    /// Build search files command
    static func buildSearchFilesCommand(pattern: String, path: String?, include: String?) -> String {
        let dir = path ?? FileManager.default.homeDirectoryForCurrentUser.path
        let includeArg = include.map { " --include='\($0)'" } ?? ""
        return "grep -rn '\(pattern)' '\(dir)'\(includeArg) 2>/dev/null | head -50"
    }
    
    /// Build git status command
    static func buildGitStatusCommand(path: String?) -> String {
        let dir = path ?? "."
        return "cd '\(dir)' && git status"
    }
    
    /// Build git diff command
    static func buildGitDiffCommand(path: String?, staged: Bool, target: String?) -> String {
        let dir = path ?? "."
        var cmd = "cd '\(dir)' && git diff"
        if staged { cmd += " --staged" }
        if let t = target { cmd += " \(t)" }
        return cmd
    }
    
    /// Build git log command
    static func buildGitLogCommand(path: String?, count: Int?) -> String {
        let dir = path ?? "."
        return "cd '\(dir)' && git log --oneline -\(count ?? 20)"
    }
    
    /// Build git commit command
    static func buildGitCommitCommand(path: String?, message: String, files: [String]?) -> String {
        let dir = path ?? "."
        var cmd = "cd '\(dir)' && git add -A"
        if let files = files, !files.isEmpty {
            cmd = "cd '\(dir)' && git add \(files.map { "'\($0)'" }.joined(separator: " "))"
        }
        let escapedMessage = message.replacingOccurrences(of: "'", with: "'\\''")
        cmd += " && git commit -m '\(escapedMessage)'"
        return cmd
    }
    
    /// Build git branch command
    static func buildGitBranchCommand(path: String?, name: String, checkout: Bool) -> String {
        let dir = path ?? "."
        if name.isEmpty {
            return "cd '\(dir)' && git branch -a"
        }
        if checkout {
            return "cd '\(dir)' && git checkout -b '\(name)'"
        }
        return "cd '\(dir)' && git branch '\(name)'"
    }
    
    /// Default directory for file operations
    static var defaultDir: String {
        FileManager.default.homeDirectoryForCurrentUser.path
    }
    
    /// Shell escape a path
    static func shellEscape(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}