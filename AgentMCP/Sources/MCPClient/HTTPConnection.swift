import Foundation

// MARK: - HTTP Connection (JSON-RPC over HTTP/HTTPS)

/// Manages MCP communication via HTTP POST requests (Streamable HTTP transport).
/// Supports both direct JSON responses and SSE-streamed responses.
final class HTTPConnection: @unchecked Sendable, MCPConnection {
    private let serverURL: URL
    private let customHeaders: [String: String]
    private let session: URLSession
    private var sessionId: String?
    private var nextId: Int = 0
    private let lock = NSLock()
    private var alive = true

    init(url: URL, headers: [String: String]) {
        self.serverURL = url
        self.customHeaders = headers
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    var isAlive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return alive
    }

    func sendRequest(method: String, params: [String: Any]?) async throws -> [String: Any] {
        guard isAlive else {
            throw MCPClientError.connectionFailed("HTTP connection is closed")
        }

        let id = nextRequestId()

        var body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method
        ]
        if let params { body["params"] = params }

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")

        // Add custom headers (Authorization, API keys, etc.)
        for (key, value) in customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add session ID for session continuity
        lock.lock()
        if let sid = sessionId {
            request.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id")
        }
        lock.unlock()

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPClientError.connectionFailed("Invalid HTTP response")
        }

        // Capture session ID from server
        if let sid = httpResponse.value(forHTTPHeaderField: "Mcp-Session-Id") {
            lock.lock()
            sessionId = sid
            lock.unlock()
        }

        // Handle HTTP errors
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data.prefix(512), encoding: .utf8) ?? ""
            throw MCPClientError.connectionFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        // Parse response based on content type
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""

        if contentType.contains("text/event-stream") {
            return try parseSSEResponse(data, expectedId: id)
        } else {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw MCPClientError.invalidResponse
            }
            return json
        }
    }

    func sendNotification(method: String, params: [String: Any]?) throws {
        guard isAlive else { return }

        var body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method
        ]
        if let params { body["params"] = params }

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        for (key, value) in customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        lock.lock()
        if let sid = sessionId {
            request.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id")
        }
        lock.unlock()

        // Fire-and-forget for notifications
        let task = session.dataTask(with: request)
        task.resume()
    }

    func disconnect() {
        lock.lock()
        alive = false
        let sid = sessionId
        lock.unlock()

        // Send DELETE to close session if we have one
        if sid != nil {
            var request = URLRequest(url: serverURL)
            request.httpMethod = "DELETE"
            if let sid {
                request.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id")
            }
            for (key, value) in customHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            let task = session.dataTask(with: request)
            task.resume()
        }

        session.invalidateAndCancel()
    }

    private func nextRequestId() -> Int {
        lock.lock()
        defer { lock.unlock() }
        nextId += 1
        return nextId
    }

    /// Parse an SSE response body into a JSON-RPC response dict.
    /// SSE format: lines starting with "data:" contain JSON payloads.
    private func parseSSEResponse(_ data: Data, expectedId: Int) throws -> [String: Any] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw MCPClientError.invalidResponse
        }

        var lastJSON: [String: Any]?

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data:") else { continue }

            let jsonStr = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            guard !jsonStr.isEmpty,
                  let jsonData = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }

            // Prefer the response matching our request ID
            if let rid = json["id"] as? Int, rid == expectedId {
                return json
            }
            if let rid = json["id"] as? String, let intId = Int(rid), intId == expectedId {
                return json
            }
            lastJSON = json
        }

        if let last = lastJSON { return last }
        throw MCPClientError.invalidResponse
    }
}
