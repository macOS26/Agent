import Foundation

/// Single source of truth for all tool names and group names.
/// Use these constants everywhere — never hardcode tool or group strings.
enum Tool {
    // MARK: - Tool Names (what the LLM calls)

    // Core
    static let done = "done"
    static let tools = "tools"
    static let search = "search"
    static let folder = "dir"
    static let code = "code"

    // Core (also)
    static let chat = "chat"
    static let msg = "msg"

    // Work
    static let agent = "agent"
    static let plan = "plan"
    static let git = "git"
    static let batch = "batch"
    static let multi = "multi"

    // Code
    static let file = "file"
    static let xc = "xc"
    static let sh = "sh"

    // Auto
    static let `as` = "as"
    static let ax = "ax"
    static let js = "js"
    static let sdef = "sdef"

    // User / Root
    static let user = "user"
    static let root = "root"

    // Web
    static let web = "web"

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
        "spawn": "spawn_agent",
    ]
}
