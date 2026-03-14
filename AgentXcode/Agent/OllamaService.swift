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
        var prompt = AgentTools.systemPrompt(userName: userName, userHome: userHome)
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

    var tools: [[String: Any]] { AgentTools.ollamaFormat }

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
            let toolNames = ["read_file", "write_file", "edit_file", "list_files", "search_files",
                              "git_status", "git_diff", "git_log", "git_commit", "git_diff_patch", "git_branch",
                              "apple_event_query",
                              "execute_user_command", "execute_command", "task_complete",
                              "list_agent_scripts", "read_agent_script", "create_agent_script",
                              "update_agent_script", "run_agent_script", "delete_agent_script",
                              "xcode_build", "xcode_run", "xcode_list_projects",
                              "xcode_select_project", "xcode_grant_permission"]
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
