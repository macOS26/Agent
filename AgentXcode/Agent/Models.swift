import Foundation

enum AgentError: Error, LocalizedError {
    case noAPIKey
    case apiError(statusCode: Int, message: String)
    case invalidResponse
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .noAPIKey: "No API key configured. Open Settings to add your Anthropic API key."
        case .apiError(let code, let msg): "API error (\(code)): \(msg)"
        case .invalidResponse: "Invalid response from Claude API"
        case .invalidURL: "Invalid URL"
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

    private var isSummarizing = false

    func add(_ record: TaskRecord, maxBeforeSummary: Int = 10, apiKey: String = "", model: String = "") {
        records.append(record)
        save()
        if !isSummarizing, records.count > maxBeforeSummary {
            summarizeWithAI(apiKey: apiKey, model: model)
        }
    }

    /// Use the current LLM to summarize all records into 1 entry, offloaded async.
    private func summarizeWithAI(apiKey: String, model: String) {
        guard !apiKey.isEmpty else {
            fallbackSummarize()
            return
        }

        isSummarizing = true

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        let firstDate = records.first.map { formatter.string(from: $0.date) } ?? ""
        let lastDate = records.last.map { formatter.string(from: $0.date) } ?? ""
        let count = records.count

        let taskDump = records.map { r in
            if r.isSummary { return "Previous summary: \(r.summary)" }
            let d = formatter.string(from: r.date)
            let cmds = r.commandsRun.prefix(3).joined(separator: "; ")
            return "[\(d)] \(r.prompt) → \(r.summary)" + (cmds.isEmpty ? "" : " (cmds: \(cmds))")
        }.joined(separator: "\n")

        let prompt = """
        Summarize these \(count) task records into a single concise paragraph. \
        Focus on what was accomplished, key patterns, and important context for future tasks. \
        Keep it under 500 words. Do not use markdown. Just plain text.\n\n\(taskDump)
        """

        let messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": messages
        ]

        Task { @MainActor in
            do {
                let bodyData = try JSONSerialization.data(withJSONObject: body)
                let summaryText = try await Self.performSummaryRequest(bodyData: bodyData, apiKey: apiKey)

                let summaryRecord = TaskRecord(
                    prompt: "(AI Summary of \(count) tasks, \(firstDate) – \(lastDate))",
                    summary: summaryText.trimmingCharacters(in: .whitespacesAndNewlines),
                    commandsRun: [],
                    isSummary: true
                )
                self.records = [summaryRecord]
                self.save()
                self.isSummarizing = false
            } catch {
                self.fallbackSummarize()
            }
        }
    }

    /// Fallback if API call fails — just concatenate into 1 record.
    private func fallbackSummarize() {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        let firstDate = records.first.map { formatter.string(from: $0.date) } ?? ""
        let lastDate = records.last.map { formatter.string(from: $0.date) } ?? ""

        let condensed = records.map { r in
            r.isSummary ? r.summary : "- \(r.prompt): \(r.summary)"
        }.joined(separator: "\n")

        let summaryRecord = TaskRecord(
            prompt: "(Summary of \(records.count) tasks, \(firstDate) – \(lastDate))",
            summary: condensed,
            commandsRun: [],
            isSummary: true
        )
        records = [summaryRecord]
        save()
        isSummarizing = false
    }

    /// Network request off main actor
    nonisolated private static func performSummaryRequest(bodyData: Data, apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { throw AgentError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = bodyData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let textBlock = content.first(where: { $0["type"] as? String == "text" }),
              let summaryText = textBlock["text"] as? String else {
            throw AgentError.invalidResponse
        }
        return summaryText
    }

    func clearAll() {
        records.removeAll()
        save()
    }

    /// Returns the last task as a user/assistant message pair so the LLM sees it in conversation.
    func lastTaskMessages() -> [[String: Any]] {
        guard let last = records.last else { return [] }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let date = formatter.string(from: last.date)

        let recap: String
        if last.isSummary {
            recap = "Here is a summary of our previous work:\n\(last.summary)"
        } else {
            var parts = ["Previous task [\(date)]: \(last.prompt)", "Result: \(last.summary)"]
            if !last.commandsRun.isEmpty {
                parts.append("Commands run: \(last.commandsRun.prefix(5).joined(separator: "; "))")
            }
            recap = parts.joined(separator: "\n")
        }

        return [
            ["role": "user", "content": recap],
            ["role": "assistant", "content": "Understood, I have context from our previous work. What would you like to do next?"]
        ]
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
        // Capture data synchronously on main actor, then write async
        let data: Data?
        do {
            data = try JSONEncoder().encode(records)
        } catch {
            data = nil
        }
        guard let data else { return }
        
        let fileURL = self.fileURL
        Task.detached(priority: .background) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
