import Foundation

/// Tracks recently run agent script prompts for the Agents menu.
/// Stores the original user prompt that triggered each agent run.
@MainActor
final class RecentAgentsService: ObservableObject {
    static let shared = RecentAgentsService()

    private let key = "recentAgentPrompts"
    private let maxCount = 20

    struct AgentEntry: Codable, Identifiable {
        let id: UUID
        let agentName: String
        let prompt: String
        let date: Date

        init(agentName: String, prompt: String) {
            self.id = UUID()
            self.agentName = agentName
            self.prompt = prompt
            self.date = Date()
        }
    }

    @Published private(set) var entries: [AgentEntry] = []

    private init() {
        load()
    }

    /// Record that an agent was run with a given prompt.
    func recordRun(agentName: String, prompt: String) {
        // Remove duplicates of same prompt
        entries.removeAll { $0.prompt == prompt }
        entries.insert(AgentEntry(agentName: agentName, prompt: prompt), at: 0)
        if entries.count > maxCount {
            entries = Array(entries.prefix(maxCount))
        }
        save()
    }

    /// Clear all entries.
    func clearAll() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AgentEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
