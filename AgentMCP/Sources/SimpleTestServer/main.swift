import Foundation
import MCP

/// Simple test MCP server for verification
/// Provides: echo tool, add tool, and a greet tool

@main
struct SimpleTestServer {
    static func main() async throws {
        let transport = StdioTransport()
        
        let server = Server(
            name: "simple-test-server",
            version: "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: false),
                resources: .init(subscribe: false, listChanged: false)
            )
        )
        
        // Register tools/list handler
        await server.withMethodHandler(ListTools.self) { _ in
            return ListTools.Result(tools: [
                Tool(
                    name: "echo",
                    description: "Echo back the input message",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "message": ["type": "string", "description": "The message to echo back"]
                        ],
                        "required": ["message"]
                    ]
                ),
                Tool(
                    name: "add",
                    description: "Add two numbers together",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "a": ["type": "number", "description": "First number"],
                            "b": ["type": "number", "description": "Second number"]
                        ],
                        "required": ["a", "b"]
                    ]
                ),
                Tool(
                    name: "greet",
                    description: "Generate a greeting message",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Name to greet"]
                        ],
                        "required": ["name"]
                    ]
                )
            ])
        }
        
        // Register resources/list handler
        await server.withMethodHandler(ListResources.self) { _ in
            return ListResources.Result(resources: [
                Resource(
                    uri: "test://info",
                    name: "Server Info",
                    description: "Information about this test server",
                    mimeType: "text/plain"
                )
            ])
        }
        
        // Register resources/read handler
        await server.withMethodHandler(ReadResource.self) { params in
            guard params.uri == "test://info" else {
                return ReadResource.Result(contents: [
                    .text("Resource not found: \(params.uri)")
                ])
            }
            return ReadResource.Result(contents: [
                .text("Simple Test MCP Server v1.0\n\nTools: echo, add, greet\nResources: test://info")
            ])
        }
        
        // Register tools/call handler
        await server.withMethodHandler(CallTool.self) { params in
            switch params.name {
            case "echo":
                let message = params.arguments?["message"]?.stringValue ?? "no message"
                return CallTool.Result(content: [.text("Echo: \(message)")], isError: false)
                
            case "add":
                let a = params.arguments?["a"]?.doubleValue ?? 0
                let b = params.arguments?["b"]?.doubleValue ?? 0
                let result = a + b
                return CallTool.Result(content: [.text("\(a) + \(b) = \(result)")], isError: false)
                
            case "greet":
                let name = params.arguments?["name"]?.stringValue ?? "World"
                return CallTool.Result(content: [.text("Hello, \(name)! Welcome to the test server.")], isError: false)
                
            default:
                return CallTool.Result(content: [.text("Unknown tool: \(params.name)")], isError: true)
            }
        }
        
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}