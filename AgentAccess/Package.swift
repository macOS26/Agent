// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AgentAccess",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "AgentAccess", targets: ["AgentAccess"]),
    ],
    dependencies: [
        .package(url: "https://github.com/macOS26/AgentAudit.git", from: "1.0.0"),
        .package(url: "https://github.com/steipete/AXorcist.git", from: "0.1.0"),
    ],
    targets: [
        .target(name: "AgentAccess", dependencies: ["AgentAudit", "AXorcist"]),
    ]
)
