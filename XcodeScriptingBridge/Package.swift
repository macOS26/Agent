// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XcodeScriptingBridge",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "XcodeScriptingBridge", targets: ["XcodeScriptingBridge"]),
    ],
    targets: [
        .target(name: "XcodeScriptingBridge"),
    ]
)
