import Foundation

/// Standardized response from any LLM provider.
public struct LLMResponse: @unchecked Sendable {
    /// Response content blocks (text, tool_use, etc.)
    public var content: [[String: Any]]
    /// Why the response ended (end_turn, tool_use, max_tokens, etc.)
    public var stopReason: String
    /// Input tokens used (0 if provider doesn't report)
    public var inputTokens: Int
    /// Output tokens used (0 if provider doesn't report)
    public var outputTokens: Int

    public init(
        content: [[String: Any]] = [],
        stopReason: String = "end_turn",
        inputTokens: Int = 0,
        outputTokens: Int = 0
    ) {
        self.content = content
        self.stopReason = stopReason
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}
