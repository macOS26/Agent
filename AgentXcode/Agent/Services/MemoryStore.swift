import Foundation

/// Persistent user memory that the LLM reads at the start of each task.
/// Users write notes/preferences here, LLM reads them for context.
/// Stored at ~/Documents/AgentScript/memory.md
@MainActor
final class MemoryStore {
    static let shared = MemoryStore()

    private let fileURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent("Documents/AgentScript")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("memory.md")
    }()

    private init() {}

    /// Read the full memory content.
    var content: String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    /// Write/replace the full memory content.
    func write(_ text: String) {
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Append a line to memory.
    func append(_ line: String) {
        var current = content
        if !current.isEmpty && !current.hasSuffix("\n") { current += "\n" }
        current += line + "\n"
        write(current)
    }

    /// Remove a line containing the given text.
    func removeLine(containing text: String) {
        let lines = content.components(separatedBy: "\n")
        let filtered = lines.filter { !$0.contains(text) }
        write(filtered.joined(separator: "\n"))
    }

    /// Memory content formatted for injection into LLM context.
    /// Returns empty string if no memory set.
    var contextBlock: String {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        return "\n\nUSER MEMORY (follow these preferences):\n\(text)"
    }
}
