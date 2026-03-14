// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentMCP",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MCPServer", type: .dynamic, targets: ["MCPServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0")
    ],
    targets: [
        .target(
            name: "MCPServer",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/MCPServer"
        )
    ]
)