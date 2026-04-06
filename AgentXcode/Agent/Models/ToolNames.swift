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
    static let code = "code_tool"

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
    static let sel = "sel"

    // Memory
    static let mem = "mem"

    // Skills
    static let skill = "skill"

    // Sub-agents
    static let spawn = "spawn"

    // MARK: - Group Names

    enum Group {
        static let core = "Core"
        static let work = "Work"
        static let code = "Code"
        static let auto = "Auto"
        static let user = "User"
        static let root = "Root"
        static let exp = "Exp"
    }

    // MARK: - Mode Groups

    static let codingGroups: Set<String> = [Group.core, Group.work, Group.code, Group.user]
    static let automationGroups: Set<String> = [Group.core, Group.work, Group.auto, Group.user]
    static let allGroups: [String] = [Group.core, Group.work, Group.code, Group.auto, Group.user, Group.root, Group.exp]

    // MARK: - Legacy Aliases (old name → handler name)
    // LLM sends short name, alias resolves to the handler the app uses

    static let aliases: [String: String] = [
        // New _tool names
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
        "list_tools_tool": "list_tools",
        "sdef_tool": "lookup_sdef",
        "javascript_tool": "execute_javascript",
        // Legacy short names (still accepted)
        "user": "execute_agent_command",
        "sh": "run_shell_script",
        "root": "execute_daemon_command",
        "batch": "batch_commands",
        "multi": "batch_tools",
        "done": "task_complete",
        "search": "web_search",
        "chat": "conversation",
        "msg": "send_message",
        "plan": "plan_mode",
        "dir": "project_folder",
        "code": "coding_mode",
        "tools": "list_tools",
        "sdef": "lookup_sdef",
        "js": "execute_javascript",
        "mem": "memory",
        "skill": "invoke_skill",
        "fetch": "web_fetch",
        "ask": "ask_user_question",
        "message_agent": "send_message_to_agent",
        "spawn": "spawn_agent",
    ]
}
