@_exported import ScriptingBridgeCommon

// MARK: ContactsSaveOptions
@objc public enum ContactsSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: ContactsPrintingErrorHandling
@objc public enum ContactsPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: ContactsSaveableFileFormat
@objc public enum ContactsSaveableFileFormat : AEKeyword {
    case archive = 0x61626275 /* The native Contacts file format */
}

// MARK: ContactsInstantMessageServiceType
@objc public enum ContactsInstantMessageServiceType : AEKeyword {
    case aim = 0x617a3835
    case facebook = 0x617a3934
    case gaduGadu = 0x617a3836
    case googleTalk = 0x617a3837
    case icq = 0x617a3838
    case jabber = 0x617a3839
    case msn = 0x617a3930
    case qq = 0x617a3931
    case skype = 0x617a3932
    case yahoo = 0x617a3933
}

// MARK: ContactsGenericMethods
@objc public protocol ContactsGenericMethods {
    @objc optional func closeSaving(_ saving: ContactsSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ `in`: URL!, `as`: ContactsSaveableFileFormat) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: ContactsApplication
@objc public protocol ContactsApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional var myCard: ContactsPerson { get } // Returns my Contacts card.
    @objc optional var unsaved: Bool { get } // Does Contacts have any unsaved changes?
    @objc optional var selection: [Any] { get } // Currently selected entries
    @objc optional var defaultCountryCode: Any { get } // Returns the default country code for addresses.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: ContactsSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func save() -> Any // Save all Contacts changes. Also see the unsaved property for the application class.
    @objc optional func groups() -> SBElementArray
    @objc optional func people() -> SBElementArray
}
extension SBApplication: ContactsApplication {}

// MARK: ContactsDocument
@objc public protocol ContactsDocument: SBObjectProtocol, ContactsGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
}
extension SBObject: ContactsDocument {}

// MARK: ContactsWindow
@objc public protocol ContactsWindow: SBObjectProtocol, ContactsGenericMethods {
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
    @objc optional var document: ContactsDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: ContactsWindow {}

// MARK: ContactsAddress
@objc public protocol ContactsAddress: SBObjectProtocol, ContactsGenericMethods {
    @objc optional var city: Any { get } // City part of the address.
    @objc optional var formattedAddress: Any { get } // properly formatted string for this address.
    @objc optional var street: Any { get } // Street part of the address, multiple lines separated by carriage returns.
    @objc optional var zip: Any { get } // Zip or postal code of the address.
    @objc optional var country: Any { get } // Country part of the address.
    @objc optional var label: Any { get } // Label.
    @objc optional var countryCode: Any { get } // Country code part of the address (should be a two character iso country code).
    @objc optional var state: Any { get } // State, Province, or Region part of the address.
    @objc optional func id() -> String // unique identifier for this address.
    @objc optional func setId(_ id: String!)
}
extension SBObject: ContactsAddress {}

// MARK: ContactsContactInfo
@objc public protocol ContactsContactInfo: SBObjectProtocol, ContactsGenericMethods {
    @objc optional var label: Any { get } // Label is the label associated with value like "work", "home", etc.
    @objc optional var value: Any { get } // Value.
    @objc optional func id() -> String // unique identifier for this entry, this is persistent, and stays with the record.
}
extension SBObject: ContactsContactInfo {}

// MARK: ContactsCustomDate
@objc public protocol ContactsCustomDate: ContactsContactInfo {
}
extension SBObject: ContactsCustomDate {}

// MARK: ContactsEmail
@objc public protocol ContactsEmail: ContactsContactInfo {
}
extension SBObject: ContactsEmail {}

// MARK: ContactsEntry
@objc public protocol ContactsEntry: SBObjectProtocol, ContactsGenericMethods {
    @objc optional var modificationDate: Date { get } // when the contact was last modified.
    @objc optional var creationDate: Date { get } // when the contact was created.
    @objc optional var selected: Bool { get } // Is the entry selected?
    @objc optional func id() -> String // unique and persistent identifier for this record.
    @objc optional func addTo(_ to: SBObject!) -> ContactsPerson // Add a child object.
    @objc optional func removeFrom(_ from: SBObject!) -> ContactsPerson // Remove a child object.
}
extension SBObject: ContactsEntry {}

// MARK: ContactsGroup
@objc public protocol ContactsGroup: ContactsEntry {
    @objc optional var name: String { get } // The name of this group.
    @objc optional func groups() -> SBElementArray
    @objc optional func people() -> SBElementArray
}
extension SBObject: ContactsGroup {}

// MARK: ContactsInstantMessage
@objc public protocol ContactsInstantMessage: ContactsContactInfo {
    @objc optional var serviceName: Any { get } // The service name of this instant message address.
    @objc optional var serviceType: Any { get } // The service type of this instant message address.
    @objc optional var userName: Any { get } // The user name of this instant message address.
}
extension SBObject: ContactsInstantMessage {}

// MARK: ContactsPerson
@objc public protocol ContactsPerson: ContactsEntry {
    @objc optional var nickname: Any { get } // The Nickname of this person.
    @objc optional var organization: Any { get } // Organization that employs this person.
    @objc optional var maidenName: Any { get } // The Maiden name of this person.
    @objc optional var suffix: Any { get } // The Suffix of this person.
    @objc optional var vcard: Any { get } // Person information in vCard format, this always returns a card in version 3.0 format.
    @objc optional var homePage: Any { get } // The home page of this person.
    @objc optional var birthDate: Any { get } // The birth date of this person.
    @objc optional var phoneticLastName: Any { get } // The phonetic version of the Last name of this person.
    @objc optional var title: Any { get } // The title of this person.
    @objc optional var phoneticMiddleName: Any { get } // The Phonetic version of the Middle name of this person.
    @objc optional var department: Any { get } // Department that this person works for.
    @objc optional var image: Any { get } // Image for person.
    @objc optional var name: String { get } // First/Last name of the person, uses the name display order preference setting in Contacts.
    @objc optional var note: Any { get } // Notes for this person.
    @objc optional var company: Bool { get } // Is the current record a company or a person.
    @objc optional var middleName: Any { get } // The Middle name of this person.
    @objc optional var phoneticFirstName: Any { get } // The phonetic version of the First name of this person.
    @objc optional var jobTitle: Any { get } // The job title of this person.
    @objc optional var lastName: Any { get } // The Last name of this person.
    @objc optional var firstName: Any { get } // The First name of this person.
    @objc optional func urls() -> SBElementArray
    @objc optional func addresses() -> SBElementArray
    @objc optional func phones() -> SBElementArray
    @objc optional func groups() -> SBElementArray
    @objc optional func customDates() -> SBElementArray
    @objc optional func instantMessages() -> SBElementArray
    @objc optional func socialProfiles() -> SBElementArray
    @objc optional func relatedNames() -> SBElementArray
    @objc optional func emails() -> SBElementArray
}
extension SBObject: ContactsPerson {}

// MARK: ContactsPhone
@objc public protocol ContactsPhone: ContactsContactInfo {
}
extension SBObject: ContactsPhone {}

// MARK: ContactsRelatedName
@objc public protocol ContactsRelatedName: ContactsContactInfo {
}
extension SBObject: ContactsRelatedName {}

// MARK: ContactsSocialProfile
@objc public protocol ContactsSocialProfile: SBObjectProtocol, ContactsGenericMethods {
    @objc optional var serviceName: Any { get } // The service name of this social profile.
    @objc optional var userName: Any { get } // The username used with this social profile.
    @objc optional var userIdentifier: Any { get } // A service-specific identifier used with this social profile.
    @objc optional var url: Any { get } // The URL of this social profile.
    @objc optional func id() -> String // The persistent unique identifier for this profile.
}
extension SBObject: ContactsSocialProfile {}

// MARK: ContactsUrl
@objc public protocol ContactsUrl: ContactsContactInfo {
}
extension SBObject: ContactsUrl {}

