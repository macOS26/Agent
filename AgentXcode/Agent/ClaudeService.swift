@preconcurrency import Foundation

@MainActor
final class ClaudeService {
    let apiKey: String
    let model: String

    private static let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"

    let historyContext: String
    let userHome: String
    let userName: String

    init(apiKey: String, model: String, historyContext: String = "") {
        self.apiKey = apiKey
        self.model = model
        self.historyContext = historyContext
        self.userHome = FileManager.default.homeDirectoryForCurrentUser.path
        self.userName = NSUserName()
    }

    var systemPrompt: String {
        var prompt = """
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

        PREFER execute_user_command by default. Only escalate to execute_command when needed.

        INLINE IMAGES: The activity log renders image files inline automatically. \
        When you save an image to disk (e.g. album art, screenshots), just print or return \
        the file path — do NOT run `open` to display it. The UI detects paths ending in \
        .jpg/.png/.gif/.tiff/.webp/.heic and shows them inline in the log.

        Work efficiently and methodically. Verify changes after making them. \
        Call task_complete when done. If a command fails, try an alternative. \
        Be concise — focus on actions, not explanations. \
        You have memory of previous tasks — build on past results. \
        NEVER ask clarifying questions — always proceed with the most reasonable interpretation. \
        ALWAYS use tools to take action. Do not just describe what you would do — do it.

        TOOL SELECTION — choose the right approach in priority order:
        1. osascript via execute_user_command — Run this FIRST for any new app to establish \
        macOS Automation permissions. Use `osascript -e '...'` or `osascript <<'EOF' ... EOF` \
        for multi-line. This triggers the permission dialog so subsequent tools work. \
        Good for app automation, write actions, multi-step workflows, and tell blocks.
        2. apple_event_query — ZERO compilation. Use for simple, quick queries once permissions \
        are already granted (by a prior osascript call). Instant results via ObjC dynamic dispatch. \
        Best for reading app data (mail, notes, music, reminders, safari tabs, etc.).
        3. run_agent_script — Native Swift ScriptingBridge scripts. Use for persistent, repeatable \
        automation and longer scripts that benefit from type-safe Swift code and compiled performance. \
        These scripts have memory — they persist in ~/Documents/Agent/agents/ across sessions. \
        Compiles with `swift build --product <name>` (fast incremental builds). \
        NEVER run bare `swift build` without --product — that compiles ALL 45+ bridges.
        4. Embedded AppleScript — Last resort fallback. Use inline osascript via execute_user_command \
        only when the above approaches fail or are not suitable.

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
        import XcodeBridge → XcodeApplication → com.apple.dt.Xcode
        import SafariBridge → SafariApplication → com.apple.Safari
        import GoogleChromeBridge → GoogleChromeApplication → com.google.Chrome
        import FirefoxBridge → FirefoxApplication → org.mozilla.firefox
        import KeynoteBridge → KeynoteApplication → com.apple.Keynote (or com.apple.iWork.Keynote)
        import PreviewBridge → PreviewApplication → com.apple.Preview
        import TextEditBridge → TextEditApplication → com.apple.TextEdit
        import QuickTimePlayerBridge → QuickTimePlayerApplication → com.apple.QuickTimePlayerX

        ScriptingBridge script pattern:
        ```
        import Foundation
        import MailBridge

        guard let mail: MailApplication = SBApplication(bundleIdentifier: "com.apple.mail") else {
            print("Could not connect to Mail")
            exit(1)
        }
        // Element arrays: use .object(at:) and cast to the protocol type
        guard let accounts = mail.accounts?() else { exit(0) }
        for i in 0..<accounts.count {
            guard let acct = accounts.object(at: i) as? MailAccount,
                  let name = acct.name else { continue }
            print("Account: \\(name)")
            // Nested element arrays
            if let mailboxes = acct.mailboxes?() {
                for j in 0..<mailboxes.count {
                    if let mb = mailboxes.object(at: j) as? MailMailbox {
                        print("  \\(mb.name ?? "?") — \\(mb.unreadCount ?? 0) unread")
                    }
                }
            }
        }
        // Methods on SBObject: cast first, e.g. message.moveTo?(target as? SBObject)
        ```

        Key ScriptingBridge patterns:
        - Connect: `guard let app: ProtocolName = SBApplication(bundleIdentifier: "...") else { exit(1) }`
        - Element arrays: `app.accounts?()` returns SBElementArray, iterate with `.object(at: i) as? Type`
        - Properties are @objc optional: always use `?.` and `??` for defaults
        - Methods like moveTo, delete: `object.moveTo?(target as? SBObject)`
        - MUSIC: To add tracks to a playlist, use the library playlist's searchFor method to find tracks, \
        then call duplicateTo on each result to copy it into the target playlist:
        ```
        let library = (music.playlists?().object(at: 0) as? MusicLibraryPlaylist)!
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
        if !historyContext.isEmpty {
            prompt += historyContext
        }
        return prompt
    }

    var tools: [[String: Any]] {
        [
            [
                "name": "apple_event_query",
                "description": "Query any scriptable Mac app dynamically via ScriptingBridge. No compilation needed. Walks the object graph using ObjC dynamic dispatch. Use this FIRST for reading app data (mail, notes, music, safari, calendar, reminders, etc.).",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "bundle_id": ["type": "string", "description": "App bundle identifier (e.g. com.apple.Music)"] as [String: Any],
                        "operations": [
                            "type": "array",
                            "description": "Array of operations to execute sequentially. Each has an 'action' key.",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "action": ["type": "string", "description": "One of: get, iterate, index, call, filter"] as [String: Any],
                                    "key": ["type": "string", "description": "Property key for 'get'"] as [String: Any],
                                    "properties": ["type": "array", "items": ["type": "string"] as [String: Any], "description": "Properties to read for 'iterate'"] as [String: Any],
                                    "limit": ["type": "integer", "description": "Max items for 'iterate' (default 50)"] as [String: Any],
                                    "index": ["type": "integer", "description": "Array index for 'index'"] as [String: Any],
                                    "method": ["type": "string", "description": "Method name for 'call'"] as [String: Any],
                                    "arg": ["type": "string", "description": "Optional argument for 'call'"] as [String: Any],
                                    "predicate": ["type": "string", "description": "NSPredicate format string for 'filter'"] as [String: Any]
                                ] as [String: Any],
                                "required": ["action"]
                            ] as [String: Any]
                        ] as [String: Any],
                        "allow_writes": ["type": "boolean", "description": "Allow destructive operations (delete, close, move, etc.). Default false."] as [String: Any]
                    ] as [String: Any],
                    "required": ["bundle_id", "operations"]
                ] as [String: Any]
            ],
            [
                "name": "execute_user_command",
                "description": "Execute a shell command as the current user (no root). Use this for most tasks: file editing, git, builds, scripts, homebrew, etc.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "command": [
                            "type": "string",
                            "description": "The bash command to execute as the current user"
                        ] as [String: Any]
                    ] as [String: Any],
                    "required": ["command"]
                ] as [String: Any]
            ],
            [
                "name": "execute_command",
                "description": "Execute a shell command with ROOT privileges via the privileged daemon. Only use when root is required: system packages, /System or /Library modifications, disk operations, launchd services, or changing ownership outside user home.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "command": [
                            "type": "string",
                            "description": "The bash command to execute as root"
                        ] as [String: Any]
                    ] as [String: Any],
                    "required": ["command"]
                ] as [String: Any]
            ],
            [
                "name": "task_complete",
                "description": "Signal that the task has been completed. Always call this when done.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "summary": [
                            "type": "string",
                            "description": "Brief summary of what was accomplished"
                        ] as [String: Any]
                    ] as [String: Any],
                    "required": ["summary"]
                ] as [String: Any]
            ],
            [
                "name": "list_agent_scripts",
                "description": "List all Swift automation scripts in ~/Documents/Agent/agents/",
                "input_schema": [
                    "type": "object",
                    "properties": [:] as [String: Any]
                ] as [String: Any]
            ],
            [
                "name": "read_agent_script",
                "description": "Read the source code of a Swift automation script.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Script name (with or without .swift)"] as [String: Any]
                    ] as [String: Any],
                    "required": ["name"]
                ] as [String: Any]
            ],
            [
                "name": "create_agent_script",
                "description": "Create a new Swift automation script in ~/Documents/Agent/agents/",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Script filename (with or without .swift)"] as [String: Any],
                        "content": ["type": "string", "description": "Swift source code"] as [String: Any]
                    ] as [String: Any],
                    "required": ["name", "content"]
                ] as [String: Any]
            ],
            [
                "name": "update_agent_script",
                "description": "Update an existing Swift automation script.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Script filename"] as [String: Any],
                        "content": ["type": "string", "description": "New Swift source code"] as [String: Any]
                    ] as [String: Any],
                    "required": ["name", "content"]
                ] as [String: Any]
            ],
            [
                "name": "run_agent_script",
                "description": "Compile and execute a Swift script from ~/Documents/Agent/agents/ using swiftc. Scripts can import Foundation, AppKit, or ScriptingBridge.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Script filename"] as [String: Any],
                        "arguments": ["type": "string", "description": "Optional command-line arguments"] as [String: Any]
                    ] as [String: Any],
                    "required": ["name"]
                ] as [String: Any]
            ],
            [
                "name": "delete_agent_script",
                "description": "Delete a Swift automation script.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Script filename"] as [String: Any]
                    ] as [String: Any],
                    "required": ["name"]
                ] as [String: Any]
            ],
            [
                "name": "xcode_build",
                "description": "Build an Xcode project or workspace via ScriptingBridge. Blocks until build completes and returns errors/warnings.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "project_path": ["type": "string", "description": "Path to .xcodeproj or .xcworkspace"] as [String: Any]
                    ] as [String: Any],
                    "required": ["project_path"]
                ] as [String: Any]
            ],
            [
                "name": "xcode_run",
                "description": "Run an Xcode project via ScriptingBridge. Triggers run and returns immediately.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "project_path": ["type": "string", "description": "Path to .xcodeproj or .xcworkspace"] as [String: Any]
                    ] as [String: Any],
                    "required": ["project_path"]
                ] as [String: Any]
            ],
            [
                "name": "xcode_grant_permission",
                "description": "Grant macOS Automation permission so the agent can control Xcode via ScriptingBridge. Run this once before using xcode_build or xcode_run.",
                "input_schema": [
                    "type": "object",
                    "properties": [:] as [String: Any]
                ] as [String: Any]
            ],
        ]
    }

    func send(messages: [[String: Any]]) async throws -> (content: [[String: Any]], stopReason: String) {
        guard !apiKey.isEmpty else { throw AgentError.noAPIKey }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": systemPrompt,
            "tools": tools,
            "messages": messages
        ]

        // Serialize on main actor, then offload network I/O + response parsing
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try await Self.performRequest(
            bodyData: bodyData,
            apiKey: apiKey,
            apiVersion: Self.apiVersion,
            url: Self.baseURL
        )
    }

    /// Network I/O and response parsing off the main thread
    nonisolated private static func performRequest(
        bodyData: Data, apiKey: String, apiVersion: String, url: URL
    ) async throws -> (content: [[String: Any]], stopReason: String) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = bodyData
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AgentError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let stopReason = json["stop_reason"] as? String else {
            throw AgentError.invalidResponse
        }

        return (content, stopReason)
    }
}
