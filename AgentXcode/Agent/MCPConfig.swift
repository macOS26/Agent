import Foundation

// MARK: - MCP Server Configuration

struct MCPServerConfig: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var command: String
    var arguments: [String]
    var environment: [String: String]

    // Agent-specific fields — stored in UserDefaults, NOT in JSON
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

    // Only encode/decode MCP-standard fields in JSON
    private enum CodingKeys: String, CodingKey {
        case name, command, args, env
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        command = try c.decode(String.self, forKey: .command)
        arguments = try c.decodeIfPresent([String].self, forKey: .args) ?? []
        environment = try c.decodeIfPresent([String: String].self, forKey: .env) ?? [:]
        // Generate ID; load Agent prefs from UserDefaults after decode
        id = UUID()
        enabled = true
        autoStart = true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(command, forKey: .command)
        if !arguments.isEmpty { try c.encode(arguments, forKey: .args) }
        if !environment.isEmpty { try c.encode(environment, forKey: .env) }
        try c.encode(name, forKey: .name)
    }

    /// Create from a JSON string (for importing)
    static func fromJSON(_ jsonString: String) -> MCPServerConfig? {
        guard let data = jsonString.data(using: .utf8),
              let config = try? JSONDecoder().decode(MCPServerConfig.self, from: data) else {
            return nil
        }
        return config
    }

    /// Export to JSON string (MCP-standard fields only)
    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - Agent Preferences (UserDefaults, keyed by server name)

extension MCPServerConfig {
    private static let enabledPrefix = "mcp.enabled."
    private static let autoStartPrefix = "mcp.autoStart."

    /// Load Agent-specific prefs from UserDefaults
    mutating func loadPrefs() {
        guard !name.isEmpty else { return }
        let defs = UserDefaults.standard
        if defs.object(forKey: Self.enabledPrefix + name) != nil {
            enabled = defs.bool(forKey: Self.enabledPrefix + name)
        }
        if defs.object(forKey: Self.autoStartPrefix + name) != nil {
            autoStart = defs.bool(forKey: Self.autoStartPrefix + name)
        }
    }

    /// Save Agent-specific prefs to UserDefaults
    func savePrefs() {
        guard !name.isEmpty else { return }
        UserDefaults.standard.set(enabled, forKey: Self.enabledPrefix + name)
        UserDefaults.standard.set(autoStart, forKey: Self.autoStartPrefix + name)
    }

    /// Remove Agent-specific prefs from UserDefaults
    func removePrefs() {
        guard !name.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: Self.enabledPrefix + name)
        UserDefaults.standard.removeObject(forKey: Self.autoStartPrefix + name)
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
        config.savePrefs()
        servers.append(config)
        save()
    }

    func update(_ config: MCPServerConfig) {
        if let index = servers.firstIndex(where: { $0.id == config.id }) {
            config.savePrefs()
            servers[index] = config
            save()
        }
    }

    func remove(at id: UUID) {
        if let server = servers.first(where: { $0.id == id }) {
            server.removePrefs()
        }
        servers.removeAll { $0.id == id }
        save()
    }

    func toggleEnabled(_ id: UUID) {
        if let index = servers.firstIndex(where: { $0.id == id }) {
            servers[index].enabled.toggle()
            servers[index].savePrefs()
        }
    }

    func setEnabled(_ id: UUID, _ enabled: Bool) {
        if let index = servers.firstIndex(where: { $0.id == id }) {
            servers[index].enabled = enabled
            servers[index].savePrefs()
        }
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: configFileURL.path),
              let data = try? Data(contentsOf: configFileURL),
              let loaded = try? JSONDecoder().decode([MCPServerConfig].self, from: data) else {
            servers = Self.defaultServers
            return
        }
        // Hydrate Agent-specific prefs from UserDefaults
        servers = loaded.map { var s = $0; s.loadPrefs(); return s }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(servers) else { return }

        Task.detached(priority: .background) { [url = configFileURL, data] in
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Default Servers

    static let defaultServers: [MCPServerConfig] = []

    // MARK: - Import/Export

    func exportAll() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(servers),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    func importFrom(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }

        // Try array of servers
        if let imported = try? JSONDecoder().decode([MCPServerConfig].self, from: data) {
            for var config in imported {
                config.loadPrefs()
                if let index = servers.firstIndex(where: { $0.name == config.name }) {
                    config.id = servers[index].id
                    servers[index] = config
                } else {
                    servers.append(config)
                }
            }
            save()
            return true
        }

        // Try single server
        if var config = try? JSONDecoder().decode(MCPServerConfig.self, from: data) {
            config.loadPrefs()
            if let index = servers.firstIndex(where: { $0.name == config.name }) {
                config.id = servers[index].id
                servers[index] = config
            } else {
                servers.append(config)
            }
            save()
            return true
        }

        return false
    }
}
