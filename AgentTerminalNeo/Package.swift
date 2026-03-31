// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AgentTerminalNeo",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "AgentTerminalNeo",
            targets: ["AgentTerminalNeo"]
        ),
    ],
    targets: [
        .target(
            name: "AgentTerminalNeo",
            path: "Sources/AgentTerminalNeo"
        ),
    ]
)
