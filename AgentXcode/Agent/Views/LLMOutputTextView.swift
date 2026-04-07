import SwiftUI
import AppKit
import AgentTerminalNeo

/// Local NSScrollView/NSTextView wrapper for the LLM Output HUD.
/// Renders text via TerminalNeoRenderer for markdown/table styling.
///
/// Scroll policy:
/// - Track `userIsAtBottom` via boundsDidChangeNotification on the clip view.
///   The moment the user scrolls away from the bottom, auto-follow is OFF.
///   When they scroll back to the bottom, auto-follow turns back ON.
/// - When new content arrives AND user is at the bottom → scroll to end.
/// - When new content arrives AND user has scrolled away → do nothing; the
///   appended text extends the document below the visible area, and the clip
///   view origin stays put on its own.
///
/// Jitter avoidance (matches the proven path in TerminalNeoTextView):
/// - Incremental append for non-table streaming chunks — no full re-layout.
/// - CATransaction.setDisableActions(true) wrap suppresses implicit animations.
/// - Full TerminalNeoRenderer re-render only for tables, shrinks, or first load.
/// - Cursor-blink path mutates only the trailing char with no scroll calls.
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
            let wasAtBottom = coord.userIsAtBottom
            let isAppend = contentLen > coord.lastContentLength && coord.lastContentLength > 0
            let hasTable = contentText.contains("|\n") && contentText.contains("---")
            if hasTable { coord.needsTableRender = true }

            CATransaction.begin()
            CATransaction.setDisableActions(true)

            if isAppend && !coord.needsTableRender {
                // FAST PATH: incremental append. No layout reflow above the
                // appended range, so no jitter. Strip trailing cursor first if
                // present, then append the delta with terminal styling.
                let attrLen = storage.length
                if attrLen > 0 {
                    let lastChar = storage.string.suffix(1)
                    if lastChar == "█" || lastChar == " " {
                        storage.deleteCharacters(in: NSRange(location: attrLen - 1, length: 1))
                    }
                }
                let startIdx = storage.length
                if startIdx < text.count {
                    let newPart = String(text[text.index(text.startIndex, offsetBy: startIdx)...])
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
                }
            } else {
                // SLOW PATH: full markdown re-render. Used for tables, shrinks
                // (text reset), and first render. Wrapped in CATransaction so
                // implicit animations don't fire.
                storage.setAttributedString(TerminalNeoRenderer.render(text))
                tv.layoutManager?.ensureLayout(for: tv.textContainer!)
            }

            CATransaction.commit()
            coord.lastContentLength = contentLen

            // Latch table-render mode while the tail looks like a table row
            let lastNonEmpty = contentText.components(separatedBy: "\n").last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
            if lastNonEmpty.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                coord.needsTableRender = true
            }

            // Follow-bottom: only scroll if the user was already at the bottom.
            // If they scrolled away, leave the clip view origin alone — the
            // appended content extends the document below their view naturally.
            if wasAtBottom {
                coord.snapToEnd(tv)
            }
        } else {
            // Cursor blink: swap last char only. No scroll calls. Skip during
            // table-render mode to avoid mutating freshly rendered table layout.
            guard !coord.needsTableRender else { return }
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
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    storage.beginEditing()
                    storage.replaceCharacters(in: NSRange(location: attrLen - 1, length: 1),
                        with: NSAttributedString(string: cursorChar, attributes: [
                            .font: font, .foregroundColor: color
                        ]))
                    storage.endEditing()
                    CATransaction.commit()
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
        /// Latched on once we see a markdown table — stays on so we keep doing
        /// full re-renders instead of incremental appends (tables can't be
        /// extended by simple character append).
        var needsTableRender: Bool = false

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

        /// Instant scroll to end — no animation, brackets the call with
        /// isProgrammaticScroll so the bounds observer doesn't misread it.
        func snapToEnd(_ textView: NSTextView) {
            guard let scrollView = textView.enclosingScrollView else {
                textView.scrollToEndOfDocument(nil)
                return
            }
            isProgrammaticScroll = true
            textView.scrollToEndOfDocument(nil)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            isProgrammaticScroll = false
            userIsAtBottom = true
        }
    }
}
