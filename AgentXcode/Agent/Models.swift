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
    /// True if this record is a condensed summary of older records
    var isSummary: Bool

    init(prompt: String, summary: String, commandsRun: [String], isSummary: Bool = false) {
        self.id = UUID()
        self.date = Date()
        self.prompt = prompt
        self.summary = summary
        self.commandsRun = commandsRun
        self.isSummary = isSummary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        prompt = try c.decode(String.self, forKey: .prompt)
        summary = try c.decode(String.self, forKey: .summary)
        commandsRun = try c.decode([String].self, forKey: .commandsRun)
        isSummary = try c.decodeIfPresent(Bool.self, forKey: .isSummary) ?? false
    }
}

@MainActor @Observable
final class TaskHistory {
    static let shared = TaskHistory()

    private(set) var records: [TaskRecord] = []

    private var fileURL: URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("task_history.json") }
        let dir = appSupport.appendingPathComponent("Agent", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("task_history.json")
    }

    private init() {
        load()
    }

    func add(_ record: TaskRecord, maxBeforeSummary: Int = 10) {
        records.append(record)
        summarizeIfNeeded(max: maxBeforeSummary)
        save()
    }

    /// When records exceed `max`, condense the oldest ones into a single summary record,
    /// keeping the most recent `max` individual records intact.
    private func summarizeIfNeeded(max: Int) {
        guard max > 0, records.count > max else { return }
        let overflowCount = records.count - max
        let oldRecords = Array(records.prefix(overflowCount))
        guard !oldRecords.isEmpty else { return }

        // Build a condensed summary from the overflow records
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        let firstDate = oldRecords.first.map { formatter.string(from: $0.date) } ?? ""
        let lastDate = oldRecords.last.map { formatter.string(from: $0.date) } ?? ""

        let taskLines = oldRecords.map { record in
            "- \(record.prompt): \(record.summary)"
        }
        let condensed = taskLines.joined(separator: "\n")

        let allCommands = oldRecords.flatMap(\.commandsRun)
        // Keep a representative sample of commands
        let sampleCommands = Array(allCommands.prefix(10))

        let summaryRecord = TaskRecord(
            prompt: "(Summary of \(oldRecords.count) tasks, \(firstDate) – \(lastDate))",
            summary: condensed,
            commandsRun: sampleCommands,
            isSummary: true
        )

        // Replace overflow records with the single summary
        records = [summaryRecord] + Array(records.suffix(max))
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
            if record.isSummary {
                lines.append("[\(date)] Earlier work summary:")
                lines.append("  \(record.summary)")
            } else {
                lines.append("[\(date)] Task: \(record.prompt)")
                lines.append("  Result: \(record.summary)")
                if !record.commandsRun.isEmpty {
                    let cmds = record.commandsRun.prefix(5).joined(separator: "; ")
                    lines.append("  Commands: \(cmds)")
                }
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
