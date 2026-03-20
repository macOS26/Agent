
// MARK: GoogleChromeGenericMethods
@objc public protocol GoogleChromeGenericMethods {
    @objc optional func saveIn(_ `in`: URL!, `as`: String!) // Save an object.
    @objc optional func close() // Close a window.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) -> SBObject // Copy object(s) and put the copies at a new location.
    @objc optional func moveTo(_ to: SBObject!) -> SBObject // Move object(s) to a new location.
    @objc optional func print() // Print an object.
    @objc optional func reload() // Reload a tab.
    @objc optional func goBack() // Go Back (If Possible).
    @objc optional func goForward() // Go Forward (If Possible).
    @objc optional func selectAll() // Select all.
    @objc optional func cutSelection() // Cut selected text (If Possible).
    @objc optional func copySelection() // Copy text.
    @objc optional func pasteSelection() // Paste text (If Possible).
    @objc optional func undo() // Undo the last change.
    @objc optional func redo() // Redo the last change.
    @objc optional func stop() // Stop the current tab from loading.
    @objc optional func viewSource() // View the HTML source of the tab.
    @objc optional func executeJavascript(_ javascript: String!) -> Any // Execute a piece of javascript.
}

// MARK: GoogleChromeApplication
@objc public protocol GoogleChromeApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the frontmost (active) application?
    @objc optional var version: String { get } // The version of the application.
    @objc optional var bookmarksBar: GoogleChromeBookmarkFolder { get } // The bookmarks bar bookmark folder.
    @objc optional var otherBookmarks: GoogleChromeBookmarkFolder { get } // The other bookmarks bookmark folder.
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: [Any]!) // Open a document.
    @objc optional func quit() // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify if an object exists.
    @objc optional func bookmarkFolders() -> SBElementArray
}
extension SBApplication: GoogleChromeApplication {}

// MARK: GoogleChromeWindow
@objc public protocol GoogleChromeWindow: SBObjectProtocol, GoogleChromeGenericMethods {
    @objc optional var givenName: String { get } // The given name of the window.
    @objc optional var name: String { get } // The full title of the window.
    @objc optional var index: Int { get } // The index of the window, ordered front to back.
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Whether the window has a close box.
    @objc optional var minimizable: Bool { get } // Whether the window can be minimized.
    @objc optional var minimized: Bool { get } // Whether the window is currently minimized.
    @objc optional var resizable: Bool { get } // Whether the window can be resized.
    @objc optional var visible: Bool { get } // Whether the window is currently visible.
    @objc optional var zoomable: Bool { get } // Whether the window can be zoomed.
    @objc optional var zoomed: Bool { get } // Whether the window is currently zoomed.
    @objc optional var activeTab: GoogleChromeTab { get } // Returns the currently selected tab
    @objc optional var mode: String { get } // Represents the mode of the window which can be 'normal' or 'incognito', can be set only once during creation of the window.
    @objc optional var activeTabIndex: Int { get } // The index of the active tab.
    @objc optional func tabs() -> SBElementArray
    @objc optional func id() -> String // The unique identifier of the window.
}
extension SBObject: GoogleChromeWindow {}

// MARK: GoogleChromeTab
@objc public protocol GoogleChromeTab: SBObjectProtocol, GoogleChromeGenericMethods {
    @objc optional var title: String { get } // The title of the tab.
    @objc optional var URL: String { get } // The url visible to the user.
    @objc optional var loading: Bool { get } // Is loading?
    @objc optional func id() -> String // Unique ID of the tab.
}
extension SBObject: GoogleChromeTab {}

// MARK: GoogleChromeBookmarkFolder
@objc public protocol GoogleChromeBookmarkFolder: SBObjectProtocol, GoogleChromeGenericMethods {
    @objc optional var title: String { get } // The title of the folder.
    @objc optional var index: NSNumber { get } // Returns the index with respect to its parent bookmark folder.
    @objc optional func bookmarkFolders() -> SBElementArray
    @objc optional func bookmarkItems() -> SBElementArray
    @objc optional func id() -> String // Unique ID of the bookmark folder.
}
extension SBObject: GoogleChromeBookmarkFolder {}

// MARK: GoogleChromeBookmarkItem
@objc public protocol GoogleChromeBookmarkItem: SBObjectProtocol, GoogleChromeGenericMethods {
    @objc optional var title: String { get } // The title of the bookmark item.
    @objc optional var URL: String { get } // The URL of the bookmark.
    @objc optional var index: NSNumber { get } // Returns the index with respect to its parent bookmark folder.
    @objc optional func id() -> String // Unique ID of the bookmark item.
}
extension SBObject: GoogleChromeBookmarkItem {}

