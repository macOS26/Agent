// swift-tools-version: 6.0
import PackageDescription
import Foundation

let bridge = "Sources/XCFScriptingBridges"
let scripts = "Sources/Scripts"
let common: Target.Dependency = "ScriptingBridgeCommon"

let bridgeNames = [
    "AdobeIllustratorBridge",
    "AutomatorBridge",
    "BluetoothFileExchangeBridge",
    "CalendarBridge",
    "ConsoleBridge",
    "ContactsBridge",
    "DatabaseEventsBridge",
    "DeveloperBridge",
    "FinalCutProCreatorStudioBridge",
    "FinderBridge",
    "FirefoxBridge",
    "FolderActionsSetupBridge",
    "GoogleChromeBridge",
    "ImageEventsBridge",
    "InstrumentsBridge",
    "KeynoteBridge",
    "LogicProCreatorStudioBridge",
    "MailBridge",
    "MessagesBridge",
    "MicrosoftEdgeBridge",
    "MusicBridge",
    "NotesBridge",
    "NumbersBridge",
    "NumbersCreatorStudioBridge",
    "PagesBridge",
    "PagesCreatorStudioBridge",
    "PhotosBridge",
    "PixelmatorProBridge",
    "PreviewBridge",
    "QuickTimePlayerBridge",
    "RemindersBridge",
    "SafariBridge",
    "ScreenSharingBridge",
    "ScriptEditorBridge",
    "ShortcutsBridge",
    "SimulatorBridge",
    "SystemEventsBridge",
    "SystemInformationBridge",
    "SystemSettingsBridge",
    "TVBridge",
    "TerminalBridge",
    "TextEditBridge",
    "UTMBridge",
    "VoiceOverBridge",
    "XcodeBridge",
]

// Set of all known bridge target names for fast lookup
let bridgeNameSet = Set(bridgeNames)

// Explicit script list — ScriptService adds/removes entries when scripts are created/deleted.
let scriptNames = [
    "AddSongsToRockPlaylist",
    "AlbumArtMonitor",
    "CheckMail",
    "ExtractAlbumArt",
    "GenerateBridge",
    "GenerateRockPlaylistSuggestions",
    "Hello",
    "ListHomeContents",
    "ListNotes",
    "ListReminders",
    "MusicScriptingExamples",
    "NowPlaying",
    "NowPlayingHTML",
    "OrganizeEmails",
    "OrganizeOtherSubcategories",
    "QuickTest",
    "ResearchRockPlaylistSuggestions",
    "RunningApps",
    "SaveAlbumArt",
    "TestGenerateBridge",
    "TodayEvents",
]

// Parse imports from each script to find bridge dependencies
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
    return deps
}

// Compute exclude lists so SPM doesn't warn about unhandled files in shared directories
let allBridgeFiles = ["ScriptingBridgeCommon.swift"] + bridgeNames.map { "\($0).swift" }
let allScriptFiles = scriptNames.map { "\($0).swift" }

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
    + scriptNames.map { name in
        .executableTarget(name: name, dependencies: parseDeps(for: name), path: scripts,
                          exclude: allScriptFiles.filter { $0 != "\(name).swift" },
                          sources: ["\(name).swift"])
    }
)
