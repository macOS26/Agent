
// MARK: DeveloperSavo
@objc public enum DeveloperSavo : AEKeyword {
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case yes = 0x79657320 /* Save the file. */
}

// MARK: DeveloperEnum
@objc public enum DeveloperEnum : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: DeveloperGenericMethods
@objc public protocol DeveloperGenericMethods {
    @objc optional func closeSaving(_ saving: DeveloperSavo, savingIn: URL!) // Close an object.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy object(s) and put the copies at a new location.
    @objc optional func exists() -> Bool // Verify if an object exists.
    @objc optional func moveTo(_ to: SBObject!) // Move object(s) to a new location.
    @objc optional func saveAs(_ `as`: String!, `in`: URL!) // Save an object.
}

// MARK: DeveloperItem
@objc public protocol DeveloperItem: SBObjectProtocol, DeveloperGenericMethods {
    @objc optional var properties: [AnyHashable : Any] { get } // All of the object's properties.
}
extension SBObject: DeveloperItem {}

// MARK: DeveloperApplication
@objc public protocol DeveloperApplication: SBApplicationProtocol {
    @objc optional var frontmost: Bool { get } // Is this the frontmost (active) application?
    @objc optional var name: String { get } // The name of the application.
    @objc optional var version: String { get } // The version of the application.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: URL!) -> DeveloperDocument // Open an object.
    @objc optional func print(_ x: URL!, printDialog: Bool, withProperties: DeveloperPrintSettings!) // Print an object.
    @objc optional func quitSaving(_ saving: DeveloperSavo) // Quit an application.
}
extension SBApplication: DeveloperApplication {}

// MARK: DeveloperColor
@objc public protocol DeveloperColor: DeveloperItem {
}
extension SBObject: DeveloperColor {}

// MARK: DeveloperDocument
@objc public protocol DeveloperDocument: DeveloperItem {
    @objc optional var modified: Bool { get } // Has the document been modified since the last save?
    @objc optional var name: String { get } // The document's name.
    @objc optional var path: String { get } // The document's path.
}
extension SBObject: DeveloperDocument {}

// MARK: DeveloperWindow
@objc public protocol DeveloperWindow: DeveloperItem {
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Whether the window has a close box.
    @objc optional var document: DeveloperDocument { get } // The document whose contents are being displayed in the window.
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
extension SBObject: DeveloperWindow {}

// MARK: DeveloperAttributeRun
@objc public protocol DeveloperAttributeRun: DeveloperItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: DeveloperAttributeRun {}

// MARK: DeveloperCharacter
@objc public protocol DeveloperCharacter: DeveloperItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: DeveloperCharacter {}

// MARK: DeveloperParagraph
@objc public protocol DeveloperParagraph: DeveloperItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: DeveloperParagraph {}

// MARK: DeveloperText
@objc public protocol DeveloperText: DeveloperItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: DeveloperText {}

// MARK: DeveloperAttachment
@objc public protocol DeveloperAttachment: DeveloperText {
    @objc optional var fileName: String { get } // The path to the file for the attachment
}
extension SBObject: DeveloperAttachment {}

// MARK: DeveloperWord
@objc public protocol DeveloperWord: DeveloperItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: DeveloperWord {}

// MARK: DeveloperPrintSettings
@objc public protocol DeveloperPrintSettings: SBObjectProtocol, DeveloperGenericMethods {
    @objc optional var copies: Int { get } // the number of copies of a document to be printed
    @objc optional var collating: Bool { get } // Should printed copies be collated?
    @objc optional var startingPage: Int { get } // the first page of the document to be printed
    @objc optional var endingPage: Int { get } // the last page of the document to be printed
    @objc optional var pagesAcross: Int { get } // number of logical pages laid across a physical page
    @objc optional var pagesDown: Int { get } // number of logical pages laid out down a physical page
    @objc optional var requestedPrintTime: Date { get } // the time at which the desktop printer should print the document
    @objc optional var errorHandling: DeveloperEnum { get } // how errors are handled
    @objc optional var faxNumber: String { get } // for fax number
    @objc optional var targetPrinter: String { get } // for target printer
}
extension SBObject: DeveloperPrintSettings {}

