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

    /// Split a Swift file into separate files.
    /// Modes: "declarations" (default) splits by top-level types/extensions.
    ///        "handlers" extracts `if name == "..."` tool handler blocks into separate functions.
    static func splitFile(path: String, deleteOriginal: Bool = false, mode: String = "declarations") -> String {
        let expanded = (path as NSString).expandingTildeInPath
        guard let data = FileManager.default.contents(atPath: expanded),
              let source = String(data: data, encoding: .utf8) else {
            return "Error: cannot read \(path)"
        }

        if mode == "handlers" {
            return splitToolHandlers(source: source, path: expanded, deleteOriginal: deleteOriginal)
        }

        let lines = source.components(separatedBy: "\n")
        let baseName = (expanded as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let dir = (expanded as NSString).deletingLastPathComponent

        // Collect ALL imports from entire file (not just top)
        var imports = [String]()
        var seenImports = Set<String>()
        // Collect file-level variables/constants (Logger, etc.) at brace depth 0
        var fileLevelVars = [String]()
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("import ") || trimmed.hasPrefix("@preconcurrency import ") {
                if seenImports.insert(trimmed).inserted { imports.append(trimmed) }
            }
        }
        // Scan for file-level let/var at brace depth 0
        var scanDepth = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if scanDepth == 0 && !trimmed.hasPrefix("import ") && !trimmed.hasPrefix("@preconcurrency") {
                if trimmed.hasPrefix("private let ") || trimmed.hasPrefix("private var ") ||
                   trimmed.hasPrefix("fileprivate let ") || trimmed.hasPrefix("fileprivate var ") ||
                   trimmed.hasPrefix("let ") || trimmed.hasPrefix("var ") ||
                   trimmed.hasPrefix("nonisolated(unsafe)") {
                    // File-level variable — needs to be in every split file
                    // Change private to internal for cross-file access
                    let fixed = line.replacingOccurrences(of: "private let ", with: "let ")
                        .replacingOccurrences(of: "private var ", with: "var ")
                        .replacingOccurrences(of: "fileprivate let ", with: "let ")
                        .replacingOccurrences(of: "fileprivate var ", with: "var ")
                    fileLevelVars.append(fixed)
                }
            }
            scanDepth += line.filter({ $0 == "{" }).count
            scanDepth -= line.filter({ $0 == "}" }).count
            scanDepth = max(0, scanDepth)
        }

        var headerComments = [String]()
        var declarations: [(name: String, startLine: Int, lines: [String])] = []
        var currentDecl: (name: String, startLine: Int, lines: [String])?
        var braceDepth = 0
        var inHeader = true

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip imports (already collected)
            if trimmed.hasPrefix("import ") || trimmed.hasPrefix("@preconcurrency import ") {
                inHeader = false
                continue
            }

            // Skip file-level vars (already collected)
            if braceDepth == 0 && (trimmed.hasPrefix("private let ") || trimmed.hasPrefix("private var ") ||
               trimmed.hasPrefix("fileprivate let ") || trimmed.hasPrefix("fileprivate var ") ||
               trimmed.hasPrefix("nonisolated(unsafe)")) {
                if !trimmed.hasPrefix("extension ") && !trimmed.hasPrefix("class ") &&
                   !trimmed.hasPrefix("struct ") && !trimmed.hasPrefix("enum ") {
                    continue
                }
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

        // If only one declaration (e.g. a single extension), split its children instead
        if declarations.count == 1 {
            let decl = declarations[0]
            let children = splitExtensionChildren(lines: decl.lines, extensionHeader: decl.name)
            if children.count <= 1 {
                return "File has only 1 top-level declaration with no splittable children."
            }
            declarations = children
        }

        let fm = FileManager.default
        let importBlock = imports.joined(separator: "\n")
        let fileLevelBlock = fileLevelVars.isEmpty ? "" : fileLevelVars.joined(separator: "\n") + "\n\n"
        var createdFiles: [String] = []
        var usedNames = Set<String>()

        for (index, decl) in declarations.enumerated() {
            var suffix = sanitizeDeclName(decl.name)
            if index == 0 && decl.name == "Header" {
                continue // Skip standalone header comments
            }
            // Deduplicate filenames
            let originalSuffix = suffix
            var counter = 2
            while usedNames.contains(suffix) {
                suffix = "\(originalSuffix)\(counter)"
                counter += 1
            }
            usedNames.insert(suffix)

            let fileName = "\(baseName)+\(suffix).swift"
            let filePath = (dir as NSString).appendingPathComponent(fileName)

            // Fix private → internal for cross-file access
            let fixedLines = decl.lines.map { line -> String in
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("private func ") { return line.replacingOccurrences(of: "private func ", with: "func ") }
                if t.hasPrefix("private static func ") { return line.replacingOccurrences(of: "private static func ", with: "static func ") }
                if t.hasPrefix("private var ") { return line.replacingOccurrences(of: "private var ", with: "var ") }
                if t.hasPrefix("private let ") { return line.replacingOccurrences(of: "private let ", with: "let ") }
                if t.hasPrefix("private enum ") { return line.replacingOccurrences(of: "private enum ", with: "enum ") }
                if t.hasPrefix("private struct ") { return line.replacingOccurrences(of: "private struct ", with: "struct ") }
                return line
            }

            var content = importBlock + "\n\n" + fileLevelBlock
            content += fixedLines.joined(separator: "\n")
            content += "\n"

            do {
                try content.write(toFile: filePath, atomically: true, encoding: .utf8)
                let lineCount = decl.lines.count
                createdFiles.append("\(fileName) (\(lineCount) lines)")
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

    /// Split the children of an extension/class into separate declarations.
    /// Each child func/enum/struct/class/var block at brace depth 1 becomes its own
    /// extension file with the parent wrapper preserved.
    private static func splitExtensionChildren(lines: [String], extensionHeader: String) -> [(name: String, startLine: Int, lines: [String])] {
        // Find the extension opening line and its closing brace
        guard let firstLine = lines.first else { return [] }

        // Extract the extension declaration line (e.g. "extension AgentViewModel {")
        var extensionLine = firstLine
        // If the first line doesn't contain "{", find it
        if !extensionLine.contains("{") {
            for line in lines {
                if line.contains("{") {
                    extensionLine = line
                    break
                }
            }
        }

        // Parse children at brace depth 1
        var children: [(name: String, startLine: Int, lines: [String])] = []
        var currentChild: (name: String, startLine: Int, lines: [String])?
        var braceDepth = 0
        var pendingComments: [String] = []

        let memberKeywords = ["func ", "var ", "let ", "enum ", "struct ", "class ", "actor ",
                              "protocol ", "typealias ", "static func ", "static var ", "static let ",
                              "private func ", "private var ", "private let ",
                              "private static func ", "private static var ",
                              "internal func ", "public func ", "nonisolated func ",
                              "@MainActor func ", "@MainActor static func ",
                              "@discardableResult"]

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Track braces
            let openBraces = line.filter({ $0 == "{" }).count
            let closeBraces = line.filter({ $0 == "}" }).count

            // At depth 1 (inside the extension), detect member declarations
            if braceDepth == 1 {
                let isMember = memberKeywords.contains(where: { trimmed.hasPrefix($0) })
                let isMark = trimmed.hasPrefix("// MARK:")
                let isComment = trimmed.hasPrefix("//") || trimmed.hasPrefix("///") || trimmed.hasPrefix("/*")

                if isMark || (isComment && currentChild == nil) {
                    pendingComments.append(line)
                } else if isMember {
                    // Save previous child
                    if let child = currentChild {
                        children.append(child)
                    }
                    // Extract member name
                    let memberName = extractMemberName(trimmed)
                    var childLines = pendingComments
                    childLines.append(line)
                    currentChild = (name: memberName, startLine: i + 1, lines: childLines)
                    pendingComments = []
                } else if currentChild != nil {
                    currentChild?.lines.append(line)
                } else if !trimmed.isEmpty && trimmed != "{" && trimmed != "}" {
                    // Stray line at depth 1 — attach to pending or ignore
                    pendingComments.append(line)
                }
            } else if braceDepth > 1 {
                // Inside a member body
                currentChild?.lines.append(line)
            }

            braceDepth += openBraces
            braceDepth -= closeBraces
            braceDepth = max(0, braceDepth)
        }

        // Save last child
        if let child = currentChild {
            children.append(child)
        }

        guard children.count > 1 else { return children }

        // Wrap each child in the extension declaration
        let extOpen = extensionLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return children.map { child in
            var wrapped = [String]()
            wrapped.append(extOpen.hasSuffix("{") ? extOpen : extOpen + " {")
            wrapped.append(contentsOf: child.lines)
            wrapped.append("}")
            return (name: child.name, startLine: child.startLine, lines: wrapped)
        }
    }

    /// Extract a member name from a line like "func executeTask(_ prompt: String) async {"
    private static func extractMemberName(_ line: String) -> String {
        let tokens = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let skipWords: Set<String> = ["func", "var", "let", "enum", "struct", "class", "actor",
                                       "protocol", "typealias", "static", "private", "internal",
                                       "public", "open", "final", "nonisolated", "override",
                                       "@MainActor", "@discardableResult", "@objc", "@available",
                                       "@preconcurrency", "lazy"]
        for token in tokens {
            if skipWords.contains(token) || token.hasPrefix("@") { continue }
            // Clean the name
            let name = token
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .replacingOccurrences(of: "{", with: "")
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "_", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return name }
        }
        return "Member"
    }

    // MARK: - Split Tool Handlers

    /// Extract `if name == "tool_name" { ... }` blocks from a large function
    /// into separate `handle_toolName()` functions, and replace the original
    /// if-blocks with calls to the new functions.
    private static func splitToolHandlers(source: String, path: String, deleteOriginal: Bool) -> String {
        let lines = source.components(separatedBy: "\n")
        let baseName = (path as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let dir = (path as NSString).deletingLastPathComponent

        // Find all `if name == "..."` blocks with their brace-matched bodies
        struct HandlerBlock {
            let toolName: String
            let startLine: Int    // 0-based
            let endLine: Int      // 0-based, inclusive
            let lines: [String]
        }

        var handlers: [HandlerBlock] = []
        let pattern = #"if\s+name\s*==\s*\"([^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return "Error: could not compile regex"
        }

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let nsLine = trimmed as NSString
            let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: nsLine.length))

            if let match = matches.first, match.numberOfRanges >= 2 {
                let toolName = nsLine.substring(with: match.range(at: 1))

                // Check this line has an opening brace
                if trimmed.contains("{") {
                    let startLine = i
                    var braceCount = line.filter({ $0 == "{" }).count - line.filter({ $0 == "}" }).count
                    var endLine = i

                    // Find matching closing brace
                    var j = i + 1
                    while j < lines.count && braceCount > 0 {
                        braceCount += lines[j].filter({ $0 == "{" }).count
                        braceCount -= lines[j].filter({ $0 == "}" }).count
                        endLine = j
                        j += 1
                    }

                    let blockLines = Array(lines[startLine...endLine])
                    // Only extract blocks with 3+ lines (skip trivial ones)
                    if blockLines.count >= 3 {
                        handlers.append(HandlerBlock(
                            toolName: toolName,
                            startLine: startLine,
                            endLine: endLine,
                            lines: blockLines
                        ))
                    }
                    i = endLine + 1
                    continue
                }
            }
            i += 1
        }

        guard !handlers.isEmpty else {
            return "No tool handler blocks found (looking for `if name == \"...\"` patterns)"
        }

        // Collect imports (trimmed, deduplicated)
        var seenHandlerImports = Set<String>()
        var handlerImports = [String]()
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("import ") || t.hasPrefix("@preconcurrency import ") {
                if seenHandlerImports.insert(t).inserted { handlerImports.append(t) }
            }
        }
        let importBlock = handlerImports.joined(separator: "\n")

        // Find the extension wrapper
        var extensionLine = ""
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("extension ") || t.hasPrefix("public extension ") || t.hasPrefix("private extension ") {
                extensionLine = t
                break
            }
        }

        let fm = FileManager.default
        var createdFiles: [String] = []

        // Group handlers by common prefix for reasonable file sizes
        // e.g. all "ax_*" handlers in one file, all "git_*" in another
        var groups: [String: [HandlerBlock]] = [:]
        for handler in handlers {
            let prefix: String
            if handler.toolName.contains("_") {
                prefix = String(handler.toolName.prefix(while: { $0 != "_" }))
            } else {
                prefix = handler.toolName
            }
            groups[prefix, default: []].append(handler)
        }

        // Write each group to a file
        for (prefix, groupHandlers) in groups.sorted(by: { $0.key < $1.key }) {
            let fileName = "\(baseName)+\(prefix)Handlers.swift"
            let filePath = (dir as NSString).appendingPathComponent(fileName)

            var content = importBlock + "\n\n"
            if !extensionLine.isEmpty {
                content += (extensionLine.hasSuffix("{") ? extensionLine : extensionLine + " {") + "\n\n"
            }

            for handler in groupHandlers {
                // Write the handler block as-is (preserving the if name == pattern)
                content += handler.lines.joined(separator: "\n") + "\n\n"
            }

            if !extensionLine.isEmpty {
                content += "}\n"
            }

            do {
                try content.write(toFile: filePath, atomically: true, encoding: .utf8)
                let toolNames = groupHandlers.map { $0.toolName }.joined(separator: ", ")
                let totalLines = groupHandlers.reduce(0) { $0 + $1.lines.count }
                createdFiles.append("\(fileName) (\(totalLines) lines: \(toolNames))")
            } catch {
                createdFiles.append("Error writing \(fileName): \(error.localizedDescription)")
            }
        }

        // Build the trimmed original with handler blocks removed
        var remainingLines = lines
        // Remove in reverse order to preserve indices
        for handler in handlers.sorted(by: { $0.startLine > $1.startLine }) {
            remainingLines.removeSubrange(handler.startLine...handler.endLine)
        }

        // Write the trimmed original
        let trimmedName = "\(baseName)+Core.swift"
        let trimmedPath = (dir as NSString).appendingPathComponent(trimmedName)
        let trimmedContent = remainingLines.joined(separator: "\n")
        do {
            try trimmedContent.write(toFile: trimmedPath, atomically: true, encoding: .utf8)
            createdFiles.append("\(trimmedName) (\(remainingLines.count) lines: core loop without handlers)")
        } catch {
            createdFiles.append("Error writing \(trimmedName): \(error.localizedDescription)")
        }

        if deleteOriginal {
            try? fm.removeItem(atPath: path)
            createdFiles.append("Deleted original: \((path as NSString).lastPathComponent)")
        }

        return "Split \(handlers.count) tool handlers into \(groups.count) files:\n" + createdFiles.joined(separator: "\n")
    }
}
