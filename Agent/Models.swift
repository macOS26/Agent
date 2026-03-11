import Foundation

enum AgentError: Error, LocalizedError {
    case noAPIKey
    case apiError(statusCode: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey: "No API key configured. Open Settings to add your Anthropic API key."
        case .apiError(let code, let msg): "API error (\(code)): \(msg)"
        case .invalidResponse: "Invalid response from Claude API"
        }
    }
}

// MARK: - Task History

struct TaskRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let prompt: String
    let summary: String
    let commandsRun: [String]

    init(prompt: String, summary: String, commandsRun: [String]) {
        self.id = UUID()
        self.date = Date()
        self.prompt = prompt
        self.summary = summary
        self.commandsRun = commandsRun
    }
}

@MainActor
final class TaskHistory: Observable {
    static let shared = TaskHistory()

    private(set) var records: [TaskRecord] = []

    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Agent", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("task_history.json")
    }

    private init() {
        load()
    }

    func add(_ record: TaskRecord) {
        records.append(record)
        save()
    }

    func clearAll() {
        records.removeAll()
        save()
    }

    /// Build a context string of recent history for the system prompt
    func contextForPrompt(maxRecent: Int = 20) -> String {
        guard !records.isEmpty else { return "" }
        let recent = records.suffix(maxRecent)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        var lines: [String] = ["\n\nPrevious task history (most recent last):"]
        for record in recent {
            let date = formatter.string(from: record.date)
            lines.append("[\(date)] Task: \(record.prompt)")
            lines.append("  Result: \(record.summary)")
            if !record.commandsRun.isEmpty {
                let cmds = record.commandsRun.prefix(5).joined(separator: "; ")
                lines.append("  Commands: \(cmds)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([TaskRecord].self, from: data)
        } catch {
            records = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // silent fail
        }
    }
}
