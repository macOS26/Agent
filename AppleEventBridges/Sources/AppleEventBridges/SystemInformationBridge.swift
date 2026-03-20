
// MARK: SystemInformationSavo
@objc public enum SystemInformationSavo : AEKeyword {
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case yes = 0x79657320 /* Save the file. */
}

// MARK: SystemInformationEdtl
@objc public enum SystemInformationEdtl : AEKeyword {
    case basic = 0x62617369 /* A version which includes the basic hardware, software and network information. Moderate in size. */
    case full = 0x66756c6c /* A profile which includes all available information - can be quite large */
    case mini = 0x6d696e69 /* A compact profile which does not include any personal identifying information */
}

// MARK: SystemInformationEnum
@objc public enum SystemInformationEnum : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: SystemInformationGenericMethods
@objc public protocol SystemInformationGenericMethods {
    @objc optional func closeSaving(_ saving: SystemInformationSavo, savingIn: URL!) // Close an object.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy object(s) and put the copies at a new location.
    @objc optional func exists() -> Bool // Verify if an object exists.
    @objc optional func moveTo(_ to: SBObject!) // Move object(s) to a new location.
    @objc optional func saveAs(_ `as`: String!, `in`: URL!) // Save an object.
    @objc optional func send() // Send to AppleCare
}

// MARK: SystemInformationItem
@objc public protocol SystemInformationItem: SBObjectProtocol, SystemInformationGenericMethods {
    @objc optional var properties: [AnyHashable : Any] { get } // All of the object's properties.
}
extension SBObject: SystemInformationItem {}

// MARK: SystemInformationApplication
@objc public protocol SystemInformationApplication: SBApplicationProtocol {
    @objc optional var frontmost: Bool { get } // Is this the frontmost (active) application?
    @objc optional var name: String { get } // The name of the application.
    @objc optional var version: String { get } // The version of the application.
    @objc optional var systemProfile: String { get } // Plain text representation of a system profile for the current machine.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: URL!) -> SystemInformationDocument // Open an object.
    @objc optional func print(_ x: URL!, printDialog: Bool, withProperties: SystemInformationPrintSettings!) // Print an object.
    @objc optional func quitSaving(_ saving: SystemInformationSavo) // Quit an application.
}
extension SBApplication: SystemInformationApplication {}

// MARK: SystemInformationColor
@objc public protocol SystemInformationColor: SystemInformationItem {
}
extension SBObject: SystemInformationColor {}

// MARK: SystemInformationDocument
@objc public protocol SystemInformationDocument: SystemInformationItem {
    @objc optional var modified: Bool { get } // Has the document been modified since the last save?
    @objc optional var name: String { get } // The document's name.
    @objc optional var path: String { get } // The document's path.
    @objc optional var detailLevel: SystemInformationEdtl { get } // The desired level of detail for the system profile document.
    @objc optional var plainText: String { get } // Plain text representation of the system profile document.
    @objc optional var profile: String { get } // Plain text representation of the system profile document.
    @objc optional var XMLText: String { get } // XML representation of the system profile document.
}
extension SBObject: SystemInformationDocument {}

// MARK: SystemInformationWindow
@objc public protocol SystemInformationWindow: SystemInformationItem {
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Whether the window has a close box.
    @objc optional var document: SystemInformationDocument { get } // The document whose contents are being displayed in the window.
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
extension SBObject: SystemInformationWindow {}

// MARK: SystemInformationAttributeRun
@objc public protocol SystemInformationAttributeRun: SystemInformationItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: SystemInformationAttributeRun {}

// MARK: SystemInformationCharacter
@objc public protocol SystemInformationCharacter: SystemInformationItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: SystemInformationCharacter {}

// MARK: SystemInformationParagraph
@objc public protocol SystemInformationParagraph: SystemInformationItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: SystemInformationParagraph {}

// MARK: SystemInformationText
@objc public protocol SystemInformationText: SystemInformationItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: SystemInformationText {}

// MARK: SystemInformationAttachment
@objc public protocol SystemInformationAttachment: SystemInformationText {
    @objc optional var fileName: String { get } // The path to the file for the attachment
}
extension SBObject: SystemInformationAttachment {}

// MARK: SystemInformationWord
@objc public protocol SystemInformationWord: SystemInformationItem {
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: SystemInformationWord {}

// MARK: SystemInformationPrintSettings
@objc public protocol SystemInformationPrintSettings: SBObjectProtocol, SystemInformationGenericMethods {
    @objc optional var copies: Int { get } // the number of copies of a document to be printed
    @objc optional var collating: Bool { get } // Should printed copies be collated?
    @objc optional var startingPage: Int { get } // the first page of the document to be printed
    @objc optional var endingPage: Int { get } // the last page of the document to be printed
    @objc optional var pagesAcross: Int { get } // number of logical pages laid across a physical page
    @objc optional var pagesDown: Int { get } // number of logical pages laid out down a physical page
    @objc optional var requestedPrintTime: Date { get } // the time at which the desktop printer should print the document
    @objc optional var errorHandling: SystemInformationEnum { get } // how errors are handled
    @objc optional var faxNumber: String { get } // for fax number
    @objc optional var targetPrinter: String { get } // for target printer
}
extension SBObject: SystemInformationPrintSettings {}

