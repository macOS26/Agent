import Foundation

/// Shared system prompt and tool definitions for all LLM providers.
/// ClaudeService and OllamaService both reference this for a single source of truth,
/// while retaining the ability to augment with provider-specific additions.
enum AgentTools {

    // MARK: - Tool Name Constants (single source of truth)
    enum Name {
        // File Tools
        static let readFile = "read_file"
        static let writeFile = "write_file"
        static let editFile = "edit_file"
        static let createDiff = "create_diff"
        static let applyDiff = "apply_diff"
        static let listFiles = "list_files"
        static let searchFiles = "search_files"
        // Git Tools
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
        // Task
        static let taskComplete = "task_complete"
        // Accessibility
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
        // Agent Script Management
        static let listAgentScripts = "list_agent_scripts"
        static let readAgentScript = "read_agent_script"
        static let createAgentScript = "create_agent_script"
        static let updateAgentScript = "update_agent_script"
        static let runAgentScript = "run_agent_script"
        static let deleteAgentScript = "delete_agent_script"
        static let combineAgentScripts = "combine_agent_scripts"
        // SDEF
        static let lookupSdef = "lookup_sdef"
        // Xcode
        static let xcodeBuild = "xcode_build"
        static let xcodeRun = "xcode_run"
        static let xcodeListProjects = "xcode_list_projects"
        static let xcodeSelectProject = "xcode_select_project"
        static let xcodeGrantPermission = "xcode_grant_permission"
        // AppleScript Management
        static let listAppleScripts = "list_apple_scripts"
        static let runAppleScript = "run_apple_script"
        static let saveAppleScript = "save_apple_script"
        static let deleteAppleScript = "delete_apple_script"
        // JavaScript Management
        static let listJavascript = "list_javascript"
        static let runJavascript = "run_javascript"
        static let saveJavascript = "save_javascript"
        static let deleteJavascript = "delete_javascript"
        // Tool Discovery
        static let listNativeTools = "list_tools"
        static let listMcpTools = "list_mcp_tools"
        static let loadGroups = "load_groups"
        static let unloadGroups = "unload_groups"
        // Web Automation
        static let webOpen = "web_open"
        static let webFind = "web_find"
        static let webClick = "web_click"
        static let webType = "web_type"
        static let webExecuteJs = "web_execute_js"
        static let webGetUrl = "web_get_url"
        static let webGetTitle = "web_get_title"
        // Selenium
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

    // MARK: - System Prompt (full version for Claude/Ollama)
    static func systemPrompt(userName: String, userHome: String, projectFolder: String = "") -> String {
        let folder = projectFolder.isEmpty ? userHome : projectFolder
        return """
        You are an autonomous macOS agent. User: "\(userName)", home: "\(userHome)".
        Project: \(folder). Always cd here first. Call task_complete when done.
        Don't repeat stdout — user sees it live. Don't ask questions — just act.
        NEVER output code as text — always use tools: create_agent_script/update_agent_script for scripts, write_file/edit_file for other files.

        TOOL PRIORITY: Native tools → MCP servers → shell (last resort).
        Prefer read_file/edit_file/write_file over cat/sed. Prefer xcode_build over xcodebuild.
        write_file returns count only — verify with read_file.

        TCC CONTEXT:
        - Full TCC (in Agent process): run_agent_script, apple_event_query, run_applescript, run_osascript, ax_* tools
        - NO TCC: execute_agent_command (user, ~=\(userHome)), execute_daemon_command (root, ~=/var/root — chown back)
        - Never use shell for Automation/Accessibility — no TCC permissions.

        AGENT SCRIPTS: ~/Documents/AgentScript/agents/. List first, update existing.
        Scripts can be 100% Swift — no ScriptingBridge required. Use for any task: data processing, file ops, networking, etc.
        ScriptingBridge is only needed when automating apps that expose an AppleScript dictionary (SDEF).
        To merge two scripts: use combine_agent_scripts tool (NOT text output).
        To create/update scripts: use create_agent_script or update_agent_script tools (NOT text output).
        Format: @_cdecl("script_main") public func scriptMain() -> Int32 { return 0 }
        Rules: No exit(). @unknown default on ScriptingBridge enums. Use lookup_sdef first for app automation.
        Data: AGENT_SCRIPT_ARGS env or json/{Name}_input.json/_output.json.
        Generate bridges: run_agent_script GenerateBridge with args /Applications/App.app

        load_groups/unload_groups: Load or unload tool groups mid-task. Groups: Coding, Automation, Accessibility, Web.
        MCP TOOLS: mcp_* in your tool list — never call a server's list/tools.
        IMAGE PATHS: Print paths — UI renders clickable links. No emojis in conversation tool output.
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
    
    // MARK: - Compact System Prompt (for Apple Intelligence with limited context)
    @MainActor static func compactSystemPrompt(userName: String, userHome: String, projectFolder: String = "") -> String {
        let folder = projectFolder.isEmpty ? userHome : projectFolder
        let n = Name.self
        return """
        You are an autonomous macOS agent for \(userName).
        
        CORE RULES:
        - Act, don't explain. Never ask questions. Call \(n.taskComplete) when done.
        - Don't repeat script stdout — user sees it live.
        - NEVER output code as text — use \(n.createAgentScript)/\(n.updateAgentScript) for scripts, \(n.writeFile)/\(n.editFile) for files.
        - Current folder: \(folder) (default for operations)
        
        TOOL PRIORITY:
        1. Native tools (\(n.readFile), \(n.writeFile), \(n.editFile), git_*, xcode_*)
        2. MCP tools (mcp_*)
        3. Shell (\(n.executeAgentCommand), \(n.executeDaemonCommand)) ONLY if native/MCP unavailable
        
        TCC PERMISSIONS:
        - Full TCC in Agent: \(n.runAgentScript), \(n.appleEventQuery), \(n.runApplescript), \(n.runOsascript), ax_*
        - User shell: \(n.executeAgentCommand) (as \(userName), ~=\(userHome)) — NO TCC
        - Root shell: \(n.executeDaemonCommand) — NO TCC
        Never use shell commands for Automation/Accessibility — no TCC.
        
        KEY TOOL CATEGORIES:
        • File/Diff: \(n.readFile), \(n.writeFile), \(n.editFile), \(n.listFiles), \(n.searchFiles), \(n.createDiff), \(n.applyDiff)
        • Git: \(n.gitStatus), \(n.gitDiff), \(n.gitLog), \(n.gitCommit), \(n.gitDiffPatch), \(n.gitBranch)
        • Xcode: \(n.xcodeBuild) (PREFERRED) → MCP → xcodebuild shell (LAST RESORT)
        • Agent Scripts (100% Swift, ScriptingBridge only for app automation): \(n.listAgentScripts), \(n.readAgentScript), \(n.createAgentScript), \(n.updateAgentScript), \(n.runAgentScript), \(n.deleteAgentScript), \(n.combineAgentScripts)
        • Automation: \(n.runApplescript), \(n.runOsascript), \(n.executeJavascript), \(n.appleEventQuery), \(n.lookupSdef)
        • Accessibility: ax_* tools (last resort for UI)
        • Web: web_*, selenium_*
        
        CRITICAL DON'Ts:
        - Never use shell for file/coding when native tools exist
        - Never use xcodebuild/swift build via shell when \(n.xcodeBuild) or MCP available
        - Never use \(n.executeAgentCommand) for AX/Automation (use \(n.runAgentScript))
        - Never build AgentScripts with \(n.xcodeBuild) (use \(n.runAgentScript))
        
        ALWAYS: \(n.xcodeBuild) → MCP → Shell (last resort)
        """
    }

    /// Brief descriptions + examples of each enabled Apple AI tool.
    @MainActor private static func enabledAppleAIToolDescriptions() -> String {
        let prefs = ToolPreferencesService.shared
        return (commonTools + conversationTools)
            .filter { prefs.isEnabled(.foundationModel, $0.name) }
            .compactMap { tool -> String? in
                guard let example = toolExamples[tool.name] else { return nil }
                return example
            }
            .joined(separator: "\n")
    }

    /// Concrete examples for each tool shown in the Apple AI compact prompt.
    private static let toolExamples: [String: String] = [
        Name.executeAgentCommand:  #"execute_agent_command {"command": "ls -la"}"#,
        Name.executeDaemonCommand: #"execute_daemon_command {"command": "whoami"}"#,
        Name.runApplescript:       #"run_applescript {"source": "tell application \"Finder\" to get name of home"}"#,
        Name.runOsascript:         #"run_osascript {"script": "display dialog \"Hello\""}"#,
        Name.executeJavascript:    #"execute_javascript {"source": "var app = Application.currentApplication(); app.includeStandardAdditions = true; app.displayDialog('Hello')"}"#,
        Name.readFile:             #"read_file {"file_path": "/Users/toddbruss/Documents/example.txt"}"#,
        Name.writeFile:            #"write_file {"file_path": "/Users/toddbruss/Documents/out.txt", "content": "hello"}"#,
        Name.editFile:             #"edit_file {"file_path": "/path/file.txt", "old_string": "old", "new_string": "new"}"#,
        Name.createDiff:           #"create_diff {"source": "old text", "destination": "new text"}"#,
        Name.applyDiff:            #"apply_diff {"file_path": "/path/file.txt", "diff": "📎 line1\n❌ old\n✅ new\n📎 line3"}"#,
        Name.listFiles:            #"list_files {"pattern": "*.swift", "path": "/Users/toddbruss/Documents"}"#,
        Name.searchFiles:          #"search_files {"pattern": "TODO", "path": "/Users/toddbruss/Documents"}"#,
        Name.taskComplete:         #"task_complete {"summary": "Done"}"#,
        Name.gitStatus:            #"git_status {"path": "/Users/toddbruss/Documents/GitHub/MyRepo"}"#,
        Name.gitCommit:            #"git_commit {"path": "/Users/toddbruss/Documents/GitHub/MyRepo", "message": "fix: update"}"#,
        Name.appleEventQuery:      #"apple_event_query {"bundle_id": "com.apple.Music", "action": "get", "key": "currentTrack"}"#,
        Name.runAgentScript:       #"run_agent_script {"name": "MyScript"}"#,
        Name.listAgentScripts:     "list_agent_scripts",
        Name.readAgentScript:      #"read_agent_script {"name": "MyScript"}"#,
        Name.createAgentScript:    #"create_agent_script {"name": "MyScript", "content": "..."}"#,
        Name.updateAgentScript:    #"update_agent_script {"name": "MyScript", "content": "..."}"#,
        Name.deleteAgentScript:    #"delete_agent_script {"name": "MyScript"}"#,
        Name.combineAgentScripts:  #"combine_agent_scripts {"source_a": "ScriptA", "source_b": "ScriptB", "target": "Combined"}"#,
        Name.lookupSdef:           #"lookup_sdef {"bundle_id": "com.apple.Music"}"#,
        Name.xcodeBuild:           #"xcode_build {"project_path": "/path/to/MyApp.xcodeproj"}"#,
        Name.xcodeListProjects:    "xcode_list_projects",
        Name.xcodeSelectProject:   #"xcode_select_project {"number": 1}"#,
        Name.xcodeRun:             #"xcode_run {"project_path": "/path/to/MyApp.xcodeproj"}"#,
        Name.xcodeGrantPermission: "xcode_grant_permission",
        Name.axListWindows:        "ax_list_windows",
        Name.axCheckPermission:    "ax_check_permission",
        Name.axRequestPermission:  "ax_request_permission",
        Name.axInspectElement:     #"ax_inspect_element {"x": 100, "y": 200}"#,
        Name.axClick:              #"ax_click {"x": 100, "y": 200}"#,
        Name.axTypeText:           #"ax_type_text {"text": "hello"}"#,
        Name.axPressKey:           #"ax_press_key {"keyCode": 36}"#,
        Name.axScreenshot:         "ax_screenshot",
        Name.axGetAuditLog:        "ax_get_audit_log",
        Name.axSetProperties:      #"ax_set_properties {"properties": {"AXValue": "hello"}}"#,
        Name.axFindElement:        #"ax_find_element {"role": "AXButton", "title": "Submit"}"#,
        Name.axGetFocusedElement:  "ax_get_focused_element",
        Name.axGetChildren:        #"ax_get_children {"role": "AXWindow"}"#,
        Name.axDrag:               #"ax_drag {"fromX": 100, "fromY": 100, "toX": 200, "toY": 200}"#,
        Name.axWaitForElement:     #"ax_wait_for_element {"role": "AXButton", "timeout": 5}"#,
        Name.axClickElement:       #"ax_click_element {"role": "AXButton", "title": "Submit"}"#,
        Name.axWaitAdaptive:       #"ax_wait_adaptive {"role": "AXTextField", "timeout": 10}"#,
        Name.axTypeIntoElement:    #"ax_type_into_element {"role": "AXTextField", "text": "hello@example.com"}"#,
        Name.axHighlightElement:   #"ax_highlight_element {"role": "AXButton", "title": "Submit", "duration": 2.0}"#,
        Name.axGetWindowFrame:     #"ax_get_window_frame {"windowId": 1234}"#,
        Name.axShowMenu:           #"ax_show_menu {"x": 100, "y": 200}"#,
        Name.listAppleScripts:     "list_apple_scripts",
        Name.runAppleScript:       #"run_apple_script {"name": "Greeting"}"#,
        Name.saveAppleScript:      #"save_apple_script {"name": "Greeting", "source": "display dialog \"Hello!\""}"#,
        Name.deleteAppleScript:    #"delete_apple_script {"name": "Greeting"}"#,
        Name.listJavascript:       "list_javascript",
        Name.runJavascript:        #"run_javascript {"name": "HelloJXA"}"#,
        Name.saveJavascript:       #"save_javascript {"name": "HelloJXA", "source": "var app = Application.currentApplication(); app.includeStandardAdditions = true; app.displayDialog('Hello')"}"#,
        Name.deleteJavascript:     #"delete_javascript {"name": "HelloJXA"}"#,
        Name.listNativeTools:      "list_tools",
        Name.listMcpTools:         "list_mcp_tools",
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
        // --- Coding Tools ---
        ToolDef(
            name: Name.readFile,
            description: "Read file contents with line numbers. Use instead of `cat`. Returns numbered lines for easy reference in edit_file.",
            properties: [
                "file_path": ["type": "string", "description": "Absolute path to the file to read"],
                "offset": ["type": "integer", "description": "1-based line number to start from (default 1)"],
                "limit": ["type": "integer", "description": "Max lines to return (default 2000)"],
            ],
            required: ["file_path"]
        ),
        ToolDef(
            name: Name.writeFile,
            description: "Create or overwrite a file. Creates parent dirs automatically. Returns line count only — call read_file after to verify content.",
            properties: [
                "file_path": ["type": "string", "description": "Absolute path to the file to write"],
                "content": ["type": "string", "description": "The full file content to write"],
            ],
            required: ["file_path", "content"]
        ),
        ToolDef(
            name: Name.editFile,
            description: "Replace exact text in a file. Use instead of sed/awk. You MUST read_file first. The old_string must be unique unless replace_all is true.",
            properties: [
                "file_path": ["type": "string", "description": "Absolute path to the file to edit"],
                "old_string": ["type": "string", "description": "The exact text to find and replace"],
                "new_string": ["type": "string", "description": "The replacement text"],
                "replace_all": ["type": "boolean", "description": "Replace all occurrences (default false)"],
            ],
            required: ["file_path", "old_string", "new_string"]
        ),
        ToolDef(
            name: Name.createDiff,
            description: "Compare two text strings and return a pretty D1F diff showing retained, deleted, and inserted lines with emoji markers.",
            properties: [
                "source": ["type": "string", "description": "The original text"],
                "destination": ["type": "string", "description": "The modified text"],
            ],
            required: ["source", "destination"]
        ),
        ToolDef(
            name: Name.applyDiff,
            description: "Apply a D1F ASCII diff (📎 retain, ❌ delete, ✅ insert) to a file. The diff must use emoji line prefixes. Returns the patched file content.",
            properties: [
                "file_path": ["type": "string", "description": "Absolute path to the file to patch"],
                "diff": ["type": "string", "description": "D1F ASCII diff text with 📎/❌/✅ line prefixes"],
            ],
            required: ["file_path", "diff"]
        ),
        ToolDef(
            name: Name.listFiles,
            description: "Find files matching a glob pattern. Use instead of `find`. Excludes hidden files and .build directories.",
            properties: [
                "pattern": ["type": "string", "description": "Glob pattern (e.g. \"*.swift\", \"Package.swift\")"],
                "path": ["type": "string", "description": "Directory to search in (default: user home). Always provide a project path for best results."],
            ],
            required: ["pattern"]
        ),
        ToolDef(
            name: Name.searchFiles,
            description: "Search file contents by regex pattern. Use instead of `grep`. Returns matching lines with file paths and line numbers.",
            properties: [
                "pattern": ["type": "string", "description": "Regex pattern to search for"],
                "path": ["type": "string", "description": "Directory to search in (default: user home). Always provide a project path for best results."],
                "include": ["type": "string", "description": "File glob filter (e.g. \"*.swift\", \"*.py\")"],
            ],
            required: ["pattern"]
        ),
        // --- Git Tools ---
        ToolDef(
            name: Name.gitStatus,
            description: "Show current branch, staged/unstaged changes, and untracked files.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.gitDiff,
            description: "Show file changes as a unified diff. Can show staged changes, unstaged changes, or diff against a branch/commit.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "staged": ["type": "boolean", "description": "Show staged changes only (default false)"],
                "target": ["type": "string", "description": "Branch, commit, or ref to diff against (e.g. \"main\", \"HEAD~3\")"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.gitLog,
            description: "Show recent commit history as one-line summaries.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "count": ["type": "integer", "description": "Number of commits to show (default 20, max 100)"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.gitCommit,
            description: "Stage files and create a commit. If no files specified, stages all changes.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "message": ["type": "string", "description": "Commit message"],
                "files": ["type": "array", "items": ["type": "string"] as [String: Any], "description": "Specific files to stage (default: all changes)"] as [String: Any],
            ],
            required: ["message"]
        ),
        ToolDef(
            name: Name.gitDiffPatch,
            description: "Apply a unified diff patch to files in the repository. Use for complex multi-line edits that are easier to express as a patch.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "patch": ["type": "string", "description": "Unified diff patch content"],
            ],
            required: ["patch"]
        ),
        ToolDef(
            name: Name.gitBranch,
            description: "Create a new git branch, optionally switching to it.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "name": ["type": "string", "description": "Branch name to create"],
                "checkout": ["type": "boolean", "description": "Switch to the new branch (default true)"],
            ],
            required: ["name"]
        ),
        // --- Coding: Xcode ---
        ToolDef(
            name: Name.xcodeBuild,
            description: "Build an Xcode project or workspace via ScriptingBridge. Blocks until build completes. Returns errors/warnings in file:line:col format with code snippets for context.",
            properties: [
                "project_path": ["type": "string", "description": "Path to .xcodeproj or .xcworkspace"],
            ],
            required: ["project_path"]
        ),
        ToolDef(
            name: Name.xcodeRun,
            description: "Build then run an Xcode project via ScriptingBridge. Builds first — only runs if clean. Returns errors if build fails.",
            properties: [
                "project_path": ["type": "string", "description": "Path to .xcodeproj or .xcworkspace"],
            ],
            required: ["project_path"]
        ),
        ToolDef(
            name: Name.xcodeListProjects,
            description: "List all open Xcode projects and workspaces with numbered indices. Use the number with xcode_select_project to choose one.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: Name.xcodeSelectProject,
            description: "Select an open Xcode project by its number from xcode_list_projects. Returns the project path for use with xcode_build/xcode_run.",
            properties: [
                "number": ["type": "integer", "description": "Project number from the list (1-based)"],
            ],
            required: ["number"]
        ),
        ToolDef(
            name: Name.xcodeGrantPermission,
            description: "Grant macOS Automation permission so the agent can control Xcode via ScriptingBridge. Run this once before using xcode_build or xcode_run.",
            properties: [:],
            required: []
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
            description: "Execute a shell command with ROOT privileges via the privileged daemon. NO TCC. Only use when root is required: system packages, /System or /Library modifications, disk operations.",
            properties: [
                "command": ["type": "string", "description": "The bash command to execute as root"],
            ],
            required: ["command"]
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
        ToolDef(
            name: Name.listAgentScripts,
            description: "List all Swift automation scripts in ~/Documents/AgentScript/agents/. Scripts can be 100% Swift — ScriptingBridge is only needed for automating apps with AppleScript dictionaries.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: Name.readAgentScript,
            description: "Read the source code of a Swift automation script.",
            properties: [
                "name": ["type": "string", "description": "Script name (with or without .swift)"],
            ],
            required: ["name"]
        ),
        ToolDef(
            name: Name.createAgentScript,
            description: "Create a new Swift script in ~/Documents/AgentScript/agents/. Scripts can be 100% Swift for any task. ScriptingBridge is only needed when automating apps with AppleScript dictionaries.",
            properties: [
                "name": ["type": "string", "description": "Script filename (with or without .swift)"],
                "content": ["type": "string", "description": "Swift source code"],
            ],
            required: ["name", "content"]
        ),
        ToolDef(
            name: Name.updateAgentScript,
            description: "Update an existing Swift script. Scripts can be 100% Swift — ScriptingBridge only needed for app automation.",
            properties: [
                "name": ["type": "string", "description": "Script filename"],
                "content": ["type": "string", "description": "New Swift source code"],
            ],
            required: ["name", "content"]
        ),
        ToolDef(
            name: Name.runAgentScript,
            description: "Compile and run a Swift dylib with full TCC. Scripts can be 100% Swift for any task — ScriptingBridge is only needed when automating apps with AppleScript dictionaries. Use existing scripts first (list_agent_scripts). For app automation: use lookup_sdef to check dictionaries, create ScriptingBridge protocols. NSAppleScript fallback if ScriptingBridge has issues. Output streams live — do NOT repeat stdout.",
            properties: [
                "name": ["type": "string", "description": "Script filename (without .swift)"],
                "arguments": ["type": "string", "description": "Simple string passed via AGENT_SCRIPT_ARGS env var. For complex data, use JSON files instead."],
            ],
            required: ["name"]
        ),
        ToolDef(
            name: Name.deleteAgentScript,
            description: "Delete a Swift automation script.",
            properties: [
                "name": ["type": "string", "description": "Script filename"],
            ],
            required: ["name"]
        ),
        ToolDef(
            name: Name.combineAgentScripts,
            description: "Combine two Swift scripts into one. Reads both, deduplicates imports, merges the code, and writes the result to the target script.",
            properties: [
                "source_a": ["type": "string", "description": "First script name (with or without .swift)"],
                "source_b": ["type": "string", "description": "Second script name (with or without .swift)"],
                "target": ["type": "string", "description": "Output script name (with or without .swift). Can be one of the sources or a new name."],
            ],
            required: ["source_a", "source_b", "target"]
        ),
        // --- Automation: AppleScript & osascript ---
        ToolDef(
            name: Name.runApplescript,
            description: "Execute AppleScript code in-process via NSAppleScript with full TCC. Use lookup_sdef first to get correct terminology. For quick automation that doesn't need a compiled AgentScript.",
            properties: [
                "source": ["type": "string", "description": "AppleScript source code to execute"],
            ],
            required: ["source"]
        ),
        ToolDef(
            name: Name.runOsascript,
            description: "Run AppleScript source code via osascript in-process with full TCC. Use for app automation via AppleScript. Prefer run_applescript or run_agent_script when available.",
            properties: [
                "script": ["type": "string", "description": "AppleScript source code to execute"],
            ],
            required: ["script"]
        ),
        ToolDef(
            name: Name.executeJavascript,
            description: "Run JavaScript for Automation (JXA) code via osascript. Use for app automation with JavaScript syntax. Example: var app = Application('Finder'); app.selection()",
            properties: [
                "source": ["type": "string", "description": "JXA source code to execute"],
            ],
            required: ["source"]
        ),
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
        // --- Automation: SDEF Lookup ---
        ToolDef(
            name: Name.lookupSdef,
            description: "Read an app's SDEF scripting dictionary. ALWAYS use this to read SDEFs — never use shell commands to find .sdef files. Returns commands, classes, properties, elements, and enums. Use before writing osascript, NSAppleScript, apple_event_query, or ScriptingBridge code.",
            properties: [
                "bundle_id": ["type": "string", "description": "App bundle identifier (e.g. com.apple.Music). Use 'list' to see all available SDEFs."],
                "class_name": ["type": "string", "description": "Optional: get details for a specific class (e.g. 'track', 'application')"],
            ],
            required: ["bundle_id"]
        ),
        // --- Saved AppleScripts ---
        ToolDef(
            name: Name.listAppleScripts,
            description: "List all saved AppleScript files in ~/Documents/AgentScript/applescript/.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: Name.runAppleScript,
            description: "Run a saved AppleScript by name. List first with list_apple_scripts.",
            properties: [
                "name": ["type": "string", "description": "Name of the saved AppleScript (without .applescript extension)"],
            ],
            required: ["name"]
        ),
        ToolDef(
            name: Name.saveAppleScript,
            description: "Save an AppleScript to ~/Documents/AgentScript/applescript/ for reuse.",
            properties: [
                "name": ["type": "string", "description": "Name for the script (without .applescript extension)"],
                "source": ["type": "string", "description": "AppleScript source code"],
            ],
            required: ["name", "source"]
        ),
        ToolDef(
            name: Name.deleteAppleScript,
            description: "Delete a saved AppleScript file.",
            properties: [
                "name": ["type": "string", "description": "Name of the saved AppleScript to delete"],
            ],
            required: ["name"]
        ),
        // --- Saved JavaScript/JXA ---
        ToolDef(
            name: Name.listJavascript,
            description: "List all saved JavaScript (JXA) files in ~/Documents/AgentScript/javascript/.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: Name.runJavascript,
            description: "Run a saved JavaScript (JXA) script by name. List first with list_javascript.",
            properties: [
                "name": ["type": "string", "description": "Name of the saved script (without .js extension)"],
            ],
            required: ["name"]
        ),
        ToolDef(
            name: Name.saveJavascript,
            description: "Save a JXA script to ~/Documents/AgentScript/javascript/ for reuse.",
            properties: [
                "name": ["type": "string", "description": "Name for the script (without .js extension)"],
                "source": ["type": "string", "description": "JavaScript for Automation source code"],
            ],
            required: ["name", "source"]
        ),
        ToolDef(
            name: Name.deleteJavascript,
            description: "Delete a saved JavaScript (JXA) file.",
            properties: [
                "name": ["type": "string", "description": "Name of the saved script to delete"],
            ],
            required: ["name"]
        ),
        // --- Accessibility Tools ---
        ToolDef(
            name: Name.axListWindows,
            description: "List all visible windows from all applications with their positions and sizes. Returns JSON array with window ID, owner PID, owner name, window name, and bounds.",
            properties: [
                "limit": ["type": "integer", "description": "Maximum number of windows to return (default 50)"],
            ],
            required: []
        ),
        /* ax_inspect_element — use ax_get_properties instead (more flexible)
        ToolDef(
            name: Name.axInspectElement,
            description: "Inspect accessibility element at a screen coordinate. Returns the accessibility hierarchy for the element at position (x, y).",
            properties: [
                "x": ["type": "number", "description": "Screen X coordinate"],
                "y": ["type": "number", "description": "Screen Y coordinate"],
                "depth": ["type": "integer", "description": "How deep to traverse the hierarchy (default 3)"],
            ],
            required: ["x", "y"]
        ), */
        ToolDef(
            name: Name.axGetProperties,
            description: "Get all properties of an accessibility element. Can find by role/title/value or by screen position. CRITICAL: If you just used ax_wait_for_element or ax_find_element, pass the SAME role/title/value parameters to this function.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXButton', 'AXTextField')"],
                "title": ["type": "string", "description": "Title or name to match (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match) - useful for text fields with specific content"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "x": ["type": "number", "description": "Screen X coordinate for position-based lookup"],
                "y": ["type": "number", "description": "Screen Y coordinate for position-based lookup"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.axPerformAction,
            description: "Perform an accessibility action on an element. SECURITY: Protected roles (AXSecureTextField, AXPasswordField) can be disabled in Accessibility Settings. CRITICAL: If you just used ax_wait_for_element or ax_find_element, pass the SAME role/title/value parameters to this function - the element locator must match exactly.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXButton', 'AXTextField')"],
                "title": ["type": "string", "description": "Title to match (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match) - useful for text fields with specific content"],
                "appBundleId": ["type": "string", "description": "Bundle ID of the target app"],
                "x": ["type": "number", "description": "Screen X coordinate for position-based lookup"],
                "y": ["type": "number", "description": "Screen Y coordinate for position-based lookup"],
                "action": ["type": "string", "description": "Accessibility action to perform (e.g., 'AXPress', 'AXConfirm')"],
            ],
            required: ["action"]
        ),
        /* ax_check_permission / ax_request_permission — one-time setup, not needed for automation
        ToolDef(
            name: Name.axCheckPermission,
            description: "Check if Accessibility permission is granted to Agent.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: Name.axRequestPermission,
            description: "Request Accessibility permission. Shows the macOS system prompt for the user to approve.",
            properties: [:],
            required: []
        ), */
        // --- Accessibility Input Simulation (Phase 2) ---
        ToolDef(
            name: Name.axTypeText,
            description: "Simulate typing text at the current cursor position or at specific coordinates. Uses CGEvent keyboard simulation.",
            properties: [
                "text": ["type": "string", "description": "Text to type"],
                "x": ["type": "number", "description": "Optional X coordinate to click first before typing"],
                "y": ["type": "number", "description": "Optional Y coordinate to click first before typing"],
            ],
            required: ["text"]
        ),
        ToolDef(
            name: Name.axClick,
            description: "Simulate a mouse click at screen coordinates.",
            properties: [
                "x": ["type": "number", "description": "Screen X coordinate (required)"],
                "y": ["type": "number", "description": "Screen Y coordinate (required)"],
                "button": ["type": "string", "description": "Mouse button: 'left' (default), 'right', or 'middle'"],
                "clicks": ["type": "integer", "description": "Number of clicks: 1 (default) or 2 for double-click"],
            ],
            required: ["x", "y"]
        ),
        /* ax_scroll — can use ax_press_key with arrow keys instead
        ToolDef(
            name: Name.axScroll,
            description: "Simulate scroll wheel at screen coordinates.",
            properties: [
                "x": ["type": "number", "description": "Screen X coordinate"],
                "y": ["type": "number", "description": "Screen Y coordinate"],
                "deltaX": ["type": "integer", "description": "Horizontal scroll amount (positive = right, negative = left)"],
                "deltaY": ["type": "integer", "description": "Vertical scroll amount (positive = down, negative = up)"],
            ],
            required: ["x", "y"]
        ), */
        ToolDef(
            name: Name.axPressKey,
            description: "Simulate pressing a key with optional modifiers (Cmd, Option, Control, Shift).",
            properties: [
                "keyCode": ["type": "integer", "description": "macOS virtual key code (e.g., 36=Return, 48=Tab, 51=Delete, 53=Escape, 123-126=Arrow keys)"],
                "modifiers": ["type": "array", "description": "Array of modifier keys: 'command', 'option', 'control', 'shift'", "items": ["type": "string"]],
            ],
            required: ["keyCode"]
        ),
        // --- Accessibility Screenshots (Phase 4) ---
        ToolDef(
            name: Name.axScreenshot,
            description: "Capture a screenshot of a screen region or specific window. Requires Screen Recording permission. Returns the path to the saved PNG file.",
            properties: [
                "x": ["type": "number", "description": "X coordinate of region (optional, required for region capture)"],
                "y": ["type": "number", "description": "Y coordinate of region (optional, required for region capture)"],
                "width": ["type": "number", "description": "Width of region (optional, required for region capture)"],
                "height": ["type": "number", "description": "Height of region (optional, required for region capture)"],
                "windowId": ["type": "integer", "description": "Window ID to capture (optional, from ax_list_windows)"],
            ],
            required: []
        ),
        /* ax_get_audit_log — debugging only, not needed for automation
        ToolDef(
            name: Name.axGetAuditLog,
            description: "Get recent accessibility audit log entries. Shows recent accessibility operations performed by the agent.",
            properties: [
                "limit": ["type": "integer", "description": "Maximum number of entries to return (default 50)"],
            ],
            required: []
        ), */
        // --- Accessibility Set Properties (Phase 6) ---
        ToolDef(
            name: Name.axSetProperties,
            description: "Set accessibility property values on an element. CRITICAL for setting text fields, selections, slider values, etc. Can find element by role/title/value, by position, or within a specific app. CRITICAL: If you just used ax_wait_for_element or ax_find_element, pass the SAME role/title/value parameters to this function.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXTextField', 'AXSlider')"],
                "title": ["type": "string", "description": "Title or name to match (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match) - useful for text fields with specific content"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "x": ["type": "number", "description": "Screen X coordinate for position-based lookup"],
                "y": ["type": "number", "description": "Screen Y coordinate for position-based lookup"],
                "properties": ["type": "object", "description": "Properties to set as key-value pairs. Common: 'AXValue' for text, 'AXSelected' for selection, 'AXValue' (with position dict) for sliders"],
            ],
            required: ["properties"]
        ),
        // --- Accessibility Find Element (Phase 6) ---
        ToolDef(
            name: Name.axFindElement,
            description: "Find an accessibility element by role, title, or value with optional timeout. Returns element properties when found. Useful for waiting for UI elements to appear.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXButton', 'AXTextField')"],
                "title": ["type": "string", "description": "Title or name to match (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match in element's AXValue)"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "timeout": ["type": "number", "description": "Maximum seconds to wait for element (default 5.0)"],
            ],
            required: []
        ),
        /* ax_get_focused_element — niche, ax_get_properties covers this
        ToolDef(
            name: Name.axGetFocusedElement,
            description: "Get the currently focused accessibility element. Can optionally filter by app. Returns element properties.",
            properties: [
                "appBundleId": ["type": "string", "description": "Optional bundle ID to get focused element within a specific app"],
            ],
            required: []
        ), */
        // --- Accessibility Get Children (Phase 6) ---
        ToolDef(
            name: Name.axGetChildren,
            description: "Get all children of an accessibility element. Useful for exploring UI hierarchy. CRITICAL: If you just used ax_wait_for_element or ax_find_element, pass the SAME role/title/value parameters to this function.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find parent element"],
                "title": ["type": "string", "description": "Title to match for parent element (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match) - useful for text fields with specific content"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "x": ["type": "number", "description": "Screen X coordinate for position-based parent lookup"],
                "y": ["type": "number", "description": "Screen Y coordinate for position-based parent lookup"],
                "depth": ["type": "integer", "description": "How deep to traverse children (default 3)"],
            ],
            required: []
        ),
        /* ax_drag — very niche, rarely needed for automation
        ToolDef(
            name: Name.axDrag,
            description: "Perform a drag operation from one point to another. Simulates mouse down, drag, and mouse up.",
            properties: [
                "fromX": ["type": "number", "description": "Starting X coordinate"],
                "fromY": ["type": "number", "description": "Starting Y coordinate"],
                "toX": ["type": "number", "description": "Ending X coordinate"],
                "toY": ["type": "number", "description": "Ending Y coordinate"],
                "button": ["type": "string", "description": "Mouse button: 'left' (default), 'right', or 'middle'"],
            ],
            required: ["fromX", "fromY", "toX", "toY"]
        ), */
        /* ax_wait_for_element — ax_find_element already has timeout polling
        ToolDef(
            name: Name.axWaitForElement,
            description: "Wait for an accessibility element to appear, polling periodically until found or timeout. Returns element properties when found. CRITICAL: When calling ax_perform_action or ax_set_properties after this, use the SAME role/title/value parameters to locate the element.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXButton', 'AXTextField')"],
                "title": ["type": "string", "description": "Title or name to match (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match) - useful for text fields"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "timeout": ["type": "number", "description": "Maximum seconds to wait (default 10.0)"],
                "pollInterval": ["type": "number", "description": "Seconds between polls (default 0.5)"],
            ],
            required: []
        ), */
        /* ax_show_menu — can use ax_click with right button or ax_perform_action AXShowMenu
        ToolDef(
            name: Name.axShowMenu,
            description: "Show context menu for an element. Uses AXShowMenu action if available, otherwise simulates right-click at element center. Protected roles can be disabled in Accessibility Settings. CRITICAL: If you just used ax_wait_for_element or ax_find_element, pass the SAME role/title/value parameters to this function.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find element"],
                "title": ["type": "string", "description": "Title to match for element (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match) - useful for text fields with specific content"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "x": ["type": "number", "description": "Screen X coordinate for position-based lookup"],
                "y": ["type": "number", "description": "Screen Y coordinate for position-based lookup"],
            ],
            required: []
        ), */
        /* ax_click_element — ax_find_element + ax_click covers this
        ToolDef(
            name: Name.axClickElement,
            description: "Click an element by finding it semantically (role/title) and clicking its center.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find"],
                "title": ["type": "string", "description": "Title or name to match"],
                "value": ["type": "string", "description": "Value to match"],
                "appBundleId": ["type": "string", "description": "App bundle ID"],
                "timeout": ["type": "number", "description": "Max seconds to wait (default 5.0)"],
                "verify": ["type": "boolean", "description": "Capture screenshot for verification (default false)"],
            ],
            required: []
        ), */
        /* ax_wait_adaptive — ax_find_element with timeout covers this
        ToolDef(
            name: Name.axWaitAdaptive,
            description: "Wait for an element with exponential backoff polling.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find"],
                "title": ["type": "string", "description": "Title or name to match"],
                "value": ["type": "string", "description": "Value to match"],
                "appBundleId": ["type": "string", "description": "App bundle ID"],
                "timeout": ["type": "number", "description": "Max seconds to wait (default 10.0)"],
                "initialDelay": ["type": "number", "description": "Initial polling delay (default 0.1)"],
                "maxDelay": ["type": "number", "description": "Max polling delay (default 1.0)"],
            ],
            required: []
        ), */
        /* ax_type_into_element — ax_find_element + ax_type_text covers this
        ToolDef(
            name: Name.axTypeIntoElement,
            description: "Type text into an element found by role/title.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role of target element"],
                "title": ["type": "string", "description": "Title to match"],
                "text": ["type": "string", "description": "Text to type"],
                "appBundleId": ["type": "string", "description": "App bundle ID"],
                "verify": ["type": "boolean", "description": "Verify text was entered (default true)"],
            ],
            required: ["text"]
        ), */
        /* ax_highlight_element — debugging/visual only, not needed for automation
        ToolDef(
            name: Name.axHighlightElement,
            description: "Temporarily highlight an element on screen with a colored overlay.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find"],
                "title": ["type": "string", "description": "Title or name to match"],
                "value": ["type": "string", "description": "Value to match"],
                "appBundleId": ["type": "string", "description": "App bundle ID"],
                "x": ["type": "number", "description": "Screen X coordinate"],
                "y": ["type": "number", "description": "Screen Y coordinate"],
                "duration": ["type": "number", "description": "Highlight duration in seconds (default 2.0)"],
                "color": ["type": "string", "description": "Color: red, green, blue, yellow, purple (default green)"],
            ],
            required: []
        ), */
        /* ax_get_window_frame — ax_list_windows already returns bounds
        ToolDef(
            name: Name.axGetWindowFrame,
            description: "Get the exact position and frame of a window by its ID.",
            properties: [
                "windowId": ["type": "integer", "description": "Window ID from ax_list_windows"],
            ],
            required: ["windowId"]
        ), */
        // --- Tool Discovery ---
        ToolDef(
            name: Name.listNativeTools,
            description: "List all enabled native tools.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: Name.listMcpTools,
            description: "List all enabled MCP (Model Context Protocol) tools.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: Name.loadGroups,
            description: "Load tool groups into the active session. Available: Coding, Automation, Accessibility, Web.",
            properties: [
                "groups": ["type": "array", "items": ["type": "string"] as [String: Any], "description": "Group names to load"] as [String: Any],
            ],
            required: ["groups"]
        ),
        ToolDef(
            name: Name.unloadGroups,
            description: "Unload tool groups from the active session to reduce token usage.",
            properties: [
                "groups": ["type": "array", "items": ["type": "string"] as [String: Any], "description": "Group names to unload"] as [String: Any],
            ],
            required: ["groups"]
        ),
        // MARK: - Web Automation (Phase 2)
        ToolDef(
            name: Name.webOpen,
            description: "Open a URL in the specified browser. Uses AppleScript for Safari/Firefox, falls back to NSWorkspace for others. Fastest way to open URLs in web automation.",
            properties: [
                "url": ["type": "string", "description": "URL to open"],
                "browser": ["type": "string", "description": "Browser type: 'safari' (default), 'chrome', 'firefox', 'edge'"],
            ],
            required: ["url"]
        ),
        ToolDef(
            name: Name.webFind,
            description: "Find an element on a web page using the best available strategy. Auto-selects: Accessibility (Safari AX) → JavaScript (Safari/Firefox) → Selenium. Supports CSS selectors, XPath, and accessibility attributes. Returns element properties with source strategy.",
            properties: [
                "selector": ["type": "string", "description": "Element selector: CSS (#id, .class), XPath (//div), or accessibility (AXButton, [title='Submit'])"],
                "strategy": ["type": "string", "description": "Strategy: 'auto' (default), 'accessibility', 'javascript', 'selenium'"],
                "timeout": ["type": "number", "description": "Maximum wait time in seconds (default 10.0)"],
                "fuzzyThreshold": ["type": "number", "description": "Minimum match score 0-1 for fuzzy matching (default 0.6)"],
                "appBundleId": ["type": "string", "description": "Optional browser bundle ID (auto-detected if not specified)"],
            ],
            required: ["selector"]
        ),
        ToolDef(
            name: Name.webClick,
            description: "Click a web element by selector. Auto-selects best strategy: AX click, JavaScript click, or Selenium click. Use after web_find to verify element exists.",
            properties: [
                "selector": ["type": "string", "description": "Element selector to click"],
                "strategy": ["type": "string", "description": "Strategy: 'auto' (default), 'accessibility', 'javascript', 'selenium'"],
                "appBundleId": ["type": "string", "description": "Optional browser bundle ID"],
            ],
            required: ["selector"]
        ),
        ToolDef(
            name: Name.webType,
            description: "Type text into a web element by selector. Auto-selects best strategy: AXValue set (fastest), JavaScript value set, or Selenium sendKeys. Verifies text was entered.",
            properties: [
                "selector": ["type": "string", "description": "Element selector for input field"],
                "text": ["type": "string", "description": "Text to type"],
                "strategy": ["type": "string", "description": "Strategy: 'auto' (default), 'accessibility', 'javascript', 'selenium'"],
                "verify": ["type": "boolean", "description": "Verify text was entered (default true)"],
                "appBundleId": ["type": "string", "description": "Optional browser bundle ID"],
            ],
            required: ["selector", "text"]
        ),
        ToolDef(
            name: Name.webExecuteJs,
            description: "Execute JavaScript in the active browser. Works in Safari and Firefox via AppleScript, Chrome via Selenium. Returns the result of the script execution.",
            properties: [
                "script": ["type": "string", "description": "JavaScript code to execute"],
                "browser": ["type": "string", "description": "Browser bundle ID (auto-detected if not specified)"],
            ],
            required: ["script"]
        ),
        ToolDef(
            name: Name.webGetUrl,
            description: "Get the current URL from the active browser. Works via AppleScript for Safari/Firefox/Chrome or via Selenium session.",
            properties: [
                "browser": ["type": "string", "description": "Optional browser bundle ID"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.webGetTitle,
            description: "Get the page title from the active browser.",
            properties: [
                "browser": ["type": "string", "description": "Optional browser bundle ID"],
            ],
            required: []
        ),
        // MARK: - Selenium WebDriver Tools
        ToolDef(
            name: Name.seleniumStart,
            description: "Start a Selenium WebDriver session. SafariDriver is built into macOS. For Chrome/Firefox, install chromedriver/geckodriver. Returns session ID for subsequent calls.",
            properties: [
                "browser": ["type": "string", "description": "Browser: 'safari' (default), 'chrome', 'firefox'"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
                "capabilities": ["type": "object", "description": "Optional WebDriver capabilities"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.seleniumStop,
            description: "End the Selenium WebDriver session.",
            properties: [
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.seleniumNavigate,
            description: "Navigate to a URL via Selenium WebDriver. More reliable than AppleScript for complex pages.",
            properties: [
                "url": ["type": "string", "description": "URL to navigate to"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: ["url"]
        ),
        ToolDef(
            name: Name.seleniumFind,
            description: "Find element via Selenium WebDriver with CSS or XPath selector. Returns element ID for subsequent operations.",
            properties: [
                "strategy": ["type": "string", "description": "Locator strategy: 'css', 'xpath', 'id', 'name', 'linktext', 'tagname', 'classname'"],
                "value": ["type": "string", "description": "Selector value"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: ["strategy", "value"]
        ),
        ToolDef(
            name: Name.seleniumClick,
            description: "Click an element via Selenium WebDriver. More reliable for dynamically loaded content.",
            properties: [
                "strategy": ["type": "string", "description": "Locator strategy: 'css', 'xpath', 'id', 'name'"],
                "value": ["type": "string", "description": "Selector value"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: ["strategy", "value"]
        ),
        ToolDef(
            name: Name.seleniumType,
            description: "Type text into an element via Selenium WebDriver. Simulates actual keyboard input.",
            properties: [
                "strategy": ["type": "string", "description": "Locator strategy: 'css', 'xpath', 'id', 'name'"],
                "value": ["type": "string", "description": "Selector value"],
                "text": ["type": "string", "description": "Text to type"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: ["strategy", "value", "text"]
        ),
        ToolDef(
            name: Name.seleniumExecute,
            description: "Execute JavaScript in the Selenium session. Useful for scrolling, DOM manipulation, or extracting data.",
            properties: [
                "script": ["type": "string", "description": "JavaScript code to execute"],
                "args": ["type": "array", "description": "Optional arguments for the script", "items": ["type": "string"] as [String: Any]] as [String: Any],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: ["script"]
        ),
        ToolDef(
            name: Name.seleniumScreenshot,
            description: "Take a screenshot via Selenium WebDriver. Saves to ~/Documents/Agent/screenshots/.",
            properties: [
                "filename": ["type": "string", "description": "Screenshot filename (default: auto-generated)"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.seleniumWait,
            description: "Wait for an element to appear via Selenium WebDriver. Uses explicit wait with timeout.",
            properties: [
                "strategy": ["type": "string", "description": "Locator strategy: 'css', 'xpath', 'id', 'name'"],
                "value": ["type": "string", "description": "Selector value"],
                "timeout": ["type": "number", "description": "Maximum wait time in seconds (default 10.0)"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: ["strategy", "value"]
        ),
    ]

    // MARK: - Foundation Models Native Tools

    /// Create native FoundationModels.Tool objects for on-device Apple Intelligence.
    /// Each tool returns GeneratedContent as arguments, which the model populates with parameters.
    @MainActor static func nativeTools() -> [any Tool] {
        (commonTools + conversationTools).map { toolDef in
            NativeAgentTool(toolDef: toolDef)
        }
    }

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
            name: Name.webSearch,
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
            description: "Create or update a step-by-step plan. Writes a planning_mode_.md file to track progress. Use 'create' to start a plan, 'update' to change a step's status, 'read' to check progress.",
            properties: [
                "action": ["type": "string", "description": "Action: 'create', 'update', or 'read'"],
                "title": ["type": "string", "description": "Plan title (required for 'create')"],
                "steps": ["type": "string", "description": "Newline-separated list of steps (required for 'create')"],
                "step": ["type": "integer", "description": "Step number to update (required for 'update')"],
                "status": ["type": "string", "description": "New status for 'update': 'in_progress', 'completed', or 'failed'"],
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

// MARK: - Native Foundation Models Tool Wrapper

import FoundationModels

/// Output from tool execution - must be PromptRepresentable.
@Generable
struct AgentToolOutput: PromptRepresentable {
    let result: String
}

/// Native FoundationModels.Tool implementation that wraps Agent tool definitions.
/// When the model calls this tool, the framework invokes the call() method.
struct NativeAgentTool: Tool {
    typealias Arguments = GeneratedContent
    typealias Output = AgentToolOutput

    let name: String
    let description: String
    let parameters: GenerationSchema

    init(toolDef: AgentTools.ToolDef) {
        self.name = toolDef.name
        self.description = toolDef.description

        // Build GenerationSchema from tool's properties
        var props: [GenerationSchema.Property] = []
        for (key, schema) in toolDef.properties {
            let isRequired = toolDef.required.contains(key)
            let desc = (schema["description"] as? String) ?? ""
            let typeStr = (schema["type"] as? String) ?? "string"

            // Create property based on type
            let prop: GenerationSchema.Property
            switch typeStr {
            case "integer":
                prop = isRequired
                    ? GenerationSchema.Property(name: key, description: desc, type: Int.self)
                    : GenerationSchema.Property(name: key, description: desc, type: Int?.self)
            case "number":
                prop = isRequired
                    ? GenerationSchema.Property(name: key, description: desc, type: Double.self)
                    : GenerationSchema.Property(name: key, description: desc, type: Double?.self)
            case "boolean":
                prop = isRequired
                    ? GenerationSchema.Property(name: key, description: desc, type: Bool.self)
                    : GenerationSchema.Property(name: key, description: desc, type: Bool?.self)
            case "array":
                // Arrays - use [String] as generic array type
                prop = isRequired
                    ? GenerationSchema.Property(name: key, description: desc, type: [String].self)
                    : GenerationSchema.Property(name: key, description: desc, type: [String]?.self)
            default: // "string" or "object"
                prop = isRequired
                    ? GenerationSchema.Property(name: key, description: desc, type: String.self)
                    : GenerationSchema.Property(name: key, description: desc, type: String?.self)
            }
            props.append(prop)
        }

        // Create schema with all properties - use type: Never for object schemas
        self.parameters = GenerationSchema(type: String.self, description: toolDef.description, properties: props)
    }

    func call(arguments: GeneratedContent) async throws -> AgentToolOutput {
        // Extract arguments via Mirror reflection
        var input: [String: Any] = [:]
        let mirror = Mirror(reflecting: arguments)
        for child in mirror.children {
            guard let label = child.label else { continue }
            // Unwrap optionals
            let childMirror = Mirror(reflecting: child.value)
            if childMirror.displayStyle == .optional {
                if let first = childMirror.children.first {
                    input[label] = first.value
                }
            } else {
                input[label] = child.value
            }
        }
        // Route to handler for real execution
        if let handler = NativeToolContext.toolHandler {
            let result = await handler(name, input)
            return AgentToolOutput(result: result)
        }
        return AgentToolOutput(result: "Error: no tool handler configured")
    }
}
