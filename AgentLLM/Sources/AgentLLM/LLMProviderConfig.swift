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
    /// Whether API key is optional (e.g. vLLM, local servers)
    public var apiKeyOptional: Bool
    /// Alternative API protocols this provider supports (e.g. LM Studio: openAI, anthropic, custom)
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
        if kind != .embedded && endpoint.baseURL.isEmpty { return false }
        return true
    }

    // MARK: - Presets for all 10 Agent! providers

    public static let claude = LLMProviderConfig(
        id: "claude", displayName: "Claude",
        kind: .cloudAPI, apiProtocol: .anthropic,
        endpoint: .claude,
        capabilities: [.streaming, .tools, .vision, .systemPrompt, .caching, .thinking, .webSearch]
    )

    public static let openAI = LLMProviderConfig(
        id: "openAI", displayName: "OpenAI",
        kind: .cloudAPI, apiProtocol: .openAI,
        endpoint: .openAI,
        capabilities: [.streaming, .tools, .vision, .systemPrompt]
    )

    public static let deepSeek = LLMProviderConfig(
        id: "deepSeek", displayName: "DeepSeek",
        kind: .cloudAPI, apiProtocol: .openAI,
        endpoint: .deepSeek,
        capabilities: [.streaming, .tools, .systemPrompt]
    )

    public static let huggingFace = LLMProviderConfig(
        id: "huggingFace", displayName: "Hugging Face",
        kind: .cloudAPI, apiProtocol: .openAI,
        endpoint: .huggingFace,
        capabilities: [.streaming, .tools, .systemPrompt]
    )

    public static let zAI = LLMProviderConfig(
        id: "zAI", displayName: "Z.ai",
        kind: .cloudAPI, apiProtocol: .openAI,
        endpoint: .zAI,
        capabilities: [.streaming, .tools, .systemPrompt, .vision],
        temperature: 0.7
    )

    public static let ollama = LLMProviderConfig(
        id: "ollama", displayName: "Ollama",
        kind: .remoteServer, apiProtocol: .ollama,
        endpoint: .ollamaCloud,
        capabilities: [.streaming, .tools, .systemPrompt, .vision],
        apiKeyOptional: true
    )

    public static let localOllama = LLMProviderConfig(
        id: "localOllama", displayName: "Local Ollama",
        kind: .localServer, apiProtocol: .ollama,
        endpoint: .ollama,
        capabilities: [.streaming, .tools, .systemPrompt, .vision],
        apiKeyOptional: true
    )

    public static let vLLM = LLMProviderConfig(
        id: "vLLM", displayName: "vLLM",
        kind: .remoteServer, apiProtocol: .openAI,
        endpoint: .vLLM,
        capabilities: [.streaming, .tools, .systemPrompt],
        apiKeyOptional: true
    )

    public static let lmStudio = LLMProviderConfig(
        id: "lmStudio", displayName: "LM Studio",
        kind: .localServer, apiProtocol: .openAI,
        endpoint: .lmStudioOpenAI,
        capabilities: [.streaming, .tools, .systemPrompt],
        apiKeyOptional: true,
        supportedProtocols: [.openAI, .anthropic, .custom]
    )

    public static let foundationModel = LLMProviderConfig(
        id: "foundationModel", displayName: "Apple Intelligence",
        kind: .embedded, apiProtocol: .foundationModel,
        endpoint: LLMEndpoint(baseURL: "", chatPath: "", modelsPath: ""),
        capabilities: [.streaming, .tools, .systemPrompt],
        apiKeyOptional: true
    )

    /// All built-in provider presets
    public static let allPresets: [LLMProviderConfig] = [
        .claude, .openAI, .deepSeek, .huggingFace, .zAI,
        .ollama, .localOllama, .vLLM, .lmStudio, .foundationModel
    ]
}
