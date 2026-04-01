import Foundation

/// Persists daily token usage to ~/Library/Application Support/Agent/token_usage.json
@MainActor
final class TokenUsageStore {
    static let shared = TokenUsageStore()

    struct DayRecord: Codable {
        let date: String          // "2026-03-29"
        var inputTokens: Int
        var outputTokens: Int
        var totalTokens: Int { inputTokens + outputTokens }
    }

    private(set) var days: [DayRecord] = []
    private let fileURL: URL

    private init() {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls.first ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Agent")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("token_usage.json")
        load()
    }

    /// Record token usage — adds to today's running total.
    func record(inputTokens: Int, outputTokens: Int) {
        let today = Self.dateString(Date())
        if let idx = days.firstIndex(where: { $0.date == today }) {
            days[idx].inputTokens += inputTokens
            days[idx].outputTokens += outputTokens
        } else {
            days.append(DayRecord(date: today, inputTokens: inputTokens, outputTokens: outputTokens))
        }
        // Keep last 31 days
        if days.count > 31 {
            days = Array(days.suffix(31))
        }
        save()
    }

    /// Today's totals.
    var todayInput: Int {
        let today = Self.dateString(Date())
        return days.first(where: { $0.date == today })?.inputTokens ?? 0
    }
    var todayOutput: Int {
        let today = Self.dateString(Date())
        return days.first(where: { $0.date == today })?.outputTokens ?? 0
    }

    /// Last N days of records for charting.
    func recentDays(_ count: Int = 30) -> [DayRecord] {
        Array(days.suffix(count))
    }

    private static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([DayRecord].self, from: data) else { return }
        days = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(days) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
