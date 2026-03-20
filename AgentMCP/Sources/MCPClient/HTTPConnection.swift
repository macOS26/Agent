import Foundation
import os

// MARK: - SSE Event Parser

/// Incrementally parses Server-Sent Events (SSE) from a line stream.
/// Handles the `event:`, `data:`, `id:` fields per the SSE specification.
/// Per MCP spec (2025-03-26), only events with type "message" or no type are processed.
struct SSEParser {
    private(set) var currentEvent = ""
    private(set) var currentData = ""

    /// Process a single line from the SSE stream.
    /// Returns a parsed JSON dict when a complete event is ready (blank line encountered).
    mutating func processLine(_ line: String) -> [String: Any]? {
        if line.isEmpty {
            defer { currentEvent = ""; currentData = "" }
            // Only process "message" events or events with no type (default per SSE spec)
            guard !currentData.isEmpty,
                  currentEvent.isEmpty || currentEvent == "message" else { return nil }
            guard let jsonData = currentData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return nil }
            return json
        } else if line.hasPrefix("event:") {
            currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            currentData = currentData.isEmpty ? data : currentData + "\n" + data
        }
        // Ignore "id:", "retry:", and comment lines (starting with :)
        return nil
    }

    /// Flush any remaining buffered data (for when stream closes without a trailing blank line).
    mutating func flush() -> [String: Any]? {
        guard !currentData.isEmpty,
              currentEvent.isEmpty || currentEvent == "message" else {
            currentEvent = ""; currentData = ""
            return nil
        }
        defer { currentEvent = ""; currentData = "" }
        guard let jsonData = currentData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return nil }
        return json
    }
}

// MARK: - HTTP Connection (JSON-RPC over Streamable HTTP)

/// Manages MCP communication via HTTP POST requests (Streamable HTTP transport).
/// Supports both direct JSON responses and true SSE streaming per MCP spec (2025-03-26).
/// Uses URLSession.bytes(for:) for async line-by-line streaming instead of buffering.
final class HTTPConnection: @unchecked Sendable, MCPConnection {
    private let serverURL: URL
    private let customHeaders: [String: String]
    private let session: URLSession
    private struct State {
        var sessionId: String?
        var nextId: Int = 0
        var alive: Bool = true
    }
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(url: URL, headers: [String: String]) {
        self.serverURL = url
        self.customHeaders = headers
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    var isAlive: Bool {
        state.withLock { $0.alive }
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
        if let sid = state.withLock({ $0.sessionId }) {
            request.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id")
        }

        // Use streaming bytes for true SSE support
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPClientError.connectionFailed("Invalid HTTP response")
        }

        // Capture session ID from server
        if let sid = httpResponse.value(forHTTPHeaderField: "Mcp-Session-Id") {
            state.withLock { $0.sessionId = sid }
        }

        // Handle session expiry (404 = session gone, need to re-initialize)
        if httpResponse.statusCode == 404 {
            state.withLock { $0.sessionId = nil }
            throw MCPClientError.connectionFailed("Session expired (404)")
        }

        // Handle HTTP errors
        guard (200...299).contains(httpResponse.statusCode) else {
            var errorBytes = Data()
            for try await byte in bytes {
                errorBytes.append(byte)
                if errorBytes.count > 512 { break }
            }
            let body = String(data: errorBytes, encoding: .utf8) ?? ""
            throw MCPClientError.connectionFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        // Parse response based on content type
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""

        if contentType.contains("text/event-stream") {
            // True SSE streaming — parse events line by line as they arrive
            return try await parseSSEStream(bytes, expectedId: id)
        } else {
            // Direct JSON response
            var data = Data()
            for try await byte in bytes { data.append(byte) }
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

        if let sid = state.withLock({ $0.sessionId }) {
            request.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id")
        }

        // Fire-and-forget for notifications (server returns 202 Accepted)
        let task = session.dataTask(with: request)
        task.resume()
    }

    func disconnect() {
        let sid = state.withLock { s -> String? in
            s.alive = false
            return s.sessionId
        }

        // Send DELETE to close session per MCP spec
        if let sid {
            var request = URLRequest(url: serverURL)
            request.httpMethod = "DELETE"
            request.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id")
            for (key, value) in customHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            let task = session.dataTask(with: request)
            task.resume()
        }

        session.invalidateAndCancel()
    }

    private func nextRequestId() -> Int {
        state.withLock { s in
            s.nextId += 1
            return s.nextId
        }
    }

    // MARK: - SSE Stream Parsing

    /// Parse an SSE stream asynchronously using true streaming (line by line as data arrives).
    /// Per MCP spec, the server MAY send notifications/progress before the final response.
    private func parseSSEStream(_ bytes: URLSession.AsyncBytes, expectedId: Int) async throws -> [String: Any] {
        var parser = SSEParser()
        var lastJSON: [String: Any]?

        for try await line in bytes.lines {
            if let json = parser.processLine(line) {
                if Self.matchesId(json, expectedId: expectedId) { return json }
                lastJSON = json
            }
        }

        // Handle trailing event data (server closed without final blank line)
        if let json = parser.flush() {
            if Self.matchesId(json, expectedId: expectedId) { return json }
            lastJSON = json
        }

        if let last = lastJSON { return last }
        throw MCPClientError.invalidResponse
    }

    /// Parse SSE from buffered data. Same logic as the stream parser, for unit testing.
    static func parseSSEData(_ data: Data, expectedId: Int) throws -> [String: Any] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw MCPClientError.invalidResponse
        }

        var parser = SSEParser()
        var lastJSON: [String: Any]?

        for line in text.components(separatedBy: "\n") {
            if let json = parser.processLine(line) {
                if matchesId(json, expectedId: expectedId) { return json }
                lastJSON = json
            }
        }

        if let json = parser.flush() {
            if matchesId(json, expectedId: expectedId) { return json }
            lastJSON = json
        }

        if let last = lastJSON { return last }
        throw MCPClientError.invalidResponse
    }

    /// Check if a JSON-RPC response matches the expected request ID.
    static func matchesId(_ json: [String: Any], expectedId: Int) -> Bool {
        if let rid = json["id"] as? Int, rid == expectedId { return true }
        if let rid = json["id"] as? String, let intId = Int(rid), intId == expectedId { return true }
        return false
    }
}
