import AppKit
import ScriptingBridge
import Foundation

// MARK: - Protocols

@objc public protocol SBObjectProtocol: NSObjectProtocol {
    func get() -> Any!
}

@objc public protocol SBApplicationProtocol: SBObjectProtocol {
    func activate()
    var delegate: SBApplicationDelegate! { get set }
    var isRunning: Bool { get }
}

// MARK: - Enumerations

@objc public enum XcodeSaveOptions: AEKeyword {
    case yes = 0x79657320 /* 'yes ' */
    case no = 0x6e6f2020 /* 'no  ' */
    case ask = 0x61736b20 /* 'ask ' */
}

@objc public enum XcodeSchemeActionResultStatus: AEKeyword {
    case notYetStarted = 0x7372736e /* 'srsn' */
    case running = 0x73727372       /* 'srsr' */
    case cancelled = 0x73727363     /* 'srsc' */
    case failed = 0x73727366        /* 'srsf' */
    case errorOccurred = 0x73727365 /* 'srse' */
    case succeeded = 0x73727373     /* 'srss' */
}

// MARK: - Generic Methods

@objc public protocol XcodeGenericMethods {
    @objc optional func closeSaving(_ saving: XcodeSaveOptions, savingIn: URL!)
    @objc optional func delete()
    @objc optional func moveTo(_ to: SBObject!)
    @objc optional func build() -> XcodeSchemeActionResult
    @objc optional func clean() -> XcodeSchemeActionResult
    @objc optional func stop()
    @objc optional func runWithCommandLineArguments(_ withCommandLineArguments: Any!, withEnvironmentVariables: Any!) -> XcodeSchemeActionResult
    @objc optional func testWithCommandLineArguments(_ withCommandLineArguments: Any!, withEnvironmentVariables: Any!) -> XcodeSchemeActionResult
}

// MARK: - XcodeApplication

@objc public protocol XcodeApplication: SBApplicationProtocol {
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional var name: String { get }
    @objc optional var frontmost: Bool { get }
    @objc optional var version: String { get }
    @objc optional func `open`(_ x: Any!) -> Any
    @objc optional func quitSaving(_ saving: XcodeSaveOptions)
    @objc optional func exists(_ x: Any!) -> Bool
    @objc optional func fileDocuments() -> SBElementArray
    @objc optional func sourceDocuments() -> SBElementArray
    @objc optional func workspaceDocuments() -> SBElementArray
    @objc optional var activeWorkspaceDocument: XcodeWorkspaceDocument { get }
    @objc optional func setActiveWorkspaceDocument(_ activeWorkspaceDocument: XcodeWorkspaceDocument!)
}
extension SBApplication: XcodeApplication {}

// MARK: - XcodeDocument

@objc public protocol XcodeDocument: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional var modified: Bool { get }
    @objc optional var file: URL { get }
    @objc optional var path: String { get }
    @objc optional func setPath(_ path: String!)
}
extension SBObject: XcodeDocument {}

// MARK: - XcodeWorkspaceDocument

@objc public protocol XcodeWorkspaceDocument: XcodeDocument {
    @objc optional func projects() -> SBElementArray
    @objc optional func schemes() -> SBElementArray
    @objc optional func runDestinations() -> SBElementArray
    @objc optional var loaded: Bool { get }
    @objc optional var activeScheme: XcodeScheme { get }
    @objc optional var activeRunDestination: XcodeRunDestination { get }
    @objc optional var lastSchemeActionResult: XcodeSchemeActionResult { get }
    @objc optional func setActiveScheme(_ activeScheme: XcodeScheme!)
    @objc optional func setActiveRunDestination(_ activeRunDestination: XcodeRunDestination!)
}
extension SBObject: XcodeWorkspaceDocument {}

// MARK: - XcodeSchemeActionResult

@objc public protocol XcodeSchemeActionResult: SBObjectProtocol, XcodeGenericMethods {
    @objc optional func buildErrors() -> SBElementArray
    @objc optional func buildWarnings() -> SBElementArray
    @objc optional func analyzerIssues() -> SBElementArray
    @objc optional func testFailures() -> SBElementArray
    @objc optional func id() -> String
    @objc optional var completed: Bool { get }
    @objc optional var status: XcodeSchemeActionResultStatus { get }
    @objc optional var errorMessage: String { get }
    @objc optional var buildLog: String { get }
}
extension SBObject: XcodeSchemeActionResult {}

// MARK: - XcodeSchemeActionIssue

@objc public protocol XcodeSchemeActionIssue: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var message: String { get }
    @objc optional var filePath: String { get }
    @objc optional var startingLineNumber: Int { get }
    @objc optional var endingLineNumber: Int { get }
    @objc optional var startingColumnNumber: Int { get }
    @objc optional var endingColumnNumber: Int { get }
}
extension SBObject: XcodeSchemeActionIssue {}

@objc public protocol XcodeBuildError: XcodeSchemeActionIssue {}
extension SBObject: XcodeBuildError {}

@objc public protocol XcodeBuildWarning: XcodeSchemeActionIssue {}
extension SBObject: XcodeBuildWarning {}

@objc public protocol XcodeAnalyzerIssue: XcodeSchemeActionIssue {}
extension SBObject: XcodeAnalyzerIssue {}

// MARK: - XcodeScheme

@objc public protocol XcodeScheme: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional func id() -> String
}
extension SBObject: XcodeScheme {}

// MARK: - XcodeRunDestination

@objc public protocol XcodeRunDestination: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional var architecture: String { get }
    @objc optional var platform: String { get }
    @objc optional var device: XcodeDevice { get }
}
extension SBObject: XcodeRunDestination {}

// MARK: - XcodeDevice

@objc public protocol XcodeDevice: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional var deviceIdentifier: String { get }
    @objc optional var operatingSystemVersion: String { get }
    @objc optional var deviceModel: String { get }
    @objc optional var generic: Bool { get }
}
extension SBObject: XcodeDevice {}

// MARK: - XcodeProject

@objc public protocol XcodeProject: SBObjectProtocol, XcodeGenericMethods {
    @objc optional func buildConfigurations() -> SBElementArray
    @objc optional func targets() -> SBElementArray
    @objc optional var name: String { get }
    @objc optional func id() -> String
}
extension SBObject: XcodeProject {}
