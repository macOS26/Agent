import Foundation

/// Connection details for an LLM service.
public struct LLMEndpoint: Codable, Sendable, Hashable {
    /// Base URL for API calls
    public var baseURL: String
    /// Chat/completions path appended to baseURL
    public var chatPath: String
    /// Models list path
    public var modelsPath: String
    /// Authentication header name ("x-api-key", "Authorization", "" for none)
    public var authHeader: String
    /// Auth value prefix ("Bearer ", "" for raw key)
    public var authPrefix: String
    /// Additional headers sent with every request
    public var extraHeaders: [String: String]
    /// Request timeout in seconds
    public var timeout: TimeInterval

    public init(
        baseURL: String,
        chatPath: String = "/v1/chat/completions",
        modelsPath: String = "/v1/models",
        authHeader: String = "Authorization",
        authPrefix: String = "Bearer ",
        extraHeaders: [String: String] = [:],
        timeout: TimeInterval = 120
    ) {
        self.baseURL = baseURL
        self.chatPath = chatPath
        self.modelsPath = modelsPath
        self.authHeader = authHeader
        self.authPrefix = authPrefix
        self.extraHeaders = extraHeaders
        self.timeout = timeout
    }

    /// Full URL for chat completions
    public var chatURL: URL? { URL(string: baseURL + chatPath) }
    /// Full URL for model listing
    public var modelsURL: URL? { URL(string: baseURL + modelsPath) }

    // MARK: - Presets

    public static let claude = LLMEndpoint(
        baseURL: "https://api.anthropic.com",
        chatPath: "/v1/messages",
        modelsPath: "/v1/models",
        authHeader: "x-api-key",
        authPrefix: "",
        extraHeaders: ["anthropic-version": "2023-06-01"]
    )

    public static let openAI = LLMEndpoint(
        baseURL: "https://api.openai.com",
        chatPath: "/v1/chat/completions",
        modelsPath: "/v1/models"
    )

    public static let deepSeek = LLMEndpoint(
        baseURL: "https://api.deepseek.com",
        chatPath: "/chat/completions",
        modelsPath: "/v1/models"
    )

    public static let huggingFace = LLMEndpoint(
        baseURL: "https://router.huggingface.co",
        chatPath: "/v1/chat/completions",
        modelsPath: "/v1/models"
    )

    public static let zAI = LLMEndpoint(
        baseURL: "https://api.z.ai",
        chatPath: "/api/coding/paas/v4/chat/completions",
        modelsPath: "/api/coding/paas/v4/models"
    )

    public static let ollama = LLMEndpoint(
        baseURL: "http://localhost:11434",
        chatPath: "/api/chat",
        modelsPath: "/api/tags",
        authHeader: "",
        authPrefix: ""
    )

    public static let ollamaCloud = LLMEndpoint(
        baseURL: "https://ollama.com",
        chatPath: "/api/chat",
        modelsPath: "/api/tags"
    )

    public static let vLLM = LLMEndpoint(
        baseURL: "http://localhost:8000",
        chatPath: "/v1/chat/completions",
        modelsPath: "/v1/models",
        authHeader: "",
        authPrefix: ""
    )

    // LM Studio — 3 protocol variants
    public static let lmStudioOpenAI = LLMEndpoint(
        baseURL: "http://localhost:1234",
        chatPath: "/v1/chat/completions",
        modelsPath: "/v1/models",
        authHeader: "",
        authPrefix: ""
    )

    public static let lmStudioAnthropic = LLMEndpoint(
        baseURL: "http://localhost:1234",
        chatPath: "/v1/messages",
        modelsPath: "/v1/models",
        authHeader: "",
        authPrefix: ""
    )

    public static let lmStudioNative = LLMEndpoint(
        baseURL: "http://localhost:1234",
        chatPath: "/api/v1/chat",
        modelsPath: "/api/v1/models",
        authHeader: "",
        authPrefix: ""
    )
}
