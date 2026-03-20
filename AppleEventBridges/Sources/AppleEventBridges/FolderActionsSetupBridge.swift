@_exported import ScriptingBridgeCommon

// MARK: FolderActionsSetupSaveOptions
@objc public enum FolderActionsSetupSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: FolderActionsSetupPrintingErrorHandling
@objc public enum FolderActionsSetupPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: FolderActionsSetupSaveableFileFormat
@objc public enum FolderActionsSetupSaveableFileFormat : AEKeyword {
    case text = 0x63747874 /* Text File Format */
}

// MARK: FolderActionsSetupGenericMethods
@objc public protocol FolderActionsSetupGenericMethods {
    @objc optional func closeSaving(_ saving: FolderActionsSetupSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ `in`: URL!, `as`: FolderActionsSetupSaveableFileFormat) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: FolderActionsSetupApplication
@objc public protocol FolderActionsSetupApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional var folderActionsEnabled: Bool { get } // Are Folder Actions currently being processed?
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: FolderActionsSetupSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func folderActions() -> SBElementArray
}
extension SBApplication: FolderActionsSetupApplication {}

// MARK: FolderActionsSetupDocument
@objc public protocol FolderActionsSetupDocument: SBObjectProtocol, FolderActionsSetupGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
}
extension SBObject: FolderActionsSetupDocument {}

// MARK: FolderActionsSetupWindow
@objc public protocol FolderActionsSetupWindow: SBObjectProtocol, FolderActionsSetupGenericMethods {
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
    @objc optional var document: FolderActionsSetupDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: FolderActionsSetupWindow {}

// MARK: FolderActionsSetupFolderAction
@objc public protocol FolderActionsSetupFolderAction: SBObjectProtocol, FolderActionsSetupGenericMethods {
    @objc optional var enabled: Bool { get } // Is the folder action enabled?
    @objc optional var name: String { get } // the name of the folder action, which is also the name of the folder
    @objc optional var path: String { get } // the path to the folder to which the folder action applies
    @objc optional var volume: String { get } // the volume on which the folder to which the folder action applies resides
    @objc optional func scripts() -> SBElementArray
    @objc optional func enableProcessNewChanges(_ processNewChanges: FolderActionsSetupSaveOptions) // Enable a folder action.
}
extension SBObject: FolderActionsSetupFolderAction {}

// MARK: FolderActionsSetupScript
@objc public protocol FolderActionsSetupScript: SBObjectProtocol, FolderActionsSetupGenericMethods {
    @objc optional var enabled: Bool { get } // Is the script enabled?
    @objc optional var name: String { get } // the name of the script
    @objc optional var path: String { get } // the file system path of the disk
    @objc optional var POSIXPath: String { get } // the POSIX file system path of the disk
}
extension SBObject: FolderActionsSetupScript {}

