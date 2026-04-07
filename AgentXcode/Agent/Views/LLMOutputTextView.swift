import SwiftUI
import AppKit
import AgentTerminalNeo

/// Local NSScrollView/NSTextView wrapper for the LLM Output HUD.
/// Renders text via TerminalNeoRenderer for markdown/table styling.
///
/// Scroll policy (mirrors ActivityLogView):
/// - Track `userIsAtBottom` via boundsDidChangeNotification on the clip view.
/// - When new content arrives AND the user is at the bottom → snap to end.
/// - When new content arrives AND the user has scrolled away → restore the
///   user's saved origin so the view doesn't jump.
/// - Programmatic scrolls are bracketed with `isProgrammaticScroll` so the
///   bounds observer doesn't misread them as the user scrolling.
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
        scrollView.drawsBackground = false

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
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
            // Real content change — snapshot scroll state BEFORE mutation so we
            // can either follow-to-end or restore the user's position.
            let wasAtBottom = coord.userIsAtBottom
            let savedY = scrollView.contentView.bounds.origin.y

            storage.setAttributedString(TerminalNeoRenderer.render(text))
            coord.lastContentLength = contentLen
            tv.layoutManager?.ensureLayout(for: tv.textContainer!)

            if wasAtBottom {
                coord.snapToEnd(tv)
            } else {
                coord.isProgrammaticScroll = true
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: savedY))
                scrollView.reflectScrolledClipView(scrollView.contentView)
                coord.isProgrammaticScroll = false
            }
        } else {
            // Cursor blink — swap last char only. Still snapshot+restore so the
            // implicit insertion-point scroll doesn't yank the view.
            let attrLen = storage.length
            if attrLen > 0 {
                let cursorChar = text.hasSuffix("█") ? "█" : " "
                let lastChar = String(storage.string.suffix(1))
                if lastChar != cursorChar {
                    let savedY = scrollView.contentView.bounds.origin.y
                    let wasAtBottom = coord.userIsAtBottom

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

                    if !wasAtBottom {
                        coord.isProgrammaticScroll = true
                        scrollView.contentView.scroll(to: NSPoint(x: 0, y: savedY))
                        scrollView.reflectScrolledClipView(scrollView.contentView)
                        coord.isProgrammaticScroll = false
                    }
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
        weak var scrollView: NSScrollView?
        var onContentHeight: ((CGFloat) -> Void)?
        var lastContentLength: Int = 0
        var lastReportedHeight: CGFloat = 0

        /// Tracks whether user is at/near bottom — updated via bounds notifications.
        var userIsAtBottom: Bool = true
        /// Suppresses tracking during programmatic scrolls.
        var isProgrammaticScroll: Bool = false
        /// Throttle for the bounds observer.
        private var scrollThrottled: Bool = false

        nonisolated(unsafe) var scrollObserver: NSObjectProtocol?

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
                    self.userIsAtBottom = self.isNearBottom(textView)
                    self.scrollThrottled = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.scrollThrottled = false
                    }
                }
            }
        }

        deinit {
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        /// User is "at bottom" if the visible bottom is within 60pt of content end.
        func isNearBottom(_ textView: NSTextView) -> Bool {
            guard let scrollView = textView.enclosingScrollView else { return true }
            let visibleBottom = scrollView.contentView.bounds.origin.y + scrollView.contentView.bounds.height
            let contentHeight = textView.frame.height
            return (contentHeight - visibleBottom) < 60
        }

        /// Instant scroll to end — no animation.
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
