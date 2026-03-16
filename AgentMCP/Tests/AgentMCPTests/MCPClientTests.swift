import XCTest
@testable import MCPClient

final class MCPClientTests: XCTestCase {

    // MARK: - ServerConfig Tests

    func testServerConfigInitialization() {
        let config = MCPClient.ServerConfig(
            name: "TestServer",
            command: "/usr/local/bin/test-server",
            arguments: ["--port", "8080"],
            env: ["API_KEY": "test123"],
            enabled: true,
            autoStart: true
        )

        XCTAssertEqual(config.name, "TestServer")
        XCTAssertEqual(config.command, "/usr/local/bin/test-server")
        XCTAssertEqual(config.arguments, ["--port", "8080"])
        XCTAssertEqual(config.env["API_KEY"], "test123")
        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.autoStart)
        XCTAssertNotNil(config.id)
    }

    func testServerConfigDefaultValues() {
        let config = MCPClient.ServerConfig(
            name: "Minimal",
            command: "/bin/echo"
        )

        XCTAssertEqual(config.name, "Minimal")
        XCTAssertEqual(config.command, "/bin/echo")
        XCTAssertTrue(config.arguments.isEmpty)
        XCTAssertTrue(config.env.isEmpty)
        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.autoStart)
    }

    func testServerConfigCodable() throws {
        let original = MCPClient.ServerConfig(
            name: "CodableTest",
            command: "/usr/bin/test",
            arguments: ["-v"],
            env: ["KEY": "VALUE"],
            enabled: false,
            autoStart: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MCPClient.ServerConfig.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.command, original.command)
        XCTAssertEqual(decoded.arguments, original.arguments)
        XCTAssertEqual(decoded.env, original.env)
        XCTAssertEqual(decoded.enabled, original.enabled)
        XCTAssertEqual(decoded.autoStart, original.autoStart)
    }

    func testServerConfigHashable() {
        let config1 = MCPClient.ServerConfig(name: "Test", command: "/bin/test")
        let config2 = MCPClient.ServerConfig(name: "Test", command: "/bin/test")

        XCTAssertNotEqual(config1.id, config2.id)

        var set = Set<MCPClient.ServerConfig>()
        set.insert(config1)
        set.insert(config2)
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - HTTP ServerConfig Tests

    func testHTTPServerConfigInitialization() {
        let config = MCPClient.ServerConfig(
            name: "RemoteServer",
            url: "https://example.com/mcp",
            headers: ["Authorization": "Bearer token123"],
            enabled: true,
            autoStart: true
        )

        XCTAssertEqual(config.name, "RemoteServer")
        XCTAssertEqual(config.url, "https://example.com/mcp")
        XCTAssertEqual(config.headers["Authorization"], "Bearer token123")
        XCTAssertTrue(config.isHTTP)
        XCTAssertTrue(config.command.isEmpty)
        XCTAssertTrue(config.arguments.isEmpty)
        XCTAssertTrue(config.env.isEmpty)
    }

    func testStdioServerConfigIsNotHTTP() {
        let config = MCPClient.ServerConfig(
            name: "StdioServer",
            command: "/usr/local/bin/test-server"
        )

        XCTAssertFalse(config.isHTTP)
        XCTAssertNil(config.url)
    }

    func testHTTPServerConfigCodable() throws {
        let original = MCPClient.ServerConfig(
            name: "CodableHTTP",
            url: "https://api.example.com/mcp",
            headers: ["X-API-Key": "abc123"],
            enabled: true,
            autoStart: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MCPClient.ServerConfig.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.url, original.url)
        XCTAssertEqual(decoded.headers, original.headers)
        XCTAssertTrue(decoded.isHTTP)
        XCTAssertEqual(decoded.enabled, original.enabled)
        XCTAssertEqual(decoded.autoStart, original.autoStart)
    }

    func testHTTPServerConfigDefaultHeaders() {
        let config = MCPClient.ServerConfig(
            name: "NoHeaders",
            url: "https://example.com/mcp"
        )

        XCTAssertTrue(config.headers.isEmpty)
        XCTAssertTrue(config.isHTTP)
    }

    // MARK: - JSONValue Tests

    func testJSONValueStringLiteral() {
        let v: JSONValue = "hello"
        XCTAssertEqual(v.stringValue, "hello")
    }

    func testJSONValueIntLiteral() {
        let v: JSONValue = 42
        if case .int(let n) = v {
            XCTAssertEqual(n, 42)
        } else {
            XCTFail("Expected int")
        }
    }

    func testJSONValueBoolLiteral() {
        let v: JSONValue = true
        if case .bool(let b) = v {
            XCTAssertTrue(b)
        } else {
            XCTFail("Expected bool")
        }
    }

    func testJSONValueDictLiteral() {
        let v: JSONValue = ["key": "value"]
        if case .object(let dict) = v {
            XCTAssertEqual(dict["key"]?.stringValue, "value")
        } else {
            XCTFail("Expected object")
        }
    }

    func testJSONValueCodable() throws {
        let original: JSONValue = [
            "name": "test",
            "count": 5,
            "active": true
        ]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testJSONValueAnyValue() {
        let v: JSONValue = "hello"
        XCTAssertEqual(v.anyValue as? String, "hello")

        let n: JSONValue = 42
        XCTAssertEqual(n.anyValue as? Int, 42)
    }

    // MARK: - DiscoveredTool Tests

    func testDiscoveredToolInitialization() {
        let serverId = UUID()
        let tool = MCPClient.DiscoveredTool(
            serverId: serverId,
            serverName: "TestServer",
            name: "read_file",
            description: "Read a file",
            inputSchemaJSON: "{\"type\":\"object\"}"
        )

        XCTAssertEqual(tool.serverId, serverId)
        XCTAssertEqual(tool.serverName, "TestServer")
        XCTAssertEqual(tool.name, "read_file")
        XCTAssertEqual(tool.description, "Read a file")
        XCTAssertNotNil(tool.id)
        XCTAssertTrue(tool.inputSchemaJSON.contains("object"))
    }

    // MARK: - DiscoveredResource Tests

    func testDiscoveredResourceInitialization() {
        let serverId = UUID()
        let resource = MCPClient.DiscoveredResource(
            serverId: serverId,
            serverName: "TestServer",
            uri: "file:///Users/test/doc.txt",
            name: "document.txt",
            description: "A text document",
            mimeType: "text/plain"
        )

        XCTAssertEqual(resource.serverId, serverId)
        XCTAssertEqual(resource.uri, "file:///Users/test/doc.txt")
        XCTAssertEqual(resource.name, "document.txt")
        XCTAssertEqual(resource.description, "A text document")
        XCTAssertEqual(resource.mimeType, "text/plain")
    }

    func testDiscoveredResourceMinimal() {
        let resource = MCPClient.DiscoveredResource(
            serverId: UUID(),
            serverName: "Server",
            uri: "test://resource",
            name: "Resource"
        )
        XCTAssertNil(resource.description)
        XCTAssertNil(resource.mimeType)
    }

    // MARK: - ToolResult Tests

    func testToolResultTextContent() {
        let result = MCPClient.ToolResult(content: [.text("Hello!")], isError: false)
        XCTAssertFalse(result.isError)
        if case .text(let text) = result.content[0] {
            XCTAssertEqual(text, "Hello!")
        } else {
            XCTFail("Expected text")
        }
    }

    func testToolResultImageContent() {
        let result = MCPClient.ToolResult(
            content: [.image(data: "base64data", mimeType: "image/png")],
            isError: false
        )
        if case .image(let data, let mime) = result.content[0] {
            XCTAssertEqual(data, "base64data")
            XCTAssertEqual(mime, "image/png")
        } else {
            XCTFail("Expected image")
        }
    }

    func testToolResultCodable() throws {
        let original = MCPClient.ToolResult(
            content: [.text("line1"), .text("line2")],
            isError: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MCPClient.ToolResult.self, from: data)
        XCTAssertEqual(decoded.isError, original.isError)
        XCTAssertEqual(decoded.content.count, 2)
    }

    // MARK: - ConnectionState Tests

    func testConnectionStateDefault() {
        let state = MCPClient.ConnectionState()
        XCTAssertTrue(state.connectedServers.isEmpty)
        XCTAssertTrue(state.discoveredTools.isEmpty)
        XCTAssertTrue(state.discoveredResources.isEmpty)
        XCTAssertTrue(state.errors.isEmpty)
    }

    // MARK: - MCPClientError Tests

    func testErrorDescriptions() {
        let id = UUID()
        XCTAssertEqual(MCPClientError.serverDisabled("X").errorDescription, "MCP server 'X' is disabled")
        XCTAssertEqual(MCPClientError.serverNotConnected(id).errorDescription, "MCP server \(id) is not connected")
        XCTAssertEqual(MCPClientError.toolNotFound(id).errorDescription, "Tool \(id) not found")
        XCTAssertEqual(MCPClientError.resourceNotFound("uri").errorDescription, "Resource 'uri' not found")
        XCTAssertEqual(MCPClientError.connectionFailed("boom").errorDescription, "Connection failed: boom")
        XCTAssertEqual(MCPClientError.invalidResponse.errorDescription, "Invalid response from MCP server")
    }

    // MARK: - Client Actor Tests

    func testClientInitialization() async {
        let client = MCPClient()
        let state = await client.getConnectionState()
        XCTAssertTrue(state.connectedServers.isEmpty)
        XCTAssertTrue(state.discoveredTools.isEmpty)
    }

    func testIsConnectedFalseByDefault() async {
        let client = MCPClient()
        let connected = await client.isConnected(UUID())
        XCTAssertFalse(connected)
    }

    func testGetErrorNilByDefault() async {
        let client = MCPClient()
        let error = await client.getError(UUID())
        XCTAssertNil(error)
    }

    func testCallToolServerNotConnected() async {
        let client = MCPClient()
        do {
            _ = try await client.callTool(serverId: UUID(), name: "test")
            XCTFail("Should throw")
        } catch let error as MCPClientError {
            if case .serverNotConnected = error { } else { XCTFail("Wrong error") }
        } catch { XCTFail("Unexpected: \(error)") }
    }

    func testCallToolByUnknownId() async {
        let client = MCPClient()
        do {
            _ = try await client.callTool(toolId: UUID())
            XCTFail("Should throw")
        } catch let error as MCPClientError {
            if case .toolNotFound = error { } else { XCTFail("Wrong error") }
        } catch { XCTFail("Unexpected: \(error)") }
    }

    func testAddServerDisabled() async {
        let client = MCPClient()
        let config = MCPClient.ServerConfig(name: "Off", command: "/bin/true", enabled: false)
        do {
            try await client.addServer(config)
            XCTFail("Should throw")
        } catch let error as MCPClientError {
            if case .serverDisabled = error { } else { XCTFail("Wrong error") }
        } catch { XCTFail("Unexpected: \(error)") }

        let servers = await client.listServers()
        XCTAssertTrue(servers.isEmpty)
    }

    func testRemoveUnknownServer() async {
        let client = MCPClient()
        await client.removeServer(UUID())
        let servers = await client.listServers()
        XCTAssertTrue(servers.isEmpty)
    }

    func testAddHTTPServerDisabled() async {
        let client = MCPClient()
        let config = MCPClient.ServerConfig(name: "Off", url: "https://example.com/mcp", enabled: false)
        do {
            try await client.addServer(config)
            XCTFail("Should throw")
        } catch let error as MCPClientError {
            if case .serverDisabled = error { } else { XCTFail("Wrong error") }
        } catch { XCTFail("Unexpected: \(error)") }
    }

    // MARK: - Integration Test (requires hello_world server)

    func testConnectToHelloWorldServer() async throws {
        let serverPath = "/Users/toddbruss/bin/mcp-server-hello"
        guard FileManager.default.fileExists(atPath: serverPath) else {
            throw XCTSkip("hello_world server not installed at \(serverPath)")
        }

        let config = MCPClient.ServerConfig(
            name: "HelloWorld",
            command: serverPath,
            enabled: true
        )

        let client = MCPClient()
        try await client.addServer(config)

        // Verify connected
        let connected = await client.isConnected(config.id)
        XCTAssertTrue(connected)

        // Verify tools discovered
        let tools = await client.getAllTools()
        XCTAssertFalse(tools.isEmpty)
        let toolNames = tools.map(\.name)
        XCTAssertTrue(toolNames.contains("hello"))
        XCTAssertTrue(toolNames.contains("echo"))

        // Call hello tool
        let result = try await client.callTool(
            serverId: config.id,
            name: "hello",
            arguments: ["name": .string("Test")]
        )
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content.count, 1)
        if case .text(let text) = result.content[0] {
            XCTAssertTrue(text.contains("Test"))
        } else {
            XCTFail("Expected text content")
        }

        // Call echo tool
        let echo = try await client.callTool(
            serverId: config.id,
            name: "echo",
            arguments: ["message": .string("ping")]
        )
        if case .text(let text) = echo.content[0] {
            XCTAssertTrue(text.contains("ping"))
        }

        // Cleanup
        await client.removeServer(config.id)
        let stillConnected = await client.isConnected(config.id)
        XCTAssertFalse(stillConnected)
    }
}
