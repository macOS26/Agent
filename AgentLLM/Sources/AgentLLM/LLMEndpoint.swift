import Foundation

/// Connection details for an LLM service.
public struct LLMEndpoint: Codable, Sendable, Hashable {
    /// Full chat URL (e.g. "https://api.anthropic.com/v1/messages")
    public var chatURL: String
    /// Models list URL (e.g. "https://api.anthropic.com/v1/models")
    public var modelsURL: String
    /// Authentication header name ("x-api-key", "Authorization", "" for none)
    public var authHeader: String
    /// Auth value prefix ("Bearer ", "" for raw key)
    public var authPrefix: String
    /// Additional headers sent with every request
    public var extraHeaders: [String: String]
    /// Request timeout in seconds
    public var timeout: TimeInterval

    public init(
        chatURL: String,
        modelsURL: String = "",
        authHeader: String = "Authorization",
        authPrefix: String = "Bearer ",
        extraHeaders: [String: String] = [:],
        timeout: TimeInterval = 120
    ) {
        self.chatURL = chatURL
        self.modelsURL = modelsURL
        self.authHeader = authHeader
        self.authPrefix = authPrefix
        self.extraHeaders = extraHeaders
        self.timeout = timeout
    }

    // MARK: - Presets (exact URLs matching the app)

    public static let claude = LLMEndpoint(
        chatURL: "https://api.anthropic.com/v1/messages",
        modelsURL: "https://api.anthropic.com/v1/models",
        authHeader: "x-api-key",
        authPrefix: "",
        extraHeaders: ["anthropic-version": "2023-06-01"]
    )

    public static let openAI = LLMEndpoint(
        chatURL: "https://api.openai.com/v1/chat/completions",
        modelsURL: "https://api.openai.com/v1/models"
    )

    public static let deepSeek = LLMEndpoint(
        chatURL: "https://api.deepseek.com/chat/completions",
        modelsURL: "https://api.deepseek.com/v1/models"
    )

    public static let huggingFace = LLMEndpoint(
        chatURL: "https://router.huggingface.co/v1/chat/completions",
        modelsURL: "https://router.huggingface.co/v1/models"
    )

    public static let zAI = LLMEndpoint(
        chatURL: "https://api.z.ai/api/coding/paas/v4/chat/completions",
        modelsURL: "https://api.z.ai/api/coding/paas/v4/models"
    )

    public static let ollamaCloud = LLMEndpoint(
        chatURL: "https://ollama.com/api/chat",
        modelsURL: "https://ollama.com/api/tags"
    )

    public static let ollamaLocal = LLMEndpoint(
        chatURL: "http://localhost:11434/api/chat",
        modelsURL: "http://localhost:11434/api/tags",
        authHeader: "",
        authPrefix: ""
    )

    public static let vLLM = LLMEndpoint(
        chatURL: "http://localhost:8000/v1/chat/completions",
        modelsURL: "http://localhost:8000/v1/models",
        authHeader: "",
        authPrefix: ""
    )

    // LM Studio — 3 protocol variants
    public static let lmStudioOpenAI = LLMEndpoint(
        chatURL: "http://localhost:1234/v1/chat/completions",
        modelsURL: "http://localhost:1234/v1/models",
        authHeader: "",
        authPrefix: ""
    )

    public static let lmStudioAnthropic = LLMEndpoint(
        chatURL: "http://localhost:1234/v1/messages",
        modelsURL: "http://localhost:1234/v1/models",
        authHeader: "",
        authPrefix: ""
    )

    public static let lmStudioNative = LLMEndpoint(
        chatURL: "http://localhost:1234/api/v1/chat",
        modelsURL: "http://localhost:1234/api/v1/models",
        authHeader: "",
        authPrefix: ""
    )
}
