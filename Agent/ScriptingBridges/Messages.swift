// MARK: MessagesSaveOptions
@objc public enum MessagesSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: MessagesPrintingErrorHandling
@objc public enum MessagesPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: MessagesServiceType
@objc public enum MessagesServiceType : AEKeyword {
    case sms = 0x73736d73
    case iMessage = 0x73696d73
    case rcs = 0x73726373
}

// MARK: MessagesDirection
@objc public enum MessagesDirection : AEKeyword {
    case incoming = 0x46546963
    case outgoing = 0x46546f67
}

// MARK: MessagesTransferStatus
@objc public enum MessagesTransferStatus : AEKeyword {
    case preparing = 0x46547370
    case waiting = 0x46547377
    case transferring = 0x46547367
    case finalizing = 0x4654737a
    case finished = 0x46547366
    case failed = 0x46547365
}

// MARK: MessagesConnectionStatus
@objc public enum MessagesConnectionStatus : AEKeyword {
    case disconnecting = 0x64636e67
    case connected = 0x636f6e6e
    case connecting = 0x636f6e67
    case disconnected = 0x64636f6e
}

// MARK: MessagesGenericMethods
@objc public protocol MessagesGenericMethods {
    @objc optional func closeSaving(_ saving: MessagesSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ `in`: URL!, `as`: Any!) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: MessagesApplication
@objc public protocol MessagesApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: MessagesSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func send(_ x: Any!, to: Any!) // Sends a message to a participant or to a chat.
    @objc optional func login() // Login to all accounts.
    @objc optional func logout() // Logout of all accounts.
    @objc optional func participants() -> SBElementArray
    @objc optional func accounts() -> SBElementArray
    @objc optional func fileTransfers() -> SBElementArray
    @objc optional func chats() -> SBElementArray
}
extension SBApplication: MessagesApplication {}

// MARK: MessagesDocument
@objc public protocol MessagesDocument: SBObjectProtocol, MessagesGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
}
extension SBObject: MessagesDocument {}

// MARK: MessagesWindow
@objc public protocol MessagesWindow: SBObjectProtocol, MessagesGenericMethods {
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
    @objc optional var document: MessagesDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: MessagesWindow {}

// MARK: MessagesParticipant
@objc public protocol MessagesParticipant: SBObjectProtocol, MessagesGenericMethods {
    @objc optional var account: MessagesAccount { get } // The account for this participant.
    @objc optional var name: String { get } // The participant's name as it appears in the participant list.
    @objc optional var handle: String { get } // The participant's handle.
    @objc optional var firstName: String { get } // The first name from this participan's Contacts card, if available
    @objc optional var lastName: String { get } // The last name from this participant's Contacts card, if available
    @objc optional var fullName: String { get } // The full name from this participant's Contacts card, if available
    @objc optional func id() -> String // The participant's unique identifier. For example: 01234567-89AB-CDEF-0123-456789ABCDEF:+11234567890
}
extension SBObject: MessagesParticipant {}

// MARK: MessagesAccount
@objc public protocol MessagesAccount: SBObjectProtocol, MessagesGenericMethods {
    @objc optional var objectDescription: String { get } // The name of this account as defined in Account preferences description field
    @objc optional var enabled: Bool { get } // Is the account enabled?
    @objc optional var connectionStatus: MessagesConnectionStatus { get } // The connection status for this account.
    @objc optional var serviceType: MessagesServiceType { get } // The type of service for this account
    @objc optional func chats() -> SBElementArray
    @objc optional func participants() -> SBElementArray
    @objc optional func id() -> String // A unique identifier for this account.
}
extension SBObject: MessagesAccount {}

// MARK: MessagesChat
@objc public protocol MessagesChat: SBObjectProtocol, MessagesGenericMethods {
    @objc optional var name: String { get } // The chat's name as it appears in the chat list.
    @objc optional var account: MessagesAccount { get } // The account which is participating in this chat.
    @objc optional func participants() -> SBElementArray
    @objc optional func id() -> String // A guid identifier for this chat.
}
extension SBObject: MessagesChat {}

// MARK: MessagesFileTransfer
@objc public protocol MessagesFileTransfer: SBObjectProtocol, MessagesGenericMethods {
    @objc optional var name: String { get } // The name of this file
    @objc optional var filePath: URL { get } // The local path to this file transfer
    @objc optional var direction: MessagesDirection { get } // The direction in which this file is being sent
    @objc optional var account: MessagesAccount { get } // The account on which this file transfer is taking place
    @objc optional var participant: MessagesParticipant { get } // The other participatant in this file transfer
    @objc optional var fileSize: Int { get } // The total size in bytes of the completed file transfer
    @objc optional var fileProgress: Int { get } // The number of bytes that have been transferred
    @objc optional var transferStatus: MessagesTransferStatus { get } // The current status of this file transfer
    @objc optional var started: Date { get } // The date that this file transfer started
    @objc optional func id() -> String // The guid for this file transfer
}
extension SBObject: MessagesFileTransfer {}

