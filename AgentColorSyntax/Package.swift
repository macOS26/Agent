// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AgentColorSyntax",
    platforms: [.macOS(.v15)],
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
