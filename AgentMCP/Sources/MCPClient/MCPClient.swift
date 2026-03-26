import Foundation

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
        // SSE/HTTP transport endpoint paths (for servers that use separate endpoints)
        public let sseEndpoint: String?
        public let httpEndpoint: String?
        // Common
        public let enabled: Bool
        public let autoStart: Bool

        /// True if this server uses HTTP/HTTPS transport
        public var isHTTP: Bool {
            guard let url = url, !url.isEmpty else { return false }
            return true
        }

        /// Stdio transport initializer
        public init(
            id: UUID = UUID(), name: String, command: String,
            arguments: [String] = [], env: [String: String] = [:],
            enabled: Bool = true, autoStart: Bool = true
        ) {
            self.id = id; self.name = name; self.command = command
            self.arguments = arguments; self.env = env
            self.url = nil; self.headers = [:]
            self.sseEndpoint = nil; self.httpEndpoint = nil
            self.enabled = enabled; self.autoStart = autoStart
        }

        /// HTTP transport initializer
        public init(
            id: UUID = UUID(), name: String, url: String,
            headers: [String: String] = [:],
            sseEndpoint: String? = nil, httpEndpoint: String? = nil,
            enabled: Bool = true, autoStart: Bool = true
        ) {
            self.id = id; self.name = name; self.command = ""
            self.arguments = []; self.env = [:]
            self.url = url; self.headers = headers
            self.sseEndpoint = sseEndpoint; self.httpEndpoint = httpEndpoint
            self.enabled = enabled; self.autoStart = autoStart
        }

        // MARK: - Codable (MCP-standard fields)

        private enum CodingKeys: String, CodingKey {
            case transport, command, args, env, url, headers
            case sseEndpoint, httpEndpoint
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let transport = try c.decodeIfPresent(String.self, forKey: .transport)

            id = UUID()
            name = ""

            command = try c.decodeIfPresent(String.self, forKey: .command) ?? ""
            arguments = try c.decodeIfPresent([String].self, forKey: .args) ?? []
            env = try c.decodeIfPresent([String: String].self, forKey: .env) ?? [:]
            url = try c.decodeIfPresent(String.self, forKey: .url)
            headers = try c.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
            sseEndpoint = try c.decodeIfPresent(String.self, forKey: .sseEndpoint)
            httpEndpoint = try c.decodeIfPresent(String.self, forKey: .httpEndpoint)

            // If transport is explicitly "http"/"https" with a url, clear command
            if let transport, (transport == "http" || transport == "https"), url != nil {
                _ = command // command stays empty for HTTP
            }

            enabled = true
            autoStart = true
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            if let url, !url.isEmpty {
                try c.encode("http", forKey: .transport)
                try c.encode(url, forKey: .url)
                if !headers.isEmpty { try c.encode(headers, forKey: .headers) }
                if let sseEndpoint, !sseEndpoint.isEmpty { try c.encode(sseEndpoint, forKey: .sseEndpoint) }
                if let httpEndpoint, !httpEndpoint.isEmpty { try c.encode(httpEndpoint, forKey: .httpEndpoint) }
            } else {
                try c.encode("stdio", forKey: .transport)
                try c.encode(command, forKey: .command)
                try c.encode(arguments, forKey: .args)
                if !env.isEmpty { try c.encode(env, forKey: .env) }
            }
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
            self.id = UUID(); self.serverId = serverId; self.serverName = serverName
            self.name = name; self.description = description; self.inputSchemaJSON = inputSchemaJSON
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
            self.id = UUID(); self.serverId = serverId; self.serverName = serverName
            self.uri = uri; self.name = name; self.description = description; self.mimeType = mimeType
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
            connectedServers: [ServerConfig] = [], discoveredTools: [DiscoveredTool] = [],
            discoveredResources: [DiscoveredResource] = [], errors: [UUID: String] = [:]
        ) {
            self.connectedServers = connectedServers; self.discoveredTools = discoveredTools
            self.discoveredResources = discoveredResources; self.errors = errors
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

        let connection: any MCPConnection
        if config.isHTTP {
            connection = try connectHTTP(config)
        } else {
            connection = try launchServer(config)
        }
        connections[config.id] = connection
        configs[config.id] = config

        // Wrap initialization in a 90-second timeout
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    let initResponse = try await connection.sendRequest(
                        method: "initialize",
                        params: [
                            "protocolVersion": "2024-11-05",
                            "capabilities": [String: Any](),
                            "clientInfo": ["name": "Agent!", "version": "1.0.0"]
                        ]
                    )

                    guard let result = initResponse["result"] as? [String: Any],
                          let serverInfo = result["serverInfo"] as? [String: Any] else {
                        throw MCPClientError.connectionFailed("Invalid initialize response")
                    }

                    let serverName = serverInfo["name"] as? String ?? config.name

                    try connection.sendNotification(method: "notifications/initialized", params: nil)

                    let capabilities = result["capabilities"] as? [String: Any] ?? [:]
                    try await self.discoverCapabilities(
                        serverId: config.id, serverName: config.name, connection: connection,
                        hasTools: capabilities["tools"] != nil,
                        hasResources: capabilities["resources"] != nil
                    )
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 90_000_000_000)
                    throw MCPClientError.connectionFailed("Initialization timed out after 90 seconds")
                }
                try await group.next()
                group.cancelAll()
            }
        } catch {
            connections[config.id]?.disconnect()
            connections.removeValue(forKey: config.id)
            configs.removeValue(forKey: config.id)
            throw error
        }

        errors.removeValue(forKey: config.id)
    }

    public func removeServer(_ serverId: UUID) {
        connections[serverId]?.disconnect()
        connections.removeValue(forKey: serverId)
        configs.removeValue(forKey: serverId)
        discoveredTools.removeValue(forKey: serverId)
        discoveredResources.removeValue(forKey: serverId)
        errors.removeValue(forKey: serverId)
    }

    public func listServers() -> [ServerConfig] { Array(configs.values) }

    public func getConnectionState() -> ConnectionState {
        ConnectionState(
            connectedServers: Array(configs.values),
            discoveredTools: discoveredTools.values.flatMap { $0 },
            discoveredResources: discoveredResources.values.flatMap { $0 },
            errors: errors
        )
    }

    public func isConnected(_ serverId: UUID) -> Bool { connections[serverId] != nil }
    public func getError(_ serverId: UUID) -> String? { errors[serverId] }

    // MARK: - Tool Discovery

    public func getAllTools() -> [DiscoveredTool] { discoveredTools.values.flatMap { $0 } }
    public func getTools(for serverId: UUID) -> [DiscoveredTool] { discoveredTools[serverId] ?? [] }

    // MARK: - Tool Execution

    public func callTool(serverId: UUID, name: String, arguments: [String: JSONValue] = [:]) async throws -> ToolResult {
        guard let connection = connections[serverId] else {
            throw MCPClientError.serverNotConnected(serverId)
        }
        guard connection.isAlive else {
            connections.removeValue(forKey: serverId)
            configs.removeValue(forKey: serverId)
            discoveredTools.removeValue(forKey: serverId)
            throw MCPClientError.connectionFailed("Server process is no longer running")
        }

        let response = try await connection.sendRequest(
            method: "tools/call",
            params: ["name": name, "arguments": arguments.mapValues(\.anyValue)]
        )

        guard let result = response["result"] as? [String: Any] else {
            if let error = response["error"] as? [String: Any] {
                let raw = error["message"] as? String ?? "Unknown error"
                let msg = String(raw.replacingOccurrences(of: "\n", with: " ").prefix(512))
                return ToolResult(content: [.text(msg)], isError: true)
            }
            throw MCPClientError.invalidResponse
        }

        let isError = result["isError"] as? Bool ?? false
        var contentBlocks: [ToolResult.ContentBlock] = []

        let maxTextSize = 1_024 * 1_024
        let maxImageSize = 10 * 1_024 * 1_024
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
                    contentBlocks.append(.image(data: data, mimeType: item["mimeType"] as? String ?? "image/png"))
                case "resource":
                    let resource = item["resource"] as? [String: Any] ?? [:]
                    contentBlocks.append(.resource(
                        uri: String((resource["uri"] as? String ?? "").prefix(2048)),
                        name: String((resource["name"] as? String ?? "").prefix(256)),
                        mimeType: resource["mimeType"] as? String
                    ))
                default:
                    contentBlocks.append(.text(String((item["text"] as? String ?? "[\(type)]").prefix(maxTextSize))))
                }
            }
        }

        return ToolResult(content: contentBlocks, isError: isError)
    }

    public func callTool(toolId: UUID, arguments: [String: JSONValue] = [:]) async throws -> ToolResult {
        guard let tool = getAllTools().first(where: { $0.id == toolId }) else {
            throw MCPClientError.toolNotFound(toolId)
        }
        return try await callTool(serverId: tool.serverId, name: tool.name, arguments: arguments)
    }

    // MARK: - Resource Operations

    public func getAllResources() -> [DiscoveredResource] { discoveredResources.values.flatMap { $0 } }

    public func readResource(serverId: UUID, uri: String) async throws -> ResourceContent {
        guard let connection = connections[serverId] else {
            throw MCPClientError.serverNotConnected(serverId)
        }
        let response = try await connection.sendRequest(method: "resources/read", params: ["uri": uri])
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

    public func startAutoStartServers(from configs: [ServerConfig]) async {
        for config in configs where config.autoStart && config.enabled {
            do { try await addServer(config) }
            catch { errors[config.id] = error.localizedDescription }
        }
    }

    // MARK: - Private Helpers

    private static let blockedEnvVars: Set<String> = [
        "DYLD_INSERT_LIBRARIES", "DYLD_LIBRARY_PATH", "LD_PRELOAD",
        "DYLD_FRAMEWORK_PATH", "DYLD_FALLBACK_LIBRARY_PATH",
        "DYLD_FALLBACK_FRAMEWORK_PATH", "DYLD_ROOT_PATH",
        "DYLD_SHARED_REGION", "DYLD_PRINT_TO_FILE",
    ]

    private func launchServer(_ config: ServerConfig) throws -> StdioConnection {
        let commandURL = URL(fileURLWithPath: config.command)
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: commandURL.path, isDirectory: &isDir), !isDir.boolValue else {
            throw MCPClientError.connectionFailed("Executable not found or is a directory: \(config.command)")
        }
        let resolved = commandURL.resolvingSymlinksInPath().path
        let originalResolved = URL(fileURLWithPath: config.command).standardizedFileURL.path
        if resolved != originalResolved {
            throw MCPClientError.connectionFailed("Refusing to execute symlink: \(config.command) → \(resolved)")
        }

        let process = Process()
        process.executableURL = commandURL
        process.arguments = config.arguments

        var env = ProcessInfo.processInfo.environment
        for (key, value) in config.env {
            let upper = key.uppercased()
            if Self.blockedEnvVars.contains(upper) || upper.hasPrefix("DYLD_") {
                continue
            }
            env[key] = value
        }
        process.environment = env

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        return StdioConnection(
            process: process,
            writer: stdinPipe.fileHandleForWriting,
            reader: stdoutPipe.fileHandleForReading,
            errorReader: stderrPipe.fileHandleForReading
        )
    }

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
        if scheme == "http" {
            let host = url.host?.lowercased() ?? ""
            guard host == "localhost" || host == "127.0.0.1" || host == "::1" else {
                throw MCPClientError.connectionFailed("Plain HTTP only allowed for localhost. Use HTTPS for remote servers.")
            }
        }
        return HTTPConnection(url: url, headers: config.headers, sseEndpoint: config.sseEndpoint, httpEndpoint: config.httpEndpoint)
    }

    private func discoverCapabilities(serverId: UUID, serverName: String, connection: any MCPConnection, hasTools: Bool, hasResources: Bool) async throws {
        if hasTools {
            do {
                let response = try await connection.sendRequest(method: "tools/list", params: nil)
                if let result = response["result"] as? [String: Any],
                   let tools = result["tools"] as? [[String: Any]] {
                    discoveredTools[serverId] = tools.compactMap { tool -> DiscoveredTool? in
                        let name = tool["name"] as? String ?? ""
                        let description = tool["description"] as? String ?? ""
                        guard !name.isEmpty, name.count <= 128,
                              name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else {
                            return nil
                        }
                        var schema = tool["inputSchema"] as? [String: Any] ?? [:]
                        if schema["properties"] == nil || schema["properties"] is NSNull {
                            schema["properties"] = [:] as [String: Any]
                        }
                        if schema["type"] == nil { schema["type"] = "object" }
                        let schemaJSON: String
                        if let data = try? JSONSerialization.data(withJSONObject: schema),
                           data.count <= 100_000,
                           let json = String(data: data, encoding: .utf8) {
                            schemaJSON = json
                        } else {
                            schemaJSON = "{\"type\":\"object\",\"properties\":{}}"
                        }
                        return DiscoveredTool(serverId: serverId, serverName: serverName, name: name,
                                             description: String(description.prefix(2048)), inputSchemaJSON: schemaJSON)
                    }
                }
            } catch { discoveredTools[serverId] = [] }
        } else {
            discoveredTools[serverId] = []
        }

        if hasResources {
            do {
                let response = try await connection.sendRequest(method: "resources/list", params: nil)
                if let result = response["result"] as? [String: Any],
                   let resources = result["resources"] as? [[String: Any]] {
                    discoveredResources[serverId] = resources.map { resource in
                        DiscoveredResource(
                            serverId: serverId, serverName: serverName,
                            uri: resource["uri"] as? String ?? "",
                            name: resource["name"] as? String ?? "",
                            description: resource["description"] as? String,
                            mimeType: resource["mimeType"] as? String
                        )
                    }
                }
            } catch { discoveredResources[serverId] = [] }
        } else {
            discoveredResources[serverId] = []
        }
    }
}
