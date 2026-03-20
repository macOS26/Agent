// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AgentMCP",
    platforms: [.macOS(.v26)],
    products: [
        // MCP Client library - embedded in Agent app to connect TO third-party MCP servers
        .library(name: "MCPClient", targets: ["MCPClient"]),
        // Test client for debugging MCP connections
        .executable(name: "TestClient", targets: ["TestClient"]),
    ],
    dependencies: [],
    targets: [
        // MCP Client library for embedding in apps (custom JSON-RPC, no SDK)
        .target(
            name: "MCPClient",
            dependencies: [],
            path: "Sources/MCPClient"
        ),
        // Test client for debugging MCP connections
        .executableTarget(
            name: "TestClient",
            dependencies: [
                "MCPClient"
            ],
            path: "Sources/TestClient"
        ),
        // Unit tests
        .testTarget(
            name: "AgentMCPTests",
            dependencies: [
                "MCPClient"
            ],
            path: "Tests/AgentMCPTests"
        )
    ]
)
