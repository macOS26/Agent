import Foundation
import MCP

/// A child MCP server that this server proxies to
actor ChildMCPServer {
    let config: MCPServerConfig
    private var process: Process?
    private var inputPipe: FileHandle?
    private var outputPipe: FileHandle?
    private var buffer = Data()
    
    var isConnected: Bool = false
    var tools: [Tool] = []
    
    init(config: MCPServerConfig) {
        self.config = config
    }
    
    /// Start the child server process and discover its tools
    func start() async {
        do {
            try spawnProcess()
            try await initializeConnection()
            try await discoverTools()
            isConnected = true
        } catch {
            print("[MCP] Failed to start server '\(config.name)': \(error)")
            isConnected = false
        }
    }
    
    /// Stop the child server
    func stop() {
        process?.terminate()
        process = nil
        inputPipe = nil
        outputPipe = nil
        isConnected = false
    }
    
    /// Call a tool on this child server
    func callTool(name: String, arguments: [String: Value]) async throws -> CallTool.Result {
        // Construct the tools/call request
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": UUID().uuidString,
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": arguments
            ]
        ]
        
        guard let requestData = try? JSONSerialization.data(withJSONObject: request),
              let requestString = String(data: requestData, encoding: .utf8) else {
            throw MCPServerError.encodingError
        }
        
        // Send request
        let message = "Content-Length: \(requestString.count)\r\n\r\n\(requestString)"
        guard let data = message.data(using: .utf8) else {
            throw MCPServerError.encodingError
        }
        
        inputPipe?.write(data)
        
        // Read response
        let response = try await readResponse()
        
        // Parse response
        guard let responseData = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let result = json["result"] as? [String: Any] else {
            throw MCPServerError.decodingError
        }
        
        // Convert to CallTool.Result
        var content: [Tool.Content] = []
        if let contentArray = result["content"] as? [[String: Any]] {
            for item in contentArray {
                if let text = item["text"] as? String {
                    content.append(.text(text))
                }
            }
        }
        
        let isError = result["isError"] as? Bool ?? false
        return CallTool.Result(content: content, isError: isError)
    }
    
    // MARK: - Private Methods
    
    private func spawnProcess() throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: config.command)
        proc.arguments = config.arguments
        
        // Set environment
        var env = ProcessInfo.processInfo.environment
        for (key, value) in config.environment {
            env[key] = value
        }
        proc.environment = env
        
        // Create pipes for stdio
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        proc.standardInput = stdinPipe
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe
        
        // Store for communication
        inputPipe = stdinPipe.fileHandleForWriting
        outputPipe = stdoutPipe.fileHandleForReading
        
        try proc.run()
        process = proc
    }
    
    private func initializeConnection() async throws {
        // Send initialize request
        let initRequest: [String: Any] = [
            "jsonrpc": "2.0",
            "id": "init",
            "method": "initialize",
            "params": [
                "protocolVersion": "2024-11-05",
                "capabilities": [:] as [String: Any],
                "clientInfo": [
                    "name": "Agent! MCP Proxy",
                    "version": "1.0.0"
                ]
            ]
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: initRequest),
              let requestString = String(data: data, encoding: .utf8) else {
            throw MCPServerError.encodingError
        }
        
        let message = "Content-Length: \(requestString.count)\r\n\r\n\(requestString)"
        guard let messageData = message.data(using: .utf8) else {
            throw MCPServerError.encodingError
        }
        
        inputPipe?.write(messageData)
        
        // Read response
        _ = try await readResponse()
    }
    
    private func discoverTools() async throws {
        // Request tools/list
        let listRequest: [String: Any] = [
            "jsonrpc": "2.0",
            "id": "list-tools",
            "method": "tools/list",
            "params": [:] as [String: Any]
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: listRequest),
              let requestString = String(data: data, encoding: .utf8) else {
            throw MCPServerError.encodingError
        }
        
        let message = "Content-Length: \(requestString.count)\r\n\r\n\(requestString)"
        guard let messageData = message.data(using: .utf8) else {
            throw MCPServerError.encodingError
        }
        
        inputPipe?.write(messageData)
        
        // Read response
        let response = try await readResponse()
        
        // Parse tools
        guard let responseData = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let toolsArray = result["tools"] as? [[String: Any]] else {
            return // No tools
        }
        
        tools = try toolsArray.compactMap { toolDict -> Tool? in
            guard let name = toolDict["name"] as? String,
                  let description = toolDict["description"] as? String,
                  let inputSchemaValue = toolDict["inputSchema"] else {
                return nil
            }
            // Convert inputSchema to Value
            let inputSchema: Value
            if let schemaValue = inputSchemaValue as? Value {
                inputSchema = schemaValue
            } else if let schemaData = try? JSONSerialization.data(withJSONObject: inputSchemaValue),
                      let schemaStr = String(data: schemaData, encoding: .utf8) {
                inputSchema = Value.string(schemaStr)
            } else {
                inputSchema = Value.object([:])
            }
            return Tool(name: name, description: description, inputSchema: inputSchema)
        }
    }
    
    private func readResponse() async throws -> String {
        guard let outputPipe = outputPipe else {
            throw MCPServerError.notConnected
        }
        
        // Read headers
        var headers = ""
        while true {
            let byte = outputPipe.readData(ofLength: 1)
            headers += String(data: byte, encoding: .utf8) ?? ""
            if headers.hasSuffix("\r\n\r\n") {
                break
            }
            if headers.count > 10000 {
                throw MCPServerError.responseTimeout
            }
        }
        
        // Parse Content-Length
        let lines = headers.components(separatedBy: "\r\n")
        var contentLength = 0
        for line in lines {
            if line.lowercased().hasPrefix("content-length:") {
                contentLength = Int(line.dropFirst(15).trimmingCharacters(in: .whitespaces)) ?? 0
                break
            }
        }
        
        guard contentLength > 0 else {
            throw MCPServerError.invalidResponse
        }
        
        // Read body
        
        guard contentLength > 0 else {
            throw MCPServerError.invalidResponse
        }
        
        var body = Data()
        while body.count < contentLength {
            let available = outputPipe.availableData
            body.append(available)
        }
        
        return String(data: body, encoding: .utf8) ?? ""
    }
}

// MARK: - Errors

enum MCPServerError: Error {
    case encodingError
    case decodingError
    case notConnected
    case responseTimeout
    case invalidResponse
}