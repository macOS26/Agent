import Foundation

/// Information about an available model.
public struct LLMModelInfo: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var displayName: String
    public var contextWindow: Int?
    public var maxOutputTokens: Int?
    public var capabilities: LLMCapability
    public var description: String?

    public init(
        id: String,
        name: String = "",
        displayName: String = "",
        contextWindow: Int? = nil,
        maxOutputTokens: Int? = nil,
        capabilities: LLMCapability = .cloudDefault,
        description: String? = nil
    ) {
        self.id = id
        self.name = name.isEmpty ? id : name
        self.displayName = displayName.isEmpty ? (name.isEmpty ? id : name) : displayName
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.capabilities = capabilities
        self.description = description
    }
}
