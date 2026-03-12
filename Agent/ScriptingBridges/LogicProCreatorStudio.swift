// MARK: LogicProCreatorStudioSavo
@objc public enum LogicProCreatorStudioSavo : AEKeyword {
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case yes = 0x79657320 /* Save the file. */
}

// MARK: LogicProCreatorStudioEnum
@objc public enum LogicProCreatorStudioEnum : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: LogicProCreatorStudioGenericMethods
@objc public protocol LogicProCreatorStudioGenericMethods {
    @objc optional func closeSaving(_ saving: LogicProCreatorStudioSavo, savingIn: URL!) // Close an object.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy object(s) and put the copies at a new location.
    @objc optional func exists() -> Bool // Verify if an object exists.
    @objc optional func moveTo(_ to: SBObject!) // Move object(s) to a new location.
    @objc optional func saveAs(_ `as`: String!, `in`: URL!) // Save an object.
}

// MARK: LogicProCreatorStudioItem
@objc public protocol LogicProCreatorStudioItem: SBObjectProtocol, LogicProCreatorStudioGenericMethods {
    @objc optional var properties: [AnyHashable : Any] { get } // All of the object's properties.
}
extension SBObject: LogicProCreatorStudioItem {}

// MARK: LogicProCreatorStudioApplication
@objc public protocol LogicProCreatorStudioApplication: SBApplicationProtocol {
    @objc optional var frontmost: Bool { get } // Is this the frontmost (active) application?
    @objc optional var name: String { get } // The name of the application.
    @objc optional var version: String { get } // The version of the application.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: URL!) -> LogicProCreatorStudioDocument // Open an object.
    @objc optional func print(_ x: URL!, printDialog: Bool, withProperties: LogicProCreatorStudioPrintSettings!) // Print an object.
    @objc optional func quitSaving(_ saving: LogicProCreatorStudioSavo) // Quit an application.
}
extension SBApplication: LogicProCreatorStudioApplication {}

// MARK: LogicProCreatorStudioColor
@objc public protocol LogicProCreatorStudioColor: LogicProCreatorStudioItem {
}
extension SBObject: LogicProCreatorStudioColor {}

// MARK: LogicProCreatorStudioDocument
@objc public protocol LogicProCreatorStudioDocument: LogicProCreatorStudioItem {
    @objc optional var modified: Bool { get } // Has the document been modified since the last save?
    @objc optional var name: String { get } // The document's name.
    @objc optional var path: String { get } // The document's path.
}
extension SBObject: LogicProCreatorStudioDocument {}

// MARK: LogicProCreatorStudioWindow
@objc public protocol LogicProCreatorStudioWindow: LogicProCreatorStudioItem {
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Whether the window has a close box.
    @objc optional var document: LogicProCreatorStudioDocument { get } // The document whose contents are being displayed in the window.
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
extension SBObject: LogicProCreatorStudioWindow {}

// MARK: LogicProCreatorStudioAttributeRun
@objc public protocol LogicProCreatorStudioAttributeRun: LogicProCreatorStudioItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: LogicProCreatorStudioAttributeRun {}

// MARK: LogicProCreatorStudioCharacter
@objc public protocol LogicProCreatorStudioCharacter: LogicProCreatorStudioItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: LogicProCreatorStudioCharacter {}

// MARK: LogicProCreatorStudioParagraph
@objc public protocol LogicProCreatorStudioParagraph: LogicProCreatorStudioItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: LogicProCreatorStudioParagraph {}

// MARK: LogicProCreatorStudioText
@objc public protocol LogicProCreatorStudioText: LogicProCreatorStudioItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: LogicProCreatorStudioText {}

// MARK: LogicProCreatorStudioAttachment
@objc public protocol LogicProCreatorStudioAttachment: LogicProCreatorStudioText {
    @objc optional var fileName: String { get } // The path to the file for the attachment
}
extension SBObject: LogicProCreatorStudioAttachment {}

// MARK: LogicProCreatorStudioWord
@objc public protocol LogicProCreatorStudioWord: LogicProCreatorStudioItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: LogicProCreatorStudioWord {}

// MARK: LogicProCreatorStudioPrintSettings
@objc public protocol LogicProCreatorStudioPrintSettings: SBObjectProtocol, LogicProCreatorStudioGenericMethods {
    @objc optional var copies: Int { get } // the number of copies of a document to be printed
    @objc optional var collating: Bool { get } // Should printed copies be collated?
    @objc optional var startingPage: Int { get } // the first page of the document to be printed
    @objc optional var endingPage: Int { get } // the last page of the document to be printed
    @objc optional var pagesAcross: Int { get } // number of logical pages laid across a physical page
    @objc optional var pagesDown: Int { get } // number of logical pages laid out down a physical page
    @objc optional var requestedPrintTime: Date { get } // the time at which the desktop printer should print the document
    @objc optional var errorHandling: LogicProCreatorStudioEnum { get } // how errors are handled
    @objc optional var faxNumber: String { get } // for fax number
    @objc optional var targetPrinter: String { get } // for target printer
}
extension SBObject: LogicProCreatorStudioPrintSettings {}

