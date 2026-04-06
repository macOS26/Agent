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
            // CRITICAL: suppress scroll observation for the ENTIRE content update.
            // setAttributedString triggers layout reflow which fires boundsDidChangeNotification,
            // and without suppression the observer would wrongly think the user scrolled and
            // flip userIsAtBottom = false. Wrap the whole content update + scroll restore.
            coord.isProgrammaticScroll = true
            let wasAtBottom = coord.userIsAtBottom

            // Snapshot the current scroll position so we can restore it if user is NOT at bottom
            let savedY = scrollView.contentView.bounds.origin.y

            storage.setAttributedString(TerminalNeoRenderer.render(text))
            coord.lastContentLength = contentLen
            tv.layoutManager?.ensureLayout(for: tv.textContainer!)

            let hasTable = contentText.contains("|\n") && contentText.contains("---")
            if !hasTable && wasAtBottom {
                // Auto-scroll to bottom — user was at bottom and content is plain text
                tv.scrollToEndOfDocument(nil)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            } else {
                // Restore the user's scroll position so layout reflow doesn't move them
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: savedY))
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
            // Re-enable observation AFTER layout settles on the next runloop tick,
            // so any deferred bounds-change notifications from layout get ignored.
            DispatchQueue.main.async {
                coord.isProgrammaticScroll = false
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
        /// True when user is at/near the bottom — drives auto-scroll on content updates
        var userIsAtBottom: Bool = true
        /// Suppresses tracking during programmatic scrolls
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
    }
}
