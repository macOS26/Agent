@_exported import ScriptingBridgeCommon

// MARK: ShortcutsEventsSaveOptions
@objc public enum ShortcutsEventsSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: ShortcutsEventsPrintingErrorHandling
@objc public enum ShortcutsEventsPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: ShortcutsEventsGenericMethods
@objc public protocol ShortcutsEventsGenericMethods {
    @objc optional func closeSaving(_ saving: ShortcutsEventsSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ `in`: URL!, `as`: Any!) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: ShortcutsEventsApplication
@objc public protocol ShortcutsEventsApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: ShortcutsEventsSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func shortcuts() -> SBElementArray
    @objc optional func folders() -> SBElementArray
}
extension SBApplication: ShortcutsEventsApplication {}

// MARK: ShortcutsEventsDocument
@objc public protocol ShortcutsEventsDocument: SBObjectProtocol, ShortcutsEventsGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
}
extension SBObject: ShortcutsEventsDocument {}

// MARK: ShortcutsEventsWindow
@objc public protocol ShortcutsEventsWindow: SBObjectProtocol, ShortcutsEventsGenericMethods {
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
    @objc optional var document: ShortcutsEventsDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: ShortcutsEventsWindow {}

// MARK: ShortcutsEventsShortcut
@objc public protocol ShortcutsEventsShortcut: SBObjectProtocol, ShortcutsEventsGenericMethods {
    @objc optional var name: String { get } // the name of the shortcut
    @objc optional var subtitle: String { get } // the shortcut's subtitle
    @objc optional var folder: ShortcutsEventsFolder { get } // the folder containing this shortcut
    @objc optional var color: NSColor { get } // the shortcut's color
    @objc optional var acceptsInput: Bool { get } // indicates whether or not the shortcut accepts input data
    @objc optional var actionCount: Int { get } // the number of actions in the shortcut
    @objc optional func id() -> String // the unique identifier of the shortcut
    @objc optional func runWithInput(_ withInput: Any!) -> Any // Run a shortcut in the background without opening Shortcuts app.
}
extension SBObject: ShortcutsEventsShortcut {}

// MARK: ShortcutsEventsFolder
@objc public protocol ShortcutsEventsFolder: SBObjectProtocol, ShortcutsEventsGenericMethods {
    @objc optional var name: String { get } // the name of the folder
    @objc optional func shortcuts() -> SBElementArray
    @objc optional func id() -> String // the unique identifier of the folder
}
extension SBObject: ShortcutsEventsFolder {}
