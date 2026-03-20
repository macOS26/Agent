// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AppleEventBridges",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "AppleEventBridges", targets: ["AppleEventBridges"]),
    ],
    targets: [
        .target(name: "AppleEventBridges"),
    ]
)
