import Foundation

// MARK: - Task Mode (auto tool subsetting)

/// Determines which tool groups are sent to the LLM based on task type.
/// Reduces token usage by only sending relevant tools.
enum TaskMode: String, CaseIterable {
    case coding       // file editing, git, builds
    case automation   // AppleScript, accessibility, app control
    case web          // browser automation, selenium
    case conversation // writing, messages, text transforms
    case general      // all tools (fallback)

    /// Tool groups included for this mode. Core + Shell always included.
    var groups: Set<String> {
        let base: Set<String> = ["Core"]
        switch self {
        case .coding:       return base.union(["Coding"])
        case .automation:   return base.union(["Automation", "Accessibility"])
        case .web:          return base.union(["Web"])
        case .conversation: return base
        case .general:      return ["Core", "Coding", "Automation", "Accessibility", "Web"]
        }
    }

    /// Classify a user prompt into a task mode via keyword matching.
    static func classify(_ prompt: String) -> TaskMode {
        let p = prompt.lowercased()

        let codingKeywords = ["build", "compile", "edit file", "edit_file", "read_file", "write_file",
                              "git ", "commit", "xcode", "swift", "code", "fix bug", "refactor",
                              "implement", "xcodeproj", "pbxproj", "merge", "branch", "diff",
                              "source", "function", "class ", "struct ", "enum ", "import "]
        let automationKeywords = ["applescript", "automate", "accessibility", "click", "type into",
                                  "apple event", "music", "finder", "safari tab", "sdef",
                                  "ax_", "osascript", "scripting bridge", "app control"]
        let webKeywords = ["selenium", "browser", "web page", "scrape", "navigate to",
                           "url ", "web form", "website", "webdriver", "web_"]
        let conversationKeywords = ["write about", "summarize", "translate", "fix grammar",
                                    "send message", "tell me about", "explain", "describe",
                                    "write text", "transform text", "fix text"]

        let codingScore = codingKeywords.filter { p.contains($0) }.count
        let automationScore = automationKeywords.filter { p.contains($0) }.count
        let webScore = webKeywords.filter { p.contains($0) }.count
        let conversationScore = conversationKeywords.filter { p.contains($0) }.count

        let maxScore = max(codingScore, automationScore, webScore, conversationScore)
        guard maxScore > 0 else { return .general }

        if codingScore == maxScore { return .coding }
        if automationScore == maxScore { return .automation }
        if webScore == maxScore { return .web }
        return .conversation
    }
}

/// Manages which internal tools are enabled per LLM provider.
/// Claude/Ollama: all tools on by default.
/// Apple AI: only core tools on by default (context window is too small for 40+).
@MainActor @Observable
final class ToolPreferencesService {
    static let shared = ToolPreferencesService()

    private var disabledTools: Set<String> = [] {
        didSet { persist() }
    }
    
    /// Globally disabled tool groups - applies to ALL providers
    private var disabledGroups: Set<String> = [] {
        didSet { persistGroups() }
    }

    private static let udKey = "agent.disabledTools"
    private static let udGroupsKey = "agent.disabledToolGroups"
    private static let appleAISeededKey = "agent.appleAISeeded.v2"

    /// Tool group definitions - maps group name to tool name prefixes
    static let toolGroups: [String: Set<String>] = [
        "Coding": Set(["read_file", "write_file", "edit_file", "create_diff", "apply_diff", "list_files", "search_files",
                       "git_status", "git_diff", "git_log", "git_commit", "git_diff_patch", "git_branch",
                       "xcode_build", "xcode_run", "xcode_list_projects", "xcode_select_project", "xcode_grant_permission"]),
        "Automation": Set(["apple_event_query", "run_applescript", "run_osascript", "execute_javascript", "lookup_sdef",
                          "list_agent_scripts", "read_agent_script", "create_agent_script", "update_agent_script",
                          "run_agent_script", "delete_agent_script",
                          "list_apple_scripts", "run_apple_script", "save_apple_script", "delete_apple_script",
                          "list_javascript", "run_javascript", "save_javascript", "delete_javascript"]),
        "Accessibility": Set(["ax_list_windows", "ax_get_properties", "ax_perform_action",
                              "ax_type_text", "ax_click", "ax_press_key", "ax_screenshot",
                              "ax_set_properties", "ax_find_element", "ax_get_children"]),
        "Core": Set(["task_complete", "list_native_tools", "list_mcp_tools", "load_tools", "web_search",
                    "write_text", "transform_text", "send_message", "about_self", "fix_text",
                    "execute_agent_command", "execute_daemon_command"]),
        "Web": Set(["web_open", "web_find", "web_click", "web_type", "web_execute_js", "web_get_url", "web_get_title",
                   "selenium_start", "selenium_stop", "selenium_navigate", "selenium_find", "selenium_click",
                   "selenium_type", "selenium_execute", "selenium_screenshot", "selenium_wait"]),
    ]

    /// Tools enabled by default for Apple Intelligence (small context window).
    static let appleAIDefaults: Set<String> = [
        AgentTools.Name.taskComplete, AgentTools.Name.listAgentScripts, AgentTools.Name.runAgentScript,
        AgentTools.Name.listNativeTools, AgentTools.Name.appleEventQuery,
        AgentTools.Name.runApplescript, AgentTools.Name.runOsascript
    ]

    private init() {
        let arr = UserDefaults.standard.stringArray(forKey: Self.udKey) ?? []
        disabledTools = Set(arr)
        let groupArr = UserDefaults.standard.stringArray(forKey: Self.udGroupsKey) ?? []
        disabledGroups = Set(groupArr)
        seedAppleAIDefaults()
    }

    /// On first launch, disable all Apple AI tools not in the core default set.
    private func seedAppleAIDefaults() {
        guard !UserDefaults.standard.bool(forKey: Self.appleAISeededKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.appleAISeededKey)
        let all = AgentTools.tools(for: .foundationModel).map { $0.name }
        var updated = disabledTools
        for name in all where !Self.appleAIDefaults.contains(name) {
            updated.insert(toolKey(.foundationModel, name))
        }
        disabledTools = updated  // single persist
    }

    private func persist() {
        UserDefaults.standard.set(Array(disabledTools), forKey: Self.udKey)
    }
    
    private func persistGroups() {
        UserDefaults.standard.set(Array(disabledGroups), forKey: Self.udGroupsKey)
    }

    private func toolKey(_ provider: APIProvider, _ name: String) -> String {
        "\(provider.rawValue).\(name)"
    }

    func isEnabled(_ provider: APIProvider, _ toolName: String) -> Bool {
        // First check if the tool's group is globally disabled
        for (group, tools) in Self.toolGroups {
            if tools.contains(toolName) && disabledGroups.contains(group) {
                return false
            }
        }
        // Then check per-provider setting
        return !disabledTools.contains(toolKey(provider, toolName))
    }
    
    /// Check if a group is enabled (not in disabledGroups)
    func isGroupEnabled(_ groupName: String) -> Bool {
        !disabledGroups.contains(groupName)
    }
    
    /// Toggle a group globally
    func toggleGroup(_ groupName: String) {
        if disabledGroups.contains(groupName) {
            disabledGroups.remove(groupName)
        } else {
            disabledGroups.insert(groupName)
        }
    }
    
    /// Enable all groups
    func enableAllGroups() {
        disabledGroups.removeAll()
    }
    
    /// Disable all groups
    func disableAllGroups() {
        disabledGroups = Set(Self.toolGroups.keys)
    }
    
    /// Get all group names sorted alphabetically
    static var allGroupNames: [String] {
        toolGroups.keys.sorted()
    }

    /// Check if a tool is enabled considering active task groups, global group toggles, and per-provider settings.
    func isEnabled(_ provider: APIProvider, _ toolName: String, activeGroups: Set<String>?) -> Bool {
        // If activeGroups is set, check if tool belongs to any active group
        if let activeGroups {
            let toolInActiveGroup = Self.toolGroups.contains { group, tools in
                activeGroups.contains(group) && tools.contains(toolName)
            }
            // load_tools is always available
            if !toolInActiveGroup && toolName != "load_tools" { return false }
        }
        return isEnabled(provider, toolName)
    }

    func toggle(_ provider: APIProvider, _ toolName: String) {
        let k = toolKey(provider, toolName)
        if disabledTools.contains(k) { disabledTools.remove(k) }
        else { disabledTools.insert(k) }
    }

    func enableAll(for provider: APIProvider) {
        disabledTools = disabledTools.filter { !$0.hasPrefix("\(provider.rawValue).") }
    }
}
