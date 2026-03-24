import Foundation

/// Shared system prompt and tool definitions for all LLM providers.
/// ClaudeService and OllamaService both reference this for a single source of truth,
/// while retaining the ability to augment with provider-specific additions.
enum AgentTools {

    // MARK: - Tool Name Constants (single source of truth)
    enum Name {
        // File Tools
        static let readDir = "read_dir"
        // File (consolidated CRUDL)
        static let file = "file"
        // Legacy file names (handlers still work)
        static let readFile = "read_file"
        static let writeFile = "write_file"
        static let editFile = "edit_file"
        static let createDiff = "create_diff"
        static let applyDiff = "apply_diff"
        static let listFiles = "list_files"
        static let searchFiles = "search_files"
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
        // Agent Script (consolidated CRUDL)
        static let agentScript = "agent_script"
        // Legacy agent script names (handlers still work)
        static let listAgentScripts = "list_agent_scripts"
        static let readAgentScript = "read_agent_script"
        static let createAgentScript = "create_agent_script"
        static let updateAgentScript = "update_agent_script"
        static let runAgentScript = "run_agent_script"
        static let deleteAgentScript = "delete_agent_script"
        static let combineAgentScripts = "combine_agent_scripts"
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
        static let listMcpTools = "list_mcp_tools"
        static let loadGroups = "load_groups"
        static let unloadGroups = "unload_groups"
        // Web (consolidated CRUDL)
        static let web = "web"
        // Legacy web names (handlers still work)
        static let webOpen = "web_open"
        static let webFind = "web_find"
        static let webClick = "web_click"
        static let webType = "web_type"
        static let webExecuteJs = "web_execute_js"
        static let webGetUrl = "web_get_url"
        static let webGetTitle = "web_get_title"
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
        return """
        You are an autonomous macOS agent. User: "\(userName)", home: "\(userHome)". Project: \(folder).
        Call task_complete when done. Don't repeat stdout. Don't ask — just act.
        NEVER output code as text — use write_file/edit_file for files, agent_script (action: create/update) for scripts.

        DIRECT TOOLS (no action parameter): read_file, write_file, list_files, search_files, read_dir, task_complete, execute_agent_command, execute_daemon_command, apple_event_query.
        ACTION TOOLS (require "action" parameter):
        edit_file: edit, create, apply | file_manager: read, write, edit, list, search, read_dir, if_to_switch, extract_function | git: status, diff, log, commit, diff_patch, branch
        xcode: build, run, list_projects, select_project, add_file, remove_file | agent_script: list, read, create, update, run, delete, combine
        plan_mode: create, update, read, list, delete | applescript_tool: execute, lookup_sdef, list, run, save, delete
        javascript_tool: execute, list, run, save, delete | accessibility: list_windows, get_properties, perform_action, type_text, click, press_key, screenshot, set_properties, find_element, get_children
        web: open, find, click, type, execute_js, get_url, get_title | selenium: start, stop, navigate, find, click, type, execute, screenshot, wait

        CRITICAL RULES:
        - SHELL COMMANDS (rm, mv, cp, ls, find, grep, etc.): ALWAYS use execute_agent_command. NEVER create .sh scripts. NEVER use applescript_tool "do shell script".
        - BUILD: Use xcode (action: build). Never xcodebuild via shell.
        - applescript_tool is ONLY for AppleScript automation of apps (tell application...). NOT for shell commands.
        - For tasks with 3+ steps, create a plan_mode plan first. Execute every step. Don't mark done without writing files.

        SPLITTING FILES — follow this exact sequence for EACH new file:
        1. read_file the source file you will extract from
        2. write_file to create the new file with imports + extracted code
        3. xcode (action: add_file) to add it to the project
        4. edit_file to remove the extracted code from the original file (old_string must match the file EXACTLY — copy from the read_file output, never from memory)
        5. xcode (action: build) to verify it compiles
        6. Mark plan step completed ONLY if build succeeds
        Do ONE file at a time. Build between EVERY file. Never batch multiple files before building.

        TCC (in-process): agent_script (run), applescript_tool (execute), accessibility. NO TCC: execute_agent_command, execute_daemon_command.
        AGENT SCRIPTS: ~/Documents/AgentScript/agents/. 100% Swift. @_cdecl("script_main") public func scriptMain() -> Int32 { return 0 }
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
        macOS agent for \(userName). Project: \(folder). Call \(n.taskComplete) when done.
        TOOLS: \(n.readFile), \(n.writeFile), \(n.editFile), \(n.executeAgentCommand), \(n.agentScript) (list/read/create/update/run).
        Shell: \(n.executeAgentCommand) for rm/mv/cp/ls/grep. Don't repeat stdout.
        """
    }

    /// Concrete examples for each tool.
    private static let toolExamples: [String: String] = [
        Name.executeAgentCommand:  #"execute_agent_command {"command": "ls -la"}"#,
        Name.executeDaemonCommand: #"execute_daemon_command {"command": "whoami"}"#,
        Name.runApplescript:       #"run_applescript {"source": "tell application \"Finder\" to get name of home"}"#,
        Name.runOsascript:         #"run_osascript {"script": "display dialog \"Hello\""}"#,
        Name.executeJavascript:    #"execute_javascript {"source": "var app = Application.currentApplication(); app.includeStandardAdditions = true; app.displayDialog('Hello')"}"#,
        Name.readFile:             #"read_file {"file_path": "/Users/toddbruss/Documents/example.txt"}"#,
        Name.writeFile:            #"write_file {"file_path": "/Users/toddbruss/Documents/out.txt", "content": "hello"}"#,
        Name.editFile:             #"edit_file {"action": "edit", "file_path": "/path/file.txt", "old_string": "old", "new_string": "new"}"#,
        Name.createDiff:           #"edit_file {"action": "create", "source": "old text", "destination": "new text"}"#,
        Name.applyDiff:            #"edit_file {"action": "apply", "file_path": "/path/file.txt", "diff": "=line1\n-old\n+new\n=line3"}"#,
        Name.listFiles:            #"list_files {"pattern": "*.swift", "path": "/Users/toddbruss/Documents"}"#,
        Name.searchFiles:          #"search_files {"pattern": "TODO", "path": "/Users/toddbruss/Documents"}"#,
        Name.readDir:              #"read_dir {"path": "/Users/toddbruss/Documents"}"#,
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
            description: "Reads a file from the filesystem. By default reads up to 2000 lines from the beginning. When you already know which part of the file you need, only read that part using offset and limit.",
            properties: [
                "file_path": ["type": "string", "description": "Absolute path to the file to read"],
                "offset": ["type": "integer", "description": "The line number to start reading from (1-based). Only provide if the file is too large to read at once."],
                "limit": ["type": "integer", "description": "The number of lines to read (default 2000). Only provide if the file is too large to read at once."],
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
            description: "File editing and diffing. Actions: edit (replace text), create (compare strings), apply (apply diff). You MUST read_file first.",
            properties: [
                "action": ["type": "string", "description": "Action: edit, create, or apply"],
                "file_path": ["type": "string", "description": "Absolute path (for edit and apply)"],
                "old_string": ["type": "string", "description": "For edit: exact text to find"],
                "new_string": ["type": "string", "description": "For edit: replacement text"],
                "replace_all": ["type": "boolean", "description": "For edit: replace all occurrences (default false)"],
                "source": ["type": "string", "description": "For create: original text"],
                "destination": ["type": "string", "description": "For create: modified text"],
                "diff": ["type": "string", "description": "For apply: each line starts with = (keep), - (remove), or + (add) immediately followed by content. Example: =func hello() {\\n-    print(\"old\")\\n+    print(\"new\")\\n=}"],
            ],
            required: ["action"]
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
        ToolDef(
            name: Name.readDir,
            description: "List directory contents. Use instead of `ls`. Returns files and subdirectories with sizes.",
            properties: [
                "path": ["type": "string", "description": "Absolute path to directory to list"],
            ],
            required: ["path"]
        ),
        // --- File Manager (consolidated — maps to direct file tools) ---
        ToolDef(
            name: Name.fileManager,
            description: "File operations and refactoring. Actions: read, write, edit, create (diff), apply (diff), list, search, read_dir, if_to_switch, extract_function.",
            properties: [
                "action": ["type": "string", "description": "Action: read, write, edit, create, apply, list, search, read_dir, if_to_switch, or extract_function"],
                "file_path": ["type": "string", "description": "File path (for read/write/edit/apply)"],
                "path": ["type": "string", "description": "Directory path (for list/search/read_dir)"],
                "content": ["type": "string", "description": "For write: file content"],
                "old_string": ["type": "string", "description": "For edit: text to find"],
                "new_string": ["type": "string", "description": "For edit: replacement text"],
                "replace_all": ["type": "boolean", "description": "For edit: replace all (default false)"],
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
            description: "Xcode operations. Actions: build (auto-detects project), run, list_projects, select_project, add_file (add to pbxproj), remove_file (remove from pbxproj), grant_permission.",
            properties: [
                "action": ["type": "string", "description": "Action: build, run, list_projects, select_project, add_file, remove_file, or grant_permission"],
                "project_path": ["type": "string", "description": "For build/run: path (auto-detected if empty)"],
                "file_path": ["type": "string", "description": "For add_file/remove_file: absolute path to source file"],
                "number": ["type": "integer", "description": "For select_project: project number (1-based)"],
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
        // --- Web (consolidated) ---
        ToolDef(
            name: Name.web,
            description: "Web automation. Actions: open (URL in browser), find (element by selector), click (element), type (text into element), execute_js (run JavaScript), get_url, get_title. Auto-selects best strategy: AX → JS → Selenium.",
            properties: [
                "action": ["type": "string", "description": "Action: open, find, click, type, execute_js, get_url, or get_title"],
                "url": ["type": "string", "description": "For open: URL to open"],
                "browser": ["type": "string", "description": "Browser: safari (default), chrome, firefox, edge"],
                "selector": ["type": "string", "description": "For find/click/type: CSS/XPath/AX selector"],
                "text": ["type": "string", "description": "For type: text to enter"],
                "script": ["type": "string", "description": "For execute_js: JavaScript code"],
                "strategy": ["type": "string", "description": "Strategy: auto (default), accessibility, javascript, selenium"],
                "timeout": ["type": "number", "description": "For find: max wait seconds (default 10)"],
                "appBundleId": ["type": "string", "description": "Optional browser bundle ID"],
                "verify": ["type": "boolean", "description": "For type: verify text entered (default true)"],
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
            description: "Manage step-by-step plans. Execute every step — don't just create and complete. Actions: create, update, read, list, delete.",
            properties: [
                "action": ["type": "string", "description": "Action: create, update, read, list, or delete"],
                "plan_id": ["type": "string", "description": "Plan name (auto-set from tab name)"],
                "title": ["type": "string", "description": "For create: plan title"],
                "steps": ["type": "string", "description": "For create: newline-separated steps"],
                "step": ["type": "integer", "description": "For update: step number"],
                "status": ["type": "string", "description": "For update: in_progress, completed, or failed"],
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
        // Mediator mode — skip all tool execution
        if await NativeToolContext.mediatorMode {
            return AgentToolOutput(result: "(skipped)")
        }
        // Route to handler for real execution
        if let handler = NativeToolContext.toolHandler {
            let result = await handler(name, input)
            return AgentToolOutput(result: result)
        }
        return AgentToolOutput(result: "Error: no tool handler configured")
    }
}
