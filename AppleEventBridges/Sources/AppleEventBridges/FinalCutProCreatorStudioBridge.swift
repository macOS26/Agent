
// MARK: FinalCutProCreatorStudioSaveOptions
@objc public enum FinalCutProCreatorStudioSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: FinalCutProCreatorStudioPrintingErrorHandling
@objc public enum FinalCutProCreatorStudioPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: FinalCutProCreatorStudioTimecodeFormats
@objc public enum FinalCutProCreatorStudioTimecodeFormats : AEKeyword {
    case unspecified = 0x756e7370 /* Timecode format unspecified. */
    case dropFrame = 0x64726f70 /* Drop frame timecode. */
    case nonDropFrame = 0x6e647270 /* Non drop frame timecode. */
}

// MARK: FinalCutProCreatorStudioGenericMethods
@objc public protocol FinalCutProCreatorStudioGenericMethods {
    @objc optional func closeSaving(_ saving: FinalCutProCreatorStudioSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ `in`: URL!, `as`: Any!) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: FinalCutProCreatorStudioApplication
@objc public protocol FinalCutProCreatorStudioApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: FinalCutProCreatorStudioSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func libraries() -> SBElementArray
}
extension SBApplication: FinalCutProCreatorStudioApplication {}

// MARK: FinalCutProCreatorStudioDocument
@objc public protocol FinalCutProCreatorStudioDocument: SBObjectProtocol, FinalCutProCreatorStudioGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
}
extension SBObject: FinalCutProCreatorStudioDocument {}

// MARK: FinalCutProCreatorStudioWindow
@objc public protocol FinalCutProCreatorStudioWindow: SBObjectProtocol, FinalCutProCreatorStudioGenericMethods {
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
    @objc optional var document: FinalCutProCreatorStudioDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: FinalCutProCreatorStudioWindow {}

// MARK: FinalCutProCreatorStudioSequence
@objc public protocol FinalCutProCreatorStudioSequence: SBObjectProtocol, FinalCutProCreatorStudioGenericMethods {
    @objc optional var name: String { get } // The name of the sequence.
    @objc optional var container: FinalCutProCreatorStudioItem { get }
    @objc optional var startTime: [AnyHashable : Any] { get } // The start time of the sequence.
    @objc optional var duration: [AnyHashable : Any] { get } // The duration of the sequence.
    @objc optional var frameDuration: [AnyHashable : Any] { get } // The duration of a video frame, an inverse is the frame rate.
    @objc optional var timecodeFormat: FinalCutProCreatorStudioTimecodeFormats { get } // Timecode format, Drop Frame (DF) or Non Drop Frame (NDF).
    @objc optional var essentialProperties: [AnyHashable : Any] { get } // essential property of the item
    @objc optional func id() -> String // The unique identifier of the sequence.
}
extension SBObject: FinalCutProCreatorStudioSequence {}

// MARK: FinalCutProCreatorStudioItem
@objc public protocol FinalCutProCreatorStudioItem: SBObjectProtocol, FinalCutProCreatorStudioGenericMethods {
    @objc optional var container: FinalCutProCreatorStudioItem { get } // the container of the item
    @objc optional var index: Int { get } // The index of the item in internal application order.
    @objc optional var name: String { get } // the name of the item
    @objc optional var persistentID: String { get } // the id of the item as a hexadecimal string. This id does not change over time.
    @objc optional var properties: [AnyHashable : Any] { get } // every property of the item
    @objc optional var essentialProperties: [AnyHashable : Any] { get } // essential property of the item
    @objc optional func id() -> String // the id of the item
}
extension SBObject: FinalCutProCreatorStudioItem {}

// MARK: FinalCutProCreatorStudioProject
@objc public protocol FinalCutProCreatorStudioProject: FinalCutProCreatorStudioItem {
    @objc optional var name: String { get } // The name of the project.
    @objc optional var container: FinalCutProCreatorStudioItem { get }
    @objc optional var essentialProperties: [AnyHashable : Any] { get } // essential property of the item
    @objc optional var sequence: FinalCutProCreatorStudioSequence { get }
    @objc optional func id() -> String // The unique identifier of the project.
}
extension SBObject: FinalCutProCreatorStudioProject {}

// MARK: FinalCutProCreatorStudioEvent
@objc public protocol FinalCutProCreatorStudioEvent: FinalCutProCreatorStudioItem {
    @objc optional var name: String { get } // The name of the event.
    @objc optional var container: FinalCutProCreatorStudioItem { get }
    @objc optional var essentialProperties: [AnyHashable : Any] { get } // essential property of the item
    @objc optional func sequences() -> SBElementArray
    @objc optional func projects() -> SBElementArray
    @objc optional func id() -> String // The unique identifier of the event.
}
extension SBObject: FinalCutProCreatorStudioEvent {}

// MARK: FinalCutProCreatorStudioLibrary
@objc public protocol FinalCutProCreatorStudioLibrary: FinalCutProCreatorStudioItem {
    @objc optional var name: String { get } // The name of the library.
    @objc optional var container: FinalCutProCreatorStudioApplication { get }
    @objc optional var essentialProperties: [AnyHashable : Any] { get } // essential property of the item
    @objc optional var file: URL { get }
    @objc optional func events() -> SBElementArray
    @objc optional func id() -> String // The unique identifier of the library.
}
extension SBObject: FinalCutProCreatorStudioLibrary {}

