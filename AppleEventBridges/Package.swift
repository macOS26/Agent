// swift-tools-version: 6.2
import PackageDescription

// Bridge names for individual targets (used by AgentScripts)
let bridgeNames = [
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
    "TVBridge",
    "TerminalBridge",
    "TextEditBridge",
    "UTMBridge",
    "VoiceOverBridge",
    "WishBridge",
]

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
    ] + bridgeProducts,
    targets: coreTargets + bridgeTargets
)