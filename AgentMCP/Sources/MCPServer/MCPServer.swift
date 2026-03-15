import Foundation
import MCP

// MARK: - MCP Server Configuration (mirrors app's MCPServerConfig)

public struct MCPServerConfig: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var command: String
    public var arguments: [String]
    public var environment: [String: String]
    public var enabled: Bool
    public var autoStart: Bool
    
    public init(id: UUID = UUID(), name: String, command: String, arguments: [String] = [], environment: [String: String] = [:], enabled: Bool = true, autoStart: Bool = true) {
        self.id = id
        self.name = name
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.enabled = enabled
        self.autoStart = autoStart
    }
}

// MARK: - MCP Server Manager for Agent! for macOS

/// MCP Server Manager - handles multiple MCP server connections
/// The Agent app spawns this process which aggregates tools from configured MCP servers
public actor MCPServer {
    public static let serverName = "Agent! for macOS MCP"
    public static let serverVersion = "1.0.0"
    
    private var server: Server?
    private var transport: (any Transport)?
    
    /// Connected child MCP servers
    private var childServers: [ChildMCPServer] = []
    
    /// Config file location (mirrors app's location)
    private var configFileURL: URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mcp_servers.json")
        }
        let dir = appSupport.appendingPathComponent("Agent", isDirectory: true)
        return dir.appendingPathComponent("mcp_servers.json")
    }
    
    public init() async throws {
        self.transport = StdioTransport()
        
        // Create server with capabilities
        self.server = Server(
            name: Self.serverName,
            version: Self.serverVersion,
            capabilities: .init(tools: .init(listChanged: false))
        )
        
        // Load and start configured MCP servers
        await loadConfiguredServers()
        
        // Register tool handlers
        await setupHandlers()
    }
    
    public func run() async throws {
        guard let server = server, let transport = transport else { return }
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
    
    // MARK: - Configuration Loading
    
    private func loadConfiguredServers() async {
        guard FileManager.default.fileExists(atPath: configFileURL.path),
              let data = try? Data(contentsOf: configFileURL),
              let configs = try? JSONDecoder().decode([MCPServerConfig].self, from: data) else {
            return
        }
        
        for config in configs where config.enabled {
            await startChildServer(config: config)
        }
    }
    
    private func startChildServer(config: MCPServerConfig) async {
        let child = ChildMCPServer(config: config)
        await child.start()
        childServers.append(child)
    }
    
    // MARK: - Handler Setup
    
    private func setupHandlers() async {
        guard let server = server else { return }
        
        // Register tools/list handler - aggregates built-in + child server tools
        await server.withMethodHandler(ListTools.self) { [weak self] _ in
            let builtinTools = Self.createToolDefinitions()
            let childTools = await self?.getChildServerTools() ?? []
            return ListTools.Result(tools: builtinTools + childTools)
        }
        
        // Register tools/call handler
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            return await self?.handleToolCall(name: params.name, arguments: params.arguments ?? [:])
                ?? CallTool.Result(content: [.text("Server not initialized")], isError: true)
        }
    }
    
    /// Get all tools from child MCP servers
    private func getChildServerTools() async -> [Tool] {
        var allTools: [Tool] = []
        for child in childServers {
            // Prefix tool names with server name to avoid collisions
            let serverPrefix = child.config.name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "_", with: "-")
            let childTools = await child.tools
            for tool in childTools {
                let prefixedTool = Tool(
                    name: "\(serverPrefix)_\(tool.name)",
                    description: "[\(child.config.name)] \(tool.description ?? "")",
                    inputSchema: tool.inputSchema
                )
                allTools.append(prefixedTool)
            }
        }
        return allTools
    }
    
    // MARK: - Tool Definitions
    
    private static func createToolDefinitions() -> [Tool] {
        [
            // File operations
            Tool(
                name: "read_file",
                description: "Read file contents with line numbers. Use instead of `cat`.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "file_path": ["type": "string", "description": "Absolute path to the file to read"],
                        "limit": ["type": "integer", "description": "Max lines to return (default 2000)"],
                        "offset": ["type": "integer", "description": "1-based line number to start from (default 1)"]
                    ],
                    "required": ["file_path"]
                ]
            ),
            Tool(
                name: "write_file",
                description: "Create or overwrite a file. Use instead of heredocs or echo redirection.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "file_path": ["type": "string", "description": "Absolute path to the file to write"],
                        "content": ["type": "string", "description": "The full file content to write"]
                    ],
                    "required": ["file_path", "content"]
                ]
            ),
            Tool(
                name: "edit_file",
                description: "Replace exact text in a file. Use instead of sed/awk. You MUST read the file first.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "file_path": ["type": "string", "description": "Absolute path to the file to edit"],
                        "old_string": ["type": "string", "description": "The exact text to find and replace"],
                        "new_string": ["type": "string", "description": "The replacement text"],
                        "replace_all": ["type": "boolean", "description": "Replace all occurrences (default false)"]
                    ],
                    "required": ["file_path", "old_string", "new_string"]
                ]
            ),
            Tool(
                name: "list_files",
                description: "Find files matching a glob pattern. Use instead of `find`.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "pattern": ["type": "string", "description": "Glob pattern (e.g. \"*.swift\", \"Package.swift\")"],
                        "path": ["type": "string", "description": "Directory to search in (default: user home)"]
                    ],
                    "required": ["pattern"]
                ]
            ),
            Tool(
                name: "search_files",
                description: "Search file contents by regex pattern. Use instead of `grep`.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "pattern": ["type": "string", "description": "Regex pattern to search for"],
                        "path": ["type": "string", "description": "Directory to search in (default: user home)"],
                        "include": ["type": "string", "description": "File glob filter (e.g. \"*.swift\", \"*.py\")"]
                    ],
                    "required": ["pattern"]
                ]
            ),
            
            // Git operations
            Tool(
                name: "git_status",
                description: "Show current branch, staged/unstaged changes, and untracked files.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Repository path (REQUIRED for git operations)"]
                    ],
                    "required": ["path"]
                ]
            ),
            Tool(
                name: "git_diff",
                description: "Show file changes as a unified diff.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Repository path (REQUIRED for git operations)"],
                        "target": ["type": "string", "description": "Branch, commit, or ref to diff against"],
                        "staged": ["type": "boolean", "description": "Show staged changes only (default false)"]
                    ],
                    "required": ["path"]
                ]
            ),
            Tool(
                name: "git_log",
                description: "Show recent commit history as one-line summaries.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Repository path (REQUIRED for git operations)"],
                        "count": ["type": "integer", "description": "Number of commits to show (default 20, max 100)"]
                    ],
                    "required": ["path"]
                ]
            ),
            Tool(
                name: "git_commit",
                description: "Stage files and create a commit.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Repository path (REQUIRED for git operations)"],
                        "message": ["type": "string", "description": "Commit message"],
                        "files": ["type": "array", "items": ["type": "string"], "description": "Specific files to stage (default: all changes)"]
                    ],
                    "required": ["path", "message"]
                ]
            ),
            
            // Shell commands
            Tool(
                name: "execute_user_command",
                description: "Execute a shell command as the current user (no root). Use this for most tasks: git, builds, scripts, homebrew, etc.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "command": ["type": "string", "description": "The bash command to execute as the current user"]
                    ],
                    "required": ["command"]
                ]
            ),
            Tool(
                name: "execute_command",
                description: "Execute a shell command with ROOT privileges via the privileged daemon. Only use when root is required.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "command": ["type": "string", "description": "The bash command to execute as root"]
                    ],
                    "required": ["command"]
                ]
            ),
            
            // Task completion
            Tool(
                name: "task_complete",
                description: "Signal that the task has been completed. Always call this when done.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "summary": ["type": "string", "description": "Brief summary of what was accomplished"]
                    ],
                    "required": ["summary"]
                ]
            )
        ]
    }
    
    // MARK: - Tool Execution
    
    private func handleToolCall(name: String, arguments: [String: Value]) async -> CallTool.Result {
        do {
            let result: String
            
            // Check if this is a child server tool (has prefix_)
            if let underscoreIndex = name.firstIndex(of: "_"),
               let serverPrefix = String(name[..<underscoreIndex]).nilIfEmpty {
                let toolName = String(name[name.index(after: underscoreIndex)...])
                // Find matching child server
                for child in childServers {
                    let childPrefix = child.config.name.lowercased()
                        .replacingOccurrences(of: " ", with: "-")
                        .replacingOccurrences(of: "_", with: "-")
                    if childPrefix == serverPrefix {
                        return await callChildTool(server: child, toolName: toolName, arguments: arguments)
                    }
                }
            }
            
            // Built-in tools
            switch name {
            case "read_file":
                result = try await handleReadFile(arguments: arguments)
            case "write_file":
                result = try await handleWriteFile(arguments: arguments)
            case "edit_file":
                result = try await handleEditFile(arguments: arguments)
            case "list_files":
                result = try await handleListFiles(arguments: arguments)
            case "search_files":
                result = try await handleSearchFiles(arguments: arguments)
            case "git_status":
                result = try await handleGitStatus(arguments: arguments)
            case "git_diff":
                result = try await handleGitDiff(arguments: arguments)
            case "git_log":
                result = try await handleGitLog(arguments: arguments)
            case "git_commit":
                result = try await handleGitCommit(arguments: arguments)
            case "execute_user_command":
                result = try await handleExecuteUserCommand(arguments: arguments)
            case "execute_command":
                result = try await handleExecuteCommand(arguments: arguments)
            case "task_complete":
                result = try await handleTaskComplete(arguments: arguments)
            default:
                return CallTool.Result(content: [.text("Unknown tool: \(name)")], isError: true)
            }
            
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
        }
    }
    
    /// Call a tool on a child MCP server
    private func callChildTool(server child: ChildMCPServer, toolName: String, arguments: [String: Value]) async -> CallTool.Result {
        do {
            return try await child.callTool(name: toolName, arguments: arguments)
        } catch {
            return CallTool.Result(content: [.text("Error calling \(child.config.name).\(toolName): \(error.localizedDescription)")], isError: true)
        }
    }
    
    // MARK: - Path Validation

    /// Directories that must never be read from or written to
    private static let blockedPaths: [String] = [
        "/etc",
        "/System",
        "/Library/LaunchDaemons",
        "/var/root"
    ]

    /// Validate a file path for safety: blocks path traversal, sensitive directories, and symlinks outside allowed areas
    private func validatePath(_ filePath: String) throws {
        // Block path traversal via ".."
        let normalized = (filePath as NSString).standardizingPath
        if filePath.contains("..") {
            throw MCPError.invalidParams("Path traversal ('..') is not allowed: \(filePath)")
        }

        // Block access to sensitive directories
        for blocked in Self.blockedPaths {
            if normalized == blocked || normalized.hasPrefix(blocked + "/") {
                throw MCPError.invalidParams("Access to \(blocked) is not allowed")
            }
        }

        // Block symlinks that resolve outside the original directory
        let url = URL(fileURLWithPath: normalized)
        let resolved = url.resolvingSymlinksInPath().path
        let parentDir = (normalized as NSString).deletingLastPathComponent
        let resolvedParent = (resolved as NSString).deletingLastPathComponent
        if resolvedParent != parentDir {
            // Symlink resolves to a different directory — check it isn't a blocked path
            for blocked in Self.blockedPaths {
                if resolved == blocked || resolved.hasPrefix(blocked + "/") {
                    throw MCPError.invalidParams("Symlink resolves to blocked path: \(resolved)")
                }
            }
        }
    }

    // MARK: - Tool Implementations

    private func handleReadFile(arguments: [String: Value]) async throws -> String {
        guard let filePath = arguments["file_path"]?.stringValue else {
            throw MCPError.invalidParams("file_path is required")
        }
        try validatePath(filePath)
        
        let limit: Int
        if let value = arguments["limit"]?.intValue {
            limit = value
        } else if let value = arguments["limit"]?.doubleValue {
            limit = Int(value)
        } else {
            limit = 2000
        }
        
        let offset: Int
        if let value = arguments["offset"]?.intValue {
            offset = value
        } else if let value = arguments["offset"]?.doubleValue {
            offset = Int(value)
        } else {
            offset = 1
        }
        
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        let startLine = max(1, offset) - 1
        let endLine = min(lines.count, startLine + limit)
        
        var result = ""
        for i in startLine..<endLine {
            let lineNum = String(format: "%5d", i + 1)
            result += "\(lineNum)\t\(lines[i])\n"
        }
        
        return result
    }
    
    private func handleWriteFile(arguments: [String: Value]) async throws -> String {
        guard let filePath = arguments["file_path"]?.stringValue,
              let content = arguments["content"]?.stringValue else {
            throw MCPError.invalidParams("file_path and content are required")
        }
        try validatePath(filePath)

        // Create parent directories if needed
        let url = URL(fileURLWithPath: filePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        return "Successfully wrote \(content.count) characters to \(filePath)"
    }
    
    private func handleEditFile(arguments: [String: Value]) async throws -> String {
        guard let filePath = arguments["file_path"]?.stringValue,
              let oldString = arguments["old_string"]?.stringValue,
              let newString = arguments["new_string"]?.stringValue else {
            throw MCPError.invalidParams("file_path, old_string, and new_string are required")
        }
        try validatePath(filePath)

        let replaceAll = arguments["replace_all"]?.boolValue ?? false
        
        var content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        if replaceAll {
            content = content.replacingOccurrences(of: oldString, with: newString)
        } else {
            guard let range = content.range(of: oldString) else {
                return "Error: old_string not found in file"
            }
            content.replaceSubrange(range, with: newString)
        }
        
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        return "Successfully edited \(filePath)"
    }
    
    private func handleListFiles(arguments: [String: Value]) async throws -> String {
        guard let pattern = arguments["pattern"]?.stringValue else {
            throw MCPError.invalidParams("pattern is required")
        }
        
        let path = arguments["path"]?.stringValue ?? FileManager.default.homeDirectoryForCurrentUser.path
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        process.arguments = [path, "-name", pattern, "-not", "-path", "*/\\.*"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func handleSearchFiles(arguments: [String: Value]) async throws -> String {
        guard let pattern = arguments["pattern"]?.stringValue else {
            throw MCPError.invalidParams("pattern is required")
        }
        
        let path = arguments["path"]?.stringValue ?? FileManager.default.homeDirectoryForCurrentUser.path
        
        var args = ["-r", "-n", "-E", pattern, path]
        if let include = arguments["include"]?.stringValue {
            args.append(contentsOf: ["--include", include])
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func handleGitStatus(arguments: [String: Value]) async throws -> String {
        guard let path = arguments["path"]?.stringValue else {
            throw MCPError.invalidParams("path is required")
        }
        
        return try await runGitCommand(in: path, args: ["status"])
    }
    
    private func handleGitDiff(arguments: [String: Value]) async throws -> String {
        guard let path = arguments["path"]?.stringValue else {
            throw MCPError.invalidParams("path is required")
        }
        
        var args = ["diff"]
        if let staged = arguments["staged"]?.boolValue, staged {
            args.append("--staged")
        }
        if let target = arguments["target"]?.stringValue {
            args.append(target)
        }
        
        return try await runGitCommand(in: path, args: args)
    }
    
    private func handleGitLog(arguments: [String: Value]) async throws -> String {
        guard let path = arguments["path"]?.stringValue else {
            throw MCPError.invalidParams("path is required")
        }
        
        let count: Int
        if let value = arguments["count"]?.intValue {
            count = min(value, 100)
        } else if let value = arguments["count"]?.doubleValue {
            count = min(Int(value), 100)
        } else {
            count = 20
        }
        
        return try await runGitCommand(in: path, args: ["log", "--oneline", "-\(count)"])
    }
    
    private func handleGitCommit(arguments: [String: Value]) async throws -> String {
        guard let path = arguments["path"]?.stringValue,
              let message = arguments["message"]?.stringValue else {
            throw MCPError.invalidParams("path and message are required")
        }

        // Sanitize commit message: strip null bytes and leading dashes that could be interpreted as flags
        var sanitizedMessage = message.replacingOccurrences(of: "\0", with: "")
        if sanitizedMessage.hasPrefix("-") {
            sanitizedMessage = " " + sanitizedMessage
        }

        if let files = arguments["files"]?.arrayValue {
            let fileList = files.compactMap { $0.stringValue }
            // Stage specified files first, then commit
            _ = try await runGitCommand(in: path, args: ["add", "--"] + fileList)
            return try await runGitCommand(in: path, args: ["commit", "-m", sanitizedMessage])
        } else {
            return try await runGitCommand(in: path, args: ["commit", "-a", "-m", sanitizedMessage])
        }
    }
    
    private func runGitCommand(in path: String, args: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Maximum command string size (100 KB)
    private static let maxCommandSize = 100 * 1024

    private func handleExecuteUserCommand(arguments: [String: Value]) async throws -> String {
        guard let command = arguments["command"]?.stringValue else {
            throw MCPError.invalidParams("command is required")
        }

        guard command.utf8.count <= Self.maxCommandSize else {
            throw MCPError.invalidParams("Command exceeds maximum size of \(Self.maxCommandSize) bytes")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func handleExecuteCommand(arguments: [String: Value]) async throws -> String {
        // Root commands require privileged helper - return error for now
        // In full implementation, this would communicate with HelperService
        throw MCPError.methodNotFound("execute_command requires privileged helper setup")
    }
    
    private func handleTaskComplete(arguments: [String: Value]) async throws -> String {
        guard let summary = arguments["summary"]?.stringValue else {
            throw MCPError.invalidParams("summary is required")
        }
        
        return "Task completed: \(summary)"
    }
}

// MARK: - Entry Point

@main
struct MCPServerMain {
    static func main() async throws {
        let server = try await MCPServer()
        try await server.run()
    }
}

// MARK: - String Extensions

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}