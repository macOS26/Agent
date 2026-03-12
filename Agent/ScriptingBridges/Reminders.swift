// MARK: RemindersSaveOptions
@objc public enum RemindersSaveOptions : AEKeyword {
    case yes = 0x79657320 /* b'yes ' */
    case no = 0x6e6f2020 /* b'no  ' */
    case ask = 0x61736b20 /* b'ask ' */
}

// MARK: RemindersPrintingErrorHandling
@objc public enum RemindersPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* b'lwst' */
    case detailed = 0x6c776474 /* b'lwdt' */
}

// MARK: RemindersSaveableFileFormat
@objc public enum RemindersSaveableFileFormat : AEKeyword {
    case text = 0x63747874 /* b'ctxt' */
}

// MARK: RemindersGenericMethods
@objc public protocol RemindersGenericMethods {
    @objc optional func closeSaving(_ saving: RemindersSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ in_: URL!, as: RemindersSaveableFileFormat) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: RemindersApplication
@objc public protocol RemindersApplication: SBApplicationProtocol {
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: RemindersSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func accounts() -> SBElementArray
    @objc optional func lists() -> SBElementArray
    @objc optional func reminders() -> SBElementArray
    @objc optional var defaultAccount: RemindersAccount { get } // The default account in the Reminders application
    @objc optional var defaultList: RemindersList { get } // The default list in the Reminders application
}
extension SBApplication: RemindersApplication {}

// MARK: RemindersDocument
@objc public protocol RemindersDocument: SBObjectProtocol, RemindersGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
}
extension SBObject: RemindersDocument {}

// MARK: RemindersWindow
@objc public protocol RemindersWindow: SBObjectProtocol, RemindersGenericMethods {
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
    @objc optional var document: RemindersDocument { get } // The document whose contents are displayed in the window.
    @objc optional func setIndex(_ index: Int) // The index of the window, ordered front to back.
    @objc optional func setBounds(_ bounds: NSRect) // The bounding rectangle of the window.
    @objc optional func setMiniaturized(_ miniaturized: Bool) // Is the window minimized right now?
    @objc optional func setVisible(_ visible: Bool) // Is the window visible right now?
    @objc optional func setZoomed(_ zoomed: Bool) // Is the window zoomed right now?
}
extension SBObject: RemindersWindow {}

// MARK: RemindersAccount
@objc public protocol RemindersAccount: SBObjectProtocol, RemindersGenericMethods {
    @objc optional func lists() -> SBElementArray
    @objc optional func reminders() -> SBElementArray
    @objc optional func id() -> String // The unique identifier of the account
    @objc optional var name: String { get } // The name of the account
}
extension SBObject: RemindersAccount {}

// MARK: RemindersList
@objc public protocol RemindersList: SBObjectProtocol, RemindersGenericMethods {
    @objc optional func reminders() -> SBElementArray
    @objc optional func id() -> String // The unique identifier of the list
    @objc optional var name: String { get } // The name of the list
    @objc optional var container: Any { get } // The container of the list
    @objc optional var color: String { get } // The color of the list
    @objc optional var emblem: String { get } // The emblem icon name of the list
    @objc optional func show() -> Any // Show an object in the Reminders UI
    @objc optional func setName(_ name: String!) // The name of the list
    @objc optional func setColor(_ color: String!) // The color of the list
    @objc optional func setEmblem(_ emblem: String!) // The emblem icon name of the list
}
extension SBObject: RemindersList {}

// MARK: RemindersReminder
@objc public protocol RemindersReminder: SBObjectProtocol, RemindersGenericMethods {
    @objc optional var name: String { get } // The name of the reminder
    @objc optional func id() -> String // The unique identifier of the reminder
    @objc optional var container: Any { get } // The container of the reminder
    @objc optional var creationDate: Date { get } // The creation date of the reminder
    @objc optional var modificationDate: Date { get } // The modification date of the reminder
    @objc optional var body: String { get } // The notes attached to the reminder
    @objc optional var completed: Bool { get } // Whether the reminder is completed
    @objc optional var completionDate: Date { get } // The completion date of the reminder
    @objc optional var dueDate: Date { get } // The due date of the reminder; will set both date and time
    @objc optional var alldayDueDate: Date { get } // The all-day due date of the reminder; will only set a date
    @objc optional var remindMeDate: Date { get } // The remind date of the reminder
    @objc optional var priority: Int { get } // The priority of the reminder; 0: no priority, 1–4: high, 5: medium, 6–9: low
    @objc optional var flagged: Bool { get } // Whether the reminder is flagged
    @objc optional func show() -> Any // Show an object in the Reminders UI
    @objc optional func setName(_ name: String!) // The name of the reminder
    @objc optional func setBody(_ body: String!) // The notes attached to the reminder
    @objc optional func setCompleted(_ completed: Bool) // Whether the reminder is completed
    @objc optional func setCompletionDate(_ completionDate: Date!) // The completion date of the reminder
    @objc optional func setDueDate(_ dueDate: Date!) // The due date of the reminder; will set both date and time
    @objc optional func setAlldayDueDate(_ alldayDueDate: Date!) // The all-day due date of the reminder; will only set a date
    @objc optional func setRemindMeDate(_ remindMeDate: Date!) // The remind date of the reminder
    @objc optional func setPriority(_ priority: Int) // The priority of the reminder; 0: no priority, 1–4: high, 5: medium, 6–9: low
    @objc optional func setFlagged(_ flagged: Bool) // Whether the reminder is flagged
}
extension SBObject: RemindersReminder {}

