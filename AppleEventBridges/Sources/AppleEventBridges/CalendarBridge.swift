@_exported import ScriptingBridgeCommon

// MARK: CalendarSaveOptions
@objc public enum CalendarSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: CalendarPrintingErrorHandling
@objc public enum CalendarPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: CalendarParticipationStatus
@objc public enum CalendarParticipationStatus : AEKeyword {
    case unknown = 0x45366e61 /* No anwser yet */
    case accepted = 0x45366170 /* Invitation has been accepted */
    case declined = 0x45366470 /* Invitation has been declined */
    case tentative = 0x45367470 /* Invitation has been tentatively accepted */
}

// MARK: CalendarEventStatus
@objc public enum CalendarEventStatus : AEKeyword {
    case cancelled = 0x45346361 /* A cancelled event */
    case confirmed = 0x4534636e /* A confirmed event */
    case none = 0x45346e6f /* An event without status */
    case tentative = 0x45347465 /* A tentative event */
}

// MARK: CalendarCalendarPriority
@objc public enum CalendarCalendarPriority : AEKeyword {
    case noPriority = 0x74647030 /* No priority */
    case lowPriority = 0x74647039 /* Low priority */
    case mediumPriority = 0x74647035 /* Medium priority */
    case highPriority = 0x74647031 /* High priority */
}

// MARK: CalendarViewType
@objc public enum CalendarViewType : AEKeyword {
    case dayView = 0x45356461 /* The iCal day view */
    case weekView = 0x45357765 /* The iCal week view */
    case monthView = 0x45356d6f /* The iCal month view */
}

// MARK: CalendarGenericMethods
@objc public protocol CalendarGenericMethods {
    @objc optional func closeSaving(_ saving: CalendarSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
    @objc optional func show() // Show the event or to-do in the calendar window
}

// MARK: CalendarApplication
@objc public protocol CalendarApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: CalendarSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func reloadCalendars() // Tell the application to reload all calendar files contents
    @objc optional func switchViewTo(_ to: CalendarViewType) // Show calendar on the given view
    @objc optional func viewCalendarAt(_ at: Date!) // Show calendar on the given date
    @objc optional func GetURL(_ x: String!) // Subscribe to a remote calendar through a webcal or http URL
    @objc optional func calendars() -> SBElementArray
}
extension SBApplication: CalendarApplication {}

// MARK: CalendarDocument
@objc public protocol CalendarDocument: SBObjectProtocol, CalendarGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
}
extension SBObject: CalendarDocument {}

// MARK: CalendarWindow
@objc public protocol CalendarWindow: SBObjectProtocol, CalendarGenericMethods {
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
    @objc optional var document: CalendarDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: CalendarWindow {}

// MARK: CalendarCalendar
@objc public protocol CalendarCalendar: SBObjectProtocol, CalendarGenericMethods {
    @objc optional var name: String { get } // This is the calendar title.
    @objc optional var color: NSColor { get } // The calendar color.
    @objc optional var calendarIdentifier: String { get } // An unique calendar key
    @objc optional var writable: Bool { get } // This is the calendar title.
    @objc optional var objectDescription: String { get } // This is the calendar description.
    @objc optional func events() -> SBElementArray
}
extension SBObject: CalendarCalendar {}

// MARK: CalendarDisplayAlarm
@objc public protocol CalendarDisplayAlarm: SBObjectProtocol, CalendarGenericMethods {
    @objc optional var triggerInterval: Int { get } // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
    @objc optional var triggerDate: Date { get } // An absolute alarm date.
}
extension SBObject: CalendarDisplayAlarm {}

// MARK: CalendarMailAlarm
@objc public protocol CalendarMailAlarm: SBObjectProtocol, CalendarGenericMethods {
    @objc optional var triggerInterval: Int { get } // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
    @objc optional var triggerDate: Date { get } // An absolute alarm date.
}
extension SBObject: CalendarMailAlarm {}

// MARK: CalendarSoundAlarm
@objc public protocol CalendarSoundAlarm: SBObjectProtocol, CalendarGenericMethods {
    @objc optional var triggerInterval: Int { get } // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
    @objc optional var triggerDate: Date { get } // An absolute alarm date.
    @objc optional var soundName: String { get } // The system sound name to be used for the alarm
    @objc optional var soundFile: String { get } // The (POSIX) path to the sound file to be used for the alarm
}
extension SBObject: CalendarSoundAlarm {}

// MARK: CalendarOpenFileAlarm
@objc public protocol CalendarOpenFileAlarm: SBObjectProtocol, CalendarGenericMethods {
    @objc optional var triggerInterval: Int { get } // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
    @objc optional var triggerDate: Date { get } // An absolute alarm date.
    @objc optional var filepath: String { get } // The (POSIX) path to be opened by the alarm
}
extension SBObject: CalendarOpenFileAlarm {}

// MARK: CalendarAttendee
@objc public protocol CalendarAttendee: SBObjectProtocol, CalendarGenericMethods {
    @objc optional var displayName: String { get } // The first and last name of the attendee.
    @objc optional var email: String { get } // e-mail of the attendee.
    @objc optional var participationStatus: CalendarParticipationStatus { get } // The invitation status for the attendee.
}
extension SBObject: CalendarAttendee {}

// MARK: CalendarEvent
@objc public protocol CalendarEvent: SBObjectProtocol, CalendarGenericMethods {
    @objc optional var objectDescription: String { get } // The events notes.
    @objc optional var startDate: Date { get } // The event start date.
    @objc optional var endDate: Date { get } // The event end date.
    @objc optional var alldayEvent: Bool { get } // True if the event is an all-day event
    @objc optional var recurrence: String { get } // The iCalendar (RFC 2445) string describing the event recurrence, if defined
    @objc optional var sequence: Int { get } // The event version.
    @objc optional var stampDate: Date { get } // The event modification date.
    @objc optional var excludedDates: [Any] { get } // The exception dates.
    @objc optional var status: CalendarEventStatus { get } // The event status.
    @objc optional var summary: String { get } // This is the event summary.
    @objc optional var location: String { get } // This is the event location.
    @objc optional var uid: String { get } // An unique event key.
    @objc optional var url: String { get } // The URL associated to the event.
    @objc optional func attendees() -> SBElementArray
    @objc optional func displayAlarms() -> SBElementArray
    @objc optional func mailAlarms() -> SBElementArray
    @objc optional func openFileAlarms() -> SBElementArray
    @objc optional func soundAlarms() -> SBElementArray
}
extension SBObject: CalendarEvent {}

