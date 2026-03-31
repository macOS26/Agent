// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AgentAudit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "AgentAudit", targets: ["AgentAudit"]),
    ],
    targets: [
        .target(name: "AgentAudit"),
    ]
)
