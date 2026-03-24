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
    @FocusState private var isTaskFieldFocused: Bool
    @State private var currentMatchIndex = 0
    @State private var totalMatches = 0
    @State private var showMCPServers = false
    @State private var showTools = false
    @State private var showOptions = false
    @ObservedObject private var aiMediator = AppleIntelligenceMediator.shared
    @State private var showAIPopover = false
    @State private var showMessages = false
    @State private var showAccessibility = false
    @State private var showQuitConfirm = false
    @State private var showClearConfirm = false
    @State private var showNewTabSheet = false
    @State private var showServices = false
    @State private var showAppleAIBanner = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderSectionView(
                viewModel: viewModel,
                showSettings: $showSettings,
                showHistory: $showHistory,
                showMCPServers: $showMCPServers,
                showTools: $showTools,
                showOptions: $showOptions,
                showMessages: $showMessages,
                showAccessibility: $showAccessibility,
                showAIPopover: $showAIPopover,
                showClearConfirm: $showClearConfirm
            )

            Divider()

            // Project folder/file (main tab)
            if viewModel.selectedTabId == nil {
                HStack(spacing: 4) {
                    ProjectFolderField(projectFolder: $viewModel.projectFolder)
                    TokenBadge(
                        taskIn: viewModel.taskInputTokens,
                        taskOut: viewModel.taskOutputTokens,
                        sessionIn: viewModel.sessionInputTokens,
                        sessionOut: viewModel.sessionOutputTokens,
                        providerName: viewModel.selectedProvider.displayName,
                        modelName: viewModel.selectedModel
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            // Per-tab project folder (when a tab is selected)
            if let selectedId = viewModel.selectedTabId,
               let tab = viewModel.scriptTabs.first(where: { $0.id == selectedId }) {
                HStack(spacing: 4) {
                    ProjectFolderField(
                        projectFolder: Binding(
                            get: { tab.projectFolder },
                            set: { tab.projectFolder = $0; viewModel.persistScriptTabs() }
                        )
                    )
                    TokenBadge(
                        taskIn: viewModel.taskInputTokens,
                        taskOut: viewModel.taskOutputTokens,
                        sessionIn: viewModel.sessionInputTokens,
                        sessionOut: viewModel.sessionOutputTokens,
                        providerName: viewModel.selectedProvider.displayName,
                        modelName: viewModel.selectedModel
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Divider()

            // Search bar
            if showSearch {
                SearchBarView(
                    searchText: $searchText,
                    totalMatches: totalMatches,
                    currentMatchIndex: currentMatchIndex,
                    previousMatch: previousMatch,
                    nextMatch: nextMatch,
                    onClose: { showSearch = false; searchText = "" }
                )
                .focused($isSearchFieldFocused)
            }

            // Tab bar (only when script tabs exist)
            if !viewModel.scriptTabs.isEmpty {
                TabBarView(viewModel: viewModel)
                Divider()
            }

            // Current task banner with cancel button
            if let prompt = activeTaskPrompt, !prompt.isEmpty {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Button { if activeAppleAIPrompt != nil { withAnimation(.easeInOut(duration: 0.2)) { showAppleAIBanner.toggle() } } } label: {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .frame(width: 14)
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .help("User prompt")
                        Text(prompt)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            if let selId = viewModel.selectedTabId,
                               let tab = viewModel.scriptTabs.first(where: { $0.id == selId }) {
                                if tab.isLLMRunning {
                                    viewModel.stopTabTask(tab: tab)
                                } else if tab.isRunning {
                                    viewModel.cancelScriptTab(id: tab.id)
                                }
                            } else {
                                viewModel.stop()
                            }
                        } label: {
                            Label("Cancel", systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.7))

                    // Apple AI prompt row (toggled by tapping person icon)
                    if showAppleAIBanner, let aiPrompt = activeAppleAIPrompt {
                        HStack(spacing: 6) {
                            Text("\u{F8FF}")
                                .font(.caption2)
                                .frame(width: 14)
                                .foregroundStyle(.white.opacity(0.8))
                            Text(aiPrompt)
                                .font(.caption)
                                .lineLimit(4)
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.6))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }

            // Activity Log — switches between main and script tab
            if let selectedId = viewModel.selectedTabId,
               let tab = viewModel.scriptTabs.first(where: { $0.id == selectedId }) {
                ZStack(alignment: .topTrailing) {
                    ActivityLogView(
                        text: tab.activityLog,
                        tabID: selectedId,
                        searchText: searchText,
                        currentMatchIndex: currentMatchIndex,
                        onMatchCount: { count in
                            DispatchQueue.main.async {
                                totalMatches = count
                                if currentMatchIndex >= count { currentMatchIndex = max(0, count - 1) }
                            }
                        }
                    )
                    // Cancel handled by green banner above
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
                    // Cancel button moved to green task banner
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
            InputSectionView(
                viewModel: viewModel,
                isTaskFieldFocused: $isTaskFieldFocused,
                selectedTab: viewModel.selectedTabId.flatMap { id in
                    viewModel.scriptTabs.first(where: { $0.id == id })
                }
            )
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTaskFieldFocused = true
            }
        }
        .overlay {
            DependencyOverlay(status: dependencyStatus, isVisible: $showDependencyOverlay)
        }
        .alert("Quit Agent?", isPresented: $showQuitConfirm) {
            Button("Quit", role: .destructive) { NSApplication.shared.terminate(nil) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to close the window and quit?")
        }
        .sheet(isPresented: $showNewTabSheet) {
            NewMainTabSheet(viewModel: viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appWillQuit)) { _ in
            viewModel.stopAll()
            viewModel.stopMessagesMonitor()
            Task { await MCPService.shared.disconnectAll() }
        }
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let status = DependencyChecker.check()
                DispatchQueue.main.async {
                    dependencyStatus = status
                    if status.allGood {
                        showDependencyOverlay = false
                    }
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

                // Cmd+T to create a new main LLM tab
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers == "t" {
                    showNewTabSheet = true
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
                
                // Keyboard shortcuts for common actions
                // Cmd+N: New task (focus input)
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers == "n" {
                    // Focus is already on text field, this is just a quick way to clear and start new
                    return nil
                }
                
                // Cmd+R: Run current task
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers == "r" {
                    if let selId = viewModel.selectedTabId,
                       let tab = viewModel.scriptTabs.first(where: { $0.id == selId }) {
                        if !tab.taskInput.isEmpty && !tab.isLLMRunning {
                            viewModel.runTabTask(tab: tab)
                        }
                    } else if !viewModel.taskInput.isEmpty && !viewModel.isRunning {
                        viewModel.run()
                    }
                    return nil
                }
                
                // Cmd+.: Cancel current task
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers == "." {
                    if let selId = viewModel.selectedTabId,
                       let tab = viewModel.scriptTabs.first(where: { $0.id == selId }),
                       tab.isLLMRunning {
                        viewModel.stopTabTask(tab: tab)
                    } else if viewModel.isRunning {
                        viewModel.stop()
                    }
                    return nil
                }
                
                // Cmd+Shift+P: Open System Prompts
                if event.modifierFlags.contains([.command, .shift]),
                   event.charactersIgnoringModifiers == "p" {
                    // System prompts window would be opened here
                    // For now, focus on settings
                    showSettings = true
                    return nil
                }
                
                // Cmd+Shift+M: Toggle Messages Monitor
                if event.modifierFlags.contains([.command, .shift]),
                   event.charactersIgnoringModifiers == "m" {
                    viewModel.messagesMonitorEnabled.toggle()
                    return nil
                }
                
                // Cmd+1-9: Switch between tabs
                if event.modifierFlags.contains(.command),
                   let char = event.charactersIgnoringModifiers,
                   let number = Int(char),
                   number >= 1, number <= 9 {
                    selectTab(number: number)
                    return nil
                }
                
                // Cmd+Shift+]: Next tab
                if event.modifierFlags.contains(.command),
                   event.keyCode == 124 { // Right arrow
                    nextTab()
                    return nil
                }
                
                // Cmd+Shift+[: Previous tab
                if event.modifierFlags.contains(.command),
                   event.keyCode == 123 { // Left arrow
                    previousTab()
                    return nil
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

    /// The prompt of the currently running task (main or selected tab).
    private var activeTaskPrompt: String? {
        // Check selected tab first
        if let selId = viewModel.selectedTabId,
           let tab = viewModel.scriptTabs.first(where: { $0.id == selId }) {
            if tab.isLLMRunning { return tab.currentTaskPrompt }
            if tab.isRunning { return "Running: \(tab.scriptName)" }
        }
        // Always show main tab's prompt if it's running
        if viewModel.isRunning { return viewModel.currentTaskPrompt }
        return nil
    }

    /// The Apple AI annotation for the currently running task.
    private var activeAppleAIPrompt: String? {
        // Check selected tab first
        if let selId = viewModel.selectedTabId,
           let tab = viewModel.scriptTabs.first(where: { $0.id == selId }) {
            let p = tab.currentAppleAIPrompt
            if !p.isEmpty { return p }
        }
        // Fall back to main tab
        let p = viewModel.currentAppleAIPrompt
        return p.isEmpty ? nil : p
    }

    /// Color for the currently selected tab.
    private var currentTabColor: Color {
        guard let selectedId = viewModel.selectedTabId else { return .red }
        if let tab = viewModel.scriptTabs.first(where: { $0.id == selectedId }) {
            return tab.isMainTab ? .blue : Self.tabColor(for: selectedId, in: viewModel.scriptTabs)
        }
        return .red
    }
}

// MARK: - Keyboard Shortcuts

extension ContentView {
    /// Focus the text input field
    func focusInput() {
        // Input field is managed by SwiftUI focus state
        // This is called from keyboard shortcut
    }
    
    /// Navigate to next tab (cycle right)
    func nextTab() {
        if viewModel.scriptTabs.isEmpty { return }
        guard let currentId = viewModel.selectedTabId else {
            // On main tab - go to first script tab
            if let firstTab = viewModel.scriptTabs.first {
                viewModel.selectedTabId = firstTab.id
            }
            return
        }
        
        guard let currentIndex = viewModel.scriptTabs.firstIndex(where: { $0.id == currentId }) else { return }
        let nextIndex = (currentIndex + 1) % viewModel.scriptTabs.count
        viewModel.selectedTabId = viewModel.scriptTabs[nextIndex].id
        viewModel.persistScriptTabs()
    }
    
    /// Navigate to previous tab (cycle left)
    func previousTab() {
        if viewModel.scriptTabs.isEmpty { return }
        guard let currentId = viewModel.selectedTabId else {
            // On main tab - go to last script tab
            if let lastTab = viewModel.scriptTabs.last {
                viewModel.selectedTabId = lastTab.id
            }
            return
        }
        
        guard let currentIndex = viewModel.scriptTabs.firstIndex(where: { $0.id == currentId }) else { return }
        let prevIndex = (currentIndex - 1 + viewModel.scriptTabs.count) % viewModel.scriptTabs.count
        viewModel.selectedTabId = viewModel.scriptTabs[prevIndex].id
        viewModel.persistScriptTabs()
    }
    
    /// Navigate to tab by number (1-9)
    func selectTab(number: Int) {
        guard number >= 1, number <= 9 else { return }
        if number == 1 {
            // Cmd+1 = Main tab
            viewModel.selectMainTab()
            return
        }
        
        // Cmd+2-9 = Script tabs (0-indexed from index 1)
        let tabIndex = number - 2
        guard tabIndex < viewModel.scriptTabs.count else { return }
        viewModel.selectedTabId = viewModel.scriptTabs[tabIndex].id
        viewModel.persistScriptTabs()
    }
}

// MARK: - Services Popover

struct ServicesPopover: View {
    @Bindable var viewModel: AgentViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Services")
                .font(.headline)
            
            Text("Background agents for shell commands and automation.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Divider()
            
            Grid(alignment: .leading, verticalSpacing: 10) {
                GridRow {
                    StatusDot(
                        isActive: viewModel.userServiceActive,
                        wasActive: viewModel.userWasActive,
                        isBusy: viewModel.isRunning,
                        enabled: viewModel.userEnabled
                    )
                    Text("User Agent")
                        .font(.caption)
                    Toggle("", isOn: $viewModel.userEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .tint(.green)
                        .labelsHidden()
                }
                GridRow {
                    StatusDot(
                        isActive: viewModel.rootServiceActive,
                        wasActive: viewModel.rootWasActive,
                        isBusy: viewModel.isRunning,
                        enabled: viewModel.rootEnabled
                    )
                    Text("Daemon Agent")
                        .font(.caption)
                    Toggle("", isOn: $viewModel.rootEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .tint(.green)
                        .labelsHidden()
                }
            }
            
            Divider()
            
            // Action Buttons
            HStack(spacing: 8) {
                Button("Unregister") {
                    viewModel.unregisterAgent()
                    viewModel.unregisterDaemon()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                
                Button("Register") {
                    viewModel.registerAgent()
                    viewModel.registerDaemon()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                
                Button("Connect") {
                    viewModel.testConnection()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
