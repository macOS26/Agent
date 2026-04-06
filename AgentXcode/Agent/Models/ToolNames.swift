import Foundation

/// Single source of truth for all tool names and group names.
/// Use these constants everywhere — never hardcode tool or group strings.
enum Tool {
    // MARK: - Tool Names (what the LLM calls)

    // Core
    static let done = "done_tool"
    static let tools = "list_tools_tool"
    static let search = "search_tool"
    static let folder = "directory_tool"
    static let code = "mode_tool"

    // Core (also)
    static let chat = "chat_tool"
    static let msg = "msg"

    // Work
    static let agent = "agent_script_tool"
    static let plan = "plan_tool"
    static let git = "git_tool"
    static let batch = "batch_shell_tool"
    static let multi = "multi_tool"

    // Code
    static let file = "file_tool"
    static let xc = "xcode_tool"
    static let sh = "shell_tool"

    // Auto
    static let `as` = "applescript_tool"
    static let ax = "accessibility_tool"
    static let js = "javascript_tool"
    static let sdef = "sdef_tool"

    // User / Root
    static let user = "user_shell_tool"
    static let root = "root_shell_tool"

    // Web
    static let web = "safari_tool"

    // Exp
    static let sel = "selenium_tool"

    // Memory
    static let mem = "memory"

    // Skills
    static let skill = "invoke_skill"

    // Sub-agents
    static let spawn = "spawn_agent"
    static let messageAgent = "send_message_to_agent"
    static let ask = "ask_user_question"
    static let webFetch = "web_fetch"

    // MARK: - Group Names

    enum Group {
        static let core = "Core"
        static let work = "Work"
        static let code = "Code"
        static let auto = "Auto"
        static let user = "User"
        static let root = "Root"
        static let exp = "Experimental"
    }

    // MARK: - Mode Groups

    static let codingGroups: Set<String> = [Group.core, Group.work, Group.code, Group.user]
    static let automationGroups: Set<String> = [Group.core, Group.work, Group.auto, Group.user]
    static let allGroups: [String] = [Group.core, Group.work, Group.code, Group.auto, Group.user, Group.root, Group.exp]

    // MARK: - Legacy Aliases (old name → handler name)
    // LLM sends short name, alias resolves to the handler the app uses

    static let aliases: [String: String] = [
        // _tool suffixed (LLM-facing canonical names)
        "user_shell_tool": "execute_agent_command",
        "shell_tool": "run_shell_script",
        "root_shell_tool": "execute_daemon_command",
        "batch_shell_tool": "batch_commands",
        "multi_tool": "batch_tools",
        "done_tool": "task_complete",
        "search_tool": "web_search",
        "chat_tool": "conversation",
        "plan_tool": "plan_mode",
        "directory_tool": "project_folder",
        "code_tool": "coding_mode",
        "mode_tool": "coding_mode",
        "list_tools_tool": "list_tools",
        "sdef_tool": "lookup_sdef",
        "javascript_tool": "execute_javascript",
        // Bare names (drop _tool suffix) — used in condensed prompt
        "user_shell": "execute_agent_command",
        "root_shell": "execute_daemon_command",
        "batch_shell": "batch_commands",
        "shell": "run_shell_script",
        "done": "task_complete",
        "search": "web_search",
        "chat": "conversation",
        "plan": "plan_mode",
        "directory": "project_folder",
        "mode": "coding_mode",
        "list_tools": "list_tools",
        "sdef": "lookup_sdef",
        "javascript": "execute_javascript",
        "memory": "memory",
        "skill_tool": "invoke_skill",
        "skill": "invoke_skill",
        "web_fetch_tool": "web_fetch",
        "fetch": "web_fetch",
        "ask_tool": "ask_user_question",
        "ask": "ask_user_question",
        "spawn_agent_tool": "spawn_agent",
        "spawn": "spawn_agent",
        "send_message_tool": "send_message_to_agent",
        "message_agent": "send_message_to_agent",
        // Legacy short names (still accepted)
        "user": "execute_agent_command",
        "sh": "run_shell_script",
        "root": "execute_daemon_command",
        "batch": "batch_commands",
        "multi": "batch_tools",
        "msg": "send_message",
        "dir": "project_folder",
        "code": "coding_mode",
        "tools": "list_tools",
        "js": "execute_javascript",
        "mem": "memory",
    ]
}
