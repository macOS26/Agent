import Foundation

/// Protocol that any LLM provider must conform to.
/// Implement this to add a new LLM to Agent!
public protocol LLMProvider: Sendable {
    /// Provider configuration
    var config: LLMProviderConfig { get }

    /// System prompt sent with every request
    var systemPrompt: String { get set }

    /// Override system prompt (for coding mode, etc.)
    var overrideSystemPrompt: String? { get set }

    /// Temperature for generation
    var temperature: Double { get set }

    /// Whether to use compact tool descriptions
    var compactTools: Bool { get set }

    /// Send a streaming request. Calls onDelta with each text chunk.
    /// Returns the complete response when done.
    func sendStreaming(
        messages: [[String: Any]],
        activeGroups: Set<String>?,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> LLMResponse

    /// Fetch available models from the provider.
    /// Returns empty array if listing isn't supported.
    func fetchModels() async throws -> [LLMModelInfo]
}

/// Default implementations
public extension LLMProvider {
    var effectiveSystemPrompt: String {
        overrideSystemPrompt ?? systemPrompt
    }

    func fetchModels() async throws -> [LLMModelInfo] { [] }
}
