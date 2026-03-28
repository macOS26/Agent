import SwiftUI

// MARK: - Notification Handlers

extension ContentView {

    /// Overlay view that handles all notification-based actions.
    /// Attach with .background() to avoid adding complexity to the main body.
    struct NotificationLayer: View {
        @Bindable var viewModel: AgentViewModel
        @State private var showRemoveAgentConfirm = false
        @State private var removeAgentName = ""
        @State private var removeAgentArgs = ""

        var body: some View {
            Color.clear
                .frame(width: 0, height: 0)
                .onReceive(NotificationCenter.default.publisher(for: .populateTaskInput)) { n in
                    guard let prompt = n.userInfo?["prompt"] as? String else { return }
                    if let selId = viewModel.selectedTabId,
                       let tab = viewModel.scriptTabs.first(where: { $0.id == selId }) {
                        tab.taskInput = prompt
                    } else {
                        viewModel.taskInput = prompt
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .runTaskImmediately)) { n in
                    guard let prompt = n.userInfo?["prompt"] as? String else { return }
                    if let selId = viewModel.selectedTabId,
                       let tab = viewModel.scriptTabs.first(where: { $0.id == selId }) {
                        tab.taskInput = prompt
                        viewModel.runTabTask(tab: tab)
                    } else {
                        viewModel.taskInput = prompt
                        viewModel.run()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .runAgentDirect)) { n in
                    guard let prompt = n.userInfo?["prompt"] as? String else { return }
                    let parts = prompt.components(separatedBy: " ")
                    let name = parts.count > 1 ? parts[1] : prompt
                    let args = parts.count > 2 ? parts.dropFirst(2).joined(separator: " ") : ""
                    Task { await viewModel.runAgentDirect(name: name, arguments: args) }
                }
                .onReceive(NotificationCenter.default.publisher(for: .confirmRemoveAgent)) { n in
                    guard let name = n.userInfo?["agentName"] as? String,
                          let args = n.userInfo?["arguments"] as? String else { return }
                    if RecentAgentsService.shared.entries.contains(where: { $0.agentName == name && $0.arguments == args }) {
                        removeAgentName = name
                        removeAgentArgs = args
                        showRemoveAgentConfirm = true
                    }
                }
                .alert("Agent Failed", isPresented: $showRemoveAgentConfirm) {
                    Button("Remove", role: .destructive) {
                        RecentAgentsService.shared.removeRun(agentName: removeAgentName, arguments: removeAgentArgs)
                    }
                    Button("Keep", role: .cancel) { }
                } message: {
                    Text("'\(removeAgentName)' failed. Remove from Agents menu?")
                }
        }
    }
}
