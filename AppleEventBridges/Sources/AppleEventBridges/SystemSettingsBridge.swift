
// MARK: SystemSettingsSaveOptions
@objc public enum SystemSettingsSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: SystemSettingsPrintingErrorHandling
@objc public enum SystemSettingsPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: SystemSettingsGenericMethods
@objc public protocol SystemSettingsGenericMethods {
    @objc optional func closeSaving(_ saving: SystemSettingsSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
}

// MARK: SystemSettingsApplication
@objc public protocol SystemSettingsApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional var currentPane: SystemSettingsPane { get } // The currently selected pane.
    @objc optional var settingsWindow: SystemSettingsWindow { get } // The main settings window.
    @objc optional var showAll: Bool { get } // Is System Settings in show-all view? (Setting to false does nothing.) Deprecated: setting this property no longer does anything; it is always set to true.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: SystemSettingsSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func panes() -> SBElementArray
}
extension SBApplication: SystemSettingsApplication {}

// MARK: SystemSettingsDocument
@objc public protocol SystemSettingsDocument: SBObjectProtocol, SystemSettingsGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
}
extension SBObject: SystemSettingsDocument {}

// MARK: SystemSettingsWindow
@objc public protocol SystemSettingsWindow: SBObjectProtocol, SystemSettingsGenericMethods {
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
    @objc optional var document: SystemSettingsDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: SystemSettingsWindow {}

// MARK: SystemSettingsPane
@objc public protocol SystemSettingsPane: SBObjectProtocol, SystemSettingsGenericMethods {
    @objc optional var name: String { get } // The name of the settings pane.
    @objc optional func anchors() -> SBElementArray
    @objc optional func id() -> String // The id of the settings pane.
    @objc optional func reveal() -> Any // Reveals a settings pane or an anchor within a pane.
    @objc optional func authorize() -> SystemSettingsPane // Prompt for authorization for a settings pane. Deprecated: no longer does anything.
}
extension SBObject: SystemSettingsPane {}

// MARK: SystemSettingsAnchor
@objc public protocol SystemSettingsAnchor: SBObjectProtocol, SystemSettingsGenericMethods {
    @objc optional var name: String { get } // The name of the anchor.
    @objc optional func reveal() -> Any // Reveals a settings pane or an anchor within a pane.
}
extension SBObject: SystemSettingsAnchor {}

