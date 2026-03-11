import SwiftUI

struct ContentView: View {
    @State private var viewModel = AgentViewModel()
    @State private var showSettings = false
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    StatusDot(
                        isReady: viewModel.agentReady,
                        isActive: viewModel.userServiceActive,
                        isBusy: viewModel.isRunning
                    )
                    Text("User")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    StatusDot(
                        isReady: viewModel.daemonReady,
                        isActive: viewModel.rootServiceActive,
                        isBusy: viewModel.isRunning
                    )
                    Text("Root")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        Text(viewModel.userServiceActive || viewModel.rootServiceActive ? "Executing..." : "Running...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            ScrollViewReader { proxy in
                ScrollView {
                    Text(viewModel.activityLog.isEmpty ? "Ready. Enter a task below to begin." : viewModel.activityLog)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .foregroundStyle(viewModel.activityLog.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .id("logBottom")
                }
                .onChange(of: viewModel.activityLog) {
                    withAnimation {
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
            }

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
                if viewModel.isRunning {
                    Button { viewModel.stop() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Cancel running task")
                    .keyboardShortcut(.escape, modifiers: [])
                }

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
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
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

/// Stoplight: Green+pulse = running, Yellow = between modes, Red = stopped
struct StatusDot: View {
    let isReady: Bool
    let isActive: Bool  // command executing on this service
    let isBusy: Bool    // any task running

    @State private var pulse = false

    var dotColor: Color {
        if isActive { return .green }   // running
        if isBusy { return .yellow }    // between modes
        return .red                      // stopped
    }

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(dotColor.opacity(0.6), lineWidth: 2)
                    .frame(width: 14, height: 14)
                    .scaleEffect(pulse ? 1.5 : 1.0)
                    .opacity(pulse ? 0 : 1)
            )
            .animation(.easeInOut(duration: 0.3), value: dotColor)
            .onChange(of: isActive) {
                if isActive {
                    withAnimation(.easeOut(duration: 0.8).repeatForever(autoreverses: false)) {
                        pulse = true
                    }
                } else {
                    withAnimation(.default) { pulse = false }
                }
            }
            .onChange(of: isBusy) {
                if !isBusy {
                    withAnimation(.default) { pulse = false }
                }
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
        Form {
            Section("Provider") {
                Picker("Provider", selection: $viewModel.selectedProvider) {
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            }

            if viewModel.selectedProvider == .claude {
                Section("Claude API") {
                    SecureField("API Key", text: $viewModel.apiKey)
                        .frame(width: 300)

                    Picker("Model", selection: $viewModel.selectedModel) {
                        Text("Claude Sonnet 4").tag("claude-sonnet-4-20250514")
                        Text("Claude Opus 4").tag("claude-opus-4-20250514")
                        Text("Claude Haiku 3.5").tag("claude-haiku-3-5-20241022")
                    }
                }
            } else {
                Section("Ollama API") {
                    TextField("Endpoint", text: $viewModel.ollamaEndpoint)
                        .frame(width: 300)
                    SecureField("API Key (optional for local)", text: $viewModel.ollamaAPIKey)
                        .frame(width: 300)

                    HStack {
                        if viewModel.ollamaModels.isEmpty {
                            TextField("Model", text: $viewModel.ollamaModel)
                                .frame(width: 220)
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
                            .frame(width: 260)
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
        }
        .padding()
        .frame(width: 420)
    }
}
