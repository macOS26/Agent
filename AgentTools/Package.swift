// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentTools",
    platforms: [.macOS(.v15)],
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
