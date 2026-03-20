// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "XcodeScriptingBridge",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "XcodeScriptingBridge", targets: ["XcodeScriptingBridge"]),
    ],
    targets: [
        .target(name: "XcodeScriptingBridge"),
    ]
)
