
// MARK: SafariSaveOptions
@objc public enum SafariSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: SafariPrintingErrorHandling
@objc public enum SafariPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: SafariGenericMethods
@objc public protocol SafariGenericMethods {
    @objc optional func closeSaving(_ saving: SafariSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ `in`: URL!, `as`: Any!) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: SafariApplication
@objc public protocol SafariApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: SafariSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func addReadingListItem(_ x: String!, andPreviewText: String!, withTitle: String!) // Add a new Reading List item with the given URL. Allows a custom title and preview text to be specified.
    @objc optional func doJavaScript(_ x: String!, `in`: Any!) -> Any // Applies a string of JavaScript code to a document.
    @objc optional func emailContentsOf(_ of: Any!) // Emails the contents of a tab.
    @objc optional func searchTheWebIn(_ `in`: Any!, `for`: String!) // Searches the web using Safari's current search provider.
    @objc optional func showBookmarks() // Shows Safari's bookmarks.
}
extension SBApplication: SafariApplication {}

// MARK: SafariDocument
@objc public protocol SafariDocument: SBObjectProtocol, SafariGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
    @objc optional var source: String { get } // The HTML source of the web page currently loaded in the document.
    @objc optional var URL: String { get } // The current URL of the document.
    @objc optional var text: String { get } // The text of the web page currently loaded in the document. Modifications to text aren't reflected on the web page.
}
extension SBObject: SafariDocument {}

// MARK: SafariWindow
@objc public protocol SafariWindow: SBObjectProtocol, SafariGenericMethods {
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
    @objc optional var document: SafariDocument { get } // The document whose contents are displayed in the window.
    @objc optional var currentTab: SafariTab { get } // The current tab.
    @objc optional func id() -> Int // The unique identifier of the window.
    @objc optional func tabs() -> SBElementArray
}
extension SBObject: SafariWindow {}

// MARK: SafariTab
@objc public protocol SafariTab: SBObjectProtocol, SafariGenericMethods {
    @objc optional var source: String { get } // The HTML source of the web page currently loaded in the tab.
    @objc optional var URL: String { get } // The current URL of the tab.
    @objc optional var index: NSNumber { get } // The index of the tab, ordered left to right.
    @objc optional var text: String { get } // The text of the web page currently loaded in the tab. Modifications to text aren't reflected on the web page.
    @objc optional var visible: Bool { get } // Whether the tab is currently visible.
    @objc optional var name: String { get } // The name of the tab.
}
extension SBObject: SafariTab {}

