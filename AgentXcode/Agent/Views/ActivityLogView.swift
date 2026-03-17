import SwiftUI
import AppKit

/// NSTextView-backed activity log — avoids SwiftUI Text layout storms on large/streaming content.
/// Detects image/HTML file paths in log output and shows clickable links that open in Preview/Browser.
/// Optimized for smooth streaming with incremental updates and debouncing.
struct ActivityLogView: NSViewRepresentable {
    let text: String
    var tabID: UUID?  // nil = main tab
    var searchText: String = ""
    var currentMatchIndex: Int = 0
    var onMatchCount: ((Int) -> Void)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        // Improve text rendering performance
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isRichText = false
        textView.allowsUndo = false
        // Enable link detection and clicking
        textView.isAutomaticLinkDetectionEnabled = true
        textView.delegate = context.coordinator
        textView.checkTextInDocument(nil)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let coord = context.coordinator

        // Store latest text for callbacks
        coord.latestText = text
        coord.latestSearchText = searchText
        coord.latestMatchIndex = currentMatchIndex
        coord.latestMatchCallback = onMatchCount

        if text.isEmpty {
            guard !coord.showingPlaceholder else { return }
            textView.textStorage?.setAttributedString(
                NSAttributedString(string: "Ready. Enter a task below to begin.",
                                   attributes: [.font: coord.font, .foregroundColor: NSColor.secondaryLabelColor])
            )
            coord.showingPlaceholder = true
            coord.lastLength = 0
            coord.lastSearch = ""
            coord.lastMatchIndex = -1
            coord.clearCache()
            onMatchCount?(0)
            return
        }

        let len = (text as NSString).length
        let searchChanged = searchText != coord.lastSearch || currentMatchIndex != coord.lastMatchIndex

        // Skip if nothing changed
        guard len != coord.lastLength || coord.showingPlaceholder || searchChanged else { return }

        let textChanged = len != coord.lastLength || coord.showingPlaceholder
        let textGrew = len > coord.lastLength
        let searchCleared = searchText.isEmpty && !coord.lastSearch.isEmpty
        coord.showingPlaceholder = false

        // Detect tab switch — reset and full rebuild
        let tabSwitched = tabID != coord.lastTabID
        if tabSwitched {
            coord.lastTabID = tabID
            coord.lastLength = 0
            coord.lastRenderedText = ""
            coord.clearCache()
        }

        if textChanged || searchCleared || tabSwitched {
            // Use incremental update only when genuinely appending to same tab
            let isAppending = len > coord.lastLength && coord.lastLength > 0 && !searchCleared && !tabSwitched

            if isAppending {
                // Incremental update: only render and append new text
                // Skip ALL image/HTML processing during incremental updates to prevent jumping
                let prevLen = coord.lastLength
                let newText = (text as NSString).substring(from: prevLen)

                // Check if new text or tail of previous text contains table rows (|)
                // Tables need full rebuild so all rows are visible to renderMarkdownTable
                let newLines = newText.components(separatedBy: "\n")
                let hasTableLines = newLines.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("|") }
                let prevTail = (text as NSString).substring(to: prevLen).components(separatedBy: "\n").suffix(3)
                let prevHasTableLines = prevTail.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("|") }

                if hasTableLines || prevHasTableLines {
                    // Full rebuild for proper NSTextTable rendering
                    let savedOrigin = scrollView.contentView.bounds.origin
                    let wasAtBottom = coord.isNearBottom(textView)

                    textView.textStorage?.beginEditing()
                    let attributed = coord.buildAttributedString(from: text)
                    textView.textStorage?.setAttributedString(attributed)
                    textView.textStorage?.endEditing()
                    coord.lastLength = len
                    coord.lastRenderedText = text

                    if !wasAtBottom {
                        scrollView.contentView.scroll(to: savedOrigin)
                        scrollView.reflectScrolledClipView(scrollView.contentView)
                    }
                } else {
                    let newAttributed = coord.renderMarkdownOnly(newText)

                    textView.textStorage?.beginEditing()
                    textView.textStorage?.append(newAttributed)
                    textView.textStorage?.endEditing()
                    coord.lastLength = len
                    coord.lastRenderedText = text
                }
            } else {
                // Full rebuild needed (search change, placeholder transition, or text deletion)
                let savedOrigin = scrollView.contentView.bounds.origin
                let wasAtBottom = coord.isNearBottom(textView)

                textView.textStorage?.beginEditing()
                let attributed = coord.buildAttributedString(from: text)
                textView.textStorage?.setAttributedString(attributed)
                textView.textStorage?.endEditing()
                coord.lastLength = len
                coord.lastRenderedText = text

                // Restore scroll position if user wasn't at bottom
                if !wasAtBottom {
                    scrollView.contentView.scroll(to: savedOrigin)
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
            }
        }

        coord.applySearchHighlighting(textView: textView, searchText: searchText, currentMatch: currentMatchIndex, onMatchCount: onMatchCount)
        coord.lastSearch = searchText
        coord.lastMatchIndex = currentMatchIndex

        if textGrew {
            coord.throttledScrollToEnd(textView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Draws a solid horizontal line for markdown thematic breaks (---).
    class HRLineCell: NSTextAttachmentCell {
        let color: NSColor

        init(color: NSColor) {
            self.color = color
            super.init(textCell: "")
        }

        @available(*, unavailable)
        required init(coder: NSCoder) { fatalError() }

        override func cellSize() -> NSSize { NSSize(width: 400, height: 8) }

        override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
            let lineY = cellFrame.midY
            let path = NSBezierPath()
            path.move(to: NSPoint(x: cellFrame.minX, y: lineY))
            path.line(to: NSPoint(x: cellFrame.maxX, y: lineY))
            path.lineWidth = 0.5
            color.setStroke()
            path.stroke()
        }
    }

    /// Clickable copy-to-clipboard button for code blocks.
    class CopyButtonCell: NSTextAttachmentCell {
        let codeText: String

        init(codeText: String) {
            self.codeText = codeText
            super.init(textCell: "")
        }

        @available(*, unavailable)
        required init(coder: NSCoder) { fatalError() }

        override func cellSize() -> NSSize { NSSize(width: 20, height: 16) }

        override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
            let emoji = "📋" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12)
            ]
            let size = emoji.size(withAttributes: attrs)
            let x = cellFrame.midX - size.width / 2
            let y = cellFrame.midY - size.height / 2
            emoji.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
        }

        override func wantsToTrackMouse(for theEvent: NSEvent, in cellFrame: NSRect,
                                         of controlView: NSView?, atCharacterIndex charIndex: Int) -> Bool { true }

        override func trackMouse(with theEvent: NSEvent, in cellFrame: NSRect,
                                  of controlView: NSView?, atCharacterIndex charIndex: Int,
                                  untilMouseUp flag: Bool) -> Bool {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(codeText, forType: .string)
            // Brief flash feedback
            if let tv = controlView as? NSTextView {
                let orig = tv.backgroundColor
                tv.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    tv.backgroundColor = orig
                }
            }
            return true
        }
    }

    @MainActor class Coordinator: NSObject, NSTextViewDelegate {
        var lastLength = 0
        var showingPlaceholder = true
        var lastSearch = ""
        var lastMatchIndex = -1
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        /// Latest state from updateNSView
        var latestText = ""
        var latestSearchText = ""
        var latestMatchIndex = 0
        var latestMatchCallback: ((Int) -> Void)?
        /// Track the last fully rendered text for incremental updates
        var lastRenderedText = ""
        /// Track which tab we last rendered — forces full rebuild on tab switch
        var lastTabID: UUID?
        /// Throttle scrollToEnd to avoid hyper-scrolling during fast streaming
        var lastScrollTime: CFAbsoluteTime = 0
        var pendingScrollWork: DispatchWorkItem?
        /// Minimum time between full renders during streaming (ms)
        private static let minRenderInterval: CFAbsoluteTime = 50

        /// Check if scroll view is near the bottom
        func isNearBottom(_ textView: NSTextView) -> Bool {
            guard let scrollView = textView.enclosingScrollView else { return true }
            let visibleBottom = scrollView.contentView.bounds.origin.y + scrollView.contentView.bounds.height
            let contentHeight = textView.frame.height
            return (contentHeight - visibleBottom) < 50
        }

        /// Throttled scroll — at most once per 0.15s, skipped if user scrolled away from bottom
        func throttledScrollToEnd(_ textView: NSTextView) {
            guard isNearBottom(textView) else { return }
            let now = CFAbsoluteTimeGetCurrent()
            let interval: CFAbsoluteTime = 0.15
            pendingScrollWork?.cancel()
            if now - lastScrollTime >= interval {
                lastScrollTime = now
                textView.scrollToEndOfDocument(nil)
            } else {
                let work = DispatchWorkItem { [weak self, weak textView] in
                    guard let self, let textView else { return }
                    guard self.isNearBottom(textView) else { return }
                    self.lastScrollTime = CFAbsoluteTimeGetCurrent()
                    textView.scrollToEndOfDocument(nil)
                }
                pendingScrollWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
            }
        }

        /// Track previous search highlight ranges so we can remove only those
        var lastSearchRanges: [NSRange] = []

        /// Highlight search matches in the text view's text storage
        func applySearchHighlighting(textView: NSTextView, searchText: String, currentMatch: Int, onMatchCount: ((Int) -> Void)?) {
            guard let storage = textView.textStorage else { return }

            // Remove only previous search highlight backgrounds (preserve code block backgrounds)
            let highlightColor = NSColor.systemYellow.withAlphaComponent(0.3)
            let currentColor = NSColor.systemOrange.withAlphaComponent(0.5)
            for range in lastSearchRanges {
                if range.location + range.length <= storage.length {
                    let existingColor = storage.attribute(.backgroundColor, at: range.location, effectiveRange: nil) as? NSColor
                    // Only remove if it's a search highlight color (yellow/orange), not code block background
                    if let color = existingColor, (color == highlightColor || color == currentColor) {
                        storage.removeAttribute(.backgroundColor, range: range)
                    }
                }
            }
            lastSearchRanges.removeAll()

            guard !searchText.isEmpty else {
                onMatchCount?(0)
                return
            }

            let text = storage.string
            var matchRanges: [NSRange] = []
            let searchLower = searchText.lowercased()
            let textLower = text.lowercased() as NSString

            var searchRange = NSRange(location: 0, length: textLower.length)
            while searchRange.location < textLower.length {
                let found = textLower.range(of: searchLower, options: [], range: searchRange)
                guard found.location != NSNotFound else { break }
                matchRanges.append(found)
                searchRange.location = found.location + found.length
                searchRange.length = textLower.length - searchRange.location
            }

            onMatchCount?(matchRanges.count)
            lastSearchRanges = matchRanges

            for (i, range) in matchRanges.enumerated() {
                let color = (i == currentMatch) ? currentColor : highlightColor
                storage.addAttribute(.backgroundColor, value: color, range: range)
            }

            // Scroll to current match
            if !matchRanges.isEmpty, currentMatch < matchRanges.count {
                let targetRange = matchRanges[currentMatch]
                textView.scrollRangeToVisible(targetRange)
                textView.showFindIndicator(for: targetRange)
            }
        }

        // Matches image files
        private static let imagePathPattern: NSRegularExpression? = try? NSRegularExpression(
            pattern: #"(/[^\s"'<>]+\.(?:jpg|jpeg|png|gif|tiff|bmp|webp|heic|ico|icon))"#,
            options: .caseInsensitive
        )
        // Matches HTML files
        private static let htmlPathPattern: NSRegularExpression? = try? NSRegularExpression(
            pattern: #"(/[^\s"'<>]+\.html?)"#,
            options: .caseInsensitive
        )

        private static let fencePattern: NSRegularExpression? = try? NSRegularExpression(
            pattern: #"```(\w*)\n([\s\S]*?)\n```(?=\n|$)"#, options: []
        )

        private static let headerPattern: NSRegularExpression? = try? NSRegularExpression(
            pattern: #"^(#{1,6})\s+(.*)"#, options: []
        )
        private static let bulletPattern: NSRegularExpression? = try? NSRegularExpression(
            pattern: #"^(\s*)[-*+]\s+(.*)"#, options: []
        )
        private static let hrPattern: NSRegularExpression? = try? NSRegularExpression(
            pattern: #"^\s*([-*_]\s*){3,}$"#, options: []
        )
        private static let blockquotePattern: NSRegularExpression? = try? NSRegularExpression(
            pattern: #"^>\s?(.*)"#, options: []
        )

        /// Strip ANSI escape sequences so they don't appear as garbage
        private static let ansiEscapePattern: NSRegularExpression? = try? NSRegularExpression(
            pattern: #"\x1B\[[0-9;]*[A-Za-z]"#, options: []
        )

        /// Fast render for incremental text updates - detects image/HTML paths and creates clickable links
        func renderMarkdownOnly(_ text: String) -> NSAttributedString {
            // Check for image or HTML file paths in this chunk
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            let imageMatches = Self.imagePathPattern?.matches(in: text, range: fullRange) ?? []
            let htmlMatches = Self.htmlPathPattern?.matches(in: text, range: fullRange) ?? []

            guard !imageMatches.isEmpty || !htmlMatches.isEmpty else {
                return renderMarkdown(text)
            }

            // Same logic as buildAttributedString for path-to-link conversion
            struct FileMatch {
                let range: NSRange
                let path: String
                let isHTML: Bool
            }
            let fm = FileManager.default
            var allMatches: [FileMatch] = []
            for m in imageMatches {
                let r = m.range(at: 1)
                let p = nsText.substring(with: r)
                if fm.fileExists(atPath: p) {
                    allMatches.append(FileMatch(range: r, path: p, isHTML: false))
                }
            }
            for m in htmlMatches {
                let r = m.range(at: 1)
                let p = nsText.substring(with: r)
                if fm.fileExists(atPath: p) {
                    allMatches.append(FileMatch(range: r, path: p, isHTML: true))
                }
            }
            allMatches.sort { $0.range.location < $1.range.location }

            guard !allMatches.isEmpty else { return renderMarkdown(text) }

            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
            let result = NSMutableAttributedString()
            var lastEnd = 0

            for match in allMatches {
                if match.range.location > lastEnd {
                    let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                    let beforeText = nsText.substring(with: beforeRange)
                    result.append(renderMarkdown(beforeText))
                }

                let path = match.path
                let linkText = match.isHTML ? "📄 \(path)" : "🖼️ \(path)"
                let linkAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.linkColor,
                    .link: URL(fileURLWithPath: path).absoluteString,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
                result.append(NSAttributedString(string: linkText, attributes: linkAttrs))
                result.append(NSAttributedString(string: "\n", attributes: baseAttrs))
                lastEnd = match.range.location + match.range.length
            }

            if lastEnd < nsText.length {
                let remainingRange = NSRange(location: lastEnd, length: nsText.length - lastEnd)
                result.append(renderMarkdown(nsText.substring(with: remainingRange)))
            }

            return result
        }

        /// Build attributed string from text. Converts image/HTML paths to clickable links.
        func buildAttributedString(from text: String) -> NSAttributedString {
            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]

            // Strip ANSI escape codes from the text
            let cleanText: String
            if let rx = Self.ansiEscapePattern {
                cleanText = rx.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "")
            } else {
                cleanText = text
            }

            let nsText = cleanText as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            let imageMatches = Self.imagePathPattern?.matches(in: cleanText, range: fullRange) ?? []
            let htmlMatches = Self.htmlPathPattern?.matches(in: cleanText, range: fullRange) ?? []

            guard !imageMatches.isEmpty || !htmlMatches.isEmpty else {
                return renderMarkdown(cleanText)
            }

            // Merge all matches sorted by location
            struct FileMatch {
                let range: NSRange
                let path: String
                let isHTML: Bool
            }
            let fm = FileManager.default
            var allMatches: [FileMatch] = []
            for m in imageMatches {
                let r = m.range(at: 1)
                let p = nsText.substring(with: r)
                if fm.fileExists(atPath: p) {
                    allMatches.append(FileMatch(range: r, path: p, isHTML: false))
                }
            }
            for m in htmlMatches {
                let r = m.range(at: 1)
                let p = nsText.substring(with: r)
                if fm.fileExists(atPath: p) {
                    allMatches.append(FileMatch(range: r, path: p, isHTML: true))
                }
            }
            allMatches.sort { $0.range.location < $1.range.location }

            guard !allMatches.isEmpty else { return renderMarkdown(cleanText) }

            let result = NSMutableAttributedString()
            var lastEnd = 0

            for match in allMatches {
                // Add text before this match
                if match.range.location > lastEnd {
                    let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                    let beforeText = nsText.substring(with: beforeRange)
                    result.append(renderMarkdown(beforeText))
                }

                // Add the path as a clickable link
                let path = match.path
                let linkText = match.isHTML ? "📄 \(path)" : "🖼️ \(path)"
                let linkAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.linkColor,
                    .link: URL(fileURLWithPath: path).absoluteString,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
                result.append(NSAttributedString(string: linkText, attributes: linkAttrs))
                result.append(NSAttributedString(string: "\n", attributes: baseAttrs))
                lastEnd = match.range.location + match.range.length
            }

            // Add remaining text after last match
            if lastEnd < nsText.length {
                let remainingRange = NSRange(location: lastEnd, length: nsText.length - lastEnd)
                result.append(renderMarkdown(nsText.substring(with: remainingRange)))
            }

            return result
        }

        private func renderMarkdown(_ text: String) -> NSAttributedString {
            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]

            // Check if the text is read_file output (strictly matches "NN |" at the start of lines)
            // This check MUST come before markdown processing to preserve backticks in code
            let readFilePattern = #"^\s*\d+\s*\|\s"#
            let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            let isReadFileOutput = !lines.isEmpty
                && lines.allSatisfy { line in
                    line.range(of: readFilePattern, options: .regularExpression) != nil
                }

            if isReadFileOutput {
                // Render read_file output as a single preformatted block with syntax highlighting
                // Do NOT process backticks as markdown - they are literal content
                let hl = CodeBlockHighlighter.highlight(code: text, language: "swift", font: font)
                let block = NSMutableAttributedString(attributedString: hl)
                block.addAttribute(.backgroundColor, value: CodeBlockTheme.bg,
                                   range: NSRange(location: 0, length: block.length))
                return block
            }

            // Handle code fences (```lang\n...\n```) first
            guard let fenceRx = Self.fencePattern else { return NSAttributedString(string: text, attributes: baseAttrs) }
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            let fences = fenceRx.matches(in: text, range: fullRange)

            guard !fences.isEmpty else {
                return renderInlineMarkdown(text)
            }

            let result = NSMutableAttributedString()
            var cursor = 0

            for fence in fences {
                if fence.range.location > cursor {
                    let seg = nsText.substring(with: NSRange(location: cursor, length: fence.range.location - cursor))
                    result.append(renderInlineMarkdown(seg))
                }

                let lang = fence.range(at: 1).length > 0 ? nsText.substring(with: fence.range(at: 1)) : nil
                var code = nsText.substring(with: fence.range(at: 2))
                if code.hasSuffix("\n") { code = String(code.dropLast()) }

                // Copy button only for actual source code blocks (not shell output or file reads)
                let shellLangs: Set<String> = ["bash", "sh", "zsh", "shell", "console", "terminal"]
                let firstLine = code.components(separatedBy: "\n").first ?? ""
                let looksLikeNumberedOutput = firstLine.range(of: #"^\s*\d+\s+"#, options: .regularExpression) != nil
                let isSourceCode = (lang.map { !shellLangs.contains($0.lowercased()) } ?? false) && !looksLikeNumberedOutput
                if isSourceCode {
                    let attach = NSTextAttachment()
                    attach.attachmentCell = CopyButtonCell(codeText: code)
                    let rightPara = NSMutableParagraphStyle()
                    rightPara.alignment = .right
                    let copyStr = NSMutableAttributedString(attachment: attach)
                    copyStr.addAttribute(.paragraphStyle, value: rightPara, range: NSRange(location: 0, length: copyStr.length))
                    result.append(copyStr)
                }

                // Syntax-highlighted code with background
                let hl = CodeBlockHighlighter.highlight(code: code, language: lang, font: font)
                let block = NSMutableAttributedString(string: "\n", attributes: baseAttrs)
                block.append(hl)
                block.append(NSAttributedString(string: "\n", attributes: baseAttrs))
                block.addAttribute(.backgroundColor, value: CodeBlockTheme.bg,
                                   range: NSRange(location: 0, length: block.length))
                result.append(block)

                cursor = fence.range.location + fence.range.length
            }

            if cursor < nsText.length {
                result.append(renderInlineMarkdown(nsText.substring(with: NSRange(location: cursor, length: nsText.length - cursor))))
            }

            return result
        }

        /// Splits text into lines and renders block-level markdown (headers, lists, rules, tables)
        /// then delegates inline rendering (bold, italic, code) per line.
        private func renderInlineMarkdown(_ text: String) -> NSAttributedString {
            guard !text.isEmpty else { return NSAttributedString() }

            let result = NSMutableAttributedString()
            let lines = text.components(separatedBy: "\n")
            var i = 0

            while i < lines.count {
                // Detect markdown table blocks (consecutive lines starting with |)
                if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    var tableLines: [String] = []
                    var j = i
                    while j < lines.count && lines[j].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                        tableLines.append(lines[j])
                        j += 1
                    }
                    if tableLines.count >= 3, isTableSeparator(tableLines[1]),
                       let tableAttr = renderMarkdownTable(tableLines) {
                        result.append(tableAttr)
                        i = j
                        continue
                    }
                }

                // Regular line
                result.append(renderMarkdownLine(lines[i]))
                if i < lines.count - 1 {
                    result.append(NSAttributedString(string: "\n", attributes: [.font: font]))
                }
                i += 1
            }

            return result
        }

        // MARK: - Markdown Table Rendering (NSTextTable)

        private func isTableSeparator(_ line: String) -> Bool {
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

        private func parseTableRow(_ line: String) -> [String] {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("|") else { return [] }
            var inner = t[t.index(after: t.startIndex)...]
            if inner.hasSuffix("|") { inner = inner.dropLast() }
            return inner.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }

        private func renderMarkdownTable(_ lines: [String]) -> NSAttributedString? {
            let headerCells = parseTableRow(lines[0])
            guard !headerCells.isEmpty else { return nil }

            let sepCells = parseTableRow(lines[1])
            let alignments: [NSTextAlignment] = sepCells.map { cell in
                let left = cell.hasPrefix(":")
                let right = cell.hasSuffix(":")
                if left && right { return .center }
                if right { return .right }
                return .left
            }

            var dataRows: [[String]] = []
            for idx in 2..<lines.count {
                let cells = parseTableRow(lines[idx])
                if !cells.isEmpty { dataRows.append(cells) }
            }

            let colCount = headerCells.count
            let table = NSTextTable()
            table.numberOfColumns = colCount
            table.layoutAlgorithm = .automaticLayoutAlgorithm
            table.collapsesBorders = true
            table.hidesEmptyCells = false

            let result = NSMutableAttributedString()
            let borderColor = NSColor.separatorColor
            let headerBg = NSColor.controlAccentColor.withAlphaComponent(0.15)
            let boldFont = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)

            for (col, cell) in headerCells.prefix(colCount).enumerated() {
                let align = col < alignments.count ? alignments[col] : .left
                result.append(makeTableCell(
                    text: cell, table: table, row: 0, column: col,
                    bg: headerBg, cellFont: boldFont, align: align, border: borderColor))
            }

            let evenBg = NSColor.controlBackgroundColor
            let oddBg = NSColor.windowBackgroundColor
            for (rowIdx, row) in dataRows.enumerated() {
                let bg = (rowIdx % 2 == 0) ? evenBg : oddBg
                for col in 0..<colCount {
                    let cellText = col < row.count ? row[col] : ""
                    let align = col < alignments.count ? alignments[col] : .left
                    result.append(makeTableCell(
                        text: cellText, table: table, row: rowIdx + 1, column: col,
                        bg: bg, cellFont: font, align: align, border: borderColor))
                }
            }

            return result
        }

        private func makeTableCell(
            text: String, table: NSTextTable, row: Int, column: Int,
            bg: NSColor, cellFont: NSFont, align: NSTextAlignment, border: NSColor
        ) -> NSAttributedString {
            let block = NSTextTableBlock(
                table: table, startingRow: row, rowSpan: 1,
                startingColumn: column, columnSpan: 1)
            block.backgroundColor = bg
            block.setBorderColor(border)
            block.setWidth(0.5, type: .absoluteValueType, for: .border)
            block.setWidth(5.0, type: .absoluteValueType, for: .padding)

            let style = NSMutableParagraphStyle()
            style.textBlocks = [block]
            style.alignment = align

            return NSAttributedString(
                string: text + "\n",
                attributes: [
                    .paragraphStyle: style,
                    .font: cellFont,
                    .foregroundColor: NSColor.labelColor
                ])
        }

        /// Renders a single line, detecting block-level elements first, then inline.
        private func renderMarkdownLine(_ line: String) -> NSAttributedString {
            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)

            // Horizontal rule (check before bullet since --- could conflict)
            if Self.hrPattern?.firstMatch(in: line, range: fullRange) != nil {
                let result = NSMutableAttributedString()
                let attachment = NSTextAttachment()
                attachment.attachmentCell = HRLineCell(color: .separatorColor)
                result.append(NSAttributedString(attachment: attachment))
                return result
            }

            // Header
            if let match = Self.headerPattern?.firstMatch(in: line, range: fullRange) {
                let level = nsLine.substring(with: match.range(at: 1)).count
                let content = nsLine.substring(with: match.range(at: 2))
                let size: CGFloat
                switch level {
                case 1: size = font.pointSize * 1.5
                case 2: size = font.pointSize * 1.3
                case 3: size = font.pointSize * 1.15
                default: size = font.pointSize
                }
                let headerFont = NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
                return renderInlineElements(content, baseFont: headerFont)
            }

            // Bullet list
            if let match = Self.bulletPattern?.firstMatch(in: line, range: fullRange) {
                let indent = nsLine.substring(with: match.range(at: 1))
                let content = nsLine.substring(with: match.range(at: 2))
                let result = NSMutableAttributedString()
                result.append(NSAttributedString(
                    string: indent + "  \u{2022} ",
                    attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
                ))
                result.append(renderInlineElements(content, baseFont: font))
                return result
            }

            // Blockquote
            if let match = Self.blockquotePattern?.firstMatch(in: line, range: fullRange) {
                let content = nsLine.substring(with: match.range(at: 1))
                let result = NSMutableAttributedString()
                result.append(NSAttributedString(
                    string: "\u{258E} ",
                    attributes: [.font: font, .foregroundColor: NSColor.systemBlue]
                ))
                let rendered = renderInlineElements(content, baseFont: font)
                let mutableRendered = NSMutableAttributedString(attributedString: rendered)
                let rRange = NSRange(location: 0, length: mutableRendered.length)
                mutableRendered.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: rRange)
                result.append(mutableRendered)
                return result
            }

            // Regular line — inline elements only
            return renderInlineElements(line, baseFont: font)
        }

        /// Parses inline markdown (bold, italic, inline code) using Apple's AttributedString.
        private func renderInlineElements(_ text: String, baseFont: NSFont) -> NSAttributedString {
            guard !text.isEmpty else { return NSAttributedString() }

            let plainAttrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: NSColor.labelColor
            ]

            // Fast path: skip the markdown parser for lines with no markdown syntax.
            let hasMarkdownChars = text.contains("*") || text.contains("_") || text.contains("`")
                || text.contains("[") || text.contains("~")
            guard hasMarkdownChars else {
                return NSAttributedString(string: text, attributes: plainAttrs)
            }

            // SAFETY: Skip markdown parsing if text contains Swift raw strings with backticks
            // (e.g., #"...`..."#). Apple's markdown parser mangles these.
            // Also skip if text looks like numbered code output (e.g., "1 | code")
            let hasRawStringWithBacktick = text.contains("#\"") && text.contains("\"#") && text.contains("`")
            let looksLikeNumberedCode = text.contains(#"\d+\s*\|"#) && text.split(separator: "\n").allSatisfy {
                $0.trimmingCharacters(in: .whitespaces).isEmpty || $0.range(of: #"^\s*\d+\s*\|"#, options: .regularExpression) != nil
            }
            if hasRawStringWithBacktick || looksLikeNumberedCode {
                return NSAttributedString(string: text, attributes: plainAttrs)
            }

            do {
                var options = AttributedString.MarkdownParsingOptions()
                options.interpretedSyntax = .inlineOnlyPreservingWhitespace
                let parsed = try AttributedString(markdown: text, options: options)

                let nsAttr = NSMutableAttributedString(parsed)
                let fullRange = NSRange(location: 0, length: nsAttr.length)

                // Set base monospaced font and color
                nsAttr.addAttribute(.font, value: baseFont, range: fullRange)
                nsAttr.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)

                // Apply bold/italic/code from inline presentation intents
                nsAttr.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
                    if let intentValue = attrs[.inlinePresentationIntent] as? Int {
                        let intent = InlinePresentationIntent(rawValue: UInt(intentValue))
                        var styledFont = baseFont
                        if intent.contains(.stronglyEmphasized) {
                            styledFont = NSFontManager.shared.convert(styledFont, toHaveTrait: .boldFontMask)
                        }
                        if intent.contains(.emphasized) {
                            styledFont = NSFontManager.shared.convert(styledFont, toHaveTrait: .italicFontMask)
                        }
                        nsAttr.addAttribute(.font, value: styledFont, range: range)
                        if intent.contains(.code) {
                            nsAttr.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor, range: range)
                        }
                    }
                }

                return nsAttr
            } catch {
                return NSAttributedString(string: text, attributes: plainAttrs)
            }
        }

        // Open image and HTML file links in the default web browser
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let urlString: String
            if let url = link as? URL {
                urlString = url.absoluteString
            } else if let str = link as? String {
                urlString = str
            } else {
                return false
            }
            guard let url = URL(string: urlString), url.isFileURL else { return false }
            // Open in the user's default web browser
            if let browserURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open([url], withApplicationAt: browserURL, configuration: config)
            } else {
                NSWorkspace.shared.open(url)
            }
            return true
        }

        func clearCache() {
            lastSearch = ""
            lastMatchIndex = -1
            lastSearchRanges.removeAll()
        }
    }
}