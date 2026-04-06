import SwiftUI
import AppKit
import AgentTerminalNeo

/// Local NSScrollView/NSTextView wrapper for the LLM Output HUD.
/// Renders text via TerminalNeoRenderer for markdown/table styling, but handles
/// auto-scroll with a user-respect pattern copied from ActivityLogView so the
/// user can scroll freely during streaming without the view fighting back.
struct LLMOutputTextView: NSViewRepresentable {
    let text: String
    var onContentHeight: ((CGFloat) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isRichText = true
        textView.allowsUndo = false
        textView.layoutManager?.allowsNonContiguousLayout = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false

        context.coordinator.textView = textView
        context.coordinator.onContentHeight = onContentHeight
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coord = context.coordinator
        coord.onContentHeight = onContentHeight
        guard let tv = coord.textView, let storage = tv.textStorage else { return }

        // Strip cursor char to detect content changes vs cursor blink
        let contentText = text.hasSuffix("█") ? String(text.dropLast()) : (text.hasSuffix(" ") ? String(text.dropLast()) : text)
        let contentLen = contentText.count

        if contentLen != coord.lastContentLength {
            // Append-only when possible — NSTextView preserves scroll position naturally
            // when content is appended (not replaced). ZERO scroll calls anywhere.
            let isAppend = contentLen > coord.lastContentLength
                && coord.lastContentLength > 0
                && contentText.hasPrefix(coord.lastRenderedContent)
            if isAppend {
                // Strip any existing trailing cursor char from storage before appending
                let prevAttrLen = storage.length
                if prevAttrLen > 0 {
                    let lastChar = String(storage.string.suffix(1))
                    if lastChar == "█" || lastChar == " " {
                        storage.beginEditing()
                        storage.deleteCharacters(in: NSRange(location: prevAttrLen - 1, length: 1))
                        storage.endEditing()
                    }
                }
                // Compute the new chars (delta) and append them as plain monospaced green text
                let newPart = String(text.dropFirst(coord.lastRenderedContent.count))
                let isDark = tv.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let color: NSColor = isDark
                    ? NSColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1)
                    : NSColor(red: 0.05, green: 0.35, blue: 0.1, alpha: 1)
                let font = NSFont.monospacedSystemFont(ofSize: 16.5, weight: .regular)
                storage.beginEditing()
                storage.append(NSAttributedString(string: newPart, attributes: [
                    .font: font, .foregroundColor: color
                ]))
                storage.endEditing()
            } else {
                // Full re-render path (text shrank or first render) — uses TerminalNeoRenderer
                // for markdown/table styling. NO scroll calls — NSTextView keeps its origin.
                storage.setAttributedString(TerminalNeoRenderer.render(text))
            }
            coord.lastContentLength = contentLen
            coord.lastRenderedContent = contentText
        } else {
            // Cursor blink — swap last char only, no scroll
            let attrLen = storage.length
            if attrLen > 0 {
                let cursorChar = text.hasSuffix("█") ? "█" : " "
                let lastChar = String(storage.string.suffix(1))
                if lastChar != cursorChar {
                    let isDark = tv.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    let color: NSColor = isDark
                        ? NSColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1)
                        : NSColor(red: 0.05, green: 0.35, blue: 0.1, alpha: 1)
                    let font = NSFont.monospacedSystemFont(ofSize: 16.5, weight: .regular)
                    storage.beginEditing()
                    storage.replaceCharacters(in: NSRange(location: attrLen - 1, length: 1),
                        with: NSAttributedString(string: cursorChar, attributes: [
                            .font: font, .foregroundColor: color
                        ]))
                    storage.endEditing()
                }
            }
        }

        // Report content height back to SwiftUI for box sizing
        let h = (tv.layoutManager?.usedRect(for: tv.textContainer!).height ?? 40) + tv.textContainerInset.height * 2
        if abs(h - coord.lastReportedHeight) > 1 {
            coord.lastReportedHeight = h
            let cb = coord.onContentHeight
            DispatchQueue.main.async { cb?(h) }
        }
    }

    @MainActor final class Coordinator: @unchecked Sendable {
        weak var textView: NSTextView?
        var onContentHeight: ((CGFloat) -> Void)?
        var lastContentLength: Int = 0
        var lastReportedHeight: CGFloat = 0
        /// Last rendered content text (without cursor) — for incremental append diffing
        var lastRenderedContent: String = ""
    }
}
