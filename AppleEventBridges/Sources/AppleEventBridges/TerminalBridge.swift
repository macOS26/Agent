
// MARK: TerminalSaveOptions
@objc public enum TerminalSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: TerminalPrintingErrorHandling
@objc public enum TerminalPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: TerminalGenericMethods
@objc public protocol TerminalGenericMethods {
    @objc optional func closeSaving(_ saving: TerminalSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ `in`: URL!) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy object(s) and put the copies at a new location.
    @objc optional func exists() -> Bool // Verify if an object exists.
    @objc optional func moveTo(_ to: SBObject!) // Move object(s) to a new location.
}

// MARK: TerminalApplication
@objc public protocol TerminalApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the frontmost (active) application?
    @objc optional var version: String { get } // The version of the application.
    @objc optional var defaultSettings: TerminalSettingsSet { get } // The settings set used for new windows.
    @objc optional var startupSettings: TerminalSettingsSet { get } // The settings set used for the window created on application startup.
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: [Any]!) // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: TerminalSaveOptions) // Quit the application.
    @objc optional func doScript(_ x: String!, `in`: Any!) -> TerminalTab // Runs a UNIX shell script or command.
    @objc optional func settingsSets() -> SBElementArray
}
extension SBApplication: TerminalApplication {}

// MARK: TerminalWindow
@objc public protocol TerminalWindow: SBObjectProtocol, TerminalGenericMethods {
    @objc optional var name: String { get } // The full title of the window.
    @objc optional var index: Int { get } // The index of the window, ordered front to back.
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Whether the window has a close box.
    @objc optional var miniaturizable: Bool { get } // Whether the window can be minimized.
    @objc optional var miniaturized: Bool { get } // Whether the window is currently minimized.
    @objc optional var resizable: Bool { get } // Whether the window can be resized.
    @objc optional var visible: Bool { get } // Whether the window is currently visible.
    @objc optional var zoomable: Bool { get } // Whether the window can be zoomed.
    @objc optional var zoomed: Bool { get } // Whether the window is currently zoomed.
    @objc optional var frontmost: Bool { get } // Whether the window is currently the frontmost Terminal window.
    @objc optional var selectedTab: TerminalTab { get }
    @objc optional var position: NSPoint { get } // The position of the window, relative to the upper left corner of the screen.
    @objc optional var origin: NSPoint { get } // The position of the window, relative to the lower left corner of the screen.
    @objc optional var size: NSPoint { get } // The width and height of the window
    @objc optional var frame: NSRect { get } // The bounding rectangle, relative to the lower left corner of the screen.
    @objc optional func tabs() -> SBElementArray
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: TerminalWindow {}

// MARK: TerminalSettingsSet
@objc public protocol TerminalSettingsSet: SBObjectProtocol, TerminalGenericMethods {
    @objc optional var name: String { get } // The name of the settings set.
    @objc optional var numberOfRows: Int { get } // The number of rows displayed in the tab.
    @objc optional var numberOfColumns: Int { get } // The number of columns displayed in the tab.
    @objc optional var cursorColor: NSColor { get } // The cursor color for the tab.
    @objc optional var backgroundColor: NSColor { get } // The background color for the tab.
    @objc optional var normalTextColor: NSColor { get } // The normal text color for the tab.
    @objc optional var boldTextColor: NSColor { get } // The bold text color for the tab.
    @objc optional var fontName: String { get } // The name of the font used to display the tab’s contents.
    @objc optional var fontSize: Int { get } // The size of the font used to display the tab’s contents.
    @objc optional var fontAntialiasing: Bool { get } // Whether the font used to display the tab’s contents is antialiased.
    @objc optional var cleanCommands: [Any] { get } // The processes which will be ignored when checking whether a tab can be closed without showing a prompt.
    @objc optional var titleDisplaysDeviceName: Bool { get } // Whether the title contains the device name.
    @objc optional var titleDisplaysShellPath: Bool { get } // Whether the title contains the shell path.
    @objc optional var titleDisplaysWindowSize: Bool { get } // Whether the title contains the tab’s size, in rows and columns.
    @objc optional var titleDisplaysSettingsName: Bool { get } // Whether the title contains the settings name.
    @objc optional var titleDisplaysCustomTitle: Bool { get } // Whether the title contains a custom title.
    @objc optional var customTitle: String { get } // The tab’s custom title.
    @objc optional func id() -> Int // The unique identifier of the settings set.
}
extension SBObject: TerminalSettingsSet {}

// MARK: TerminalTab
@objc public protocol TerminalTab: SBObjectProtocol, TerminalGenericMethods {
    @objc optional var numberOfRows: Int { get } // The number of rows displayed in the tab.
    @objc optional var numberOfColumns: Int { get } // The number of columns displayed in the tab.
    @objc optional var contents: String { get } // The currently visible contents of the tab.
    @objc optional var history: String { get } // The contents of the entire scrolling buffer of the tab.
    @objc optional var busy: Bool { get } // Whether the tab is busy running a process.
    @objc optional var processes: [Any] { get } // The processes currently running in the tab.
    @objc optional var selected: Bool { get } // Whether the tab is selected.
    @objc optional var titleDisplaysCustomTitle: Bool { get } // Whether the title contains a custom title.
    @objc optional var customTitle: String { get } // The tab’s custom title.
    @objc optional var tty: String { get } // The tab’s TTY device.
    @objc optional var currentSettings: TerminalSettingsSet { get } // The set of settings which control the tab’s behavior and appearance.
    @objc optional var cursorColor: NSColor { get } // The cursor color for the tab.
    @objc optional var backgroundColor: NSColor { get } // The background color for the tab.
    @objc optional var normalTextColor: NSColor { get } // The normal text color for the tab.
    @objc optional var boldTextColor: NSColor { get } // The bold text color for the tab.
    @objc optional var cleanCommands: [Any] { get } // The processes which will be ignored when checking whether a tab can be closed without showing a prompt.
    @objc optional var titleDisplaysDeviceName: Bool { get } // Whether the title contains the device name.
    @objc optional var titleDisplaysShellPath: Bool { get } // Whether the title contains the shell path.
    @objc optional var titleDisplaysWindowSize: Bool { get } // Whether the title contains the tab’s size, in rows and columns.
    @objc optional var titleDisplaysFileName: Bool { get } // Whether the title contains the file name.
    @objc optional var fontName: String { get } // The name of the font used to display the tab’s contents.
    @objc optional var fontSize: Int { get } // The size of the font used to display the tab’s contents.
    @objc optional var fontAntialiasing: Bool { get } // Whether the font used to display the tab’s contents is antialiased.
}
extension SBObject: TerminalTab {}

