// swift-tools-version: 6.2
import PackageDescription
import Foundation

// Auto-detect bridge names from actual source files (single source of truth)
let bridgeNames: [String] = {
    let fileManager = FileManager.default
    let currentPath = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let sourcesPath = currentPath.appendingPathComponent("Sources/AppleEventBridges")
    guard let files = try? fileManager.contentsOfDirectory(atPath: sourcesPath.path) else { return [] }
    return files
        .filter { $0.hasSuffix("Bridge.swift") && $0 != "ScriptingBridgeCommon.swift" }
        .map { $0.replacingOccurrences(of: ".swift", with: "") }
        .sorted()
}()

let bridgePath = "Sources/AppleEventBridges"
let commonTarget: Target.Dependency = "ScriptingBridgeCommon"

// All bridge files for exclusion lists
let allBridgeFiles = ["ScriptingBridgeCommon.swift"] + bridgeNames.map { "\($0).swift" }

// Individual bridge targets for AgentScripts dynamic library imports
let bridgeTargets: [Target] = bridgeNames.map { name in
    .target(
        name: name,
        dependencies: [commonTarget],
        path: bridgePath,
        exclude: allBridgeFiles.filter { $0 != "\(name).swift" },
        sources: ["\(name).swift"]
    )
}

// Core targets: common utilities + aggregate library
let coreTargets: [Target] = [
    .target(
        name: "ScriptingBridgeCommon",
        path: bridgePath,
        exclude: bridgeNames.map { "\($0).swift" },
        sources: ["ScriptingBridgeCommon.swift"]
    ),
    // Aggregate library that re-exports all bridges (for Agent app)
    .target(
        name: "AppleEventBridges",
        dependencies: [commonTarget] + bridgeNames.map { Target.Dependency(stringLiteral: $0) },
        path: "Sources/AppleEventBridgesAggregate",
        sources: ["AppleEventBridgesAggregate.swift"]
    ),
]

// Products: aggregate library + individual bridge libraries
let bridgeProducts: [Product] = bridgeNames.map { name in
    .library(name: name, targets: [name])
}

let package = Package(
    name: "AppleEventBridges",
    platforms: [.macOS(.v26)],
    products: [
        // Aggregate library for Agent app
        .library(name: "AppleEventBridges", targets: ["AppleEventBridges"]),
        // Common utilities needed by individual scripts
        .library(name: "ScriptingBridgeCommon", targets: ["ScriptingBridgeCommon"]),
    ] + bridgeProducts,
    targets: coreTargets + bridgeTargets
)
