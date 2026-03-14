import Foundation
import Security

/// Secure credential storage using the macOS Keychain.
/// API keys and other sensitive credentials should be stored here instead of UserDefaults.
final class KeychainService: Sendable {
    static let shared = KeychainService()
    
    private init() {}
    
    // MARK: - Key Constants
    
    private static let claudeAPIKey = "agent.claudeAPIKey"
    private static let ollamaAPIKey = "agent.ollamaAPIKey"
    
    // MARK: - Public API
    
    /// Store a Claude API key securely in the Keychain
    func setClaudeAPIKey(_ key: String) {
        set(key: Self.claudeAPIKey, value: key)
    }
    
    /// Retrieve the Claude API key from the Keychain
    func getClaudeAPIKey() -> String? {
        get(key: Self.claudeAPIKey)
    }
    
    /// Delete the Claude API key from the Keychain
    func deleteClaudeAPIKey() {
        delete(key: Self.claudeAPIKey)
    }
    
    /// Store an Ollama API key securely in the Keychain
    func setOllamaAPIKey(_ key: String) {
        set(key: Self.ollamaAPIKey, value: key)
    }
    
    /// Retrieve the Ollama API key from the Keychain
    func getOllamaAPIKey() -> String? {
        get(key: Self.ollamaAPIKey)
    }
    
    /// Delete the Ollama API key from the Keychain
    func deleteOllamaAPIKey() {
        delete(key: Self.ollamaAPIKey)
    }
    
    // MARK: - Generic Keychain Operations
    
    /// Store a value in the Keychain
    private func set(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        // First, try to delete any existing value
        delete(key: key)
        
        // Create the keychain query — use data protection keychain to avoid
        // password prompts on every rebuild during development
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "Agent!",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecUseDataProtectionKeychain as String: true
        ]
        
        // Add to keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess && status != errSecDuplicateItem {
            print("KeychainService: Failed to store \(key): \(status)")
        }
    }
    
    /// Retrieve a value from the Keychain
    private func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "Agent!",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    /// Delete a value from the Keychain
    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "Agent!",
            kSecUseDataProtectionKeychain as String: true
        ]

        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Migration
    
    /// One-time migration from UserDefaults to Keychain
    /// Call this during app initialization
    static func migrateFromUserDefaults() {
        let defaults = UserDefaults.standard
        let migrated = defaults.bool(forKey: "agent.keychainMigration")
        guard !migrated else { return }
        
        // Migrate Claude API key
        if let claudeKey = defaults.string(forKey: "agentAPIKey"), !claudeKey.isEmpty {
            shared.setClaudeAPIKey(claudeKey)
            defaults.removeObject(forKey: "agentAPIKey")
        }
        
        // Migrate Ollama API key
        if let ollamaKey = defaults.string(forKey: "ollamaAPIKey"), !ollamaKey.isEmpty {
            shared.setOllamaAPIKey(ollamaKey)
            defaults.removeObject(forKey: "ollamaAPIKey")
        }
        
        defaults.set(true, forKey: "agent.keychainMigration")
    }
}
