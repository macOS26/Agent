import Foundation

/// API protocol format the provider uses.
public enum LLMAPIProtocol: String, Codable, Sendable, CaseIterable {
    /// Anthropic Messages API format
    case anthropic
    /// OpenAI Chat Completions format
    case openAI
    /// Ollama native format
    case ollama
    /// Apple Foundation Models (on-device)
    case foundationModel
    /// Custom / native format
    case custom

    public var displayName: String {
        switch self {
        case .anthropic: "Anthropic Compatible"
        case .openAI: "OpenAI Compatible"
        case .ollama: "Ollama Native"
        case .foundationModel: "Apple Intelligence"
        case .custom: "Custom"
        }
    }
}

/// Full configuration for an LLM provider instance.
/// The app creates these — the package just defines the shape.
public struct LLMProviderConfig: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public var displayName: String
    public var kind: LLMProviderKind
    public var apiProtocol: LLMAPIProtocol
    public var endpoint: LLMEndpoint
    public var apiKey: String
    public var model: String
    public var capabilities: LLMCapability
    public var temperature: Double
    public var maxTokens: Int
    public var contextSize: Int
    public var enabled: Bool
    /// Whether API key is optional (local servers, etc.)
    public var apiKeyOptional: Bool
    /// Alternative protocols this provider supports (e.g. LM Studio: openAI, anthropic, custom)
    public var supportedProtocols: [LLMAPIProtocol]

    public init(
        id: String,
        displayName: String,
        kind: LLMProviderKind,
        apiProtocol: LLMAPIProtocol = .openAI,
        endpoint: LLMEndpoint,
        apiKey: String = "",
        model: String = "",
        capabilities: LLMCapability = .cloudDefault,
        temperature: Double = 0.2,
        maxTokens: Int = 8192,
        contextSize: Int = 0,
        enabled: Bool = true,
        apiKeyOptional: Bool = false,
        supportedProtocols: [LLMAPIProtocol] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.apiProtocol = apiProtocol
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.capabilities = capabilities
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.contextSize = contextSize
        self.enabled = enabled
        self.apiKeyOptional = apiKeyOptional
        self.supportedProtocols = supportedProtocols
    }

    /// True if this provider requires an API key
    public var requiresAPIKey: Bool {
        !apiKeyOptional && kind == .cloudAPI
    }

    /// True if configuration is valid enough to attempt a connection
    public var isConfigured: Bool {
        if requiresAPIKey && apiKey.isEmpty { return false }
        if model.isEmpty { return false }
        if kind != .embedded && endpoint.chatURL.isEmpty { return false }
        return true
    }
}
