import AppKit

// MARK: - Diff Block Highlighting

extension CodeBlockHighlighter {

    /// Highlight a diff code block with red/green backgrounds for removed/added lines,
    /// and line numbers for context. Format: "LINE_NUM -\tcode" or "LINE_NUM +\tcode" or "LINE_NUM\tcode"
    public static func highlightDiffBlock(code: String, font: NSFont) -> NSAttributedString {
        let text = CodeBlockTheme.text
        let result = NSMutableAttributedString(string: code, attributes: [
            .font: font, .foregroundColor: text
        ])
        let isDark = CodeBlockTheme.isDark

        let removedBg = isDark
            ? NSColor(red: 0.4, green: 0.1, blue: 0.1, alpha: 1.0)    // dark red
            : NSColor(red: 1.0, green: 0.85, blue: 0.85, alpha: 1.0)
        let addedBg = isDark
            ? NSColor(red: 0.1, green: 0.3, blue: 0.1, alpha: 1.0)    // dark green
            : NSColor(red: 0.85, green: 1.0, blue: 0.85, alpha: 1.0)
        let lineNumColor = isDark
            ? NSColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1)     // dim
            : NSColor(red: 0.45, green: 0.45, blue: 0.5, alpha: 1)
        let removedText = isDark
            ? NSColor(red: 1.0, green: 0.7, blue: 0.7, alpha: 1)      // light red text
            : NSColor(red: 0.6, green: 0.0, blue: 0.0, alpha: 1)
        let addedText = isDark
            ? NSColor(red: 0.7, green: 1.0, blue: 0.7, alpha: 1)      // light green text
            : NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1)

        // Line-numbered diff: "123 -\tcode" or "123 +\tcode" or "123\tcode"
        let lineNumDiffRx = try? NSRegularExpression(
            pattern: #"^(\d+)(\s[+-])?\t(.*)$"#, options: .anchorsMatchLines)
        // Simple diff: "- code" or "+ code"
        let simpleDiffRx = try? NSRegularExpression(
            pattern: #"^([+-])\s(.*)$"#, options: .anchorsMatchLines)

        let ns = code as NSString
        let r = NSRange(location: 0, length: ns.length)

        // Try line-numbered format first
        var matched = false
        lineNumDiffRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let m else { return }
            matched = true
            let fullRange = m.range

            // Color line number dim
            let numRange = m.range(at: 1)
            result.addAttribute(.foregroundColor, value: lineNumColor, range: numRange)

            // Check for +/- marker
            if m.range(at: 2).length > 0 {
                let marker = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespaces)
                if marker == "-" {
                    result.addAttribute(.backgroundColor, value: removedBg, range: fullRange)
                    result.addAttribute(.foregroundColor, value: removedText, range: m.range(at: 3))
                } else if marker == "+" {
                    result.addAttribute(.backgroundColor, value: addedBg, range: fullRange)
                    result.addAttribute(.foregroundColor, value: addedText, range: m.range(at: 3))
                }
            }
        }

        // Fallback to simple diff format if no line-numbered matches
        if !matched {
            simpleDiffRx?.enumerateMatches(in: code, range: r) { m, _, _ in
                guard let m else { return }
                let fullRange = m.range
                let marker = ns.substring(with: m.range(at: 1))
                if marker == "-" {
                    result.addAttribute(.backgroundColor, value: removedBg, range: fullRange)
                    result.addAttribute(.foregroundColor, value: removedText, range: fullRange)
                } else if marker == "+" {
                    result.addAttribute(.backgroundColor, value: addedBg, range: fullRange)
                    result.addAttribute(.foregroundColor, value: addedText, range: fullRange)
                }
            }
        }

        return result
    }
}
