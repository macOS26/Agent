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
    @objc optional func closeSaving(_ saving: XcodeSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func delete() // Delete an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
    @objc optional func build() -> XcodeSchemeActionResult // Invoke the "build" scheme action. This command should be sent to a workspace document. The build will be performed using the workspace document's current active scheme and active run destination. This command does not wait for the action to complete; its progress can be tracked with the returned scheme action result.
    @objc optional func clean() -> XcodeSchemeActionResult // Invoke the "clean" scheme action. This command should be sent to a workspace document. The clean will be performed using the workspace document's current active scheme and active run destination. This command does not wait for the action to complete; its progress can be tracked with the returned scheme action result.
    @objc optional func stop() // Stop the active scheme action, if one is running. This command should be sent to a workspace document. This command does not wait for the action to stop.
    @objc optional func runWithCommandLineArguments(_ withCommandLineArguments: Any!, withEnvironmentVariables: Any!) -> XcodeSchemeActionResult // Invoke the "run" scheme action. This command should be sent to a workspace document. The run action will be performed using the workspace document's current active scheme and active run destination. This command does not wait for the action to complete; its progress can be tracked with the returned scheme action result.
    @objc optional func testWithCommandLineArguments(_ withCommandLineArguments: Any!, withEnvironmentVariables: Any!) -> XcodeSchemeActionResult // Invoke the "test" scheme action. This command should be sent to a workspace document. The test action will be performed using the workspace document's current active scheme and active run destination. This command does not wait for the action to complete; its progress can be tracked with the returned scheme action result.
    @objc optional func attachToProcessIdentifier(_ toProcessIdentifier: Int, suspended: Bool) // Start a new debugging session in the workspace. This command should be sent to a workspace document. This command does not wait for the action to complete.
    @objc optional func debugScheme(_ scheme: String!, runDestinationSpecifier: String!, skipBuilding: Bool, commandLineArguments: Any!, environmentVariables: Any!) -> XcodeSchemeActionResult // Start a debugging session using the "run" or "run without building" scheme action. This command should be sent to a workspace document. If no scheme is specified, the action will be performed using the workspace document's current active scheme. If no run destination is specified, the active run destination will be used. This command does not wait for the action to complete; its progress can be tracked with the returned scheme action result.
}

// MARK: XcodeApplication
@objc public protocol XcodeApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional var activeWorkspaceDocument: XcodeWorkspaceDocument { get } // The active workspace document in Xcode.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func quitSaving(_ saving: XcodeSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func createTemporaryDebuggingWorkspace() -> XcodeWorkspaceDocument // Create a new temporary debugging workspace.
    @objc optional func fileDocuments() -> SBElementArray
    @objc optional func sourceDocuments() -> SBElementArray
    @objc optional func workspaceDocuments() -> SBElementArray
}
extension SBApplication: XcodeApplication {}

// MARK: XcodeDocument
@objc public protocol XcodeDocument: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
    @objc optional var path: String { get } // The document's path.
}
extension SBObject: XcodeDocument {}

// MARK: XcodeWindow
@objc public protocol XcodeWindow: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get } // The title of the window.
    @objc optional var index: Int { get } // The index of the window, ordered front to back.
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Does the window have a close button?
    @objc optional var miniaturizable: Bool { get } // Does the window have a minimize button?
    @objc optional var miniaturized: Bool { get } // Is the window minimized right now?
    @objc optional var resizable: Bool { get } // Can the window be resized?
    @objc optional var visible: Bool { get } // Is the window visible right now?
    @objc optional var zoomable: Bool { get } // Does the window have a zoom button?
    @objc optional var zoomed: Bool { get } // Is the window zoomed right now?
    @objc optional var document: XcodeDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: XcodeWindow {}

// MARK: XcodeFileDocument
@objc public protocol XcodeFileDocument: XcodeDocument {
}
extension SBObject: XcodeFileDocument {}

// MARK: XcodeTextDocument
@objc public protocol XcodeTextDocument: XcodeFileDocument {
    @objc optional var selectedCharacterRange: [Any] { get } // The first and last character positions in the selection.
    @objc optional var selectedParagraphRange: [Any] { get } // The first and last paragraph positions that contain the selection.
    @objc optional var text: String { get } // The text of the text file referenced.
    @objc optional var notifiesWhenClosing: Bool { get } // Should Xcode notify other apps when this document is closed?
}
extension SBObject: XcodeTextDocument {}

// MARK: XcodeSourceDocument
@objc public protocol XcodeSourceDocument: XcodeTextDocument {
}
extension SBObject: XcodeSourceDocument {}

// MARK: XcodeWorkspaceDocument
@objc public protocol XcodeWorkspaceDocument: XcodeDocument {
    @objc optional var loaded: Bool { get } // Whether the workspace document has finsished loading after being opened. Messages sent to a workspace document before it has loaded will result in errors.
    @objc optional var activeScheme: XcodeScheme { get } // The workspace's scheme that will be used for scheme actions.
    @objc optional var activeRunDestination: XcodeRunDestination { get } // The workspace's run destination that will be used for scheme actions.
    @objc optional var lastSchemeActionResult: XcodeSchemeActionResult { get } // The scheme action result for the last scheme action command issued to the workspace document.
    @objc optional var file: URL { get } // The workspace document's location on disk, if it has one.
    @objc optional func projects() -> SBElementArray
    @objc optional func schemes() -> SBElementArray
    @objc optional func runDestinations() -> SBElementArray
}
extension SBObject: XcodeWorkspaceDocument {}

// MARK: XcodeSchemeActionResult
@objc public protocol XcodeSchemeActionResult: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var completed: Bool { get } // Whether this scheme action has completed (sucessfully or otherwise) or not.
    @objc optional var status: XcodeSchemeActionResultStatus { get } // Indicates the status of the scheme action.
    @objc optional var errorMessage: String { get } // If the result's status is "error occurred", this will be the error message; otherwise, this will be "missing value".
    @objc optional var buildLog: String { get } // If this scheme action performed a build, this will be the text of the build log.
    @objc optional func buildErrors() -> SBElementArray
    @objc optional func buildWarnings() -> SBElementArray
    @objc optional func analyzerIssues() -> SBElementArray
    @objc optional func testFailures() -> SBElementArray
    @objc optional func id() -> String // The unique identifier for the scheme.
}
extension SBObject: XcodeSchemeActionResult {}

// MARK: XcodeSchemeActionIssue
@objc public protocol XcodeSchemeActionIssue: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var message: String { get } // The text of the issue.
    @objc optional var filePath: String { get } // The file path where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
    @objc optional var startingLineNumber: Int { get } // The starting line number in the file where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
    @objc optional var endingLineNumber: Int { get } // The ending line number in the file where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
    @objc optional var startingColumnNumber: Int { get } // The starting column number in the file where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
    @objc optional var endingColumnNumber: Int { get } // The ending column number in the file where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
}
extension SBObject: XcodeSchemeActionIssue {}

// MARK: XcodeBuildError
@objc public protocol XcodeBuildError: XcodeSchemeActionIssue {
}
extension SBObject: XcodeBuildError {}

// MARK: XcodeBuildWarning
@objc public protocol XcodeBuildWarning: XcodeSchemeActionIssue {
}
extension SBObject: XcodeBuildWarning {}

// MARK: XcodeAnalyzerIssue
@objc public protocol XcodeAnalyzerIssue: XcodeSchemeActionIssue {
}
extension SBObject: XcodeAnalyzerIssue {}

// MARK: XcodeTestFailure
@objc public protocol XcodeTestFailure: XcodeSchemeActionIssue {
}
extension SBObject: XcodeTestFailure {}

// MARK: XcodeScheme
@objc public protocol XcodeScheme: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get } // The name of the scheme.
    @objc optional func id() -> String // The unique identifier for the scheme.
}
extension SBObject: XcodeScheme {}

// MARK: XcodeRunDestination
@objc public protocol XcodeRunDestination: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get } // The name of the run destination, as displayed in Xcode's interface.
    @objc optional var architecture: String { get } // The architecture for which this run destination results in execution.
    @objc optional var platform: String { get } // The identifier of the platform which this run destination targets, such as "macosx", "iphoneos", "iphonesimulator", etc .
    @objc optional var device: XcodeDevice { get } // The physical or virtual device which this run destination targets.
    @objc optional var companionDevice: XcodeDevice { get } // If the run destination's device has a companion (e.g. a paired watch for a phone) which it will use, this is that device.
}
extension SBObject: XcodeRunDestination {}

// MARK: XcodeDevice
@objc public protocol XcodeDevice: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get } // The name of the device.
    @objc optional var deviceIdentifier: String { get } // A stable identifier for the device, as shown in Xcode's "Devices" window.
    @objc optional var operatingSystemVersion: String { get } // The version of the operating system installed on the device which this run destination targets.
    @objc optional var deviceModel: String { get } // The model of device (e.g. "iPad Air") which this run destination targets.
    @objc optional var generic: Bool { get } // Whether this run destination is generic instead of representing a specific device. Most destinations are not generic, but a generic destination (such as "Any iOS Device") will be available for some platforms if no physical devices are connected.
}
extension SBObject: XcodeDevice {}

// MARK: XcodeBuildConfiguration
@objc public protocol XcodeBuildConfiguration: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get } // The name of the build configuration.
    @objc optional func buildSettings() -> SBElementArray
    @objc optional func resolvedBuildSettings() -> SBElementArray
    @objc optional func id() -> String // The unique identifier for the build configuration.
}
extension SBObject: XcodeBuildConfiguration {}

// MARK: XcodeProject
@objc public protocol XcodeProject: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get } // The name of the project
    @objc optional func buildConfigurations() -> SBElementArray
    @objc optional func targets() -> SBElementArray
    @objc optional func id() -> String // The unique identifier for the project.
}
extension SBObject: XcodeProject {}

// MARK: XcodeBuildSetting
@objc public protocol XcodeBuildSetting: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get } // The unlocalized build setting name (e.g. DSTROOT).
    @objc optional var value: String { get } // A string value for the build setting.
}
extension SBObject: XcodeBuildSetting {}

// MARK: XcodeResolvedBuildSetting
@objc public protocol XcodeResolvedBuildSetting: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get } // The unlocalized build setting name (e.g. DSTROOT).
    @objc optional var value: String { get } // A string value for the build setting.
}
extension SBObject: XcodeResolvedBuildSetting {}

// MARK: XcodeTarget
@objc public protocol XcodeTarget: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: String { get } // The name of this target.
    @objc optional var project: XcodeProject { get } // The project that contains this target
    @objc optional func buildConfigurations() -> SBElementArray
    @objc optional func id() -> String // The unique identifier for the target.
}
extension SBObject: XcodeTarget {}

