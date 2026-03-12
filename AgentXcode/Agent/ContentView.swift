import SwiftUI
import AppKit

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

                            Text("Agent")
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

/// NSTextView-backed activity log — avoids SwiftUI Text layout storms on large/streaming content
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

        if text.isEmpty {
            guard !coord.showingPlaceholder else { return }
            textView.string = "Ready. Enter a task below to begin."
            textView.textColor = .secondaryLabelColor
            coord.showingPlaceholder = true
            coord.lastLength = 0
            return
        }

        let len = (text as NSString).length
        guard len != coord.lastLength || coord.showingPlaceholder else { return }

        if coord.showingPlaceholder {
            textView.textColor = .labelColor
            coord.showingPlaceholder = false
        }

        textView.string = text
        coord.lastLength = len
        textView.scrollToEndOfDocument(nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var lastLength = 0
        var showingPlaceholder = true
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
                        Text("Endpoint").font(.caption).foregroundStyle(.secondary)
                        TextField("https://ollama.com/api/chat", text: $viewModel.ollamaEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }

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
            VStack(alignment: .leading, spacing: 6) {
                Text("History")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Summarize after").font(.caption).foregroundStyle(.secondary)
                    Stepper("\(viewModel.maxHistoryBeforeSummary) tasks", value: $viewModel.maxHistoryBeforeSummary, in: 5...50)
                }
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
