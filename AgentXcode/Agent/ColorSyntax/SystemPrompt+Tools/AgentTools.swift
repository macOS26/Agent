import Foundation

/// Shared system prompt and tool definitions for all LLM providers.
/// ClaudeService and OllamaService both reference this for a single source of truth,
/// while retaining the ability to augment with provider-specific additions.
enum AgentTools {

    // MARK: - Tool Name Constants (single source of truth)
    enum Name {
        // File Manager (consolidated CRUDL)
        static let fileManager = "file_manager"
        // Git (consolidated CRUDL)
        static let git = "git"
        // Legacy git names (handlers still work)
        static let gitStatus = "git_status"
        static let gitDiff = "git_diff"
        static let gitLog = "git_log"
        static let gitCommit = "git_commit"
        static let gitDiffPatch = "git_diff_patch"
        static let gitBranch = "git_branch"
        // Core Scripting
        static let appleEventQuery = "apple_event_query"
        static let runApplescript = "run_applescript"
        static let runOsascript = "run_osascript"
        static let executeJavascript = "execute_javascript"
        // Shell Execution
        static let executeAgentCommand = "execute_agent_command"
        static let executeDaemonCommand = "execute_daemon_command"
        static let batchCommands = "batch_commands"
        static let batchTools = "batch_tools"
        static let runShellScript = "run_shell_script"
        // Task
        static let taskComplete = "task_complete"
        // Accessibility (consolidated)
        static let accessibility = "accessibility"
        // Legacy ax names (handlers still work)
        static let axListWindows = "ax_list_windows"
        static let axInspectElement = "ax_inspect_element"
        static let axGetProperties = "ax_get_properties"
        static let axPerformAction = "ax_perform_action"
        static let axCheckPermission = "ax_check_permission"
        static let axRequestPermission = "ax_request_permission"
        static let axTypeText = "ax_type_text"
        static let axClick = "ax_click"
        static let axScroll = "ax_scroll"
        static let axPressKey = "ax_press_key"
        static let axScreenshot = "ax_screenshot"
        static let axGetAuditLog = "ax_get_audit_log"
        static let axSetProperties = "ax_set_properties"
        static let axFindElement = "ax_find_element"
        static let axGetFocusedElement = "ax_get_focused_element"
        static let axGetChildren = "ax_get_children"
        static let axDrag = "ax_drag"
        static let axWaitForElement = "ax_wait_for_element"
        static let axShowMenu = "ax_show_menu"
        static let axClickElement = "ax_click_element"
        static let axWaitAdaptive = "ax_wait_adaptive"
        static let axTypeIntoElement = "ax_type_into_element"
        static let axHighlightElement = "ax_highlight_element"
        static let axGetWindowFrame = "ax_get_window_frame"
        static let axClickMenuItem = "ax_click_menu_item"
        static let axSetWindowFrame = "ax_set_window_frame"
        static let axManageApp = "ax_manage_app"
        static let axScrollToElement = "ax_scroll_to_element"
        static let axReadFocused = "ax_read_focused"
        // Agent Script (consolidated CRUDL)
        static let agentScript = "agent"
        // Agent action names (expanded from consolidated "agent" tool)
        static let listAgentScripts = "list_agents"
        static let readAgentScript = "read_agent"
        static let createAgentScript = "create_agent"
        static let updateAgentScript = "update_agent"
        static let runAgentScript = "run_agent"
        static let deleteAgentScript = "delete_agent"
        static let combineAgentScripts = "combine_agents"
        // SDEF
        static let lookupSdef = "lookup_sdef"
        // Xcode (consolidated CRUDL)
        static let xcode = "xcode"
        // Legacy xcode names (handlers still work)
        static let xcodeBuild = "xcode_build"
        static let xcodeRun = "xcode_run"
        static let xcodeListProjects = "xcode_list_projects"
        static let xcodeSelectProject = "xcode_select_project"
        static let xcodeGrantPermission = "xcode_grant_permission"
        // AppleScript (consolidated CRUDL)
        static let appleScriptTool = "applescript_tool"
        // Legacy AppleScript names (handlers still work)
        static let listAppleScripts = "list_apple_scripts"
        static let runAppleScript = "run_apple_script"
        static let saveAppleScript = "save_apple_script"
        static let deleteAppleScript = "delete_apple_script"
        // JavaScript (consolidated CRUDL)
        static let javascriptTool = "javascript_tool"
        // Legacy JavaScript names (handlers still work)
        static let listJavascript = "list_javascript"
        static let runJavascript = "run_javascript"
        static let saveJavascript = "save_javascript"
        static let deleteJavascript = "delete_javascript"
        // Tool Discovery
        static let listNativeTools = "list_tools"
// Safari (consolidated web automation)
        static let safari = "web"
        // Legacy web_ names (handlers still work)
        static let safariOpen = "web_open"
        static let safariFind = "web_find"
        static let safariClick = "web_click"
        static let safariType = "web_type"
        static let safariExecuteJs = "web_execute_js"
        static let safariGetUrl = "web_get_url"
        static let safariGetTitle = "web_get_title"
        static let safariGoogleSearch = "web_google_search"
        static let safariReadContent = "web_read_content"
        static let safariScrollTo = "web_scroll_to"
        static let safariSelect = "web_select"
        static let safariSubmit = "web_submit"
        static let safariNavigate = "web_navigate"
        static let safariListTabs = "web_list_tabs"
        static let safariSwitchTab = "web_switch_tab"
        static let safariListWindows = "web_list_windows"
        static let webSwitchWindow = "web_switch_window"
        static let webNewWindow = "web_new_window"
        static let webCloseWindow = "web_close_window"
        static let webWaitForElement = "web_wait_for_element"
        // Selenium (consolidated CRUDL)
        static let seleniumTool = "selenium"
        // Legacy selenium names (handlers still work)
        static let seleniumStart = "selenium_start"
        static let seleniumStop = "selenium_stop"
        static let seleniumNavigate = "selenium_navigate"
        static let seleniumFind = "selenium_find"
        static let seleniumClick = "selenium_click"
        static let seleniumType = "selenium_type"
        static let seleniumExecute = "selenium_execute"
        static let seleniumScreenshot = "selenium_screenshot"
        static let seleniumWait = "selenium_wait"
        // Ollama-only
        static let webSearch = "web_search"
        // Conversation Tools
        static let writeText = "write_text"
        static let transformText = "transform_text"
        static let sendMessage = "send_message"
        static let aboutSelf = "about_self"
        static let fixText = "fix_text"
        static let planMode = "plan_mode"
    }

    // MARK: - Full LLM System Prompt (Desktop: Claude, Ollama, OpenAI, etc.)
    static func systemPrompt(userName: String, userHome: String, projectFolder: String = "") -> String {
        let folder = projectFolder.isEmpty ? userHome : projectFolder
        let shell = AppConstants.shellPath.components(separatedBy: "/").last ?? "zsh"
        return """
        You are an autonomous macOS agent. User: "\(userName)", home: "\(userHome)". Project: \(folder). Shell: \(shell).
        ALWAYS call task_complete when finished — no exceptions. If you need user input, put the question in the summary AND call task_complete. NEVER output text without calling task_complete. Don't ask — just act.
        When the user asks to list or show something, display the full output — don't summarize or categorize it.
        NEVER output code as text — use write_file/edit_file for files, agent (action: create/update) for scripts.
        For conversation (greetings, questions, thanks, explanations) reply with plain text AND call task_complete. Every response MUST end with task_complete — no exceptions.

        DIRECT TOOLS (no action parameter): task_complete, execute_agent_command, execute_daemon_command, run_shell_script, batch_commands, batch_tools, apple_event_query.
        - run_shell_script: alias for execute_agent_command with automatic fallback to in-process when User Agent is off.
        - BATCH COMMANDS: Use batch_commands to run multiple shell commands in one call (newline-separated). Avoids round-trips. Ideal for gathering info (ls, cat, grep, find, git).
        - BATCH TOOLS: Use batch_tools to run multiple tool calls in one batch. Provide a description and an array of {tool, input} tasks. Each task runs sequentially with progress tracking. Avoids LLM round-trips for multi-step operations like reading several files or combining file reads with searches.
        ACTION TOOLS (require "action" parameter):
        file_manager: read, write, edit, list, search, read_dir, create, apply, undo, diff_apply, if_to_switch, extract_function | git: status, diff, log, commit, diff_patch, branch
        xcode: build, run, list_projects, select_project, add_file, remove_file, analyze, snippet | agent: list, read, create, update, run, delete, combine
        plan_mode: create, update, read, list, delete | applescript_tool: execute, lookup_sdef, list, run, save, delete
        javascript_tool: execute, list, run, save, delete
        accessibility: list_windows, get_properties, perform_action, type_text, click, press_key, set_properties, find_element, get_children, click_element, type_into_element, wait_adaptive, show_menu, drag, highlight_element, get_window_frame, click_menu_item, set_window_frame, manage_app, scroll_to_element, read_focused
        web: search, google_search, open, find, click, type, execute_js, get_url, get_title, read_content, scroll_to, select, submit, navigate, list_tabs, switch_tab, list_windows, new_window, close_window

        GUIDELINES:
        - All tools are available. Choose the best tool for the job — no restrictions on which tools you can use.
        - PREFER BUILT-IN TOOLS over MCP tools. Use file_manager for file operations (read/write/edit/list/search), git for version control, xcode for builds. Only use MCP tools (mcp_*) when a built-in tool cannot do the job.
        - NEVER GUESS FILE PATHS. Always use file_manager(action:"list") or execute_agent_command("find . -name '*.swift'") first to discover actual file paths before reading files.
        - SAFARI: Prefer Safari's JavaScript via AppleScript for web automation instead of accessibility or web tools: `tell application "Safari" to do JavaScript "..." in document 1`. Faster, more reliable, and can read/modify page content directly. Requires "Allow JavaScript from Apple Events" in Safari > Settings > Developer. If it fails with "not allowed", tell the user: Safari > Settings > Developer > check "Allow JavaScript from Apple Events".
        - WEB PAGES: web tool workflow: 1) open 2) scan to discover selectors 3) type/click/read_content as needed.
        - SHELL: execute_agent_command for shell commands. Shell scripts (.sh) are fine — use file_manager (action: write) to create, execute_agent_command to run.
        - BUILD: Always use xcode (action: build) to build Xcode projects. Do NOT use xcodebuild via shell.
        - CODE REVIEW: For Swift 5/6 Xcode projects, ALWAYS use xcode (action: analyze) and xcode (action: snippet) for code reviews. analyze runs comprehensive Swift static analysis (syntax, style, safety, performance, best practices) and returns actionable findings. snippet extracts code by line range for targeted review. These are highly recommended — use them before suggesting changes to Swift files.
        - CONVERSATION: For greetings, questions, thanks, or chat, reply with plain text and call task_complete.
        - Direct commands like "list agents", "run agent X" are immediate — execute directly without planning.
        - PLAN MODE: For tasks with 3+ steps, create a plan first then execute it. Usage:
          1. Create: plan_mode(action:"create", name:"my-plan", steps:["Step 1 description","Step 2 description"])
          2. Read: plan_mode(action:"read", name:"my-plan") — shows current plan with status
          3. Update: plan_mode(action:"update", name:"my-plan", step_index:0, status:"completed")
          4. List: plan_mode(action:"list") — shows all plans
          5. Delete: plan_mode(action:"delete", name:"my-plan")
          Plan names must be simple slugs (letters, numbers, hyphens). Execute every step.

        EDITING FILES (use file_manager):
        - file_manager (action: edit): replace exact text (old_string → new_string). Best for small, single-location changes.
        - file_manager (action: diff_apply): edit a section by line range. Provide file_path, start_line, end_line, and destination text. Reads file from disk, applies, shows preview. Best for multi-line edits.
        - file_manager (action: create + apply): two-step review workflow. create previews changes, apply commits them.
        CRITICAL: After ANY diff apply, line numbers shift. You MUST re-read the file before making another edit. Only one edit per tool call — never batch multiple diffs on the same file.

        SPLITTING FILES — follow this exact sequence for EACH new file:
        1. file_manager (action: read) the source file you will extract from
        2. file_manager (action: write) to create the new file with imports + extracted code
        3. xcode (action: add_file) to add it to the project
        4. file_manager (action: edit) to remove the extracted code from the original file (old_string must match the file EXACTLY — copy from the read output, never from memory)
        5. xcode (action: build) to verify it compiles
        6. Mark plan step completed ONLY if build succeeds
        Do ONE file at a time. Build between EVERY file. Never batch multiple files before building.

        CONVERSATION TOOLS (no action parameter):
        - write_text: Generate prose on any subject. Params: subject (required), style (default: informative), length (short/medium/long or word count), context (optional).
        - transform_text: Restructure text into a formatted output. Params: text (required), transform (required: grocery_list, todo_list, outline, summary, bullet_points, numbered_list, table, qa), options (optional).
        - fix_text: Correct spelling and grammar. - send_message: Send content via iMessage, email, or SMS. - about_self: Describe Agent's capabilities.

        TCC (in-process): agent_script (run), applescript_tool (execute), accessibility. NO TCC: execute_agent_command, execute_daemon_command.
        LAUNCH DAEMON: execute_daemon_command runs as root — use it for system troubleshooting: reading system logs (log show, /var/log), disk diagnostics (diskutil, fsck, df), network debugging (lsof -i, netstat, pfctl), process inspection (ps aux, lsof), launchd service management (launchctl), hardware info (system_profiler), firewall config, and any diagnostics requiring elevated privileges. Try execute_agent_command first; escalate to execute_daemon_command when permission is denied or root access is needed.
        AGENT SCRIPTS: ~/Documents/AgentScript/agents/. 100% Swift dylibs loaded at runtime.
        Entry point: @_cdecl("script_main") public func scriptMain() -> Int32 { return 0 }
        Arguments via: ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"]
        Full Swift capabilities: Process() for shell, NSAppleScript, ScriptingBridge (Finder/Music/etc), Foundation, CoreGraphics, AVFoundation, Security — anything Swift can do, Agents can do. Write COMPLETE scripts — never leave stubs or TODOs. Return 0 on success, non-zero on failure.
        """
    }

    // MARK: - Tool List per Provider (for ToolsView)

    /// Returns the tools available for a given provider.
    /// Web search via Tavily is now available for all providers as a backup search option.
    /// Conversation tools for natural language tasks are also included.
    static func tools(for provider: APIProvider) -> [ToolDef] {
        // All providers get web_search and conversation tools
        return commonTools + webSearchTools + conversationTools
    }
//TOOLS:
//\(enabledAppleAIToolLines())
    //\(Name.executeAgentCommand) {"command": "ls -la"}
    //\(Name.runApplescript) {"source": "tell app \\"Finder\\" to get name of home"}
    //\(Name.runOsascript) {"script": "display dialog \\"Hello\\""}
    //\(Name.taskComplete) {"summary": "Done"}
    
    // MARK: - Lite System Prompt (Apple Intelligence — small context window)
    @MainActor static func compactSystemPrompt(userName: String, userHome: String, projectFolder: String = "") -> String {
        let folder = projectFolder.isEmpty ? userHome : projectFolder
        let n = Name.self
        return """
        macOS agent for \(userName). Project: \(folder). ALWAYS call \(n.taskComplete) when finished. If you need user input, put the question in the summary AND call \(n.taskComplete). Every response MUST end with \(n.taskComplete).
        TOOLS: \(n.fileManager) (action: read/write/edit/list/search), \(n.executeAgentCommand), \(n.agentScript) (list/read/create/update/run).
        Shell: \(n.executeAgentCommand) for rm/mv/cp/ls/grep. Don't repeat stdout.
        """
    }

    /// Concrete examples for each tool.
    private static let toolExamples: [String: String] = [
        Name.executeAgentCommand:  #"execute_agent_command {"command": "ls -la"}"#,
        Name.executeDaemonCommand: #"execute_daemon_command {"command": "whoami"}"#,
        Name.batchCommands:        #"batch_commands {"commands": "ls -la\ncat README.md\ngit status"}"#,
        Name.batchTools:           #"batch_tools {"description": "Read project files", "tasks": [{"tool": "file_manager", "input": {"action": "read", "file_path": "/path/a.swift"}}, {"tool": "file_manager", "input": {"action": "search", "pattern": "TODO", "path": "/path"}}]}"#,
        Name.runShellScript:       #"run_shell_script {"command": "ls -la"}"#,
        Name.runApplescript:       #"run_applescript {"source": "tell application \"Finder\" to get name of home"}"#,
        Name.runOsascript:         #"run_osascript {"script": "display dialog \"Hello\""}"#,
        Name.executeJavascript:    #"execute_javascript {"source": "var app = Application.currentApplication(); app.includeStandardAdditions = true; app.displayDialog('Hello')"}"#,
        Name.fileManager:          #"file_manager {"action": "read", "file_path": "/Users/toddbruss/Documents/example.txt"}"#,
        Name.taskComplete:         #"task_complete {"summary": "Done"}"#,
        Name.git:                  #"git {"action": "status", "path": "/Users/toddbruss/Documents/GitHub/MyRepo"}"#,
        Name.appleEventQuery:      #"apple_event_query {"bundle_id": "com.apple.Music", "action": "get", "key": "currentTrack"}"#,
        Name.agentScript:          #"agent {"action": "run", "name": "MyScript"}"#,
        Name.lookupSdef:           #"lookup_sdef {"bundle_id": "com.apple.Music"}"#,
        Name.xcode:                #"xcode {"action": "build"}"#,
        Name.accessibility:        #"accessibility {"action": "list_windows"}"#,
        Name.safari:               #"web {"action": "open", "url": "https://example.com"}"#,
        Name.appleScriptTool:      #"applescript_tool {"action": "execute", "source": "display dialog \"Hello\""}"#,
        Name.javascriptTool:       #"javascript_tool {"action": "execute", "source": "var app = Application.currentApplication(); app.displayDialog('Hello')"}"#,
        Name.webSearch:            #"web_search {"query": "latest Swift news"}"#,
        // Conversation Tools
        Name.writeText:            #"write_text {"subject": "machine learning", "style": "informative", "length": "medium"}"#,
        Name.transformText:        #"transform_text {"text": "buy milk, eggs, bread", "transform": "grocery_list"}"#,
        Name.sendMessage:          #"send_message {"content": "Hello!", "recipient": "me", "channel": "imessage"}"#,
        Name.aboutSelf:            "about_self",
        Name.fixText:              #"fix_text {"text": "this has spellng erors", "fixes": "all"}"#,
    ]

    @MainActor private static func enabledAppleAIToolLines() -> String {
        let prefs = ToolPreferencesService.shared
        return commonTools
            .filter { prefs.isEnabled(.foundationModel, $0.name) }
            .map { tool in toolExamples[tool.name] ?? "\(tool.name) {}" }
            .joined(separator: "\n")
    }

    // MARK: - Tool Definitions (internal, format-neutral)

    struct ToolDef {
        let name: String
        let description: String
        let properties: [String: [String: Any]]
        let required: [String]
    }

    nonisolated(unsafe) private static let commonTools: [ToolDef] = [
        // --- File Manager (consolidated) ---
        ToolDef(
            name: Name.fileManager,
            description: "File operations and refactoring. Actions: read, write, edit, create (diff), apply (diff), undo, diff_apply, list, search, read_dir, if_to_switch, extract_function.",
            properties: [
                "action": ["type": "string", "description": "Action: read, write, edit, create, apply, undo, diff_apply, list, search, read_dir, if_to_switch, or extract_function"],
                "file_path": ["type": "string", "description": "File path (for read/write/edit/apply/undo/diff_apply)"],
                "path": ["type": "string", "description": "Directory path (for list/search/read_dir)"],
                "content": ["type": "string", "description": "For write: file content"],
                "old_string": ["type": "string", "description": "For edit: text to find"],
                "new_string": ["type": "string", "description": "For edit: replacement text"],
                "replace_all": ["type": "boolean", "description": "For edit: replace all (default false)"],
                "context": ["type": "string", "description": "For edit: surrounding lines to disambiguate multiple matches"],
                "source": ["type": "string", "description": "For create/diff_apply: original text (omit to read from file_path)"],
                "destination": ["type": "string", "description": "For create/diff_apply: the modified text"],
                "start_line": ["type": "integer", "description": "For create: 1-based start line for section editing"],
                "end_line": ["type": "integer", "description": "For create: 1-based end line for section editing"],
                "diff_id": ["type": "string", "description": "For apply: UUID from create"],
                "diff": ["type": "string", "description": "For apply: inline diff with =/-/+ prefixes"],
                "offset": ["type": "integer", "description": "For read: start line (default 1)"],
                "limit": ["type": "integer", "description": "For read: max lines (default 2000)"],
                "pattern": ["type": "string", "description": "For list: glob. For search: regex"],
                "include": ["type": "string", "description": "For search: file filter (e.g. *.swift)"],
                "function_name": ["type": "string", "description": "For extract_function: name of function to extract"],
                "new_file": ["type": "string", "description": "For extract_function: destination filename"],
            ],
            required: ["action"]
        ),
        // --- Git (consolidated) ---
        ToolDef(
            name: Name.git,
            description: "Git operations. Actions: status (branch/changes), diff (show changes), log (commit history), commit (stage+commit), diff_patch (apply patch), branch (create branch).",
            properties: [
                "action": ["type": "string", "description": "Action: status, diff, log, commit, diff_patch, or branch"],
                "path": ["type": "string", "description": "Repository path (REQUIRED)"],
                "staged": ["type": "boolean", "description": "For diff: staged changes only"],
                "target": ["type": "string", "description": "For diff: branch/commit to diff against"],
                "count": ["type": "integer", "description": "For log: number of commits (default 20)"],
                "message": ["type": "string", "description": "For commit: commit message"],
                "files": ["type": "array", "items": ["type": "string"] as [String: Any], "description": "For commit: specific files to stage"] as [String: Any],
                "patch": ["type": "string", "description": "For diff_patch: unified diff content"],
                "name": ["type": "string", "description": "For branch: branch name"],
                "checkout": ["type": "boolean", "description": "For branch: switch to new branch (default true)"],
            ],
            required: ["action"]
        ),
        // --- Xcode (consolidated) ---
        ToolDef(
            name: Name.xcode,
            description: "Xcode operations. Actions: build, run, list_projects, select_project, add_file, remove_file, grant_permission, analyze, snippet, code_review. code_review auto-discovers Swift files, creates a plan, analyzes each file, and produces a summary.",
            properties: [
                "action": ["type": "string", "description": "Action: build, run, list_projects, select_project, add_file, remove_file, grant_permission, analyze, snippet, or code_review"],
                "project_path": ["type": "string", "description": "For build/run: path (auto-detected if empty)"],
                "file_path": ["type": "string", "description": "For add_file/remove_file/analyze/snippet: path to source file"],
                "number": ["type": "integer", "description": "For select_project: project number (1-based)"],
                "start_line": ["type": "integer", "description": "For analyze/snippet: start line number"],
                "end_line": ["type": "integer", "description": "For analyze/snippet: end line number"],
                "checks": ["type": "string", "description": "For analyze: check groups (all, syntax, style, safety, performance, bestPractices)"],
            ],
            required: ["action"]
        ),
        // --- Coding: Shell ---
        ToolDef(
            name: Name.executeAgentCommand,
            description: "Execute a shell command as the current user (no root). NO TCC permissions. Use for git, builds, file ops, homebrew, etc.",
            properties: [
                "command": ["type": "string", "description": "The bash command to execute as the current user"],
            ],
            required: ["command"]
        ),
        ToolDef(
            name: Name.executeDaemonCommand,
            description: "Execute a shell command with ROOT privileges via the privileged daemon. NO TCC. Use for: troubleshooting (system logs, disk health, network diagnostics, process inspection, launchd services), system packages, /System or /Library modifications, disk operations, and any task requiring elevated privileges.",
            properties: [
                "command": ["type": "string", "description": "The bash command to execute as root"],
            ],
            required: ["command"]
        ),
        ToolDef(
            name: Name.runShellScript,
            description: "Run a shell command or script. Uses the User Agent XPC when available, falls back to in-process execution. Alias for execute_agent_command with automatic fallback.",
            properties: [
                "command": ["type": "string", "description": "The bash command or shell script to execute"],
            ],
            required: ["command"]
        ),
        ToolDef(
            name: Name.batchCommands,
            description: "Run multiple shell commands sequentially in one call. Returns all results without LLM round-trips. Use for information gathering (ls, cat, grep, find, git log, etc.) when you need to run several commands in a row.",
            properties: [
                "commands": ["type": "string", "description": "Commands separated by newlines. Each runs sequentially as the current user."],
            ],
            required: ["commands"]
        ),
        ToolDef(
            name: Name.batchTools,
            description: "Run multiple tool calls sequentially in one batch. Shows progress as a mini task list. Avoids LLM round-trips for multi-step operations like reading several files, combining reads with searches, or gathering info from different tools.",
            properties: [
                "description": ["type": "string", "description": "Brief description of this batch (shown as header in task list)"],
                "tasks": ["type": "array", "description": "Array of tool calls. Each: {\"tool\": \"tool_name\", \"input\": {param: value}}", "items": ["type": "object"] as [String: Any]] as [String: Any],
            ],
            required: ["description", "tasks"]
        ),
        ToolDef(
            name: Name.taskComplete,
            description: "Signal that the task has been completed. Always call this when done.",
            properties: [
                "summary": ["type": "string", "description": "Brief summary of what was accomplished"],
            ],
            required: ["summary"]
        ),
        // --- Agent Scripts (reusable Swift scripts) ---
        // --- Agent Scripts (consolidated) ---
        ToolDef(
            name: Name.agentScript,
            description: "Swift automation scripts. 100% Swift — ScriptingBridge only for apps with AppleScript dictionaries. Actions: list, read, create, update, run (compile+execute with TCC), delete, combine (merge two scripts).",
            properties: [
                "action": ["type": "string", "description": "Action: list, read, create, update, run, delete, or combine"],
                "name": ["type": "string", "description": "Script name (for read/create/update/run/delete)"],
                "content": ["type": "string", "description": "Swift source code (for create/update)"],
                "arguments": ["type": "string", "description": "For run: string passed via AGENT_SCRIPT_ARGS env var"],
                "source_a": ["type": "string", "description": "For combine: first script name"],
                "source_b": ["type": "string", "description": "For combine: second script name"],
                "target": ["type": "string", "description": "For combine: output script name"],
            ],
            required: ["action"]
        ),
        // --- Inline AppleScript/JXA execution now via applescript_tool/javascript_tool execute action ---
        // --- Automation: Apple Events ---
        ToolDef(
            name: Name.appleEventQuery,
            description: "Query a scriptable Mac app via ObjC dispatch. Flat keys, one operation per call. Use lookup_sdef first.",
            properties: [
                "bundle_id": ["type": "string", "description": "App bundle identifier (e.g. com.apple.Music)"],
                "action": ["type": "string", "description": "One of: get, iterate, index, call, filter"],
                "key": ["type": "string", "description": "Property key for 'get' action"],
                "properties": ["type": "string", "description": "Comma-separated property names for 'iterate' (e.g. \"name,artist,album\")"],
                "limit": ["type": "integer", "description": "Max items for 'iterate' (default 50)"],
                "index": ["type": "integer", "description": "Array index for 'index' action"],
                "method": ["type": "string", "description": "Method name for 'call' action"],
                "arg": ["type": "string", "description": "Argument for 'call' action"],
                "predicate": ["type": "string", "description": "NSPredicate format string for 'filter' action"],
            ],
            required: ["bundle_id", "action"]
        ),
        // --- AppleScript (consolidated) ---
        ToolDef(
            name: Name.appleScriptTool,
            description: "AppleScript tool with full TCC. Actions: execute (run inline source via NSAppleScript), lookup_sdef (read app's scripting dictionary — use before writing AppleScript), list (saved scripts), run (saved by name), save, delete.",
            properties: [
                "action": ["type": "string", "description": "Action: execute, lookup_sdef, list, run, save, or delete"],
                "name": ["type": "string", "description": "Script name (for run/save/delete)"],
                "source": ["type": "string", "description": "AppleScript source code (for execute/save)"],
                "bundle_id": ["type": "string", "description": "For lookup_sdef: app bundle ID (e.g. com.apple.Music). Use 'list' to see all SDEFs."],
                "class_name": ["type": "string", "description": "For lookup_sdef: specific class to inspect (e.g. 'track')"],
            ],
            required: ["action"]
        ),
        // --- JavaScript/JXA (consolidated) ---
        ToolDef(
            name: Name.javascriptTool,
            description: "JavaScript for Automation (JXA) tool. Actions: execute (run inline JXA source), list (saved scripts), run (saved by name), save, delete.",
            properties: [
                "action": ["type": "string", "description": "Action: execute, list, run, save, or delete"],
                "name": ["type": "string", "description": "Script name (for run/save/delete)"],
                "source": ["type": "string", "description": "JXA source code (for execute/save)"],
            ],
            required: ["action"]
        ),
        // --- Accessibility (consolidated) ---
        ToolDef(
            name: Name.accessibility,
            description: "macOS Accessibility API. Actions: list_windows, get_properties, perform_action, type_text, click, press_key, screenshot, set_properties, find_element, get_children, check_permission, request_permission. Use same role/title/value across calls to target same element.",
            properties: [
                "action": ["type": "string", "description": "Action: list_windows, get_properties, perform_action, type_text, click, press_key, screenshot, set_properties, find_element, get_children"],
                "role": ["type": "string", "description": "AX role (e.g. AXButton, AXTextField)"],
                "title": ["type": "string", "description": "Title/name to match (partial)"],
                "value": ["type": "string", "description": "Value to match (partial)"],
                "appBundleId": ["type": "string", "description": "App bundle ID to search within"],
                "x": ["type": "number", "description": "Screen X coordinate"],
                "y": ["type": "number", "description": "Screen Y coordinate"],
                "text": ["type": "string", "description": "For type_text: text to type"],
                "button": ["type": "string", "description": "For click: left/right/middle (default left)"],
                "clicks": ["type": "integer", "description": "For click: 1 or 2 (default 1)"],
                "keyCode": ["type": "integer", "description": "For press_key: macOS virtual key code"],
                "modifiers": ["type": "array", "description": "For press_key: command/option/control/shift", "items": ["type": "string"]],
                "width": ["type": "number", "description": "For screenshot: region width"],
                "height": ["type": "number", "description": "For screenshot: region height"],
                "windowId": ["type": "integer", "description": "For screenshot/list_windows: window ID"],
                "limit": ["type": "integer", "description": "For list_windows: max windows (default 50)"],
                "ax_action": ["type": "string", "description": "For perform_action: AX action (e.g. AXPress, AXConfirm)"],
                "properties": ["type": "object", "description": "For set_properties: key-value pairs to set"],
                "timeout": ["type": "number", "description": "For find_element: max seconds to wait (default 5)"],
                "depth": ["type": "integer", "description": "For get_children: traversal depth (default 3)"],
            ],
            required: ["action"]
        ),
        // --- Tool Discovery ---
        ToolDef(
            name: Name.listNativeTools,
            description: "List all enabled tools (built-in and MCP).",
            properties: [:],
            required: []
        ),
        // --- Web (consolidated) ---
        ToolDef(
            name: Name.safari,
            description: "Web browser automation. Actions: open, scan, read_content, click, type, execute_js, get_url, get_title, google_search, submit, navigate, list_tabs, switch_tab.",
            properties: [
                "action": ["type": "string", "description": "Action to perform"],
                "url": ["type": "string", "description": "URL to open"],
                "selector": ["type": "string", "description": "CSS selector for click/type/submit"],
                "text": ["type": "string", "description": "Text to type"],
                "query": ["type": "string", "description": "Search query"],
                "script": ["type": "string", "description": "JavaScript code"],
            ],
            required: ["action"]
        ),
        // --- Selenium (consolidated) ---
        ToolDef(
            name: Name.seleniumTool,
            description: "Selenium WebDriver. Actions: start (new session), stop (end session), navigate (go to URL), find (element), click (element), type (text), execute (JS), screenshot, wait (for element).",
            properties: [
                "action": ["type": "string", "description": "Action: start, stop, navigate, find, click, type, execute, screenshot, or wait"],
                "browser": ["type": "string", "description": "For start: safari (default), chrome, firefox"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
                "url": ["type": "string", "description": "For navigate: URL"],
                "strategy": ["type": "string", "description": "For find/click/type/wait: css, xpath, id, name"],
                "value": ["type": "string", "description": "For find/click/type/wait: selector value"],
                "text": ["type": "string", "description": "For type: text to enter"],
                "script": ["type": "string", "description": "For execute: JavaScript code"],
                "filename": ["type": "string", "description": "For screenshot: filename"],
                "timeout": ["type": "number", "description": "For wait: max seconds (default 10)"],
                "capabilities": ["type": "object", "description": "For start: WebDriver capabilities"],
            ],
            required: ["action"]
        ),
    ]

    // MARK: - Plain-Text Format (for Foundation Models / text-based providers)

    /// All tool names derived from commonTools + conversationTools. Use instead of hardcoded lists.
    nonisolated static var toolNames: [String] {
        (commonTools + conversationTools).map { $0.name }
    }

    /// Compact tool reference for inclusion in plain-text model prompts.
    /// Format: toolName {"param": type, "optParam"?: type} — short description
    nonisolated static var textFormat: String {
        var lines: [String] = ["TOOLS — call as: toolName {\"param\": value, ...}"]
        for tool in (commonTools + conversationTools) {
            let reqParams = tool.required
            let allKeys = tool.properties.keys.sorted { a, b in
                let aReq = reqParams.contains(a)
                let bReq = reqParams.contains(b)
                if aReq != bReq { return aReq }
                return a < b
            }
            var paramParts: [String] = []
            for key in allKeys {
                guard let schema = tool.properties[key] else { continue }
                let typeStr = (schema["type"] as? String) ?? "any"
                let opt = reqParams.contains(key) ? "" : "?"
                paramParts.append("\"\(key)\"\(opt): \(typeStr)")
            }
            let params = paramParts.isEmpty ? "{}" : "{\(paramParts.joined(separator: ", "))}"
            let shortDesc = tool.description.components(separatedBy: ". ").first ?? tool.description
            lines.append("\(tool.name) \(params) — \(shortDesc)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Claude (Anthropic) Format

    /// Convert a ToolDef to Anthropic's tool schema.
    static func claudeTool(name: String, description: String, properties: [String: Any], required: [String]) -> [String: Any] {
        [
            "name": name,
            "description": description,
            "input_schema": [
                "type": "object",
                "properties": properties,
                "required": required,
            ] as [String: Any],
        ]
    }

    /// Sanitize an MCP tool name to alphanumeric, underscore, and hyphen only.
    private static func sanitizeToolName(_ name: String) -> String {
        String(name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "_" || $0 == "-" }.prefix(128))
    }

    /// Sanitize an MCP tool description: collapse newlines, cap length.
    private static func sanitizeDescription(_ desc: String, maxLength: Int = 1024) -> String {
        let cleaned = desc
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return String(cleaned.prefix(maxLength))
    }

    /// Recursively remove NSNull values and ensure schema validity
    private static func sanitizeSchema(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            // Filter out NSNull values and sanitize recursively
            var result: [String: Any] = [:]
            for (key, val) in dict {
                if !(val is NSNull) {
                    result[key] = sanitizeSchema(val)
                }
            }
            // Ensure "properties" is always an object for object-type schemas
            if (result["type"] as? String) == "object" && result["properties"] == nil {
                result["properties"] = [:] as [String: Any]
            }
            // Fix OpenAI array schema: ensure "items" field exists for array types
            if result["type"] as? String == "array" && result["items"] == nil {
                // OpenAI requires "items" for array types - use empty object schema as default
                result["items"] = ["type": "object"] as [String: Any]
            }
            return result
        } else if let arr = value as? [Any] {
            return arr.map { sanitizeSchema($0) }
        } else if value is NSNull {
            // Replace NSNull with empty object for schema fields, or empty string for others
            return "" as Any
        }
        return value
    }

    /// All common tools + MCP tools in Claude/Anthropic format.
    /// When activeGroups is set, only tools in those groups are included.
    @MainActor static func claudeFormat(activeGroups: Set<String>? = nil) -> [[String: Any]] {
        let prefs = ToolPreferencesService.shared
        var tools = (commonTools + webSearchTools + conversationTools)
            .filter { prefs.isEnabled(.claude, $0.name, activeGroups: activeGroups) }
            .map { tool in
                claudeTool(name: tool.name, description: tool.description,
                           properties: tool.properties, required: tool.required)
            }
        let mcpService = MCPService.shared
        for tool in mcpService.discoveredTools where mcpService.isToolEnabled(serverName: tool.serverName, toolName: tool.name) {
            let safeName = sanitizeToolName("mcp_\(tool.serverName)_\(tool.name)")
            let safeDesc = sanitizeDescription("[MCP:\(tool.serverName)] \(tool.description)")
            let rawSchema = (try? JSONSerialization.jsonObject(with: Data(tool.inputSchemaJSON.utf8))) as? [String: Any]
            let schema = rawSchema.map { sanitizeSchema($0) as? [String: Any] } ?? nil
            let validSchema: [String: Any]
            if let s = schema, !s.isEmpty {
                validSchema = s
            } else {
                validSchema = ["type": "object", "properties": [:] as [String: Any]]
            }
            tools.append([
                "name": safeName,
                "description": safeDesc,
                "input_schema": validSchema,
            ] as [String: Any])
        }
        return tools
    }

    // MARK: - Ollama (OpenAI) Format

    /// Convert a ToolDef to OpenAI/Ollama tool schema.
    /// Applies schema sanitization to fix OpenAI-specific issues (e.g., array items requirement).
    static func ollamaTool(name: String, description: String, properties: [String: Any], required: [String]) -> [String: Any] {
        // Sanitize properties to ensure OpenAI schema compliance
        let sanitizedProperties = sanitizeSchema(properties) as? [String: Any] ?? properties
        
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": sanitizedProperties,
                    "required": required,
                ] as [String: Any],
            ] as [String: Any],
        ]
    }

    /// Web search tool available for all providers (client-side via Tavily).
    nonisolated(unsafe) private static let webSearchTools: [ToolDef] = [
        ToolDef(
            name: Name.webSearch, // Tavily web search — still uses web_search internally
            description: "Search the web for current information. Returns relevant web page titles, URLs, and content snippets. Use when you need up-to-date information or facts you're unsure about.",
            properties: [
                "query": ["type": "string", "description": "The search query"],
            ],
            required: ["query"]
        ),
    ]

    /// Conversation tool definitions for writing, text transformation, self-description, and corrections.
    nonisolated(unsafe) static let conversationTools: [ToolDef] = [
        ToolDef(
            name: Name.writeText,
            description: "Write text about a given subject. Creates well-structured prose on any topic without emojis. Use for generating content, articles, descriptions, explanations, or creative writing.",
            properties: [
                "subject": ["type": "string", "description": "The subject or topic to write about"],
                "style": ["type": "string", "description": "Writing style: 'informative', 'creative', 'technical', 'casual', or 'formal' (default: 'informative')"],
                "length": ["type": "string", "description": "Desired length: 'short' (~100 words), 'medium' (~300 words), 'long' (~600 words), or specify exact word count as number"],
                "context": ["type": "string", "description": "Optional additional context or requirements for the writing"],
            ],
            required: ["subject"]
        ),
        ToolDef(
            name: Name.transformText,
            description: "Transform text into different formats. Convert prose to lists, outlines, summaries, or restructured content. No emojis in output. Use for creating grocery lists, todo lists, bullet points, or reformatting text.",
            properties: [
                "text": ["type": "string", "description": "The text to transform"],
                "transform": ["type": "string", "description": "Transformation type: 'grocery_list', 'todo_list', 'outline', 'summary', 'bullet_points', 'numbered_list', 'table', or 'qa'"],
                "options": ["type": "string", "description": "Optional additional options for the transformation"],
            ],
            required: ["text", "transform"]
        ),
        ToolDef(
            name: Name.sendMessage,
            description: "Send a message to the user via iMessage, email, or other channels. Formats and delivers text content to specified recipients. No emojis in message content.",
            properties: [
                "content": ["type": "string", "description": "The message content to send"],
                "recipient": ["type": "string", "description": "Recipient: 'me' (self), phone number, email address, or contact name"],
                "channel": ["type": "string", "description": "Delivery channel: 'imessage' (default), 'email', 'sms', or 'clipboard'"],
                "subject": ["type": "string", "description": "Subject line for email messages"],
            ],
            required: ["content", "recipient"]
        ),
        ToolDef(
            name: Name.aboutSelf,
            description: "Describe Agent's capabilities, features, and how to use it. Returns information about available tools, current configuration, and example usage patterns. No emojis.",
            properties: [
                "topic": ["type": "string", "description": "Optional specific topic: 'tools', 'features', 'scripting', 'automation', 'coding', or 'all' (default: 'all')"],
                "detail": ["type": "string", "description": "Level of detail: 'brief', 'standard', or 'detailed' (default: 'standard')"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.fixText,
            description: "Fix spelling and grammar errors in text without adding emojis. Corrects typos, punctuation, capitalization, and grammar while preserving the original meaning and tone.",
            properties: [
                "text": ["type": "string", "description": "The text to fix"],
                "fixes": ["type": "string", "description": "Types of fixes: 'all' (default), 'spelling', 'grammar', 'punctuation', or 'capitalization'"],
                "preserve_style": ["type": "boolean", "description": "Keep original writing style and tone (default: true)"],
            ],
            required: ["text"]
        ),
        ToolDef(
            name: Name.planMode,
            description: "Manage step-by-step plans. Create a plan, execute every step, update status as you go. Example: action='create', name='my-plan', steps='Step 1\\nStep 2\\nStep 3'. Then update each step: action='update', name='my-plan', step=0, status='completed'.",
            properties: [
                "action": ["type": "string", "description": "One of: create, update, read, list, delete"],
                "name": ["type": "string", "description": "Plan name slug (e.g. 'code-review', 'refactor-auth'). Required for create/read/update/delete."],
                "steps": ["type": "string", "description": "For create: newline-separated list of steps (e.g. 'Step 1\\nStep 2\\nStep 3')"],
                "step": ["type": "integer", "description": "For update: zero-based step index (0 = first step)"],
                "status": ["type": "string", "description": "For update: 'in_progress', 'completed', or 'failed'"],
            ],
            required: ["action"]
        ),
        ToolDef(
            name: "memory",
            description: "Read/write persistent user preferences. Memory is shown at task start. Actions: read, write, append, clear. Users say 'remember X' → append.",
            properties: [
                "action": ["type": "string", "description": "One of: read, write, append, clear"],
                "text": ["type": "string", "description": "For write/append: the text to store"],
            ],
            required: ["action"]
        ),
    ]

    /// Provider-aware Ollama/OpenAI format — filters tools by per-provider preferences.
    /// When activeGroups is set, only tools in those groups are included.
    @MainActor static func ollamaTools(for provider: APIProvider, activeGroups: Set<String>? = nil) -> [[String: Any]] {
        let prefs = ToolPreferencesService.shared
        // All providers get web_search and conversation tools
        var tools = (commonTools + webSearchTools + conversationTools)
            .filter { prefs.isEnabled(provider, $0.name, activeGroups: activeGroups) }
            .map { tool in
                ollamaTool(name: tool.name, description: tool.description,
                           properties: tool.properties, required: tool.required)
            }
        let mcpService = MCPService.shared
        for tool in mcpService.discoveredTools where mcpService.isToolEnabled(serverName: tool.serverName, toolName: tool.name) {
            let safeName = sanitizeToolName("mcp_\(tool.serverName)_\(tool.name)")
            let safeDesc = sanitizeDescription("[MCP:\(tool.serverName)] \(tool.description)")
            let rawSchema = (try? JSONSerialization.jsonObject(with: Data(tool.inputSchemaJSON.utf8))) as? [String: Any]
            let schema = rawSchema.map { sanitizeSchema($0) as? [String: Any] } ?? nil
            let validSchema: [String: Any]
            if let s = schema, !s.isEmpty {
                validSchema = s
            } else {
                validSchema = ["type": "object", "properties": [:] as [String: Any]]
            }
            tools.append([
                "type": "function",
                "function": [
                    "name": safeName,
                    "description": safeDesc,
                    "parameters": validSchema,
                ] as [String: Any],
            ] as [String: Any])
        }
        return tools
    }

    /// Backward-compat alias — defaults to Ollama Cloud preferences.
    @MainActor static var ollamaFormat: [[String: Any]] { ollamaTools(for: .ollama) }
}

