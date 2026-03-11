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
        You are an autonomous macOS agent with root privileges via a privileged launch daemon. \
        You can execute any shell command with root access. \
        Work efficiently and methodically to complete tasks. \
        Always verify your changes after making them. \
        When the task is fully complete, call the task_complete tool with a summary. \
        If a command fails, analyze the error and try an alternative approach. \
        Be concise in your text responses - focus on actions, not explanations. \
        You have memory of previous tasks - use this context to avoid repeating work and to build on past results.

        IMPORTANT: Commands run as root via the daemon. The ~ shortcut expands to /var/root (root's home), \
        NOT the user's home directory. Always use the full path "\(userHome)" instead of ~ when \
        targeting the user's files. The current user is "\(userName)" with home directory "\(userHome)".
        """
        if !historyContext.isEmpty {
            prompt += historyContext
        }
        return prompt
    }

    var tools: [[String: Any]] {
        [
            [
                "name": "execute_command",
                "description": "Execute a shell command with root privileges. Returns combined stdout/stderr and exit code.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "command": [
                            "type": "string",
                            "description": "The bash command to execute"
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
