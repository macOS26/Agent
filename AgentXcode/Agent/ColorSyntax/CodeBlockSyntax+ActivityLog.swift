import AppKit

// MARK: - Activity Log Line Highlighting Extension

extension CodeBlockHighlighter {
    
    // MARK: - Activity Log Regexes
    
    static let actTimestampRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\[\d{2}:\d{2}:\d{2}\]"#)
    static let actSectionRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"---\s+.+?\s+---"#)
    static let actLabelRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b(?:Task|Model|Status|Error|Warning|Result|Info|Read|exit code):"#)
    static let actShellRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\$\s+\S+"#)
    static let actPipeCmdRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?:&&|\|)\s+(\w+)"#)
    static let actGrepFileRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^([^\s:]+):(\d+):"#, options: .anchorsMatchLines)
    static let actAbsPathRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?:^|\s)(\.?/?(?:[\w.@+\-]+/)+[\w.@+\-]+/?)"#, options: .anchorsMatchLines)
    static let actFlagRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<=\s)-{1,2}[\w][\w\-]*"#)
    
    // MARK: - Activity Log Detection
    
    /// Check if a line is activity log output (timestamps, grep results, or ls output)
    static func looksLikeActivityLogLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.range(of: #"^\[\d{2}:\d{2}:\d{2}\]"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"^\S+\.\w+:\d+:"#, options: .regularExpression) != nil { return true }
        if looksLikeHexDump(t) { return true }
        if looksLikeTerminalLine(t) { return true }
        if looksLikeGitOutput(t) { return true }
        if looksLikeD1FLine(t) { return true }
        // Compiler/SPM warnings and errors
        if t.hasPrefix("warning:") || t.hasPrefix("error:") || t.hasPrefix("note:") { return true }
        // Bare file paths (e.g. /Users/... or ~/Documents/...)
        if t.hasPrefix("/") || t.hasPrefix("~/") { return true }
        return false
    }
    
    /// Check if a line is D1F diff output (📎/❌/✅/📍/📊 prefixed)
    static func looksLikeD1FLine(_ t: String) -> Bool {
        t.hasPrefix("📎 ") || t.hasPrefix("❌ ") || t.hasPrefix("✅ ") ||
        t.hasPrefix("📍 ") || t.hasPrefix("📊 ") || t.hasPrefix("❓ ")
    }
    
    /// Check if a single line looks like ls -la output (permissions string)
    static func looksLikeTerminalLine(_ t: String) -> Bool {
        guard t.count > 10, let first = t.first, "d-lbcps".contains(first) else { return false }
        let perm = t.prefix(10)
        return perm.allSatisfy({ "drwx-lbcpsTt@+. ".contains($0) })
    }
    
    // MARK: - Activity Log Highlighting
    
    /// Highlight a single activity log line. Returns nil if the line is not activity-log output.
    static func highlightActivityLogLine(line: String, font: NSFont) -> NSAttributedString? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // D1F diff output (📎/❌/✅ prefixed lines)
        if looksLikeD1FLine(trimmed) {
            return highlightD1FLine(line: line, font: font)
        }
        
        // Hex dump output (xxd / hexdump)
        if looksLikeHexDump(trimmed) {
            return highlightHexDump(line: line, font: font)
        }
        
        // Terminal output (ls -la) — use the full terminal highlighter
        if looksLikeTerminalLine(trimmed) {
            return highlightTerminalOutput(code: line, font: font)
        }
        
        // Git output (files changed, delete mode, commit refs)
        if looksLikeGitOutput(trimmed) {
            return highlightGitOutput(line: line, font: font)
        }
        
        guard looksLikeActivityLogLine(line) else { return nil }
        
        let result = NSMutableAttributedString(string: line, attributes: [
            .font: font, .foregroundColor: NSColor.labelColor
        ])
        let ns = line as NSString
        let r = NSRange(location: 0, length: ns.length)
        let bold = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)
        
        // Paths → multi-color segments (home dim, top-dir green, middle cyan, filename blue bold)
        actAbsPathRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range(at: 1) else { return }
            let pathStr = ns.substring(with: mr)
            colorizePath(result, pathRange: mr, path: pathStr, bold: bold)
        }
        
        // Timestamps [HH:MM:SS]
        actTimestampRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttributes([.foregroundColor: CodeBlockTheme.number, .font: bold], range: mr)
        }
        
        // Section headers --- Text ---
        actSectionRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: CodeBlockTheme.keyword, range: mr)
        }
        
        // Labels (Task:, Model:, Status:, Error:, etc.)
        actLabelRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: CodeBlockTheme.keyword, range: mr)
        }
        
        // Shell prompts $ command
        actShellRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: CodeBlockTheme.keyword, range: mr)
        }
        
        // Piped commands after | or &&
        actPipeCmdRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range(at: 1) else { return }
            result.addAttribute(.foregroundColor, value: CodeBlockTheme.funcCall, range: mr)
        }
        
        // grep -n style file:line:
        actGrepFileRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: CodeBlockTheme.string, range: mr)
        }
        
        // Command-line flags
        actFlagRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: CodeBlockTheme.number, range: mr)
        }
        
        return result
    }
}