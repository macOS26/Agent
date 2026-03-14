import Foundation
import Security

/// Secure credential storage using the macOS data protection keychain.
/// No password prompts across rebuilds.
final class KeychainService: Sendable {
    static let shared = KeychainService()

    private init() {}

    // MARK: - Key Constants

    private static let claudeAPIKey = "agent.claudeAPIKey"
    private static let ollamaAPIKey = "agent.ollamaAPIKey"

    // MARK: - Public API

    func setClaudeAPIKey(_ key: String) { set(key: Self.claudeAPIKey, value: key) }
    func getClaudeAPIKey() -> String? { get(key: Self.claudeAPIKey) }
    func deleteClaudeAPIKey() { delete(key: Self.claudeAPIKey) }

    func setOllamaAPIKey(_ key: String) { set(key: Self.ollamaAPIKey, value: key) }
    func getOllamaAPIKey() -> String? { get(key: Self.ollamaAPIKey) }
    func deleteOllamaAPIKey() { delete(key: Self.ollamaAPIKey) }

    // MARK: - Data Protection Keychain

    private func set(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "Agent!",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecUseDataProtectionKeychain as String: true
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess && status != errSecDuplicateItem {
            print("KeychainService: Failed to store \(key): \(status)")
        }
    }

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

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "Agent!",
            kSecUseDataProtectionKeychain as String: true
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - One-Time Cleanup

    /// Wipe legacy keychain items and stale migration flags.
    /// Call once at startup. After this, only data protection keychain is used.
    static func cleanSlate() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "agent.cleanSlateV1") else { return }

        // Delete any legacy keychain items (without data protection flag)
        for key in [claudeAPIKey, ollamaAPIKey] {
            let legacyQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: "Agent!"
            ]
            SecItemDelete(legacyQuery as CFDictionary)
        }

        // Remove stale migration flags
        for flag in ["agentMigrationV4", "agent.keychainMigration", "agent.keychainMigrationV5"] {
            defaults.removeObject(forKey: flag)
        }

        defaults.set(true, forKey: "agent.cleanSlateV1")
    }
}
