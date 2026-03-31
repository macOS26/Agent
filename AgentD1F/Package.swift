// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AgentD1F",
    platforms: [.macOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AgentD1F",
            targets: ["AgentD1F"]),
        .executable(
            name: "AgentD1FRunner",
            targets: ["AgentD1FRunner"])
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AgentD1F"),
        .executableTarget(
            name: "AgentD1FRunner",
            dependencies: ["AgentD1F"]),
        .testTarget(
            name: "AgentD1FTests",
            dependencies: ["AgentD1F"]
        )
    ]
)
