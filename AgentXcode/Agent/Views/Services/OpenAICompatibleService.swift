@preconcurrency import Foundation

/// Unified service for OpenAI and Hugging Face Inference API.
/// Both use the OpenAI chat completions format with SSE streaming.
@MainActor
final class OpenAICompatibleService {
    let apiKey: String
    let model: String
    let baseURL: URL
    let supportsVision: Bool
    let provider: APIProvider
    var temperature: Double = 0.2
    /// Key name for the messages array in the request body.
    /// OpenAI uses "messages", LM Studio Native uses "input".
    let messagesKey: String

    let historyContext: String
    let userHome: String
    let userName: String
    let projectFolder: String

    init(apiKey: String, model: String, baseURL: String, supportsVision: Bool = false, historyContext: String = "", projectFolder: String = "", provider: APIProvider, messagesKey: String = "messages") {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = URL(string: baseURL) ?? URL(filePath: "/")
        self.supportsVision = supportsVision
        self.provider = provider
        self.messagesKey = messagesKey
        self.historyContext = historyContext
        self.userHome = FileManager.default.homeDirectoryForCurrentUser.path
        self.userName = NSUserName()
        self.projectFolder = projectFolder
    }

    var systemPrompt: String {
        var prompt = SystemPromptService.shared.prompt(for: provider, userName: userName, userHome: userHome, projectFolder: projectFolder)
        if !projectFolder.isEmpty {
            prompt = "CURRENT PROJECT FOLDER: \(projectFolder)\nAlways cd to this directory before running any shell commands. Use it as the default for all file operations. You may go outside it when needed.\n\n" + prompt
        }
        if supportsVision {
            prompt += "\nYou have VISION. When images are attached, you can see and analyze them."
        }
        if !historyContext.isEmpty {
            prompt += historyContext
        }
        return prompt
    }

    func tools(activeGroups: Set<String>? = nil) -> [[String: Any]] { AgentTools.ollamaTools(for: provider, activeGroups: activeGroups) }

    /// Prepend project folder to the last user message.
    private func withFolderPrefix(_ messages: [[String: Any]]) -> [[String: Any]] {
        guard !projectFolder.isEmpty else { return messages }
        let prefix = "PROJECT FOLDER: \(projectFolder)\n"
        var result = messages
        for i in stride(from: result.count - 1, through: 0, by: -1) {
            guard result[i]["role"] as? String == "user" else { continue }
            if let text = result[i]["content"] as? String {
                result[i]["content"] = prefix + text
            } else if var blocks = result[i]["content"] as? [[String: Any]],
                      let first = blocks.first, first["type"] as? String == "text",
                      let existing = first["text"] as? String {
                blocks[0]["text"] = prefix + existing
                result[i]["content"] = blocks
            }
            break
        }
        return result
    }

    /// Convert Claude-format messages to OpenAI chat messages.
    private func convertMessages(_ messages: [[String: Any]]) -> [[String: Any]] {
        var chatMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        for msg in withFolderPrefix(messages) {
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
                        // Content blocks (text + images) — use OpenAI multipart content
                        var contentParts: [[String: Any]] = []
                        for block in blocks {
                            if block["type"] as? String == "text",
                               let t = block["text"] as? String {
                                contentParts.append(["type": "text", "text": t])
                            } else if block["type"] as? String == "image",
                                      let source = block["source"] as? [String: Any],
                                      let base64 = source["data"] as? String {
                                let mediaType = source["media_type"] as? String ?? "image/png"
                                contentParts.append([
                                    "type": "image_url",
                                    "image_url": [
                                        "url": "data:\(mediaType);base64,\(base64)"
                                    ] as [String: Any]
                                ])
                            }
                        }
                        if contentParts.isEmpty {
                            contentParts.append(["type": "text", "text": "Describe the attached image(s)."])
                        }
                        chatMessages.append(["role": "user", "content": contentParts])
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
                            // OpenAI expects arguments as a JSON string
                            let argsString: String
                            if let data = try? JSONSerialization.data(withJSONObject: input),
                               let str = String(data: data, encoding: .utf8) {
                                argsString = str
                            } else {
                                argsString = "{}"
                            }
                            toolCalls.append([
                                "id": callId,
                                "type": "function",
                                "function": [
                                    "name": name,
                                    "arguments": argsString
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
        return chatMessages
    }

    // MARK: - Non-Streaming

    func send(messages: [[String: Any]], activeGroups: Set<String>? = nil) async throws -> (content: [[String: Any]], stopReason: String) {
        let chatMessages = convertMessages(messages)

        var body: [String: Any] = [
            "model": model,
            "temperature": temperature,
            messagesKey: chatMessages,
            "stream": false,
            "max_tokens": 2048
        ]
        let toolDefs = tools(activeGroups: activeGroups)
        if !toolDefs.isEmpty { body["tools"] = toolDefs }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try await Self.performRequest(bodyData: bodyData, apiKey: apiKey, url: baseURL)
    }

    // MARK: - Streaming

    func sendStreaming(
        messages: [[String: Any]],
        activeGroups: Set<String>? = nil,
        onTextDelta: @escaping @Sendable (String) -> Void
    ) async throws -> (content: [[String: Any]], stopReason: String) {
        let chatMessages = convertMessages(messages)

        var body: [String: Any] = [
            "model": model,
            "temperature": temperature,
            messagesKey: chatMessages,
            "stream": true,
            "max_tokens": 2048
        ]
        let toolDefs = tools(activeGroups: activeGroups)
        if !toolDefs.isEmpty { body["tools"] = toolDefs }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try await Self.performStreamingRequest(
            bodyData: bodyData,
            apiKey: apiKey,
            url: baseURL,
            onTextDelta: onTextDelta
        )
    }

    // MARK: - Non-Streaming Request

    nonisolated private static func performRequest(
        bodyData: Data, apiKey: String, url: URL
    ) async throws -> (content: [[String: Any]], stopReason: String) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        request.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AgentError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw AgentError.invalidResponse
        }

        let finishReason = firstChoice["finish_reason"] as? String ?? "stop"

        // Convert to Claude-compatible content blocks
        var contentBlocks: [[String: Any]] = []
        var parsedToolFromText = false

        if let text = message["content"] as? String, !text.isEmpty {
            // Check for DeepSeek text-based tool calls before treating as plain text
            if let deepSeekCalls = OllamaService.extractDeepSeekToolCalls(from: text) {
                for call in deepSeekCalls {
                    contentBlocks.append([
                        "type": "tool_use",
                        "id": UUID().uuidString,
                        "name": call.name,
                        "input": call.input
                    ])
                }
                parsedToolFromText = true
            } else if let dsmlCalls = OllamaService.extractDSMLToolCalls(from: text) {
                for call in dsmlCalls {
                    contentBlocks.append([
                        "type": "tool_use",
                        "id": UUID().uuidString,
                        "name": call.name,
                        "input": call.input
                    ])
                }
                parsedToolFromText = true
            } else if let (toolName, _, parsed) = OllamaService.extractFirstToolCall(from: text) {
                contentBlocks.append([
                    "type": "tool_use",
                    "id": UUID().uuidString,
                    "name": toolName,
                    "input": parsed
                ])
                parsedToolFromText = true
            } else {
                // Strip vLLM/Qwen special tokens
                var cleaned = text
                    .replacingOccurrences(of: "<\\|im_(?:start|end)\\|>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                // If native tool_calls also present, skip text that is raw JSON
                let hasNativeTools = message["tool_calls"] != nil
                if hasNativeTools && (cleaned.hasPrefix("{\"name\"") || cleaned.hasPrefix("[{\"name\"")) {
                    cleaned = ""
                }
                if !cleaned.isEmpty {
                    contentBlocks.append(["type": "text", "text": cleaned])
                }
            }
        }

        if let toolCalls = message["tool_calls"] as? [[String: Any]] {
            for call in toolCalls {
                guard let function = call["function"] as? [String: Any],
                      let name = function["name"] as? String else { continue }

                let callId = call["id"] as? String ?? UUID().uuidString

                // OpenAI: arguments is a JSON string
                let input: [String: Any]
                if let argsString = function["arguments"] as? String,
                   let parsed = try? JSONSerialization.jsonObject(with: Data(argsString.utf8)) as? [String: Any] {
                    input = parsed
                } else if let args = function["arguments"] as? [String: Any] {
                    input = args
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

        let hasToolCalls = (message["tool_calls"] != nil) || parsedToolFromText
        let stopReason = hasToolCalls ? "tool_use" : (finishReason == "tool_calls" ? "tool_use" : (finishReason == "length" ? "max_tokens" : "end_turn"))
        return (contentBlocks, stopReason)
    }

    // MARK: - Streaming Request (SSE)

    nonisolated private static func performStreamingRequest(
        bodyData: Data, apiKey: String, url: URL,
        onTextDelta: @escaping @Sendable (String) -> Void
    ) async throws -> (content: [[String: Any]], stopReason: String) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        request.timeoutInterval = llmAPITimeout

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
        var finishReason = "stop"

        // Accumulate streamed tool calls: index -> (id, name, arguments)
        var toolCallAccum: [Int: (id: String, name: String, arguments: String)] = [:]

        // Buffer text line-by-line so we can suppress raw JSON tool calls
        // that vLLM/Qwen outputs as text content instead of native tool_calls
        var lineBuffer = ""

        /// Check if a line is a raw JSON tool call (e.g. {"name": "...", "arguments": {...}})
        func isToolCallJSON(_ line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("{"), trimmed.contains("\"name\""),
                  trimmed.contains("\"arguments\"") else { return false }
            // Verify it actually parses as JSON with name + arguments keys
            if let data = trimmed.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               obj["name"] is String, obj["arguments"] != nil {
                return true
            }
            return false
        }

        /// Flush the line buffer — forward to UI if it's not a tool call JSON
        func flushLineBuffer() {
            guard !lineBuffer.isEmpty else { return }
            if !isToolCallJSON(lineBuffer) {
                onTextDelta(lineBuffer)
            }
            lineBuffer = ""
        }

        // OpenAI SSE format: lines prefixed with "data: "
        for try await line in bytes.lines {
            // Skip empty lines and SSE comments
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))

            // End of stream
            if payload == "[DONE]" { break }

            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first else { continue }

            // Check finish reason
            if let fr = firstChoice["finish_reason"] as? String {
                finishReason = fr
            }

            guard let delta = firstChoice["delta"] as? [String: Any] else { continue }

            // Tool call deltas (streamed incrementally)
            if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                for tc in toolCalls {
                    let index = tc["index"] as? Int ?? 0

                    if toolCallAccum[index] == nil {
                        toolCallAccum[index] = (id: "", name: "", arguments: "")
                    }

                    if let id = tc["id"] as? String {
                        toolCallAccum[index]?.id = id
                    }
                    if let function = tc["function"] as? [String: Any] {
                        if let name = function["name"] as? String {
                            toolCallAccum[index]?.name += name
                        }
                        if let args = function["arguments"] as? String {
                            toolCallAccum[index]?.arguments += args
                        }
                    }
                }
            }

            // Text content delta — buffer by newlines to detect and suppress
            // raw JSON tool calls that vLLM/Qwen outputs as text
            if let content = delta["content"] as? String, !content.isEmpty {
                // Strip special tokens
                let cleaned = content
                    .replacingOccurrences(of: "<|im_start|>", with: "")
                    .replacingOccurrences(of: "<|im_end|>", with: "")
                fullText += cleaned

                // Suppress all text when native tool calls are being streamed
                if !toolCallAccum.isEmpty { continue }

                // Buffer text and flush on newlines to filter JSON tool calls
                for ch in cleaned {
                    if ch == "\n" {
                        let suppressed = isToolCallJSON(lineBuffer)
                        flushLineBuffer()
                        if !suppressed {
                            onTextDelta("\n")
                        }
                    } else {
                        lineBuffer.append(ch)
                    }
                }
            }
        }
        // Flush any remaining buffered text
        flushLineBuffer()

        // Build Claude-compatible content blocks
        var contentBlocks: [[String: Any]] = []
        var parsedToolFromText = false

        // Convert accumulated native tool calls first
        for index in toolCallAccum.keys.sorted() {
            guard let tc = toolCallAccum[index], !tc.name.isEmpty else { continue }
            let callId = tc.id.isEmpty ? "call_\(UUID().uuidString.prefix(8).lowercased())" : tc.id

            let input: [String: Any]
            if let parsed = try? JSONSerialization.jsonObject(with: Data(tc.arguments.utf8)) as? [String: Any] {
                input = parsed
            } else {
                input = [:]
            }

            contentBlocks.append([
                "type": "tool_use",
                "id": callId,
                "name": tc.name,
                "input": input
            ])
        }

        // If no native tool calls, check text for DeepSeek-style tool calls
        if contentBlocks.isEmpty && !fullText.isEmpty {
            if let deepSeekCalls = OllamaService.extractDeepSeekToolCalls(from: fullText) {
                for call in deepSeekCalls {
                    contentBlocks.append([
                        "type": "tool_use",
                        "id": UUID().uuidString,
                        "name": call.name,
                        "input": call.input
                    ])
                }
                parsedToolFromText = true
            } else if let dsmlCalls = OllamaService.extractDSMLToolCalls(from: fullText) {
                for call in dsmlCalls {
                    contentBlocks.append([
                        "type": "tool_use",
                        "id": UUID().uuidString,
                        "name": call.name,
                        "input": call.input
                    ])
                }
                parsedToolFromText = true
            } else if let (toolName, _, parsed) = OllamaService.extractFirstToolCall(from: fullText) {
                contentBlocks.append([
                    "type": "tool_use",
                    "id": UUID().uuidString,
                    "name": toolName,
                    "input": parsed
                ])
                parsedToolFromText = true
            }
        }

        // Add text if no tool calls were found from it
        // Strip vLLM/Qwen special tokens that leak through as text content
        if !parsedToolFromText && !fullText.isEmpty {
            var cleaned = fullText
            // Remove <|im_start|>, <|im_end|>, and similar special tokens
            cleaned = cleaned.replacingOccurrences(of: "<\\|im_(?:start|end)\\|>", with: "", options: .regularExpression)
            // If native tool calls exist, discard text that is just raw JSON tool call output
            if !toolCallAccum.isEmpty {
                let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                // Skip text that looks like raw tool call JSON the model leaked
                if trimmed.isEmpty || trimmed.hasPrefix("{\"name\"") || trimmed.hasPrefix("[{\"name\"") {
                    cleaned = ""
                }
            }
            if !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                contentBlocks.insert(["type": "text", "text": cleaned], at: 0)
            }
        }

        if contentBlocks.isEmpty {
            contentBlocks.append(["type": "text", "text": "(no response)"])
        }

        let hasToolCalls = !toolCallAccum.isEmpty || parsedToolFromText
        let stopReason = hasToolCalls ? "tool_use" : (finishReason == "tool_calls" ? "tool_use" : (finishReason == "length" ? "max_tokens" : "end_turn"))
        return (contentBlocks, stopReason)
    }
}
