import Foundation

/// Shared system prompt and tool definitions for all LLM providers.
/// ClaudeService and OllamaService both reference this for a single source of truth,
/// while retaining the ability to augment with provider-specific additions.
enum AgentTools {

    // MARK: - System Prompt (full version for Claude/Ollama)
    static func systemPrompt(userName: String, userHome: String) -> String {
        """
        You are an autonomous macOS agent. User: "\(userName)", home: "\(userHome)".
        Your Documents folder is \(userHome)/Documents/
        Act, don't explain. Never ask questions. Call task_complete when done.
        Do NOT repeat script stdout — user sees it live.

        EXECUTION & TCC:
        - run_agent_script / apple_event_query / run_osascript (TCC): in Agent process → ALL TCC.
        - run_osascript (non-TCC): routes through UserService LaunchAgent, same as execute_user_command.
        - execute_user_command: as \(userName), ~ = \(userHome). NO TCC. For git, builds, file ops, CLI tools.
        - execute_command: ROOT via LaunchDaemon, ~ = /var/root, use "\(userHome)" for user files. NO TCC. Chown back.
        Never use execute_user_command or execute_command for Automation/Accessibility — no TCC.

        APP AUTOMATION PRIORITY:
        1. apple_event_query — ObjC dispatch, no compile. Fast property reads. Use lookup_sdef first.
        2. run_agent_script — ScriptingBridge Swift dylib, full TCC. NSAppleScript fallback if bridge has issues.
        3. run_applescript — NSAppleScript in-process, full TCC. Quick AppleScript without compilation.
        4. Accessibility tools (ax_*) — AXUIElement API for UI inspection/interaction.
        5. run_osascript — osascript. Last resort for AppleScript.
        Shell commands fill gaps: execute_user_command (user) / execute_command (root) for CLI tools.

        FILE TOOLS: read_file, write_file, edit_file (read first), list_files, search_files
        write_file returns line count only — call read_file after to verify.

        GIT: git_status, git_diff, git_log, git_commit, git_diff_patch, git_branch

        XCODE: xcode_list_projects, xcode_select_project, xcode_build, xcode_run, xcode_grant_permission
        NEVER xcodebuild or swift build via shell. Workflow: read → edit → xcode_build → fix → commit.

        ACCESSIBILITY (require TCC):
        Read: ax_list_windows, ax_inspect_element, ax_get_properties, ax_check_permission, ax_request_permission
        Input: ax_type_text, ax_click, ax_scroll, ax_press_key
        Action: ax_perform_action (allowWrites=true required). Password fields always blocked.
        Other: ax_screenshot, ax_get_audit_log

        AGENTSCRIPTS:
        Core scripts: pre-compiled dylibs in Agent.app/Contents/Resources/. Run via run_agent_script.
        User scripts: ~/Documents/Agent/agents/. Tools: list/read/create/update/delete/run_agent_script.
        ALWAYS list first — update existing, don't duplicate.
        delete_agent_script blocklists so bundled scripts won't respawn. NEVER edit Package.swift manually.
        AgentScripts are Swift — use the full Swift language, any Swift 6 framework, ScriptingBridge, NSAppleScript, Process(), AXUIElement.

        SCRIPT FORMAT:
        import Foundation; import MailBridge
        @_cdecl("script_main") public func scriptMain() -> Int32 { doWork(); return 0 }
        Rules: @_cdecl + scriptMain required. Return 0=success. No exit(). No top-level code.
        CRITICAL: @unknown default on ScriptingBridge enums — unexpected rawValues crash the Agent app.

        DATA PASSING (scripts are dlopen'd):
        - Simple: env AGENT_SCRIPT_ARGS
        - Structured: ~/Documents/Agent/json/{Name}_input.json / _output.json

        OUTPUT FOLDERS (~/Documents/Agent/):
        json/ photos/ images/ screenshots/ html/

        SCRIPTING BRIDGE:
        Connect: guard let app: Protocol = SBApplication(bundleIdentifier: "...") else { return }
        Elements: app.accounts?() → SBElementArray, .object(at: i) as? Type
        Props: @objc optional, use ?. and ??
        New bridge: run_agent_script GenerateBridge with args /Applications/App.app

        BRIDGES (import→protocol→bundleID):
        AppleScriptUtilityBridge→AppleScriptUtilityApplication→com.apple.AppleScriptUtility
        AutomatorBridge→AutomatorApplication→com.apple.Automator
        CalendarBridge→CalendarApplication→com.apple.iCal
        ContactsBridge→ContactsApplication→com.apple.AddressBook
        ConsoleBridge→ConsoleApplication→com.apple.Console
        DatabaseEventsBridge→DatabaseEventsApplication→com.apple.databaseevents
        FinderBridge→FinderApplication→com.apple.finder
        ImageEventsBridge→ImageEventsApplication→com.apple.imageevents
        MailBridge→MailApplication→com.apple.mail
        MessagesBridge→MessagesApplication→com.apple.MobileSMS
        MusicBridge→MusicApplication→com.apple.Music
        NotesBridge→NotesApplication→com.apple.Notes
        NumbersBridge→NumbersApplication→com.apple.Numbers
        PagesBridge→PagesApplication→com.apple.Pages
        PhotosBridge→PhotosApplication→com.apple.Photos
        PreviewBridge→PreviewApplication→com.apple.Preview
        QuickTimePlayerBridge→QuickTimePlayerApplication→com.apple.QuickTimePlayerX
        RemindersBridge→RemindersApplication→com.apple.reminders
        SafariBridge→SafariApplication→com.apple.Safari
        ScriptEditorBridge→ScriptEditorApplication→com.apple.ScriptEditor2
        ShortcutsBridge→ShortcutsApplication→com.apple.shortcuts
        ShortcutsEventsBridge→ShortcutsEventsApplication→com.apple.shortcuts.events
        SystemEventsBridge→SystemEventsApplication→com.apple.systemevents
        SystemSettingsBridge→SystemSettingsApplication→com.apple.systempreferences
        TerminalBridge→TerminalApplication→com.apple.Terminal
        TextEditBridge→TextEditApplication→com.apple.TextEdit
        TVBridge→TVApplication→com.apple.TV
        VoiceOverBridge→VoiceOverApplication→com.apple.VoiceOver
        AgentScriptingBridge→XcodeApplication→com.apple.dt.Xcode
        GoogleChromeBridge→GoogleChromeApplication→com.google.Chrome
        FirefoxBridge→FirefoxApplication→org.mozilla.firefox
        MicrosoftEdgeBridge→MicrosoftEdgeApplication→com.microsoft.edgemac
        KeynoteBridge→KeynoteApplication→com.apple.Keynote
        WishBridge→WishApplication→com.tcltk.wish
        UTMBridge→UTMApplication→com.utmapp.UTM

        APPLE EVENT QUERY:
        Pass bundle_id + operations: get {key} | iterate {properties, limit} | index {index} | call {method, arg} | filter {predicate}
        Writes blocked by default; set allow_writes=true.

        SDEF LOOKUP (51 app dictionaries bundled as JSON):
        ALWAYS use lookup_sdef to read SDEFs — never sdef or find for .sdef files. \
        Use before writing osascript, NSAppleScript, apple_event_query, or ScriptingBridge code. \
        bundle_id="list" shows all apps. class_name drills into a specific class. \
        Read bridge Swift files via read_agent_script for Swift names.

        IMAGE PATHS: Print file paths — UI renders clickable links.

        MCP TOOLS: mcp_* functions in your tool list. Never call a server's list/tools — your list IS the truth.

        NEVER DO:
        - xcodebuild or swift build via shell → use xcode_build / run_agent_script
        - xcode_build on ~/Documents/Agent/agents/ → use run_agent_script
        - execute_user_command for AX/Automation → use run_agent_script
        """
    }

    // MARK: - Tool List per Provider (for ToolsView)

    /// Returns the tools available for a given provider.
    static func tools(for provider: APIProvider) -> [ToolDef] {
        switch provider {
        case .ollama, .localOllama:
            return commonTools + ollamaOnlyTools
        default:
            return commonTools
        }
    }
    
    
    // MARK: - Compact System Prompt (for Apple Intelligence with limited context)
    @MainActor static func compactSystemPrompt(userName: String, userHome: String) -> String {
        """
        macOS assistant. User: \(userName), home: \(userHome). Be brief.
        When asked to DO something, call a tool immediately. Do not explain — just act.
        One tool per reply. Always end with task_complete {"summary": "..."}.
        Tool call format — always JSON after the tool name:
        execute_user_command {"command": "ls -la"}
        run_applescript {"source": "tell app \\"Finder\\" to get name of home"}
        run_osascript {"script": "display dialog \\"Hello\\""}
        task_complete {"summary": "Done"}

        TOOLS:
        \(enabledAppleAIToolLines())
        """
    }

    /// Concrete examples for each tool shown in the Apple AI compact prompt.
    private static let toolExamples: [String: String] = [
        "execute_user_command": #"execute_user_command {"command": "ls -la"}"#,
        "execute_command":      #"execute_command {"command": "whoami"}"#,
        "run_applescript":      #"run_applescript {"source": "tell application \"Finder\" to get name of home"}"#,
        "run_osascript":        #"run_osascript {"script": "display dialog \"Hello\""}"#,
        "read_file":            #"read_file {"file_path": "/Users/toddbruss/Documents/example.txt"}"#,
        "write_file":           #"write_file {"file_path": "/Users/toddbruss/Documents/out.txt", "content": "hello"}"#,
        "edit_file":            #"edit_file {"file_path": "/path/file.txt", "old_string": "old", "new_string": "new"}"#,
        "list_files":           #"list_files {"pattern": "*.swift", "path": "/Users/toddbruss/Documents"}"#,
        "search_files":         #"search_files {"pattern": "TODO", "path": "/Users/toddbruss/Documents"}"#,
        "task_complete":        #"task_complete {"summary": "Done"}"#,
        "git_status":           #"git_status {"path": "/Users/toddbruss/Documents/GitHub/MyRepo"}"#,
        "git_commit":           #"git_commit {"path": "/Users/toddbruss/Documents/GitHub/MyRepo", "message": "fix: update"}"#,
        "apple_event_query":    #"apple_event_query {"bundle_id": "com.apple.Music", "operations": [{"action": "get", "key": "currentTrack"}]}"#,
        "run_agent_script":     #"run_agent_script {"name": "MyScript"}"#,
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
            name: "read_file",
            description: "Read file contents with line numbers. Use instead of `cat`. Returns numbered lines for easy reference in edit_file.",
            properties: [
                "file_path": ["type": "string", "description": "Absolute path to the file to read"],
                "offset": ["type": "integer", "description": "1-based line number to start from (default 1)"],
                "limit": ["type": "integer", "description": "Max lines to return (default 2000)"],
            ],
            required: ["file_path"]
        ),
        ToolDef(
            name: "write_file",
            description: "Create or overwrite a file. Creates parent dirs automatically. Returns line count only — call read_file after to verify content.",
            properties: [
                "file_path": ["type": "string", "description": "Absolute path to the file to write"],
                "content": ["type": "string", "description": "The full file content to write"],
            ],
            required: ["file_path", "content"]
        ),
        ToolDef(
            name: "edit_file",
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
            name: "list_files",
            description: "Find files matching a glob pattern. Use instead of `find`. Excludes hidden files and .build directories.",
            properties: [
                "pattern": ["type": "string", "description": "Glob pattern (e.g. \"*.swift\", \"Package.swift\")"],
                "path": ["type": "string", "description": "Directory to search in (default: user home). Always provide a project path for best results."],
            ],
            required: ["pattern"]
        ),
        ToolDef(
            name: "search_files",
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
            name: "git_status",
            description: "Show current branch, staged/unstaged changes, and untracked files.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
            ],
            required: []
        ),
        ToolDef(
            name: "git_diff",
            description: "Show file changes as a unified diff. Can show staged changes, unstaged changes, or diff against a branch/commit.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "staged": ["type": "boolean", "description": "Show staged changes only (default false)"],
                "target": ["type": "string", "description": "Branch, commit, or ref to diff against (e.g. \"main\", \"HEAD~3\")"],
            ],
            required: []
        ),
        ToolDef(
            name: "git_log",
            description: "Show recent commit history as one-line summaries.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "count": ["type": "integer", "description": "Number of commits to show (default 20, max 100)"],
            ],
            required: []
        ),
        ToolDef(
            name: "git_commit",
            description: "Stage files and create a commit. If no files specified, stages all changes.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "message": ["type": "string", "description": "Commit message"],
                "files": ["type": "array", "items": ["type": "string"] as [String: Any], "description": "Specific files to stage (default: all changes)"] as [String: Any],
            ],
            required: ["message"]
        ),
        ToolDef(
            name: "git_diff_patch",
            description: "Apply a unified diff patch to files in the repository. Use for complex multi-line edits that are easier to express as a patch.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "patch": ["type": "string", "description": "Unified diff patch content"],
            ],
            required: ["patch"]
        ),
        ToolDef(
            name: "git_branch",
            description: "Create a new git branch, optionally switching to it.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "name": ["type": "string", "description": "Branch name to create"],
                "checkout": ["type": "boolean", "description": "Switch to the new branch (default true)"],
            ],
            required: ["name"]
        ),
        // --- Core Tools ---
        ToolDef(
            name: "apple_event_query",
            description: "PRIORITY 1 for app automation. Query a scriptable Mac app via ObjC dynamic dispatch. No compilation, instant results. Use lookup_sdef first to get valid keys.",
            properties: [
                "bundle_id": ["type": "string", "description": "App bundle identifier (e.g. com.apple.Music)"],
                "operations": [
                    "type": "array",
                    "description": "Array of operations to execute sequentially. Each has an 'action' key.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "action": ["type": "string", "description": "One of: get, iterate, index, call, filter"],
                            "key": ["type": "string", "description": "Property key for 'get'"],
                            "properties": ["type": "array", "items": ["type": "string"], "description": "Properties to read for 'iterate'"],
                            "limit": ["type": "integer", "description": "Max items for 'iterate' (default 50)"],
                            "index": ["type": "integer", "description": "Array index for 'index'"],
                            "method": ["type": "string", "description": "Method name for 'call'"],
                            "arg": ["type": "string", "description": "Optional argument for 'call'"],
                            "predicate": ["type": "string", "description": "NSPredicate format string for 'filter'"],
                        ] as [String: Any],
                        "required": ["action"],
                    ] as [String: Any],
                ] as [String: Any],
                "allow_writes": ["type": "boolean", "description": "Allow destructive operations (delete, close, move, etc.). Default false."],
            ],
            required: ["bundle_id", "operations"]
        ),
        ToolDef(
            name: "run_applescript",
            description: "Execute AppleScript code in-process via NSAppleScript with full TCC. Use lookup_sdef first to get correct terminology. For quick automation that doesn't need a compiled AgentScript.",
            properties: [
                "source": ["type": "string", "description": "AppleScript source code to execute"],
            ],
            required: ["source"]
        ),
        ToolDef(
            name: "run_osascript",
            description: "Run AppleScript source code via osascript in-process with full TCC. Use for app automation via AppleScript. Prefer run_applescript or run_agent_script when available.",
            properties: [
                "script": ["type": "string", "description": "AppleScript source code to execute"],
            ],
            required: ["script"]
        ),
        ToolDef(
            name: "execute_user_command",
            description: "Execute a shell command as the current user (no root). NO TCC permissions. Use for git, builds, file ops, homebrew, etc.",
            properties: [
                "command": ["type": "string", "description": "The bash command to execute as the current user"],
            ],
            required: ["command"]
        ),
        ToolDef(
            name: "execute_command",
            description: "Execute a shell command with ROOT privileges via the privileged daemon. NO TCC. Only use when root is required: system packages, /System or /Library modifications, disk operations.",
            properties: [
                "command": ["type": "string", "description": "The bash command to execute as root"],
            ],
            required: ["command"]
        ),
        ToolDef(
            name: "task_complete",
            description: "Signal that the task has been completed. Always call this when done.",
            properties: [
                "summary": ["type": "string", "description": "Brief summary of what was accomplished"],
            ],
            required: ["summary"]
        ),
        // --- Accessibility Tools ---
        ToolDef(
            name: "ax_list_windows",
            description: "List all visible windows from all applications with their positions and sizes. Returns JSON array with window ID, owner PID, owner name, window name, and bounds.",
            properties: [
                "limit": ["type": "integer", "description": "Maximum number of windows to return (default 50)"],
            ],
            required: []
        ),
        ToolDef(
            name: "ax_inspect_element",
            description: "Inspect accessibility element at a screen coordinate. Returns the accessibility hierarchy for the element at position (x, y).",
            properties: [
                "x": ["type": "number", "description": "Screen X coordinate"],
                "y": ["type": "number", "description": "Screen Y coordinate"],
                "depth": ["type": "integer", "description": "How deep to traverse the hierarchy (default 3)"],
            ],
            required: ["x", "y"]
        ),
        ToolDef(
            name: "ax_get_properties",
            description: "Get all properties of an accessibility element. Can find by role/title or by screen position.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXButton', 'AXTextField')"],
                "title": ["type": "string", "description": "Title or name to match (partial match)"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "x": ["type": "number", "description": "Screen X coordinate for position-based lookup"],
                "y": ["type": "number", "description": "Screen Y coordinate for position-based lookup"],
            ],
            required: []
        ),
        ToolDef(
            name: "ax_perform_action",
            description: "Perform an accessibility action on an element. SECURITY: Interaction actions (click, press) require allowWrites=true. Password fields are always blocked.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find"],
                "title": ["type": "string", "description": "Title to match"],
                "appBundleId": ["type": "string", "description": "Bundle ID of the target app"],
                "x": ["type": "number", "description": "Screen X coordinate for position-based lookup"],
                "y": ["type": "number", "description": "Screen Y coordinate for position-based lookup"],
                "action": ["type": "string", "description": "Accessibility action to perform (e.g., 'AXPress', 'AXConfirm')"],
                "allowWrites": ["type": "boolean", "description": "Allow interaction actions (default false)"],
            ],
            required: ["action"]
        ),
        ToolDef(
            name: "ax_check_permission",
            description: "Check if Accessibility permission is granted to Agent.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: "ax_request_permission",
            description: "Request Accessibility permission. Shows the macOS system prompt for the user to approve.",
            properties: [:],
            required: []
        ),
        // --- Accessibility Input Simulation (Phase 2) ---
        ToolDef(
            name: "ax_type_text",
            description: "Simulate typing text at the current cursor position or at specific coordinates. Uses CGEvent keyboard simulation.",
            properties: [
                "text": ["type": "string", "description": "Text to type"],
                "x": ["type": "number", "description": "Optional X coordinate to click first before typing"],
                "y": ["type": "number", "description": "Optional Y coordinate to click first before typing"],
            ],
            required: ["text"]
        ),
        ToolDef(
            name: "ax_click",
            description: "Simulate a mouse click at screen coordinates.",
            properties: [
                "x": ["type": "number", "description": "Screen X coordinate (required)"],
                "y": ["type": "number", "description": "Screen Y coordinate (required)"],
                "button": ["type": "string", "description": "Mouse button: 'left' (default), 'right', or 'middle'"],
                "clicks": ["type": "integer", "description": "Number of clicks: 1 (default) or 2 for double-click"],
            ],
            required: ["x", "y"]
        ),
        ToolDef(
            name: "ax_scroll",
            description: "Simulate scroll wheel at screen coordinates.",
            properties: [
                "x": ["type": "number", "description": "Screen X coordinate"],
                "y": ["type": "number", "description": "Screen Y coordinate"],
                "deltaX": ["type": "integer", "description": "Horizontal scroll amount (positive = right, negative = left)"],
                "deltaY": ["type": "integer", "description": "Vertical scroll amount (positive = down, negative = up)"],
            ],
            required: ["x", "y"]
        ),
        ToolDef(
            name: "ax_press_key",
            description: "Simulate pressing a key with optional modifiers (Cmd, Option, Control, Shift).",
            properties: [
                "keyCode": ["type": "integer", "description": "macOS virtual key code (e.g., 36=Return, 48=Tab, 51=Delete, 53=Escape, 123-126=Arrow keys)"],
                "modifiers": ["type": "array", "description": "Array of modifier keys: 'command', 'option', 'control', 'shift'", "items": ["type": "string"]],
            ],
            required: ["keyCode"]
        ),
        // --- Accessibility Screenshots (Phase 4) ---
        ToolDef(
            name: "ax_screenshot",
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
        // --- Accessibility Audit Log (Phase 5) ---
        ToolDef(
            name: "ax_get_audit_log",
            description: "Get recent accessibility audit log entries. Shows recent accessibility operations performed by the agent.",
            properties: [
                "limit": ["type": "integer", "description": "Maximum number of entries to return (default 50)"],
            ],
            required: []
        ),
        // --- Script Management ---
        ToolDef(
            name: "list_agent_scripts",
            description: "List all Swift automation scripts in ~/Documents/Agent/agents/",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: "read_agent_script",
            description: "Read the source code of a Swift automation script.",
            properties: [
                "name": ["type": "string", "description": "Script name (with or without .swift)"],
            ],
            required: ["name"]
        ),
        ToolDef(
            name: "create_agent_script",
            description: "Create a new Swift automation script in ~/Documents/Agent/agents/",
            properties: [
                "name": ["type": "string", "description": "Script filename (with or without .swift)"],
                "content": ["type": "string", "description": "Swift source code"],
            ],
            required: ["name", "content"]
        ),
        ToolDef(
            name: "update_agent_script",
            description: "Update an existing Swift automation script.",
            properties: [
                "name": ["type": "string", "description": "Script filename"],
                "content": ["type": "string", "description": "New Swift source code"],
            ],
            required: ["name", "content"]
        ),
        ToolDef(
            name: "run_agent_script",
            description: "PRIORITY 1 for app automation. Compile and run a Swift dylib with full TCC using ScriptingBridge. Use existing scripts first (list_agent_scripts), create new ones with ScriptingBridge protocols. Use lookup_sdef and read_agent_script to check app dictionaries and bridge Swift files. NSAppleScript fallback if ScriptingBridge has issues. Output streams live — do NOT repeat stdout.",
            properties: [
                "name": ["type": "string", "description": "Script filename (without .swift)"],
                "arguments": ["type": "string", "description": "Simple string passed via AGENT_SCRIPT_ARGS env var. For complex data, use JSON files instead."],
            ],
            required: ["name"]
        ),
        ToolDef(
            name: "delete_agent_script",
            description: "Delete a Swift automation script.",
            properties: [
                "name": ["type": "string", "description": "Script filename"],
            ],
            required: ["name"]
        ),
        // --- SDEF Lookup ---
        ToolDef(
            name: "lookup_sdef",
            description: "Read an app's SDEF scripting dictionary. ALWAYS use this to read SDEFs — never use shell commands to find .sdef files. Returns commands, classes, properties, elements, and enums. Use before writing osascript, NSAppleScript, apple_event_query, or ScriptingBridge code.",
            properties: [
                "bundle_id": ["type": "string", "description": "App bundle identifier (e.g. com.apple.Music). Use 'list' to see all available SDEFs."],
                "class_name": ["type": "string", "description": "Optional: get details for a specific class (e.g. 'track', 'application')"],
            ],
            required: ["bundle_id"]
        ),
        // --- Xcode ---
        ToolDef(
            name: "xcode_build",
            description: "Build an Xcode project or workspace via ScriptingBridge. Blocks until build completes. Returns errors/warnings in file:line:col format with code snippets for context.",
            properties: [
                "project_path": ["type": "string", "description": "Path to .xcodeproj or .xcworkspace"],
            ],
            required: ["project_path"]
        ),
        ToolDef(
            name: "xcode_run",
            description: "Build then run an Xcode project via ScriptingBridge. Builds first — only runs if clean. Returns errors if build fails.",
            properties: [
                "project_path": ["type": "string", "description": "Path to .xcodeproj or .xcworkspace"],
            ],
            required: ["project_path"]
        ),
        ToolDef(
            name: "xcode_list_projects",
            description: "List all open Xcode projects and workspaces with numbered indices. Use the number with xcode_select_project to choose one.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: "xcode_select_project",
            description: "Select an open Xcode project by its number from xcode_list_projects. Returns the project path for use with xcode_build/xcode_run.",
            properties: [
                "number": ["type": "integer", "description": "Project number from the list (1-based)"],
            ],
            required: ["number"]
        ),
        ToolDef(
            name: "xcode_grant_permission",
            description: "Grant macOS Automation permission so the agent can control Xcode via ScriptingBridge. Run this once before using xcode_build or xcode_run.",
            properties: [:],
            required: []
        ),
    ]

    // MARK: - Foundation Models Native Tools

    /// Create native FoundationModels.Tool objects for on-device Apple Intelligence.
    /// Each tool returns GeneratedContent as arguments, which the model populates with parameters.
    @MainActor static func nativeTools() -> [any Tool] {
        commonTools.map { toolDef in
            NativeAgentTool(toolDef: toolDef)
        }
    }

    // MARK: - Plain-Text Format (for Foundation Models / text-based providers)

    /// All tool names derived from commonTools. Use instead of hardcoded lists.
    nonisolated static var toolNames: [String] {
        commonTools.map { $0.name }
    }

    /// Compact tool reference for inclusion in plain-text model prompts.
    /// Format: toolName {"param": type, "optParam"?: type} — short description
    nonisolated static var textFormat: String {
        var lines: [String] = ["TOOLS — call as: toolName {\"param\": value, ...}"]
        for tool in commonTools {
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
            // Ensure "properties" is always an object if present
            if result["properties"] == nil {
                result["properties"] = [:] as [String: Any]
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
    @MainActor static var claudeFormat: [[String: Any]] {
        let prefs = ToolPreferencesService.shared
        var tools = commonTools
            .filter { prefs.isEnabled(.claude, $0.name) }
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
    static func ollamaTool(name: String, description: String, properties: [String: Any], required: [String]) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required,
                ] as [String: Any],
            ] as [String: Any],
        ]
    }

    /// Tools only available for Ollama providers (client-side web search via Tavily).
    nonisolated(unsafe) private static let ollamaOnlyTools: [ToolDef] = [
        ToolDef(
            name: "web_search",
            description: "Search the web for current information. Returns relevant web page titles, URLs, and content snippets. Use when you need up-to-date information or facts you're unsure about.",
            properties: [
                "query": ["type": "string", "description": "The search query"],
            ],
            required: ["query"]
        ),
    ]

    /// Provider-aware Ollama/OpenAI format — filters tools by per-provider preferences.
    @MainActor static func ollamaTools(for provider: APIProvider) -> [[String: Any]] {
        let prefs = ToolPreferencesService.shared
        var tools = (commonTools + ollamaOnlyTools)
            .filter { prefs.isEnabled(provider, $0.name) }
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
        // This is called by Foundation Models when the tool is invoked.
        // The actual tool execution happens in TaskExecution.swift, which handles
        // the tool_use blocks from the parsed response.
        // We return a placeholder here - the real execution flow is:
        // 1. Model generates tool calls in transcript
        // 2. FoundationModelService.parseResponse extracts tool_calls from transcript
        // 3. TaskExecution.swift processes the tool_use blocks
        // This design allows us to reuse the existing tool execution infrastructure.
        return AgentToolOutput(result: "Tool \(name) queued for execution")
    }
}
