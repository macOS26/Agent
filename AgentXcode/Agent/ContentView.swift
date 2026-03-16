import SwiftUI
import AppKit
import WebKit

struct ContentView: View {
    @State private var viewModel = AgentViewModel()
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showSplash = true
    @State private var splashOpacity: Double = 0.85
    @State private var dependencyStatus: DependencyStatus?
    @State private var showDependencyOverlay = false
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var currentMatchIndex = 0
    @State private var totalMatches = 0
    @State private var showMCPServers = false
    @State private var showMessages = false
    @State private var showAccessibility = false

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
                    Text("Agent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    StatusDot(
                        isActive: viewModel.rootServiceActive,
                        wasActive: viewModel.rootWasActive,
                        isBusy: viewModel.isRunning,
                        enabled: viewModel.rootEnabled
                    )
                    Toggle("Daemon", isOn: $viewModel.rootEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .tint(.green)
                        .font(.caption)
                        .foregroundStyle(viewModel.rootEnabled ? .secondary : .tertiary)
                    StatusDot(
                        isActive: viewModel.messagesPolling,
                        wasActive: viewModel.messagesMonitorEnabled,
                        isBusy: false,
                        enabled: viewModel.messagesMonitorEnabled
                    )
                    Toggle("Messages", isOn: $viewModel.messagesMonitorEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .tint(.green)
                        .font(.caption)
                        .foregroundStyle(viewModel.messagesMonitorEnabled ? .secondary : .tertiary)
                }

                Button("Register") {
                    viewModel.registerAgent()
                    viewModel.registerDaemon()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Connect") {
                    viewModel.testConnection()
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


                Button { showMessages.toggle() } label: {
                    Image(systemName: "message")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showMessages) {
                    MessagesView(viewModel: viewModel)
                }

                Button { showAccessibility.toggle() } label: {
                    Image(systemName: "hand.raised")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showAccessibility) {
                    AccessibilitySettingsView()
                }

                Button { showMCPServers.toggle() } label: {
                    Image(systemName: "server.rack")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showMCPServers) {
                    MCPServersView()
                }

                Button { showSettings.toggle() } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showSettings) {
                    SettingsView(viewModel: viewModel)
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
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Project folder/file
            HStack(spacing: 4) {
                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.message = "Select a project folder or file"
                    if panel.runModal() == .OK, let url = panel.url {
                        viewModel.projectFolder = url.path
                    }
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Pick project folder or file")

                TextField("Project folder or file...", text: $viewModel.projectFolder)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)

                Button {
                    viewModel.projectFolder = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Clear project folder")
                .disabled(viewModel.projectFolder.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            Divider()

            // Search bar
            if showSearch {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Find in log...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 250)
                        .onSubmit { nextMatch() }
                    if !searchText.isEmpty {
                        Text(totalMatches > 0 ? "\(currentMatchIndex + 1)/\(totalMatches)" : "0 results")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 60)
                        Button { previousMatch() } label: {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(totalMatches == 0)
                        Button { nextMatch() } label: {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(totalMatches == 0)
                    }
                    Spacer()
                    Button { showSearch = false; searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                Divider()
            }

            // Tab bar (only when script tabs exist)
            if !viewModel.scriptTabs.isEmpty {
                TabBarView(viewModel: viewModel)
                Divider()
            }

            // Activity Log — switches between main and script tab
            if let selectedId = viewModel.selectedTabId,
               let tab = viewModel.scriptTabs.first(where: { $0.id == selectedId }) {
                ZStack(alignment: .bottomTrailing) {
                    ActivityLogView(
                        text: tab.activityLog,
                        searchText: searchText,
                        currentMatchIndex: currentMatchIndex,
                        onMatchCount: { count in
                            DispatchQueue.main.async {
                                totalMatches = count
                                if currentMatchIndex >= count { currentMatchIndex = max(0, count - 1) }
                            }
                        }
                    )
                    VStack(spacing: 4) {
                        if tab.isRunning {
                            Button { viewModel.cancelScriptTab(id: tab.id) } label: {
                                Label("Cancel Script", systemImage: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        if tab.isLLMRunning {
                            let vm = viewModel
                            let t = tab
                            Button { vm.stopTabTask(tab: t) } label: {
                                Label("Cancel LLM", systemImage: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(12)
                }
            } else {
                ActivityLogView(
                    text: viewModel.activityLog,
                    searchText: searchText,
                    currentMatchIndex: currentMatchIndex,
                    onMatchCount: { count in
                        DispatchQueue.main.async {
                            totalMatches = count
                            if currentMatchIndex >= count { currentMatchIndex = max(0, count - 1) }
                        }
                    }
                )
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

            // Input — switches between main and tab input
            if let selectedId = viewModel.selectedTabId,
               let tab = viewModel.scriptTabs.first(where: { $0.id == selectedId }) {
                // Tab input
                HStack {
                    let vm = viewModel
                    let t = tab
                    Button { vm.stopTabTask(tab: t) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Cancel tab LLM task")
                    .opacity(tab.isLLMRunning ? 1 : 0)
                    .disabled(!tab.isLLMRunning)

                    if tab.isLLMThinking {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if tab.isLLMRunning {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Running...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    TextField("Ask about \(tab.scriptName)...", text: Binding(
                        get: { tab.taskInput },
                        set: { tab.taskInput = $0 }
                    ))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            if !tab.taskInput.isEmpty {
                                vm.runTabTask(tab: t)
                            }
                        }

                    Button("Run") { vm.runTabTask(tab: t) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(tab.taskInput.isEmpty || (viewModel.selectedProvider == .claude && viewModel.apiKey.isEmpty))
                }
                .padding()
            } else {
                // Main tab input
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
                                .font(.system(size: 50, weight: .black, design: .monospaced))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .blue],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .blue, radius: 12)
                                .shadow(color: .blue.opacity(0.7), radius: 24)
                                .offset(y: 100)

                            Text("macOS26")
                                .font(.system(size: 50, weight: .black, design: .monospaced))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .blue],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .blue, radius: 12)
                                .shadow(color: .blue.opacity(0.7), radius: 24)
                                .offset(y: 155)

                            Text("")
                                .font(.system(size: 115, weight: .black, design: .monospaced))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .blue],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .blue, radius: 12)
                                .shadow(color: .blue.opacity(0.7), radius: 24)
                                .offset(y: 220)
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
            Task {
                await viewModel.fetchClaudeModels()

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
                // Cmd+F to toggle search bar
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers == "f" {
                    showSearch.toggle()
                    if !showSearch { searchText = "" }
                    return nil
                }

                // Escape to close search bar
                if event.keyCode == 53, showSearch {
                    showSearch = false
                    searchText = ""
                    return nil
                }

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

    private func nextMatch() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % totalMatches
    }

    private func previousMatch() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + totalMatches) % totalMatches
    }
}
