@_exported import ScriptingBridgeCommon

// MARK: AutomatorSavo
@objc public enum AutomatorSavo : AEKeyword {
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case yes = 0x79657320 /* Save the file. */
}

// MARK: AutomatorWlev
@objc public enum AutomatorWlev : AEKeyword {
    case irreversible = 0x69727276 /* irreversible */
    case none = 0x6e6f6e65 /* none */
    case reversible = 0x7276626c /* reversible */
}

// MARK: AutomatorEnum
@objc public enum AutomatorEnum : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: AutomatorGenericMethods
@objc public protocol AutomatorGenericMethods {
    @objc optional func closeSaving(_ saving: AutomatorSavo, savingIn: URL!) // Close an object.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy object(s) and put the copies at a new location.
    @objc optional func exists() -> Bool // Verify if an object exists.
    @objc optional func moveTo(_ to: SBObject!) // Move object(s) to a new location.
    @objc optional func saveAs(_ `as`: String!, `in`: URL!) // Save an object.
}

// MARK: AutomatorItem
@objc public protocol AutomatorItem: SBObjectProtocol, AutomatorGenericMethods {
    @objc optional var properties: [AnyHashable : Any] { get } // All of the object's properties.
}
extension SBObject: AutomatorItem {}

// MARK: AutomatorApplication
@objc public protocol AutomatorApplication: SBApplicationProtocol {
    @objc optional var frontmost: Bool { get } // Is this the frontmost (active) application?
    @objc optional var name: String { get } // The name of the application.
    @objc optional var version: String { get } // The version of the application.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: URL!) -> AutomatorDocument // Open an object.
    @objc optional func print(_ x: URL!, printDialog: Bool, withProperties: AutomatorPrintSettings!) // Print an object.
    @objc optional func quitSaving(_ saving: AutomatorSavo) // Quit an application.
    @objc optional func add(_ x: Any!, to: AutomatorWorkflow!, atIndex: Int) // Add an Automator action or variable to a workflow
    @objc optional func remove(_ x: Any!) // Remove an Automator action or variable from a workflow
    @objc optional func AutomatorActions() -> SBElementArray
    @objc optional func variables() -> SBElementArray
    @objc optional func workflows() -> SBElementArray
}
extension SBApplication: AutomatorApplication {}

// MARK: AutomatorColor
@objc public protocol AutomatorColor: AutomatorItem {
}
extension SBObject: AutomatorColor {}

// MARK: AutomatorDocument
@objc public protocol AutomatorDocument: AutomatorItem {
    @objc optional var modified: Bool { get } // Has the document been modified since the last save?
    @objc optional var name: String { get } // The document's name.
    @objc optional var path: String { get } // The document's path.
}
extension SBObject: AutomatorDocument {}

// MARK: AutomatorWindow
@objc public protocol AutomatorWindow: AutomatorItem {
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Whether the window has a close box.
    @objc optional var document: AutomatorDocument { get } // The document whose contents are being displayed in the window.
    @objc optional var floating: Bool { get } // Whether the window floats.
    @objc optional var index: Int { get } // The index of the window, ordered front to back.
    @objc optional var miniaturizable: Bool { get } // Whether the window can be miniaturized.
    @objc optional var miniaturized: Bool { get } // Whether the window is currently miniaturized.
    @objc optional var modal: Bool { get } // Whether the window is the application's current modal window.
    @objc optional var name: String { get } // The full title of the window.
    @objc optional var resizable: Bool { get } // Whether the window can be resized.
    @objc optional var titled: Bool { get } // Whether the window has a title bar.
    @objc optional var visible: Bool { get } // Whether the window is currently visible.
    @objc optional var zoomable: Bool { get } // Whether the window can be zoomed.
    @objc optional var zoomed: Bool { get } // Whether the window is currently zoomed.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: AutomatorWindow {}

// MARK: AutomatorAttributeRun
@objc public protocol AutomatorAttributeRun: AutomatorItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AutomatorAttributeRun {}

// MARK: AutomatorCharacter
@objc public protocol AutomatorCharacter: AutomatorItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AutomatorCharacter {}

// MARK: AutomatorParagraph
@objc public protocol AutomatorParagraph: AutomatorItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AutomatorParagraph {}

// MARK: AutomatorText
@objc public protocol AutomatorText: AutomatorItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AutomatorText {}

// MARK: AutomatorAttachment
@objc public protocol AutomatorAttachment: AutomatorText {
    @objc optional var fileName: String { get } // The path to the file for the attachment
}
extension SBObject: AutomatorAttachment {}

// MARK: AutomatorWord
@objc public protocol AutomatorWord: AutomatorItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AutomatorWord {}

// MARK: AutomatorAutomatorAction
@objc public protocol AutomatorAutomatorAction: AutomatorItem {
    @objc optional var bundleId: String { get } // The bundle identifier for the action
    @objc optional var category: [Any] { get } // The category that contains the action
    @objc optional var comment: String { get } // The comment for the name of the action
    @objc optional var enabled: Bool { get } // Is the action enabled?
    @objc optional var executionErrorMessage: String { get } // The text error message generated by execution of the action
    @objc optional var executionErrorNumber: Int { get } // The numeric error code generated by execution of the action
    @objc optional var executionResult: Any { get } // The result of the action, passed as input to the next action
    @objc optional var iconName: String { get } // The icon name of the action
    @objc optional var ignoresInput: Bool { get } // Shall the action ignore its input when it is run?
    @objc optional var index: Int { get } // The index of the action
    @objc optional var inputTypes: [Any] { get } // The input types accepted by the action
    @objc optional var keywords: [Any] { get } // The keywords that describe the action
    @objc optional var name: String { get } // The localized name of the action
    @objc optional var outputTypes: [Any] { get } // The output types produced by the action
    @objc optional var parentWorkflow: AutomatorWorkflow { get } // The workflow that contains the action
    @objc optional var path: URL { get } // The path of the file that contains the action
    @objc optional var showActionWhenRun: Bool { get } // Shall the action show its user interface when it is run?
    @objc optional var targetApplication: [Any] { get } // The application with which the action communicates
    @objc optional var version: String { get } // The version of the action
    @objc optional var warningAction: String { get } // The action suggested by the warning, if any
    @objc optional var warningLevel: AutomatorWlev { get } // The level of the warning, increasing in likelihood of data loss
    @objc optional var warningMessage: String { get } // The message that accompanies the warning, if any
    @objc optional func requiredResources() -> SBElementArray
    @objc optional func settings() -> SBElementArray
    @objc optional func id() -> String // The unique identifier for the action
}
extension SBObject: AutomatorAutomatorAction {}

// MARK: AutomatorRequiredResource
@objc public protocol AutomatorRequiredResource: AutomatorItem {
    @objc optional var kind: String { get } // The kind of required resource
    @objc optional var name: String { get } // The name of the required resource
    @objc optional var resource: String { get } // The specification of the required resource
    @objc optional var version: Int { get } // The minimum acceptable version of the required resource
}
extension SBObject: AutomatorRequiredResource {}

// MARK: AutomatorSetting
@objc public protocol AutomatorSetting: AutomatorItem {
    @objc optional var defaultValue: Any { get } // The default value of the setting
    @objc optional var name: String { get } // The name of the setting
    @objc optional var value: Any { get } // The value of the setting
}
extension SBObject: AutomatorSetting {}

// MARK: AutomatorVariable
@objc public protocol AutomatorVariable: AutomatorItem {
    @objc optional var name: String { get } // The name of the variable
    @objc optional var settable: Bool { get } // Are the name and value of the variable settable?
    @objc optional var value: Any { get } // The value of the variable
}
extension SBObject: AutomatorVariable {}

// MARK: AutomatorWorkflow
@objc public protocol AutomatorWorkflow: AutomatorDocument {
    @objc optional var currentAction: AutomatorAutomatorAction { get } // The current or most recent action of the workflow
    @objc optional var executionErrorMessage: String { get } // The text error message generated by the most recent execution
    @objc optional var executionErrorNumber: Int { get } // The numeric error code generated by the most recent execution
    @objc optional var executionId: String { get } // The identifier of the current or most recent execution
    @objc optional var executionResult: Any { get } // The result of the most recent execution; the output of the last action of that execution
    @objc optional var name: String { get } // The name of the workflow
    @objc optional func AutomatorActions() -> SBElementArray
    @objc optional func variables() -> SBElementArray
    @objc optional func execute() -> Any // Execute the workflow
}
extension SBObject: AutomatorWorkflow {}

// MARK: AutomatorPrintSettings
@objc public protocol AutomatorPrintSettings: SBObjectProtocol, AutomatorGenericMethods {
    @objc optional var copies: Int { get } // the number of copies of a document to be printed
    @objc optional var collating: Bool { get } // Should printed copies be collated?
    @objc optional var startingPage: Int { get } // the first page of the document to be printed
    @objc optional var endingPage: Int { get } // the last page of the document to be printed
    @objc optional var pagesAcross: Int { get } // number of logical pages laid across a physical page
    @objc optional var pagesDown: Int { get } // number of logical pages laid out down a physical page
    @objc optional var requestedPrintTime: Date { get } // the time at which the desktop printer should print the document
    @objc optional var errorHandling: AutomatorEnum { get } // how errors are handled
    @objc optional var faxNumber: String { get } // for fax number
    @objc optional var targetPrinter: String { get } // for target printer
}
extension SBObject: AutomatorPrintSettings {}

