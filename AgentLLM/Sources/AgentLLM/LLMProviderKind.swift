import Foundation

/// How the LLM is hosted and accessed.
public enum LLMProviderKind: String, Codable, Sendable, CaseIterable {
    /// Cloud API with API key auth (e.g. Claude, OpenAI, DeepSeek)
    case cloudAPI
    /// Local server on the same machine (e.g. Ollama, LM Studio)
    case localServer
    /// Remote self-hosted server (e.g. vLLM, Ollama Cloud)
    case remoteServer
    /// On-device model via system frameworks (e.g. Apple Intelligence)
    case embedded
    /// Custom or mixed setup
    case custom
}
