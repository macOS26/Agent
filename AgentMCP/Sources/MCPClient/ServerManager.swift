import Foundation

/// Manages persistent MCP server configurations
/// Stores server configs in ~/Library/Application Support/Agent!/MCPServers/
public actor ServerManager {
    
    // MARK: - Properties
    
    public static let shared = ServerManager()
    
    private let configDirectory: URL
    private let configFile: URL
    private var servers: [MCPClient.ServerConfig] = []
    
    // MARK: - Initialization
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        configDirectory = appSupport.appendingPathComponent("Agent!/MCPServers")
        configFile = configDirectory.appendingPathComponent("servers.json")
    }
    
    // MARK: - Server Management
    
    /// Load saved server configurations
    public func loadServers() throws -> [MCPClient.ServerConfig] {
        // Create directory if needed
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        
        // Load from file if exists
        guard FileManager.default.fileExists(atPath: configFile.path),
              let data = FileManager.default.contents(atPath: configFile.path),
              let decoded = try? JSONDecoder().decode([MCPClient.ServerConfig].self, from: data) else {
            servers = []
            return servers
        }
        
        servers = decoded
        return servers
    }
    
    /// Save server configurations to disk
    public func saveServers() throws {
        // Create directory if needed
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        
        let data = try JSONEncoder().encode(servers)
        try data.write(to: configFile)
    }
    
    /// Add a new server configuration
    public func addServer(_ config: MCPClient.ServerConfig) throws {
        // Check for duplicate
        if servers.contains(where: { $0.id == config.id }) {
            throw ServerManagerError.duplicateServer
        }
        
        servers.append(config)
        try saveServers()
    }
    
    /// Remove a server configuration
    public func removeServer(_ serverId: UUID) throws {
        servers.removeAll { $0.id == serverId }
        try saveServers()
    }
    
    /// Update a server configuration
    public func updateServer(_ config: MCPClient.ServerConfig) throws {
        guard let index = servers.firstIndex(where: { $0.id == config.id }) else {
            throw ServerManagerError.serverNotFound
        }
        
        servers[index] = config
        try saveServers()
    }
    
    /// Get all server configurations
    public func getServers() -> [MCPClient.ServerConfig] {
        servers
    }
    
    /// Get a server by ID
    public func getServer(_ id: UUID) -> MCPClient.ServerConfig? {
        servers.first { $0.id == id }
    }
    
    /// Enable a server
    public func enableServer(_ serverId: UUID) throws {
        guard let index = servers.firstIndex(where: { $0.id == serverId }) else {
            throw ServerManagerError.serverNotFound
        }
        
        var config = servers[index]
        config = MCPClient.ServerConfig(
            id: config.id,
            name: config.name,
            command: config.command,
            arguments: config.arguments,
            env: config.env,
            enabled: true
        )
        servers[index] = config
        try saveServers()
    }
    
    /// Disable a server
    public func disableServer(_ serverId: UUID) throws {
        guard let index = servers.firstIndex(where: { $0.id == serverId }) else {
            throw ServerManagerError.serverNotFound
        }
        
        var config = servers[index]
        config = MCPClient.ServerConfig(
            id: config.id,
            name: config.name,
            command: config.command,
            arguments: config.arguments,
            env: config.env,
            enabled: false
        )
        servers[index] = config
        try saveServers()
    }
    
    // MARK: - Presets
    
    /// Common MCP server presets for quick setup
    public static let presets: [MCPClient.ServerConfig] = [
        // Filesystem server (from official MCP servers)
        MCPClient.ServerConfig(
            name: "Filesystem",
            command: "/usr/local/bin/mcp-server-filesystem",
            arguments: ["/Users/\(NSUserName())/Documents"],
            enabled: false
        ),
        
        // GitHub server
        MCPClient.ServerConfig(
            name: "GitHub",
            command: "/usr/local/bin/mcp-server-github",
            arguments: [],
            env: ["GITHUB_TOKEN": ""],
            enabled: false
        ),
        
        // Puppeteer/Playwright browser automation
        MCPClient.ServerConfig(
            name: "Puppeteer",
            command: "/usr/local/bin/mcp-server-puppeteer",
            arguments: [],
            enabled: false
        ),
        
        // SQLite database
        MCPClient.ServerConfig(
            name: "SQLite",
            command: "/usr/local/bin/mcp-server-sqlite",
            arguments: [],
            enabled: false
        ),
        
        // Brave Search
        MCPClient.ServerConfig(
            name: "Brave Search",
            command: "/usr/local/bin/mcp-server-brave-search",
            arguments: [],
            env: ["BRAVE_API_KEY": ""],
            enabled: false
        ),
        
        // Memory/Knowledge graph
        MCPClient.ServerConfig(
            name: "Memory",
            command: "/usr/local/bin/mcp-server-memory",
            arguments: [],
            enabled: false
        ),
        
        // Sequential Thinking
        MCPClient.ServerConfig(
            name: "Sequential Thinking",
            command: "/usr/local/bin/mcp-server-sequential-thinking",
            arguments: [],
            enabled: false
        )
    ]
}

// MARK: - Errors

public enum ServerManagerError: LocalizedError {
    case duplicateServer
    case serverNotFound
    case saveFailed(String)
    case loadFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .duplicateServer:
            return "Server with this ID already exists"
        case .serverNotFound:
            return "Server not found"
        case .saveFailed(let reason):
            return "Failed to save servers: \(reason)"
        case .loadFailed(let reason):
            return "Failed to load servers: \(reason)"
        }
    }
}