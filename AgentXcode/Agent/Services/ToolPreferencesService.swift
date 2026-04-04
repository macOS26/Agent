import Foundation
import AgentTools

// MARK: - Task Mode (auto tool subsetting)

/// Determines which tool groups are sent to the LLM based on task type.
/// Reduces token usage by only sending relevant tools.
// TaskMode removed — all tool groups always available, user controls via UI toggles.

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
        "Code": Set(["xc", "xcode", "file", "file_manager", "folder", "project_folder", "code", "coding_mode", "sh", "run_shell_script"]),
        "Auto": Set(["as", "applescript_tool", "ax", "accessibility", "jxa", "javascript_tool", "sdef", "lookup_sdef"]),
        "Exp": Set(["sel", "selenium", "ax_screenshot"]),
        "Core": Set(["done", "task_complete", "tools", "list_tools", "search", "web_search"]),
        "Chat": Set(["chat", "conversation"]),
        "Work": Set(["agent", "plan", "plan_mode", "git", "msg", "send_message", "batch", "batch_commands", "multi", "batch_tools"]),
        "User": Set(["user", "execute_agent_command"]),
        "Root": Set(["root", "execute_daemon_command"]),
        "Web": Set(["web"]),
    ]

    /// Tools enabled by default for Apple Intelligence (small context window).
    static let appleAIDefaults: Set<String> = [
        AgentTools.Name.executeAgentCommand, AgentTools.Name.fileManager,
        AgentTools.Name.agentScript, AgentTools.Name.taskComplete
    ]

    private static let groupSeededKey = "agent.groupsSeeded.v2"

    private init() {
        let arr = UserDefaults.standard.stringArray(forKey: Self.udKey) ?? []
        disabledTools = Set(arr)
        let groupArr = UserDefaults.standard.stringArray(forKey: Self.udGroupsKey) ?? []
        disabledGroups = Set(groupArr)
        seedDefaultDisabledGroups()
        seedAppleAIDefaults()
    }

    /// On first launch, disable Accessibility and Web groups by default.
    private func seedDefaultDisabledGroups() {
        guard !UserDefaults.standard.bool(forKey: Self.groupSeededKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.groupSeededKey)
        disabledGroups.insert(Tool.Group.exp)
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
            if !toolInActiveGroup { return false }
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
