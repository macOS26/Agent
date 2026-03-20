
// MARK: DatabaseEventsSavo
@objc public enum DatabaseEventsSavo : AEKeyword {
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case yes = 0x79657320 /* Save the file. */
}

// MARK: DatabaseEventsStty
@objc public enum DatabaseEventsStty : AEKeyword {
    case binary = 0x62696e20 /* binary store type */
    case memory = 0x6d656d20 /* memory store type */
    case sqLite = 0x73716c74 /* SQLite store type */
    case xml = 0x786d6c20 /* XML store type */
}

// MARK: DatabaseEventsEnum
@objc public enum DatabaseEventsEnum : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: DatabaseEventsGenericMethods
@objc public protocol DatabaseEventsGenericMethods {
    @objc optional func closeSaving(_ saving: DatabaseEventsSavo, savingIn: URL!) // Close an object.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: DatabaseEventsRecord!) // Copy object(s) and put the copies at a new location.
    @objc optional func exists() -> Bool // Verify if an object exists.
    @objc optional func moveTo(_ to: SBObject!) // Move object(s) to a new location.
    @objc optional func saveAs(_ `as`: String!, `in`: URL!) // Save an object.
}

// MARK: DatabaseEventsItem
@objc public protocol DatabaseEventsItem: SBObjectProtocol, DatabaseEventsGenericMethods {
    @objc optional var properties: DatabaseEventsRecord { get } // All of the object's properties.
}
extension SBObject: DatabaseEventsItem {}

// MARK: DatabaseEventsApplication
@objc public protocol DatabaseEventsApplication: SBApplicationProtocol {
    @objc optional var frontmost: Bool { get } // Is this the frontmost (active) application?
    @objc optional var name: String { get } // The name of the application.
    @objc optional var version: String { get } // The version of the application.
    @objc optional var quitDelay: Int { get } // the time in seconds the application will idle before quitting; if set to zero, idle time will not cause the application to quit
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: URL!) -> DatabaseEventsDocument // Open an object.
    @objc optional func print(_ x: URL!, printDialog: Bool, withProperties: DatabaseEventsPrintSettings!) // Print an object.
    @objc optional func quitSaving(_ saving: DatabaseEventsSavo) // Quit an application.
    @objc optional func databases() -> SBElementArray
}
extension SBApplication: DatabaseEventsApplication {}

// MARK: DatabaseEventsColor
@objc public protocol DatabaseEventsColor: DatabaseEventsItem {
}
extension SBObject: DatabaseEventsColor {}

// MARK: DatabaseEventsDocument
@objc public protocol DatabaseEventsDocument: DatabaseEventsItem {
    @objc optional var modified: Bool { get } // Has the document been modified since the last save?
    @objc optional var name: String { get } // The document's name.
    @objc optional var path: String { get } // The document's path.
}
extension SBObject: DatabaseEventsDocument {}

// MARK: DatabaseEventsWindow
@objc public protocol DatabaseEventsWindow: DatabaseEventsItem {
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Whether the window has a close box.
    @objc optional var document: DatabaseEventsDocument { get } // The document whose contents are being displayed in the window.
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
extension SBObject: DatabaseEventsWindow {}

// MARK: DatabaseEventsAttributeRun
@objc public protocol DatabaseEventsAttributeRun: DatabaseEventsItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: DatabaseEventsAttributeRun {}

// MARK: DatabaseEventsCharacter
@objc public protocol DatabaseEventsCharacter: DatabaseEventsItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: DatabaseEventsCharacter {}

// MARK: DatabaseEventsParagraph
@objc public protocol DatabaseEventsParagraph: DatabaseEventsItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: DatabaseEventsParagraph {}

// MARK: DatabaseEventsText
@objc public protocol DatabaseEventsText: DatabaseEventsItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: DatabaseEventsText {}

// MARK: DatabaseEventsAttachment
@objc public protocol DatabaseEventsAttachment: DatabaseEventsText {
    @objc optional var fileName: String { get } // The path to the file for the attachment
}
extension SBObject: DatabaseEventsAttachment {}

// MARK: DatabaseEventsWord
@objc public protocol DatabaseEventsWord: DatabaseEventsItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: DatabaseEventsWord {}

// MARK: DatabaseEventsDatabase
@objc public protocol DatabaseEventsDatabase: DatabaseEventsItem {
    @objc optional var location: URL { get } // the folder that contains the database
    @objc optional var name: String { get } // the name of the database
    @objc optional var storeType: DatabaseEventsStty { get } // the type of storage used by the database; may be specified upon creation, but not thereafter; defaults to SQLite
    @objc optional func records() -> SBElementArray
}
extension SBObject: DatabaseEventsDatabase {}

// MARK: DatabaseEventsField
@objc public protocol DatabaseEventsField: DatabaseEventsItem {
    @objc optional var name: String { get } // the name of the field
    @objc optional var value: Any { get } // the value of the field
    @objc optional func id() -> Int // the unique id of the field
}
extension SBObject: DatabaseEventsField {}

// MARK: DatabaseEventsRecord
@objc public protocol DatabaseEventsRecord: DatabaseEventsItem {
    @objc optional var name: String { get } // the name of the record, equivalent to the value of the field named "name"
    @objc optional func fields() -> SBElementArray
    @objc optional func id() -> Int // the unique id of the record
}
extension SBObject: DatabaseEventsRecord {}

// MARK: DatabaseEventsPrintSettings
@objc public protocol DatabaseEventsPrintSettings: SBObjectProtocol, DatabaseEventsGenericMethods {
    @objc optional var copies: Int { get } // the number of copies of a document to be printed
    @objc optional var collating: Bool { get } // Should printed copies be collated?
    @objc optional var startingPage: Int { get } // the first page of the document to be printed
    @objc optional var endingPage: Int { get } // the last page of the document to be printed
    @objc optional var pagesAcross: Int { get } // number of logical pages laid across a physical page
    @objc optional var pagesDown: Int { get } // number of logical pages laid out down a physical page
    @objc optional var requestedPrintTime: Date { get } // the time at which the desktop printer should print the document
    @objc optional var errorHandling: DatabaseEventsEnum { get } // how errors are handled
    @objc optional var faxNumber: String { get } // for fax number
    @objc optional var targetPrinter: String { get } // for target printer
}
extension SBObject: DatabaseEventsPrintSettings {}

