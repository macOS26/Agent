import Foundation

// MARK: - MCP Server Configuration

struct MCPServerConfig: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var command: String
    var arguments: [String]
    var environment: [String: String]
    var enabled: Bool
    var autoStart: Bool

    init(id: UUID = UUID(), name: String, command: String, arguments: [String] = [], environment: [String: String] = [:], enabled: Bool = true, autoStart: Bool = true) {
        self.id = id
        self.name = name
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.enabled = enabled
        self.autoStart = autoStart
    }

    // Accept both standard MCP format (args/env) and Agent format (arguments/environment)
    private enum CodingKeys: String, CodingKey {
        case id, name, command
        case arguments, args
        case environment, env
        case enabled, autoStart
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        command = try c.decode(String.self, forKey: .command)
        // Accept "args" (MCP standard) or "arguments" (Agent)
        arguments = try c.decodeIfPresent([String].self, forKey: .args)
            ?? c.decodeIfPresent([String].self, forKey: .arguments) ?? []
        // Accept "env" (MCP standard) or "environment" (Agent)
        environment = try c.decodeIfPresent([String: String].self, forKey: .env)
            ?? c.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        autoStart = try c.decodeIfPresent(Bool.self, forKey: .autoStart) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(command, forKey: .command)
        try c.encode(arguments, forKey: .args)
        try c.encode(environment, forKey: .env)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(autoStart, forKey: .autoStart)
    }
    
    /// Create from a JSON string (for importing)
    static func fromJSON(_ jsonString: String) -> MCPServerConfig? {
        guard let data = jsonString.data(using: .utf8),
              let config = try? JSONDecoder().decode(MCPServerConfig.self, from: data) else {
            return nil
        }
        return config
    }
    
    /// Export to JSON string
    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - MCP Server Registry

@MainActor @Observable
final class MCPServerRegistry {
    static let shared = MCPServerRegistry()
    
    private let configFileURL: URL = {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mcp_servers.json")
        }
        let dir = appSupport.appendingPathComponent("Agent", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("mcp_servers.json")
    }()
    
    private(set) var servers: [MCPServerConfig] = []
    
    private init() {
        load()
    }
    
    // MARK: - CRUD Operations
    
    func add(_ config: MCPServerConfig) {
        servers.append(config)
        save()
    }
    
    func update(_ config: MCPServerConfig) {
        if let index = servers.firstIndex(where: { $0.id == config.id }) {
            servers[index] = config
            save()
        }
    }
    
    func remove(at id: UUID) {
        servers.removeAll { $0.id == id }
        save()
    }
    
    func toggleEnabled(_ id: UUID) {
        if let index = servers.firstIndex(where: { $0.id == id }) {
            servers[index].enabled.toggle()
            save()
        }
    }

    func setEnabled(_ id: UUID, _ enabled: Bool) {
        if let index = servers.firstIndex(where: { $0.id == id }) {
            servers[index].enabled = enabled
            save()
        }
    }
    
    // MARK: - Persistence
    
    private func load() {
        guard FileManager.default.fileExists(atPath: configFileURL.path),
              let data = try? Data(contentsOf: configFileURL),
              let loaded = try? JSONDecoder().decode([MCPServerConfig].self, from: data) else {
            // Load defaults if no config exists
            servers = Self.defaultServers
            return
        }
        servers = loaded
    }
    
    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(servers) else { return }
        
        Task.detached(priority: .background) { [url = configFileURL, data] in
            try? data.write(to: url, options: .atomic)
        }
    }
    
    // MARK: - Default Servers
    
    static let defaultServers: [MCPServerConfig] = [
        // Example: Filesystem MCP server (if installed)
        // MCPServerConfig(
        //     name: "Filesystem",
        //     command: "/usr/local/bin/mcp-filesystem",
        //     arguments: ["/Users/toddbruss/Documents"],
        //     environment: [:],
        //     enabled: false,
        //     autoStart: false
        // )
    ]
    
    // MARK: - Import/Export
    
    func exportAll() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(servers),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
    
    func importFrom(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8),
              let imported = try? JSONDecoder().decode([MCPServerConfig].self, from: data) else {
            return false
        }
        // Merge: update existing, add new
        for config in imported {
            if let index = servers.firstIndex(where: { $0.id == config.id }) {
                servers[index] = config
            } else {
                servers.append(config)
            }
        }
        save()
        return true
    }
}