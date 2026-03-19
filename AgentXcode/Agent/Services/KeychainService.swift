import Foundation
import Security

/// Secure credential storage using the macOS data protection keychain.
/// No password prompts across rebuilds.
final class KeychainService: Sendable {
    static let shared = KeychainService()

    private init() {}

    private static let claudeAPIKey = "agent.claudeAPIKey"
    private static let ollamaAPIKey = "agent.ollamaAPIKey"
    private static let tavilyAPIKey = "agent.tavilyAPIKey"
    private static let openAIAPIKey = "agent.openAIAPIKey"
    private static let huggingFaceAPIKey = "agent.huggingFaceAPIKey"

    func setClaudeAPIKey(_ key: String) { set(key: Self.claudeAPIKey, value: key) }
    func getClaudeAPIKey() -> String? { get(key: Self.claudeAPIKey) }

    func setOllamaAPIKey(_ key: String) { set(key: Self.ollamaAPIKey, value: key) }
    func getOllamaAPIKey() -> String? { get(key: Self.ollamaAPIKey) }

    func setTavilyAPIKey(_ key: String) { set(key: Self.tavilyAPIKey, value: key) }
    func getTavilyAPIKey() -> String? { get(key: Self.tavilyAPIKey) }

    func setOpenAIAPIKey(_ key: String) { set(key: Self.openAIAPIKey, value: key) }
    func getOpenAIAPIKey() -> String? { get(key: Self.openAIAPIKey) }

    func setHuggingFaceAPIKey(_ key: String) { set(key: Self.huggingFaceAPIKey, value: key) }
    func getHuggingFaceAPIKey() -> String? { get(key: Self.huggingFaceAPIKey) }

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
}
