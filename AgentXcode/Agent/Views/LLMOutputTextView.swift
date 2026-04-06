import SwiftUI
import AppKit
import AgentTerminalNeo

/// NSTextView subclass that refuses to auto-scroll. The stock NSTextView calls
/// scrollRangeToVisible() on every text mutation to keep the insertion point
/// visible — we override every entry point so only the user (mouse wheel,
/// trackpad, scroller drag) can move the clip view.
final class NoAutoScrollTextView: NSTextView {
    override func scrollRangeToVisible(_ range: NSRange) { /* no-op */ }
    override func scroll(_ point: NSPoint) { /* no-op */ }
    override func scrollToVisible(_ rect: NSRect) -> Bool { false }
}

/// NSClipView subclass that ignores programmatic scroll requests originating
/// from subviews (NSTextView's layout manager will call scrollToVisible on the
/// clip view directly during layout). User scrolling still works because the
/// scroller and wheel events drive the clip view via setBoundsOrigin, which
/// we leave alone.
final class NoAutoScrollClipView: NSClipView {
    override func scrollToVisible(_ rect: NSRect) -> Bool { false }
}

/// Local NSScrollView/NSTextView wrapper for the LLM Output HUD.
/// Renders text via TerminalNeoRenderer for markdown/table styling.
///
/// Scroll policy: USER OWNS THE SCROLL POSITION, ALWAYS.
/// All auto-scroll paths are disabled via NoAutoScrollTextView and
/// NoAutoScrollClipView. Mouse wheel / trackpad / scroller drag still work.
struct LLMOutputTextView: NSViewRepresentable {
    let text: String
    var onContentHeight: ((CGFloat) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        // Swap in our no-auto-scroll clip view
        let clipView = NoAutoScrollClipView()
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        let contentSize = scrollView.contentSize
        let textView = NoAutoScrollTextView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height))
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

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

        scrollView.documentView = textView

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
            storage.setAttributedString(TerminalNeoRenderer.render(text))
            coord.lastContentLength = contentLen
            tv.layoutManager?.ensureLayout(for: tv.textContainer!)
        } else {
            // Cursor blink — swap last char only
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
    }
}
