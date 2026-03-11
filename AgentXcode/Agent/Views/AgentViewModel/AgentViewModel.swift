@preconcurrency import Foundation
import AppKit
import SwiftUI
import SQLite3
import Speech
import AVFoundation
import FoundationModels

/// Per-tab LLM configuration for multi-main-tab support
struct LLMConfig: Codable {
    var provider: APIProvider
    var model: String
    var displayName: String
}

enum APIProvider: String, CaseIterable, Codable {
    case claude = "claude"
    case openAI = "openAI"
    case deepSeek = "deepSeek"
    case huggingFace = "huggingFace"
    case zAI = "zAI"
    case ollama = "ollama"
    case localOllama = "localOllama"
    case vLLM = "vLLM"
    case lmStudio = "lmStudio"
    case foundationModel = "foundationModel"  // runs in the
        // background, Used for LoRA training & mediator tasks,
        //not selectable in UI

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .openAI: "OpenAI"
        case .deepSeek: "DeepSeek"
        case .huggingFace: "Hugging Face"
        case .ollama: "Ollama"
        case .localOllama: "Local Ollama"
        case .vLLM: "vLLM"
        case .lmStudio: "LM Studio"
        case .zAI: "Z.ai"
        case .foundationModel: "Apple Intelligence"
        }
    }

    /// Providers selectable in the UI for task execution
    /// Note: foundationModel (Apple Intelligence) is NOT selectable - it's for LoRA training only.
    /// Apple Intelligence is an assistant to LLMs and users, not a direct LLM provider.
    static var selectableProviders: [APIProvider] {
        [.claude, .openAI, .deepSeek, .huggingFace, .zAI, .ollama, .localOllama, .vLLM, .lmStudio]
    }
}

enum LMStudioProtocol: String, CaseIterable, Codable {
    case openAI = "openAI"
    case anthropic = "anthropic"
    case lmStudio = "lmStudio"

    var displayName: String {
        switch self {
        case .openAI: "OpenAI Compatible"
        case .anthropic: "Anthropic Compatible"
        case .lmStudio: "LM Studio Native"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .openAI: "http://localhost:1234/v1/chat/completions"
        case .anthropic: "http://localhost:1234/v1/messages"
        case .lmStudio: "http://localhost:1234/api/v1/chat"
        }
    }
}

enum PromptStyle: String, CaseIterable, Codable {
    case full
    case compact
    
    var displayName: String {
        switch self {
        case .full: "Full"
        case .compact: "Compact"
        }
    }
}

@MainActor @Observable
final class AgentViewModel {
    var taskInput = ""
    
    // Stored property drives live UI; ChatHistoryStore persists across launches via SwiftData
    var activityLog = ChatHistoryStore.shared.buildActivityLogText(maxTasks: 3)
    var isRunning = false
    var isThinking = false
    var thinkingDismissed: Bool = UserDefaults.standard.object(forKey: "thinkingDismissed") as? Bool ?? true {
        didSet { UserDefaults.standard.set(thinkingDismissed, forKey: "thinkingDismissed") }
    }
    var showThinkingIndicator: Bool = UserDefaults.standard.object(forKey: "showThinkingIndicator") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showThinkingIndicator, forKey: "showThinkingIndicator") }
    }
    var thinkingExpanded: Bool = UserDefaults.standard.object(forKey: "thinkingExpanded") as? Bool ?? false {
        didSet { UserDefaults.standard.set(thinkingExpanded, forKey: "thinkingExpanded") }
    }
    var thinkingOutputExpanded: Bool = UserDefaults.standard.object(forKey: "thinkingOutputExpanded") as? Bool ?? false {
        didSet { UserDefaults.standard.set(thinkingOutputExpanded, forKey: "thinkingOutputExpanded") }
    }
    var isListening = false

    // Failed agent alert
    var showFailedAgentAlert = false
    var failedAgentName = ""
    var failedAgentId: UUID?

    /// Call when an agent fails — triggers the remove-from-menu alert.
    /// Finds the most recent matching entry by name and stores its UUID for exact removal.
    func notifyAgentFailed(name: String, arguments: String) {
        if let entry = RecentAgentsService.shared.entries.first(where: { $0.agentName == name && $0.arguments == arguments })
            ?? RecentAgentsService.shared.entries.first(where: { $0.agentName == name }) {
            failedAgentName = name
            failedAgentId = entry.id
            showFailedAgentAlert = true
        }
    }

    // Token tracking
    var taskInputTokens: Int = 0
    var taskOutputTokens: Int = 0
    var sessionInputTokens: Int = 0
    var sessionOutputTokens: Int = 0
    var userServiceActive = false
    var rootServiceActive = false
    var userWasActive = false
    var rootWasActive = false
    var userPingOK = false
    var daemonPingOK = false
    var userEnabled: Bool = UserDefaults.standard.object(forKey: "agentUserEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(userEnabled, forKey: "agentUserEnabled")
            if !userEnabled {
                userService.shutdownAgent()
                userPingOK = false
                appendLog("⚙️ User Agent shut down. Re-enable: Connect → Register.")
            }
            syncServicesGroup()
        }
    }
    var rootEnabled: Bool = UserDefaults.standard.object(forKey: "agentRootEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(rootEnabled, forKey: "agentRootEnabled")
            if !rootEnabled {
                helperService.shutdownDaemon()
                daemonPingOK = false
                appendLog("⚙️ Launch Daemon shut down. Re-enable: Connect → Register.")
            }
            syncServicesGroup()
        }
    }

    /// Keep service tool groups and individual tools in sync with userEnabled/rootEnabled.
    private func syncServicesGroup() {
        let prefs = ToolPreferencesService.shared
        // Sync User Agent group
        let agentGroupOn = prefs.isGroupEnabled("User Agent")
        if userEnabled != agentGroupOn { prefs.toggleGroup("User Agent") }
        // Sync individual tool — re-enable if service turned on
        if userEnabled && !prefs.isEnabled(selectedProvider, "execute_agent_command") {
            prefs.toggle(selectedProvider, "execute_agent_command")
        }
        // Sync Launch Daemon group
        let daemonGroupOn = prefs.isGroupEnabled("Launch Daemon")
        if rootEnabled != daemonGroupOn { prefs.toggleGroup("Launch Daemon") }
        // Sync individual tool — re-enable if service turned on
        if rootEnabled && !prefs.isEnabled(selectedProvider, "execute_daemon_command") {
            prefs.toggle(selectedProvider, "execute_daemon_command")
        }
    }

    /// CPU icon color: green = running, blue = configured, red = not configured
    var llmStatusColor: Color {
        let needsKey: Set<APIProvider> = [.claude, .openAI, .deepSeek, .huggingFace]
        if needsKey.contains(selectedProvider) && apiKey.isEmpty { return .red }
        // When running, use the active tab's color
        if isRunning || isThinking {
            if let selId = selectedTabId {
                return ContentView.tabColor(for: selId, in: scriptTabs)
            }
            return .blue
        }
        // Check if any tab is running
        if let runningTab = scriptTabs.first(where: { $0.isLLMRunning || $0.isLLMThinking }) {
            return ContentView.tabColor(for: runningTab.id, in: scriptTabs)
        }
        return .green
    }

    /// Gear icon color reflecting overall service health
    var servicesGearColor: Color {
        if !userEnabled && !rootEnabled { return .gray }
        if userEnabled && rootEnabled { return .green }
        return .yellow
    }

    /// Tool icon color reflecting tool accessibility
    var toolsIconColor: Color {
        let prefs = ToolPreferencesService.shared
        let all = AgentTools.tools(for: selectedProvider)
        let enabledCount = all.filter { prefs.isEnabled(selectedProvider, $0.name) }.count
        if enabledCount == 0 { return .red }
        if !userEnabled { return .yellow }
        if !rootEnabled { return .orange }
        return .green
    }

    /// Hand icon color reflecting accessibility status
    var accessibilityIconColor: Color {
        if !AccessibilityService.hasAccessibilityPermission() { return .red }
        let prefs = ToolPreferencesService.shared
        if !prefs.isEnabled(selectedProvider, "accessibility") { return .orange }
        let axSettings = AccessibilityEnabled.shared
        if axSettings.axEnabled.count < AccessibilityEnabledIDs.allAxIds.count { return .yellow }
        return .green
    }

    /// History icon color reflecting history state
    var historyIconColor: Color {
        let hasPrompts = !currentTabPromptHistory.isEmpty
        let hasTasks = !taskSummaries.isEmpty
        let hasErrors = !errorHistory.isEmpty
        if !hasPrompts && !hasTasks && !hasErrors { return Color.gray }
        if hasErrors { return .red }
        return .green
    }

    /// Options slider icon color based on temperature
    var optionsIconColor: Color {
        let temp = temperatureForProvider(selectedProvider)
        if temp >= 1.0 { return .red }
        if temp >= 0.75 { return .orange }
        if temp >= 0.5 { return .yellow }
        return .green
    }

    /// MCP server icon color based on connection and tool state
    var mcpIconColor: Color {
        let mcp = MCPService.shared
        let config = MCPServerRegistry.shared
        let servers = config.servers
        // No servers configured
        guard !servers.isEmpty else { return .gray }
        let connectedIds = mcp.connectedServerIds
        let tools = mcp.discoveredTools
        // No servers connected
        guard !connectedIds.isEmpty else { return .gray }
        // Check if all tools are disabled
        let enabledTools = tools.filter { mcp.isToolEnabled(serverName: $0.serverName, toolName: $0.name) }
        if enabledTools.isEmpty && !tools.isEmpty { return .red }
        // Check if some servers have errors or some tools disabled
        let hasErrors = !mcp.connectionErrors.isEmpty
        let someDisabled = enabledTools.count < tools.count
        if hasErrors || someDisabled { return .orange }
        // All good
        return .green
    }

    /// Tooltip for the gear icon
    var servicesGearHelp: String {
        let userStatus = userPingOK ? "connected" : (userEnabled ? "not responding" : "disabled")
        let rootStatus = daemonPingOK ? "connected" : (rootEnabled ? "not responding" : "disabled")
        return "Background Agents — Agent: \(userStatus), Daemon: \(rootStatus)"
    }

    var selectedProvider: APIProvider = {
        let rawValue = UserDefaults.standard.string(forKey: "agentProvider") ?? "ollama"
        let provider = APIProvider(rawValue: rawValue) ?? .ollama
        // foundationModel is NEVER a valid selection - it's for LoRA training only
        // If somehow stored, fall back to ollama
        return APIProvider.selectableProviders.contains(provider) ? provider : .ollama
    }() {
        didSet {
            // Ensure foundationModel can never be stored as selected provider
            guard APIProvider.selectableProviders.contains(selectedProvider) else {
                selectedProvider = .ollama
                return
            }
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "agentProvider")
            if selectedProvider == .ollama && ollamaModels.isEmpty {
                fetchOllamaModels()
            }
            if selectedProvider == .localOllama && localOllamaModels.isEmpty {
                fetchLocalOllamaModels()
            }
            if selectedProvider == .claude && availableClaudeModels.isEmpty {
                Task { await fetchClaudeModels() }
            }
            if selectedProvider == .openAI && openAIModels.isEmpty {
                fetchOpenAIModels()
            }
            if selectedProvider == .deepSeek && deepSeekModels.isEmpty {
                fetchDeepSeekModels()
            }
            if selectedProvider == .huggingFace && huggingFaceModels.isEmpty {
                fetchHuggingFaceModels()
            }
            if selectedProvider == .vLLM && vLLMModels.isEmpty {
                fetchVLLMModels()
            }
            if selectedProvider == .lmStudio && lmStudioModels.isEmpty {
                fetchLMStudioModels()
            }
            if selectedProvider == .zAI && zAIModels.isEmpty {
                fetchZAIModels()
            }
        }
    }

    // Claude settings - stored securely in Keychain
    var apiKey: String = KeychainService.shared.getClaudeAPIKey() ?? "" {
        didSet { KeychainService.shared.setClaudeAPIKey(apiKey) }
    }

    var selectedModel: String = UserDefaults.standard.string(forKey: "agentModel") ?? "claude-sonnet-4-20250514" {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "agentModel") }
    }

    // Ollama settings - API key stored securely in Keychain
    var ollamaAPIKey: String = KeychainService.shared.getOllamaAPIKey() ?? "" {
        didSet { KeychainService.shared.setOllamaAPIKey(ollamaAPIKey) }
    }

    // Tavily web search API key (available for all providers)
    var tavilyAPIKey: String = KeychainService.shared.getTavilyAPIKey() ?? "" {
        didSet { KeychainService.shared.setTavilyAPIKey(tavilyAPIKey) }
    }

    let ollamaEndpoint = "https://ollama.com/api/chat"

    // OpenAI settings
    var openAIAPIKey: String = KeychainService.shared.getOpenAIAPIKey() ?? "" {
        didSet { KeychainService.shared.setOpenAIAPIKey(openAIAPIKey) }
    }

    var openAIModel: String = UserDefaults.standard.string(forKey: "openAIModel") ?? "gpt-4.1-nano" {
        didSet { UserDefaults.standard.set(openAIModel, forKey: "openAIModel") }
    }

    struct OpenAIModelInfo: Identifiable {
        let id: String
        let name: String
    }

    var openAIModels: [OpenAIModelInfo] = []
    var isFetchingOpenAIModels = false

    private static let defaultOpenAIModels: [OpenAIModelInfo] = [
        OpenAIModelInfo(id: "gpt-4.1-nano", name: "GPT-4.1 Nano"),
        OpenAIModelInfo(id: "gpt-4.1-mini", name: "GPT-4.1 Mini"),
        OpenAIModelInfo(id: "gpt-4.1", name: "GPT-4.1"),
        OpenAIModelInfo(id: "gpt-4o-mini", name: "GPT-4o Mini"),
        OpenAIModelInfo(id: "gpt-4o", name: "GPT-4o"),
        OpenAIModelInfo(id: "o4-mini", name: "o4-mini"),
        OpenAIModelInfo(id: "o3-mini", name: "o3-mini"),
        OpenAIModelInfo(id: "o3", name: "o3"),
    ]

    // DeepSeek settings
    var deepSeekAPIKey: String = KeychainService.shared.getDeepSeekAPIKey() ?? "" {
        didSet { KeychainService.shared.setDeepSeekAPIKey(deepSeekAPIKey) }
    }

    var deepSeekModel: String = UserDefaults.standard.string(forKey: "deepSeekModel") ?? "deepseek-chat" {
        didSet { UserDefaults.standard.set(deepSeekModel, forKey: "deepSeekModel") }
    }

    private static let defaultDeepSeekModels: [OpenAIModelInfo] = [
        OpenAIModelInfo(id: "deepseek-chat", name: "DeepSeek Chat (V3)"),
        OpenAIModelInfo(id: "deepseek-reasoner", name: "DeepSeek Reasoner (R1)"),
    ]

    var deepSeekModels: [OpenAIModelInfo] = []
    var isFetchingDeepSeekModels = false

    // Hugging Face settings
    var huggingFaceAPIKey: String = KeychainService.shared.getHuggingFaceAPIKey() ?? "" {
        didSet { KeychainService.shared.setHuggingFaceAPIKey(huggingFaceAPIKey) }
    }

    var huggingFaceModel: String = UserDefaults.standard.string(forKey: "huggingFaceModel") ?? "deepseek-ai/DeepSeek-V3-0324" {
        didSet { UserDefaults.standard.set(huggingFaceModel, forKey: "huggingFaceModel") }
    }

    var huggingFaceModels: [OpenAIModelInfo] = []
    var isFetchingHuggingFaceModels = false

    // vLLM settings
    var vLLMAPIKey: String = KeychainService.shared.getVLLMAPIKey() ?? "" {
        didSet { KeychainService.shared.setVLLMAPIKey(vLLMAPIKey) }
    }

    var vLLMEndpoint: String = UserDefaults.standard.string(forKey: "vLLMEndpoint") ?? "http://localhost:8000/v1/chat/completions" {
        didSet { UserDefaults.standard.set(vLLMEndpoint, forKey: "vLLMEndpoint") }
    }

    var vLLMModel: String = UserDefaults.standard.string(forKey: "vLLMModel") ?? "" {
        didSet { UserDefaults.standard.set(vLLMModel, forKey: "vLLMModel") }
    }

    var vLLMModels: [OpenAIModelInfo] = []
    var isFetchingVLLMModels = false

    // LM Studio settings
    var lmStudioProtocol: LMStudioProtocol = {
        let raw = UserDefaults.standard.string(forKey: "lmStudioProtocol") ?? "openAI"
        return LMStudioProtocol(rawValue: raw) ?? .openAI
    }() {
        didSet {
            UserDefaults.standard.set(lmStudioProtocol.rawValue, forKey: "lmStudioProtocol")
            lmStudioEndpoint = lmStudioProtocol.defaultEndpoint
        }
    }

    var lmStudioEndpoint: String = UserDefaults.standard.string(forKey: "lmStudioEndpoint") ?? "http://localhost:1234/v1/chat/completions" {
        didSet { UserDefaults.standard.set(lmStudioEndpoint, forKey: "lmStudioEndpoint") }
    }

    var lmStudioModel: String = UserDefaults.standard.string(forKey: "lmStudioModel") ?? "" {
        didSet { UserDefaults.standard.set(lmStudioModel, forKey: "lmStudioModel") }
    }

    var lmStudioAPIKey: String = UserDefaults.standard.string(forKey: "lmStudioAPIKey") ?? "" {
        didSet { UserDefaults.standard.set(lmStudioAPIKey, forKey: "lmStudioAPIKey") }
    }

    var lmStudioModels: [OpenAIModelInfo] = []
    var isFetchingLMStudioModels = false

    // Z.ai (ZhipuAI GLM) settings
    var zAIAPIKey: String = KeychainService.shared.getZAIAPIKey() ?? "" {
        didSet { KeychainService.shared.setZAIAPIKey(zAIAPIKey) }
    }

    var zAIModel: String = UserDefaults.standard.string(forKey: "zAIModel") ?? "glm-4.7" {
        didSet { UserDefaults.standard.set(zAIModel, forKey: "zAIModel") }
    }

    private static let defaultZAIModels: [OpenAIModelInfo] = [
        // Text models
        OpenAIModelInfo(id: "glm-5.1", name: "GLM-5.1"),
        OpenAIModelInfo(id: "glm-5", name: "GLM-5"),
        OpenAIModelInfo(id: "glm-5-turbo", name: "GLM-5 Turbo"),
        OpenAIModelInfo(id: "glm-5-code", name: "GLM-5 Code"),
        OpenAIModelInfo(id: "glm-4.7", name: "GLM-4.7"),
        OpenAIModelInfo(id: "glm-4.7-flashx", name: "GLM-4.7 FlashX"),
        OpenAIModelInfo(id: "glm-4.6", name: "GLM-4.6"),
        OpenAIModelInfo(id: "glm-4.5", name: "GLM-4.5"),
        OpenAIModelInfo(id: "glm-4.5-x", name: "GLM-4.5 X"),
        OpenAIModelInfo(id: "glm-4.5-air", name: "GLM-4.5 Air"),
        OpenAIModelInfo(id: "glm-4.5-airx", name: "GLM-4.5 AirX"),
        OpenAIModelInfo(id: "glm-4.5-flash", name: "GLM-4.5 Flash (Free)"),
        OpenAIModelInfo(id: "glm-4.7-flash", name: "GLM-4.7 Flash (Free)"),
        // Vision models
        OpenAIModelInfo(id: "glm-4.6v", name: "GLM-4.6V (Vision)"),
        OpenAIModelInfo(id: "glm-4.5v", name: "GLM-4.5V (Vision)"),
        OpenAIModelInfo(id: "glm-4.6v-flashx", name: "GLM-4.6V FlashX"),
        OpenAIModelInfo(id: "glm-4.6v-flash", name: "GLM-4.6V Flash (Free)"),
    ]

    var zAIModels: [OpenAIModelInfo] = []
    var isFetchingZAIModels = false

    private static let defaultHuggingFaceModels: [OpenAIModelInfo] = [
        OpenAIModelInfo(id: "deepseek-ai/DeepSeek-V3-0324", name: "DeepSeek V3"),
        OpenAIModelInfo(id: "deepseek-ai/DeepSeek-R1", name: "DeepSeek R1"),
        OpenAIModelInfo(id: "Qwen/Qwen2.5-Coder-32B-Instruct", name: "Qwen 2.5 Coder 32B"),
        OpenAIModelInfo(id: "meta-llama/Llama-3.3-70B-Instruct", name: "Llama 3.3 70B"),
        OpenAIModelInfo(id: "mistralai/Mistral-Small-24B-Instruct-2501", name: "Mistral Small 24B"),
    ]

    var maxHistoryBeforeSummary: Int = UserDefaults.standard.object(forKey: "agentMaxHistory") as? Int ?? 10 {
        didSet { UserDefaults.standard.set(maxHistoryBeforeSummary, forKey: "agentMaxHistory") }
    }

    var visibleTaskCount: Int = UserDefaults.standard.object(forKey: "agentVisibleTasks") as? Int ?? 3 {
        didSet { UserDefaults.standard.set(visibleTaskCount, forKey: "agentVisibleTasks") }
    }

    static let iterationOptions = [25, 50, 100, 200, 400, 800, 1600]

    var maxIterations: Int = UserDefaults.standard.object(forKey: "agentMaxIterations") as? Int ?? 50 {
        didSet { UserDefaults.standard.set(maxIterations, forKey: "agentMaxIterations") }
    }

    static let retryOptions = [1, 2, 3, 5, 10, 15, 20]

    var maxRetries: Int = UserDefaults.standard.object(forKey: "agentMaxRetries") as? Int ?? 10 {
        didSet { UserDefaults.standard.set(maxRetries, forKey: "agentMaxRetries") }
    }

    // MARK: - Temperature per provider
    var claudeTemperature: Double = UserDefaults.standard.object(forKey: "claudeTemperature") as? Double ?? 0.2 {
        didSet { UserDefaults.standard.set(claudeTemperature, forKey: "claudeTemperature") }
    }
    var ollamaTemperature: Double = UserDefaults.standard.object(forKey: "ollamaTemperature") as? Double ?? 0.2 {
        didSet { UserDefaults.standard.set(ollamaTemperature, forKey: "ollamaTemperature") }
    }
    var openAITemperature: Double = UserDefaults.standard.object(forKey: "openAITemperature") as? Double ?? 0.2 {
        didSet { UserDefaults.standard.set(openAITemperature, forKey: "openAITemperature") }
    }
    var deepSeekTemperature: Double = UserDefaults.standard.object(forKey: "deepSeekTemperature") as? Double ?? 0.2 {
        didSet { UserDefaults.standard.set(deepSeekTemperature, forKey: "deepSeekTemperature") }
    }
    var huggingFaceTemperature: Double = UserDefaults.standard.object(forKey: "huggingFaceTemperature") as? Double ?? 0.2 {
        didSet { UserDefaults.standard.set(huggingFaceTemperature, forKey: "huggingFaceTemperature") }
    }
    var localOllamaTemperature: Double = UserDefaults.standard.object(forKey: "localOllamaTemperature") as? Double ?? 0.2 {
        didSet { UserDefaults.standard.set(localOllamaTemperature, forKey: "localOllamaTemperature") }
    }
    /// Context window size for local Ollama. 0 = let model decide.
    var localOllamaContextSize: Int = UserDefaults.standard.object(forKey: "localOllamaContextSize") as? Int ?? 0 {
        didSet { UserDefaults.standard.set(localOllamaContextSize, forKey: "localOllamaContextSize") }
    }
    var vLLMTemperature: Double = UserDefaults.standard.object(forKey: "vLLMTemperature") as? Double ?? 0.2 {
        didSet { UserDefaults.standard.set(vLLMTemperature, forKey: "vLLMTemperature") }
    }
    var lmStudioTemperature: Double = UserDefaults.standard.object(forKey: "lmStudioTemperature") as? Double ?? 0.2 {
        didSet { UserDefaults.standard.set(lmStudioTemperature, forKey: "lmStudioTemperature") }
    }
    var zAITemperature: Double = UserDefaults.standard.object(forKey: "zAITemperature") as? Double ?? 0.7 {
        didSet { UserDefaults.standard.set(zAITemperature, forKey: "zAITemperature") }
    }

    /// Get temperature for the current provider.
    func temperatureForProvider(_ provider: APIProvider) -> Double {
        switch provider {
        case .claude: return claudeTemperature
        case .ollama: return ollamaTemperature
        case .openAI: return openAITemperature
        case .deepSeek: return deepSeekTemperature
        case .huggingFace: return huggingFaceTemperature
        case .localOllama: return localOllamaTemperature
        case .vLLM: return vLLMTemperature
        case .lmStudio: return lmStudioTemperature
        case .zAI: return zAITemperature
        case .foundationModel: return 0.2
        }
    }

    /// Max output tokens per provider. 0 = let provider decide (omit from request).
    /// Claude API requires max_tokens so 0 defaults to 16384 at the service level.
    var maxTokens: Int = UserDefaults.standard.object(forKey: "maxTokens") as? Int ?? 0 {
        didSet { UserDefaults.standard.set(maxTokens, forKey: "maxTokens") }
    }

    var ollamaModel: String = UserDefaults.standard.string(forKey: "ollamaModel") ?? "" {
        didSet {
            UserDefaults.standard.set(ollamaModel, forKey: "ollamaModel")
            if !ollamaModel.isEmpty && oldValue != ollamaModel {
                let vision = selectedOllamaSupportsVision ? " (vision)" : ""
                appendLog("🔄\(ollamaModel)\(vision)")
                flushLog()
            }
        }
    }

    struct OllamaModelInfo: Identifiable {
        let id: String // same as name
        let name: String
        let supportsVision: Bool
    }

    private static let defaultOllamaModels: [OllamaModelInfo] = [
        OllamaModelInfo(id: "nemotron-3-super", name: "nemotron-3-super", supportsVision: false),
        OllamaModelInfo(id: "qwen3.5:397b", name: "qwen3.5:397b", supportsVision: false),
        OllamaModelInfo(id: "minimax-m2.5", name: "minimax-m2.5", supportsVision: false),
        OllamaModelInfo(id: "glm-5", name: "glm-5", supportsVision: false),
        OllamaModelInfo(id: "kimi-k2.5", name: "kimi-k2.5", supportsVision: true),
        OllamaModelInfo(id: "glm-4.7", name: "glm-4.7", supportsVision: false),
        OllamaModelInfo(id: "minimax-m2.1", name: "minimax-m2.1", supportsVision: false),
        OllamaModelInfo(id: "gemini-3-flash-preview", name: "gemini-3-flash-preview", supportsVision: true),
        OllamaModelInfo(id: "nemotron-3-nano:30b", name: "nemotron-3-nano:30b", supportsVision: false),
        OllamaModelInfo(id: "devstral-small-2:24b", name: "devstral-small-2:24b", supportsVision: false),
        OllamaModelInfo(id: "devstral-2:123b", name: "devstral-2:123b", supportsVision: false),
        OllamaModelInfo(id: "ministral-3:8b", name: "ministral-3:8b", supportsVision: false),
        OllamaModelInfo(id: "ministral-3:14b", name: "ministral-3:14b", supportsVision: false),
        OllamaModelInfo(id: "deepseek-v3.2", name: "deepseek-v3.2", supportsVision: false),
        OllamaModelInfo(id: "mistral-large-3:675b", name: "mistral-large-3:675b", supportsVision: false),
        OllamaModelInfo(id: "deepseek-v3.1:671b", name: "deepseek-v3.1:671b", supportsVision: false),
        OllamaModelInfo(id: "cogito-2.1:671b", name: "cogito-2.1:671b", supportsVision: false),
        OllamaModelInfo(id: "minimax-m2", name: "minimax-m2", supportsVision: false),
        OllamaModelInfo(id: "glm-4.6", name: "glm-4.6", supportsVision: false),
        OllamaModelInfo(id: "qwen3-vl:235b-instruct", name: "qwen3-vl:235b-instruct", supportsVision: true),
        OllamaModelInfo(id: "qwen3-vl:235b", name: "qwen3-vl:235b", supportsVision: true),
        OllamaModelInfo(id: "qwen3-next:80b", name: "qwen3-next:80b", supportsVision: false),
        OllamaModelInfo(id: "kimi-k2:1t", name: "kimi-k2:1t", supportsVision: false),
        OllamaModelInfo(id: "gpt-oss:120b", name: "gpt-oss:120b", supportsVision: false),
        OllamaModelInfo(id: "qwen3-coder:480b", name: "qwen3-coder:480b", supportsVision: false),
        OllamaModelInfo(id: "gemma3:27b", name: "gemma3:27b", supportsVision: true),
        OllamaModelInfo(id: "gemma3:12b", name: "gemma3:12b", supportsVision: true),
        OllamaModelInfo(id: "gemma3:4b", name: "gemma3:4b", supportsVision: true),
        OllamaModelInfo(id: "qwen3-coder-next", name: "qwen3-coder-next", supportsVision: false),
        OllamaModelInfo(id: "gpt-oss:20b", name: "gpt-oss:20b", supportsVision: false)

    ]
    // MARK: - Claude Models

    struct ClaudeModelInfo: Identifiable, Codable {
        let id: String
        let name: String
        let displayName: String
        let createdAt: String?
        let description: String?

        var formattedDisplayName: String {
            if let created = createdAt {
                let dateStr = String(created.prefix(10))
                return "\(displayName) (\(dateStr))"
            }
            return displayName
        }
    }

    var availableClaudeModels: [ClaudeModelInfo] = []

    private static let defaultClaudeModels: [ClaudeModelInfo] = [
        ClaudeModelInfo(id: "claude-sonnet-4-6", name: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6", createdAt: "2026-02-17", description: nil),
        ClaudeModelInfo(id: "claude-opus-4-6", name: "claude-opus-4-6", displayName: "Claude Opus 4.6", createdAt: "2026-02-04", description: nil),
        ClaudeModelInfo(id: "claude-opus-4-5-20251101", name: "claude-opus-4-5-20251101", displayName: "Claude Opus 4.5", createdAt: "2025-11-24", description: nil),
        ClaudeModelInfo(id: "claude-haiku-4-5-20251001", name: "claude-haiku-4-5-20251001", displayName: "Claude Haiku 4.5", createdAt: "2025-10-15", description: nil),
        ClaudeModelInfo(id: "claude-sonnet-4-5-20250929", name: "claude-sonnet-4-5-20250929", displayName: "Claude Sonnet 4.5", createdAt: "2025-09-29", description: nil),
        ClaudeModelInfo(id: "claude-opus-4-1-20250805", name: "claude-opus-4-1-20250805", displayName: "Claude Opus 4.1", createdAt: "2025-08-05", description: nil),
        ClaudeModelInfo(id: "claude-opus-4-20250514", name: "claude-opus-4-20250514", displayName: "Claude Opus 4", createdAt: "2025-05-22", description: nil),
        ClaudeModelInfo(id: "claude-sonnet-4-20250514", name: "claude-sonnet-4-20250514", displayName: "Claude Sonnet 4", createdAt: "2025-05-22", description: nil),
        ClaudeModelInfo(id: "claude-3-haiku-20240307", name: "claude-3-haiku-20240307", displayName: "Claude Haiku 3", createdAt: "2024-03-07", description: nil)
    ]

    var ollamaModels: [OllamaModelInfo] = []
    var isFetchingModels = false

    var selectedOllamaSupportsVision: Bool {
        ollamaModels.first(where: { $0.name == ollamaModel })?.supportsVision ?? false
    }

    // Local Ollama settings
    var localOllamaEndpoint: String = UserDefaults.standard.string(forKey: "localOllamaEndpoint") ?? "http://localhost:11434/api/chat" {
        didSet { UserDefaults.standard.set(localOllamaEndpoint, forKey: "localOllamaEndpoint") }
    }

    var localOllamaModel: String = UserDefaults.standard.string(forKey: "localOllamaModel") ?? "" {
        didSet {
            UserDefaults.standard.set(localOllamaModel, forKey: "localOllamaModel")
            if !localOllamaModel.isEmpty && oldValue != localOllamaModel {
                let vision = selectedLocalOllamaSupportsVision ? " (vision)" : ""
                appendLog("🔄\(localOllamaModel)\(vision)")
                flushLog()
            }
        }
    }

    var localOllamaModels: [OllamaModelInfo] = []
    var isFetchingLocalModels = false

    var selectedLocalOllamaSupportsVision: Bool {
        localOllamaModels.first(where: { $0.name == localOllamaModel })?.supportsVision ?? false
    }

    var projectFolder: String = UserDefaults.standard.string(forKey: "agentProjectFolder") ?? "" {
        didSet { UserDefaults.standard.set(projectFolder, forKey: "agentProjectFolder") }
    }

    var attachedImages: [NSImage] = []
    var attachedImagesBase64: [String] = []

    var promptHistory: [String] = UserDefaults.standard.stringArray(forKey: "agentPromptHistory") ?? []
    var historyIndex = -1
    var savedInput = ""

    /// Prompt history for whichever tab is currently selected.
    var currentTabPromptHistory: [String] {
        if let selectedId = selectedTabId,
           let tab = scriptTabs.first(where: { $0.id == selectedId }) {
            return tab.promptHistory
        }
        return promptHistory
    }

    /// Display name for the currently selected tab.
    var currentTabName: String {
        if let selectedId = selectedTabId,
           let tab = scriptTabs.first(where: { $0.id == selectedId }) {
            return tab.displayTitle
        }
        return "Main"
    }
    
    /// Error history for UI display — per-tab when a tab is selected, global for main
    var errorHistory: [String] {
        if let selectedId = selectedTabId,
           let tab = scriptTabs.first(where: { $0.id == selectedId }),
           !tab.isMainTab {
            return tab.tabErrors
        }
        return ErrorHistory.shared.recentErrors(limit: 50).map { error in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let time = formatter.string(from: error.timestamp)
            let message = error.message.truncate(to: 100)
            return "[\(time)] \(error.errorType): \(message)"
        }
    }

    /// Task summaries for UI display — per-tab when a tab is selected, global for main
    var taskSummaries: [String] {
        if let selectedId = selectedTabId,
           let tab = scriptTabs.first(where: { $0.id == selectedId }),
           !tab.isMainTab {
            return tab.tabTaskSummaries
        }
        return history.records.suffix(50).map { record in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let time = formatter.string(from: record.date)
            return "[\(time)] \(record.prompt) → \(record.summary)"
        }
    }

    /// Clear prompt history for whichever tab is currently selected.
    func clearCurrentTabPromptHistory() {
        if let selectedId = selectedTabId,
           let tab = scriptTabs.first(where: { $0.id == selectedId }) {
            tab.promptHistory.removeAll()
            tab.historyIndex = -1
            tab.savedInput = ""
        } else {
            promptHistory.removeAll()
            historyIndex = -1
            savedInput = ""
            UserDefaults.standard.removeObject(forKey: "agentPromptHistory")
        }
    }

    /// Clear history by type: "Prompts", "Error History", or "Task Summaries".
    func clearHistory(type: String) {
        if let selectedId = selectedTabId,
           let tab = scriptTabs.first(where: { $0.id == selectedId }),
           !tab.isMainTab {
            switch type {
            case "Prompts":
                tab.promptHistory.removeAll()
                tab.historyIndex = -1
                tab.savedInput = ""
            case "Error History":
                tab.tabErrors.removeAll()
            case "Task Summaries":
                tab.tabTaskSummaries.removeAll()
            default:
                break
            }
        } else {
            switch type {
            case "Prompts":
                clearCurrentTabPromptHistory()
            case "Error History":
                ErrorHistory.shared.clear()
            case "Task Summaries":
                history.clearAll()
            default:
                break
            }
        }
    }

    let helperService = HelperService()
    let userService = UserService()
    let scriptService = ScriptService()
    let history = TaskHistory.shared
    var isCancelled = false
    private var runningTask: Task<Void, Never>?
    var mainTaskQueue: [String] = []
    var currentTaskPrompt: String = ""
    var currentAppleAIPrompt: String = ""
    @ObservationIgnored private var terminationObserver: Any?

    // MARK: - Messages Monitor
    var messagesMonitorEnabled: Bool = UserDefaults.standard.object(forKey: "agentMessagesMonitor") as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(messagesMonitorEnabled, forKey: "agentMessagesMonitor")
            if messagesMonitorEnabled {
                startMessagesMonitor()
            } else {
                stopMessagesMonitor()
            }
        }
    }
    private var messagesMonitorTask: Task<Void, Never>?
    /// ROWID of the last message we've already processed
    private var lastSeenMessageROWID: Int = 0
    /// Briefly true during each poll cycle so the StatusDot pulses on the timer
    var messagesPolling = false
    /// Handle ID to reply to when an Agent! task completes (nil = no reply needed)
    var agentReplyHandle: String?
    /// Task for periodic progress updates during long-running tasks
    private var progressUpdateTask: Task<Void, Never>?
    /// Counter for progress updates sent
    private var progressUpdateCount: Int = 0
    /// Current task description for progress updates
    private var currentTaskDescription: String = ""
    /// Timestamp when the current task started
    private var taskStartTime: Date?

    var messageFilter: MessageFilter = {
        MessageFilter(rawValue: UserDefaults.standard.string(forKey: "agentMessageFilter") ?? "") ?? .fromOthers
    }() {
        didSet { UserDefaults.standard.set(messageFilter.rawValue, forKey: "agentMessageFilter") }
    }

    var messageRecipients: [MessageRecipient] = []
    /// Set of handle IDs (phone/email) the user has enabled for monitoring
    var enabledHandleIds: Set<String> = {
        let saved = UserDefaults.standard.stringArray(forKey: "agentEnabledHandleIds") ?? []
        return Set(saved)
    }() {
        didSet { UserDefaults.standard.set(Array(enabledHandleIds), forKey: "agentEnabledHandleIds") }
    }

    // MARK: - Script Tabs

    var scriptTabs: [ScriptTab] = []
    var selectedTabId: UUID?   // nil = Main tab

    func openScriptTab(scriptName: String, selectTab: Bool = true) -> ScriptTab {
        let tab = ScriptTab(scriptName: scriptName)
        // Inherit LLM config from the currently selected main tab
        if let selId = selectedTabId,
           let parent = scriptTabs.first(where: { $0.id == selId && $0.isMainTab }) {
            tab.parentTabId = parent.id
        }
        // Inherit project folder from current context (resolve to directory, not file)
        tab.projectFolder = Self.resolvedWorkingDirectory(self.projectFolder)
        scriptTabs.append(tab)
        if selectTab { selectedTabId = tab.id }
        persistScriptTabs()
        return tab
    }

    /// Create a new main tab with its own LLM provider/model.
    @discardableResult
    func createMainTab(config: LLMConfig) -> ScriptTab {
        // Number duplicate model names: glm-5, glm-5 2, glm-5 3, etc.
        var numberedConfig = config
        let baseName = config.displayName
        let existingCount = scriptTabs.filter { $0.scriptName.hasPrefix(baseName) && $0.isMainTab }.count
        if existingCount > 0 {
            numberedConfig.displayName = "\(baseName) \(existingCount + 1)"
        }
        let tab = ScriptTab(llmConfig: numberedConfig)
        // Inherit project folder from main tab (resolve to directory, not file)
        tab.projectFolder = Self.resolvedWorkingDirectory(self.projectFolder)
        scriptTabs.append(tab)
        selectedTabId = tab.id
        persistScriptTabs()
        return tab
    }

    /// Resolve the LLM provider and model for a given tab.
    /// Main tabs use their own config; script tabs inherit from parent; fallback to global.
    func resolvedLLMConfig(for tab: ScriptTab) -> (provider: APIProvider, model: String) {
        if let config = tab.llmConfig {
            return (config.provider, config.model)
        }
        if let parentId = tab.parentTabId,
           let parent = scriptTabs.first(where: { $0.id == parentId }),
           let config = parent.llmConfig {
            return (config.provider, config.model)
        }
        return (selectedProvider, globalModelForProvider(selectedProvider))
    }

    /// Return the current global model ID for the given provider.
    func globalModelForProvider(_ provider: APIProvider) -> String {
        switch provider {
        case .claude: return selectedModel
        case .openAI: return openAIModel
        case .deepSeek: return deepSeekModel
        case .huggingFace: return huggingFaceModel
        case .ollama: return ollamaModel
        case .localOllama: return localOllamaModel
        case .vLLM: return vLLMModel
        case .lmStudio: return lmStudioModel
        case .zAI: return zAIModel
        case .foundationModel: return "Apple Intelligence"
        }
    }

    /// Return a human-readable display name for a model ID given its provider.
    func modelDisplayName(provider: APIProvider, modelId: String) -> String {
        switch provider {
        case .claude:
            return availableClaudeModels.first(where: { $0.id == modelId })?.displayName ?? modelId
        case .openAI:
            return openAIModels.first(where: { $0.id == modelId })?.name
                ?? Self.defaultOpenAIModels.first(where: { $0.id == modelId })?.name ?? modelId
        case .deepSeek:
            return deepSeekModels.first(where: { $0.id == modelId })?.name
                ?? Self.defaultDeepSeekModels.first(where: { $0.id == modelId })?.name ?? modelId
        case .huggingFace:
            return huggingFaceModels.first(where: { $0.id == modelId })?.name
                ?? Self.defaultHuggingFaceModels.first(where: { $0.id == modelId })?.name ?? modelId
        case .ollama:
            return ollamaModels.first(where: { $0.id == modelId })?.name ?? modelId
        case .localOllama:
            return localOllamaModels.first(where: { $0.id == modelId })?.name ?? modelId
        case .vLLM:
            return vLLMModels.first(where: { $0.id == modelId })?.name ?? modelId
        case .lmStudio:
            return lmStudioModels.first(where: { $0.id == modelId })?.name ?? modelId
        case .zAI:
            return zAIModels.first(where: { $0.id == modelId })?.name
                ?? Self.defaultZAIModels.first(where: { $0.id == modelId })?.name ?? modelId
        case .foundationModel:
            return "Apple Intelligence"
        }
    }

    func closeScriptTab(id: UUID) {
        if let tab = scriptTabs.first(where: { $0.id == id }) {
            // Stop LLM task and clear queue
            if tab.isLLMRunning || !tab.taskQueue.isEmpty {
                stopTabTask(tab: tab)
            }
            // Cancel running script
            if tab.isRunning {
                tab.isCancelled = true
                tab.cancelHandler?()
                tab.isRunning = false
            }
            tab.logFlushTask?.cancel()
            tab.llmStreamFlushTask?.cancel()
            tab.flush()
        }
        if selectedTabId == id {
            if let idx = scriptTabs.firstIndex(where: { $0.id == id }) {
                if idx > 0 {
                    selectedTabId = scriptTabs[idx - 1].id
                } else if scriptTabs.count > 1 {
                    selectedTabId = scriptTabs[1].id
                } else {
                    selectedTabId = nil
                }
            } else {
                selectedTabId = nil
            }
        }
        scriptTabs.removeAll { $0.id == id }
        persistScriptTabs()
    }

    func cancelScriptTab(id: UUID) {
        guard let tab = scriptTabs.first(where: { $0.id == id }) else { return }
        tab.isCancelled = true
        tab.cancelHandler?()
        tab.isRunning = false
        // Also cancel any running LLM task
        if tab.isLLMRunning {
            stopTabTask(tab: tab)
        }
    }

    func selectMainTab() {
        selectedTabId = nil
        persistScriptTabs()
    }

    /// Ensure an LLM tab is selected when a task comes in:
    /// 1. If currently on a main LLM tab, stay there
    /// 2. If on a script tab with a parent, switch to the parent LLM tab
    /// 3. Otherwise, switch to main tab
    func ensureLLMTabSelected() {
        if selectedTabId == nil {
            // Already on main tab
            return
        }

        guard let currentTab = scriptTabs.first(where: { $0.id == selectedTabId }) else {
            // Tab not found, go to main
            selectMainTab()
            return
        }

        if currentTab.isMainTab {
            // Already on an LLM main tab, stay there
            return
        }

        // On a script tab - find its parent
        if let parentId = currentTab.parentTabId,
           let parentTab = scriptTabs.first(where: { $0.id == parentId && $0.isMainTab }) {
            // Switch to parent LLM tab
            selectedTabId = parentTab.id
            persistScriptTabs()
        } else {
            // No parent found or not a main tab, go to main
            selectMainTab()
        }
    }

    // MARK: - Script Tab Persistence

    /// Save open script tabs: order/selected to UserDefaults, log data to SwiftData.
    func persistScriptTabs() {
        for tab in scriptTabs { tab.flush() }

        let ids = scriptTabs.map { $0.id.uuidString }
        UserDefaults.standard.set(ids, forKey: "agentScriptTabIds")
        UserDefaults.standard.set(selectedTabId?.uuidString, forKey: "agentSelectedTabId")

        let tabData = scriptTabs.map { tab in
            let configJSON: String? = {
                guard let config = tab.llmConfig,
                      let data = try? JSONEncoder().encode(config) else { return nil }
                return String(data: data, encoding: .utf8)
            }()
            let historyJSON: String? = {
                guard !tab.promptHistory.isEmpty,
                      let data = try? JSONEncoder().encode(tab.promptHistory) else { return nil }
                return String(data: data, encoding: .utf8)
            }()
            let summariesJSON: String? = {
                guard !tab.tabTaskSummaries.isEmpty,
                      let data = try? JSONEncoder().encode(tab.tabTaskSummaries) else { return nil }
                return String(data: data, encoding: .utf8)
            }()
            let tabErrorsJSON: String? = {
                guard !tab.tabErrors.isEmpty,
                      let data = try? JSONEncoder().encode(tab.tabErrors) else { return nil }
                return String(data: data, encoding: .utf8)
            }()
            return (id: tab.id, scriptName: tab.scriptName, activityLog: tab.activityLog,
                    exitCode: tab.exitCode, llmConfigJSON: configJSON,
                    parentTabIdString: tab.parentTabId?.uuidString,
                    isMessagesTab: tab.isMessagesTab, projectFolder: tab.projectFolder,
                    promptHistoryJSON: historyJSON, taskSummariesJSON: summariesJSON,
                    errorsJSON: tabErrorsJSON,
                    rawLLMOutput: tab.rawLLMOutput, lastElapsed: tab.lastElapsed,
                    thinkingExpanded: tab.thinkingExpanded, thinkingOutputExpanded: tab.thinkingOutputExpanded,
                    thinkingDismissed: tab.thinkingDismissed,
                    tabInputTokens: tab.tabInputTokens, tabOutputTokens: tab.tabOutputTokens)
        }
        ChatHistoryStore.shared.saveScriptTabs(tabData)
    }

    /// Restore script tabs from UserDefaults (order) + SwiftData (data).
    private func restoreScriptTabs() {
        guard let ids = UserDefaults.standard.stringArray(forKey: "agentScriptTabIds"),
              !ids.isEmpty else { return }

        let records = ChatHistoryStore.shared.fetchScriptTabs()
        let recordMap = Dictionary(uniqueKeysWithValues: records.compactMap { r in
            (r.tabId, r)
        })

        for idStr in ids {
            guard let uuid = UUID(uuidString: idStr),
                  let record = recordMap[uuid] else { continue }
            let tab = ScriptTab(record: record)
            scriptTabs.append(tab)
        }

        // Always start on Main tab
        selectedTabId = nil
    }

    // MARK: - Logging State

    static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var logBuffer = ""
    var logFlushTask: Task<Void, Never>?
    var logPersistTask: Task<Void, Never>?
    var streamLineCount = 0
    var streamTruncated = false
    static let outputLineOptions = [10, 50, 75, 100, 150, 200, 250, 500, 750, 1000, 1500]
    var maxOutputLines: Int = UserDefaults.standard.object(forKey: "agentMaxOutputLines") as? Int ?? 1000 {
        didSet { UserDefaults.standard.set(maxOutputLines, forKey: "agentMaxOutputLines") }
    }

    static let readPreviewOptions = [3, 10, 50, 100, 250, 500, 750, 1000]
    var readFilePreviewLines: Int = UserDefaults.standard.object(forKey: "agentReadFilePreviewLines") as? Int ?? 3 {
        didSet { UserDefaults.standard.set(readFilePreviewLines, forKey: "agentReadFilePreviewLines") }
    }

    var scriptCaptureStderr: Bool = UserDefaults.standard.object(forKey: "agentScriptCaptureStderr") as? Bool ?? false {
        didSet { UserDefaults.standard.set(scriptCaptureStderr, forKey: "agentScriptCaptureStderr") }
    }

    var taskAutoComplete: Bool = UserDefaults.standard.object(forKey: "agentTaskAutoComplete") as? Bool ?? true {
        didSet { UserDefaults.standard.set(taskAutoComplete, forKey: "agentTaskAutoComplete") }
    }

    var deletionLimit: Int = UserDefaults.standard.object(forKey: "agentDeletionLimit") as? Int ?? 10 {
        didSet { UserDefaults.standard.set(deletionLimit, forKey: "agentDeletionLimit") }
    }

    // LLM streaming state
    var streamBuffer = ""
    var rawLLMOutput: String = UserDefaults.standard.string(forKey: "mainRawLLMOutput") ?? "" {
        didSet { UserDefaults.standard.set(rawLLMOutput, forKey: "mainRawLLMOutput") }
    }
    var streamFlushTask: Task<Void, Never>?
    var streamingTextStarted = false
    static let maxLogSize = 60_000
    var recentOutputHashes: Set<Int> = []

    // MARK: - Image snapshot cache (persists across launches)

    static let logImageCacheDir: URL = {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Agent/log_images") }
        let dir = caches.appendingPathComponent("Agent/log_images")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let imagePathRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(/[^\s"'<>]+\.(?:jpg|jpeg|png|gif|tiff|bmp|webp|heic))"#,
        options: .caseInsensitive
    )

    // MARK: - Off-Main-Thread Helper

    /// Run synchronous work off the main thread to avoid blocking the UI.
    static func offMain<T: Sendable>(_ work: @Sendable @escaping () -> T) async -> T {
        await Task.detached { work() }.value
    }

    // MARK: - Message History Compression

    /// Compress old tool results — use Apple AI summary if cached, otherwise first 3 lines.
    /// Last 4 messages keep full content. Tool calls (assistant) stay intact.
    static func compressMessages(_ messages: [[String: Any]], keepRecent: Int = 4) -> [[String: Any]] {
        guard messages.count > keepRecent + 1 else { return messages }

        var result: [[String: Any]] = []
        let middleEnd = messages.count - keepRecent

        for i in 0..<middleEnd {
            var msg = messages[i]
            let role = msg["role"] as? String ?? ""

            if role == "user" {
                if var blocks = msg["content"] as? [[String: Any]] {
                    for j in 0..<blocks.count {
                        if blocks[j]["type"] as? String == "tool_result",
                           let content = blocks[j]["content"] as? String, content.count > 200 {
                            let key = content.hashValue
                            if let cached = _summaryCache[key] {
                                blocks[j]["content"] = cached
                            } else {
                                let preview = content.components(separatedBy: "\n").prefix(3).joined(separator: "\n")
                                blocks[j]["content"] = preview + "\n(... already processed)"
                            }
                        }
                    }
                    msg["content"] = blocks
                }
            } else if role == "assistant" {
                // Compress old assistant text (keep tool_use blocks intact)
                if var blocks = msg["content"] as? [[String: Any]] {
                    for j in 0..<blocks.count {
                        if blocks[j]["type"] as? String == "text",
                           let text = blocks[j]["text"] as? String, text.count > 150 {
                            blocks[j]["text"] = String(text.prefix(100)) + "..."
                        }
                    }
                    msg["content"] = blocks
                }
            }
            result.append(msg)
        }

        result.append(contentsOf: messages.suffix(keepRecent))
        return result
    }

    /// Use Apple AI to summarize long text, fall back to truncation if unavailable.
    private static func summarizeOrTruncate(_ text: String) -> String {
        let key = text.hashValue
        if let cached = _summaryCache[key] { return cached }

        // Fallback: truncate (Apple AI summary happens async via compressMessagesAsync)
        let truncated = String(text.prefix(150)) + "...(truncated \(text.count) chars)"
        _summaryCache[key] = truncated
        return truncated
    }

    /// Cache summaries so we don't re-summarize the same content.
    nonisolated(unsafe) private static var _summaryCache: [Int: String] = [:]

    /// Async version: summarize old messages using Apple AI before sending.
    /// Call this before compressMessages for best results.
    static func summarizeOldMessages(_ messages: inout [[String: Any]], keepRecent: Int = 4) async {
        guard messages.count > keepRecent + 1, FoundationModelService.isAvailable else {
            print("🧠 [AppleAI Summary] skipped: msgs=\(messages.count) available=\(FoundationModelService.isAvailable)")
            return
        }

        let middleEnd = messages.count - keepRecent
        print("🧠 [AppleAI Summary] processing \(middleEnd - 1) old messages")
        let session = LanguageModelSession(model: .default, instructions: Instructions("Summarize in 1-2 concise sentences. Keep file paths, function names, errors, and key results."))

        for i in 1..<middleEnd {
            let role = messages[i]["role"] as? String ?? ""

            if role == "user" {
                if var blocks = messages[i]["content"] as? [[String: Any]] {
                    var changed = false
                    for j in 0..<blocks.count {
                        if let content = blocks[j]["content"] as? String, content.count > 300 {
                            let key = content.hashValue
                            if _summaryCache[key] == nil {
                                let input = String(content.prefix(2000))
                                if let resp = try? await session.respond(to: input) {
                                    _summaryCache[key] = "[summary] " + resp.content
                                }
                            }
                            if let cached = _summaryCache[key] {
                                blocks[j]["content"] = cached
                                changed = true
                            }
                        }
                    }
                    if changed { messages[i]["content"] = blocks }
                } else if let text = messages[i]["content"] as? String, text.count > 300 {
                    let key = text.hashValue
                    if _summaryCache[key] == nil {
                        let input = String(text.prefix(2000))
                        if let resp = try? await session.respond(to: input) {
                            _summaryCache[key] = "[summary] " + resp.content
                        }
                    }
                    if let cached = _summaryCache[key] { messages[i]["content"] = cached }
                }
            }
        }
    }

    // MARK: - Token Estimation (~4 chars per token)

    /// Estimate input tokens from message array.
    static func estimateTokens(messages: [[String: Any]]) -> Int {
        var chars = 0
        for msg in messages {
            if let text = msg["content"] as? String {
                chars += text.count
            } else if let blocks = msg["content"] as? [[String: Any]] {
                for block in blocks {
                    if let text = block["text"] as? String { chars += text.count }
                    else if let text = block["content"] as? String { chars += text.count }
                }
            }
        }
        return max(1, chars / 4)
    }

    /// Estimate output tokens from response content blocks.
    static func estimateTokens(content: [[String: Any]]) -> Int {
        var chars = 0
        for block in content {
            if let text = block["text"] as? String { chars += text.count }
            if let input = block["input"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: input) {
                chars += data.count
            }
        }
        return max(1, chars / 4)
    }

    // MARK: - Computed Properties

    var daemonReady: Bool { helperService.helperReady }
    var agentReady: Bool { userService.userReady }
    var hasAttachments: Bool { !attachedImages.isEmpty }

    // MARK: - Voice Input

    /// Check if speech recognition is authorized
    var isSpeechRecognitionAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    var speechAudioEngine: AVAudioEngine?
    var speechRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var speechRecognitionTask: SFSpeechRecognitionTask?
    var preDictationText: String = ""
    /// Tracks which tab was selected when dictation started, so speech goes to the correct input field
    var preDictationTabId: UUID?

    // MARK: - Hotword ("Agent!") Listening
    /// When true, mic stays open waiting for "Agent!" wake word
    var isHotwordListening = false {
        didSet { UserDefaults.standard.set(isHotwordListening, forKey: "isHotwordListening") }
    }
    /// True while capturing a command after the wake word was detected
    var isHotwordCapturing = false
    /// Timer that fires after 5 seconds of silence to auto-submit
    var hotwordSilenceTimer: Timer?
    /// Transcription length at last change — used to detect silence
    var hotwordLastTranscriptionLength = 0
    
    // MARK: - Init

    init() {
        // Restore ~/Documents/AgentScript/ folder and bundled resources if missing
        scriptService.ensurePackage()
        scriptService.rebuildAllMetadata()
        SystemPromptService.shared.ensureDefaults()

        // Sync known agent names for direct command matching
        AppleIntelligenceMediator.knownAgentNames = Set(scriptService.listScripts().map { $0.name.lowercased() })

        // Cancel any orphaned processes from a previous app session
        let defaults = UserDefaults.standard
        if let oldHelperID = defaults.string(forKey: "lastHelperInstanceID") {
            HelperService.cancelProcess(instanceID: oldHelperID)
        }
        if let oldUserID = defaults.string(forKey: "lastUserInstanceID") {
            UserService.cancelProcess(instanceID: oldUserID)
        }
        // Persist current instanceIDs so next launch can clean up
        defaults.set(helperService.instanceID, forKey: "lastHelperInstanceID")
        defaults.set(userService.instanceID, forKey: "lastUserInstanceID")

        // Restore persisted script tabs
        restoreScriptTabs()

        // Cancel running processes and persist script tabs on app quit
        let helperID = helperService.instanceID
        let userID = userService.instanceID
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.persistScriptTabs() }
            HelperService.cancelProcess(instanceID: helperID)
            UserService.cancelProcess(instanceID: userID)
            UserDefaults.standard.removeObject(forKey: "lastHelperInstanceID")
            UserDefaults.standard.removeObject(forKey: "lastUserInstanceID")
        }

        // Models are fetched on-demand when the user switches providers,
        // opens the new-tab sheet, or clicks refresh in settings.
        // No auto-fetch on launch — avoids wasting API calls for inactive LLMs.

        // Xcode Command Line Tools check is handled by DependencyOverlay in ContentView

        // Resume Messages monitor if it was enabled
        if messagesMonitorEnabled {
            // Delay start so UserService is connected first
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                startMessagesMonitor()
            }
        }

        // Test daemon connectivity on startup — auto-fix if not responding
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            appendLog("🔥 Warming up...")
            var userOK = await userService.ping()
            userPingOK = userOK
            appendLog("⚙️ User agent: \(userOK ? "ping OK" : "no response")")
            var daemonOK = false
            if rootEnabled {
                daemonOK = await helperService.ping()
                daemonPingOK = daemonOK
                appendLog("⚙️ Launch Daemon: \(daemonOK ? "ping OK" : "no response")")
            } else {
                daemonPingOK = false
                appendLog("⚙️ Launch Daemon: disabled")
            }
            if !userOK {
                appendLog("🔄 User agent: mending...")
                _ = userService.restartAgent()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                userOK = await userService.ping()
                userPingOK = userOK
                appendLog("⚙️ User agent: \(userOK ? "mended — ping OK" : "still NOT responding")")
            }
            if rootEnabled && !daemonOK {
                appendLog("🔄 Launch Daemon: mending...")
                _ = helperService.restartDaemon()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                daemonOK = await helperService.ping()
                daemonPingOK = daemonOK
                appendLog("⚙️ Launch Daemon: \(daemonOK ? "mended — ping OK" : "still NOT responding")")
            }
            if !userOK || (rootEnabled && !daemonOK) {
                appendLog("⚠️ Click Register to restart services")
            }
        }
    }

    // MARK: - Registration

    func registerDaemon() {
        let msg = helperService.registerHelper()
        appendLog(msg)
    }

    func registerAgent() {
        let msg = userService.registerUser()
        appendLog(msg)
    }

    func unregisterDaemon() {
        helperService.shutdownDaemon()
        daemonPingOK = false
        appendLog("⚙️ Helper daemon unregistered.")
    }

    func unregisterAgent() {
        userService.shutdownAgent()
        userPingOK = false
        appendLog("⚙️ User agent unregistered.")
    }

    func testConnection() {
        appendLog("🔌 Testing connections...")
        Task {
            var userOK = await userService.ping()
            userPingOK = userOK
            appendLog("⚙️ User agent: \(userOK ? "ping OK" : "no response")")
            var daemonOK = await helperService.ping()
            daemonPingOK = daemonOK
            appendLog("⚙️ Launch Daemon: \(daemonOK ? "ping OK" : "no response")")
            if !userOK {
                appendLog("🔄 User agent: mending...")
                _ = userService.restartAgent()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                userOK = await userService.ping()
                userPingOK = userOK
                appendLog("⚙️ User agent: \(userOK ? "mended — ping OK" : "still NOT responding")")
            }
            if !daemonOK {
                appendLog("🔄 Launch Daemon: mending...")
                _ = helperService.restartDaemon()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                daemonOK = await helperService.ping()
                daemonPingOK = daemonOK
                appendLog("⚙️ Launch Daemon: \(daemonOK ? "mended — ping OK" : "still NOT responding")")
            }
            if !userOK || !daemonOK {
                appendLog("⚠️ Click Register to restart services")
            }
        }
    }

    // MARK: - Run / Stop

    func run() {
        let task = taskInput.trimmingCharacters(in: .whitespaces)
        guard !task.isEmpty else { return }

        // Handle /clear commands
        if task.lowercased().hasPrefix("/clear") {
            taskInput = ""
            let arg = task.dropFirst(6).trimmingCharacters(in: .whitespaces).lowercased()
            switch arg {
            case "", "log":
                clearSelectedLog()
            case "all":
                clearAll()
            case "llm":
                rawLLMOutput = ""
                if let selId = selectedTabId, let tab = scriptTabs.first(where: { $0.id == selId }) {
                    tab.rawLLMOutput = ""
                }
                appendLog("🧹 LLM output cleared.")
                flushLog()
            case "history":
                promptHistory.removeAll()
                UserDefaults.standard.removeObject(forKey: "agentPromptHistory")
                if let selId = selectedTabId, let tab = scriptTabs.first(where: { $0.id == selId }) {
                    tab.promptHistory.removeAll()
                }
                appendLog("🧹 Prompt history cleared.")
                flushLog()
            case "tasks":
                history.clearAll()
                appendLog("🧹 Task history cleared.")
                flushLog()
            case "tokens":
                taskInputTokens = 0; taskOutputTokens = 0
                sessionInputTokens = 0; sessionOutputTokens = 0
                appendLog("🧹 Token counts reset.")
                flushLog()
            default:
                appendLog("Usage: /clear [all|log|llm|history|tasks|tokens]")
                flushLog()
            }
            return
        }

        // Handle /memory command — show, edit, or clear memory
        if task.lowercased().hasPrefix("/memory") {
            taskInput = ""
            let arg = task.dropFirst(7).trimmingCharacters(in: .whitespaces)
            if arg.isEmpty || arg.lowercased() == "show" {
                let content = MemoryStore.shared.content
                appendLog("📝 Memory:\n\(content.isEmpty ? "(empty)" : content)")
            } else if arg.lowercased() == "clear" {
                MemoryStore.shared.write("")
                appendLog("📝 Memory cleared.")
            } else if arg.lowercased() == "edit" {
                // Open the memory file in default editor
                let url = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/AgentScript/memory.md")
                NSWorkspace.shared.open(url)
                appendLog("📝 Opened memory.md in editor.")
            } else {
                // Anything else: append to memory
                MemoryStore.shared.append(arg)
                appendLog("📝 Added to memory: \(arg)")
            }
            flushLog()
            return
        }

        // Switch to appropriate LLM tab: current LLM tab, parent LLM tab if on child, or main tab
        ensureLLMTabSelected()

        promptHistory.append(task)
        UserDefaults.standard.set(promptHistory, forKey: "agentPromptHistory")
        // Sync to selected tab so arrow keys work — seed from viewModel if tab is empty
        if let selectedId = selectedTabId,
           let tab = scriptTabs.first(where: { $0.id == selectedId }) {
            if tab.promptHistory.isEmpty && !promptHistory.isEmpty {
                tab.promptHistory = promptHistory
            } else {
                tab.addToHistory(task)
            }
        }
        historyIndex = -1
        savedInput = ""

        // Clean up prompt via Apple AI in the background (for autocomplete suggestions)
        Task { @MainActor [weak self] in
            let cleaned = await FoundationModelService.cleanUpPrompt(task)
            guard let self, cleaned != task else { return }
            if let idx = self.promptHistory.lastIndex(of: task) {
                self.promptHistory[idx] = cleaned
                UserDefaults.standard.set(self.promptHistory, forKey: "agentPromptHistory")
            }
            if let selectedId = self.selectedTabId,
               let tab = self.scriptTabs.first(where: { $0.id == selectedId }),
               let tabIdx = tab.promptHistory.lastIndex(of: task) {
                tab.promptHistory[tabIdx] = cleaned
            }
        }
        taskInput = ""

        // Queue if already running
        if isRunning {
            mainTaskQueue.append(task)
            appendLog("📋 Queued (\(mainTaskQueue.count)): \(task)")
            flushLog()
            return
        }

        startMainTask(task)
    }

    /// Start executing a task on the main tab (not queued).
    private func startMainTask(_ task: String) {
        isCancelled = false
        currentTaskPrompt = task
        ChatHistoryStore.shared.startNewTask(prompt: task)

        runningTask = Task {
            await executeTask(task)
            // When done, run next queued task
            if !mainTaskQueue.isEmpty && !isCancelled {
                let next = mainTaskQueue.removeFirst()
                startMainTask(next)
            }
        }
    }

    /// Navigate prompt history. direction: -1 = older (up arrow), 1 = newer (down arrow)
    func navigatePromptHistory(direction: Int) {
        guard !currentTabPromptHistory.isEmpty else { return }

        if historyIndex == -1 {
            // Starting to browse — save current input
            savedInput = taskInput
            if direction == -1 {
                historyIndex = currentTabPromptHistory.count - 1
            } else {
                return // already at the beginning, nothing newer
            }
        } else {
            historyIndex += direction
        }

        if historyIndex < 0 {
            // Went past the oldest — restore saved input
            historyIndex = -1
            taskInput = savedInput
            return
        }

        if historyIndex >= currentTabPromptHistory.count {
            // Back to current input
            historyIndex = -1
            taskInput = savedInput
            return
        }

        taskInput = currentTabPromptHistory[historyIndex]
    }

    func stop(silent: Bool = false) {
        let queueCount = mainTaskQueue.count
        mainTaskQueue.removeAll()
        isCancelled = true
        runningTask?.cancel()
        runningTask = nil
        helperService.cancel()
        helperService.onOutput = nil
        // Don't cancel userService — tabs may be using it for concurrent operations
        userService.onOutput = nil
        // Stop progress updates
        stopProgressUpdates()
        if !silent {
            if queueCount > 0 {
                appendLog("🚫 Cancelled. \(queueCount) queued task(s) cleared.")
            } else {
                appendLog("🚫 Cancelled.")
            }
        }
        flushLog()
        persistLogNow()
        // End the current task in chat history
        ChatHistoryStore.shared.endCurrentTask(cancelled: !silent)
        isRunning = false
        isThinking = false
        currentTaskPrompt = ""
        currentAppleAIPrompt = ""
        userServiceActive = false
        rootServiceActive = false
        userWasActive = false
        rootWasActive = false
    }

    /// Stop everything — main task AND all script tabs.
    func stopAll() {
        stop()
        for tab in scriptTabs {
            // Stop LLM tasks and clear queues
            if tab.isLLMRunning || !tab.taskQueue.isEmpty {
                stopTabTask(tab: tab)
            }
            // Cancel running scripts
            if tab.isRunning {
                tab.isCancelled = true
                tab.cancelHandler?()
                tab.isRunning = false
            }
            tab.logFlushTask?.cancel()
            tab.llmStreamFlushTask?.cancel()
            tab.flush()
        }
        persistScriptTabs()
    }

    // MARK: - Messages Monitor

    func startMessagesMonitor() {
        stopMessagesMonitor()
        refreshMessageRecipients()
        appendLog("💬 Messages: ON")
        flushLog()

        messagesMonitorTask = Task { [weak self] in
            guard let self else { return }
            // Seed the last-seen ROWID so we only act on NEW messages
            await self.seedLastSeenROWID()

            // Pulse on startup
            self.flashMessagesDot()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // poll every 5s
                guard !Task.isCancelled else { break }
                await self.pollMessages()
            }
        }
    }

    func stopMessagesMonitor() {
        messagesMonitorTask?.cancel()
        messagesMonitorTask = nil
        messagesPolling = false
    }

    /// Send an immediate acknowledgment via iMessage when a task starts.
    private func sendAgentAck() {
        guard let handle = agentReplyHandle else { return }
        let ack = "Working on it..."
        let escaped = ack.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(handle)" of targetService
            send "\(escaped)" to targetBuddy
        end tell
        """
        Task {
            let result = await Self.executeTCC(command: "osascript -e '\(script.replacingOccurrences(of: "'", with: "'\\''"))'")

            if result.status == 0 {
                appendLog("Agent! ack sent to \(handle)")
            } else {
                appendLog("Agent! ack failed: \(result.output.prefix(100))")
            }
            flushLog()
        }
    }

    /// Send a reply via iMessage to the handle that triggered the Agent! task.
    func sendAgentReply(_ summary: String) {
        guard let handle = agentReplyHandle else { return }
        agentReplyHandle = nil

        // Strip "Agent!" prefix from outgoing replies to avoid triggering another command
        var reply = summary
        if reply.hasPrefix("Agent!") {
            reply = String(reply.dropFirst(6)) // Drop "Agent!" (5 chars + potential space)
            if reply.hasPrefix(" ") {
                reply = String(reply.dropFirst())
            }
        }

        // iMessage supports up to ~65KB, but we cap at 4000 chars for reliability
        // (this is the practical limit before carriers may split messages)
        reply = String(reply.prefix(4000))
        // Escape for AppleScript
        let escaped = reply
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(handle)" of targetService
            send "\(escaped)" to targetBuddy
        end tell
        """
        Task {
            let result = await Self.executeTCC(command: "osascript -e '\(script.replacingOccurrences(of: "'", with: "'\\''"))'")

            if result.status == 0 {
                appendLog("Agent! reply sent to \(handle)")
            } else {
                appendLog("Agent! reply failed: \(result.output.prefix(100))")
            }
            flushLog()
        }
    }

    /// Briefly flash the Messages StatusDot green.
    private func flashMessagesDot() {
        messagesPolling = true
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            messagesPolling = false
        }
    }

    // MARK: - Progress Updates for Long-Running Tasks
    
    /// Start periodic progress updates via iMessage for long-running tasks.
    /// Sends an update every 10 minutes with elapsed time and current status.
    func startProgressUpdates(for taskDescription: String) {
        stopProgressUpdates() // Cancel any existing updates
        
        currentTaskDescription = taskDescription
        taskStartTime = Date()
        progressUpdateCount = 0
        
        progressUpdateTask = Task { [weak self] in
            while !Task.isCancelled {
                // Wait 10 minutes between updates
                do {
                    try await Task.sleep(for: .seconds(600))
                } catch {
                    break // Task cancelled
                }
                
                guard let self = self, self.isRunning else { break }
                
                self.progressUpdateCount += 1
                let elapsed: String
                if let startTime = self.taskStartTime {
                    let interval = Date().timeIntervalSince(startTime)
                    let minutes = Int(interval) / 60
                    let seconds = Int(interval) % 60
                    if minutes > 0 {
                        elapsed = "\(minutes)m \(seconds)s"
                    } else {
                        elapsed = "\(seconds)s"
                    }
                } else {
                    elapsed = "unknown"
                }
                
                let statusMessage: String
                if self.isThinking {
                    statusMessage = "thinking..."
                } else if self.userServiceActive || self.rootServiceActive {
                    statusMessage = "executing command..."
                } else {
                    statusMessage = "processing..."
                }
                
                // Send progress update
                let update = "⏳ Progress: \(elapsed) elapsed, \(statusMessage) (update #\(self.progressUpdateCount))"
                self.sendProgressUpdate(update)
            }
        }
    }
    
    /// Stop progress updates when task completes or is cancelled.
    func stopProgressUpdates() {
        progressUpdateTask?.cancel()
        progressUpdateTask = nil
        taskStartTime = nil
        progressUpdateCount = 0
        currentTaskDescription = ""
    }
    
    /// Send a progress update message via iMessage.
    func sendProgressUpdate(_ message: String) {
        guard let handle = agentReplyHandle else { return }
        let escaped = message.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(handle)" of targetService
            send "\(escaped)" to targetBuddy
        end tell
        """
        Task {
            let result = await Self.executeTCC(command: "osascript -e '\(script.replacingOccurrences(of: "'", with: "'\\''"))'")

            if result.status == 0 {
                appendLog("📤 Progress: \(message)")
            } else {
                appendLog("❌ Progress failed: \(result.output.prefix(50))")
            }
            flushLog()
        }
    }

    // Stored outside @MainActor so nonisolated static methods can access it
    private nonisolated static let messagesDBPath = NSHomeDirectory() + "/Library/Messages/chat.db"

    /// Decode attributedBody blob (typedstream/NSArchiver format).
    /// NSUnarchiver is the only way to decode the typedstream format used by the Messages database.
    private nonisolated static func decodeAttributedBody(_ data: Data) -> NSAttributedString? {
        guard let cls = NSClassFromString("NSUnarchiver") else { return nil }
        let sel = NSSelectorFromString("unarchiveObjectWithData:")
        guard let method = class_getClassMethod(cls, sel) else { return nil }
        typealias Fn = @convention(c) (AnyClass, Selector, NSData) -> AnyObject?
        let imp = method_getImplementation(method)
        let f = unsafeBitCast(imp, to: Fn.self)
        return f(cls, sel, data as NSData) as? NSAttributedString
    }

    /// Read new messages directly from chat.db using SQLite3 C API.
    private nonisolated static func queryMessages(afterROWID: Int, filter: MessageFilter) -> [RawMessage] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(messagesDBPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        let whereClause: String
        switch filter {
        case .fromOthers: whereClause = "m.ROWID > ?1 AND m.is_from_me = 0"
        case .fromMe:     whereClause = "m.ROWID > ?1 AND m.is_from_me = 1"
        case .noFilter:   whereClause = "m.ROWID > ?1"
        }

        let sql = """
        SELECT m.ROWID, m.text, m.attributedBody, \
        COALESCE(h.id, ''), m.handle_id, COALESCE(cmj.chat_id, 0), \
        COALESCE(m.service, ''), COALESCE(m.account, '') \
        FROM message m \
        LEFT JOIN handle h ON h.ROWID = m.handle_id \
        LEFT JOIN chat_message_join cmj ON cmj.message_id = m.ROWID \
        WHERE \(whereClause) ORDER BY m.ROWID ASC LIMIT 10
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(afterROWID))

        var results: [RawMessage] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowid = Int(sqlite3_column_int64(stmt, 0))
            let handleId = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
            let handleRowId = Int(sqlite3_column_int64(stmt, 4))
            let chatId = Int(sqlite3_column_int64(stmt, 5))
            let service = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""
            let account = sqlite3_column_text(stmt, 7).map { String(cString: $0) } ?? ""

            // Try the `text` column first
            var text: String?
            if let cStr = sqlite3_column_text(stmt, 1) {
                let s = String(cString: cStr)
                if !s.isEmpty { text = s }
            }

            // Fall back to decoding attributedBody blob (NSArchiver typedstream format)
            if text == nil, let blobPtr = sqlite3_column_blob(stmt, 2) {
                let blobLen = Int(sqlite3_column_bytes(stmt, 2))
                let data = Data(bytes: blobPtr, count: blobLen)
                if let attrStr = Self.decodeAttributedBody(data) {
                    let s = attrStr.string
                    if !s.isEmpty { text = s }
                }
            }

            results.append(RawMessage(rowid: rowid, text: text ?? "", handleId: handleId, handleRowId: handleRowId, chatId: chatId, service: service, account: account))
        }
        return results
    }

    /// Auto-add a recipient from an incoming message if not already known.
    private func autoAddRecipient(from row: RawMessage) {
        guard !row.handleId.isEmpty else { return }
        if messageRecipients.contains(where: { $0.id == row.handleId }) { return }
        let fromMe = messageFilter == .fromMe
        let recipient = MessageRecipient(id: row.handleId, displayName: row.handleId, service: row.service, fromMe: fromMe)
        messageRecipients.append(recipient)
        persistRecipients()
    }

    private func persistRecipients() {
        let ids = messageRecipients.map(\.id)
        let services = messageRecipients.map(\.service)
        let fromMes = messageRecipients.map(\.fromMe)
        UserDefaults.standard.set(ids, forKey: "agentDiscoveredHandles")
        UserDefaults.standard.set(services, forKey: "agentDiscoveredServices")
        UserDefaults.standard.set(fromMes, forKey: "agentDiscoveredFromMe")
    }

    /// Reload previously discovered recipients from UserDefaults.
    func refreshMessageRecipients() {
        let ids = UserDefaults.standard.stringArray(forKey: "agentDiscoveredHandles") ?? []
        let services = UserDefaults.standard.stringArray(forKey: "agentDiscoveredServices") ?? []
        let fromMes = UserDefaults.standard.array(forKey: "agentDiscoveredFromMe") as? [Bool] ?? []
        var recipients: [MessageRecipient] = []
        for (i, id) in ids.enumerated() {
            let service = i < services.count ? services[i] : ""
            let fromMe = i < fromMes.count ? fromMes[i] : false
            recipients.append(MessageRecipient(id: id, displayName: id, service: service, fromMe: fromMe))
        }
        messageRecipients = recipients
    }

    /// Recipients filtered by the current message filter setting.
    var filteredRecipients: [MessageRecipient] {
        switch messageFilter {
        case .fromOthers: return messageRecipients.filter { !$0.fromMe }
        case .fromMe:     return messageRecipients.filter { $0.fromMe }
        case .noFilter:   return messageRecipients
        }
    }

    /// Query for the max ROWID in the Messages database.
    private nonisolated static func maxMessageROWID() -> Int? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(messagesDBPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT MAX(ROWID) FROM message", -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// Seed the ROWID cursor so we only process messages arriving after monitor starts.
    private func seedLastSeenROWID() async {
        // Retry up to 3 times with a delay (macOS may need a moment to grant DB access)
        for attempt in 1...3 {
            if let rowid = await Self.offMain({ Self.maxMessageROWID() }) {
                lastSeenMessageROWID = rowid
                appendLog("💬 Messages: seeded at ROWID \(rowid)")
                flushLog()
                return
            }
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        // Cannot read chat.db — open Full Disk Access settings for the user
        lastSeenMessageROWID = Int.max
        appendLog("💬 Messages: Full Disk Access required to read iMessages. Opening System Settings…")
        flushLog()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }

    // MARK: - Messages Tab

    /// Find or create the dedicated Messages tab. Always uses main tab's LLM settings.
    func ensureMessagesTab() -> ScriptTab {
        if let existing = scriptTabs.first(where: { $0.isMessagesTab }) {
            return existing
        }
        let tab = ScriptTab(scriptName: "Messages")
        tab.isMessagesTab = true
        tab.isRunning = false
        scriptTabs.append(tab)
        persistScriptTabs()
        return tab
    }

    /// Send an iMessage reply from the Messages tab after its task completes.
    func sendMessagesTabReply(_ summary: String, handle: String) {
        // Strip "Agent!" prefix from outgoing replies to avoid triggering another command
        var reply = summary
        if reply.hasPrefix("Agent!") {
            reply = String(reply.dropFirst(6))
            if reply.hasPrefix(" ") {
                reply = String(reply.dropFirst())
            }
        }
        let escaped = reply.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(handle)" of targetService
            send "\(escaped)" to targetBuddy
        end tell
        """
        Task {
            let result = await Self.executeTCC(command: "osascript -e '\(script.replacingOccurrences(of: "'", with: "'\\''"))'")

            let msgTab = scriptTabs.first(where: { $0.isMessagesTab })
            if result.status == 0 {
                msgTab?.appendLog("💬 Reply sent to \(handle)")
            } else {
                msgTab?.appendLog("❌ Reply failed: \(result.output.prefix(100))")
            }
            msgTab?.flush()
        }
    }

    /// Send an iMessage acknowledgment from the Messages tab.
    private func sendMessagesTabAck(handle: String) {
        let ack = "Working on it..."
        let escaped = ack.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(handle)" of targetService
            send "\(escaped)" to targetBuddy
        end tell
        """
        Task {
            let result = await Self.executeTCC(command: "osascript -e '\(script.replacingOccurrences(of: "'", with: "'\\''"))'")

            let msgTab = scriptTabs.first(where: { $0.isMessagesTab })
            if result.status == 0 {
                msgTab?.appendLog("💬 Ack sent to \(handle)")
            } else {
                msgTab?.appendLog("❌ Ack failed: \(result.output.prefix(100))")
            }
            msgTab?.flush()
        }
    }

    /// Poll for new incoming messages; log from enabled handles, act on "Agent!" prefix.
    /// Routes messages to the dedicated Messages tab instead of the main/active tab.
    private func pollMessages() async {
        // If seed failed, try to reseed now
        if lastSeenMessageROWID == Int.max {
            if let rowid = await Self.offMain({ Self.maxMessageROWID() }) {
                lastSeenMessageROWID = rowid
                appendLog("💬 Messages: reseeded at ROWID \(rowid)")
                flushLog()
            }
            return
        }

        let after = lastSeenMessageROWID
        let enabled = enabledHandleIds
        let filter = messageFilter
        let rows = await Self.offMain({ Self.queryMessages(afterROWID: after, filter: filter) })
        guard !rows.isEmpty else { return }

        for row in rows {
            lastSeenMessageROWID = row.rowid

            guard !row.text.isEmpty else { continue }

            // Only process messages that start with "Agent!"
            guard row.text.hasPrefix("Agent!") else { continue }

            // Auto-discover this sender
            autoAddRecipient(from: row)

            let approved = enabled.contains(row.handleId)

            // Always show the message in the main log
            flashMessagesDot()
            if approved {
                appendLog("iMessage (\(row.handleId)): \(row.text)")
            } else {
                appendLog("iMessage not approved (\(row.handleId)): \(row.text) — select this recipient in the Messages toolbar button")
            }
            flushLog()

            guard approved else { continue }

            let stripped = row.text.dropFirst(6) // drop "Agent!"
            let prompt = stripped.hasPrefix(" ")
                ? String(stripped.dropFirst()).trimmingCharacters(in: .whitespaces)
                : String(stripped).trimmingCharacters(in: .whitespaces)
            guard !prompt.isEmpty else { continue }

            // Route to dedicated Messages tab
            let msgTab = ensureMessagesTab()

            // Skip if Messages tab is already running a task
            guard !msgTab.isLLMRunning else {
                msgTab.appendLog("Busy — skipped: \(prompt)")
                msgTab.flush()
                continue
            }

            msgTab.replyHandle = row.handleId
            msgTab.appendLog("iMessage from \(row.handleId): \(prompt)")
            msgTab.flush()

            // Send immediate ack
            sendMessagesTabAck(handle: row.handleId)

            // Select the Messages tab so the user sees it
            selectedTabId = msgTab.id

            // Run the task on the Messages tab (uses main tab's LLM config via resolvedLLMConfig fallback)
            msgTab.taskInput = prompt
            runTabTask(tab: msgTab)
        }
    }

    // MARK: - Model Fetching

    func fetchClaudeModels() async {
        guard !apiKey.isEmpty else {
            await MainActor.run {
                self.availableClaudeModels = Self.defaultClaudeModels
            }
            return
        }

        do {
            let models = try await Self.fetchClaudeModelsFromAPI(apiKey: apiKey)
            await MainActor.run {
                self.availableClaudeModels = models.isEmpty ? Self.defaultClaudeModels : models
            }
        } catch {
            print("Error fetching Claude models: \(error)")
            await MainActor.run {
                self.availableClaudeModels = Self.defaultClaudeModels
            }
        }
    }

    private static func fetchClaudeModelsFromAPI(apiKey: String) async throws -> [ClaudeModelInfo] {
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AgentError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "API error")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsData = json["data"] as? [[String: Any]] else {
            return defaultClaudeModels
        }

        let models = modelsData.compactMap { modelData -> ClaudeModelInfo? in
            guard let id = modelData["id"] as? String else { return nil }
            let displayName = modelData["display_name"] as? String ?? id
            let createdAt = modelData["created_at"] as? String
            let description = modelData["description"] as? String

            return ClaudeModelInfo(
                id: id,
                name: displayName,
                displayName: displayName,
                createdAt: createdAt,
                description: description
            )
        }

        return models.isEmpty ? defaultClaudeModels : models
    }

    func fetchOllamaModels() {
        let endpoint = ollamaEndpoint
        let apiKey = ollamaAPIKey
        isFetchingModels = true
        Task {
            defer { isFetchingModels = false }
            do {
                let models = try await Self.fetchModels(endpoint: endpoint, apiKey: apiKey)
                ollamaModels = models.isEmpty ? Self.defaultOllamaModels : models
                // Auto-select first model if current selection is empty or not in list
                let names = ollamaModels.map(\.name)
                if ollamaModel.isEmpty || (!names.isEmpty && !names.contains(ollamaModel)) {
                    ollamaModel = names.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch models: \(error.localizedDescription)")
                ollamaModels = Self.defaultOllamaModels
            }
        }
    }

    func fetchLocalOllamaModels() {
        let endpoint = localOllamaEndpoint
        isFetchingLocalModels = true
        Task {
            defer { isFetchingLocalModels = false }
            do {
                let models = try await Self.fetchModels(endpoint: endpoint, apiKey: "")
                localOllamaModels = models
                let names = models.map(\.name)
                if localOllamaModel.isEmpty || (!names.isEmpty && !names.contains(localOllamaModel)) {
                    localOllamaModel = names.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch local models: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - OpenAI Models

    func fetchOpenAIModels() {
        isFetchingOpenAIModels = true
        let key = openAIAPIKey
        Task {
            defer { isFetchingOpenAIModels = false }
            guard !key.isEmpty else {
                openAIModels = Self.defaultOpenAIModels
                return
            }
            do {
                let models = try await Self.fetchOpenAIModelsFromAPI(apiKey: key)
                openAIModels = models.isEmpty ? Self.defaultOpenAIModels : models
                if openAIModel.isEmpty || !openAIModels.contains(where: { $0.id == openAIModel }) {
                    openAIModel = openAIModels.first?.id ?? "gpt-4.1-nano"
                }
            } catch {
                appendLog("Failed to fetch OpenAI models: \(error.localizedDescription)")
                openAIModels = Self.defaultOpenAIModels
            }
        }
    }

    private nonisolated static func fetchOpenAIModelsFromAPI(apiKey: String) async throws -> [OpenAIModelInfo] {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsData = json["data"] as? [[String: Any]] else {
            return []
        }

        // Filter to chat models only
        let chatPrefixes = ["gpt-4", "gpt-3.5", "o1", "o3", "o4"]
        return modelsData.compactMap { model -> OpenAIModelInfo? in
            guard let id = model["id"] as? String else { return nil }
            guard chatPrefixes.contains(where: { id.hasPrefix($0) }) else { return nil }
            // Skip dated snapshots if the base model is also available
            return OpenAIModelInfo(id: id, name: id)
        }.sorted { $0.name < $1.name }
    }

    // MARK: - DeepSeek Models

    func fetchDeepSeekModels() {
        isFetchingDeepSeekModels = true
        let key = deepSeekAPIKey
        Task {
            defer { isFetchingDeepSeekModels = false }
            guard !key.isEmpty else {
                deepSeekModels = Self.defaultDeepSeekModels
                return
            }
            do {
                let models = try await Self.fetchDeepSeekModelsFromAPI(apiKey: key)
                deepSeekModels = models.isEmpty ? Self.defaultDeepSeekModels : models
                if deepSeekModel.isEmpty || !deepSeekModels.contains(where: { $0.id == deepSeekModel }) {
                    deepSeekModel = deepSeekModels.first?.id ?? "deepseek-chat"
                }
            } catch {
                appendLog("Failed to fetch DeepSeek models: \(error.localizedDescription)")
                deepSeekModels = Self.defaultDeepSeekModels
            }
        }
    }

    private nonisolated static func fetchDeepSeekModelsFromAPI(apiKey: String) async throws -> [OpenAIModelInfo] {
        guard let url = URL(string: "https://api.deepseek.com/models") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsData = json["data"] as? [[String: Any]] else {
            return []
        }

        return modelsData.compactMap { model -> OpenAIModelInfo? in
            guard let id = model["id"] as? String else { return nil }
            return OpenAIModelInfo(id: id, name: id)
        }.sorted { $0.name < $1.name }
    }

    // MARK: - Hugging Face Models

    func fetchHuggingFaceModels() {
        isFetchingHuggingFaceModels = true
        let key = huggingFaceAPIKey
        Task {
            defer { isFetchingHuggingFaceModels = false }
            guard !key.isEmpty else {
                huggingFaceModels = Self.defaultHuggingFaceModels
                return
            }
            do {
                let models = try await Self.fetchHuggingFaceModelsFromAPI(apiKey: key)
                huggingFaceModels = models.isEmpty ? Self.defaultHuggingFaceModels : models
                if huggingFaceModel.isEmpty || !huggingFaceModels.contains(where: { $0.id == huggingFaceModel }) {
                    huggingFaceModel = huggingFaceModels.first?.id ?? "deepseek-ai/DeepSeek-V3-0324"
                }
            } catch {
                appendLog("Failed to fetch HF models: \(error.localizedDescription)")
                huggingFaceModels = Self.defaultHuggingFaceModels
            }
        }
    }

    private nonisolated static func fetchHuggingFaceModelsFromAPI(apiKey: String) async throws -> [OpenAIModelInfo] {
        guard let url = URL(string: "https://router.huggingface.co/v1/models") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsData = json["data"] as? [[String: Any]] else {
            return []
        }

        return modelsData.compactMap { model -> OpenAIModelInfo? in
            guard let id = model["id"] as? String else { return nil }
            return OpenAIModelInfo(id: id, name: id)
        }.sorted { $0.name < $1.name }
    }

    // MARK: - Z.ai Models

    func fetchZAIModels() {
        isFetchingZAIModels = true
        let key = zAIAPIKey
        Task {
            defer { isFetchingZAIModels = false }
            guard !key.isEmpty else {
                zAIModels = Self.defaultZAIModels
                return
            }
            do {
                let models = try await Self.fetchZAIModelsFromAPI(apiKey: key)
                zAIModels = models.isEmpty ? Self.defaultZAIModels : models
                if zAIModel.isEmpty || !zAIModels.contains(where: { $0.id == zAIModel }) {
                    zAIModel = zAIModels.first?.id ?? "glm-4-plus"
                }
            } catch {
                appendLog("Failed to fetch Z.ai models: \(error.localizedDescription)")
                zAIModels = Self.defaultZAIModels
            }
        }
    }

    private nonisolated static func fetchZAIModelsFromAPI(apiKey: String) async throws -> [OpenAIModelInfo] {
        guard let url = URL(string: "https://api.z.ai/api/coding/paas/v4/models") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        // Z.ai may return models in "data" array (OpenAI format) or top-level array
        let modelsData: [[String: Any]]
        if let data = json["data"] as? [[String: Any]] {
            modelsData = data
        } else if let models = json["models"] as? [[String: Any]] {
            modelsData = models
        } else {
            return []
        }

        return modelsData.compactMap { model -> OpenAIModelInfo? in
            guard let id = model["id"] as? String else { return nil }
            return OpenAIModelInfo(id: id, name: id)
        }.sorted { $0.name < $1.name }
    }

    // MARK: - vLLM Models

    func fetchVLLMModels() {
        isFetchingVLLMModels = true
        let endpoint = vLLMEndpoint
        let key = vLLMAPIKey
        Task {
            defer { isFetchingVLLMModels = false }
            do {
                let models = try await Self.fetchVLLMModelsFromAPI(endpoint: endpoint, apiKey: key)
                vLLMModels = models
                let ids = models.map(\.id)
                if vLLMModel.isEmpty || (!ids.isEmpty && !ids.contains(vLLMModel)) {
                    vLLMModel = ids.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch vLLM models: \(error.localizedDescription)")
            }
        }
    }

    private nonisolated static func fetchVLLMModelsFromAPI(endpoint: String, apiKey: String) async throws -> [OpenAIModelInfo] {
        // Derive /v1/models from the chat completions endpoint
        let modelsURL: URL
        if let range = endpoint.range(of: "/v1/") {
            let base = String(endpoint[endpoint.startIndex..<range.upperBound])
            guard let url = URL(string: base + "models") else { throw AgentError.invalidURL }
            modelsURL = url
        } else {
            guard let url = URL(string: endpoint) else { throw AgentError.invalidURL }
            modelsURL = url.deletingLastPathComponent().appendingPathComponent("models")
        }

        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsData = json["data"] as? [[String: Any]] else {
            return []
        }

        return modelsData.compactMap { model -> OpenAIModelInfo? in
            guard let id = model["id"] as? String else { return nil }
            return OpenAIModelInfo(id: id, name: id)
        }.sorted { $0.name < $1.name }
    }

    // MARK: - LM Studio Models

    func fetchLMStudioModels() {
        isFetchingLMStudioModels = true
        let proto = lmStudioProtocol
        // Models endpoint is always /v1/models for OpenAI/Anthropic, /api/v1/models for native
        let modelsEndpoint: String
        switch proto {
        case .lmStudio: modelsEndpoint = "http://localhost:1234/api/v1/models"
        default: modelsEndpoint = "http://localhost:1234/v1/models"
        }
        Task {
            defer { isFetchingLMStudioModels = false }
            do {
                let models = try await Self.fetchLMStudioModelsFromAPI(modelsURL: modelsEndpoint)
                lmStudioModels = models
                let ids = models.map(\.id)
                if lmStudioModel.isEmpty || (!ids.isEmpty && !ids.contains(lmStudioModel)) {
                    lmStudioModel = ids.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch LM Studio models: \(error.localizedDescription)")
            }
        }
    }

    private nonisolated static func fetchLMStudioModelsFromAPI(modelsURL: String) async throws -> [OpenAIModelInfo] {
        guard let url = URL(string: modelsURL) else { throw AgentError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsData = json["data"] as? [[String: Any]] else {
            return []
        }

        return modelsData.compactMap { model -> OpenAIModelInfo? in
            guard let id = model["id"] as? String else { return nil }
            return OpenAIModelInfo(id: id, name: id)
        }.sorted { $0.name < $1.name }
    }

    private nonisolated static func fetchModels(endpoint: String, apiKey: String) async throws -> [OllamaModelInfo] {
        let effectiveEndpoint = endpoint.isEmpty ? "http://localhost:11434/api/chat" : endpoint
        guard let chatURL = URL(string: effectiveEndpoint) else { throw AgentError.invalidResponse }
        let baseDir = chatURL.deletingLastPathComponent().absoluteString

        guard let tagsURL = URL(string: baseDir + "tags") else { throw AgentError.invalidResponse }
        guard let showURL = URL(string: baseDir + "show") else { throw AgentError.invalidResponse }

        // 1. Fetch model list
        var tagsRequest = URLRequest(url: tagsURL)
        tagsRequest.httpMethod = "GET"
        tagsRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        if !apiKey.isEmpty {
            tagsRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        tagsRequest.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: tagsRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AgentError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            throw AgentError.invalidResponse
        }

        let names = models.compactMap { $0["name"] as? String }.sorted()

        // 2. Check capabilities for each model via /api/show (in parallel)
        return await withTaskGroup(of: OllamaModelInfo?.self) { group in
            for name in names {
                group.addTask {
                    let hasVision = await Self.checkVision(model: name, showURL: showURL, apiKey: apiKey)
                    return OllamaModelInfo(id: name, name: name, supportsVision: hasVision)
                }
            }
            var results: [OllamaModelInfo] = []
            for await info in group {
                if let info { results.append(info) }
            }
            return results.sorted { $0.name < $1.name }
        }
    }

    /// Check if a model has "vision" in its capabilities via /api/show
    private nonisolated static func checkVision(model: String, showURL: URL, apiKey: String) async -> Bool {
        do {
            let body = try JSONSerialization.data(withJSONObject: ["model": model])
            var request = URLRequest(url: showURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = body
            request.timeoutInterval = llmAPITimeout

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let capabilities = json["capabilities"] as? [String] else {
                return false
            }
            return capabilities.contains("vision")
        } catch {
            return false
        }
    }
}
