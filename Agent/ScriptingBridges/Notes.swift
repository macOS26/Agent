// MARK: NotesSaveOptions
@objc public enum NotesSaveOptions : AEKeyword {
    case yes = 0x79657320 /* b'yes ' */
    case no = 0x6e6f2020 /* b'no  ' */
    case ask = 0x61736b20 /* b'ask ' */
}

// MARK: NotesPrintingErrorHandling
@objc public enum NotesPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* b'lwst' */
    case detailed = 0x6c776474 /* b'lwdt' */
}

// MARK: NotesSaveableFileFormat
@objc public enum NotesSaveableFileFormat : AEKeyword {
    case nativeFormat = 0x6974656d /* b'item' */
}

// MARK: NotesGenericMethods
@objc public protocol NotesGenericMethods {
    @objc optional func closeSaving(_ saving: NotesSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ in_: URL!, as: NotesSaveableFileFormat) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: NotesApplication
@objc public protocol NotesApplication: SBApplicationProtocol {
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: NotesSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func openNoteLocation(_ x: String!) // Open a note URL.
    @objc optional func accounts() -> SBElementArray
    @objc optional func folders() -> SBElementArray
    @objc optional func notes() -> SBElementArray
    @objc optional func attachments() -> SBElementArray
    @objc optional var defaultAccount: NotesAccount { get } // the default account for creating notes
    @objc optional var selection: [NotesNote] { get } // the selected note(s)
    @objc optional func setDefaultAccount(_ defaultAccount: NotesAccount!) // the default account for creating notes
    @objc optional func setSelection(_ selection: [NotesNote]!) // the selected note(s)
}
extension SBApplication: NotesApplication {}

// MARK: NotesDocument
@objc public protocol NotesDocument: SBObjectProtocol, NotesGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
}
extension SBObject: NotesDocument {}

// MARK: NotesWindow
@objc public protocol NotesWindow: SBObjectProtocol, NotesGenericMethods {
    @objc optional var name: String { get } // The title of the window.
    @objc optional func id() -> Int // The unique identifier of the window.
    @objc optional var index: Int { get } // The index of the window, ordered front to back.
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Does the window have a close button?
    @objc optional var miniaturizable: Bool { get } // Does the window have a minimize button?
    @objc optional var miniaturized: Bool { get } // Is the window minimized right now?
    @objc optional var resizable: Bool { get } // Can the window be resized?
    @objc optional var visible: Bool { get } // Is the window visible right now?
    @objc optional var zoomable: Bool { get } // Does the window have a zoom button?
    @objc optional var zoomed: Bool { get } // Is the window zoomed right now?
    @objc optional var document: NotesDocument { get } // The document whose contents are displayed in the window.
    @objc optional func setIndex(_ index: Int) // The index of the window, ordered front to back.
    @objc optional func setBounds(_ bounds: NSRect) // The bounding rectangle of the window.
    @objc optional func setMiniaturized(_ miniaturized: Bool) // Is the window minimized right now?
    @objc optional func setVisible(_ visible: Bool) // Is the window visible right now?
    @objc optional func setZoomed(_ zoomed: Bool) // Is the window zoomed right now?
}
extension SBObject: NotesWindow {}

// MARK: NotesAccount
@objc public protocol NotesAccount: SBObjectProtocol, NotesGenericMethods {
    @objc optional func folders() -> SBElementArray
    @objc optional func notes() -> SBElementArray
    @objc optional var defaultFolder: NotesFolder { get } // the default folder for creating notes
    @objc optional var name: String { get } // the name of the account
    @objc optional var upgraded: Bool { get } // Is the account upgraded?
    @objc optional func id() -> String // the unique identifier of the account
    @objc optional func showSeparately(_ separately: Bool) -> Any // Show an object in the UI
    @objc optional func setDefaultFolder(_ defaultFolder: NotesFolder!) // the default folder for creating notes
    @objc optional func setName(_ name: String!) // the name of the account
}
extension SBObject: NotesAccount {}

// MARK: NotesFolder
@objc public protocol NotesFolder: SBObjectProtocol, NotesGenericMethods {
    @objc optional func folders() -> SBElementArray
    @objc optional func notes() -> SBElementArray
    @objc optional var name: String { get } // the name of the folder
    @objc optional func id() -> String // the unique identifier of the folder
    @objc optional var shared: Bool { get } // Is the folder shared?
    @objc optional var container: Any { get } // the container of the folder
    @objc optional func showSeparately(_ separately: Bool) -> Any // Show an object in the UI
    @objc optional func setName(_ name: String!) // the name of the folder
}
extension SBObject: NotesFolder {}

// MARK: NotesNote
@objc public protocol NotesNote: SBObjectProtocol, NotesGenericMethods {
    @objc optional func attachments() -> SBElementArray
    @objc optional var name: String { get } // the name of the note (normally the first line of the body)
    @objc optional func id() -> String // the unique identifier of the note
    @objc optional var container: NotesFolder { get } // the folder of the note
    @objc optional var body: String { get } // the HTML content of the note
    @objc optional var plaintext: String { get } // the plaintext content of the note
    @objc optional var creationDate: Date { get } // the creation date of the note
    @objc optional var modificationDate: Date { get } // the modification date of the note
    @objc optional var passwordProtected: Bool { get } // Is the note password protected?
    @objc optional var shared: Bool { get } // Is the note shared?
    @objc optional func showSeparately(_ separately: Bool) -> Any // Show an object in the UI
    @objc optional func setName(_ name: String!) // the name of the note (normally the first line of the body)
    @objc optional func setBody(_ body: String!) // the HTML content of the note
}
extension SBObject: NotesNote {}

// MARK: NotesAttachment
@objc public protocol NotesAttachment: SBObjectProtocol, NotesGenericMethods {
    @objc optional var name: String { get } // the name of the attachment
    @objc optional func id() -> String // the unique identifier of the attachment
    @objc optional var container: NotesNote { get } // the note containing the attachment
    @objc optional var contentIdentifier: String { get } // the content-id URL in the note's HTML
    @objc optional var creationDate: Date { get } // the creation date of the attachment
    @objc optional var modificationDate: Date { get } // the modification date of the attachment
    @objc optional var URL: String { get } // for URL attachments, the URL the attachment represents
    @objc optional var shared: Bool { get } // Is the attachment shared?
    @objc optional func showSeparately(_ separately: Bool) -> Any // Show an object in the UI
}
extension SBObject: NotesAttachment {}

