import Foundation

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
        "Coding": Set(["read_file", "write_file", "edit_file", "create_diff", "apply_diff", "list_files", "search_files"]),
        "Git": Set(["git_status", "git_diff", "git_log", "git_commit", "git_diff_patch", "git_branch"]),
        "Automation": Set(["apple_event_query", "run_applescript", "run_osascript", "execute_javascript"]),
        "Shell": Set(["execute_agent_command", "execute_daemon_command"]),
        "Accessibility": Set(["ax_list_windows", "ax_inspect_element", "ax_get_properties", "ax_perform_action",
                              "ax_check_permission", "ax_request_permission", "ax_type_text", "ax_click",
                              "ax_scroll", "ax_press_key", "ax_screenshot", "ax_get_audit_log",
                              "ax_set_properties", "ax_find_element", "ax_get_focused_element", "ax_get_children",
                              "ax_drag", "ax_wait_for_element", "ax_show_menu", "ax_click_element",
                              "ax_wait_adaptive", "ax_type_into_element", "ax_highlight_element", "ax_get_window_frame"]),
        "Scripts": Set(["list_agent_scripts", "read_agent_script", "create_agent_script", "update_agent_script",
                        "run_agent_script", "delete_agent_script"]),
        "SDEF": Set(["lookup_sdef"]),
        "Xcode": Set(["xcode_build", "xcode_run", "xcode_list_projects", "xcode_select_project", "xcode_grant_permission"]),
        "AppleScript": Set(["list_apple_scripts", "run_apple_script", "save_apple_script", "delete_apple_script"]),
        "JavaScript": Set(["list_javascript", "run_javascript", "save_javascript", "delete_javascript"]),
        "Core": Set(["task_complete", "list_native_tools", "list_mcp_tools"]),
        "Web": Set(["web_open", "web_find", "web_click", "web_type", "web_execute_js", "web_get_url", "web_get_title"]),
        "Selenium": Set(["selenium_start", "selenium_stop", "selenium_navigate", "selenium_find", "selenium_click",
                         "selenium_type", "selenium_execute", "selenium_screenshot", "selenium_wait"]),
        "Web Search": Set(["web_search"]),
        "Conversation": Set(["write_text", "transform_text", "send_message", "about_self", "fix_text"])
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

    func toggle(_ provider: APIProvider, _ toolName: String) {
        let k = toolKey(provider, toolName)
        if disabledTools.contains(k) { disabledTools.remove(k) }
        else { disabledTools.insert(k) }
    }

    func enableAll(for provider: APIProvider) {
        disabledTools = disabledTools.filter { !$0.hasPrefix("\(provider.rawValue).") }
    }
}
