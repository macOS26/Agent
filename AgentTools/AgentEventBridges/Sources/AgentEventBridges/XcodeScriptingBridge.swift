import Foundation
import ScriptingBridgeCommon

// MARK: - Xcode Scripting Bridge

// MARK: XcodeSaveOptions
@objc public enum XcodeSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: XcodeSchemeActionResultStatus
@objc public enum XcodeSchemeActionResultStatus : AEKeyword {
    case notYetStarted = 0x7372736e /* The action has not yet started. */
    case running = 0x73727372 /* The action is in progress. */
    case cancelled = 0x73727363 /* The action was cancelled. */
    case failed = 0x73727366 /* The action ran but did not complete successfully. */
    case errorOccurred = 0x73727365 /* The action was not able to run due to an error. */
    case succeeded = 0x73727373 /* The action succeeded. */
}

// MARK: XcodeGenericMethods
@objc public protocol XcodeGenericMethods {
    @objc optional func closeSaving(_ saving: XcodeSaveOptions, savingIn: URL!)
    @objc optional func delete()
    @objc optional func moveTo(_ to: SBObject!)
    @objc optional func build() -> XcodeSchemeActionResult
    @objc optional func clean() -> XcodeSchemeActionResult
    @objc optional func stop()
    @objc optional func runWithCommandLineArguments(_ withCommandLineArguments: Any!, withEnvironmentVariables: Any!) -> XcodeSchemeActionResult
    @objc optional func testWithCommandLineArguments(_ withCommandLineArguments: Any!, withEnvironmentVariables: Any!) -> XcodeSchemeActionResult
    @objc optional func attachToProcessIdentifier(_ toProcessIdentifier: Int, suspended: Bool)
    @objc optional func debugScheme(_ scheme: String!, runDestinationSpecifier: String!, skipBuilding: Bool, commandLineArguments: Any!, environmentVariables: Any!) -> XcodeSchemeActionResult
}

// MARK: XcodeApplication
@objc public protocol XcodeApplication: SBApplicationProtocol {
    @objc optional var name: String { get }
    @objc optional var frontmost: Bool { get }
    @objc optional var version: String { get }
    @objc optional var activeWorkspaceDocument: XcodeWorkspaceDocument { get }
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any
    @objc optional func quitSaving(_ saving: XcodeSaveOptions)
    @objc optional func exists(_ x: Any!) -> Bool
    @objc optional func createTemporaryDebuggingWorkspace() -> XcodeWorkspaceDocument
    @objc optional func fileDocuments() -> SBElementArray
    @objc optional func sourceDocuments() -> SBElementArray
    @objc optional func workspaceDocuments() -> SBElementArray
}
extension SBApplication: XcodeApplication {}

// MARK: XcodeDocument
@objc public protocol XcodeDocument: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional var modified: Bool { get }
    @objc optional var file: URL { get }
    @objc optional var path: String { get }
}
extension SBObject: XcodeDocument {}

// MARK: XcodeWindow
@objc public protocol XcodeWindow: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional var index: Int { get }
    @objc optional var bounds: NSRect { get }
    @objc optional var closeable: Bool { get }
    @objc optional var miniaturizable: Bool { get }
    @objc optional var miniaturized: Bool { get }
    @objc optional var resizable: Bool { get }
    @objc optional var visible: Bool { get }
    @objc optional var zoomable: Bool { get }
    @objc optional var zoomed: Bool { get }
    @objc optional var document: XcodeDocument { get }
    @objc optional func id() -> Int
}
extension SBObject: XcodeWindow {}

// MARK: XcodeFileDocument
@objc public protocol XcodeFileDocument: XcodeDocument {}
extension SBObject: XcodeFileDocument {}

// MARK: XcodeTextDocument
@objc public protocol XcodeTextDocument: XcodeFileDocument {
    @objc optional var selectedCharacterRange: [Any] { get }
    @objc optional var selectedParagraphRange: [Any] { get }
    @objc optional var text: String { get }
    @objc optional var notifiesWhenClosing: Bool { get }
}
extension SBObject: XcodeTextDocument {}

// MARK: XcodeSourceDocument
@objc public protocol XcodeSourceDocument: XcodeTextDocument {}
extension SBObject: XcodeSourceDocument {}

// MARK: XcodeWorkspaceDocument
@objc public protocol XcodeWorkspaceDocument: XcodeDocument {
    @objc optional var loaded: Bool { get }
    @objc optional var activeScheme: XcodeScheme { get }
    @objc optional var activeRunDestination: XcodeRunDestination { get }
    @objc optional var lastSchemeActionResult: XcodeSchemeActionResult { get }
    @objc optional var file: URL { get }
    @objc optional func projects() -> SBElementArray
    @objc optional func schemes() -> SBElementArray
    @objc optional func runDestinations() -> SBElementArray
}
extension SBObject: XcodeWorkspaceDocument {}

// MARK: XcodeSchemeActionResult
@objc public protocol XcodeSchemeActionResult: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var completed: Bool { get }
    @objc optional var status: XcodeSchemeActionResultStatus { get }
    @objc optional var errorMessage: String { get }
    @objc optional var buildLog: String { get }
    @objc optional func buildErrors() -> SBElementArray
    @objc optional func buildWarnings() -> SBElementArray
    @objc optional func analyzerIssues() -> SBElementArray
    @objc optional func testFailures() -> SBElementArray
    @objc optional func id() -> String
}
extension SBObject: XcodeSchemeActionResult {}

// MARK: XcodeSchemeActionIssue
@objc public protocol XcodeSchemeActionIssue: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var message: String { get }
    @objc optional var filePath: String { get }
    @objc optional var startingLineNumber: Int { get }
    @objc optional var endingLineNumber: Int { get }
    @objc optional var startingColumnNumber: Int { get }
    @objc optional var endingColumnNumber: Int { get }
}
extension SBObject: XcodeSchemeActionIssue {}

// MARK: XcodeBuildError
@objc public protocol XcodeBuildError: XcodeSchemeActionIssue {}
extension SBObject: XcodeBuildError {}

// MARK: XcodeBuildWarning
@objc public protocol XcodeBuildWarning: XcodeSchemeActionIssue {}
extension SBObject: XcodeBuildWarning {}

// MARK: XcodeAnalyzerIssue
@objc public protocol XcodeAnalyzerIssue: XcodeSchemeActionIssue {}
extension SBObject: XcodeAnalyzerIssue {}

// MARK: XcodeTestFailure
@objc public protocol XcodeTestFailure: XcodeSchemeActionIssue {}
extension SBObject: XcodeTestFailure {}

// MARK: XcodeScheme
@objc public protocol XcodeScheme: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional func id() -> String
}
extension SBObject: XcodeScheme {}

// MARK: XcodeRunDestination
@objc public protocol XcodeRunDestination: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional var architecture: String { get }
    @objc optional var platform: String { get }
    @objc optional var device: XcodeDevice { get }
    @objc optional var companionDevice: XcodeDevice { get }
}
extension SBObject: XcodeRunDestination {}

// MARK: XcodeDevice
@objc public protocol XcodeDevice: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional var deviceIdentifier: String { get }
    @objc optional var operatingSystemVersion: String { get }
    @objc optional var deviceModel: String { get }
    @objc optional var generic: Bool { get }
}
extension SBObject: XcodeDevice {}

// MARK: XcodeBuildConfiguration
@objc public protocol XcodeBuildConfiguration: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional func buildSettings() -> SBElementArray
    @objc optional func resolvedBuildSettings() -> SBElementArray
    @objc optional func id() -> String
}
extension SBObject: XcodeBuildConfiguration {}

// MARK: XcodeProject
@objc public protocol XcodeProject: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional func buildConfigurations() -> SBElementArray
    @objc optional func targets() -> SBElementArray
    @objc optional func id() -> String
}
extension SBObject: XcodeProject {}

// MARK: XcodeBuildSetting
@objc public protocol XcodeBuildSetting: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional var value: String { get }
}
extension SBObject: XcodeBuildSetting {}

// MARK: XcodeResolvedBuildSetting
@objc public protocol XcodeResolvedBuildSetting: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional var value: String { get }
}
extension SBObject: XcodeResolvedBuildSetting {}

// MARK: XcodeTarget
@objc public protocol XcodeTarget: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get }
    @objc optional var project: XcodeProject { get }
    @objc optional func buildConfigurations() -> SBElementArray
    @objc optional func id() -> String
}
extension SBObject: XcodeTarget {}