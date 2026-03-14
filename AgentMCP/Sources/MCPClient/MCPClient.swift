import Foundation
import MCP

#if canImport(System)
    import System
#else
    @preconcurrency import SystemPackage
#endif

/// MCP Client for connecting to third-party MCP servers
/// Manages server connections, discovers tools/resources, and executes tool calls
public actor MCPClient {
    
    // MARK: - Types
    
    public struct ServerConfig: Codable, Identifiable, Hashable, Sendable {
        public let id: UUID
        public let name: String
        public let command: String
        public let arguments: [String]
        public let env: [String: String]
        public let enabled: Bool
        public let autoStart: Bool
        
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
        public let inputSchemaJSON: String // JSON-encoded schema
        
        public init(serverId: UUID, serverName: String, name: String, description: String, inputSchema: Value) {
            self.id = UUID()
            self.serverId = serverId
            self.serverName = serverName
            self.name = name
            self.description = description
            
            // Encode schema to JSON string
            if let data = try? JSONEncoder().encode(inputSchema),
               let json = String(data: data, encoding: .utf8) {
                self.inputSchemaJSON = json
            } else {
                self.inputSchemaJSON = "{}"
            }
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
    
    private var clients: [UUID: Client] = [:]
    private var processes: [UUID: Process] = [:]
    private var pipes: [UUID: (input: Pipe, output: Pipe)] = [:]
    private var configs: [UUID: ServerConfig] = [:]
    private var discoveredTools: [UUID: [DiscoveredTool]] = [:]
    private var discoveredResources: [UUID: [DiscoveredResource]] = [:]
    private var errors: [UUID: String] = [:]
    
    public init() {}
    
    // MARK: - Server Management
    
    /// Add and connect to an MCP server
    public func addServer(_ config: ServerConfig) async throws {
        guard config.enabled else {
            throw MCPClientError.serverDisabled(config.name)
        }
        
        // Launch the MCP server process
        let process = try launchServerProcess(config)
        processes[config.id] = process
        configs[config.id] = config
        
        // Get pipes for stdio communication
        guard let (inputPipe, outputPipe) = pipes[config.id] else {
            throw MCPClientError.connectionFailed("Failed to create stdio pipes")
        }
        
        // Create stdio transport using file descriptors from pipes
        let inputFD = FileDescriptor(rawValue: outputPipe.fileHandleForReading.fileDescriptor)
        let outputFD = FileDescriptor(rawValue: inputPipe.fileHandleForWriting.fileDescriptor)
        
        let transport = StdioTransport(input: inputFD, output: outputFD)
        
        // Create and connect the client
        let client = Client(name: "Agent!", version: "1.0.0")
        try await client.connect(transport: transport)
        clients[config.id] = client
        
        // Discover tools and resources
        try await discoverCapabilities(serverId: config.id, serverName: config.name, client: client)
        
        // Clear any previous error
        errors.removeValue(forKey: config.id)
    }
    
    /// Remove a server connection
    public func removeServer(_ serverId: UUID) async {
        if let client = clients[serverId] {
            await client.disconnect()
            clients.removeValue(forKey: serverId)
        }
        
        if let process = processes[serverId] {
            process.terminate()
            processes.removeValue(forKey: serverId)
        }
        
        pipes.removeValue(forKey: serverId)
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
        clients[serverId] != nil
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
        arguments: [String: Value] = [:]
    ) async throws -> ToolResult {
        guard let client = clients[serverId] else {
            throw MCPClientError.serverNotConnected(serverId)
        }
        
        let (content, isError) = try await client.callTool(name: name, arguments: arguments)
        
        let contentBlocks: [ToolResult.ContentBlock] = content.map { item in
            switch item {
            case .text(let text):
                return .text(text)
            case .image(let data, let mimeType, _):
                return .image(data: data, mimeType: mimeType)
            case .resource(let resource, _, _):
                return .resource(uri: resource.uri, name: resource.text ?? resource.uri, mimeType: resource.mimeType)
            case .audio(let data, let mimeType):
                return .text("Audio (\(mimeType)): \(data.prefix(100))...")
            case .resourceLink(let uri, let name, _, _, let mimeType, _):
                return .resource(uri: uri, name: name, mimeType: mimeType)
            }
        }
        
        return ToolResult(content: contentBlocks, isError: isError ?? false)
    }
    
    /// Call a tool by its discovered ID
    public func callTool(
        toolId: UUID,
        arguments: [String: Value] = [:]
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
    public func readResource(serverId: UUID, uri: String) async throws -> Resource.Content {
        guard let client = clients[serverId] else {
            throw MCPClientError.serverNotConnected(serverId)
        }
        
        let contents = try await client.readResource(uri: uri)
        guard let content = contents.first else {
            throw MCPClientError.resourceNotFound(uri)
        }
        return content
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
    
    private func launchServerProcess(_ config: ServerConfig) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: config.command)
        process.arguments = config.arguments
        
        // Set up environment
        var env = ProcessInfo.processInfo.environment
        for (key, value) in config.env {
            env[key] = value
        }
        process.environment = env
        
        // Create pipes for stdio
        let inputPipe = Pipe()   // We write to this, server reads from it
        let outputPipe = Pipe()  // Server writes to this, we read from it
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        
        pipes[config.id] = (input: inputPipe, output: outputPipe)
        
        try process.run()
        return process
    }
    
    private func discoverCapabilities(
        serverId: UUID,
        serverName: String,
        client: Client
    ) async throws {
        // Discover tools
        do {
            let (tools, _) = try await client.listTools()
            discoveredTools[serverId] = tools.map { tool in
                DiscoveredTool(
                    serverId: serverId,
                    serverName: serverName,
                    name: tool.name,
                    description: tool.description ?? "",
                    inputSchema: tool.inputSchema
                )
            }
        } catch {
            // Server may not support tools
            discoveredTools[serverId] = []
        }
        
        // Discover resources
        do {
            let (resources, _) = try await client.listResources()
            discoveredResources[serverId] = resources.map { resource in
                DiscoveredResource(
                    serverId: serverId,
                    serverName: serverName,
                    uri: resource.uri,
                    name: resource.name,
                    description: resource.description,
                    mimeType: resource.mimeType
                )
            }
        } catch {
            // Server may not support resources
            discoveredResources[serverId] = []
        }
    }
}

// MARK: - Supporting Types

public enum MCPClientError: LocalizedError {
    case serverDisabled(String)
    case serverNotConnected(UUID)
    case toolNotFound(UUID)
    case resourceNotFound(String)
    case connectionFailed(String)
    case invalidResponse
    
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
        }
    }
}