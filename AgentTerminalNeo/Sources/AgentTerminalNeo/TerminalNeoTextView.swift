import AppKit
import Combine
import SwiftUI

public struct TerminalNeoTextView: NSViewRepresentable {
    public let text: String
    public var onContentHeight: ((CGFloat) -> Void)?
    public var textProvider: (@MainActor () -> String)?

    public init(text: String, onContentHeight: ((CGFloat) -> Void)? = nil, textProvider: (@MainActor () -> String)? = nil) {
        self.text = text
        self.onContentHeight = onContentHeight
        self.textProvider = textProvider
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator: @unchecked Sendable {
        let textSubject = PassthroughSubject<String, Never>()
        var cancellable: AnyCancellable?
        /// Used by updateNSView to dedup — independent of render tracking
        var updateLastLength: Int = 0
        /// Used by poll to dedup
        var pollLastLength: Int = 0
        var onContentHeight: ((CGFloat) -> Void)?
        weak var textView: NSTextView?
        var textProvider: (@MainActor () -> String)?
        private var pollTimer: DispatchSourceTimer?

        @MainActor func startPolling() {
            guard pollTimer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + .milliseconds(250), repeating: .milliseconds(250))
            timer.setEventHandler { [weak self] in
                MainActor.assumeIsolated {
                    self?.pollTextSource()
                }
            }
            timer.resume()
            pollTimer = timer
        }

        @MainActor private func pollTextSource() {
            guard let provider = textProvider else { return }
            let newText = provider()
            let newLen = (newText as NSString).length
            guard newLen != pollLastLength else { return }
            pollLastLength = newLen
            textSubject.send(newText)
        }

        deinit {
            pollTimer?.cancel()
            pollTimer = nil
        }
    }

    public func makeNSView(context: Context) -> NSScrollView {
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
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        context.coordinator.textView = textView
        context.coordinator.onContentHeight = onContentHeight
        context.coordinator.textProvider = textProvider
        context.coordinator.startPolling()

        let coord = context.coordinator
        coord.cancellable = coord.textSubject
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak coord] text in
                guard let coord, let tv = coord.textView else { return }
                let textCopy = text
                DispatchQueue.global(qos: .userInitiated).async {
                    let attributed = TerminalNeoRenderer.render(textCopy)
                    DispatchQueue.main.async { [weak coord] in
                        guard let coord, let tv = coord.textView else { return }
                        tv.textStorage?.setAttributedString(attributed)
                        tv.layoutManager?.ensureLayout(for: tv.textContainer!)
                        let h = (tv.layoutManager?.usedRect(for: tv.textContainer!).height ?? 40) + tv.textContainerInset.height * 2
                        coord.onContentHeight?(h)
                    }
                }
            }

        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coord = context.coordinator
        coord.textProvider = textProvider
        let len = (text as NSString).length
        guard len != coord.updateLastLength else { return }
        coord.updateLastLength = len
        coord.textSubject.send(text)
    }
}
