// swift-tools-version: 6.0
import PackageDescription

let bridge = "Sources/XCFScriptingBridges"
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

// Compute exclude list so SPM doesn't warn about unhandled files
let allBridgeFiles = ["ScriptingBridgeCommon.swift"] + bridgeNames.map { "\($0).swift" }

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
)
