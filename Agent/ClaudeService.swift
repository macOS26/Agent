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
        Scripts can `import ScriptingBridges` to get type-safe ScriptingBridge protocols for macOS apps.

        Available ScriptingBridge apps (via `import ScriptingBridges`):
        Automator, Calendar, Contacts, Finder, ImageEvents, Mail, Messages, Music, \
        Notes, Numbers, Pages, Photos, Reminders, ScriptEditor, Shortcuts, \
        SystemEvents, Terminal, TV, Xcode.

        ScriptingBridge pattern — ALWAYS use this instead of osascript/AppleScript:
        1. `import ScriptingBridges` (provides all protocols and SBApplication/SBObject extensions)
        2. `let app: AppProtocol = SBApplication(bundleIdentifier: "com.apple.mail")!`
        3. Access properties and methods via the protocol (all are @objc optional)
        Example: `let count = mail.accounts?()?.count ?? 0`

        You can control Xcode directly via ScriptingBridge:
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
