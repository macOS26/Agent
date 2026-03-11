@preconcurrency import Foundation

@MainActor
final class OllamaService {
    let apiKey: String
    let model: String
    let baseURL: URL
    let supportsVision: Bool

    let historyContext: String
    let userHome: String
    let userName: String

    init(apiKey: String, model: String, endpoint: String, supportsVision: Bool = false, historyContext: String = "") {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = URL(string: endpoint)!
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

        PREFER execute_user_command by default. Only escalate to execute_command when needed.

        Work efficiently and methodically. Verify changes after making them. \
        Call task_complete when done. If a command fails, try an alternative. \
        Be concise — focus on actions, not explanations. \
        You have memory of previous tasks — build on past results. \
        NEVER ask clarifying questions — always proceed with the most reasonable interpretation. \
        ALWAYS use tools to take action. Do not just describe what you would do — do it.
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
            ]
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
            let toolNames = ["execute_user_command", "execute_command", "task_complete"]
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
}
