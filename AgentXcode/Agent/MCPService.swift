import Foundation
import MCPClient

/// Service for managing MCP server connections
/// Acts as a bridge between the UI (MCPServersView) and the underlying MCP client
/// The MCPClient is imported from the AgentMCP package
@MainActor @Observable
final class MCPService: @unchecked Sendable {
    static let shared = MCPService()

    private let client = MCPClient()
    private(set) var connectedServerIds: Set<UUID> = []
    var connectionErrors: [UUID: String] = [:]
    private(set) var discoveredTools: [MCPToolInfo] = []
    private(set) var discoveredResources: [MCPResourceInfo] = []
    /// Tool names disabled by the user, keyed by server name. Stored in UserDefaults.
    var disabledTools: Set<String> = [] {
        didSet { saveDisabledTools() }
    }

    private static let disabledToolsKey = "mcp.disabledTools"

    private func loadDisabledTools() {
        let arr = UserDefaults.standard.stringArray(forKey: Self.disabledToolsKey) ?? []
        disabledTools = Set(arr)
    }

    private func saveDisabledTools() {
        UserDefaults.standard.set(Array(disabledTools), forKey: Self.disabledToolsKey)
    }

    /// Unique key for a tool: "serverName.toolName"
    static func toolKey(serverName: String, toolName: String) -> String {
        "\(serverName).\(toolName)"
    }

    /// Check if a tool is enabled
    func isToolEnabled(serverName: String, toolName: String) -> Bool {
        !disabledTools.contains(Self.toolKey(serverName: serverName, toolName: toolName))
    }

    /// Toggle a tool's enabled state
    func toggleTool(serverName: String, toolName: String) {
        let key = Self.toolKey(serverName: serverName, toolName: toolName)
        if disabledTools.contains(key) {
            disabledTools.remove(key)
        } else {
            disabledTools.insert(key)
        }
    }

    struct MCPToolInfo: Identifiable, Sendable {
        let id: UUID
        let serverId: UUID
        let serverName: String
        let name: String
        let description: String
        let inputSchemaJSON: String
    }

    struct MCPResourceInfo: Identifiable, Sendable {
        let id: UUID
        let serverId: UUID
        let serverName: String
        let uri: String
        let name: String
    }

    private init() { loadDisabledTools() }

    /// Connect to an MCP server
    /// This launches the server process and establishes stdio communication
    func connect(to config: MCPServerConfig) async throws {
        let serverConfig = MCPClient.ServerConfig(
            id: config.id,
            name: config.name,
            command: config.command,
            arguments: config.arguments,
            env: config.environment,
            enabled: config.enabled,
            autoStart: config.autoStart
        )

        try await client.addServer(serverConfig)
        connectedServerIds.insert(config.id)
        connectionErrors.removeValue(forKey: config.id)

        // Refresh state
        await refreshState()
    }

    /// Disconnect from an MCP server
    func disconnect(serverId: UUID) async {
        await client.removeServer(serverId)
        connectedServerIds.remove(serverId)
        connectionErrors.removeValue(forKey: serverId)

        await refreshState()
    }

    /// Start all servers marked with autoStart
    func startAutoStartServers() async {
        let autoStartConfigs = MCPServerRegistry.shared.servers
            .filter { $0.autoStart && $0.enabled && !connectedServerIds.contains($0.id) }

        for config in autoStartConfigs {
            do {
                try await connect(to: config)
            } catch {
                connectionErrors[config.id] = error.localizedDescription
            }
        }
    }

    /// Check if a server is connected
    func isConnected(_ serverId: UUID) async -> Bool {
        await client.isConnected(serverId)
    }

    /// Get error for a server
    func getError(_ serverId: UUID) async -> String? {
        // Check both local errors and client-side errors
        if let localError = connectionErrors[serverId] {
            return localError
        }
        return await client.getError(serverId)
    }

    /// Refresh local state from client
    private func refreshState() async {
        let state = await client.getConnectionState()

        discoveredTools = state.discoveredTools.map { tool in
            MCPToolInfo(
                id: tool.id,
                serverId: tool.serverId,
                serverName: tool.serverName,
                name: tool.name,
                description: tool.description,
                inputSchemaJSON: tool.inputSchemaJSON
            )
        }

        discoveredResources = state.discoveredResources.map { resource in
            MCPResourceInfo(
                id: resource.id,
                serverId: resource.serverId,
                serverName: resource.serverName,
                uri: resource.uri,
                name: resource.name
            )
        }
    }

    /// Call a tool on a specific server
    func callTool(serverId: UUID, name: String, arguments: [String: JSONValue]) async throws -> MCPClient.ToolResult {
        try await client.callTool(serverId: serverId, name: name, arguments: arguments)
    }

    /// Read a resource from a server
    func readResource(serverId: UUID, uri: String) async throws -> MCPClient.ResourceContent {
        try await client.readResource(serverId: serverId, uri: uri)
    }

    /// Refresh a server connection
    func refreshConnection(serverId: UUID) async throws {
        guard let config = MCPServerRegistry.shared.servers.first(where: { $0.id == serverId }) else {
            return
        }

        await disconnect(serverId: serverId)
        try await connect(to: config)
    }
}
