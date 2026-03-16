import Foundation

// MARK: - JSON Value Type (replaces MCP SDK's Value)

/// Lightweight JSON value enum for MCP tool arguments and schemas
public enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode([String: JSONValue].self) { self = .object(v) }
        else if let v = try? container.decode([JSONValue].self) { self = .array(v) }
        else if container.decodeNil() { self = .null }
        else { self = .null }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }

    /// Convert to Any for JSON serialization
    public var anyValue: Any {
        switch self {
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        case .null: return NSNull()
        case .array(let v): return v.map(\.anyValue)
        case .object(let v): return v.mapValues(\.anyValue)
        }
    }

    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}
extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
}
extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}
extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}
extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}
extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}

// MARK: - Connection Protocol

/// Protocol for MCP transport connections (stdio or HTTP)
private protocol MCPConnection: AnyObject, Sendable {
    func sendRequest(method: String, params: [String: Any]?) async throws -> [String: Any]
    func sendNotification(method: String, params: [String: Any]?) throws
    func disconnect()
    var isAlive: Bool { get }
}

// MARK: - Stdio Connection (JSON-RPC over pipes)

/// Manages a server process and JSON-RPC communication via stdio pipes.
/// Uses readabilityHandler callbacks for fully non-blocking I/O.
private final class StdioConnection: @unchecked Sendable, MCPConnection {
    let process: Process
    let writer: FileHandle
    let reader: FileHandle
    let errorReader: FileHandle
    private var nextId: Int = 0
    private let lock = NSLock()

    // Pending response continuations keyed by request id
    private var pending: [Int: CheckedContinuation<[String: Any], any Error>] = [:]
    private var buffer = Data()
    /// Maximum buffer size (10 MB) — disconnect server if exceeded
    private static let maxBufferSize = 10 * 1024 * 1024

    init(process: Process, writer: FileHandle, reader: FileHandle, errorReader: FileHandle) {
        self.process = process
        self.writer = writer
        self.reader = reader
        self.errorReader = errorReader

        // Drain stderr to prevent the server from blocking on a full pipe (64 KB OS limit)
        errorReader.readabilityHandler = { handle in
            _ = handle.availableData
        }

        // Set up non-blocking read via readabilityHandler
        reader.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self else { return }

            self.lock.lock()
            self.buffer.append(data)

            // Guard against unbounded buffer growth from malicious servers
            if self.buffer.count > Self.maxBufferSize {
                print("[MCPClient] Buffer exceeded \(Self.maxBufferSize) bytes — disconnecting server")
                self.buffer.removeAll()
                let pendingCopy = self.pending
                self.pending.removeAll()
                self.lock.unlock()
                for (_, continuation) in pendingCopy {
                    continuation.resume(throwing: MCPClientError.bufferOverflow)
                }
                self.disconnect()
                return
            }

            // Process complete newline-delimited messages
            while let newlineIndex = self.buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = self.buffer[self.buffer.startIndex..<newlineIndex]
                self.buffer = self.buffer[(newlineIndex + 1)...]

                guard !lineData.isEmpty,
                      let json = try? JSONSerialization.jsonObject(with: Data(lineData)) as? [String: Any] else {
                    continue
                }

                // Match response to pending request
                var matchedId: Int?
                if let rid = json["id"] as? Int {
                    matchedId = rid
                } else if let rid = json["id"] as? String, let intId = Int(rid) {
                    matchedId = intId
                }

                if let id = matchedId, let continuation = self.pending.removeValue(forKey: id) {
                    self.lock.unlock()
                    continuation.resume(returning: json)
                    self.lock.lock()
                }
            }
            self.lock.unlock()
        }
    }

    /// Send a JSON-RPC request and await the response (non-blocking)
    func sendRequest(method: String, params: [String: Any]? = nil) async throws -> [String: Any] {
        let id = nextRequestId()

        var request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method
        ]
        if let params { request["params"] = params }

        let data = try JSONSerialization.data(withJSONObject: request)
        var message = data
        message.append(contentsOf: [UInt8(ascii: "\n")])

        return try await withCheckedThrowingContinuation { continuation in
            // Register pending before writing to avoid race
            lock.lock()
            pending[id] = continuation
            lock.unlock()

            writer.write(message)

            // Timeout after 10 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                if let cont = self.pending.removeValue(forKey: id) {
                    self.lock.unlock()
                    cont.resume(throwing: MCPClientError.connectionFailed("Timeout waiting for \(method)"))
                } else {
                    self.lock.unlock()
                }
            }
        }
    }

    /// Send a JSON-RPC notification (no response expected)
    func sendNotification(method: String, params: [String: Any]? = nil) throws {
        var notification: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method
        ]
        if let params { notification["params"] = params }

        let data = try JSONSerialization.data(withJSONObject: notification)
        var message = data
        message.append(contentsOf: [UInt8(ascii: "\n")])

        writer.write(message)
    }

    var isAlive: Bool { process.isRunning }

    func disconnect() {
        reader.readabilityHandler = nil
        errorReader.readabilityHandler = nil
        lock.lock()
        let leftover = pending
        pending.removeAll()
        lock.unlock()
        for (_, cont) in leftover {
            cont.resume(throwing: MCPClientError.connectionFailed("Disconnected"))
        }
        if process.isRunning {
            process.terminate()
            // Force-kill after 2 seconds if the server ignores SIGTERM
            let proc = process
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if proc.isRunning {
                    kill(proc.processIdentifier, SIGKILL)
                }
            }
        }
    }

    private func nextRequestId() -> Int {
        lock.lock()
        defer { lock.unlock() }
        nextId += 1
        return nextId
    }
}

// MARK: - HTTP Connection (JSON-RPC over HTTP/HTTPS)

/// Manages MCP communication via HTTP POST requests (Streamable HTTP transport).
/// Supports both direct JSON responses and SSE-streamed responses.
private final class HTTPConnection: @unchecked Sendable, MCPConnection {
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

// MARK: - MCP Client

/// MCP Client for connecting to MCP servers via stdio or HTTP
/// Uses direct JSON-RPC over pipes - no SDK dependency
public actor MCPClient {

    // MARK: - Types

    public struct ServerConfig: Codable, Identifiable, Hashable, Sendable {
        public let id: UUID
        public let name: String
        // Stdio transport
        public let command: String
        public let arguments: [String]
        public let env: [String: String]
        // HTTP transport
        public let url: String?
        public let headers: [String: String]
        // Common
        public let enabled: Bool
        public let autoStart: Bool

        /// True if this server uses HTTP/HTTPS transport
        public var isHTTP: Bool { url != nil && !(url!.isEmpty) }

        /// Stdio transport initializer
        public init(
            id: UUID = UUID(),
            name: String,
            command: String,
            arguments: [String] = [],
            env: [String: String] = [:],
            enabled: Bool = true,
            autoStart: Bool = true
        ) {
            self.id = id
            self.name = name
            self.command = command
            self.arguments = arguments
            self.env = env
            self.url = nil
            self.headers = [:]
            self.enabled = enabled
            self.autoStart = autoStart
        }

        /// HTTP transport initializer
        public init(
            id: UUID = UUID(),
            name: String,
            url: String,
            headers: [String: String] = [:],
            enabled: Bool = true,
            autoStart: Bool = true
        ) {
            self.id = id
            self.name = name
            self.command = ""
            self.arguments = []
            self.env = [:]
            self.url = url
            self.headers = headers
            self.enabled = enabled
            self.autoStart = autoStart
        }
    }

    public struct DiscoveredTool: Codable, Identifiable, Hashable, Sendable {
        public let id: UUID
        public let serverId: UUID
        public let serverName: String
        public let name: String
        public let description: String
        public let inputSchemaJSON: String

        public init(serverId: UUID, serverName: String, name: String, description: String, inputSchemaJSON: String) {
            self.id = UUID()
            self.serverId = serverId
            self.serverName = serverName
            self.name = name
            self.description = description
            self.inputSchemaJSON = inputSchemaJSON
        }
    }

    public struct DiscoveredResource: Codable, Identifiable, Hashable, Sendable {
        public let id: UUID
        public let serverId: UUID
        public let serverName: String
        public let uri: String
        public let name: String
        public let description: String?
        public let mimeType: String?

        public init(serverId: UUID, serverName: String, uri: String, name: String, description: String? = nil, mimeType: String? = nil) {
            self.id = UUID()
            self.serverId = serverId
            self.serverName = serverName
            self.uri = uri
            self.name = name
            self.description = description
            self.mimeType = mimeType
        }
    }

    public struct ToolResult: Codable, Sendable {
        public let content: [ContentBlock]
        public let isError: Bool

        public enum ContentBlock: Codable, Sendable {
            case text(String)
            case image(data: String, mimeType: String)
            case resource(uri: String, name: String, mimeType: String?)
        }
    }

    public struct ResourceContent: Sendable {
        public let uri: String
        public let text: String?
        public let mimeType: String?
    }

    /// Connection state snapshot for UI binding
    public struct ConnectionState: Sendable {
        public let connectedServers: [ServerConfig]
        public let discoveredTools: [DiscoveredTool]
        public let discoveredResources: [DiscoveredResource]
        public let errors: [UUID: String]

        public init(
            connectedServers: [ServerConfig] = [],
            discoveredTools: [DiscoveredTool] = [],
            discoveredResources: [DiscoveredResource] = [],
            errors: [UUID: String] = [:]
        ) {
            self.connectedServers = connectedServers
            self.discoveredTools = discoveredTools
            self.discoveredResources = discoveredResources
            self.errors = errors
        }
    }

    // MARK: - Private Properties

    private var connections: [UUID: any MCPConnection] = [:]
    private var configs: [UUID: ServerConfig] = [:]
    private var discoveredTools: [UUID: [DiscoveredTool]] = [:]
    private var discoveredResources: [UUID: [DiscoveredResource]] = [:]
    private var errors: [UUID: String] = [:]


    public init() {}

    // MARK: - Server Management

    /// Add and connect to an MCP server (30-second timeout on initialization)
    public func addServer(_ config: ServerConfig) async throws {
        guard config.enabled else {
            throw MCPClientError.serverDisabled(config.name)
        }

        // Create connection based on transport type
        let connection: any MCPConnection
        if config.isHTTP {
            print("[MCPClient] Adding HTTP server: \(config.name) at \(config.url ?? "")")
            connection = try connectHTTP(config)
        } else {
            print("[MCPClient] Adding server: \(config.name) at \(config.command)")
            connection = try launchServer(config)
        }
        connections[config.id] = connection
        configs[config.id] = config

        // Wrap initialization in a 30-second timeout
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    // MCP handshake: initialize
                    print("[MCPClient] Sending initialize...")
                    let initResponse = try await connection.sendRequest(
                        method: "initialize",
                        params: [
                            "protocolVersion": "2024-11-05",
                            "capabilities": [String: Any](),
                            "clientInfo": [
                                "name": "Agent!",
                                "version": "1.0.0"
                            ]
                        ]
                    )

                    // Verify we got a valid result
                    guard let result = initResponse["result"] as? [String: Any],
                          let serverInfo = result["serverInfo"] as? [String: Any] else {
                        throw MCPClientError.connectionFailed("Invalid initialize response")
                    }

                    let serverName = serverInfo["name"] as? String ?? config.name
                    print("[MCPClient] Connected to: \(serverName)")

                    // Send initialized notification
                    try connection.sendNotification(method: "notifications/initialized", params: nil)

                    // Check server capabilities to know what to discover
                    let capabilities = result["capabilities"] as? [String: Any] ?? [:]
                    let hasTools = capabilities["tools"] != nil
                    let hasResources = capabilities["resources"] != nil

                    // Discover tools/resources based on capabilities
                    try await self.discoverCapabilities(serverId: config.id, serverName: config.name, connection: connection, hasTools: hasTools, hasResources: hasResources)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                    throw MCPClientError.connectionFailed("Initialization timed out after 30 seconds")
                }
                // Wait for the first task to complete (either init finishes or timeout fires)
                try await group.next()
                group.cancelAll()
            }
        } catch {
            // Clean up on failure
            connections[config.id]?.disconnect()
            connections.removeValue(forKey: config.id)
            configs.removeValue(forKey: config.id)
            throw error
        }

        errors.removeValue(forKey: config.id)
        print("[MCPClient] Server \(config.name) ready with \(discoveredTools[config.id]?.count ?? 0) tools")
    }

    /// Remove a server connection
    public func removeServer(_ serverId: UUID) {
        connections[serverId]?.disconnect()
        connections.removeValue(forKey: serverId)
        configs.removeValue(forKey: serverId)
        discoveredTools.removeValue(forKey: serverId)
        discoveredResources.removeValue(forKey: serverId)
        errors.removeValue(forKey: serverId)
    }

    /// List all configured servers
    public func listServers() -> [ServerConfig] {
        Array(configs.values)
    }

    /// Get current connection state snapshot
    public func getConnectionState() -> ConnectionState {
        ConnectionState(
            connectedServers: Array(configs.values),
            discoveredTools: discoveredTools.values.flatMap { $0 },
            discoveredResources: discoveredResources.values.flatMap { $0 },
            errors: errors
        )
    }

    /// Check if a server is connected
    public func isConnected(_ serverId: UUID) -> Bool {
        connections[serverId] != nil
    }

    /// Get error for a server
    public func getError(_ serverId: UUID) -> String? {
        errors[serverId]
    }

    // MARK: - Tool Discovery

    /// Get all discovered tools from all connected servers
    public func getAllTools() -> [DiscoveredTool] {
        discoveredTools.values.flatMap { $0 }
    }

    /// Get tools from a specific server
    public func getTools(for serverId: UUID) -> [DiscoveredTool] {
        discoveredTools[serverId] ?? []
    }

    // MARK: - Tool Execution

    /// Call a tool on a specific server
    public func callTool(
        serverId: UUID,
        name: String,
        arguments: [String: JSONValue] = [:]
    ) async throws -> ToolResult {
        guard let connection = connections[serverId] else {
            throw MCPClientError.serverNotConnected(serverId)
        }

        // Connection liveness check
        guard connection.isAlive else {
            // Clean up stale connection
            connections.removeValue(forKey: serverId)
            configs.removeValue(forKey: serverId)
            discoveredTools.removeValue(forKey: serverId)
            throw MCPClientError.connectionFailed("Server process is no longer running")
        }

        let args = arguments.mapValues(\.anyValue)

        let response = try await connection.sendRequest(
            method: "tools/call",
            params: [
                "name": name,
                "arguments": args
            ]
        )

        guard let result = response["result"] as? [String: Any] else {
            if let error = response["error"] as? [String: Any] {
                let raw = error["message"] as? String ?? "Unknown error"
                // Cap error message length and strip newlines to limit injection surface
                let msg = String(raw.replacingOccurrences(of: "\n", with: " ").prefix(512))
                return ToolResult(content: [.text(msg)], isError: true)
            }
            throw MCPClientError.invalidResponse
        }

        let isError = result["isError"] as? Bool ?? false
        var contentBlocks: [ToolResult.ContentBlock] = []

        let maxTextSize = 1_024 * 1_024       // 1 MB per text block
        let maxImageSize = 10 * 1_024 * 1_024  // 10 MB per image (base64)
        let maxContentBlocks = 100

        if let contentArray = result["content"] as? [[String: Any]] {
            for item in contentArray.prefix(maxContentBlocks) {
                let type = item["type"] as? String ?? "text"
                switch type {
                case "text":
                    let text = item["text"] as? String ?? ""
                    contentBlocks.append(.text(String(text.prefix(maxTextSize))))
                case "image":
                    let data = item["data"] as? String ?? ""
                    guard data.count <= maxImageSize else {
                        contentBlocks.append(.text("[image too large: \(data.count) bytes]"))
                        break
                    }
                    let mimeType = item["mimeType"] as? String ?? "image/png"
                    contentBlocks.append(.image(data: data, mimeType: mimeType))
                case "resource":
                    let resource = item["resource"] as? [String: Any] ?? [:]
                    let uri = resource["uri"] as? String ?? ""
                    let name = resource["name"] as? String ?? uri
                    let mimeType = resource["mimeType"] as? String
                    contentBlocks.append(.resource(uri: String(uri.prefix(2048)), name: String(name.prefix(256)), mimeType: mimeType))
                default:
                    let text = item["text"] as? String ?? "[\(type)]"
                    contentBlocks.append(.text(String(text.prefix(maxTextSize))))
                }
            }
        }

        return ToolResult(content: contentBlocks, isError: isError)
    }

    /// Call a tool by its discovered ID
    public func callTool(
        toolId: UUID,
        arguments: [String: JSONValue] = [:]
    ) async throws -> ToolResult {
        guard let tool = getAllTools().first(where: { $0.id == toolId }) else {
            throw MCPClientError.toolNotFound(toolId)
        }
        return try await callTool(serverId: tool.serverId, name: tool.name, arguments: arguments)
    }

    // MARK: - Resource Operations

    /// Get all discovered resources from all connected servers
    public func getAllResources() -> [DiscoveredResource] {
        discoveredResources.values.flatMap { $0 }
    }

    /// Read a resource from a server
    public func readResource(serverId: UUID, uri: String) async throws -> ResourceContent {
        guard let connection = connections[serverId] else {
            throw MCPClientError.serverNotConnected(serverId)
        }

        let response = try await connection.sendRequest(
            method: "resources/read",
            params: ["uri": uri]
        )

        guard let result = response["result"] as? [String: Any],
              let contents = result["contents"] as? [[String: Any]],
              let first = contents.first else {
            throw MCPClientError.resourceNotFound(uri)
        }

        return ResourceContent(
            uri: first["uri"] as? String ?? uri,
            text: first["text"] as? String,
            mimeType: first["mimeType"] as? String
        )
    }

    /// Start all servers marked with autoStart
    public func startAutoStartServers(from configs: [ServerConfig]) async {
        for config in configs where config.autoStart && config.enabled {
            do {
                try await addServer(config)
            } catch {
                errors[config.id] = error.localizedDescription
            }
        }
    }

    // MARK: - Private Helpers

    /// Environment variables that must never be set via server config
    private static let blockedEnvVars: Set<String> = [
        "DYLD_INSERT_LIBRARIES",
        "DYLD_LIBRARY_PATH",
        "LD_PRELOAD",
        "DYLD_FRAMEWORK_PATH",
        "DYLD_FALLBACK_LIBRARY_PATH",
        "DYLD_FALLBACK_FRAMEWORK_PATH",
        "DYLD_ROOT_PATH",
        "DYLD_SHARED_REGION",
        "DYLD_PRINT_TO_FILE",
    ]

    private func launchServer(_ config: ServerConfig) throws -> StdioConnection {
        // Validate executable exists and is a regular file (not a symlink to a dangerous location)
        let commandURL = URL(fileURLWithPath: config.command)
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: commandURL.path, isDirectory: &isDir), !isDir.boolValue else {
            throw MCPClientError.connectionFailed("Executable not found or is a directory: \(config.command)")
        }
        // Reject symlinks — the resolved path must match the original
        let resolved = commandURL.resolvingSymlinksInPath().path
        let originalResolved = URL(fileURLWithPath: config.command).standardizedFileURL.path
        if resolved != originalResolved {
            throw MCPClientError.connectionFailed("Refusing to execute symlink: \(config.command) → \(resolved)")
        }

        let process = Process()
        process.executableURL = commandURL
        process.arguments = config.arguments

        // Filter out blocked environment variables
        var env = ProcessInfo.processInfo.environment
        for (key, value) in config.env {
            let upper = key.uppercased()
            // Block all DYLD_* vars (dylib injection vectors) and other dangerous vars
            if Self.blockedEnvVars.contains(upper) || upper.hasPrefix("DYLD_") {
                print("[MCPClient] Blocked dangerous environment variable: \(key)")
                continue
            }
            env[key] = value
        }
        process.environment = env

        let stdinPipe = Pipe()    // We write → server reads
        let stdoutPipe = Pipe()   // Server writes → we read
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        print("[MCPClient] Launched PID \(process.processIdentifier): \(config.command)")

        return StdioConnection(
            process: process,
            writer: stdinPipe.fileHandleForWriting,
            reader: stdoutPipe.fileHandleForReading,
            errorReader: stderrPipe.fileHandleForReading
        )
    }

    /// Validate and create an HTTP connection for a remote MCP server
    private func connectHTTP(_ config: ServerConfig) throws -> HTTPConnection {
        guard let urlString = config.url, !urlString.isEmpty else {
            throw MCPClientError.connectionFailed("No URL specified for HTTP server")
        }

        guard let url = URL(string: urlString) else {
            throw MCPClientError.connectionFailed("Invalid URL: \(urlString)")
        }

        let scheme = url.scheme?.lowercased()
        guard scheme == "https" || scheme == "http" else {
            throw MCPClientError.connectionFailed("Only HTTP/HTTPS URLs are supported, got: \(scheme ?? "none")")
        }

        // Enforce TLS for remote servers — plain HTTP only for localhost
        if scheme == "http" {
            let host = url.host?.lowercased() ?? ""
            guard host == "localhost" || host == "127.0.0.1" || host == "::1" else {
                throw MCPClientError.connectionFailed("Plain HTTP only allowed for localhost. Use HTTPS for remote servers.")
            }
        }

        print("[MCPClient] Creating HTTP connection to \(urlString)")
        return HTTPConnection(url: url, headers: config.headers)
    }

    private func discoverCapabilities(serverId: UUID, serverName: String, connection: any MCPConnection, hasTools: Bool, hasResources: Bool) async throws {
        // Only discover tools if server advertises tool support
        if hasTools {
            do {
                let response = try await connection.sendRequest(method: "tools/list", params: nil)
                if let result = response["result"] as? [String: Any],
                   let tools = result["tools"] as? [[String: Any]] {
                    discoveredTools[serverId] = tools.compactMap { tool -> DiscoveredTool? in
                        let name = tool["name"] as? String ?? ""
                        let description = tool["description"] as? String ?? ""

                        // Validate tool name: must be non-empty, alphanumeric/underscore/hyphen, max 128 chars
                        guard !name.isEmpty,
                              name.count <= 128,
                              name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else {
                            print("[MCPClient] Skipping tool with invalid name: '\(name.prefix(64))'")
                            return nil
                        }

                        var schema = tool["inputSchema"] as? [String: Any] ?? [:]
                        // Ensure "properties" is never null - must be an object
                        if schema["properties"] == nil || schema["properties"] is NSNull {
                            schema["properties"] = [:] as [String: Any]
                        }
                        // Ensure "type" is set
                        if schema["type"] == nil {
                            schema["type"] = "object"
                        }
                        let schemaJSON: String
                        if let data = try? JSONSerialization.data(withJSONObject: schema),
                           data.count <= 100_000,
                           let json = String(data: data, encoding: .utf8) {
                            schemaJSON = json
                        } else {
                            schemaJSON = "{\"type\":\"object\",\"properties\":{}}"
                        }
                        return DiscoveredTool(
                            serverId: serverId,
                            serverName: serverName,
                            name: name,
                            description: String(description.prefix(2048)),
                            inputSchemaJSON: schemaJSON
                        )
                    }
                }
            } catch {
                discoveredTools[serverId] = []
            }
        } else {
            discoveredTools[serverId] = []
        }

        // Only discover resources if server advertises resource support
        if hasResources {
            do {
                let response = try await connection.sendRequest(method: "resources/list", params: nil)
                if let result = response["result"] as? [String: Any],
                   let resources = result["resources"] as? [[String: Any]] {
                    discoveredResources[serverId] = resources.map { resource in
                        DiscoveredResource(
                            serverId: serverId,
                            serverName: serverName,
                            uri: resource["uri"] as? String ?? "",
                            name: resource["name"] as? String ?? "",
                            description: resource["description"] as? String,
                            mimeType: resource["mimeType"] as? String
                        )
                }
            }
        } catch {
            discoveredResources[serverId] = []
        }
        } else {
            discoveredResources[serverId] = []
        }
    }
}

// MARK: - Errors

public enum MCPClientError: LocalizedError {
    case serverDisabled(String)
    case serverNotConnected(UUID)
    case toolNotFound(UUID)
    case resourceNotFound(String)
    case connectionFailed(String)
    case invalidResponse
    case bufferOverflow

    public var errorDescription: String? {
        switch self {
        case .serverDisabled(let name):
            return "MCP server '\(name)' is disabled"
        case .serverNotConnected(let id):
            return "MCP server \(id) is not connected"
        case .toolNotFound(let id):
            return "Tool \(id) not found"
        case .resourceNotFound(let uri):
            return "Resource '\(uri)' not found"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .invalidResponse:
            return "Invalid response from MCP server"
        case .bufferOverflow:
            return "MCP server exceeded maximum buffer size"
        }
    }
}
