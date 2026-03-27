import SwiftUI

/// Menu content for the Agents menu bar item.
/// Groups by agent name, each agent has a submenu showing its prompts.
struct AgentsMenuContent: View {
    @ObservedObject private var recentAgents = RecentAgentsService.shared

    /// Group entries by agent name, preserving most-recent order.
    private var grouped: [(name: String, prompts: [RecentAgentsService.AgentEntry])] {
        var seen: [String: [RecentAgentsService.AgentEntry]] = [:]
        var order: [String] = []
        for entry in recentAgents.entries {
            if seen[entry.agentName] == nil {
                order.append(entry.agentName)
                seen[entry.agentName] = []
            }
            seen[entry.agentName]?.append(entry)
        }
        return order.map { (name: $0, prompts: seen[$0] ?? []) }
    }

    var body: some View {
        if recentAgents.entries.isEmpty {
            Text("No recent agents")
                .foregroundStyle(.secondary)
        } else {
            ForEach(grouped, id: \.name) { group in
                if group.prompts.count == 1, let entry = group.prompts.first {
                    Button {
                        populateInput(entry.prompt)
                    } label: {
                        Text("\(group.name) — \(entry.prompt)")
                    }
                } else {
                    Menu(group.name) {
                        ForEach(group.prompts) { entry in
                            Button(entry.prompt) {
                                populateInput(entry.prompt)
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
