import SwiftUI
import AppKit
import WebKit

struct ContentView: View {
    @State private var viewModel = AgentViewModel()
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var dependencyStatus: DependencyStatus?
    @State private var showDependencyOverlay = true
    @State private var showSearch = false
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    @State private var currentMatchIndex = 0
    @State private var totalMatches = 0
    @State private var showMCPServers = false
    @State private var showTools = false
    @State private var showOptions = false
    @State private var showMessages = false
    @State private var showAccessibility = false
    @State private var showQuitConfirm = false
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    StatusDot(
                        isActive: viewModel.userServiceActive,
                        wasActive: viewModel.userWasActive,
                        isBusy: viewModel.isRunning,
                        enabled: viewModel.userEnabled
                    )
                    Toggle("User", isOn: $viewModel.userEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .tint(.green)
                        .font(.caption)
                        .foregroundStyle(viewModel.userEnabled ? .secondary : .tertiary)
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

                Button { showTools.toggle() } label: {
                    Image(systemName: "wrench.and.screwdriver")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showTools) {
                    ToolsView(selectedProvider: $viewModel.selectedProvider)
                }

                Button { showSettings.toggle() } label: {
                    Image(systemName: "cpu")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showSettings) {
                    SettingsView(viewModel: viewModel)
                }

                Button { showOptions.toggle() } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showOptions) {
                    AgentOptionsView(viewModel: viewModel)
                }

                Button { showHistory.toggle() } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showHistory) {
                    HistoryView(history: viewModel.history)
                }

                Button { showClearConfirm = true } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isRunning)
                .alert("Clear Log", isPresented: $showClearConfirm) {
                    Button("Clear", role: .destructive) { viewModel.clearSelectedLog() }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text(viewModel.selectedTabId != nil
                         ? "Clear this tab's log?"
                         : "Clear all task history?")
                }
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
                    .textContentType(.none)
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
                        .focused($isSearchFieldFocused)
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
                ZStack(alignment: .topTrailing) {
                    ActivityLogView(
                        text: tab.activityLog,
                        tabID: tab.id,
                        searchText: searchText,
                        currentMatchIndex: currentMatchIndex,
                        onMatchCount: { count in
                            DispatchQueue.main.async {
                                totalMatches = count
                                if currentMatchIndex >= count { currentMatchIndex = max(0, count - 1) }
                            }
                        }
                    )
                    let tabColor = Self.tabColor(for: tab.id, in: viewModel.scriptTabs)
                    VStack(spacing: 4) {
                        if tab.isRunning {
                            Button { viewModel.cancelScriptTab(id: tab.id) } label: {
                                Label("Cancel Script", systemImage: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(tabColor)
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
                                    .foregroundStyle(tabColor)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(12)
                }
            } else {
                ZStack(alignment: .topTrailing) {
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
                    if viewModel.isRunning {
                        Button { viewModel.stop() } label: {
                            Label("Cancel LLM", systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(12)
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

            // Input — switches between main and tab input
            if let selectedId = viewModel.selectedTabId,
               let tab = viewModel.scriptTabs.first(where: { $0.id == selectedId }) {
                // Tab input
                HStack {
                    let vm = viewModel
                    let t = tab
                    let tabColor = Self.tabColor(for: tab.id, in: vm.scriptTabs)
                    Button { vm.stopTabTask(tab: t) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(tabColor)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Cancel tab LLM task")
                    .opacity(tab.isLLMRunning ? 1 : 0)
                    .disabled(!tab.isLLMRunning)

                    Button { vm.captureScreenshot() } label: {
                        Image(systemName: "camera")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Take a screenshot to attach")

                    Button { vm.pasteImageFromClipboard() } label: {
                        Image(systemName: "photo.on.rectangle.angled")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Paste image from clipboard")

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
                    .opacity(viewModel.isRunning || viewModel.isThinking ? 1 : 0)
                    .disabled(!viewModel.isRunning && !viewModel.isThinking)

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
                            Text(viewModel.rootServiceActive ? "Root..." : viewModel.userServiceActive ? "Executing..." : "Running...")
                                .font(.caption)
                                .foregroundStyle(viewModel.rootServiceActive ? .orange : .secondary)
                        }
                    }

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
        .frame(minWidth: 900, minHeight: 500)
        .overlay {
            DependencyOverlay(status: dependencyStatus, isVisible: $showDependencyOverlay)
        }
        .alert("Quit Agent?", isPresented: $showQuitConfirm) {
            Button("Quit", role: .destructive) { NSApplication.shared.terminate(nil) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to close the window and quit?")
        }
        .onReceive(NotificationCenter.default.publisher(for: .appWillQuit)) { _ in
            viewModel.stopAll()
            viewModel.stopMessagesMonitor()
            Task { await MCPService.shared.disconnectAll() }
        }
        .onAppear {
            Task {
                await viewModel.fetchClaudeModels()
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let status = DependencyChecker.check()
                DispatchQueue.main.async {
                    dependencyStatus = status
                }
            }
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Cmd+W to close current tab or quit
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers == "w" {
                    if let selId = viewModel.selectedTabId {
                        viewModel.closeScriptTab(id: selId)
                    } else if viewModel.scriptTabs.isEmpty {
                        showQuitConfirm = true
                    } else {
                        // Tabs exist but Main is selected — do nothing
                    }
                    return nil
                }

                // Cmd+F to toggle search bar
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers == "f" {
                    showSearch.toggle()
                    if showSearch {
                        isSearchFieldFocused = true
                    } else {
                        searchText = ""
                    }
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

                // Escape key to cancel active context (tab or main)
                if event.keyCode == 53 {
                    if let selId = viewModel.selectedTabId,
                       let tab = viewModel.scriptTabs.first(where: { $0.id == selId }),
                       tab.isLLMRunning {
                        viewModel.stopTabTask(tab: tab)
                        return nil
                    } else if viewModel.isRunning {
                        viewModel.stop()
                        return nil
                    }
                }

                // Up/Down arrow for prompt history (per-tab or main)
                if event.keyCode == 126 || event.keyCode == 125 {
                    let direction = event.keyCode == 126 ? -1 : 1
                    if let tabId = viewModel.selectedTabId,
                       let tab = viewModel.scriptTabs.first(where: { $0.id == tabId }) {
                        tab.navigateHistory(direction: direction)
                    } else {
                        viewModel.navigatePromptHistory(direction: direction)
                    }
                    return nil
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

    private static let tabColors: [Color] = [
        .orange, .purple, .pink, .cyan, .mint, .indigo, .teal, .yellow
    ]

    /// Assign a consistent color per tab based on its index. Main tab uses .red.
    static func tabColor(for tabId: UUID, in tabs: [ScriptTab]) -> Color {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return .orange }
        return tabColors[idx % tabColors.count]
    }
}
