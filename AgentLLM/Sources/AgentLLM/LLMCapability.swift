import Foundation

/// What an LLM provider supports.
public struct LLMCapability: OptionSet, Sendable, Codable, Hashable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    /// Supports streaming token-by-token responses
    public static let streaming      = LLMCapability(rawValue: 1 << 0)
    /// Supports tool/function calling
    public static let tools          = LLMCapability(rawValue: 1 << 1)
    /// Supports image/vision input
    public static let vision         = LLMCapability(rawValue: 1 << 2)
    /// Supports system prompt / system role
    public static let systemPrompt   = LLMCapability(rawValue: 1 << 3)
    /// Supports JSON mode / structured output
    public static let jsonMode       = LLMCapability(rawValue: 1 << 4)
    /// Supports prompt caching
    public static let caching        = LLMCapability(rawValue: 1 << 5)
    /// Supports extended thinking / chain of thought
    public static let thinking       = LLMCapability(rawValue: 1 << 6)
    /// Supports web search as a built-in tool
    public static let webSearch      = LLMCapability(rawValue: 1 << 7)

    /// Common set for most cloud APIs
    public static let cloudDefault: LLMCapability = [.streaming, .tools, .systemPrompt]
    /// Common set for local models
    public static let localDefault: LLMCapability = [.streaming, .tools, .systemPrompt]
}
