// swift-tools-version: 6.0
import PackageDescription

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

let scriptTargets: [(String, [Target.Dependency])] = [
    ("CheckMail", ["MailBridge"]),
    ("GenerateBridge", []),
    ("Hello", []),
    ("ListNotes", ["NotesBridge"]),
    ("ListReminders", ["RemindersBridge"]),
    ("NowPlaying", ["MusicBridge"]),
    ("OrganizeEmails", ["MailBridge"]),
    ("OrganizeOtherSubcategories", [common, "MailBridge"]),
    ("RunningApps", ["SystemEventsBridge"]),
    ("TestGenerateBridge", []),
    ("TodayEvents", ["CalendarBridge"]),
]

let package = Package(
    name: "AgentScripts",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "XcodeBridge", targets: ["XcodeBridge"]),
    ],
    targets: [
        .target(name: "ScriptingBridgeCommon", path: bridge, sources: ["ScriptingBridgeCommon.swift"]),
    ]
    + bridgeNames.map { .target(name: $0, dependencies: [common], path: bridge, sources: ["\($0).swift"]) }
    + scriptTargets.map { name, deps in
        .executableTarget(name: name, dependencies: deps, path: scripts, sources: ["\(name).swift"])
    }
)
