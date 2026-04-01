import Foundation

/// Central registry for all available LLM providers.
/// Register providers at app startup. Look them up by ID.
@MainActor
public final class LLMRegistry: @unchecked Sendable {
    public static let shared = LLMRegistry()

    /// Registered provider configs, keyed by provider ID
    private var configs: [String: LLMProviderConfig] = [:]
    /// Ordered list for UI display
    private var order: [String] = []

    private init() {}

    // MARK: - Registration

    /// Register a provider configuration.
    public func register(_ config: LLMProviderConfig) {
        if configs[config.id] == nil {
            order.append(config.id)
        }
        configs[config.id] = config
    }

    /// Register multiple providers at once.
    public func registerAll(_ providers: [LLMProviderConfig]) {
        for config in providers { register(config) }
    }

    // MARK: - Lookup

    /// Get a provider config by ID — O(1)
    public func provider(_ id: String) -> LLMProviderConfig? {
        configs[id]
    }

    /// All registered providers in registration order
    public var allProviders: [LLMProviderConfig] {
        order.compactMap { configs[$0] }
    }

    /// All enabled providers
    public var enabledProviders: [LLMProviderConfig] {
        allProviders.filter(\.enabled)
    }

    /// All configured providers (have required settings)
    public var configuredProviders: [LLMProviderConfig] {
        allProviders.filter(\.isConfigured)
    }

    /// Providers filtered by kind
    public func providers(ofKind kind: LLMProviderKind) -> [LLMProviderConfig] {
        allProviders.filter { $0.kind == kind }
    }

    // MARK: - Mutation

    /// Update a provider's config
    public func update(_ config: LLMProviderConfig) {
        configs[config.id] = config
    }

    /// Update just the API key for a provider
    public func setAPIKey(_ id: String, key: String) {
        configs[id]?.apiKey = key
    }

    /// Update just the model for a provider
    public func setModel(_ id: String, model: String) {
        configs[id]?.model = model
    }

    /// Update just the endpoint for a provider
    public func setEndpoint(_ id: String, endpoint: LLMEndpoint) {
        configs[id]?.endpoint = endpoint
    }

    /// Enable or disable a provider
    public func setEnabled(_ id: String, enabled: Bool) {
        configs[id]?.enabled = enabled
    }

    /// Remove a provider
    public func remove(_ id: String) {
        configs.removeValue(forKey: id)
        order.removeAll { $0 == id }
    }

    /// Remove all providers
    public func removeAll() {
        configs.removeAll()
        order.removeAll()
    }
}
