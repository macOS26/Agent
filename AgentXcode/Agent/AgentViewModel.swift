@preconcurrency import Foundation

import AppKit

@MainActor @Observable
final class AgentViewModel {
    var taskInput = ""
    private let apiService = APIService()
    private let logService = LogService()
    private let xpcService = XPCService()
    
    var isRunning = false
    var isThinking = false
    
    // One-time migration for stale defaults and API keys to Keychain — runs before property defaults are evaluated
    @ObservationIgnored
    private static let _migrate: Void = {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "agentMigrationV4") else { return }
        
        // Migration V4: Move API keys from UserDefaults to Keychain
        if let claudeKey = defaults.string(forKey: "agentAPIKey"), !claudeKey.isEmpty {
            KeychainService.shared.setClaudeAPIKey(claudeKey)
            defaults.removeObject(forKey: "agentAPIKey")
        }
        if let ollamaKey = defaults.string(forKey: "ollamaAPIKey"), !ollamaKey.isEmpty {
            KeychainService.shared.setOllamaAPIKey(ollamaKey)
            defaults.removeObject(forKey: "ollamaAPIKey")
        }
        
        // Legacy migrations from V3
        defaults.removeObject(forKey: "ollamaEndpoint")  // now a constant
        if let model = defaults.string(forKey: "ollamaModel"), model == "llama3.1" {
            defaults.set("qwen3.5:397b", forKey: "selectedOllamaModel")
        }
        
        defaults.set(true, forKey: "agentMigrationV4")
    }()
    
    init() {
        _ = Self._migrate
        checkXPCStatus()
    }
    
    func checkXPCStatus() {
        xpcService.checkXPCStatus()
    }
    
    func toggleRootService() {
        xpcService.toggleRootService()
    }
    
    func clearLog() {
        logService.clearLog()
    }
    
    func persistLogNow() {
        logService.persistLogNow()
    }
    
    // MARK: - API Provider Accessors
    
    var selectedProvider: APIProvider {
        get { apiService.selectedProvider }
        set { apiService.selectedProvider = newValue }
    }
    
    var claudeModels: [ClaudeModelInfo] {
        apiService.claudeModels
    }
    
    var ollamaModels: [OllamaModelInfo] {
        apiService.ollamaModels
    }
    
    var selectedClaudeModel: String {
        get { apiService.selectedClaudeModel }
        set { apiService.selectedClaudeModel = newValue }
    }
    
    var selectedOllamaModel: String {
        get { apiService.selectedOllamaModel }
        set { apiService.selectedOllamaModel = newValue }
    }
    
    // MARK: - Log Accessors
    
    var activityLog: String {
        get { logService.activityLog }
        set { logService.activityLog = newValue }
    }
    
    func appendStreamDelta(_ delta: String) {
        logService.appendStreamDelta(delta)
    }
}
