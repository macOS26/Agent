import Foundation

/// Connection details for an LLM service. Fully configurable — no hardcoded URLs.
public struct LLMEndpoint: Codable, Sendable, Hashable {
    /// Full chat API URL
    public var chatURL: String
    /// Full models list URL (empty if not supported)
    public var modelsURL: String
    /// Auth header name ("x-api-key", "Authorization", "" for none)
    public var authHeader: String
    /// Auth value prefix ("Bearer ", "" for raw key)
    public var authPrefix: String
    /// Extra headers sent with every request
    public var extraHeaders: [String: String]
    /// Request timeout in seconds
    public var timeout: TimeInterval
    /// Default port for this service (0 = use URL as-is)
    public var defaultPort: Int

    public init(
        chatURL: String,
        modelsURL: String = "",
        authHeader: String = "Authorization",
        authPrefix: String = "Bearer ",
        extraHeaders: [String: String] = [:],
        timeout: TimeInterval = 120,
        defaultPort: Int = 0
    ) {
        self.chatURL = chatURL
        self.modelsURL = modelsURL
        self.authHeader = authHeader
        self.authPrefix = authPrefix
        self.extraHeaders = extraHeaders
        self.timeout = timeout
        self.defaultPort = defaultPort
    }

    // MARK: - Well-Known Default Ports

    /// Ollama default port
    public static let ollamaPort = 11434
    /// LM Studio default port
    public static let lmStudioPort = 1234
    /// vLLM default port
    public static let vLLMPort = 8000
}
