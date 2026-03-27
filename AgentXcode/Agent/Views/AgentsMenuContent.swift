import SwiftUI

/// Menu content for the Agents menu bar item.
/// Groups by agent name, each agent has a submenu showing its prompts with arguments.
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
                    // Single entry — show inline with argument hint
                    Button {
                        populateInput(entry.populatedPrompt)
                    } label: {
                        Text(entry.menuLabel)
                    }
                } else {
                    // Multiple entries — submenu per agent
                    Menu(group.name) {
                        ForEach(group.entries) { entry in
                            Button {
                                populateInput(entry.populatedPrompt)
                            } label: {
                                if entry.arguments.isEmpty {
                                    Text("run \(entry.agentName)")
                                } else {
                                    Text(entry.arguments)
                                }
                            }
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
}
