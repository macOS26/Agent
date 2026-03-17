@preconcurrency import Foundation

@MainActor
final class ClaudeService {
    let apiKey: String
    let model: String

    private static let baseURL = URL(string: "https://api.anthropic.com/v1/messages") ?? URL(filePath: "/")
    private static let apiVersion = "2023-06-01"

    let historyContext: String
    let userHome: String
    let userName: String
    let projectFolder: String

    init(apiKey: String, model: String, historyContext: String = "", projectFolder: String = "") {
        self.apiKey = apiKey
        self.model = model
        self.historyContext = historyContext
        self.userHome = FileManager.default.homeDirectoryForCurrentUser.path
        self.userName = NSUserName()
        self.projectFolder = projectFolder
    }

    var systemPrompt: String {
        var prompt = AgentTools.systemPrompt(userName: userName, userHome: userHome)
        if !projectFolder.isEmpty {
            prompt += "\nPROJECT FOLDER: \(projectFolder) — use as the default working directory for commands and file operations. You may look outside this folder when needed to complete a task."
        }
        if !historyContext.isEmpty {
            prompt += historyContext
        }
        return prompt
    }

    var tools: [[String: Any]] {
        var t = AgentTools.claudeFormat
        t.append([
            "type": "web_search_20250305",
            "name": "web_search"
        ])
        return t
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

    // MARK: - Streaming

    func sendStreaming(
        messages: [[String: Any]],
        onTextDelta: @escaping @Sendable (String) -> Void
    ) async throws -> (content: [[String: Any]], stopReason: String) {
        guard !apiKey.isEmpty else { throw AgentError.noAPIKey }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": systemPrompt,
            "tools": tools,
            "messages": messages,
            "stream": true
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try await Self.performStreamingRequest(
            bodyData: bodyData,
            apiKey: apiKey,
            apiVersion: Self.apiVersion,
            url: Self.baseURL,
            onTextDelta: onTextDelta
        )
    }

    nonisolated private static func performStreamingRequest(
        bodyData: Data, apiKey: String, apiVersion: String, url: URL,
        onTextDelta: @escaping @Sendable (String) -> Void
    ) async throws -> (content: [[String: Any]], stopReason: String) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
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

        var contentBlocks: [[String: Any]] = []
        var currentTextBlock = ""
        var currentToolId = ""
        var currentToolName = ""
        var currentToolJson = ""
        var stopReason = ""
        var inToolUse = false
        var inServerToolUse = false
        var pendingServerResult: [String: Any]?

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            guard let data = jsonStr.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String else { continue }

            switch type {
            case "content_block_start":
                if let block = event["content_block"] as? [String: Any],
                   let blockType = block["type"] as? String {
                    if blockType == "text" {
                        currentTextBlock = ""
                        inToolUse = false
                        inServerToolUse = false
                    } else if blockType == "tool_use" {
                        currentToolId = block["id"] as? String ?? ""
                        currentToolName = block["name"] as? String ?? ""
                        currentToolJson = ""
                        inToolUse = true
                        inServerToolUse = false
                    } else if blockType == "server_tool_use" {
                        currentToolId = block["id"] as? String ?? ""
                        currentToolName = block["name"] as? String ?? ""
                        currentToolJson = ""
                        inToolUse = true
                        inServerToolUse = true
                    } else if blockType == "web_search_tool_result" {
                        pendingServerResult = block
                    }
                }

            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   let deltaType = delta["type"] as? String {
                    if deltaType == "text_delta", let text = delta["text"] as? String {
                        currentTextBlock += text
                        onTextDelta(text)
                    } else if deltaType == "input_json_delta", let json = delta["partial_json"] as? String {
                        currentToolJson += json
                    }
                }

            case "content_block_stop":
                if inToolUse {
                    let input: [String: Any]
                    if let parsed = try? JSONSerialization.jsonObject(with: Data(currentToolJson.utf8)) as? [String: Any] {
                        input = parsed
                    } else {
                        input = [:]
                    }
                    let blockType = inServerToolUse ? "server_tool_use" : "tool_use"
                    contentBlocks.append([
                        "type": blockType,
                        "id": currentToolId,
                        "name": currentToolName,
                        "input": input
                    ])
                    currentToolName = ""
                    currentToolId = ""
                    currentToolJson = ""
                    inToolUse = false
                    inServerToolUse = false
                } else if pendingServerResult != nil {
                    contentBlocks.append(pendingServerResult!)
                    pendingServerResult = nil
                } else if !currentTextBlock.isEmpty {
                    contentBlocks.append(["type": "text", "text": currentTextBlock])
                    currentTextBlock = ""
                }

            case "message_delta":
                if let delta = event["delta"] as? [String: Any],
                   let reason = delta["stop_reason"] as? String {
                    stopReason = reason
                }

            default:
                break
            }
        }

        return (contentBlocks, stopReason)
    }
}
