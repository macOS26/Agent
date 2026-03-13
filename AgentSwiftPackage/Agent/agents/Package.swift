// swift-tools-version: 6.0
import PackageDescription
import Foundation

let bridge = "Sources/XCFScriptingBridges"
let scripts = "Sources/Scripts"
let common: Target.Dependency = "ScriptingBridgeCommon"

let bridgeNames = [
    "AdobeIllustratorBridge", "AutomatorBridge", "BluetoothFileExchangeBridge",
    "CalendarBridge", "ConsoleBridge", "ContactsBridge", "DatabaseEventsBridge",
    "DeveloperBridge", "FinalCutProCreatorStudioBridge", "FinderBridge",
    "FirefoxBridge", "FolderActionsSetupBridge", "GoogleChromeBridge",
    "ImageEventsBridge", "InstrumentsBridge", "KeynoteBridge",
    "LogicProCreatorStudioBridge", "MailBridge", "MessagesBridge",
    "MicrosoftEdgeBridge", "MusicBridge", "NotesBridge", "NumbersBridge",
    "NumbersCreatorStudioBridge", "PagesBridge", "PagesCreatorStudioBridge",
    "PhotosBridge", "PixelmatorProBridge", "PreviewBridge", "QuickTimePlayerBridge",
    "RemindersBridge", "SafariBridge", "ScreenSharingBridge", "ScriptEditorBridge",
    "ShortcutsBridge", "SimulatorBridge", "SystemEventsBridge",
    "SystemInformationBridge", "SystemSettingsBridge", "TVBridge", "TerminalBridge",
    "TextEditBridge", "UTMBridge", "VoiceOverBridge", "XcodeBridge",
]

// Set of all known bridge target names for fast lookup
let bridgeNameSet = Set(bridgeNames)

// Auto-discover scripts from Sources/Scripts/ and parse their imports for dependencies.
// The agent can create new .swift files and they'll be picked up automatically.
let scriptTargets: [(String, [Target.Dependency])] = {
    let scriptsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent(scripts)
    guard let files = try? FileManager.default.contentsOfDirectory(
        at: scriptsDir, includingPropertiesForKeys: nil
    ) else { return [] }

    return files
        .filter { $0.pathExtension == "swift" }
        .map { url -> (String, [Target.Dependency]) in
            let name = url.deletingPathExtension().lastPathComponent
            // Parse imports to find bridge dependencies
            var deps: [Target.Dependency] = []
            if let contents = try? String(contentsOf: url, encoding: .utf8) {
                for line in contents.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("import ") {
                        let module = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                        if bridgeNameSet.contains(module) {
                            deps.append(.init(stringLiteral: module))
                        } else if module == "ScriptingBridgeCommon" {
                            deps.append(common)
                        }
                    }
                    // Stop scanning after first non-import, non-comment, non-blank line
                    if !trimmed.isEmpty && !trimmed.hasPrefix("import ") &&
                       !trimmed.hasPrefix("//") && !trimmed.hasPrefix("@") {
                        break
                    }
                }
            }
            return (name, deps)
        }
        .sorted { $0.0 < $1.0 }
}()

// Compute exclude lists so SPM doesn't warn about unhandled files in shared directories
let allBridgeFiles = ["ScriptingBridgeCommon.swift"] + bridgeNames.map { "\($0).swift" }
let allScriptFiles = scriptTargets.map { "\($0.0).swift" }

let package = Package(
    name: "AgentScripts",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "XcodeBridge", targets: ["XcodeBridge"]),
    ],
    targets: [
        .target(name: "ScriptingBridgeCommon", path: bridge,
                exclude: bridgeNames.map { "\($0).swift" },
                sources: ["ScriptingBridgeCommon.swift"]),
    ]
    + bridgeNames.map { name in
        .target(name: name, dependencies: [common], path: bridge,
                exclude: allBridgeFiles.filter { $0 != "\(name).swift" },
                sources: ["\(name).swift"])
    }
    + scriptTargets.map { name, deps in
        .executableTarget(name: name, dependencies: deps, path: scripts,
                          exclude: allScriptFiles.filter { $0 != "\(name).swift" },
                          sources: ["\(name).swift"])
    }
)
