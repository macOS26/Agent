import SwiftUI

/// Header section containing status indicators and toolbar buttons
struct HeaderSectionView: View {
    @Bindable var viewModel: AgentViewModel
    @Binding var showSettings: Bool
    @Binding var showHistory: Bool
    @Binding var showMCPServers: Bool
    @Binding var showTools: Bool
    @Binding var showOptions: Bool
    @Binding var showMessages: Bool
    @Binding var showAccessibility: Bool
    @Binding var showAIPopover: Bool
    @Binding var showClearConfirm: Bool
    @ObservedObject var aiMediator = AppleIntelligenceMediator.shared
    
    var currentTabColor: Color {
        guard let selectedId = viewModel.selectedTabId,
              let tab = viewModel.scriptTabs.first(where: { $0.id == selectedId }) else {
            return .primary
        }
        return ContentView.tabColor(for: tab.id, in: viewModel.scriptTabs)
    }
    
    var body: some View {
        HStack {
            // Service status indicators (left side)
            HStack(spacing: 4) {
                StatusDot(
                    isActive: viewModel.userServiceActive,
                    wasActive: viewModel.userWasActive,
                    isBusy: viewModel.isRunning,
                    enabled: viewModel.userEnabled
                )
                Text("Agent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .help("User Agent: \(viewModel.userServiceActive ? "Running" : (viewModel.userEnabled ? "Stopped" : "Disabled"))")

            HStack(spacing: 4) {
                StatusDot(
                    isActive: viewModel.rootServiceActive,
                    wasActive: viewModel.rootWasActive,
                    isBusy: viewModel.isRunning,
                    enabled: viewModel.rootEnabled
                )
                Text("Daemon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .help("Daemon: \(viewModel.rootServiceActive ? "Running" : (viewModel.rootEnabled ? "Stopped" : "Disabled"))")

            // Unified status spinner — main tab or active script tab
            if let selId = viewModel.selectedTabId,
               let tab = viewModel.scriptTabs.first(where: { $0.id == selId }) {
                let color = tab.isMainTab ? Color.blue : ContentView.tabColor(for: selId, in: viewModel.scriptTabs)
                if tab.isLLMThinking {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text("Thinking...")
                            .font(.caption).foregroundStyle(color)
                    }
                } else if tab.isLLMRunning {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text(tab.taskQueue.isEmpty ? "Running..." : "Running... +\(tab.taskQueue.count) queued")
                            .font(.caption).foregroundStyle(color)
                    }
                }
            } else {
                if viewModel.isThinking {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text("Thinking...")
                            .font(.caption).foregroundStyle(.blue)
                    }
                } else if viewModel.isRunning {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text(viewModel.mainTaskQueue.isEmpty
                             ? (viewModel.rootServiceActive ? "Root..." : viewModel.userServiceActive ? "Executing..." : "Running...")
                             : "Running... +\(viewModel.mainTaskQueue.count) queued")
                            .font(.caption)
                            .foregroundStyle(viewModel.rootServiceActive ? .orange : .secondary)
                    }
                }
            }

            Spacer()

            // Toolbar buttons (right side)
            Button { showMessages.toggle() } label: {
                Image(systemName: "message.fill")
                    .frame(width: 20, height: 16)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help(viewModel.messagesMonitorEnabled ? "Messages Monitor: ON (click to configure)" : "Messages Monitor: OFF (click to configure)")
            .popover(isPresented: $showMessages) {
                MessagesView(viewModel: viewModel)
            }

            Button { showAccessibility.toggle() } label: {
                Image(systemName: "hand.raised")
                    .frame(width: 20, height: 16)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .popover(isPresented: $showAccessibility) {
                AccessibilitySettingsView()
            }

            Button { showMCPServers.toggle() } label: {
                Image(systemName: "server.rack")
                    .frame(width: 20, height: 16)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .popover(isPresented: $showMCPServers) {
                MCPServersView()
            }

            Button { showTools.toggle() } label: {
                Image(systemName: "wrench.and.screwdriver")
                    .frame(width: 20, height: 16)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .popover(isPresented: $showTools) {
                ToolsView(selectedProvider: $viewModel.selectedProvider, viewModel: viewModel)
            }

            Button { showSettings.toggle() } label: {
                Image(systemName: "cpu")
                    .frame(width: 20, height: 16)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .popover(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel)
            }

            // Apple Intelligence Mediator Toggle Button
            Button {
                showAIPopover.toggle()
            } label: {
                Image(systemName: AppleIntelligenceMediator.isAvailable ? "brain.fill" : "brain")
                    .foregroundStyle(aiMediator.isEnabled ? .blue : .secondary)
                    .frame(width: 20, height: 16)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help("Apple Intelligence Settings")
            .popover(isPresented: $showAIPopover) {
                AppleIntelligencePopover()
            }

            Button { showOptions.toggle() } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 20, height: 16)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .popover(isPresented: $showOptions) {
                AgentOptionsView(viewModel: viewModel)
            }

            Button { showHistory.toggle() } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .frame(width: 20, height: 16)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .popover(isPresented: $showHistory) {
                HistoryView(
                    prompts: viewModel.currentTabPromptHistory,
                    errorHistory: viewModel.errorHistory,
                    taskSummaries: viewModel.taskSummaries,
                    tabName: viewModel.currentTabName,
                    onClear: { type in viewModel.clearHistory(type: type) },
                    onRerun: { prompt in
                        // Set the prompt in the current tab's input field and run it
                        if let selectedId = viewModel.selectedTabId,
                           let tab = viewModel.scriptTabs.first(where: { $0.id == selectedId }) {
                            tab.taskInput = prompt
                            viewModel.runTabTask(tab: tab)
                        } else {
                            viewModel.taskInput = prompt
                            viewModel.run()
                        }
                    }
                )
            }

            Button { showClearConfirm = true } label: {
                Image(systemName: "trash")
                    .foregroundStyle(currentTabColor)
                    .frame(width: 20, height: 16)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
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
    }
}