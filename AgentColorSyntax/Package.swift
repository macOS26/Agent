// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AgentColorSyntax",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "AgentColorSyntax",
            targets: ["AgentColorSyntax"]
        ),
    ],
    targets: [
        .target(
            name: "AgentColorSyntax",
            path: "Sources/AgentColorSyntax"
        ),
    ]
)
