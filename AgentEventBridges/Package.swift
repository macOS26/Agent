// swift-tools-version: 6.2
import PackageDescription

let bridgePath = "Sources/AgentEventBridges"

let bridgeNames: [String] = [
    "AdobeIllustratorBridge",
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
    "TerminalBridge",
    "TextEditBridge",
    "TVBridge",
    "UTMBridge",
    "VoiceOverBridge",
    "WishBridge",
    "XcodeScriptingBridge",
]

let allFiles = ["ScriptingBridgeCommon.swift"] + bridgeNames.map { "\($0).swift" }

let bridgeTargets: [Target] = bridgeNames.map { name in
    .target(
        name: name,
        dependencies: ["ScriptingBridgeCommon"],
        path: bridgePath,
        exclude: allFiles.filter { $0 != "\(name).swift" },
        sources: ["\(name).swift"]
    )
}

let bridgeProducts: [Product] = bridgeNames.map { name in
    .library(name: name, targets: [name])
}

let package = Package(
    name: "AgentEventBridges",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ScriptingBridgeCommon", targets: ["ScriptingBridgeCommon"]),
    ] + bridgeProducts,
    targets: [
        .target(
            name: "ScriptingBridgeCommon",
            path: bridgePath,
            exclude: bridgeNames.map { "\($0).swift" },
            sources: ["ScriptingBridgeCommon.swift"]
        ),
    ] + bridgeTargets
)
