import Foundation
import MCPClient

print("=== MCP Client Connection Test ===")

let config = MCPClient.ServerConfig(
    id: UUID(),
    name: "HelloWorld",
    command: "/Users/toddbruss/bin/mcp-server-hello",
    arguments: [],
    env: [:],
    enabled: true,
    autoStart: true
)

let client = MCPClient()

do {
    print("Connecting to server...")
    try await client.addServer(config)
    print("Connected!")

    let tools = await client.getAllTools()
    print("Discovered \(tools.count) tools:")
    for tool in tools {
        print("  - \(tool.name): \(tool.description)")
    }

    print("\nCalling 'hello' tool...")
    let result = try await client.callTool(
        serverId: config.id,
        name: "hello",
        arguments: ["name": .string("Agent")]
    )
    print("Tool result:")
    for content in result.content {
        if case .text(let text) = content {
            print("  \(text)")
        }
    }

    print("\nCalling 'echo' tool...")
    let echoResult = try await client.callTool(
        serverId: config.id,
        name: "echo",
        arguments: ["message": .string("MCP works!")]
    )
    print("Echo result:")
    for content in echoResult.content {
        if case .text(let text) = content {
            print("  \(text)")
        }
    }

    await client.removeServer(config.id)
    print("\nAll tests passed!")
} catch {
    print("Error: \(error)")
    print("  Localized: \(error.localizedDescription)")
}
