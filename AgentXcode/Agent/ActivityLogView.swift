import SwiftUI
import AppKit
@preconcurrency import WebKit

/// NSTextView-backed activity log — avoids SwiftUI Text layout storms on large/streaming content.
/// Detects image file paths in log output and renders them inline.
struct ActivityLogView: NSViewRepresentable {
    let text: String
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
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let coord = context.coordinator

        // Wire up HTML snapshot callback to trigger re-render
        let currentText = text
        let currentSearch = searchText
        let currentIndex = currentMatchIndex
        let matchCallback = onMatchCount
        coord.onHTMLReady = { [weak textView, weak coord] in
            guard let textView, let coord else { return }
            let attributed = coord.buildAttributedString(from: currentText)
            textView.textStorage?.setAttributedString(attributed)
            coord.applySearchHighlighting(textView: textView, searchText: currentSearch, currentMatch: currentIndex, onMatchCount: matchCallback)
            coord.throttledScrollToEnd(textView)
        }

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
            matchCallback?(0)
            return
        }

        let len = (text as NSString).length
        let searchChanged = currentSearch != coord.lastSearch || currentIndex != coord.lastMatchIndex
        guard len != coord.lastLength || coord.showingPlaceholder || searchChanged else { return }

        let textChanged = len != coord.lastLength || coord.showingPlaceholder
        coord.showingPlaceholder = false

        if textChanged {
            let attributed = coord.buildAttributedString(from: text)
            textView.textStorage?.setAttributedString(attributed)
            coord.lastLength = len
        }

        coord.applySearchHighlighting(textView: textView, searchText: currentSearch, currentMatch: currentIndex, onMatchCount: matchCallback)
        coord.lastSearch = currentSearch
        coord.lastMatchIndex = currentIndex

        if textChanged {
            coord.throttledScrollToEnd(textView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

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
            if let icon = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy code") {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                guard let tinted = (icon.withSymbolConfiguration(config) ?? icon).copy() as? NSImage else { return }
                tinted.isTemplate = true
                NSColor.secondaryLabelColor.set()
                tinted.draw(in: cellFrame)
            }
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

    @MainActor class Coordinator: NSObject, WKNavigationDelegate {
        var lastLength = 0
        var showingPlaceholder = true
        var lastSearch = ""
        var lastMatchIndex = -1
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        /// Throttle scrollToEnd to avoid hyper-scrolling during fast streaming
        var lastScrollTime: CFAbsoluteTime = 0
        var pendingScrollWork: DispatchWorkItem?
        /// Images keyed by their character offset in the log — each occurrence gets its own
        /// snapshot so the same path (e.g. current_artwork.jpg) shows different art per task.
        var imageCache: [Int: (image: NSImage, mtime: Date)] = [:]
        /// HTML snapshots keyed by character offset, with file modification time for invalidation
        var htmlCache: [Int: (image: NSImage, mtime: Date)] = [:]
        /// Offsets currently being rendered (prevent duplicate requests)
        var htmlPending: Set<Int> = []
        /// Retain WKWebViews until snapshot completes
        var activeWebViews: [Int: WKWebView] = [:]
        /// Callback to trigger re-render when HTML snapshot is ready
        var onHTMLReady: (() -> Void)?

        // SECURITY: Limit concurrent web views to prevent memory exhaustion
        private static let maxActiveWebViews = 10

        /// Check if scroll view is near the bottom
        private func isNearBottom(_ textView: NSTextView) -> Bool {
            guard let scrollView = textView.enclosingScrollView else { return true }
            let visibleBottom = scrollView.contentView.bounds.origin.y + scrollView.contentView.bounds.height
            let contentHeight = textView.frame.height
            return (contentHeight - visibleBottom) < 50
        }

        /// Throttled scroll — at most once per 0.3s, skipped if user scrolled away from bottom
        func throttledScrollToEnd(_ textView: NSTextView) {
            guard isNearBottom(textView) else { return }
            let now = CFAbsoluteTimeGetCurrent()
            let interval: CFAbsoluteTime = 0.3
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

        /// Highlight search matches in the text view's text storage
        func applySearchHighlighting(textView: NSTextView, searchText: String, currentMatch: Int, onMatchCount: ((Int) -> Void)?) {
            guard let storage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)

            // Remove previous search highlights
            storage.removeAttribute(.backgroundColor, range: fullRange)

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

            let highlightColor = NSColor.systemYellow.withAlphaComponent(0.3)
            let currentColor = NSColor.systemOrange.withAlphaComponent(0.5)

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

        func buildAttributedString(from text: String) -> NSAttributedString {
            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]

            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            let imageMatches = Self.imagePathPattern?.matches(in: text, range: fullRange) ?? []
            let htmlMatches = Self.htmlPathPattern?.matches(in: text, range: fullRange) ?? []

            guard !imageMatches.isEmpty || !htmlMatches.isEmpty else {
                return renderMarkdown(text)
            }

            // Merge all matches sorted by location
            struct FileMatch {
                let range: NSRange
                let path: String
                let isHTML: Bool
            }
            var allMatches: [FileMatch] = []
            for m in imageMatches {
                let r = m.range(at: 1)
                allMatches.append(FileMatch(range: r, path: nsText.substring(with: r), isHTML: false))
            }
            for m in htmlMatches {
                let r = m.range(at: 1)
                allMatches.append(FileMatch(range: r, path: nsText.substring(with: r), isHTML: true))
            }
            allMatches.sort { $0.range.location < $1.range.location }

            let result = NSMutableAttributedString()
            var lastEnd = 0
            var renderedSizes: Set<Int> = []

            for match in allMatches {
                let offset = match.range.location

                // Add text before this match
                if match.range.location > lastEnd {
                    let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                    let beforeText = nsText.substring(with: beforeRange)
                    result.append(renderMarkdown(beforeText))
                    if beforeText.contains("--- New Task ---") {
                        renderedSizes.removeAll()
                    }
                }

                // Add the path text itself
                result.append(NSAttributedString(string: match.path, attributes: baseAttrs))
                lastEnd = match.range.location + match.range.length

                let fileAttrs = try? FileManager.default.attributesOfItem(atPath: match.path)
                guard fileAttrs != nil else { continue }
                let fileSize = fileAttrs?[.size] as? Int ?? 0
                let fileMtime = fileAttrs?[.modificationDate] as? Date ?? .distantPast
                // Also check parent directory mtime — catches sibling resources (e.g. album_art.jpg) created after the HTML
                let dirPath = (match.path as NSString).deletingLastPathComponent
                let dirMtime = (try? FileManager.default.attributesOfItem(atPath: dirPath)[.modificationDate] as? Date) ?? .distantPast
                let effectiveMtime = max(fileMtime, dirMtime)

                if match.isHTML {
                    // HTML snapshot
                    if let cached = htmlCache[offset], cached.mtime == effectiveMtime {
                        // Use cached snapshot
                        let attachment = NSTextAttachment()
                        attachment.image = cached.image
                        let imgStr = NSAttributedString(attachment: attachment)
                        result.append(imgStr)
                        result.append(NSAttributedString(string: "\n", attributes: baseAttrs))
                    } else if !htmlPending.contains(offset) && activeWebViews.count < Self.maxActiveWebViews {
                        // Render HTML to image
                        htmlPending.insert(offset)
                        renderHTMLSnapshot(at: match.path, offset: offset, mtime: effectiveMtime)
                    }
                } else {
                    // Image file
                    // Skip if we already rendered this size at this offset
                    guard !renderedSizes.contains(offset) else { continue }
                    renderedSizes.insert(offset)

                    // Cache check
                    if let cached = imageCache[offset], cached.mtime == fileMtime {
                        // Use cached image
                        let attachment = NSTextAttachment()
                        attachment.image = cached.image
                        let imgStr = NSAttributedString(attachment: attachment)
                        result.append(imgStr)
                        result.append(NSAttributedString(string: "\n", attributes: baseAttrs))
                        continue
                    }

                    // Load and cache image
                    guard let image = NSImage(contentsOfFile: match.path) else { continue }
                    let maxDim: CGFloat = min(400, CGFloat(integerLiteral: fileSize / 10))
                    let scaled = scaleImage(image, maxDimension: max(100, maxDim))
                    imageCache[offset] = (image: scaled, mtime: fileMtime)

                    let attachment = NSTextAttachment()
                    attachment.image = scaled
                    let imgStr = NSAttributedString(attachment: attachment)
                    result.append(imgStr)
                    result.append(NSAttributedString(string: "\n", attributes: baseAttrs))
                }
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

            // Handle code fences (```lang\n...\n```) first
            guard let fenceRx = try? NSRegularExpression(pattern: #"```(\w*)\n([\s\S]*?)```"#) else { return NSAttributedString(string: text, attributes: baseAttrs) }
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

        private func renderInlineMarkdown(_ text: String) -> NSAttributedString {
            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]

            let result = NSMutableAttributedString()
            let lines = text.components(separatedBy: "\n")
            var i = 0

            while i < lines.count {
                if i > 0 {
                    result.append(NSAttributedString(string: "\n", attributes: baseAttrs))
                }

                // Detect markdown table blocks (consecutive lines starting with |)
                let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("|") {
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

                if trimmed.hasPrefix("### ") {
                    let hFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize + 2, weight: .bold)
                    result.append(styledLine(String(trimmed.dropFirst(4)), baseFont: hFont))
                } else if trimmed.hasPrefix("## ") {
                    let hFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize + 4, weight: .bold)
                    result.append(styledLine(String(trimmed.dropFirst(3)), baseFont: hFont))
                } else if trimmed.hasPrefix("# ") {
                    let hFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize + 6, weight: .bold)
                    result.append(styledLine(String(trimmed.dropFirst(2)), baseFont: hFont))
                } else {
                    result.append(styledLine(lines[i], baseFont: font))
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

        /// Apply inline **bold**, `code`, and [link](url) formatting to a single line.
        private func styledLine(_ text: String, baseFont: NSFont) -> NSAttributedString {
            // ANSI first pass: if escape codes are present, parse them directly
            if ANSIParser.containsANSI(text) {
                return ANSIParser.parse(text, font: baseFont)
            }

            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: NSColor.labelColor
            ]

            guard let boldRx = try? NSRegularExpression(pattern: #"\*\*([^*]+)\*\*"#),
                  let codeRx = try? NSRegularExpression(pattern: #"`([^`]+)`"#),
                  let linkRx = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#) else {
                return NSAttributedString(string: text, attributes: baseAttrs)
            }

            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)

            struct Match {
                let range: NSRange
                let type: Int // 1=bold, 2=code, 3=link
                let content: String
                let url: String?
            }
            var matches: [Match] = []

            for m in boldRx.matches(in: text, range: fullRange) {
                matches.append(Match(range: m.range, type: 1, content: nsText.substring(with: m.range(at: 1)), url: nil))
            }
            for m in codeRx.matches(in: text, range: fullRange) {
                matches.append(Match(range: m.range, type: 2, content: nsText.substring(with: m.range(at: 1)), url: nil))
            }
            for m in linkRx.matches(in: text, range: fullRange) {
                matches.append(Match(range: m.range, type: 3, content: nsText.substring(with: m.range(at: 1)), url: nsText.substring(with: m.range(at: 2))))
            }

            matches.sort { $0.range.location < $1.range.location }

            let result = NSMutableAttributedString()
            var lastEnd = 0

            for match in matches {
                guard match.range.location >= lastEnd else { continue } // Skip overlaps

                if match.range.location > lastEnd {
                    let r = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                    result.append(NSAttributedString(string: nsText.substring(with: r), attributes: baseAttrs))
                }

                switch match.type {
                case 1: // Bold
                    result.append(NSAttributedString(string: match.content, attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .bold),
                        .foregroundColor: NSColor.labelColor
                    ]))
                case 2: // Inline code
                    result.append(NSAttributedString(string: match.content, attributes: [
                        .font: baseFont,
                        .foregroundColor: NSColor.systemBlue,
                        .backgroundColor: NSColor.controlBackgroundColor
                    ]))
                case 3: // Link
                    result.append(NSAttributedString(string: match.content, attributes: [
                        .font: baseFont,
                        .foregroundColor: NSColor.linkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ]))
                default: break
                }

                lastEnd = match.range.location + match.range.length
            }

            if lastEnd < nsText.length {
                let r = NSRange(location: lastEnd, length: nsText.length - lastEnd)
                result.append(NSAttributedString(string: nsText.substring(with: r), attributes: baseAttrs))
            }

            return result
        }

        private func scaleImage(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
            let size = image.size
            guard size.width > 0, size.height > 0 else { return image }
            let scale = min(maxDimension / size.width, maxDimension / size.height)
            guard scale < 1 else { return image }
            let newSize = NSSize(width: size.width * scale, height: size.height * scale)
            let result = NSImage(size: newSize)
            result.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize))
            result.unlockFocus()
            return result
        }

        private func renderHTMLSnapshot(at path: String, offset: Int, mtime: Date) {
            // Read HTML content
            guard let htmlContent = try? String(contentsOfFile: path, encoding: .utf8) else { return }

            // Get directory for resolving relative paths
            let directory = (path as NSString).deletingLastPathComponent

            // Inject base tag for relative URLs
            var processedHTML = htmlContent
            if !htmlContent.contains("<base") {
                let baseTag = "<base href=\"file://\(directory)/\">"
                if let headRange = htmlContent.range(of: "<head>", options: .caseInsensitive) {
                    processedHTML = htmlContent.replacingCharacters(in: headRange, with: "<head>\(baseTag)")
                } else if htmlContent.range(of: "<body", options: .caseInsensitive) != nil {
                    // If no head, prepend base before body
                    processedHTML = "<html><head>\(baseTag)</head>" + htmlContent
                }
            }

            // Configure WKWebView
            let config = WKWebViewConfiguration()
            config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
            webView.loadHTMLString(processedHTML, baseURL: URL(fileURLWithPath: directory))
            webView.navigationDelegate = self

            activeWebViews[offset] = webView
        }

        // MARK: - WKNavigationDelegate

        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                guard let offset = activeWebViews.first(where: { $0.value === webView })?.key else { return }

                // Wait for layout to settle
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Get content height
                let contentHeight = (try? await webView.evaluateJavaScript("document.body.scrollHeight")) as? Double ?? 600
                let contentWidth = (try? await webView.evaluateJavaScript("document.body.scrollWidth")) as? Double ?? 800

                // Take snapshot
                let config = WKSnapshotConfiguration()
                config.rect = CGRect(x: 0, y: 0, width: contentWidth, height: min(contentHeight, 2000))

                webView.takeSnapshot(with: config) { [weak self] image, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if let image {
                            let scaled = self.scaleImage(image, maxDimension: 400)

                            // Find the path and mtime for this offset
                            if let (path, _) = self.findPathForOffset(offset) {
                                let fileMtime = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? .distantPast
                                let dirPath = (path as NSString).deletingLastPathComponent
                                let dirMtime = (try? FileManager.default.attributesOfItem(atPath: dirPath)[.modificationDate] as? Date) ?? .distantPast
                                let effectiveMtime = max(fileMtime, dirMtime)

                                self.htmlCache[offset] = (image: scaled, mtime: effectiveMtime)
                            }

                            // Trigger re-render
                            self.onHTMLReady?()
                        }

                        self.htmlPending.remove(offset)
                        self.activeWebViews.removeValue(forKey: offset)
                    }
                }
            }
        }

        private func findPathForOffset(_ offset: Int) -> (String, Bool)? {
            // This is a helper to find the path for a given offset
            // We'll need to track this differently - for now return nil
            return nil
        }

        func clearCache() {
            imageCache.removeAll()
            htmlCache.removeAll()
            htmlPending.removeAll()
            activeWebViews.removeAll()
            lastSearch = ""
            lastMatchIndex = -1
        }
    }
}