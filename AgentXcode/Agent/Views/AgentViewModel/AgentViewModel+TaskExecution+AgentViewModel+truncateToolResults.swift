import MCPClient
import MultiLineDiff
import os.log
import Cocoa
                import Foundation

extension AgentViewModel {
    // MARK: - Tool Result Truncation
    static func truncateToolResults(_ results: [[String: Any]]) -> [[String: Any]] {
        results.map { result in
            guard var content = result["content"] as? String,
                  content.count > maxToolResultChars else { return result }
            let keepChars = maxToolResultChars / 2
            let head = String(content.prefix(keepChars))
            let tail = String(content.suffix(keepChars))
            let trimmed = content.count - maxToolResultChars
            content = head + "\n\n... (\(trimmed) chars truncated) ...\n\n" + tail
            var updated = result
            updated["content"] = content
            return updated
        }
    }


    /// Prune old messages to reduce token usage on long tasks.
    /// Keeps the first user message and the most recent messages.
    /// Middle messages are summarized into a compact text block.
}
