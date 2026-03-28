import SwiftUI

/// Menu content for the Agents menu bar item.
/// Each agent shows ▶ (play = run immediately) and ⏸ (pause = fill prompt to edit).
/// Version numbers are auto-bumped (1.0.45 → 1.0.46) when selected.
struct AgentsMenuContent: View {
    @ObservedObject private var recentAgents = RecentAgentsService.shared

    /// Group entries by agent name, preserving most-recent order.
    private var grouped: [(name: String, entries: [RecentAgentsService.AgentEntry])] {
        var seen: [String: [RecentAgentsService.AgentEntry]] = [:]
        var order: [String] = []
        for entry in recentAgents.entries {
            if seen[entry.agentName] == nil {
                order.append(entry.agentName)
                seen[entry.agentName] = []
            }
            seen[entry.agentName]?.append(entry)
        }
        return order.map { (name: $0, entries: seen[$0] ?? []) }
    }

    var body: some View {
        if recentAgents.entries.isEmpty {
            Text("No recent agents")
                .foregroundStyle(.secondary)
        } else {
            ForEach(grouped, id: \.name) { group in
                if group.entries.count == 1, let entry = group.entries.first {
                    agentRow(entry)
                } else {
                    Menu(group.name) {
                        ForEach(group.entries) { entry in
                            agentRow(entry)
                        }
                    }
                }
            }

            Divider()

            Button("Clear Recent Agents") {
                recentAgents.clearAll()
            }
        }
    }

    @ViewBuilder
    private func agentRow(_ entry: RecentAgentsService.AgentEntry) -> some View {
        // ▶ Play — run immediately
        Button {
            runImmediately(entry.populatedPrompt)
        } label: {
            Label(entry.menuLabel, systemImage: "play.fill")
        }

        // ⏸ Pause — fill prompt for editing
        Button {
            populateInput(entry.populatedPrompt)
        } label: {
            Label("Edit: \(entry.menuLabel)", systemImage: "pause.fill")
        }
    }

    private func runImmediately(_ prompt: String) {
        NotificationCenter.default.post(
            name: .runTaskImmediately,
            object: nil,
            userInfo: ["prompt": prompt]
        )
    }

    private func populateInput(_ prompt: String) {
        NotificationCenter.default.post(
            name: .populateTaskInput,
            object: nil,
            userInfo: ["prompt": prompt]
        )
    }
}

extension Notification.Name {
    static let populateTaskInput = Notification.Name("populateTaskInput")
    static let runTaskImmediately = Notification.Name("runTaskImmediately")
    static let runAgentDirect = Notification.Name("runAgentDirect")
    static let confirmRemoveAgent = Notification.Name("confirmRemoveAgent")
}
