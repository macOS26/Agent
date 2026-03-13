import SwiftUI
import AppKit
@preconcurrency import WebKit

struct ContentView: View {
    @State private var viewModel = AgentViewModel()
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showSplash = true
    @State private var splashOpacity: Double = 0.85
    @State private var dependencyStatus: DependencyStatus?
    @State private var showDependencyOverlay = false

    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    StatusDot(
                        isActive: viewModel.userServiceActive,
                        wasActive: viewModel.userWasActive,
                        isBusy: viewModel.isRunning
                    )
                    Text("User")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    StatusDot(
                        isActive: viewModel.rootServiceActive,
                        wasActive: viewModel.rootWasActive,
                        isBusy: viewModel.isRunning,
                        enabled: viewModel.rootEnabled
                    )
                    Toggle("Root", isOn: $viewModel.rootEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .tint(.green)
                        .font(.caption)
                        .foregroundStyle(viewModel.rootEnabled ? .secondary : .tertiary)
                }

                Button("Register") {
                    viewModel.registerAgent()
                    viewModel.registerDaemon()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                if viewModel.isThinking {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Thinking...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.isRunning {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Text(viewModel.rootServiceActive ? "Root executing..." : viewModel.userServiceActive ? "Executing..." : "Running...")
                            .font(.caption)
                            .foregroundStyle(viewModel.rootServiceActive ? .orange : .secondary)
                    }
                }


                Button { showHistory.toggle() } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showHistory) {
                    HistoryView(history: viewModel.history)
                }

                Button { viewModel.clearLog() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isRunning)

                Button { showSettings.toggle() } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showSettings) {
                    SettingsView(viewModel: viewModel)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Activity Log
            ActivityLogView(text: viewModel.activityLog)

            Divider()

            // Screenshot previews
            if !viewModel.attachedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.attachedImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(.secondary.opacity(0.3))
                                    )
                                Button {
                                    viewModel.removeAttachment(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.white, .red)
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        }
                        Text("\(viewModel.attachedImages.count) image(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Clear All") { viewModel.removeAllAttachments() }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
            }

            // Input — always enabled so user can override a running task
            HStack {
                Button { viewModel.stop() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Cancel running task")
                .opacity(viewModel.isRunning ? 1 : 0)
                .disabled(!viewModel.isRunning)

                Button { viewModel.captureScreenshot() } label: {
                    Image(systemName: "camera")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Take a screenshot to attach")

                Button { viewModel.pasteImageFromClipboard() } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Paste image from clipboard")

                TextField("Enter task...", text: $viewModel.taskInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !viewModel.taskInput.isEmpty {
                            viewModel.run()
                        }
                    }

                Button("Run") { viewModel.run() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(viewModel.taskInput.isEmpty || (viewModel.selectedProvider == .claude && viewModel.apiKey.isEmpty))
            }
            .padding()
        }

            DependencyOverlay(status: dependencyStatus, isVisible: $showDependencyOverlay)

            if showSplash {
                Color(.windowBackgroundColor)
                    .overlay {
                        ZStack {
                            Image("AgentIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .shadow(color: .blue.opacity(0.6), radius: 40)
                                .shadow(color: .blue.opacity(0.3), radius: 80)
                                .padding(40)

                            Text("Agent!")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .blue],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .blue, radius: 12)
                                .shadow(color: .blue.opacity(0.7), radius: 24)
                                .offset(y: 90)
                        }
                    }
                    .opacity(splashOpacity)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.6)) {
                    splashOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    showSplash = false
                }
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let status = DependencyChecker.check()
                DispatchQueue.main.async {
                    dependencyStatus = status
                    if !status.allGood {
                        showDependencyOverlay = true
                    }
                }
            }
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Intercept Cmd+V for image paste
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers == "v" {
                    if viewModel.pasteImageFromClipboard() {
                        return nil
                    }
                }

                // Escape key to cancel running task
                if event.keyCode == 53, viewModel.isRunning {
                    viewModel.stop()
                    return nil
                }

                // Up/Down arrow for prompt history
                if true {
                    if event.keyCode == 126 { // Up arrow
                        viewModel.navigatePromptHistory(direction: -1)
                        return nil
                    } else if event.keyCode == 125 { // Down arrow
                        viewModel.navigatePromptHistory(direction: 1)
                        return nil
                    }
                }

                return event
            }
        }
    }
}

/// NSTextView-backed activity log — avoids SwiftUI Text layout storms on large/streaming content.
/// Detects image file paths in log output and renders them inline.
struct ActivityLogView: NSViewRepresentable {
    let text: String

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
        coord.onHTMLReady = { [weak textView, weak coord] in
            guard let textView, let coord else { return }
            let attributed = coord.buildAttributedString(from: currentText)
            textView.textStorage?.setAttributedString(attributed)
            textView.scrollToEndOfDocument(nil)
        }

        if text.isEmpty {
            guard !coord.showingPlaceholder else { return }
            textView.textStorage?.setAttributedString(
                NSAttributedString(string: "Ready. Enter a task below to begin.",
                                   attributes: [.font: coord.font, .foregroundColor: NSColor.secondaryLabelColor])
            )
            coord.showingPlaceholder = true
            coord.lastLength = 0
            coord.clearCache()
            return
        }

        let len = (text as NSString).length
        guard len != coord.lastLength || coord.showingPlaceholder else { return }
        coord.showingPlaceholder = false

        let attributed = coord.buildAttributedString(from: text)
        textView.textStorage?.setAttributedString(attributed)
        coord.lastLength = len
        textView.scrollToEndOfDocument(nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor class Coordinator: NSObject, WKNavigationDelegate {
        var lastLength = 0
        var showingPlaceholder = true
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
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

        // Matches image files
        private static let imagePathPattern = try! NSRegularExpression(
            pattern: #"(/[^\s"'<>]+\.(?:jpg|jpeg|png|gif|tiff|bmp|webp|heic|ico|icon))"#,
            options: .caseInsensitive
        )
        // Matches HTML files
        private static let htmlPathPattern = try! NSRegularExpression(
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
            let imageMatches = Self.imagePathPattern.matches(in: text, range: fullRange)
            let htmlMatches = Self.htmlPathPattern.matches(in: text, range: fullRange)

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
                    // HTML: use cached snapshot, invalidate if file or sibling resources changed
                    if let cached = htmlCache[offset], cached.mtime >= effectiveMtime {
                        if fileSize > 0 && renderedSizes.contains(fileSize) { continue }
                        renderedSizes.insert(fileSize)
                        appendImage(cached.image, maxWidth: 480.0, to: result, attrs: baseAttrs)
                    } else if !htmlPending.contains(offset) {
                        htmlCache.removeValue(forKey: offset)
                        htmlPending.insert(offset)
                        let path = match.path
                        snapshotHTML(path: path, offset: offset)
                    }
                } else {
                    // Image file
                    if fileSize > 0 && renderedSizes.contains(fileSize) { continue }
                    renderedSizes.insert(fileSize)

                    let image: NSImage
                    if let cached = imageCache[offset], cached.mtime >= effectiveMtime {
                        image = cached.image
                    } else if let loaded = NSImage(contentsOfFile: match.path) {
                        imageCache[offset] = (image: loaded, mtime: fileMtime)
                        image = loaded
                    } else {
                        continue
                    }
                    appendImage(image, maxWidth: 300.0, to: result, attrs: baseAttrs)
                }
            }

            if lastEnd < nsText.length {
                let remaining = NSRange(location: lastEnd, length: nsText.length - lastEnd)
                result.append(renderMarkdown(nsText.substring(with: remaining)))
            }

            return result
        }

        private func appendImage(_ image: NSImage, maxWidth: CGFloat, to result: NSMutableAttributedString, attrs: [NSAttributedString.Key: Any]) {
            let scale = min(1.0, maxWidth / image.size.width)
            let scaledSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)

            let resized = NSImage(size: scaledSize, flipped: false) { rect in
                image.draw(in: rect)
                return true
            }

            let attachment = NSTextAttachment()
            let cell = NSTextAttachmentCell(imageCell: resized)
            attachment.attachmentCell = cell

            result.append(NSAttributedString(string: "\n", attributes: attrs))
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: "\n", attributes: attrs))
        }

        // MARK: - Markdown rendering

        private static let codeBlockPattern = try! NSRegularExpression(
            pattern: "```\\w*\\n?([\\s\\S]*?)```",
            options: []
        )

        private func renderMarkdown(_ text: String) -> NSAttributedString {
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            let codeMatches = Self.codeBlockPattern.matches(in: text, range: fullRange)

            guard !codeMatches.isEmpty else {
                return renderInlineMarkdown(text)
            }

            let result = NSMutableAttributedString()
            var lastEnd = 0
            let codeBg = NSColor.unemphasizedSelectedContentBackgroundColor

            for match in codeMatches {
                if match.range.location > lastEnd {
                    let before = nsText.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                    result.append(renderInlineMarkdown(before))
                }
                let codeContent = nsText.substring(with: match.range(at: 1))
                let codeAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.labelColor,
                    .backgroundColor: codeBg
                ]
                result.append(NSAttributedString(string: "\n", attributes: [.font: font]))
                result.append(NSAttributedString(string: codeContent, attributes: codeAttrs))
                result.append(NSAttributedString(string: "\n", attributes: [.font: font]))
                lastEnd = match.range.location + match.range.length
            }

            if lastEnd < nsText.length {
                let remaining = nsText.substring(from: lastEnd)
                result.append(renderInlineMarkdown(remaining))
            }

            return result
        }

        private func renderInlineMarkdown(_ text: String) -> NSAttributedString {
            guard !text.isEmpty else { return NSAttributedString() }

            do {
                var options = AttributedString.MarkdownParsingOptions()
                options.interpretedSyntax = .inlineOnlyPreservingWhitespace
                let parsed = try AttributedString(markdown: text, options: options)

                let nsAttr = NSMutableAttributedString(parsed)
                let fullRange = NSRange(location: 0, length: nsAttr.length)

                // Set base monospaced font and color
                nsAttr.addAttribute(.font, value: font, range: fullRange)
                nsAttr.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)

                // Apply bold/italic/code from inline presentation intents
                nsAttr.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
                    // Check for presentation intent stored by markdown parser
                    if let intentValue = attrs[.inlinePresentationIntent] as? Int {
                        let intent = InlinePresentationIntent(rawValue: UInt(intentValue))
                        var styledFont = self.font
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
                return NSAttributedString(string: text, attributes: [
                    .font: font,
                    .foregroundColor: NSColor.labelColor
                ])
            }
        }

        private static var snapshotOffsetKey: UInt8 = 0
        private static var snapshotPathKey: UInt8 = 0

        /// Render HTML to image via off-screen WKWebView
        private func snapshotHTML(path: String, offset: Int) {
            let fileURL = URL(fileURLWithPath: path)
            let config = WKWebViewConfiguration()
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 480, height: 800), configuration: config)
            webView.navigationDelegate = self

            // Store context for the delegate callback
            objc_setAssociatedObject(webView, &Self.snapshotOffsetKey, offset, .OBJC_ASSOCIATION_RETAIN)
            objc_setAssociatedObject(webView, &Self.snapshotPathKey, path, .OBJC_ASSOCIATION_RETAIN)

            // Retain the web view until snapshot completes
            activeWebViews[offset] = webView

            webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
        }

        // WKNavigationDelegate — snapshot when page finishes loading
        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                let offset = objc_getAssociatedObject(webView, &Self.snapshotOffsetKey) as? Int ?? 0

                // Wait for images/fonts to actually load (up to 4s, polling every 250ms)
                // Check naturalWidth > 0 because img.complete is true even for broken images
                var allImagesLoaded = false
                for _ in 0..<16 {
                    let ready = try? await webView.evaluateJavaScript("""
                        document.readyState === 'complete' &&
                        Array.from(document.images).every(i => i.complete && i.naturalWidth > 0)
                        """) as? Bool
                    if ready == true { allImagesLoaded = true; break }
                    try? await Task.sleep(for: .milliseconds(250))
                }

                if allImagesLoaded {
                    // Extra settle time for CSS animations/fonts
                    try? await Task.sleep(for: .milliseconds(300))

                    let snapConfig = WKSnapshotConfiguration()
                    snapConfig.snapshotWidth = 480 as NSNumber

                    if let snapshot = try? await webView.takeSnapshot(configuration: snapConfig) {
                        let path = objc_getAssociatedObject(webView, &Self.snapshotPathKey) as? String ?? ""
                        let fileMtime = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? Date()
                        let dirPath = (path as NSString).deletingLastPathComponent
                        let dirMtime = (try? FileManager.default.attributesOfItem(atPath: dirPath)[.modificationDate] as? Date) ?? Date()
                        self.htmlCache[offset] = (image: snapshot, mtime: max(fileMtime, dirMtime))
                    }
                }
                // If images didn't load, don't cache — allow retry on next render
                self.htmlPending.remove(offset)
                self.activeWebViews.removeValue(forKey: offset)
                // Force re-render
                self.lastLength = 0
                self.onHTMLReady?()
            }
        }

        // WKNavigationDelegate — handle load failures
        nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                let offset = objc_getAssociatedObject(webView, &Self.snapshotOffsetKey) as? Int ?? 0
                self.htmlPending.remove(offset)
                self.activeWebViews.removeValue(forKey: offset)
            }
        }

        func clearCache() {
            imageCache.removeAll()
            htmlCache.removeAll()
            htmlPending.removeAll()
            activeWebViews.removeAll()
        }
    }
}

/// Stoplight: Green = running, Yellow = was green + cooling down, Red = not running
struct StatusDot: View {
    let isActive: Bool
    let wasActive: Bool
    let isBusy: Bool
    var enabled: Bool = true

    var dotColor: Color {
        if !enabled { return .gray }
        if isActive || (wasActive && isBusy) { return .green }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            if dotColor == .green {
                PulseRing()
            }
        }
        .frame(width: 12, height: 12) // Fixed frame prevents layout shift
    }
}

struct PulseRing: View {
    private let duration: Double = 1.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration) / duration
            let ease = 1.0 - pow(1.0 - progress, 2.0) // easeOut curve
            Circle()
                .stroke(Color.green.opacity(0.6), lineWidth: 2)
                .frame(width: 12, height: 12)
                .scaleEffect(1.0 + 1.5 * ease)
                .opacity(0.8 * (1.0 - ease))
        }
    }
}

struct HistoryView: View {
    let history: TaskHistory

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Task History")
                    .font(.headline)
                Spacer()
                Text("\(history.records.count) tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Clear All") { history.clearAll() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(history.records.isEmpty)
            }
            .padding()

            Divider()

            if history.records.isEmpty {
                Text("No tasks yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(history.records.reversed()) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(record.prompt)
                                .font(.system(.body, weight: .medium))
                                .lineLimit(2)
                            Spacer()
                            Text(dateFormatter.string(from: record.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(record.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !record.commandsRun.isEmpty {
                            Text("\(record.commandsRun.count) commands")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

struct SettingsView: View {
    @Bindable var viewModel: AgentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Provider toggle
            VStack(alignment: .leading, spacing: 6) {
                Text("Provider")
                    .font(.headline)
                Picker("Provider", selection: $viewModel.selectedProvider) {
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, -20)
            }

            Divider()

            if viewModel.selectedProvider == .claude {
                // Claude settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Claude API")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key").font(.caption).foregroundStyle(.secondary)
                        SecureField("sk-ant-...", text: $viewModel.apiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model").font(.caption).foregroundStyle(.secondary)
                        Picker("Model", selection: $viewModel.selectedModel) {
                            Text("Claude Sonnet 4").tag("claude-sonnet-4-20250514")
                            Text("Claude Opus 4").tag("claude-opus-4-20250514")
                            Text("Claude Haiku 3.5").tag("claude-haiku-3-5-20241022")
                        }
                        .labelsHidden()
                    }
                }
            } else if viewModel.selectedProvider == .ollama {
                // Cloud Ollama settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ollama Cloud")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key").font(.caption).foregroundStyle(.secondary)
                        SecureField("Required for cloud", text: $viewModel.ollamaAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            if viewModel.ollamaModels.isEmpty {
                                TextField("Model name", text: $viewModel.ollamaModel)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Picker("Model", selection: $viewModel.ollamaModel) {
                                    ForEach(viewModel.ollamaModels) { model in
                                        HStack(spacing: 4) {
                                            Text(model.name)
                                            if model.supportsVision {
                                                Image(systemName: "eye")
                                                    .foregroundStyle(.blue)
                                                    .font(.caption2)
                                            }
                                        }
                                        .tag(model.name)
                                    }
                                }
                                .labelsHidden()
                            }

                            Button {
                                viewModel.fetchOllamaModels()
                            } label: {
                                if viewModel.isFetchingModels {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.isFetchingModels)
                            .help("Fetch available models")
                        }
                    }
                }
            } else {
                // Local Ollama settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Local Ollama")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Endpoint").font(.caption).foregroundStyle(.secondary)
                        TextField("http://localhost:11434/api/chat", text: $viewModel.localOllamaEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            if viewModel.localOllamaModels.isEmpty {
                                TextField("Model name", text: $viewModel.localOllamaModel)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Picker("Model", selection: $viewModel.localOllamaModel) {
                                    ForEach(viewModel.localOllamaModels) { model in
                                        HStack(spacing: 4) {
                                            Text(model.name)
                                            if model.supportsVision {
                                                Image(systemName: "eye")
                                                    .foregroundStyle(.blue)
                                                    .font(.caption2)
                                            }
                                        }
                                        .tag(model.name)
                                    }
                                }
                                .labelsHidden()
                            }

                            Button {
                                viewModel.fetchLocalOllamaModels()
                            } label: {
                                if viewModel.isFetchingLocalModels {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.isFetchingLocalModels)
                            .help("Fetch available local models")
                        }
                    }
                }
            }
            Divider()

            // History settings
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Summarize after").font(.caption).foregroundStyle(.secondary)
                    Stepper("\(viewModel.maxHistoryBeforeSummary) tasks",
                           onIncrement: { if viewModel.maxHistoryBeforeSummary > 5 { viewModel.maxHistoryBeforeSummary -= 5 } },
                           onDecrement: { if viewModel.maxHistoryBeforeSummary < 50 { viewModel.maxHistoryBeforeSummary += 5 } })
                }
                Spacer().frame(width: 16)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Visible tasks in chat").font(.caption).foregroundStyle(.secondary)
                    Stepper("\(viewModel.visibleTaskCount)",
                           onIncrement: { if viewModel.visibleTaskCount > 1 { viewModel.visibleTaskCount -= 1 } },
                           onDecrement: { if viewModel.visibleTaskCount < 5 { viewModel.visibleTaskCount += 1 } })
                }
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
