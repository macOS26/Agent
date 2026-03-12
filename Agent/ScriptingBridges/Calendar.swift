// MARK: CalendarSaveOptions
@objc public enum CalendarSaveOptions : AEKeyword {
    case yes = 0x79657320 /* b'yes ' */
    case no = 0x6e6f2020 /* b'no  ' */
    case ask = 0x61736b20 /* b'ask ' */
}

// MARK: CalendarPrintingErrorHandling
@objc public enum CalendarPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* b'lwst' */
    case detailed = 0x6c776474 /* b'lwdt' */
}

// MARK: CalendarParticipationStatus
@objc public enum CalendarParticipationStatus : AEKeyword {
    case unknown = 0x45366e61 /* b'E6na' */
    case accepted = 0x45366170 /* b'E6ap' */
    case declined = 0x45366470 /* b'E6dp' */
    case tentative = 0x45367470 /* b'E6tp' */
}

// MARK: CalendarEventStatus
@objc public enum CalendarEventStatus : AEKeyword {
    case cancelled = 0x45346361 /* b'E4ca' */
    case confirmed = 0x4534636e /* b'E4cn' */
    case none = 0x45346e6f /* b'E4no' */
    case tentative = 0x45347465 /* b'E4te' */
}

// MARK: CalendarCalendarPriority
@objc public enum CalendarCalendarPriority : AEKeyword {
    case noPriority = 0x74647030 /* b'tdp0' */
    case lowPriority = 0x74647039 /* b'tdp9' */
    case mediumPriority = 0x74647035 /* b'tdp5' */
    case highPriority = 0x74647031 /* b'tdp1' */
}

// MARK: CalendarViewType
@objc public enum CalendarViewType : AEKeyword {
    case dayView = 0x45356461 /* b'E5da' */
    case weekView = 0x45357765 /* b'E5we' */
    case monthView = 0x45356d6f /* b'E5mo' */
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
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
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
    @objc optional var document: CalendarDocument { get } // The document whose contents are displayed in the window.
    @objc optional func setIndex(_ index: Int) // The index of the window, ordered front to back.
    @objc optional func setBounds(_ bounds: NSRect) // The bounding rectangle of the window.
    @objc optional func setMiniaturized(_ miniaturized: Bool) // Is the window minimized right now?
    @objc optional func setVisible(_ visible: Bool) // Is the window visible right now?
    @objc optional func setZoomed(_ zoomed: Bool) // Is the window zoomed right now?
}
extension SBObject: CalendarWindow {}

// MARK: CalendarCalendar
@objc public protocol CalendarCalendar: SBObjectProtocol, CalendarGenericMethods {
    @objc optional func events() -> SBElementArray
    @objc optional var name: String { get } // This is the calendar title.
    @objc optional var color: NSColor { get } // The calendar color.
    @objc optional var calendarIdentifier: String { get } // An unique calendar key
    @objc optional var writable: Bool { get } // This is the calendar title.
    @objc optional var objectDescription: String { get } // This is the calendar description.
    @objc optional func setName(_ name: String!) // This is the calendar title.
    @objc optional func setColor(_ color: NSColor!) // The calendar color.
    @objc optional func setObjectDescription(_ objectDescription: String!) // This is the calendar description.
}
extension SBObject: CalendarCalendar {}

// MARK: CalendarDisplayAlarm
@objc public protocol CalendarDisplayAlarm: SBObjectProtocol, CalendarGenericMethods {
    @objc optional var triggerInterval: Int { get } // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
    @objc optional var triggerDate: Date { get } // An absolute alarm date.
    @objc optional func setTriggerInterval(_ triggerInterval: Int) // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
    @objc optional func setTriggerDate(_ triggerDate: Date!) // An absolute alarm date.
}
extension SBObject: CalendarDisplayAlarm {}

// MARK: CalendarMailAlarm
@objc public protocol CalendarMailAlarm: SBObjectProtocol, CalendarGenericMethods {
    @objc optional var triggerInterval: Int { get } // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
    @objc optional var triggerDate: Date { get } // An absolute alarm date.
    @objc optional func setTriggerInterval(_ triggerInterval: Int) // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
    @objc optional func setTriggerDate(_ triggerDate: Date!) // An absolute alarm date.
}
extension SBObject: CalendarMailAlarm {}

// MARK: CalendarSoundAlarm
@objc public protocol CalendarSoundAlarm: SBObjectProtocol, CalendarGenericMethods {
    @objc optional var triggerInterval: Int { get } // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
    @objc optional var triggerDate: Date { get } // An absolute alarm date.
    @objc optional var soundName: String { get } // The system sound name to be used for the alarm
    @objc optional var soundFile: String { get } // The (POSIX) path to the sound file to be used for the alarm
    @objc optional func setTriggerInterval(_ triggerInterval: Int) // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
    @objc optional func setTriggerDate(_ triggerDate: Date!) // An absolute alarm date.
    @objc optional func setSoundName(_ soundName: String!) // The system sound name to be used for the alarm
    @objc optional func setSoundFile(_ soundFile: String!) // The (POSIX) path to the sound file to be used for the alarm
}
extension SBObject: CalendarSoundAlarm {}

// MARK: CalendarOpenFileAlarm
@objc public protocol CalendarOpenFileAlarm: SBObjectProtocol, CalendarGenericMethods {
    @objc optional var triggerInterval: Int { get } // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
    @objc optional var triggerDate: Date { get } // An absolute alarm date.
    @objc optional var filepath: String { get } // The (POSIX) path to be opened by the alarm
    @objc optional func setTriggerInterval(_ triggerInterval: Int) // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
    @objc optional func setTriggerDate(_ triggerDate: Date!) // An absolute alarm date.
    @objc optional func setFilepath(_ filepath: String!) // The (POSIX) path to be opened by the alarm
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
    @objc optional func attendees() -> SBElementArray
    @objc optional func displayAlarms() -> SBElementArray
    @objc optional func mailAlarms() -> SBElementArray
    @objc optional func openFileAlarms() -> SBElementArray
    @objc optional func soundAlarms() -> SBElementArray
    @objc optional var objectDescription: String { get } // The events notes.
    @objc optional var startDate: Date { get } // The event start date.
    @objc optional var endDate: Date { get } // The event end date.
    @objc optional var alldayEvent: Bool { get } // True if the event is an all-day event
    @objc optional var recurrence: String { get } // The iCalendar (RFC 2445) string describing the event recurrence, if defined
    @objc optional var sequence: Int { get } // The event version.
    @objc optional var stampDate: Date { get } // The event modification date.
    @objc optional var excludedDates: [Date] { get } // The exception dates.
    @objc optional var status: CalendarEventStatus { get } // The event status.
    @objc optional var summary: String { get } // This is the event summary.
    @objc optional var location: String { get } // This is the event location.
    @objc optional var uid: String { get } // An unique event key.
    @objc optional var url: String { get } // The URL associated to the event.
    @objc optional func setObjectDescription(_ objectDescription: String!) // The events notes.
    @objc optional func setStartDate(_ startDate: Date!) // The event start date.
    @objc optional func setEndDate(_ endDate: Date!) // The event end date.
    @objc optional func setAlldayEvent(_ alldayEvent: Bool) // True if the event is an all-day event
    @objc optional func setRecurrence(_ recurrence: String!) // The iCalendar (RFC 2445) string describing the event recurrence, if defined
    @objc optional func setStampDate(_ stampDate: Date!) // The event modification date.
    @objc optional func setExcludedDates(_ excludedDates: [Date]!) // The exception dates.
    @objc optional func setStatus(_ status: CalendarEventStatus) // The event status.
    @objc optional func setSummary(_ summary: String!) // This is the event summary.
    @objc optional func setLocation(_ location: String!) // This is the event location.
    @objc optional func setUrl(_ url: String!) // The URL associated to the event.
}
extension SBObject: CalendarEvent {}

