// swift-tools-version: 6.2
import PackageDescription
import Foundation

// Scripts compile as dynamic libraries (.dylib) loaded into Agent! via dlopen.
// ScriptService adds/removes entries when scripts are created/deleted.
let scriptNames = [
    "AXDemo",
    "AccessibilityRecorder",
    "CapturePhoto",
    "CheckMail",
    "CreateDMG",
    "EmailAccounts",
    "ExtractAlbumArt",
    "GenerateBridge",
    "Hello",
    "ListHomeContents",
    "ListNotes",
    "ListReminders",
    "MusicScriptingExamples",
    "NowPlaying",
    "NowPlayingHTML",
    "OrganizeEmails",
    "PlayPlaylist",
    "PlayRandomFromCurrent",
    "QuitApps",
    "RunningApps",
    "SDEFtoJSON",
    "SafariSearch",
    "SaveImageFromClipboard",
    "Selenium",
    "SendGroupMessage",
    "SendMessage",
    "SystemInfo",
    "TodayEvents",
    "WebForm",
    "WebNavigate",
    "WebScrape",
]

// Auto-detect bridge names from AppleEventBridges source files (single source of truth)
let bridgeNames: [String] = {
    let fileManager = FileManager.default
    let currentPath = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let bridgesPath = currentPath.appendingPathComponent("../../../AppleEventBridges/Sources/AppleEventBridges")
    guard let files = try? fileManager.contentsOfDirectory(atPath: bridgesPath.path) else { return [] }
    return files
        .filter { $0.hasSuffix("Bridge.swift") && $0 != "ScriptingBridgeCommon.swift" }
        .map { $0.replacingOccurrences(of: ".swift", with: "") }
        .sorted()
}()

let scripts = "Sources/Scripts"
let bridgeNameSet = Set(bridgeNames)

// Local package dependency for shared bridges
let packageDependencies: [PackageDescription.Package.Dependency] = [
    .package(name: "AppleEventBridges", path: "../../../AppleEventBridges")
]

// Build Target.Dependency for each bridge (explicit package reference)
func bridgeDep(_ name: String) -> Target.Dependency {
    .product(name: name, package: "AppleEventBridges")
}

// Auto-detect bridge imports in each script
func parseDeps(for name: String) -> [Target.Dependency] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent(scripts).appendingPathComponent("\(name).swift")
    guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    var deps: [Target.Dependency] = []
    for line in contents.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("import ") {
            let module = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            if bridgeNameSet.contains(module) {
                deps.append(bridgeDep(module))
            } else if module == "ScriptingBridgeCommon" {
                deps.append(bridgeDep("ScriptingBridgeCommon"))
            } else if module == "AgentAccessibility" {
                deps.append(.init(stringLiteral: "AgentAccessibility"))
            }
        }
        if !trimmed.isEmpty && !trimmed.hasPrefix("import ") &&
           !trimmed.hasPrefix("//") && !trimmed.hasPrefix("@") {
            break
        }
    }
    return deps
}

let allScriptFiles = scriptNames.map { "\($0).swift" }

let scriptProducts: [Product] = scriptNames.map {
    .library(name: $0, type: .dynamic, targets: [$0])
}

let coreTargets: [Target] = [
    .target(name: "AgentAccessibility", path: "Sources/AgentAccessibility"),
]

let scriptTargets: [Target] = scriptNames.map { name in
    .target(name: name, dependencies: parseDeps(for: name), path: scripts,
            exclude: allScriptFiles.filter { $0 != "\(name).swift" },
            sources: ["\(name).swift"])
}

let package = Package(
    name: "agents",
    platforms: [.macOS(.v26)],
    products: scriptProducts,
    dependencies: packageDependencies,
    targets: coreTargets + scriptTargets
)