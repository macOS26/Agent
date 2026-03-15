import Foundation
import MCP

/// Simple hello_world_tool MCP server for testing integration
/// Provides a single "hello_world" tool that returns a greeting

@main
struct HelloWorldServer {
    static func main() async throws {
        let transport = StdioTransport()
        
        let server = Server(
            name: "hello_world_tool",
            version: "1.0.0",
            capabilities: .init(tools: .init(listChanged: false))
        )
        
        // Register tools/list handler
        await server.withMethodHandler(ListTools.self) { _ in
            return ListTools.Result(tools: [
                Tool(
                    name: "hello_world",
                    description: "Return a hello world greeting",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Optional name to personalize the greeting"]
                        ]
                    ]
                )
            ])
        }
        
        // Register tools/call handler
        await server.withMethodHandler(CallTool.self) { params in
            guard params.name == "hello_world" else {
                return CallTool.Result(content: [.text("Unknown tool: \(params.name)")], isError: true)
            }
            
            let name = params.arguments?["name"]?.stringValue
            let greeting: String
            if let name = name, !name.isEmpty {
                greeting = "Hello, \(name)! Welcome from the hello_world_tool MCP server."
            } else {
                greeting = "Hello, World! Welcome from the hello_world_tool MCP server."
            }
            
            return CallTool.Result(content: [.text(greeting)], isError: false)
        }
        
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}