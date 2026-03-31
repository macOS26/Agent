import Foundation
import FoundationModels

extension AgentViewModel {
    // MARK: - Message History Compression

    /// Compress old tool results — use Apple AI summary if cached, otherwise first 3 lines.
    /// Last 4 messages keep full content. Tool calls (assistant) stay intact.
    static func compressMessages(_ messages: [[String: Any]], keepRecent: Int = 4) -> [[String: Any]] {
        guard messages.count > keepRecent + 1 else { return messages }

        var result: [[String: Any]] = []
        let middleEnd = messages.count - keepRecent

        for i in 0..<middleEnd {
            var msg = messages[i]
            let role = msg["role"] as? String ?? ""

            if role == "user" {
                if var blocks = msg["content"] as? [[String: Any]] {
                    for j in 0..<blocks.count {
                        if blocks[j]["type"] as? String == "tool_result",
                           let content = blocks[j]["content"] as? String, content.count > 200 {
                            let key = content.hashValue
                            if let cached = _summaryCache[key] {
                                blocks[j]["content"] = cached
                            } else {
                                let preview = content.components(separatedBy: "\n").prefix(3).joined(separator: "\n")
                                blocks[j]["content"] = preview + "\n(... already processed)"
                            }
                        }
                    }
                    msg["content"] = blocks
                }
            } else if role == "assistant" {
                // Compress old assistant text (keep tool_use blocks intact)
                if var blocks = msg["content"] as? [[String: Any]] {
                    for j in 0..<blocks.count {
                        if blocks[j]["type"] as? String == "text",
                           let text = blocks[j]["text"] as? String, text.count > 150 {
                            blocks[j]["text"] = String(text.prefix(100)) + "..."
                        }
                    }
                    msg["content"] = blocks
                }
            }
            result.append(msg)
        }

        result.append(contentsOf: messages.suffix(keepRecent))
        return result
    }

    /// Use Apple AI to summarize long text, fall back to truncation if unavailable.
    private static func summarizeOrTruncate(_ text: String) -> String {
        let key = text.hashValue
        if let cached = _summaryCache[key] { return cached }

        // Fallback: truncate (Apple AI summary happens async via compressMessagesAsync)
        let truncated = String(text.prefix(150)) + "...(truncated \(text.count) chars)"
        _summaryCache[key] = truncated
        return truncated
    }

    /// Cache summaries so we don't re-summarize the same content.
    nonisolated(unsafe) private static var _summaryCache: [Int: String] = [:]

    /// Async version: summarize old messages using Apple AI before sending.
    /// Call this before compressMessages for best results.
    static func summarizeOldMessages(_ messages: inout [[String: Any]], keepRecent: Int = 4) async {
        guard messages.count > keepRecent + 1, FoundationModelService.isAvailable else {
            return
        }

        let middleEnd = messages.count - keepRecent
        let session = LanguageModelSession(model: .default, instructions: Instructions("Summarize in 1-2 concise sentences. Keep file paths, function names, errors, and key results."))

        for i in 1..<middleEnd {
            let role = messages[i]["role"] as? String ?? ""

            if role == "user" {
                if var blocks = messages[i]["content"] as? [[String: Any]] {
                    var changed = false
                    for j in 0..<blocks.count {
                        if let content = blocks[j]["content"] as? String, content.count > 300 {
                            let key = content.hashValue
                            if _summaryCache[key] == nil {
                                let input = String(content.prefix(2000))
                                if let resp = try? await session.respond(to: input) {
                                    _summaryCache[key] = "[summary] " + resp.content
                                }
                            }
                            if let cached = _summaryCache[key] {
                                blocks[j]["content"] = cached
                                changed = true
                            }
                        }
                    }
                    if changed { messages[i]["content"] = blocks }
                } else if let text = messages[i]["content"] as? String, text.count > 300 {
                    let key = text.hashValue
                    if _summaryCache[key] == nil {
                        let input = String(text.prefix(2000))
                        if let resp = try? await session.respond(to: input) {
                            _summaryCache[key] = "[summary] " + resp.content
                        }
                    }
                    if let cached = _summaryCache[key] { messages[i]["content"] = cached }
                }
            }
        }
    }

    // MARK: - Token Estimation (~4 chars per token)

    /// Estimate input tokens from message array.
    static func estimateTokens(messages: [[String: Any]]) -> Int {
        var chars = 0
        for msg in messages {
            if let text = msg["content"] as? String {
                chars += text.count
            } else if let blocks = msg["content"] as? [[String: Any]] {
                for block in blocks {
                    if let text = block["text"] as? String { chars += text.count }
                    else if let text = block["content"] as? String { chars += text.count }
                }
            }
        }
        return max(1, chars / 4)
    }

    /// Estimate output tokens from response content blocks.
    static func estimateTokens(content: [[String: Any]]) -> Int {
        var chars = 0
        for block in content {
            if let text = block["text"] as? String { chars += text.count }
            if let input = block["input"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: input) {
                chars += data.count
            }
        }
        return max(1, chars / 4)
    }
}
