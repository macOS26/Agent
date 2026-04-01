import Foundation

/// Full configuration for an LLM provider instance.
public struct LLMProviderConfig: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public var displayName: String
    public var kind: LLMProviderKind
    public var endpoint: LLMEndpoint
    public var apiKey: String
    public var model: String
    public var capabilities: LLMCapability
    public var temperature: Double
    public var maxTokens: Int
    public var contextSize: Int
    public var enabled: Bool

    public init(
        id: String,
        displayName: String,
        kind: LLMProviderKind,
        endpoint: LLMEndpoint,
        apiKey: String = "",
        model: String = "",
        capabilities: LLMCapability = .cloudDefault,
        temperature: Double = 0.7,
        maxTokens: Int = 8192,
        contextSize: Int = 0,
        enabled: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.capabilities = capabilities
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.contextSize = contextSize
        self.enabled = enabled
    }

    /// True if this provider requires an API key
    public var requiresAPIKey: Bool {
        kind == .cloudAPI
    }

    /// True if configuration is valid enough to attempt a connection
    public var isConfigured: Bool {
        if requiresAPIKey && apiKey.isEmpty { return false }
        if model.isEmpty { return false }
        if endpoint.baseURL.isEmpty { return false }
        return true
    }
}
