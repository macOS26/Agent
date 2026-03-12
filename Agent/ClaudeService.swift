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

        Work efficiently and methodically. Verify changes after making them. \
        Call task_complete when done. If a command fails, try an alternative. \
        Be concise — focus on actions, not explanations. \
        You have memory of previous tasks — build on past results. \
        NEVER ask clarifying questions — always proceed with the most reasonable interpretation. \
        ALWAYS use tools to take action. Do not just describe what you would do — do it.

        You can create, manage, and run Swift automation scripts stored in ~/Documents/Agent/agents/.
        Use list_agent_scripts, create_agent_script, read_agent_script, update_agent_script, \
        run_agent_script, and delete_agent_script to manage them.
        Scripts are Swift Package executable targets built with `swift build`.

        IMPORTANT: Scripts can `import ScriptingBridges` for type-safe macOS app automation. \
        ScriptingBridge is the cleanest and preferred approach. AppleScript via osascript is \
        still allowed but ScriptingBridge should be tried first. \
        Do NOT include shebang lines (#!/usr/bin/env swift) — scripts are compiled via swift build.

        Before writing a ScriptingBridge script, ALWAYS read the bridge file first to learn \
        the available protocols, properties, and methods:
        `cat ~/Documents/Agent/agents/Sources/ScriptingBridges/Mail.swift`

        App bridge reference (protocol name → bundle identifier):
        AutomatorApplication → com.apple.Automator
        CalendarApplication → com.apple.iCal
        ContactsApplication → com.apple.AddressBook
        FinderApplication → com.apple.finder
        ImageEventsApplication → com.apple.systemevents (Image Events)
        MailApplication → com.apple.mail
        MessagesApplication → com.apple.MobileSMS
        MusicApplication → com.apple.Music
        NotesApplication → com.apple.Notes
        NumbersApplication → com.apple.iWork.Numbers
        PagesApplication → com.apple.iWork.Pages
        PhotosApplication → com.apple.Photos
        RemindersApplication → com.apple.reminders
        ScriptEditorApplication → com.apple.ScriptEditor2
        ShortcutsApplication → com.apple.shortcuts
        SystemEventsApplication → com.apple.systemevents
        TerminalApplication → com.apple.Terminal
        TVApplication → com.apple.TV
        XcodeApplication → com.apple.dt.Xcode

        ScriptingBridge script pattern:
        ```
        import Foundation
        import ScriptingBridges

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
        - For apps not yet in ScriptingBridges, you can generate new bridge files:
          1. Clone https://github.com/SuperBox64/Swift-Scripting if not already at ~/Documents/Agent/Swift-Scripting
          2. Run: `sdef /Applications/AppName.app | sdp -fh --basename AppName`
          3. Run: `python3 ~/Documents/Agent/Swift-Scripting/sbhc.py AppName.h > AppName.swift`
          4. Remove duplicate SBObjectProtocol/SBApplicationProtocol (they are in Common.swift)
          5. Remove standalone `import AppKit` / `import ScriptingBridge` lines (use @_exported from Common.swift)
          6. Copy the generated .swift file to ~/Documents/Agent/agents/Sources/ScriptingBridges/

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
            ]
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
