import AppKit

// MARK: - Language Resolution

extension CodeBlockHighlighter {
    /// Language aliases mapping alternate names to canonical names
    public static let aliases: [String: String] = [
        "js": "javascript", "jsx": "javascript", "ts": "typescript", "tsx": "typescript",
        "sh": "bash", "shell": "bash", "zsh": "bash",
        "c++": "cpp", "cc": "cpp", "cxx": "cpp", "h": "c", "hpp": "cpp",
        "objective-c": "objc", "objectivec": "objc", "m": "objc",
        "golang": "go", "rb": "ruby", "rs": "rust", "yml": "yaml",
        "kt": "kotlin", "py": "python", "python3": "python",
        "htm": "html",
    ]

    /// Shell command indicators — if an untagged code block starts with these, use bash highlighting.
    public static let shellPrefixes = ["$", "#", "cd ", "ls ", "cat ", "echo ", "grep ", "find ",
        "git ", "brew ", "sudo ", "mkdir ", "rm ", "cp ", "mv ", "curl ", "chmod ", "chown ",
        "npm ", "pip ", "export ", "source ", "touch ", "tar ", "ssh ", "kill ", "xargs ",
        "xcodebuild ", "swift ", "swiftc ", "clang ", "make ", "docker ", "pkill ",
        "FILTER_BRANCH"]

    /// Get language definition for a given language
    public static func langDef(for language: String?) -> LangDef {
        guard let l = language?.lowercased().trimmingCharacters(in: .whitespaces), !l.isEmpty else {
            return genericDef
        }
        let key = aliases[l] ?? l
        return defs[key] ?? genericDef
    }

    /// Guess language from code content when no language tag is provided.
    public static func guessLanguage(from code: String) -> String? {
        let firstLine = code.prefix(200).split(separator: "\n").first.map(String.init) ?? code
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        // Shell commands
        if shellPrefixes.contains(where: { trimmed.hasPrefix($0) }) { return "bash" }
        // Swift indicators
        if trimmed.hasPrefix("import ") || trimmed.hasPrefix("func ") || trimmed.hasPrefix("let ")
            || trimmed.hasPrefix("var ") || trimmed.hasPrefix("struct ") || trimmed.hasPrefix("class ")
            || trimmed.hasPrefix("@") || trimmed.hasPrefix("guard ") || trimmed.hasPrefix("enum ")
            || trimmed.hasPrefix("protocol ") { return "swift" }
        // Python
        if trimmed.hasPrefix("def ") || trimmed.hasPrefix("from ") || trimmed.hasPrefix("print(") { return "python" }
        // JSON
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") { return "json" }
        return nil
    }
}
