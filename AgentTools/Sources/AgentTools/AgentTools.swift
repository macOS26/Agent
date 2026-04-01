import Foundation

/// Shared system prompt and tool definitions for all LLM providers.
/// ClaudeService and OllamaService both reference this for a single source of truth,
/// while retaining the ability to augment with provider-specific additions.
public enum AgentTools {

    // MARK: - Tool Name Constants (single source of truth)
    public enum Name {
        // File Manager (consolidated CRUDL)
        public static let fileManager = "file_manager"
        // Git (consolidated CRUDL)
        public static let git = "git"
        // Legacy git names (handlers still work)
        public static let gitStatus = "git_status"
        public static let gitDiff = "git_diff"
        public static let gitLog = "git_log"
        public static let gitCommit = "git_commit"
        public static let gitDiffPatch = "git_diff_patch"
        public static let gitBranch = "git_branch"
        // Core Scripting
        public static let appleEventQuery = "apple_event_query"
        public static let runApplescript = "run_applescript"
        public static let runOsascript = "run_osascript"
        public static let executeJavascript = "execute_javascript"
        // Shell Execution
        public static let executeAgentCommand = "execute_agent_command"
        public static let executeDaemonCommand = "execute_daemon_command"
        public static let batchCommands = "batch_commands"
        public static let batchTools = "batch_tools"
        public static let runShellScript = "run_shell_script"
        // Task
        public static let taskComplete = "task_complete"
        // Accessibility (consolidated)
        public static let accessibility = "accessibility"
        // Legacy ax names (handlers still work)
        public static let axListWindows = "ax_list_windows"
        public static let axInspectElement = "ax_inspect_element"
        public static let axGetProperties = "ax_get_properties"
        public static let axPerformAction = "ax_perform_action"
        public static let axCheckPermission = "ax_check_permission"
        public static let axRequestPermission = "ax_request_permission"
        public static let axTypeText = "ax_type_text"
        public static let axClick = "ax_click"
        public static let axScroll = "ax_scroll"
        public static let axPressKey = "ax_press_key"
        public static let axScreenshot = "ax_screenshot"
        public static let axGetAuditLog = "ax_get_audit_log"
        public static let axSetProperties = "ax_set_properties"
        public static let axFindElement = "ax_find_element"
        public static let axGetFocusedElement = "ax_get_focused_element"
        public static let axGetChildren = "ax_get_children"
        public static let axDrag = "ax_drag"
        public static let axWaitForElement = "ax_wait_for_element"
        public static let axShowMenu = "ax_show_menu"
        public static let axClickElement = "ax_click_element"
        public static let axWaitAdaptive = "ax_wait_adaptive"
        public static let axTypeIntoElement = "ax_type_into_element"
        public static let axHighlightElement = "ax_highlight_element"
        public static let axGetWindowFrame = "ax_get_window_frame"
        public static let axClickMenuItem = "ax_click_menu_item"
        public static let axSetWindowFrame = "ax_set_window_frame"
        public static let axManageApp = "ax_manage_app"
        public static let axScrollToElement = "ax_scroll_to_element"
        public static let axReadFocused = "ax_read_focused"
        // Agent Script (consolidated CRUDL)
        public static let agentScript = "agent"
        // Agent action names (expanded from consolidated "agent" tool)
        public static let listAgentScripts = "list_agents"
        public static let readAgentScript = "read_agent"
        public static let createAgentScript = "create_agent"
        public static let updateAgentScript = "update_agent"
        public static let runAgentScript = "run_agent"
        public static let deleteAgentScript = "delete_agent"
        public static let combineAgentScripts = "combine_agents"
        // SDEF
        public static let lookupSdef = "lookup_sdef"
        // Xcode (consolidated CRUDL)
        public static let xcode = "xcode"
        // Legacy xcode names (handlers still work)
        public static let xcodeBuild = "xcode_build"
        public static let xcodeRun = "xcode_run"
        public static let xcodeListProjects = "xcode_list_projects"
        public static let xcodeSelectProject = "xcode_select_project"
        public static let xcodeGrantPermission = "xcode_grant_permission"
        // AppleScript (consolidated CRUDL)
        public static let appleScriptTool = "applescript_tool"
        // Legacy AppleScript names (handlers still work)
        public static let listAppleScripts = "list_apple_scripts"
        public static let runAppleScript = "run_apple_script"
        public static let saveAppleScript = "save_apple_script"
        public static let deleteAppleScript = "delete_apple_script"
        // JavaScript (consolidated CRUDL)
        public static let javascriptTool = "javascript_tool"
        // Legacy JavaScript names (handlers still work)
        public static let listJavascript = "list_javascript"
        public static let runJavascript = "run_javascript"
        public static let saveJavascript = "save_javascript"
        public static let deleteJavascript = "delete_javascript"
        // Tool Discovery
        public static let listNativeTools = "list_tools"
// Safari (consolidated web automation)
        public static let safari = "web"
        // Legacy web_ names (handlers still work)
        public static let safariOpen = "web_open"
        public static let safariFind = "web_find"
        public static let safariClick = "web_click"
        public static let safariType = "web_type"
        public static let safariExecuteJs = "web_execute_js"
        public static let safariGetUrl = "web_get_url"
        public static let safariGetTitle = "web_get_title"
        public static let safariGoogleSearch = "web_google_search"
        public static let safariReadContent = "web_read_content"
        public static let safariScrollTo = "web_scroll_to"
        public static let safariSelect = "web_select"
        public static let safariSubmit = "web_submit"
        public static let safariNavigate = "web_navigate"
        public static let safariListTabs = "web_list_tabs"
        public static let safariSwitchTab = "web_switch_tab"
        public static let safariListWindows = "web_list_windows"
        public static let webSwitchWindow = "web_switch_window"
        public static let webNewWindow = "web_new_window"
        public static let webCloseWindow = "web_close_window"
        public static let webWaitForElement = "web_wait_for_element"
        // Selenium (consolidated CRUDL)
        public static let seleniumTool = "selenium"
        // Legacy selenium names (handlers still work)
        public static let seleniumStart = "selenium_start"
        public static let seleniumStop = "selenium_stop"
        public static let seleniumNavigate = "selenium_navigate"
        public static let seleniumFind = "selenium_find"
        public static let seleniumClick = "selenium_click"
        public static let seleniumType = "selenium_type"
        public static let seleniumExecute = "selenium_execute"
        public static let seleniumScreenshot = "selenium_screenshot"
        public static let seleniumWait = "selenium_wait"
        // Ollama-only
        public static let webSearch = "web_search"
        // Conversation (consolidated CRUDL)
        public static let conversation = "conversation"
        public static let sendMessage = "send_message"
        public static let planMode = "plan_mode"
        public static let projectFolderTool = "project_folder"
        public static let codingMode = "coding_mode"
    }

    // MARK: - Full LLM System Prompt (Desktop: Claude, Ollama, OpenAI, etc.)
    public static func systemPrompt(userName: String, userHome: String, projectFolder: String = "") -> String {
        let folder = projectFolder.isEmpty ? userHome : projectFolder
        let shell = ProcessInfo.processInfo.environment["SHELL"]?.components(separatedBy: "/").last ?? "zsh"
        return """
        You are an autonomous macOS agent. User: "\(userName)", home: "\(userHome)". Project: \(folder). Shell: \(shell).
        ALWAYS call task_complete when finished. Put questions in the summary. Don't ask — act.
        Show full output when listing. Never output code as text — use file_manager or agent tools.

        TOOLS: file_manager (read/write/edit/list/search/diff_apply/extract_function) | git (status/diff/log/commit/branch) | xcode (build/run/analyze/snippet/add_file/remove_file) | agent (list/read/create/update/run/delete/combine) | plan_mode (create/update/read/list/delete) | project_folder (get/set/home/documents/library/none) | coding_mode (enabled:true/false)
        applescript_tool (execute/lookup_sdef/list/run/save/delete) | javascript_tool (execute/list/run/save/delete) | accessibility (list_windows/click/type_text/find_element/get_properties + more) | web (open/click/type/read_content/execute_js/google_search + more)
        execute_agent_command (shell) | execute_daemon_command (root shell) | batch_commands (multi-shell) | batch_tools (multi-tool) | run_shell_script (shell with fallback)

        RULES:
        - Prefer built-in tools over MCP (mcp_*). Use file_manager for files, git for VCS, xcode for builds.
        - NEVER guess file paths. ALWAYS call file_manager(action:"list") BEFORE reading files to verify they exist. Guessing paths wastes tokens on errors.
        - ALWAYS use file_manager(action:"list") and file_manager(action:"search") instead of shell find/grep commands. These tools format output as a directory tree and save tokens.
        - xcode(action:"build") for Xcode projects, never xcodebuild shell.
        - xcode(action:"analyze"/"snippet") for Swift code review.
        - Safari JS via AppleScript preferred for web: `tell application "Safari" to do JavaScript "..." in document 1`.
        - For 3+ step tasks, create a plan_mode plan first, then execute each step.
        - EDITING FILES (file_manager actions):
          edit: exact string replace (old_string → new_string). Best for single-line changes.
          diff_apply: replace a line range (file_path, start_line, end_line, destination). Best for multi-line edits. PREFERRED for code changes.
          create: preview a diff without applying (returns diff_id). Use with apply to review before committing.
          apply: commit a previewed diff by diff_id from create.
          undo: revert the last edit on a file.
          ALWAYS re-read file after any edit — line numbers shift. One edit per call.
        - SPLITTING FILES: read → write new → xcode add_file → edit original → xcode build. One file at a time.

        TCC (in-process): agent(run), applescript_tool(execute), accessibility. NO TCC: execute_agent_command, execute_daemon_command.
        SHELL: execute_agent_command runs as current user. execute_daemon_command runs as ROOT — no sudo needed, it uses a privileged Launch Daemon. Use execute_daemon_command for: system logs, disk diagnostics, network debug, launchd, firewall, /System or /Library access, and any command that would normally require sudo. NEVER use sudo — use execute_daemon_command instead.
        AGENT SCRIPTS: ~/Documents/AgentScript/agents/. Swift dylibs. Entry: @_cdecl("script_main") public func scriptMain() -> Int32. Args via AGENT_SCRIPT_ARGS env. Full Swift + ScriptingBridge + TCC.
        """
    }

    /// Minimal system prompt for coding mode iterations 2+. Saves ~2K tokens per iteration.
    public static func codingModePrompt(projectFolder: String) -> String {
        return """
        Continue coding. Project: \(projectFolder). ALWAYS call task_complete when done. Re-read files after edits. Use diff_apply for multi-line changes. One edit per call.
        """
    }

    // MARK: - Tool List per Provider (for ToolsView)

    /// Returns the tools available for a given provider.
    /// Web search via Tavily is now available for all providers as a backup search option.
    /// Conversation tools for natural language tasks are also included.
    public static func tools(for provider: APIProvider) -> [ToolDef] {
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
    @MainActor public static func compactSystemPrompt(userName: String, userHome: String, projectFolder: String = "") -> String {
        let folder = projectFolder.isEmpty ? userHome : projectFolder
        let n = Name.self
        return """
        macOS agent for \(userName). Project: \(folder). ALWAYS call \(n.taskComplete) when finished. If you need user input, put the question in the summary AND call \(n.taskComplete). Every response MUST end with \(n.taskComplete).
        TOOLS: \(n.fileManager) (action: read/write/edit/list/search), \(n.executeAgentCommand), \(n.agentScript) (list/read/create/update/run).
        Shell: \(n.executeAgentCommand) for rm/mv/cp/ls/grep. Don't repeat stdout.
        """
    }

    /// Concrete examples for each tool.
    public static let toolExamples: [String: String] = [
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
        Name.accessibility:        #"accessibility {"action": "click", "role": "AXButton", "title": "take photo", "appBundleId": "com.apple.PhotoBooth"}"#,
        Name.safari:               #"web {"action": "open", "url": "https://example.com"}"#,
        Name.appleScriptTool:      #"applescript_tool {"action": "execute", "source": "display dialog \"Hello\""}"#,
        Name.javascriptTool:       #"javascript_tool {"action": "execute", "source": "var app = Application.currentApplication(); app.displayDialog('Hello')"}"#,
        Name.projectFolderTool:    #"project_folder {"action": "set", "path": "/Users/me/Projects/MyApp"}"#,
        Name.webSearch:            #"web_search {"query": "latest Swift news"}"#,
        // Conversation (consolidated)
        Name.conversation:         #"conversation {"action": "write", "subject": "machine learning", "style": "informative", "length": "medium"}"#,
        Name.sendMessage:          #"send_message {"content": "Hello!", "recipient": "me", "channel": "imessage"}"#,
    ]

    @MainActor public static func enabledAppleAIToolLines(isEnabled: (String) -> Bool) -> String {
        return commonTools
            .filter { isEnabled($0.name) }
            .map { tool in toolExamples[tool.name] ?? "\(tool.name) {}" }
            .joined(separator: "\n")
    }

    // MARK: - Tool Definitions (internal, format-neutral)

    public struct ToolDef: @unchecked Sendable {
        public let name: String
        public let description: String
        public let properties: [String: [String: Any]]
        public let required: [String]

        public init(name: String, description: String, properties: [String: [String: Any]], required: [String]) {
            self.name = name
            self.description = description
            self.properties = properties
            self.required = required
        }
    }

    nonisolated(unsafe) public static let commonTools: [ToolDef] = [
        // --- File Manager (consolidated) ---
        ToolDef(
            name: Name.fileManager,
            description: "File ops. edit=exact string replace. diff_apply=replace line range (PREFERRED for code). create=preview diff (returns diff_id). apply=commit diff by id. undo=revert last edit. Also: read/write/list/search/extract_function.",
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
                "detail": ["type": "string", "description": "For read_dir: 'slim' (default, names only) or 'more' (full ls -la with sizes/dates/permissions)"],
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
            description: "Xcode: build/run, analyze/snippet for code review, get_version/bump_version/bump_build, add/remove files. bump_version also bumps build. Use delta:-1 to decrement.",
            properties: [
                "action": ["type": "string", "description": "Action: build, run, list_projects, select_project, add_file, remove_file, grant_permission, analyze, snippet, or code_review"],
                "project_path": ["type": "string", "description": "For build/run: path (auto-detected if empty)"],
                "file_path": ["type": "string", "description": "For add_file/remove_file/analyze/snippet: path to source file"],
                "number": ["type": "integer", "description": "For select_project: project number (1-based)"],
                "start_line": ["type": "integer", "description": "For analyze/snippet: start line number"],
                "end_line": ["type": "integer", "description": "For analyze/snippet: end line number"],
                "checks": ["type": "string", "description": "For analyze: check groups (all, syntax, style, safety, performance, bestPractices)"],
                "delta": ["type": "integer", "description": "For bump_version/bump_build: +1 (default) or -1 to decrement"],
            ],
            required: ["action"]
        ),
        // --- Coding: Shell ---
        ToolDef(
            name: Name.executeAgentCommand,
            description: "Shell command as current user. Use for git, ls, grep, find, homebrew, scripts. No TCC.",
            properties: [
                "command": ["type": "string", "description": "The bash command to execute as the current user"],
            ],
            required: ["command"]
        ),
        ToolDef(
            name: Name.executeDaemonCommand,
            description: "Shell command as ROOT via Launch Daemon — no sudo needed. Use instead of sudo for: system logs, disk ops, network debug, launchd, firewall, /System, /Library.",
            properties: [
                "command": ["type": "string", "description": "The bash command to execute as root"],
            ],
            required: ["command"]
        ),
        ToolDef(
            name: Name.runShellScript,
            description: "Shell command with automatic fallback to in-process when User Agent is off.",
            properties: [
                "command": ["type": "string", "description": "The bash command or shell script to execute"],
            ],
            required: ["command"]
        ),
        ToolDef(
            name: Name.batchCommands,
            description: "Run multiple shell commands in one call. Newline-separated. No round-trips.",
            properties: [
                "commands": ["type": "string", "description": "Commands separated by newlines. Each runs sequentially as the current user."],
            ],
            required: ["commands"]
        ),
        ToolDef(
            name: Name.batchTools,
            description: "Run multiple tool calls in one batch with progress tracking. No round-trips.",
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
        // --- Project Folder ---
        ToolDef(
            name: Name.projectFolderTool,
            description: "Get or change the working directory for this tab. Actions: get (show current), set (change to path), home (~), documents (~/Documents), library (~/Library), none (clear).",
            properties: [
                "action": ["type": "string", "description": "One of: get, set, home, documents, library, none"],
                "path": ["type": "string", "description": "For set: absolute path to new project folder"],
            ],
            required: ["action"]
        ),
        // --- Coding Mode ---
        ToolDef(
            name: Name.codingMode,
            description: "Toggle coding mode on/off. When ON, only Core+Workflow+Coding+UserAgent tools are sent to the LLM — removes conversation, accessibility, automation, web, daemon tools for faster responses. Auto-enables after iteration 1 for coding tasks.",
            properties: [
                "enabled": ["type": "boolean", "description": "true to enable coding mode, false to disable and restore all tools"],
            ],
            required: ["enabled"]
        ),
        // --- Agent Scripts (reusable Swift scripts) ---
        // --- Agent Scripts (consolidated) ---
        ToolDef(
            name: Name.agentScript,
            description: "Swift automation scripts with TCC. Actions: list, read, create, update, run, delete, combine.",
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
            description: "AppleScript with TCC. Actions: execute, lookup_sdef, list, run, save, delete.",
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
        // --- Accessibility (consolidated, powered by AXorcist) ---
        ToolDef(
            name: Name.accessibility,
            description: "macOS UI automation via AXorcist. IMPORTANT: To click a button in an app, use action=click with title and appBundleId directly — do NOT call list_windows first. Example: click title='take photo' appBundleId='Photo Booth'. The appBundleId accepts app names like 'Photo Booth', 'Safari', 'TextEdit' (auto-resolves to bundle ID). Actions: click (finds+activates app+presses element), perform_action, type_text, type_into_element, find_element, get_properties, get_children, list_windows, manage_app (launch/activate/quit/list), click_menu_item, scroll, press_key, screenshot, set_properties, wait_for_element, get_focused_element, read_focused, highlight_element, show_menu, drag, set_window_frame, get_window_frame, scroll_to_element.",
            properties: [
                "action": ["type": "string", "description": "Action to perform. Common: click (find+press by role/title), perform_action (custom AX action), list_windows, get_properties, find_element, get_children, type_text, type_into_element, manage_app, click_menu_item, screenshot, scroll, press_key, set_properties, wait_for_element, get_focused_element, read_focused, highlight_element, show_menu, drag, set_window_frame, get_window_frame, scroll_to_element"],
                "role": ["type": "string", "description": "AX role filter (e.g. AXButton, AXTextField, AXWindow)"],
                "title": ["type": "string", "description": "Element name to match — searches AXTitle, AXDescription, AXHelp (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial)"],
                "appBundleId": ["type": "string", "description": "App bundle ID (e.g. com.apple.PhotoBooth). Required to target a specific app"],
                "x": ["type": "number", "description": "Screen X coordinate"],
                "y": ["type": "number", "description": "Screen Y coordinate"],
                "text": ["type": "string", "description": "For type_text/type_into_element: text to type"],
                "button": ["type": "string", "description": "For click: left/right/middle (default left)"],
                "clicks": ["type": "integer", "description": "For click: 1 or 2 (default 1)"],
                "keyCode": ["type": "integer", "description": "For press_key: macOS virtual key code"],
                "modifiers": ["type": "array", "description": "For press_key: command/option/control/shift", "items": ["type": "string"]],
                "width": ["type": "number", "description": "For screenshot/set_window_frame: width"],
                "height": ["type": "number", "description": "For screenshot/set_window_frame: height"],
                "windowId": ["type": "integer", "description": "For screenshot: window ID"],
                "limit": ["type": "integer", "description": "For list_windows: max windows (default 50)"],
                "ax_action": ["type": "string", "description": "For perform_action: AXPress, AXConfirm, AXCancel, AXShowMenu, AXRaise, AXIncrement, AXDecrement"],
                "properties": ["type": "object", "description": "For set_properties: key-value pairs to set"],
                "timeout": ["type": "number", "description": "For find_element/click/wait_for_element: max seconds (default 5)"],
                "depth": ["type": "integer", "description": "For get_children: traversal depth (default 3)"],
                "menuPath": ["type": "string", "description": "For click_menu_item: menu path separated by ' > ' (e.g. 'File > Save')"],
                "name": ["type": "string", "description": "For manage_app: app name (e.g. 'Photo Booth')"],
                "bundleId": ["type": "string", "description": "For manage_app: bundle ID to launch/activate/quit"],
                "deltaX": ["type": "number", "description": "For scroll: horizontal scroll amount"],
                "deltaY": ["type": "number", "description": "For scroll: vertical scroll amount (negative=down)"],
                "fromX": ["type": "number", "description": "For drag: start X"],
                "fromY": ["type": "number", "description": "For drag: start Y"],
                "toX": ["type": "number", "description": "For drag: end X"],
                "toY": ["type": "number", "description": "For drag: end Y"],
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
            description: "Safari web automation: open/click/type/read_content/execute_js/google_search/navigate/tabs.",
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
    nonisolated public static var toolNames: [String] {
        (commonTools + conversationTools).map { $0.name }
    }

    /// Compact tool reference for inclusion in plain-text model prompts.
    /// Format: toolName {"param": type, "optParam"?: type} — short description
    nonisolated public static var textFormat: String {
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
    public static func claudeTool(name: String, description: String, properties: [String: Any], required: [String]) -> [String: Any] {
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

    /// Strip property descriptions to just type for compact mode.
    private static func compactProperties(_ properties: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in properties {
            if var dict = value as? [String: Any] {
                // Keep type, remove verbose description
                if let desc = dict["description"] as? String {
                    // Shorten to first phrase only
                    let short = desc.components(separatedBy: ".").first ?? desc
                    dict["description"] = String(short.prefix(40))
                }
                result[key] = dict
            } else {
                result[key] = value
            }
        }
        return result
    }

    /// All common tools + MCP tools in Claude/Anthropic format.
    /// When activeGroups is set, only tools in those groups are included.
    /// When compact is true, property descriptions are shortened for coding mode.
    /// MCP tool descriptor for format functions.
    public struct MCPToolInfo: Sendable {
        public let serverName: String
        public let name: String
        public let description: String
        public let inputSchemaJSON: String
        public init(serverName: String, name: String, description: String, inputSchemaJSON: String) {
            self.serverName = serverName; self.name = name; self.description = description; self.inputSchemaJSON = inputSchemaJSON
        }
    }

    @MainActor public static func claudeFormat(isEnabled: (String) -> Bool, mcpTools: [MCPToolInfo] = [], compact: Bool = false) -> [[String: Any]] {
        var tools = (commonTools + webSearchTools + conversationTools)
            .filter { isEnabled($0.name) }
            .map { tool in
                let props = compact ? compactProperties(tool.properties) : tool.properties
                return claudeTool(name: tool.name, description: compact ? String(tool.description.prefix(60)) : tool.description,
                           properties: props, required: tool.required)
            }
        for tool in mcpTools {
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
    public static func ollamaTool(name: String, description: String, properties: [String: Any], required: [String]) -> [String: Any] {
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
    nonisolated(unsafe) public static let webSearchTools: [ToolDef] = [
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
    nonisolated(unsafe) public static let conversationTools: [ToolDef] = [
        // --- Conversation (consolidated) ---
        ToolDef(
            name: Name.conversation,
            description: "Conversation tools. Actions: write (generate prose), transform (reformat text), fix (correct spelling/grammar), about (describe Agent capabilities).",
            properties: [
                "action": ["type": "string", "description": "Action: write, transform, fix, or about"],
                "subject": ["type": "string", "description": "For write: topic to write about"],
                "style": ["type": "string", "description": "For write: 'informative', 'creative', 'technical', 'casual', or 'formal' (default: 'informative')"],
                "length": ["type": "string", "description": "For write: 'short' (~100 words), 'medium' (~300 words), 'long' (~600 words), or exact word count"],
                "context": ["type": "string", "description": "For write: additional context or requirements"],
                "text": ["type": "string", "description": "For transform/fix: the text to process"],
                "transform": ["type": "string", "description": "For transform: 'grocery_list', 'todo_list', 'outline', 'summary', 'bullet_points', 'numbered_list', 'table', or 'qa'"],
                "options": ["type": "string", "description": "For transform: additional options"],
                "fixes": ["type": "string", "description": "For fix: 'all' (default), 'spelling', 'grammar', 'punctuation', or 'capitalization'"],
                "preserve_style": ["type": "boolean", "description": "For fix: keep original tone (default: true)"],
                "topic": ["type": "string", "description": "For about: 'tools', 'features', 'scripting', 'automation', 'coding', or 'all' (default: 'all')"],
                "detail": ["type": "string", "description": "For about: 'brief', 'standard', or 'detailed' (default: 'standard')"],
            ],
            required: ["action"]
        ),
        ToolDef(
            name: Name.planMode,
            description: "Step-by-step plans with status tracking. Actions: create, update, read, list, delete.",
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
    @MainActor public static func ollamaTools(isEnabled: (String) -> Bool, mcpTools: [MCPToolInfo] = [], compact: Bool = false) -> [[String: Any]] {
        // All providers get web_search and conversation tools
        var tools = (commonTools + webSearchTools + conversationTools)
            .filter { isEnabled($0.name) }
            .map { tool in
                let props = compact ? compactProperties(tool.properties) : tool.properties
                return ollamaTool(name: tool.name, description: compact ? String(tool.description.prefix(60)) : tool.description,
                           properties: props, required: tool.required)
            }
        for tool in mcpTools {
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
}

