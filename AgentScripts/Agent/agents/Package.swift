// swift-tools-version: 6.2
import PackageDescription
import Foundation

// Scripts compile as dynamic libraries (.dylib) loaded into Agent! via dlopen.
// ScriptService adds/removes entries when scripts are created/deleted.
let scriptNames = [
    "AccessibilityRecorder",
    "AgentAccessibility",
    "AXDemo",
    "CapturePhoto",
    "CheckMail",
    "CreateDMG",
    "CurrentPlaylist",
    "EmailAccounts",
    "ExtractAlbumArt",
    "GenerateBridge",
    "Hello",
    "JSDialog",
    "ListHomeContents",
    "ListNotes",
    "ListReminders",
    "MusicScriptingExamples",
    "NowPlaying",
    "NowPlayingHTML",
    "OrganizeEmails",
    "OrganizeOtherSubcategories",
    "PlayPlaylist",
    "PlayRandomFromCurrent",
    "QuitApps",
    "RunningApps",
    "SafariSearch",
    "SaveImageFromChat",
    "SaveImageFromClipboard",
    "SDEFtoJSON",
    "SendGroupMessage",
    "SendMessage",
    "Selenium",
    "SystemInfo",
    "TestCodingTools",
    "TestEnvVars",
    "TestGenerateBridge",
    "TodayEvents",
    "WebForm",
    "WebNavigate",
    "WebScrape",
    "WhatsPlaying",
]

// Scripting Bridge wrappers — generated from app .sdef files.
// Each becomes a target that scripts can `import`.
let bridgeNames = [
    "AdobeIllustratorBridge",
    "AgentScriptingBridge",
    "AppleScriptUtilityBridge",
    "AutomatorApplicationStubBridge",
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
    "SeleniumBridge",
    "ShortcutsBridge",
    "ShortcutsEventsBridge",
    "SimulatorBridge",
    "SystemEventsBridge",
    "SystemInformationBridge",
    "SystemSettingsBridge",
    "TVBridge",
    "TerminalBridge",
    "TextEditBridge",
    "UTMBridge",
    "VoiceOverBridge",
    "WishBridge",
]

let bridge = "Sources/XCFScriptingBridges"
let scripts = "Sources/Scripts"
let common: Target.Dependency = "ScriptingBridgeCommon"
let bridgeNameSet = Set(bridgeNames)

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
                deps.append(.init(stringLiteral: module))
            } else if module == "ScriptingBridgeCommon" {
                deps.append(common)
            }
        }
        if !trimmed.isEmpty && !trimmed.hasPrefix("import ") &&
           !trimmed.hasPrefix("//") && !trimmed.hasPrefix("@") {
            break
        }
    }
    return deps
}

// Exclude lists so SPM doesn't warn about unhandled files in shared directories
let allBridgeFiles = ["ScriptingBridgeCommon.swift"] + bridgeNames.map { "\($0).swift" }
let allScriptFiles = scriptNames.map { "\($0).swift" }

let package = Package(
    name: "agents",
    platforms: [.macOS(.v26)],
    products: scriptNames.map { .library(name: $0, type: .dynamic, targets: [$0]) },
    targets: [
        // ScriptingBridgeCommon — shared protocols and types for all bridges
        .target(name: "ScriptingBridgeCommon", path: bridge,
                exclude: bridgeNames.map { "\($0).swift" },
                sources: ["ScriptingBridgeCommon.swift"]),
    ]
    // Bridge targets — each wraps one app's scripting dictionary
    + bridgeNames.map { name in
        .target(name: name, dependencies: [common], path: bridge,
                exclude: allBridgeFiles.filter { $0 != "\(name).swift" },
                sources: ["\(name).swift"])
    }
    // Script targets — each compiles to a .dylib
    + scriptNames.map { name in
        .target(name: name, dependencies: parseDeps(for: name), path: scripts,
                exclude: allScriptFiles.filter { $0 != "\(name).swift" },
                sources: ["\(name).swift"])
    }
)
