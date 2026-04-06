import SwiftUI
import AppKit
import AgentTerminalNeo

/// Local NSScrollView/NSTextView wrapper for the LLM Output HUD.
/// Renders text via TerminalNeoRenderer for markdown/table styling.
/// Auto-scrolls to bottom on content change ONLY when the user is already at/near
/// the bottom — same pattern as ActivityLogView. If the user scrolls away, we
/// leave them alone until they scroll back to the bottom.
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

        context.coordinator.textView = textView
        context.coordinator.onContentHeight = onContentHeight
        context.coordinator.startObservingScroll(scrollView)
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
            // Use incremental append when new text is a strict prefix-extension of the previous —
            // NSTextView preserves scroll position on append. setAttributedString resets to top,
            // which would teleport the user every drip char.
            let isAppend = contentLen > coord.lastContentLength
                && coord.lastContentLength > 0
                && contentText.hasPrefix(coord.lastRenderedContent)
            if isAppend {
                // Strip any trailing cursor char from storage before appending the delta
                let prevAttrLen = storage.length
                if prevAttrLen > 0 {
                    let lastChar = String(storage.string.suffix(1))
                    if lastChar == "█" || lastChar == " " {
                        storage.beginEditing()
                        storage.deleteCharacters(in: NSRange(location: prevAttrLen - 1, length: 1))
                        storage.endEditing()
                    }
                }
                let newPart = String(text.dropFirst(coord.lastRenderedContent.count))
                let isDark = tv.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let color: NSColor = isDark
                    ? NSColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1)
                    : NSColor(red: 0.05, green: 0.35, blue: 0.1, alpha: 1)
                let appendFont = NSFont.monospacedSystemFont(ofSize: 16.5, weight: .regular)
                storage.beginEditing()
                storage.append(NSAttributedString(string: newPart, attributes: [
                    .font: appendFont, .foregroundColor: color
                ]))
                storage.endEditing()
            } else {
                // Full re-render path (text shrank or first render). Snapshot scroll position
                // and restore it after — setAttributedString resets NSTextView to top.
                let savedY = scrollView.contentView.bounds.origin.y
                coord.isProgrammaticScroll = true
                storage.setAttributedString(TerminalNeoRenderer.render(text))
                tv.layoutManager?.ensureLayout(for: tv.textContainer!)
                if !coord.userIsAtBottom {
                    scrollView.contentView.scroll(to: NSPoint(x: 0, y: savedY))
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
                coord.isProgrammaticScroll = false
            }
            coord.lastContentLength = contentLen
            coord.lastRenderedContent = contentText
            // Auto-scroll to bottom only if user is at the bottom (same as ActivityLogView)
            if coord.userIsAtBottom {
                coord.snapToEnd(tv)
            }
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
        /// Tracks whether user is at/near bottom — drives auto-scroll-to-bottom on content change
        var userIsAtBottom: Bool = true
        /// Suppresses scroll tracking during programmatic scrolls
        var isProgrammaticScroll: Bool = false
        nonisolated(unsafe) var scrollObserver: NSObjectProtocol?
        private var scrollThrottled = false

        deinit {
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        /// Same pattern as ActivityLogView — observe content view bounds change.
        func startObservingScroll(_ scrollView: NSScrollView) {
            scrollView.contentView.postsBoundsChangedNotifications = true
            scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self, weak scrollView] _ in
                MainActor.assumeIsolated {
                    guard let self, !self.scrollThrottled, let scrollView else { return }
                    guard !self.isProgrammaticScroll else { return }
                    guard let textView = scrollView.documentView as? NSTextView else { return }
                    self.userIsAtBottom = Self.isNearBottom(textView)
                    self.scrollThrottled = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.scrollThrottled = false
                    }
                }
            }
        }

        /// Within 60pt of the bottom counts as "at bottom"
        static func isNearBottom(_ textView: NSTextView) -> Bool {
            guard let scrollView = textView.enclosingScrollView else { return true }
            let visibleBottom = scrollView.contentView.bounds.origin.y + scrollView.contentView.bounds.height
            let contentHeight = textView.frame.height
            return (contentHeight - visibleBottom) < 60
        }

        /// Instant scroll to end — same as ActivityLogView.snapToEnd
        func snapToEnd(_ textView: NSTextView) {
            guard let scrollView = textView.enclosingScrollView,
                  let textContainer = textView.textContainer else {
                textView.scrollToEndOfDocument(nil)
                return
            }
            isProgrammaticScroll = true
            textView.layoutManager?.ensureLayout(for: textContainer)
            textView.scrollToEndOfDocument(nil)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            isProgrammaticScroll = false
            userIsAtBottom = true
        }
    }
}
