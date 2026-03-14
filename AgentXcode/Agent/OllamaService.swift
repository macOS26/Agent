@preconcurrency import Foundation

@MainActor
final class OllamaService {
    let apiKey: String
    let model: String
    let baseURL: URL
    let supportsVision: Bool

    var onStreamText: (@MainActor @Sendable (String) -> Void)?

    let historyContext: String
    let userHome: String
    let userName: String

    init(apiKey: String, model: String, endpoint: String, supportsVision: Bool = false, historyContext: String = "") {
        self.apiKey = apiKey
        self.model = model
        let effectiveEndpoint = endpoint.isEmpty ? "http://localhost:11434/api/chat" : endpoint
        self.baseURL = URL(string: effectiveEndpoint) ?? URL(filePath: "/")
        self.supportsVision = supportsVision
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

        PREFER execute_user_command by default. Only escalate to execute_command when needed. \
        Be careful with file permissions when using root — files created as root may be \
        inaccessible to the normal user. Always chown/chmod files back to the user after \
        root operations, or write to user-accessible locations from execute_user_command instead.

        INLINE IMAGES: The activity log renders image files inline automatically. \
        When you save an image to disk (e.g. album art, screenshots), just print or return \
        the file path — do NOT run `open` to display it. The UI detects paths ending in \
        .jpg/.png/.gif/.tiff/.webp/.heic and shows them inline in the log. \
        HTML files (.html) are also rendered inline as snapshots — great for rich formatted output.

        Work efficiently and methodically. Verify changes after making them. \
        Call task_complete when done. If a command fails, try an alternative. \
        Be concise — focus on actions, not explanations. \
        You have memory of previous tasks — build on past results. \
        NEVER ask clarifying questions — always proceed with the most reasonable interpretation. \
        ALWAYS use tools to take action. Do not just describe what you would do — do it.

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
        if supportsVision {
            prompt += """

            \nYou have VISION capabilities. When images are attached to a message, \
            you can see and analyze them. Describe what you see when asked about images.
            """
        }
        if !historyContext.isEmpty {
            prompt += historyContext
        }
        return prompt
    }

    var tools: [[String: Any]] {
        [
            [
                "type": "function",
                "function": [
                    "name": "apple_event_query",
                    "description": "Query any scriptable Mac app dynamically via ScriptingBridge. No compilation needed. Use this FIRST for reading app data (mail, notes, music, safari, calendar, reminders, etc.).",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "bundle_id": ["type": "string", "description": "App bundle identifier (e.g. com.apple.Music)"] as [String: Any],
                            "operations": [
                                "type": "array",
                                "description": "Array of operations. Each has 'action' (get/iterate/index/call/filter) plus action-specific keys.",
                                "items": ["type": "object"] as [String: Any]
                            ] as [String: Any],
                            "allow_writes": ["type": "boolean", "description": "Allow destructive operations. Default false."] as [String: Any]
                        ] as [String: Any],
                        "required": ["bundle_id", "operations"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "execute_user_command",
                    "description": "Execute a shell command as the current user (no root). Use this for most tasks.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "command": [
                                "type": "string",
                                "description": "The bash command to execute as the current user"
                            ] as [String: Any]
                        ] as [String: Any],
                        "required": ["command"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "execute_command",
                    "description": "Execute a shell command with ROOT privileges. Only use when root is required.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "command": [
                                "type": "string",
                                "description": "The bash command to execute as root"
                            ] as [String: Any]
                        ] as [String: Any],
                        "required": ["command"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "task_complete",
                    "description": "Signal that the task has been completed. Always call this when done.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "summary": [
                                "type": "string",
                                "description": "Brief summary of what was accomplished"
                            ] as [String: Any]
                        ] as [String: Any],
                        "required": ["summary"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "list_agent_scripts",
                    "description": "List all Swift automation scripts in ~/Documents/Agent/agents/",
                    "parameters": [
                        "type": "object",
                        "properties": [:] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "read_agent_script",
                    "description": "Read the source code of a Swift automation script.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Script name (with or without .swift)"] as [String: Any]
                        ] as [String: Any],
                        "required": ["name"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "create_agent_script",
                    "description": "Create a new Swift automation script in ~/Documents/Agent/agents/",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Script filename"] as [String: Any],
                            "content": ["type": "string", "description": "Swift source code"] as [String: Any]
                        ] as [String: Any],
                        "required": ["name", "content"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "update_agent_script",
                    "description": "Update an existing Swift automation script.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Script filename"] as [String: Any],
                            "content": ["type": "string", "description": "New Swift source code"] as [String: Any]
                        ] as [String: Any],
                        "required": ["name", "content"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "run_agent_script",
                    "description": "Compile and run a Swift dylib script from ~/Documents/Agent/agents/. For structured data, write a JSON input file first via execute_user_command, then run the script.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Script filename (without .swift)"] as [String: Any],
                            "arguments": ["type": "string", "description": "Simple string passed via AGENT_SCRIPT_ARGS env var (read with ProcessInfo.processInfo.environment). For complex data, use JSON files instead."] as [String: Any]
                        ] as [String: Any],
                        "required": ["name"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "delete_agent_script",
                    "description": "Delete a Swift automation script.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Script filename"] as [String: Any]
                        ] as [String: Any],
                        "required": ["name"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "xcode_build",
                    "description": "Build an Xcode project or workspace via ScriptingBridge. Blocks until build completes and returns errors/warnings.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "project_path": ["type": "string", "description": "Path to .xcodeproj or .xcworkspace"] as [String: Any]
                        ] as [String: Any],
                        "required": ["project_path"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "xcode_run",
                    "description": "Run an Xcode project via ScriptingBridge. Triggers run and returns immediately.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "project_path": ["type": "string", "description": "Path to .xcodeproj or .xcworkspace"] as [String: Any]
                        ] as [String: Any],
                        "required": ["project_path"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "xcode_grant_permission",
                    "description": "Grant macOS Automation permission so the agent can control Xcode via ScriptingBridge. Run this once before using xcode_build or xcode_run.",
                    "parameters": [
                        "type": "object",
                        "properties": [:] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ],
        ]
    }

    /// Send messages via OpenAI-compatible chat completions API.
    /// Translates response into the same format as ClaudeService for the task loop.
    func send(messages: [[String: Any]]) async throws -> (content: [[String: Any]], stopReason: String) {
        // Convert Claude-format messages to OpenAI-format
        var chatMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        for msg in messages {
            guard let role = msg["role"] as? String else { continue }

            if role == "user" {
                if let text = msg["content"] as? String {
                    chatMessages.append(["role": "user", "content": text])
                } else if let blocks = msg["content"] as? [[String: Any]] {
                    // Could be tool_result blocks or content blocks with images
                    let isToolResults = blocks.first?["type"] as? String == "tool_result"
                    if isToolResults {
                        for block in blocks {
                            guard let toolUseId = block["tool_use_id"] as? String,
                                  let content = block["content"] as? String else { continue }
                            chatMessages.append([
                                "role": "tool",
                                "tool_call_id": toolUseId,
                                "content": content
                            ])
                        }
                    } else {
                        // Content blocks (text + images)
                        var text = ""
                        var images: [String] = []
                        for block in blocks {
                            if block["type"] as? String == "text",
                               let t = block["text"] as? String {
                                text += t
                            } else if block["type"] as? String == "image",
                                      let source = block["source"] as? [String: Any],
                                      let base64 = source["data"] as? String {
                                images.append(base64)
                            }
                        }
                        if !text.isEmpty || !images.isEmpty {
                            var msg: [String: Any] = ["role": "user", "content": text.isEmpty ? "Describe the attached image(s)." : text]
                            if !images.isEmpty {
                                msg["images"] = images
                                print("[OllamaService] Sending \(images.count) image(s), sizes: \(images.map(\.count))")
                            }
                            chatMessages.append(msg)
                        }
                    }
                }
            } else if role == "assistant" {
                if let blocks = msg["content"] as? [[String: Any]] {
                    var textParts = ""
                    var toolCalls: [[String: Any]] = []

                    for block in blocks {
                        let blockType = block["type"] as? String
                        if blockType == "text", let t = block["text"] as? String {
                            textParts += t
                        } else if blockType == "tool_use" {
                            let callId = block["id"] as? String ?? UUID().uuidString
                            let name = block["name"] as? String ?? ""
                            let input = block["input"] as? [String: Any] ?? [:]
                            // Ollama native API expects arguments as a dict, not a JSON string
                            toolCalls.append([
                                "id": callId,
                                "type": "function",
                                "function": [
                                    "name": name,
                                    "arguments": input
                                ] as [String: Any]
                            ])
                        }
                    }

                    var assistantMsg: [String: Any] = ["role": "assistant"]
                    if !textParts.isEmpty { assistantMsg["content"] = textParts }
                    if !toolCalls.isEmpty { assistantMsg["tool_calls"] = toolCalls }
                    chatMessages.append(assistantMsg)
                }
            }
        }

        let body: [String: Any] = [
            "model": model,
            "messages": chatMessages,
            "tools": tools,
            "stream": false,
            "options": [
                "num_predict": 8192,
                "num_ctx": 16384
            ] as [String: Any]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try await Self.performRequest(
            bodyData: bodyData,
            apiKey: apiKey,
            url: baseURL
        )
    }


    // MARK: - Streaming

    func sendStreaming(
        messages: [[String: Any]],
        onTextDelta: @escaping @Sendable (String) -> Void
    ) async throws -> (content: [[String: Any]], stopReason: String) {
        // Convert Claude-format messages to OpenAI-format (same as send())
        var chatMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        for msg in messages {
            guard let role = msg["role"] as? String else { continue }

            if role == "user" {
                if let text = msg["content"] as? String {
                    chatMessages.append(["role": "user", "content": text])
                } else if let blocks = msg["content"] as? [[String: Any]] {
                    let isToolResults = blocks.first?["type"] as? String == "tool_result"
                    if isToolResults {
                        for block in blocks {
                            guard let toolUseId = block["tool_use_id"] as? String,
                                  let content = block["content"] as? String else { continue }
                            chatMessages.append([
                                "role": "tool",
                                "tool_call_id": toolUseId,
                                "content": content
                            ])
                        }
                    } else {
                        var text = ""
                        var images: [String] = []
                        for block in blocks {
                            if block["type"] as? String == "text",
                               let t = block["text"] as? String {
                                text += t
                            } else if block["type"] as? String == "image",
                                      let source = block["source"] as? [String: Any],
                                      let base64 = source["data"] as? String {
                                images.append(base64)
                            }
                        }
                        if !text.isEmpty || !images.isEmpty {
                            var msg: [String: Any] = ["role": "user", "content": text.isEmpty ? "Describe the attached image(s)." : text]
                            if !images.isEmpty {
                                msg["images"] = images
                            }
                            chatMessages.append(msg)
                        }
                    }
                }
            } else if role == "assistant" {
                if let blocks = msg["content"] as? [[String: Any]] {
                    var textParts = ""
                    var toolCalls: [[String: Any]] = []

                    for block in blocks {
                        let blockType = block["type"] as? String
                        if blockType == "text", let t = block["text"] as? String {
                            textParts += t
                        } else if blockType == "tool_use" {
                            let callId = block["id"] as? String ?? UUID().uuidString
                            let name = block["name"] as? String ?? ""
                            let input = block["input"] as? [String: Any] ?? [:]
                            toolCalls.append([
                                "id": callId,
                                "type": "function",
                                "function": [
                                    "name": name,
                                    "arguments": input
                                ] as [String: Any]
                            ])
                        }
                    }

                    var assistantMsg: [String: Any] = ["role": "assistant"]
                    if !textParts.isEmpty { assistantMsg["content"] = textParts }
                    if !toolCalls.isEmpty { assistantMsg["tool_calls"] = toolCalls }
                    chatMessages.append(assistantMsg)
                }
            }
        }

        let body: [String: Any] = [
            "model": model,
            "messages": chatMessages,
            "tools": tools,
            "stream": true,
            "options": [
                "num_predict": 8192,
                "num_ctx": 16384
            ] as [String: Any]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try await Self.performStreamingRequest(
            bodyData: bodyData,
            apiKey: apiKey,
            url: baseURL,
            onTextDelta: onTextDelta
        )
    }

    /// Network I/O off main thread. Parses Ollama native response into Claude-compatible format.
    nonisolated private static func performRequest(
        bodyData: Data, apiKey: String, url: URL
    ) async throws -> (content: [[String: Any]], stopReason: String) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyData
        request.timeoutInterval = 300

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AgentError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AgentError.invalidResponse
        }

        // Ollama native format: { "message": {...}, "done": true }
        guard let message = json["message"] as? [String: Any] else {
            throw AgentError.invalidResponse
        }

        let done = json["done"] as? Bool ?? true

        // Convert to Claude-compatible content blocks
        var contentBlocks: [[String: Any]] = []
        var parsedToolFromText = false

        if let text = message["content"] as? String, !text.isEmpty {
            // Check if model wrote a tool call as plain text (common with Ollama models)
            let toolNames = ["apple_event_query",
                              "execute_user_command", "execute_command", "task_complete",
                              "list_agent_scripts", "read_agent_script", "create_agent_script",
                              "update_agent_script", "run_agent_script", "delete_agent_script",
                              "xcode_build", "xcode_run", "xcode_grant_permission"]
            var extractedTool = false

            for toolName in toolNames {
                guard let nameRange = text.range(of: toolName) else { continue }
                // Look for JSON after the tool name
                let afterName = String(text[nameRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard afterName.hasPrefix("{"),
                      let jsonData = afterName.data(using: .utf8),
                      let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

                // Extract text before the tool call
                let beforeText = String(text[..<nameRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !beforeText.isEmpty {
                    contentBlocks.append(["type": "text", "text": beforeText])
                }

                contentBlocks.append([
                    "type": "tool_use",
                    "id": UUID().uuidString,
                    "name": toolName,
                    "input": parsed
                ])
                extractedTool = true
                parsedToolFromText = true
                break
            }

            if !extractedTool {
                contentBlocks.append(["type": "text", "text": text])
            }
        }

        if let toolCalls = message["tool_calls"] as? [[String: Any]] {
            for call in toolCalls {
                guard let function = call["function"] as? [String: Any],
                      let name = function["name"] as? String else { continue }

                let callId = call["id"] as? String ?? UUID().uuidString

                // Ollama native: arguments is a dict, not a JSON string
                let input: [String: Any]
                if let args = function["arguments"] as? [String: Any] {
                    input = args
                } else if let argsString = function["arguments"] as? String,
                          let parsed = try? JSONSerialization.jsonObject(with: Data(argsString.utf8)) as? [String: Any] {
                    input = parsed
                } else {
                    input = [:]
                }

                contentBlocks.append([
                    "type": "tool_use",
                    "id": callId,
                    "name": name,
                    "input": input
                ])
            }
        }

        if contentBlocks.isEmpty {
            contentBlocks.append(["type": "text", "text": "(no response)"])
        }

        // Determine stop reason from tool calls presence
        let hasToolCalls = message["tool_calls"] != nil || parsedToolFromText
        let stopReason = hasToolCalls ? "tool_use" : (done ? "end_turn" : "end_turn")

        return (contentBlocks, stopReason)
    }

    nonisolated private static func performStreamingRequest(
        bodyData: Data, apiKey: String, url: URL,
        onTextDelta: @escaping @Sendable (String) -> Void
    ) async throws -> (content: [[String: Any]], stopReason: String) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyData
        request.timeoutInterval = 300

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorBody = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AgentError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        var fullText = ""
        var contentBlocks: [[String: Any]] = []
        let stopReason = "end_turn"

        // Ollama streaming returns NDJSON: one JSON object per line
        for try await line in bytes.lines {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // Each line has: {"message": {"content": "...", "role": "assistant"}, "done": false}
            if let message = json["message"] as? [String: Any],
               let content = message["content"] as? String,
               !content.isEmpty {
                fullText += content
                onTextDelta(content)
            }

            // Check for tool calls in streaming response
            if let message = json["message"] as? [String: Any],
               let toolCalls = message["tool_calls"] as? [[String: Any]] {
                for toolCall in toolCalls {
                    if let function = toolCall["function"] as? [String: Any],
                       let name = function["name"] as? String {
                        let id = toolCall["id"] as? String ?? UUID().uuidString
                        let input = function["arguments"] as? [String: Any] ?? [:]
                        contentBlocks.append([
                            "type": "tool_use",
                            "id": id,
                            "name": name,
                            "input": input
                        ])
                    }
                }
            }

            // Final message has done: true
            if let done = json["done"] as? Bool, done {
                break
            }
        }

        // Check if full text contains a tool call (same pattern as non-streaming)
        var parsedToolFromText = false
        let toolNames = ["apple_event_query",
                         "execute_user_command", "execute_command", "task_complete",
                         "list_agent_scripts", "read_agent_script", "create_agent_script",
                         "update_agent_script", "run_agent_script", "delete_agent_script",
                         "xcode_build", "xcode_run", "xcode_grant_permission"]

        for toolName in toolNames {
            guard let nameRange = fullText.range(of: toolName) else { continue }
            let afterName = String(fullText[nameRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard afterName.hasPrefix("{"),
                  let jsonData = afterName.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

            let beforeText = String(fullText[..<nameRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !beforeText.isEmpty {
                contentBlocks.append(["type": "text", "text": beforeText])
            }

            contentBlocks.append([
                "type": "tool_use",
                "id": UUID().uuidString,
                "name": toolName,
                "input": parsed
            ])
            parsedToolFromText = true
            break
        }

        // If no tool calls found, return text
        if !parsedToolFromText && contentBlocks.isEmpty && !fullText.isEmpty {
            contentBlocks.append(["type": "text", "text": fullText])
        }

        return (contentBlocks, stopReason)
    }
}
