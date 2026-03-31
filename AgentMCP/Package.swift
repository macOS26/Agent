// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AgentMCP",
    platforms: [.macOS(.v26)],
    products: [
        // MCP Client library - embedded in Agent app to connect TO third-party MCP servers
        .library(name: "AgentMCP", targets: ["AgentMCP"]),
        // Test client for debugging MCP connections
        .executable(name: "TestClient", targets: ["TestClient"]),
    ],
    dependencies: [],
    targets: [
        // MCP Client library for embedding in apps (custom JSON-RPC, no SDK)
        .target(
            name: "AgentMCP",
            dependencies: [],
            path: "Sources/AgentMCP"
        ),
        // Test client for debugging MCP connections
        .executableTarget(
            name: "TestClient",
            dependencies: [
                "AgentMCP"
            ],
            path: "Sources/TestClient"
        ),
        // Unit tests
        .testTarget(
            name: "AgentMCPTests",
            dependencies: [
                "AgentMCP"
            ],
            path: "Tests/AgentMCPTests"
        )
    ]
)
