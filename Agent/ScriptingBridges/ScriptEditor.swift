// MARK: ScriptEditorSavo
@objc public enum ScriptEditorSavo : AEKeyword {
    case ask = 0x61736b20 /* b'ask ' */
    case no = 0x6e6f2020 /* b'no  ' */
    case yes = 0x79657320 /* b'yes ' */
}

// MARK: ScriptEditorEnum
@objc public enum ScriptEditorEnum : AEKeyword {
    case standard = 0x6c777374 /* b'lwst' */
    case detailed = 0x6c776474 /* b'lwdt' */
}

// MARK: ScriptEditorGenericMethods
@objc public protocol ScriptEditorGenericMethods {
    @objc optional func closeSaving(_ saving: ScriptEditorSavo, savingIn: URL!) // Close an object.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy object(s) and put the copies at a new location.
    @objc optional func exists() -> Bool // Verify if an object exists.
    @objc optional func moveTo(_ to: SBObject!) // Move object(s) to a new location.
    @objc optional func saveAs(_ as: String!, in in_: URL!) // Save an object.
    @objc optional func checkSyntax() // Check the syntax of a document.
    @objc optional func compile() -> Bool // Compile the script of a document.
    @objc optional func saveAs(_ as: String!, in in_: URL!, runOnly: Bool, startupScreen: Bool, stayOpen: Bool) // Save an object.
}

// MARK: ScriptEditorItem
@objc public protocol ScriptEditorItem: SBObjectProtocol, ScriptEditorGenericMethods {
    @objc optional var properties: [AnyHashable : Any] { get } // All of the object's properties.
    @objc optional func setProperties(_ properties: [AnyHashable : Any]!) // All of the object's properties.
}
extension SBObject: ScriptEditorItem {}

// MARK: ScriptEditorApplication
@objc public protocol ScriptEditorApplication: SBApplicationProtocol {
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional var frontmost: Bool { get } // Is this the frontmost (active) application?
    @objc optional var name: String { get } // The name of the application.
    @objc optional var version: String { get } // The version of the application.
    @objc optional func `open`(_ x: URL!) -> ScriptEditorDocument // Open an object.
    @objc optional func print(_ x: URL!, printDialog: Bool, withProperties: ScriptEditorPrintSettings!) // Print an object.
    @objc optional func quitSaving(_ saving: ScriptEditorSavo) // Quit an application.
    @objc optional func objectClasss() -> SBElementArray
    @objc optional func languages() -> SBElementArray
    @objc optional var selection: ScriptEditorSelectionObject { get } // The current selection.
    @objc optional func setSelection(_ selection: ScriptEditorSelectionObject!) // The current selection.
}
extension SBApplication: ScriptEditorApplication {}

// MARK: ScriptEditorColor
@objc public protocol ScriptEditorColor: ScriptEditorItem {
}
extension SBObject: ScriptEditorColor {}

// MARK: ScriptEditorDocument
@objc public protocol ScriptEditorDocument: ScriptEditorItem {
    @objc optional var modified: Bool { get } // Has the document been modified since the last save?
    @objc optional var name: String { get } // The document's name.
    @objc optional var path: String { get } // The document's path.
    @objc optional func setName(_ name: String!) // The document's name.
    @objc optional func setPath(_ path: String!) // The document's path.
    @objc optional func windows() -> SBElementArray
    @objc optional var contents: ScriptEditorText { get } // The contents of the document.
    @objc optional var objectDescription: ScriptEditorText { get } // The description of the document.
    @objc optional var eventLog: ScriptEditorText { get } // The event log of the document.
    @objc optional var language: ScriptEditorLanguage { get } // The scripting language.
    @objc optional var selection: ScriptEditorSelectionObject { get } // The current selection.
    @objc optional var text: ScriptEditorText { get } // The text of the document.
    @objc optional func setContents(_ contents: ScriptEditorText!) // The contents of the document.
    @objc optional func setObjectDescription(_ objectDescription: ScriptEditorText!) // The description of the document.
    @objc optional func setLanguage(_ language: ScriptEditorLanguage!) // The scripting language.
    @objc optional func setSelection(_ selection: ScriptEditorSelectionObject!) // The current selection.
    @objc optional func setText(_ text: ScriptEditorText!) // The text of the document.
}
extension SBObject: ScriptEditorDocument {}

// MARK: ScriptEditorWindow
@objc public protocol ScriptEditorWindow: ScriptEditorItem {
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Whether the window has a close box.
    @objc optional var document: ScriptEditorDocument { get } // The document whose contents are being displayed in the window.
    @objc optional var floating: Bool { get } // Whether the window floats.
    @objc optional func id() -> Int // The unique identifier of the window.
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
    @objc optional func setBounds(_ bounds: NSRect) // The bounding rectangle of the window.
    @objc optional func setIndex(_ index: Int) // The index of the window, ordered front to back.
    @objc optional func setMiniaturized(_ miniaturized: Bool) // Whether the window is currently miniaturized.
    @objc optional func setName(_ name: String!) // The full title of the window.
    @objc optional func setVisible(_ visible: Bool) // Whether the window is currently visible.
    @objc optional func setZoomed(_ zoomed: Bool) // Whether the window is currently zoomed.
}
extension SBObject: ScriptEditorWindow {}

// MARK: ScriptEditorAttributeRun
@objc public protocol ScriptEditorAttributeRun: ScriptEditorItem {
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func setColor(_ color: NSColor!) // The color of the first character.
    @objc optional func setFont(_ font: String!) // The name of the font of the first character.
    @objc optional func setSize(_ size: Int) // The size in points of the first character.
}
extension SBObject: ScriptEditorAttributeRun {}

// MARK: ScriptEditorCharacter
@objc public protocol ScriptEditorCharacter: ScriptEditorItem {
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func setColor(_ color: NSColor!) // The color of the first character.
    @objc optional func setFont(_ font: String!) // The name of the font of the first character.
    @objc optional func setSize(_ size: Int) // The size in points of the first character.
}
extension SBObject: ScriptEditorCharacter {}

// MARK: ScriptEditorParagraph
@objc public protocol ScriptEditorParagraph: ScriptEditorItem {
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func setColor(_ color: NSColor!) // The color of the first character.
    @objc optional func setFont(_ font: String!) // The name of the font of the first character.
    @objc optional func setSize(_ size: Int) // The size in points of the first character.
}
extension SBObject: ScriptEditorParagraph {}

// MARK: ScriptEditorText
@objc public protocol ScriptEditorText: ScriptEditorItem {
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func setColor(_ color: NSColor!) // The color of the first character.
    @objc optional func setFont(_ font: String!) // The name of the font of the first character.
    @objc optional func setSize(_ size: Int) // The size in points of the first character.
    @objc optional func insertionPoints() -> SBElementArray
    @objc optional func text() -> SBElementArray
}
extension SBObject: ScriptEditorText {}

// MARK: ScriptEditorAttachment
@objc public protocol ScriptEditorAttachment: ScriptEditorText {
    @objc optional var fileName: String { get } // The path to the file for the attachment
    @objc optional func setFileName(_ fileName: String!) // The path to the file for the attachment
}
extension SBObject: ScriptEditorAttachment {}

// MARK: ScriptEditorWord
@objc public protocol ScriptEditorWord: ScriptEditorItem {
    @objc optional func attachments() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: Int { get } // The size in points of the first character.
    @objc optional func setColor(_ color: NSColor!) // The color of the first character.
    @objc optional func setFont(_ font: String!) // The name of the font of the first character.
    @objc optional func setSize(_ size: Int) // The size in points of the first character.
}
extension SBObject: ScriptEditorWord {}

// MARK: ScriptEditorObjectClass
@objc public protocol ScriptEditorObjectClass: ScriptEditorItem {
}
extension SBObject: ScriptEditorObjectClass {}

// MARK: ScriptEditorInsertionPoint
@objc public protocol ScriptEditorInsertionPoint: ScriptEditorItem {
    @objc optional var contents: ScriptEditorItem { get } // The contents of the insertion point.
    @objc optional func setContents(_ contents: ScriptEditorItem!) // The contents of the insertion point.
}
extension SBObject: ScriptEditorInsertionPoint {}

// MARK: ScriptEditorLanguage
@objc public protocol ScriptEditorLanguage: ScriptEditorItem {
    @objc optional var objectDescription: String { get } // The description
    @objc optional func id() -> String // The unique id of the language.
    @objc optional var name: String { get } // The name of the language.
    @objc optional var supportsCompiling: Bool { get } // Is the language compilable?
    @objc optional var supportsRecording: Bool { get } // Is the language recordable?
}
extension SBObject: ScriptEditorLanguage {}

// MARK: ScriptEditorSelectionObject
@objc public protocol ScriptEditorSelectionObject: ScriptEditorItem {
    @objc optional var characterRange: NSPoint { get } // The range of characters in the selection.
    @objc optional var contents: ScriptEditorItem { get } // The contents of the selection.
    @objc optional func setContents(_ contents: ScriptEditorItem!) // The contents of the selection.
}
extension SBObject: ScriptEditorSelectionObject {}

// MARK: ScriptEditorPrintSettings
@objc public protocol ScriptEditorPrintSettings: SBObjectProtocol, ScriptEditorGenericMethods {
    @objc optional var copies: Int { get } // the number of copies of a document to be printed
    @objc optional var collating: Bool { get } // Should printed copies be collated?
    @objc optional var startingPage: Int { get } // the first page of the document to be printed
    @objc optional var endingPage: Int { get } // the last page of the document to be printed
    @objc optional var pagesAcross: Int { get } // number of logical pages laid across a physical page
    @objc optional var pagesDown: Int { get } // number of logical pages laid out down a physical page
    @objc optional var requestedPrintTime: Date { get } // the time at which the desktop printer should print the document
    @objc optional var errorHandling: ScriptEditorEnum { get } // how errors are handled
    @objc optional var faxNumber: String { get } // for fax number
    @objc optional var targetPrinter: String { get } // for target printer
    @objc optional func setCopies(_ copies: Int) // the number of copies of a document to be printed
    @objc optional func setCollating(_ collating: Bool) // Should printed copies be collated?
    @objc optional func setStartingPage(_ startingPage: Int) // the first page of the document to be printed
    @objc optional func setEndingPage(_ endingPage: Int) // the last page of the document to be printed
    @objc optional func setPagesAcross(_ pagesAcross: Int) // number of logical pages laid across a physical page
    @objc optional func setPagesDown(_ pagesDown: Int) // number of logical pages laid out down a physical page
    @objc optional func setRequestedPrintTime(_ requestedPrintTime: Date!) // the time at which the desktop printer should print the document
    @objc optional func setErrorHandling(_ errorHandling: ScriptEditorEnum) // how errors are handled
    @objc optional func setFaxNumber(_ faxNumber: String!) // for fax number
    @objc optional func setTargetPrinter(_ targetPrinter: String!) // for target printer
}
extension SBObject: ScriptEditorPrintSettings {}

