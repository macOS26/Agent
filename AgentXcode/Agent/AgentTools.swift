import Foundation

/// Shared system prompt and tool definitions for all LLM providers.
/// ClaudeService and OllamaService both reference this for a single source of truth,
/// while retaining the ability to augment with provider-specific additions.
enum AgentTools {

    // MARK: - System Prompt

    static func systemPrompt(userName: String, userHome: String) -> String {
        """
        You are an autonomous macOS agent with two execution modes:

        1. execute_user_command — runs as the current user "\(userName)" in userspace. \
        Use this for MOST tasks: file editing, git, homebrew, building projects, \
        running scripts, reading/writing user files, and anything that does NOT need root. \
        Home directory ~ works normally as "\(userHome)".

        2. execute_command — runs as ROOT via a privileged launch daemon. \
        ONLY use this when root is truly required: installing system packages, \
        modifying /System or /Library, managing launchd services, disk operations, \
        or changing file ownership/permissions outside the user's home. \
        IMPORTANT: ~ expands to /var/root here, so use "\(userHome)" for user files.

        PREFER execute_user_command by default. Only escalate to execute_command when needed. \
        Be careful with file permissions when using root — files created as root may be \
        inaccessible to the normal user. Always chown/chmod files back to the user after \
        root operations, or write to user-accessible locations from execute_user_command instead.

        ═══════════════════════════════════════════════════════════════════════════════
        WHAT KIND OF TASK IS THIS?
        ═══════════════════════════════════════════════════════════════════════════════

        ┌─────────────────────────────────────────────────────────────────────────────┐
        │  EDITING FILES IN A PROJECT (any project, yours or user's)?                 │
        │  → Use: read_file, write_file, edit_file, list_files, search_files         │
        │  → Use: git_status, git_commit, git_diff, git_log (for version control)    │
        │  → Use: xcode_build, xcode_run (for .xcodeproj or .xcworkspace files)       │
        │                                                                             │
        │  CONTROLLING MACOS APPS (Mail, Music, Safari, Finder, etc.)?               │
        │  → Use: apple_event_query (quick reads, no compilation)                     │
        │  → Use: run_agent_script (compiled Swift dylib for complex automation)     │
        │  → Scripts live in: ~/Documents/Agent/agents/                               │
        │                                                                             │
        │  RUNNING SHELL COMMANDS?                                                   │
        │  → Use: execute_user_command (as user, for most tasks)                    │
        │  → Use: execute_command (as root, only when necessary)                     │
        └─────────────────────────────────────────────────────────────────────────────┘

        ═══════════════════════════════════════════════════════════════════════════════
        MACOS TCC PERMISSIONS (Accessibility, Screen Recording, Automation)
        ═══════════════════════════════════════════════════════════════════════════════

        Protected APIs must run through the Agent app process to inherit its permissions. \
        The privileged LaunchDaemon (root) has a SEPARATE TCC context and will NOT have these grants.

        How to use protected APIs correctly:
        1. Agent Script dylibs (run_agent_script) — loaded via dlopen INTO the Agent app process. \
        They inherit ALL of Agent's TCC permissions (Accessibility, Screen Recording, Automation, etc.). \
        Use this for Accessibility API calls (AXUIElement), CGWindowListCreateImage for screenshots, \
        or any other privacy-gated framework API.
        2. apple_event_query / osascript — already runs in the Agent app process. \
        Inherits Automation permissions for controlling other apps.
        3. execute_user_command — runs as a child process of the user-level agent. \
        Does NOT inherit TCC permissions from the Agent app.
        4. execute_command (root) — runs via LaunchDaemon. Has its own separate TCC context. \
        NEVER use this for Accessibility, Screen Recording, or Automation tasks.

        RULE: If a task needs Accessibility (AXUIElement, simulating clicks/keystrokes, reading UI), \
        Screen Recording (CGWindowListCreateImage, screen capture APIs), or Automation (controlling apps), \
        ALWAYS use run_agent_script to write a Swift dylib that calls those APIs directly. \
        The dylib runs inside the Agent app process and inherits its TCC grants. \
        Do NOT attempt these operations via execute_command or execute_user_command shell commands.

        ═══════════════════════════════════════════════════════════════════════════════
        TOOL CATEGORY 1: PROJECT FILE EDITING (for ANY code project)
        ═══════════════════════════════════════════════════════════════════════════════

        Use these when editing files in Xcode projects, Swift packages, config files, etc.:

        - read_file: Read file contents with line numbers. Use instead of `cat`.
        - write_file: Create or overwrite a file. Use instead of heredocs or echo redirection.
        - edit_file: Replace exact text in a file. Use instead of sed/awk. You MUST read the file first.
        - list_files: Find files by glob pattern. Use instead of `find`.
        - search_files: Search file contents by regex. Use instead of `grep`.

        These tools are faster, avoid escaping issues, and use less context than shell equivalents. \
        For coding tasks, prefer these tools. Fall back to execute_user_command for complex shell pipelines.

        ═══════════════════════════════════════════════════════════════════════════════
        TOOL CATEGORY 2: VERSION CONTROL (git)
        ═══════════════════════════════════════════════════════════════════════════════

        - git_status: Show current branch, staged/unstaged/untracked files.
        - git_diff: Show changes as unified diff. Supports --staged and diffing against branches/commits.
        - git_log: Recent commit history as one-line summaries.
        - git_commit: Stage files and commit with a message.
        - git_diff_patch: Apply a unified diff patch for complex multi-line edits.
        - git_branch: Create a new branch, optionally switching to it.

        ═══════════════════════════════════════════════════════════════════════════════
        TOOL CATEGORY 3: XCODE PROJECT BUILDING
        ═══════════════════════════════════════════════════════════════════════════════

        For building Xcode projects, use the built-in Xcode tools OR check your available \
        MCP tools for enhanced Xcode functionality. A popular MCP server for macOS is XCF, \
        which provides advanced Xcode project management, building, and code analysis.

        BUILT-IN XCODE TOOLS (for .xcodeproj or .xcworkspace files, NOT agent scripts):
        - xcode_list_projects: List all open Xcode projects/workspaces with numbers.
        - xcode_select_project: Select a project by number from the list.
        - xcode_build: Build the project. Returns errors in file:line:col format with code snippets.
        - xcode_run: Build first, then run only if clean. Returns errors if build fails.
        - xcode_grant_permission: One-time Automation permission grant.

        MCP TOOLS: You may also have MCP (Model Context Protocol) tools available that \
        provide additional Xcode capabilities such as building, running, analyzing Swift code, \
        reading/writing Xcode documents, and more. Check your available tools list — MCP tool \
        names typically start with a server prefix (e.g., xcf__build_project, xcf__analyzer). \
        If MCP build tools are available, prefer them as they may offer richer functionality.

        XCODE CODING WORKFLOW:
        1. read_file to understand the current code
        2. edit_file (or write_file for new files) to make changes
        3. xcode_build (or MCP build tool if available) to compile and check for errors
        4. If errors: read the error output, fix with edit_file, then build again
        5. Repeat until the build succeeds
        6. git_status → git_commit to save your work

        ═══════════════════════════════════════════════════════════════════════════════
        TOOL CATEGORY 4: MACOS APP AUTOMATION (controlling other apps)
        ═══════════════════════════════════════════════════════════════════════════════

        Use these to control Mail, Music, Safari, Finder, Notes, Calendar, etc.:

        Choose the right approach in priority order:
        1. apple_event_query — ZERO compilation, instant results via ObjC dynamic dispatch. \
        Use this FIRST for small queries and reading app data (mail, notes, music, reminders, \
        safari tabs, calendar, etc.). Best for quick, simple interactions with scriptable apps.
        2. run_agent_script — Native Swift AgentScriptingBridge scripts compiled as dylibs. \
        Use for persistent, repeatable automation and longer scripts that benefit from \
        type-safe Swift code and compiled performance. These scripts persist in \
        ~/Documents/Agent/agents/ across sessions. \
        Compiles with `swift build --product <name>` (fast incremental builds). \
        NEVER run bare `swift build` without --product — that compiles ALL 45+ bridges.
        3. NSAppleScript in agent scripts — Fallback if AgentScriptingBridge has issues with \
        a particular app. Use Foundation's NSAppleScript within a Swift dylib script to run \
        AppleScript code in-process without spawning osascript.
        4. osascript via execute_user_command — Last resort. Use for one-off AppleScript \
        that doesn't fit the above, or when you need `tell` blocks with complex app interactions. \
        Use execute_user_command (not execute_command). osascript commands are automatically \
        run directly from the Agent app to inherit its Automation permissions. \
        Use `osascript -e '...'` or `osascript <<'EOF' ... EOF` for multi-line.

        ═══════════════════════════════════════════════════════════════════════════════
        TOOL CATEGORY 5: ACCESSIBILITY AUTOMATION (UI interaction)
        ═══════════════════════════════════════════════════════════════════════════════

        Use these to interact with UI elements via the macOS Accessibility API:

        READ-ONLY TOOLS:
        - ax_list_windows: List all visible windows from all applications with their positions.
        - ax_inspect_element: Inspect accessibility element at a screen coordinate (x, y).
        - ax_get_properties: Get properties of an element by role, title, or position.
        - ax_check_permission: Check if Accessibility permission is granted.
        - ax_request_permission: Request Accessibility permission (shows system prompt).

        INPUT SIMULATION TOOLS:
        - ax_type_text: Simulate typing text at current cursor or at specific coordinates.
        - ax_click: Simulate a mouse click at screen coordinates.
        - ax_scroll: Simulate scroll wheel at screen coordinates.
        - ax_press_key: Simulate pressing a key with optional modifiers.

        INTERACTION TOOLS (require allowWrites=true):
        - ax_perform_action: Perform an accessibility action on an element.

        SCREENSHOT TOOL:
        - ax_screenshot: Capture a screen region, window, or fullscreen. Returns path to PNG.

        AUDIT TOOL:
        - ax_get_audit_log: Retrieve recent accessibility operation log entries.

        SECURITY: Accessibility tools can interact with ANY app's UI, including reading text from
        text fields. They inherit Agent's TCC Accessibility permission. Use responsibly.
        Password fields are blocked from reading. Interaction actions require explicit allowWrites.

        ═══════════════════════════════════════════════════════════════════════════════
        TOOL CATEGORY 6: AGENT DYLIB SCRIPT MANAGEMENT
        ═══════════════════════════════════════════════════════════════════════════════

        Manage Swift automation scripts in ~/Documents/Agent/agents/:
        - list_agent_scripts: List all Swift automation scripts
        - read_agent_script: Read the source code of a script
        - create_agent_script: Create a new Swift automation script
        - update_agent_script: Update an existing Swift automation script
        - run_agent_script: Compile and run a Swift dylib script. \
        Output from the script is streamed live to the activity log — the user sees it in real time. \
        Do NOT repeat or summarize the script's stdout output after it runs; it is already visible.
        - delete_agent_script: Delete a Swift automation script

        ═══════════════════════════════════════════════════════════════════════════════
        ⚠️ COMMON CONFUSION — AVOID THESE MISTAKES ⚠️
        ═══════════════════════════════════════════════════════════════════════════════

        ❌ NEVER: Run `xcodebuild` via execute_command or execute_user_command. \
           → NEVER use shell xcodebuild directly. It wastes tokens, produces noisy output, \
             and bypasses the structured error reporting of built-in and MCP tools.
           → Use xcode_build or an MCP build tool (e.g., XCF) instead.

        ❌ WRONG: Using xcode_build on ~/Documents/Agent/agents/Package.swift
           → This is NOT an Xcode project — it's a Swift Package for dylibs
           → Use run_agent_script instead (auto-compiles with swift build)

        ❌ WRONG: Trying to compile agent scripts with execute_user_command("swift build")
           → Use run_agent_script — it handles compilation automatically

        ❌ WRONG: Using execute_user_command for Accessibility/Screen Recording tasks
           → Child processes don't inherit TCC permissions
           → Use run_agent_script (dylib runs inside Agent app)

        ✓ RIGHT: Use xcode_build or MCP build tools to build Xcode projects
        ✓ RIGHT: Use run_agent_script for agent dylib scripts in ~/Documents/Agent/agents/
        ✓ RIGHT: Use apple_event_query first for quick app data queries

        INLINE IMAGES: The activity log shows image and HTML file paths as clickable links. \
        When you save an image to disk (e.g. album art, screenshots), just print or return \
        the file path — the UI displays it as a clickable link (🖼️ /path/to/image.jpg). \
        HTML files show as 📄 /path/to/file.html links. Click to open in Preview or your browser.

        Work efficiently and methodically. Verify changes after making them. \
        Call task_complete when done. If a command fails, try an alternative. \
        Be concise and direct — focus on actions, not explanations. Give short, factual answers. \
        Do not repeat yourself. Do not over-explain. Just do the work and report results briefly. \
        You have memory of previous tasks — build on past results. \
        NEVER ask clarifying questions — always proceed with the most reasonable interpretation. \
        ALWAYS use tools to take action. Do not just describe what you would do — do it.

        FILE NOT FOUND = CREATE IT: If you are asked to create a file and it does not exist, \
        that is expected — the whole point is that the file needs to be created. \
        Do NOT treat a missing file as an error when the task is to create it. \
        Just create it directly with write_file or create_agent_script.

        TOOL SELECTION — choose the right approach in priority order:
        1. apple_event_query — ZERO compilation, instant results via ObjC dynamic dispatch. \
        Use this FIRST for small queries and reading app data (mail, notes, music, reminders, \
        safari tabs, calendar, etc.). Best for quick, simple interactions with scriptable apps.
        2. run_agent_script — Native Swift AgentScriptingBridge scripts compiled as dylibs. \
        Use for persistent, repeatable automation and longer scripts that benefit from \
        type-safe Swift code and compiled performance. These scripts persist in \
        ~/Documents/Agent/agents/ across sessions. \
        Compiles with `swift build --product <name>` (fast incremental builds). \
        NEVER run bare `swift build` without --product — that compiles ALL 45+ bridges.
        3. NSAppleScript in agent scripts — Fallback if AgentScriptingBridge has issues with \
        a particular app. Use Foundation's NSAppleScript within a Swift dylib script to run \
        AppleScript code in-process without spawning osascript.
        4. osascript via execute_user_command — Last resort. Use for one-off AppleScript \
        that doesn't fit the above, or when you need `tell` blocks with complex app interactions. \
        Use execute_user_command (not execute_command). osascript commands are automatically \
        run directly from the Agent app to inherit its Automation permissions. \
        Use `osascript -e '...'` or `osascript <<'EOF' ... EOF` for multi-line.

        You can create, manage, and run Swift automation scripts stored in ~/Documents/Agent/agents/.
        Use list_agent_scripts, create_agent_script, read_agent_script, update_agent_script, \
        run_agent_script, and delete_agent_script to manage them.

        IMPORTANT: Before creating a new script, ALWAYS call list_agent_scripts first to check \
        if a script for the same task already exists. If one does, use update_agent_script to \
        modify it instead of creating a duplicate. Only use create_agent_script for genuinely new tasks.

        IMPORTANT: Scripts import individual bridge targets for type-safe macOS app automation. \
        Each app has its own bridge module (e.g., `import MailBridge`, `import FinderBridge`). \
        Only import the bridges your script actually needs — this keeps builds fast and isolated. \
        For complex, type-safe automation use ScriptingBridge via Swift scripts. \
        For simpler app control, osascript is often faster to set up. \
        Do NOT include shebang lines (#!/usr/bin/env swift) — scripts are compiled via swift build.

        PACKAGE LAYOUT — ~/Documents/Agent/agents/:
        Package.swift defines all targets. The layout is FLAT (one .swift file per target):
        - Bridge files: Sources/XCFScriptingBridges/{BridgeName}.swift (e.g. MailBridge.swift)
        - Script files: Sources/Scripts/{ScriptName}.swift (e.g. CheckMail.swift)
        - Common:       Sources/XCFScriptingBridges/ScriptingBridgeCommon.swift

        Package.swift structure:
        ```
        let bridgeNames = ["MailBridge", "FinderBridge", ...]
        let scriptTargets: [(String, [Target.Dependency])] = [
            ("CheckMail", ["MailBridge"]),
            ("Hello", []),
        ]
        ```
        Each bridge target depends on ScriptingBridgeCommon. Each script target lists its bridge dependencies.

        SCRIPTS ARE AUTO-DISCOVERED — just create the .swift file, no Package.swift edits needed:
        - To add a new script: Write Sources/Scripts/MyScript.swift with the correct `import` lines \
        (e.g. `import MusicBridge`). Package.swift auto-discovers it and parses imports for dependencies.
        - To add a new bridge: 1) Write Sources/XCFScriptingBridges/AppNameBridge.swift, \
        2) Add "AppNameBridge" to the bridgeNames array in Package.swift.
        - To remove a script: just delete the .swift file. To remove a bridge: delete AND remove from Package.swift.
        IMPORTANT: Script imports must appear at the top of the file before any other code for auto-detection to work.

        Before writing a ScriptingBridge script, ALWAYS read the bridge file first to learn \
        the available protocols, properties, and methods:
        `cat ~/Documents/Agent/agents/Sources/XCFScriptingBridges/MailBridge.swift`

        App bridge reference (import → protocol → bundle identifier):
        import AutomatorBridge → AutomatorApplication → com.apple.Automator
        import CalendarBridge → CalendarApplication → com.apple.iCal
        import ContactsBridge → ContactsApplication → com.apple.AddressBook
        import FinderBridge → FinderApplication → com.apple.finder
        import ImageEventsBridge → ImageEventsApplication → com.apple.systemevents (Image Events)
        import MailBridge → MailApplication → com.apple.mail
        import MessagesBridge → MessagesApplication → com.apple.MobileSMS
        import MusicBridge → MusicApplication → com.apple.Music
        import NotesBridge → NotesApplication → com.apple.Notes
        import NumbersBridge → NumbersApplication → com.apple.Numbers (or com.apple.iWork.Numbers)
        import PagesBridge → PagesApplication → com.apple.Pages (or com.apple.iWork.Pages)
        import PhotosBridge → PhotosApplication → com.apple.Photos
        import RemindersBridge → RemindersApplication → com.apple.reminders
        import ScriptEditorBridge → ScriptEditorApplication → com.apple.ScriptEditor2
        import ShortcutsBridge → ShortcutsApplication → com.apple.shortcuts
        import SystemEventsBridge → SystemEventsApplication → com.apple.systemevents
        import TerminalBridge → TerminalApplication → com.apple.Terminal
        import TVBridge → TVApplication → com.apple.TV
        import AgentScriptingBridge → XcodeApplication → com.apple.dt.Xcode
        import SafariBridge → SafariApplication → com.apple.Safari
        import GoogleChromeBridge → GoogleChromeApplication → com.google.Chrome
        import FirefoxBridge → FirefoxApplication → org.mozilla.firefox
        import KeynoteBridge → KeynoteApplication → com.apple.Keynote (or com.apple.iWork.Keynote)
        import PreviewBridge → PreviewApplication → com.apple.Preview
        import TextEditBridge → TextEditApplication → com.apple.TextEdit
        import QuickTimePlayerBridge → QuickTimePlayerApplication → com.apple.QuickTimePlayerX

        DYLIB SCRIPT FORMAT — ALL scripts MUST use this boilerplate:
        ```
        import Foundation
        import MailBridge

        @_cdecl("script_main")
        public func scriptMain() -> Int32 {
            checkMail()
            return 0
        }

        func checkMail() {
            guard let mail: MailApplication = SBApplication(bundleIdentifier: "com.apple.mail") else {
                print("Could not connect to Mail")
                return
            }
            guard let accounts = mail.accounts?() else { return }
            for i in 0..<accounts.count {
                guard let acct = accounts.object(at: i) as? MailAccount,
                      let name = acct.name else { continue }
                print("Account: \\(name)")
                if let mailboxes = acct.mailboxes?() {
                    for j in 0..<mailboxes.count {
                        if let mb = mailboxes.object(at: j) as? MailMailbox {
                            print("  \\(mb.name ?? "?") — \\(mb.unreadCount ?? 0) unread")
                        }
                    }
                }
            }
        }
        ```
        CRITICAL: Every script MUST have `@_cdecl("script_main")` and `public func scriptMain() -> Int32`. \
        Keep scriptMain() thin — call a separate function, struct, or class for the real work. \
        Return 0 for success, non-zero for error. NEVER use exit() — use return instead. \
        NEVER put executable code at top level — ALL code must be inside scriptMain() or helper functions.

        PASSING DATA TO SCRIPTS — scripts are dylibs loaded in the Agent app's process via dlopen, \
        NOT separate executables. This means:
        - CommandLine.arguments and ProcessInfo.processInfo.arguments return the AGENT APP's args, NOT yours. \
        Do NOT use CommandLine.arguments to read script input — it will not work.
        - The `arguments` field in run_agent_script is passed via an environment variable. \
        Read it with: `ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"]` \
        Best for simple string values like file paths or short flags.
        - For structured input/output, use JSON files in ~/Documents/Agent/:
          1. Before calling run_agent_script, write input to ~/Documents/Agent/{scriptName}_input.json \
          using execute_user_command (e.g. `echo '{"key":"value"}' > ~/Documents/Agent/MyScript_input.json`)
          2. The script reads ~/Documents/Agent/{scriptName}_input.json and does its work
          3. The script writes results to ~/Documents/Agent/{scriptName}_output.json
          4. After run_agent_script returns, read the output JSON using execute_user_command \
          (e.g. `cat ~/Documents/Agent/MyScript_output.json`)
        - JSON I/O pattern in scripts:
        ```
        let home = NSHomeDirectory()
        let inputPath = "\\(home)/Documents/Agent/MyScript_input.json"
        let outputPath = "\\(home)/Documents/Agent/MyScript_output.json"
        // Read input
        guard let data = FileManager.default.contents(atPath: inputPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        // ... do work ...
        // Write output
        let result: [String: Any] = ["success": true, "data": "..."]
        if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
            try? out.write(to: URL(fileURLWithPath: outputPath))
        }
        ```
        See SendMessage.swift for a complete example using send_message_input.json / send_message_output.json.

        Key ScriptingBridge patterns:
        - Connect: `guard let app: ProtocolName = SBApplication(bundleIdentifier: "...") else { return 1 }`
        - Element arrays: `app.accounts?()` returns SBElementArray, iterate with `.object(at: i) as? Type`
        - Properties are @objc optional: always use `?.` and `??` for defaults
        - Methods like moveTo, delete: `object.moveTo?(target as? SBObject)`
        - NEVER do redundant conditional downcasts on SBObject — `as? SBObject` on a value that is \
        already `SBObject?` does nothing and produces a compiler warning. Just use optional binding: \
        `if let container = track.container { ... }` — NOT `if let container = track.container as? SBObject`.
        - MUSIC: To add tracks to a playlist, use the library playlist's searchFor method to find tracks, \
        then call duplicateTo on each result to copy it into the target playlist:
        ```
        guard let library = music.playlists?().object(at: 0) as? MusicLibraryPlaylist else { return 1 }
        let results = library.searchFor("Song Name", only: .names)
        // results is an SBObject acting as an array — iterate with value(forKey:)
        if let tracks = (results as? SBObject)?.value(forKey: "get") as? [SBObject] {
            for track in tracks {
                if let t = track as? MusicTrack, t.artist?.lowercased().contains("artist") == true {
                    t.duplicateTo?(targetPlaylist as SBObject)
                }
            }
        }
        ```
        NEVER iterate all library tracks manually — use searchFor instead (instant vs minutes).
        - For apps not yet in the package, generate a new bridge file using the GenerateBridge script:
          1. Run: `run_agent_script GenerateBridge` with arguments: `/Applications/AppName.app`
          2. The generated file lands in Sources/XCFScriptingBridges/
          3. Add the new bridge name to bridgeNames in Package.swift
          The script handles the full sdef → sdp → Swift conversion pipeline automatically.

        DYNAMIC APPLE EVENT QUERIES — apple_event_query:
        For quick, one-off queries against any scriptable Mac app, use apple_event_query \
        instead of writing a full Swift script. It uses ObjC dynamic dispatch (value(forKey:)) \
        so no compilation is needed. Pass a bundle_id and an array of operations:
        - "get" {key}: walk the object graph (e.g. "tracks", "name", "currentTrack")
        - "iterate" {properties, limit}: read properties from each item in an SBElementArray
        - "index" {index}: pick one item from an array by index
        - "call" {method, arg}: invoke a method (e.g. "playpause", "searchFor" with arg)
        - "filter" {predicate}: NSPredicate filter on an SBElementArray
        Examples:
        Get current Music track: bundle_id="com.apple.Music", operations=[{action:"get",key:"currentTrack"},{action:"iterate",properties:["name","artist","album"]}]
        List Safari windows: bundle_id="com.apple.Safari", operations=[{action:"get",key:"windows"},{action:"iterate",properties:["name"],limit:10}]
        List first 5 Notes: bundle_id="com.apple.Notes", operations=[{action:"get",key:"notes"},{action:"iterate",properties:["name"],limit:5}]
        Write operations (delete, close, move, etc.) are blocked by default. Set allow_writes=true to permit them.
        Use apple_event_query for reading data; use compiled scripts for complex logic.

        You can also control Xcode directly via built-in tools:
        Use xcode_grant_permission once to authorize Automation access, then \
        xcode_build to build a project (returns errors/warnings), and \
        xcode_run to run a project.
        """
    }

    // MARK: - Tool Definitions (internal, format-neutral)

    private struct ToolDef {
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
            description: "Create or overwrite a file. Use instead of heredocs or echo redirection. Creates parent directories automatically.",
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
            description: "Query any scriptable Mac app dynamically via ScriptingBridge. No compilation needed. Walks the object graph using ObjC dynamic dispatch. Use this FIRST for reading app data (mail, notes, music, safari, calendar, reminders, etc.).",
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
            name: "execute_user_command",
            description: "Execute a shell command as the current user (no root). Use this for most tasks: git, builds, scripts, homebrew, etc.",
            properties: [
                "command": ["type": "string", "description": "The bash command to execute as the current user"],
            ],
            required: ["command"]
        ),
        ToolDef(
            name: "execute_command",
            description: "Execute a shell command with ROOT privileges via the privileged daemon. Only use when root is required: system packages, /System or /Library modifications, disk operations, launchd services, or changing ownership outside user home.",
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
            description: "Compile and run a Swift dylib script from ~/Documents/Agent/agents/. Output is streamed live to the activity log — do NOT repeat or summarize stdout output. For structured data, write a JSON input file first via execute_user_command, then run the script.",
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
        var tools = commonTools.map { tool in
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

    /// All common tools + Ollama-specific tools + MCP tools in Ollama/OpenAI format.
    @MainActor static var ollamaFormat: [[String: Any]] {
        var tools = (commonTools + ollamaOnlyTools).map { tool in
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
}
