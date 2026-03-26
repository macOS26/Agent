import Foundation
import MultiLineDiff

/// Errors for diff tool operations.
enum DiffError: LocalizedError {
    case invalidDiff

    var errorDescription: String? {
        switch self {
        case .invalidDiff: return "No diff_id or inline diff provided"
        }
    }
}

/// In-memory store for diff results keyed by UUID.
/// Allows `create_diff` to return a compact UUID that `apply_diff` can reference
/// instead of requiring the LLM to echo the entire diff text back.
@MainActor
final class DiffStore {
    static let shared = DiffStore()

    private var diffs: [UUID: DiffResult] = [:]
    private var sources: [UUID: String] = [:]
    private var editHistory: [String: String] = [:] // file path → original content before last edit

    private init() {}

    /// Store a diff and its source text. Returns the UUID key.
    func store(diff: DiffResult, source: String) -> UUID {
        let id = UUID()
        diffs[id] = diff
        sources[id] = source
        return id
    }

    /// Retrieve a stored diff by UUID.
    func retrieve(_ id: UUID) -> (diff: DiffResult, source: String)? {
        guard let diff = diffs[id], let source = sources[id] else { return nil }
        return (diff, source)
    }

    /// Record original content before an edit for undo support.
    func recordEdit(filePath: String, originalContent: String) {
        editHistory[filePath] = originalContent
    }

    /// Retrieve original content for undo.
    func lastEdit(for filePath: String) -> String? {
        editHistory[filePath]
    }

    /// Clear undo history for a file after successful undo.
    func clearEditHistory(for filePath: String) {
        editHistory.removeValue(forKey: filePath)
    }

    /// Clear all stored diffs (call at task start).
    func clear() {
        diffs.removeAll()
        sources.removeAll()
        editHistory.removeAll()
    }
}
