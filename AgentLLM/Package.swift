// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AgentLLM",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "AgentLLM", targets: ["AgentLLM"]),
    ],
    targets: [
        .target(name: "AgentLLM"),
    ]
)
