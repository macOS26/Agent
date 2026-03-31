// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AgentTools",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "AgentTools",
            targets: ["AgentTools"]
        ),
    ],
    targets: [
        .target(
            name: "AgentTools",
            path: "Sources/AgentTools"
        ),
    ]
)
