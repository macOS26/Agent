import AppKit

/// Renders markdown text as NSAttributedString with retro neo green terminal styling.
/// Supports: tables (NSTextTable), headers, bold, italic, inline code, code blocks, lists, horizontal rules.
public enum TerminalNeoRenderer: Sendable {

    public nonisolated(unsafe) static let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    public nonisolated(unsafe) static let boldFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)

    // MARK: - Regex patterns

    private static let boldItalicRx = try? NSRegularExpression(pattern: #"\*\*\*(.+?)\*\*\*"#)
    private static let boldRx = try? NSRegularExpression(pattern: #"\*\*(.+?)\*\*"#)
    private static let italicRx = try? NSRegularExpression(pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#)
    private static let codeRx = try? NSRegularExpression(pattern: #"`([^`]+)`"#)
    private static let headerRx = try? NSRegularExpression(pattern: #"^(#{1,6})\s+(.+)$"#, options: .anchorsMatchLines)
    private static let bulletRx = try? NSRegularExpression(pattern: #"^(\s*)[-*+]\s+(.*)"#)
    private static let numListRx = try? NSRegularExpression(pattern: #"^(\s*)\d+\.\s+(.*)"#)
    private static let hrRx = try? NSRegularExpression(pattern: #"^\s*([-*_]\s*){3,}$"#)

    // MARK: - Public API

    /// Render markdown text to NSAttributedString with retro neo green terminal styling.
    public static func render(_ text: String) -> NSAttributedString {
        let lines = text.components(separatedBy: "\n")
        let result = NSMutableAttributedString()
        var i = 0
        var inCodeBlock = false
        var codeLines: [String] = []

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block fences
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    if result.length > 0 { result.append(NSAttributedString(string: "\n", attributes: [.font: font])) }
                    let codeText = codeLines.joined(separator: "\n")
                    result.append(NSAttributedString(string: codeText, attributes: [
                        .font: font, .foregroundColor: TerminalNeoTheme.bright, .backgroundColor: TerminalNeoTheme.codeBg
                    ]))
                    codeLines = []
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                i += 1
                continue
            }
            if inCodeBlock {
                codeLines.append(line)
                i += 1
                continue
            }

            // Table block
            if i + 2 < lines.count,
               trimmed.hasPrefix("|"),
               isTableSeparator(lines[i + 1]) {
                var tableEnd = i + 2
                while tableEnd < lines.count,
                      lines[tableEnd].trimmingCharacters(in: .whitespaces).hasPrefix("|"),
                      !isTableSeparator(lines[tableEnd]) {
                    tableEnd += 1
                }
                result.append(renderTable(lines: Array(lines[i..<tableEnd])))
                i = tableEnd
                continue
            }

            if i > 0 { result.append(NSAttributedString(string: "\n", attributes: [.font: font])) }
            result.append(renderLine(line))
            i += 1
        }
        return result
    }

    // MARK: - Table

    public static func isTableSeparator(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("|") else { return false }
        var inner = t[t.index(after: t.startIndex)...]
        if inner.hasSuffix("|") { inner = inner.dropLast() }
        let cells = inner.split(separator: "|", omittingEmptySubsequences: false)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let s = cell.trimmingCharacters(in: .whitespaces)
            return !s.isEmpty && s.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    public static func parseTableRow(_ line: String) -> [String] {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("|") else { return [] }
        var inner = t[t.index(after: t.startIndex)...]
        if inner.hasSuffix("|") { inner = inner.dropLast() }
        return inner.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func renderTable(lines: [String]) -> NSAttributedString {
        let headerCells = parseTableRow(lines[0])
        let sepCells = parseTableRow(lines[1])
        let alignments: [NSTextAlignment] = sepCells.map { cell in
            let left = cell.hasPrefix(":")
            let right = cell.hasSuffix(":")
            if left && right { return .center }
            if right { return .right }
            return .left
        }
        var dataRows: [[String]] = []
        for r in 2..<lines.count {
            dataRows.append(parseTableRow(lines[r]))
        }
        let colCount = headerCells.count
        let table = NSTextTable()
        table.numberOfColumns = colCount
        table.layoutAlgorithm = .automaticLayoutAlgorithm
        table.collapsesBorders = true
        table.hidesEmptyCells = false

        let result = NSMutableAttributedString()
        for (col, cell) in headerCells.prefix(colCount).enumerated() {
            let align = col < alignments.count ? alignments[col] : .left
            result.append(makeCell(cell, table: table, row: 0, col: col,
                                   bg: TerminalNeoTheme.headerBg, fg: TerminalNeoTheme.bright,
                                   f: boldFont, align: align))
        }
        for (rowIdx, row) in dataRows.enumerated() {
            let bg = (rowIdx % 2 == 0) ? TerminalNeoTheme.evenBg : TerminalNeoTheme.oddBg
            for col in 0..<colCount {
                let cellText = col < row.count ? row[col] : ""
                let align = col < alignments.count ? alignments[col] : .left
                result.append(makeCell(cellText, table: table, row: rowIdx + 1, col: col,
                                       bg: bg, fg: TerminalNeoTheme.cellFg, f: font, align: align))
            }
        }
        return result
    }

    private static func makeCell(_ text: String, table: NSTextTable, row: Int, col: Int,
                                  bg: NSColor, fg: NSColor, f: NSFont, align: NSTextAlignment) -> NSAttributedString {
        let block = NSTextTableBlock(table: table, startingRow: row, rowSpan: 1, startingColumn: col, columnSpan: 1)
        block.backgroundColor = bg
        block.setBorderColor(TerminalNeoTheme.border)
        block.setWidth(0.5, type: .absoluteValueType, for: .border)
        block.setWidth(5.0, type: .absoluteValueType, for: .padding)
        let style = NSMutableParagraphStyle()
        style.textBlocks = [block]
        style.alignment = align
        return NSAttributedString(string: text + "\n", attributes: [.font: f, .foregroundColor: fg, .paragraphStyle: style])
    }

    // MARK: - Line rendering

    private static func renderLine(_ line: String) -> NSAttributedString {
        let ns = line as NSString
        let r = NSRange(location: 0, length: ns.length)

        if hrRx?.firstMatch(in: line, range: r) != nil {
            return NSAttributedString(string: String(repeating: "─", count: 40),
                                      attributes: [.font: font, .foregroundColor: TerminalNeoTheme.dim])
        }

        if let m = headerRx?.firstMatch(in: line, range: r) {
            let level = ns.substring(with: m.range(at: 1)).count
            let content = ns.substring(with: m.range(at: 2))
            let size = max(11, 18 - CGFloat(level) * 1.5)
            let hFont = NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
            return applyInlineMarkdown(content, baseFont: hFont, baseColor: TerminalNeoTheme.bright)
        }

        if let m = bulletRx?.firstMatch(in: line, range: r) {
            let indent = ns.substring(with: m.range(at: 1))
            let content = ns.substring(with: m.range(at: 2))
            let bullet = NSMutableAttributedString(string: indent + "  \u{2022} ",
                                                    attributes: [.font: font, .foregroundColor: TerminalNeoTheme.dim])
            bullet.append(applyInlineMarkdown(content, baseFont: font, baseColor: TerminalNeoTheme.text))
            return bullet
        }

        if let m = numListRx?.firstMatch(in: line, range: r) {
            let indent = ns.substring(with: m.range(at: 1))
            let content = ns.substring(with: m.range(at: 2))
            let numEnd = line.firstIndex(of: ".")!
            let num = String(line[line.startIndex...numEnd])
            let prefix = NSMutableAttributedString(string: indent + num + " ",
                                                    attributes: [.font: font, .foregroundColor: TerminalNeoTheme.dim])
            prefix.append(applyInlineMarkdown(content, baseFont: font, baseColor: TerminalNeoTheme.text))
            return prefix
        }

        return applyInlineMarkdown(line, baseFont: font, baseColor: TerminalNeoTheme.text)
    }

    // MARK: - Inline markdown

    private static func applyInlineMarkdown(_ text: String, baseFont: NSFont, baseColor: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [.font: baseFont, .foregroundColor: baseColor])
        let ns = text as NSString
        let r = NSRange(location: 0, length: ns.length)
        let bFont = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .bold)
        let iFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        let tinyFont = NSFont.monospacedSystemFont(ofSize: 1, weight: .regular)

        // Inline code
        codeRx?.enumerateMatches(in: text, range: r) { m, _, _ in
            guard let m else { return }
            result.addAttributes([.foregroundColor: TerminalNeoTheme.bright, .backgroundColor: TerminalNeoTheme.codeBg], range: m.range(at: 1))
            result.addAttributes([.foregroundColor: NSColor.clear, .font: tinyFont], range: NSRange(location: m.range.location, length: 1))
            result.addAttributes([.foregroundColor: NSColor.clear, .font: tinyFont], range: NSRange(location: m.range.location + m.range.length - 1, length: 1))
        }

        // Bold+Italic ***text***
        boldItalicRx?.enumerateMatches(in: text, range: r) { m, _, _ in
            guard let m else { return }
            let biFont = NSFontManager.shared.convert(bFont, toHaveTrait: .italicFontMask)
            result.addAttributes([.font: biFont, .foregroundColor: TerminalNeoTheme.bright], range: m.range(at: 1))
            for offset in [m.range.location, m.range.location + 1, m.range.location + 2,
                           m.range.location + m.range.length - 3, m.range.location + m.range.length - 2, m.range.location + m.range.length - 1] {
                result.addAttributes([.foregroundColor: NSColor.clear, .font: tinyFont], range: NSRange(location: offset, length: 1))
            }
        }

        // Bold **text**
        boldRx?.enumerateMatches(in: text, range: r) { m, _, _ in
            guard let m else { return }
            result.addAttributes([.font: bFont, .foregroundColor: TerminalNeoTheme.bright], range: m.range(at: 1))
            for offset in [m.range.location, m.range.location + 1,
                           m.range.location + m.range.length - 2, m.range.location + m.range.length - 1] {
                result.addAttributes([.foregroundColor: NSColor.clear, .font: tinyFont], range: NSRange(location: offset, length: 1))
            }
        }

        // Italic *text*
        italicRx?.enumerateMatches(in: text, range: r) { m, _, _ in
            guard let m else { return }
            result.addAttribute(.font, value: iFont, range: m.range(at: 1))
            result.addAttributes([.foregroundColor: NSColor.clear, .font: tinyFont], range: NSRange(location: m.range.location, length: 1))
            result.addAttributes([.foregroundColor: NSColor.clear, .font: tinyFont], range: NSRange(location: m.range.location + m.range.length - 1, length: 1))
        }

        return result
    }
}
