
// MARK: AutomatorApplicationStubSavo
@objc public enum AutomatorApplicationStubSavo : AEKeyword {
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case yes = 0x79657320 /* Save the file. */
}

// MARK: AutomatorApplicationStubEnum
@objc public enum AutomatorApplicationStubEnum : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: AutomatorApplicationStubGenericMethods
@objc public protocol AutomatorApplicationStubGenericMethods {
    @objc optional func closeSaving(_ saving: AutomatorApplicationStubSavo, savingIn: URL!) // Close an object.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy object(s) and put the copies at a new location.
    @objc optional func exists() -> Bool // Verify if an object exists.
    @objc optional func moveTo(_ to: SBObject!) // Move object(s) to a new location.
    @objc optional func saveAs(_ `as`: String!, `in`: URL!) // Save an object.
}

// MARK: AutomatorApplicationStubItem
@objc public protocol AutomatorApplicationStubItem: SBObjectProtocol, AutomatorApplicationStubGenericMethods {
    @objc optional var properties: [AnyHashable : Any] { get } // All of the object's properties.
}
extension SBObject: AutomatorApplicationStubItem {}

// MARK: AutomatorApplicationStubApplication
@objc public protocol AutomatorApplicationStubApplication: SBApplicationProtocol {
    @objc optional var frontmost: Bool { get } // Is this the frontmost (active) application?
    @objc optional var name: String { get } // The name of the application.
    @objc optional var version: String { get } // The version of the application.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: URL!) -> AutomatorApplicationStubDocument // Open an object.
    @objc optional func print(_ x: URL!, printDialog: Bool, withProperties: AutomatorApplicationStubPrintSettings!) // Print an object.
    @objc optional func quitSaving(_ saving: AutomatorApplicationStubSavo) // Quit an application.
}
extension SBApplication: AutomatorApplicationStubApplication {}

// MARK: AutomatorApplicationStubColor
@objc public protocol AutomatorApplicationStubColor: AutomatorApplicationStubItem {
}
extension SBObject: AutomatorApplicationStubColor {}

// MARK: AutomatorApplicationStubDocument
@objc public protocol AutomatorApplicationStubDocument: AutomatorApplicationStubItem {
    @objc optional var modified: Bool { get } // Has the document been modified since the last save?
    @objc optional var name: String { get } // The document's name.
    @objc optional var path: String { get } // The document's path.
}
extension SBObject: AutomatorApplicationStubDocument {}

// MARK: AutomatorApplicationStubWindow
@objc public protocol AutomatorApplicationStubWindow: AutomatorApplicationStubItem {
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Whether the window has a close box.
    @objc optional var document: AutomatorApplicationStubDocument { get } // The document whose contents are being displayed in the window.
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
extension SBObject: AutomatorApplicationStubWindow {}

// MARK: AutomatorApplicationStubAttributeRun
@objc public protocol AutomatorApplicationStubAttributeRun: AutomatorApplicationStubItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AutomatorApplicationStubAttributeRun {}

// MARK: AutomatorApplicationStubCharacter
@objc public protocol AutomatorApplicationStubCharacter: AutomatorApplicationStubItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AutomatorApplicationStubCharacter {}

// MARK: AutomatorApplicationStubParagraph
@objc public protocol AutomatorApplicationStubParagraph: AutomatorApplicationStubItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AutomatorApplicationStubParagraph {}

// MARK: AutomatorApplicationStubText
@objc public protocol AutomatorApplicationStubText: AutomatorApplicationStubItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AutomatorApplicationStubText {}

// MARK: AutomatorApplicationStubAttachment
@objc public protocol AutomatorApplicationStubAttachment: AutomatorApplicationStubText {
    @objc optional var fileName: String { get } // The path to the file for the attachment
}
extension SBObject: AutomatorApplicationStubAttachment {}

// MARK: AutomatorApplicationStubWord
@objc public protocol AutomatorApplicationStubWord: AutomatorApplicationStubItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AutomatorApplicationStubWord {}

// MARK: AutomatorApplicationStubPrintSettings
@objc public protocol AutomatorApplicationStubPrintSettings: SBObjectProtocol, AutomatorApplicationStubGenericMethods {
    @objc optional var copies: Int { get } // the number of copies of a document to be printed
    @objc optional var collating: Bool { get } // Should printed copies be collated?
    @objc optional var startingPage: Int { get } // the first page of the document to be printed
    @objc optional var endingPage: Int { get } // the last page of the document to be printed
    @objc optional var pagesAcross: Int { get } // number of logical pages laid across a physical page
    @objc optional var pagesDown: Int { get } // number of logical pages laid out down a physical page
    @objc optional var requestedPrintTime: Date { get } // the time at which the desktop printer should print the document
    @objc optional var errorHandling: AutomatorApplicationStubEnum { get } // how errors are handled
    @objc optional var faxNumber: String { get } // for fax number
    @objc optional var targetPrinter: String { get } // for target printer
}
extension SBObject: AutomatorApplicationStubPrintSettings {}
