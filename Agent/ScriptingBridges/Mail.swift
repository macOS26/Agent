// MARK: MailSaveOptions
@objc public enum MailSaveOptions : AEKeyword {
    case yes = 0x79657320 /* b'yes ' */
    case no = 0x6e6f2020 /* b'no  ' */
    case ask = 0x61736b20 /* b'ask ' */
}

// MARK: MailPrintingErrorHandling
@objc public enum MailPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* b'lwst' */
    case detailed = 0x6c776474 /* b'lwdt' */
}

// MARK: MailSaveableFileFormat
@objc public enum MailSaveableFileFormat : AEKeyword {
    case nativeFormat = 0x6974656d /* b'item' */
}

// MARK: MailDefaultMessageFormat
@objc public enum MailDefaultMessageFormat : AEKeyword {
    case plainFormat = 0x646d7074 /* b'dmpt' */
    case richFormat = 0x646d7274 /* b'dmrt' */
}

// MARK: MailQuotingColor
@objc public enum MailQuotingColor : AEKeyword {
    case blue = 0x6363626c /* b'ccbl' */
    case green = 0x63636772 /* b'ccgr' */
    case orange = 0x63636f72 /* b'ccor' */
    case other = 0x63636f74 /* b'ccot' */
    case purple = 0x63637075 /* b'ccpu' */
    case red = 0x63637265 /* b'ccre' */
    case yellow = 0x63637965 /* b'ccye' */
}

// MARK: MailViewerColumns
@objc public enum MailViewerColumns : AEKeyword {
    case attachmentsColumn = 0x65636174 /* b'ecat' */
    case messageColor = 0x6563636c /* b'eccl' */
    case dateReceivedColumn = 0x65636472 /* b'ecdr' */
    case dateSentColumn = 0x65636473 /* b'ecds' */
    case flagsColumn = 0x6563666c /* b'ecfl' */
    case fromColumn = 0x65636672 /* b'ecfr' */
    case mailboxColumn = 0x65636d62 /* b'ecmb' */
    case messageStatusColumn = 0x65636d73 /* b'ecms' */
    case numberColumn = 0x65636e6d /* b'ecnm' */
    case sizeColumn = 0x6563737a /* b'ecsz' */
    case subjectColumn = 0x65637375 /* b'ecsu' */
    case toColumn = 0x6563746f /* b'ecto' */
    case dateLastSavedColumn = 0x65636c73 /* b'ecls' */
}

// MARK: MailAuthentication
@objc public enum MailAuthentication : AEKeyword {
    case password = 0x61786374 /* b'axct' */
    case apop = 0x6161706f /* b'aapo' */
    case kerberos5 = 0x61786b35 /* b'axk5' */
    case ntlm = 0x61786e74 /* b'axnt' */
    case md5 = 0x61786d64 /* b'axmd' */
    case external = 0x61657874 /* b'aext' */
    case appleToken = 0x61746f6b /* b'atok' */
    case none = 0x63636e6f /* b'ccno' */
}

// MARK: MailHighlightColors
@objc public enum MailHighlightColors : AEKeyword {
    case blue = 0x6363626c /* b'ccbl' */
    case gray = 0x63636779 /* b'ccgy' */
    case green = 0x63636772 /* b'ccgr' */
    case none = 0x63636e6f /* b'ccno' */
    case orange = 0x63636f72 /* b'ccor' */
    case other = 0x63636f74 /* b'ccot' */
    case purple = 0x63637075 /* b'ccpu' */
    case red = 0x63637265 /* b'ccre' */
    case yellow = 0x63637965 /* b'ccye' */
}

// MARK: MailMessageCachingPolicy
@objc public enum MailMessageCachingPolicy : AEKeyword {
    case doNotKeepCopiesOfAnyMessages = 0x78396e6f /* b'x9no' */
    case onlyMessagesIHaveRead = 0x78397772 /* b'x9wr' */
    case allMessagesButOmitAttachments = 0x7839626f /* b'x9bo' */
    case allMessagesAndTheirAttachments = 0x7839616c /* b'x9al' */
}

// MARK: MailRuleQualifier
@objc public enum MailRuleQualifier : AEKeyword {
    case beginsWithValue = 0x72716277 /* b'rqbw' */
    case doesContainValue = 0x7271636f /* b'rqco' */
    case doesNotContainValue = 0x7271646e /* b'rqdn' */
    case endsWithValue = 0x72716577 /* b'rqew' */
    case equalToValue = 0x72716965 /* b'rqie' */
    case lessThanValue = 0x72716c74 /* b'rqlt' */
    case greaterThanValue = 0x72716774 /* b'rqgt' */
    case none = 0x72716e6f /* b'rqno' */
}

// MARK: MailRuleType
@objc public enum MailRuleType : AEKeyword {
    case account = 0x74616363 /* b'tacc' */
    case anyRecipient = 0x74616e72 /* b'tanr' */
    case ccHeader = 0x74636363 /* b'tccc' */
    case matchesEveryMessage = 0x7465766d /* b'tevm' */
    case fromHeader = 0x7466726f /* b'tfro' */
    case headerKey = 0x7468646b /* b'thdk' */
    case messageContent = 0x746d6563 /* b'tmec' */
    case messageIsJunkMail = 0x746d696a /* b'tmij' */
    case senderIsInMyContacts = 0x74736969 /* b'tsii' */
    case senderIsInMyPreviousRecipients = 0x74736168 /* b'tsah' */
    case senderIsMemberOfGroup = 0x7473696d /* b'tsim' */
    case senderIsNotInMyContacts = 0x7473696e /* b'tsin' */
    case senderIsNotInMyPreviousRecipients = 0x746e6168 /* b'tnah' */
    case senderIsNotMemberOfGroup = 0x74736967 /* b'tsig' */
    // case senderIsVIP = 0x74736967 -- duplicate raw value of senderIsNotMemberOfGroup
    case subjectHeader = 0x74737562 /* b'tsub' */
    case toHeader = 0x74746f6f /* b'ttoo' */
    case toOrCcHeader = 0x74746f63 /* b'ttoc' */
    case attachmentType = 0x74617474 /* b'tatt' */
}

// MARK: MailTypeOfAccount
@objc public enum MailTypeOfAccount : AEKeyword {
    case pop = 0x6574706f /* b'etpo' */
    case smtp = 0x6574736d /* b'etsm' */
    case imap = 0x6574696d /* b'etim' */
    case iCloud = 0x65746974 /* b'etit' */
    case unknown = 0x6574756e /* b'etun' */
}

// MARK: MailGenericMethods
@objc public protocol MailGenericMethods {
    @objc optional func closeSaving(_ saving: MailSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ in_: URL!, as: MailSaveableFileFormat) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: MailApplication
@objc public protocol MailApplication: SBApplicationProtocol {
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: MailSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func checkForNewMailFor(_ for_: MailAccount!) // Triggers a check for email.
    @objc optional func extractNameFrom(_ x: String!) -> String // Command to get the full name out of a fully specified email address. E.g. Calling this with "John Doe <jdoe@example.com>" as the direct object would return "John Doe"
    @objc optional func extractAddressFrom(_ x: String!) -> String // Command to get just the email address of a fully specified email address. E.g. Calling this with "John Doe <jdoe@example.com>" as the direct object would return "jdoe@example.com"
    @objc optional func GetURL(_ x: String!) // Opens a mailto URL.
    @objc optional func importMailMailboxAt(_ at: URL!) // Imports a mailbox created by Mail.
    @objc optional func mailto(_ x: String!) // Opens a mailto URL.
    @objc optional func performMailActionWithMessages(_ x: [MailMessage]!, inMailboxes: MailMailbox!, forRule: MailRule!) // Script handler invoked by rules and menus that execute AppleScripts. The direct parameter of this handler is a list of messages being acted upon.
    @objc optional func synchronizeWith(_ with: MailAccount!) // Command to trigger synchronizing of an IMAP account with the server.
    @objc optional func accounts() -> SBElementArray
    @objc optional func popAccounts() -> SBElementArray
    @objc optional func imapAccounts() -> SBElementArray
    @objc optional func iCloudAccounts() -> SBElementArray
    @objc optional func smtpServers() -> SBElementArray
    @objc optional func outgoingMessages() -> SBElementArray
    @objc optional func mailboxes() -> SBElementArray
    @objc optional func messageViewers() -> SBElementArray
    @objc optional func rules() -> SBElementArray
    @objc optional func signatures() -> SBElementArray
    @objc optional var alwaysBccMyself: Bool { get } // Indicates whether you will be included in the Bcc: field of messages which you are composing
    @objc optional var alwaysCcMyself: Bool { get } // Indicates whether you will be included in the Cc: field of messages which you are composing
    @objc optional var selection: [MailMessage] { get } // List of messages that the user has selected
    @objc optional var applicationVersion: String { get } // The build number of the application
    @objc optional var fetchInterval: Int { get } // The interval (in minutes) between automatic fetches of new mail, -1 means to use an automatically determined interval
    @objc optional var backgroundActivityCount: Int { get } // Number of background activities currently running in Mail, according to the Activity window
    @objc optional var chooseSignatureWhenComposing: Bool { get } // Indicates whether user can choose a signature directly in a new compose window
    @objc optional var colorQuotedText: Bool { get } // Indicates whether quoted text should be colored
    @objc optional var defaultMessageFormat: MailDefaultMessageFormat { get } // Default format for messages being composed or message replies
    @objc optional var downloadHtmlAttachments: Bool { get } // Indicates whether images and attachments in HTML messages should be downloaded and displayed
    @objc optional var draftsMailbox: MailMailbox { get } // The top level Drafts mailbox
    @objc optional var expandGroupAddresses: Bool { get } // Indicates whether group addresses will be expanded when entered into the address fields of a new compose message
    @objc optional var fixedWidthFont: String { get } // Font for plain text messages, only used if 'use fixed width font' is set to true
    @objc optional var fixedWidthFontSize: Double { get } // Font size for plain text messages, only used if 'use fixed width font' is set to true
    @objc optional var inbox: MailMailbox { get } // The top level In mailbox
    @objc optional var includeAllOriginalMessageText: Bool { get } // Indicates whether all of the original message will be quoted or only the text you have selected (if any)
    @objc optional var quoteOriginalMessage: Bool { get } // Indicates whether the text of the original message will be included in replies
    @objc optional var checkSpellingWhileTyping: Bool { get } // Indicates whether spelling will be checked automatically in messages being composed
    @objc optional var junkMailbox: MailMailbox { get } // The top level Junk mailbox
    @objc optional var levelOneQuotingColor: MailQuotingColor { get } // Color for quoted text with one level of indentation
    @objc optional var levelTwoQuotingColor: MailQuotingColor { get } // Color for quoted text with two levels of indentation
    @objc optional var levelThreeQuotingColor: MailQuotingColor { get } // Color for quoted text with three levels of indentation
    @objc optional var messageFont: String { get } // Font for messages (proportional font)
    @objc optional var messageFontSize: Double { get } // Font size for messages (proportional font)
    @objc optional var messageListFont: String { get } // Font for message list
    @objc optional var messageListFontSize: Double { get } // Font size for message list
    @objc optional var newMailSound: String { get } // Name of new mail sound or 'None' if no sound is selected
    @objc optional var outbox: MailMailbox { get } // The top level Out mailbox
    @objc optional var shouldPlayOtherMailSounds: Bool { get } // Indicates whether sounds will be played for various things such as when a messages is sent or if no mail is found when manually checking for new mail or if there is a fetch error
    @objc optional var sameReplyFormat: Bool { get } // Indicates whether replies will be in the same text format as the message to which you are replying
    @objc optional var selectedSignature: String { get } // Name of current selected signature (or 'randomly', 'sequentially', or 'none')
    @objc optional var sentMailbox: MailMailbox { get } // The top level Sent mailbox
    @objc optional var fetchesAutomatically: Bool { get } // Indicates whether mail will automatically be fetched at a specific interval
    @objc optional var highlightSelectedConversation: Bool { get } // Indicates whether messages in conversations should be highlighted in the Mail viewer window when not grouped
    @objc optional var trashMailbox: MailMailbox { get } // The top level Trash mailbox
    @objc optional var useAddressCompletion: Bool { get } // This always returns true, and setting it doesn't do anything (deprecated)
    @objc optional var useFixedWidthFont: Bool { get } // Should fixed-width font be used for plain text messages?
    @objc optional var primaryEmail: String { get } // The user's primary email address
    @objc optional func setAlwaysBccMyself(_ alwaysBccMyself: Bool) // Indicates whether you will be included in the Bcc: field of messages which you are composing
    @objc optional func setAlwaysCcMyself(_ alwaysCcMyself: Bool) // Indicates whether you will be included in the Cc: field of messages which you are composing
    @objc optional func setFetchInterval(_ fetchInterval: Int) // The interval (in minutes) between automatic fetches of new mail, -1 means to use an automatically determined interval
    @objc optional func setChooseSignatureWhenComposing(_ chooseSignatureWhenComposing: Bool) // Indicates whether user can choose a signature directly in a new compose window
    @objc optional func setColorQuotedText(_ colorQuotedText: Bool) // Indicates whether quoted text should be colored
    @objc optional func setDefaultMessageFormat(_ defaultMessageFormat: MailDefaultMessageFormat) // Default format for messages being composed or message replies
    @objc optional func setDownloadHtmlAttachments(_ downloadHtmlAttachments: Bool) // Indicates whether images and attachments in HTML messages should be downloaded and displayed
    @objc optional func setExpandGroupAddresses(_ expandGroupAddresses: Bool) // Indicates whether group addresses will be expanded when entered into the address fields of a new compose message
    @objc optional func setFixedWidthFont(_ fixedWidthFont: String!) // Font for plain text messages, only used if 'use fixed width font' is set to true
    @objc optional func setFixedWidthFontSize(_ fixedWidthFontSize: Double) // Font size for plain text messages, only used if 'use fixed width font' is set to true
    @objc optional func setIncludeAllOriginalMessageText(_ includeAllOriginalMessageText: Bool) // Indicates whether all of the original message will be quoted or only the text you have selected (if any)
    @objc optional func setQuoteOriginalMessage(_ quoteOriginalMessage: Bool) // Indicates whether the text of the original message will be included in replies
    @objc optional func setCheckSpellingWhileTyping(_ checkSpellingWhileTyping: Bool) // Indicates whether spelling will be checked automatically in messages being composed
    @objc optional func setLevelOneQuotingColor(_ levelOneQuotingColor: MailQuotingColor) // Color for quoted text with one level of indentation
    @objc optional func setLevelTwoQuotingColor(_ levelTwoQuotingColor: MailQuotingColor) // Color for quoted text with two levels of indentation
    @objc optional func setLevelThreeQuotingColor(_ levelThreeQuotingColor: MailQuotingColor) // Color for quoted text with three levels of indentation
    @objc optional func setMessageFont(_ messageFont: String!) // Font for messages (proportional font)
    @objc optional func setMessageFontSize(_ messageFontSize: Double) // Font size for messages (proportional font)
    @objc optional func setMessageListFont(_ messageListFont: String!) // Font for message list
    @objc optional func setMessageListFontSize(_ messageListFontSize: Double) // Font size for message list
    @objc optional func setNewMailSound(_ newMailSound: String!) // Name of new mail sound or 'None' if no sound is selected
    @objc optional func setShouldPlayOtherMailSounds(_ shouldPlayOtherMailSounds: Bool) // Indicates whether sounds will be played for various things such as when a messages is sent or if no mail is found when manually checking for new mail or if there is a fetch error
    @objc optional func setSameReplyFormat(_ sameReplyFormat: Bool) // Indicates whether replies will be in the same text format as the message to which you are replying
    @objc optional func setSelectedSignature(_ selectedSignature: String!) // Name of current selected signature (or 'randomly', 'sequentially', or 'none')
    @objc optional func setFetchesAutomatically(_ fetchesAutomatically: Bool) // Indicates whether mail will automatically be fetched at a specific interval
    @objc optional func setHighlightSelectedConversation(_ highlightSelectedConversation: Bool) // Indicates whether messages in conversations should be highlighted in the Mail viewer window when not grouped
    @objc optional func setUseAddressCompletion(_ useAddressCompletion: Bool) // This always returns true, and setting it doesn't do anything (deprecated)
    @objc optional func setUseFixedWidthFont(_ useFixedWidthFont: Bool) // Should fixed-width font be used for plain text messages?
}
extension SBApplication: MailApplication {}

// MARK: MailDocument
@objc public protocol MailDocument: SBObjectProtocol, MailGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
}
extension SBObject: MailDocument {}

// MARK: MailWindow
@objc public protocol MailWindow: SBObjectProtocol, MailGenericMethods {
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
    @objc optional var document: MailDocument { get } // The document whose contents are displayed in the window.
    @objc optional func setIndex(_ index: Int) // The index of the window, ordered front to back.
    @objc optional func setBounds(_ bounds: NSRect) // The bounding rectangle of the window.
    @objc optional func setMiniaturized(_ miniaturized: Bool) // Is the window minimized right now?
    @objc optional func setVisible(_ visible: Bool) // Is the window visible right now?
    @objc optional func setZoomed(_ zoomed: Bool) // Is the window zoomed right now?
}
extension SBObject: MailWindow {}

// MARK: MailRichText
@objc public protocol MailRichText: SBObjectProtocol, MailGenericMethods {
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func attachments() -> SBElementArray
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: NSNumber { get } // The size in points of the first character.
    @objc optional func setColor(_ color: NSColor!) // The color of the first character.
    @objc optional func setFont(_ font: String!) // The name of the font of the first character.
    @objc optional func setSize(_ size: NSNumber!) // The size in points of the first character.
}
extension SBObject: MailRichText {}

// MARK: MailAttachment
@objc public protocol MailAttachment: MailRichText {
    @objc optional var fileName: URL { get } // The file for the attachment
    @objc optional func setFileName(_ fileName: URL!) // The file for the attachment
}
extension SBObject: MailAttachment {}

// MARK: MailParagraph
@objc public protocol MailParagraph: SBObjectProtocol, MailGenericMethods {
    @objc optional func words() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func attachments() -> SBElementArray
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: NSNumber { get } // The size in points of the first character.
    @objc optional func setColor(_ color: NSColor!) // The color of the first character.
    @objc optional func setFont(_ font: String!) // The name of the font of the first character.
    @objc optional func setSize(_ size: NSNumber!) // The size in points of the first character.
}
extension SBObject: MailParagraph {}

// MARK: MailWord
@objc public protocol MailWord: SBObjectProtocol, MailGenericMethods {
    @objc optional func characters() -> SBElementArray
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func attachments() -> SBElementArray
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: NSNumber { get } // The size in points of the first character.
    @objc optional func setColor(_ color: NSColor!) // The color of the first character.
    @objc optional func setFont(_ font: String!) // The name of the font of the first character.
    @objc optional func setSize(_ size: NSNumber!) // The size in points of the first character.
}
extension SBObject: MailWord {}

// MARK: MailCharacter
@objc public protocol MailCharacter: SBObjectProtocol, MailGenericMethods {
    @objc optional func attributeRuns() -> SBElementArray
    @objc optional func attachments() -> SBElementArray
    @objc optional var color: NSColor { get } // The color of the character.
    @objc optional var font: String { get } // The name of the font of the character.
    @objc optional var size: NSNumber { get } // The size in points of the character.
    @objc optional func setColor(_ color: NSColor!) // The color of the character.
    @objc optional func setFont(_ font: String!) // The name of the font of the character.
    @objc optional func setSize(_ size: NSNumber!) // The size in points of the character.
}
extension SBObject: MailCharacter {}

// MARK: MailAttributeRun
@objc public protocol MailAttributeRun: SBObjectProtocol, MailGenericMethods {
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func attachments() -> SBElementArray
    @objc optional var color: NSColor { get } // The color of the first character.
    @objc optional var font: String { get } // The name of the font of the first character.
    @objc optional var size: NSNumber { get } // The size in points of the first character.
    @objc optional func setColor(_ color: NSColor!) // The color of the first character.
    @objc optional func setFont(_ font: String!) // The name of the font of the first character.
    @objc optional func setSize(_ size: NSNumber!) // The size in points of the first character.
}
extension SBObject: MailAttributeRun {}

// MARK: MailOutgoingMessage
@objc public protocol MailOutgoingMessage: SBObjectProtocol, MailGenericMethods {
    @objc optional func bccRecipients() -> SBElementArray
    @objc optional func ccRecipients() -> SBElementArray
    @objc optional func recipients() -> SBElementArray
    @objc optional func toRecipients() -> SBElementArray
    @objc optional var sender: String { get } // The sender of the message
    @objc optional var subject: String { get } // The subject of the message
    @objc optional var content: MailRichText { get } // The contents of the message
    @objc optional var visible: Bool { get } // Controls whether the message window is shown on the screen. The default is false
    @objc optional var messageSignature: Any { get } // The signature of the message
    @objc optional func id() -> Int // The unique identifier of the message
    @objc optional func send() -> Bool // Sends a message.
    @objc optional func setSender(_ sender: String!) // The sender of the message
    @objc optional func setSubject(_ subject: String!) // The subject of the message
    @objc optional func setContent(_ content: MailRichText!) // The contents of the message
    @objc optional func setVisible(_ visible: Bool) // Controls whether the message window is shown on the screen. The default is false
    @objc optional func setMessageSignature(_ messageSignature: Any!) // The signature of the message
}
extension SBObject: MailOutgoingMessage {}

// MARK: MailMessageViewer
@objc public protocol MailMessageViewer: SBObjectProtocol, MailGenericMethods {
    @objc optional func messages() -> SBElementArray
    @objc optional var draftsMailbox: MailMailbox { get } // The top level Drafts mailbox
    @objc optional var inbox: MailMailbox { get } // The top level In mailbox
    @objc optional var junkMailbox: MailMailbox { get } // The top level Junk mailbox
    @objc optional var outbox: MailMailbox { get } // The top level Out mailbox
    @objc optional var sentMailbox: MailMailbox { get } // The top level Sent mailbox
    @objc optional var trashMailbox: MailMailbox { get } // The top level Trash mailbox
    @objc optional var sortColumn: MailViewerColumns { get } // The column that is currently sorted in the viewer
    @objc optional var sortedAscending: Bool { get } // Whether the viewer is sorted ascending or not
    @objc optional var mailboxListVisible: Bool { get } // Controls whether the list of mailboxes is visible or not
    @objc optional var previewPaneIsVisible: Bool { get } // Controls whether the preview pane of the message viewer window is visible or not
    @objc optional var visibleColumns: [NSAppleEventDescriptor] { get } // List of columns that are visible. The subject column and the message status column will always be visible
    @objc optional func id() -> Int // The unique identifier of the message viewer
    @objc optional var visibleMessages: [MailMessage] { get } // List of messages currently being displayed in the viewer
    @objc optional var selectedMessages: [MailMessage] { get } // List of messages currently selected
    @objc optional var selectedMailboxes: [MailMailbox] { get } // List of mailboxes currently selected in the list of mailboxes
    @objc optional var window: MailWindow { get } // The window for the message viewer
    @objc optional func setSortColumn(_ sortColumn: MailViewerColumns) // The column that is currently sorted in the viewer
    @objc optional func setSortedAscending(_ sortedAscending: Bool) // Whether the viewer is sorted ascending or not
    @objc optional func setMailboxListVisible(_ mailboxListVisible: Bool) // Controls whether the list of mailboxes is visible or not
    @objc optional func setPreviewPaneIsVisible(_ previewPaneIsVisible: Bool) // Controls whether the preview pane of the message viewer window is visible or not
    @objc optional func setVisibleColumns(_ visibleColumns: [NSAppleEventDescriptor]!) // List of columns that are visible. The subject column and the message status column will always be visible
    @objc optional func setVisibleMessages(_ visibleMessages: [MailMessage]!) // List of messages currently being displayed in the viewer
    @objc optional func setSelectedMessages(_ selectedMessages: [MailMessage]!) // List of messages currently selected
    @objc optional func setSelectedMailboxes(_ selectedMailboxes: [MailMailbox]!) // List of mailboxes currently selected in the list of mailboxes
    @objc optional func setWindow(_ window: MailWindow!) // The window for the message viewer
}
extension SBObject: MailMessageViewer {}

// MARK: MailSignature
@objc public protocol MailSignature: SBObjectProtocol, MailGenericMethods {
    @objc optional var content: String { get } // Contents of email signature. If there is a version with fonts and/or styles, that will be returned over the plain text version
    @objc optional var name: String { get } // Name of the signature
    @objc optional func setContent(_ content: String!) // Contents of email signature. If there is a version with fonts and/or styles, that will be returned over the plain text version
    @objc optional func setName(_ name: String!) // Name of the signature
}
extension SBObject: MailSignature {}

// MARK: MailMessage
@objc public protocol MailMessage: SBObjectProtocol, MailGenericMethods {
    @objc optional func bccRecipients() -> SBElementArray
    @objc optional func ccRecipients() -> SBElementArray
    @objc optional func recipients() -> SBElementArray
    @objc optional func toRecipients() -> SBElementArray
    @objc optional func headers() -> SBElementArray
    @objc optional func mailAttachments() -> SBElementArray
    @objc optional func id() -> Int // The unique identifier of the message.
    @objc optional var allHeaders: String { get } // All the headers of the message
    @objc optional var backgroundColor: MailHighlightColors { get } // The background color of the message
    @objc optional var mailbox: MailMailbox { get } // The mailbox in which this message is filed
    @objc optional var content: MailRichText { get } // Contents of an email message
    @objc optional var dateReceived: Date { get } // The date a message was received
    @objc optional var dateSent: Date { get } // The date a message was sent
    @objc optional var deletedStatus: Bool { get } // Indicates whether the message is deleted or not
    @objc optional var flaggedStatus: Bool { get } // Indicates whether the message is flagged or not
    @objc optional var flagIndex: Int { get } // The flag on the message, or -1 if the message is not flagged
    @objc optional var junkMailStatus: Bool { get } // Indicates whether the message has been marked junk or evaluated to be junk by the junk mail filter.
    @objc optional var readStatus: Bool { get } // Indicates whether the message is read or not
    @objc optional var messageId: String { get } // The unique message ID string
    @objc optional var source: String { get } // Raw source of the message
    @objc optional var replyTo: String { get } // The address that replies should be sent to
    @objc optional var messageSize: Int { get } // The size (in bytes) of a message
    @objc optional var sender: String { get } // The sender of the message
    @objc optional var subject: String { get } // The subject of the message
    @objc optional var wasForwarded: Bool { get } // Indicates whether the message was forwarded or not
    @objc optional var wasRedirected: Bool { get } // Indicates whether the message was redirected or not
    @objc optional var wasRepliedTo: Bool { get } // Indicates whether the message was replied to or not
    @objc optional func forwardOpeningWindow(_ openingWindow: Bool) -> MailOutgoingMessage // Creates a forwarded message.
    @objc optional func redirectOpeningWindow(_ openingWindow: Bool) -> MailOutgoingMessage // Creates a redirected message.
    @objc optional func replyOpeningWindow(_ openingWindow: Bool, replyToAll: Bool) -> MailOutgoingMessage // Creates a reply message.
    @objc optional func setBackgroundColor(_ backgroundColor: MailHighlightColors) // The background color of the message
    @objc optional func setMailbox(_ mailbox: MailMailbox!) // The mailbox in which this message is filed
    @objc optional func setDeletedStatus(_ deletedStatus: Bool) // Indicates whether the message is deleted or not
    @objc optional func setFlaggedStatus(_ flaggedStatus: Bool) // Indicates whether the message is flagged or not
    @objc optional func setFlagIndex(_ flagIndex: Int) // The flag on the message, or -1 if the message is not flagged
    @objc optional func setJunkMailStatus(_ junkMailStatus: Bool) // Indicates whether the message has been marked junk or evaluated to be junk by the junk mail filter.
    @objc optional func setReadStatus(_ readStatus: Bool) // Indicates whether the message is read or not
}
extension SBObject: MailMessage {}

// MARK: MailAccount
@objc public protocol MailAccount: SBObjectProtocol, MailGenericMethods {
    @objc optional func mailboxes() -> SBElementArray
    @objc optional var deliveryAccount: Any { get } // The delivery account used when sending mail from this account
    @objc optional var name: String { get } // The name of an account
    @objc optional func id() -> String // The unique identifier of the account
    @objc optional var password: String { get } // Password for this account. Can be set, but not read via scripting
    @objc optional var authentication: MailAuthentication { get } // Preferred authentication scheme for account
    @objc optional var accountType: MailTypeOfAccount { get } // The type of an account
    @objc optional var emailAddresses: [String] { get } // The list of email addresses configured for an account
    @objc optional var fullName: String { get } // The users full name configured for an account
    @objc optional var emptyJunkMessagesFrequency: Int { get } // Number of days before junk messages are deleted (0 = delete on quit, -1 = never delete)
    @objc optional var emptyTrashFrequency: Int { get } // Number of days before messages in the trash are permanently deleted (0 = delete on quit, -1 = never delete)
    @objc optional var emptyJunkMessagesOnQuit: Bool { get } // Indicates whether the messages in the junk messages mailboxes will be deleted on quit
    @objc optional var emptyTrashOnQuit: Bool { get } // Indicates whether the messages in deleted messages mailboxes will be permanently deleted on quit
    @objc optional var enabled: Bool { get } // Indicates whether the account is enabled or not
    @objc optional var userName: String { get } // The user name used to connect to an account
    @objc optional var accountDirectory: URL { get } // The directory where the account stores things on disk
    @objc optional var port: Int { get } // The port used to connect to an account
    @objc optional var serverName: String { get } // The host name used to connect to an account
    @objc optional var moveDeletedMessagesToTrash: Bool { get } // Indicates whether messages that are deleted will be moved to the trash mailbox
    @objc optional var usesSsl: Bool { get } // Indicates whether SSL is enabled for this receiving account
    @objc optional func setDeliveryAccount(_ deliveryAccount: Any!) // The delivery account used when sending mail from this account
    @objc optional func setName(_ name: String!) // The name of an account
    @objc optional func setPassword(_ password: String!) // Password for this account. Can be set, but not read via scripting
    @objc optional func setAuthentication(_ authentication: MailAuthentication) // Preferred authentication scheme for account
    @objc optional func setEmailAddresses(_ emailAddresses: [String]!) // The list of email addresses configured for an account
    @objc optional func setFullName(_ fullName: String!) // The users full name configured for an account
    @objc optional func setEmptyJunkMessagesFrequency(_ emptyJunkMessagesFrequency: Int) // Number of days before junk messages are deleted (0 = delete on quit, -1 = never delete)
    @objc optional func setEmptyTrashFrequency(_ emptyTrashFrequency: Int) // Number of days before messages in the trash are permanently deleted (0 = delete on quit, -1 = never delete)
    @objc optional func setEmptyJunkMessagesOnQuit(_ emptyJunkMessagesOnQuit: Bool) // Indicates whether the messages in the junk messages mailboxes will be deleted on quit
    @objc optional func setEmptyTrashOnQuit(_ emptyTrashOnQuit: Bool) // Indicates whether the messages in deleted messages mailboxes will be permanently deleted on quit
    @objc optional func setEnabled(_ enabled: Bool) // Indicates whether the account is enabled or not
    @objc optional func setUserName(_ userName: String!) // The user name used to connect to an account
    @objc optional func setPort(_ port: Int) // The port used to connect to an account
    @objc optional func setServerName(_ serverName: String!) // The host name used to connect to an account
    @objc optional func setMoveDeletedMessagesToTrash(_ moveDeletedMessagesToTrash: Bool) // Indicates whether messages that are deleted will be moved to the trash mailbox
    @objc optional func setUsesSsl(_ usesSsl: Bool) // Indicates whether SSL is enabled for this receiving account
}
extension SBObject: MailAccount {}

// MARK: MailImapAccount
@objc public protocol MailImapAccount: MailAccount {
    @objc optional var compactMailboxesWhenClosing: Bool { get } // Indicates whether an IMAP mailbox is automatically compacted when you quit Mail or switch to another mailbox
    @objc optional var messageCaching: MailMessageCachingPolicy { get } // Message caching setting for this account
    @objc optional var storeDraftsOnServer: Bool { get } // Indicates whether drafts will be stored on the IMAP server
    @objc optional var storeJunkMailOnServer: Bool { get } // Indicates whether junk mail will be stored on the IMAP server
    @objc optional var storeSentMessagesOnServer: Bool { get } // Indicates whether sent messages will be stored on the IMAP server
    @objc optional var storeDeletedMessagesOnServer: Bool { get } // Indicates whether deleted messages will be stored on the IMAP server
    @objc optional func setCompactMailboxesWhenClosing(_ compactMailboxesWhenClosing: Bool) // Indicates whether an IMAP mailbox is automatically compacted when you quit Mail or switch to another mailbox
    @objc optional func setMessageCaching(_ messageCaching: MailMessageCachingPolicy) // Message caching setting for this account
    @objc optional func setStoreDraftsOnServer(_ storeDraftsOnServer: Bool) // Indicates whether drafts will be stored on the IMAP server
    @objc optional func setStoreJunkMailOnServer(_ storeJunkMailOnServer: Bool) // Indicates whether junk mail will be stored on the IMAP server
    @objc optional func setStoreSentMessagesOnServer(_ storeSentMessagesOnServer: Bool) // Indicates whether sent messages will be stored on the IMAP server
    @objc optional func setStoreDeletedMessagesOnServer(_ storeDeletedMessagesOnServer: Bool) // Indicates whether deleted messages will be stored on the IMAP server
}
extension SBObject: MailImapAccount {}

// MARK: MailICloudAccount
@objc public protocol MailICloudAccount: MailImapAccount {
}
extension SBObject: MailICloudAccount {}

// MARK: MailPopAccount
@objc public protocol MailPopAccount: MailAccount {
    @objc optional var bigMessageWarningSize: Int { get } // If message size (in bytes) is over this amount, Mail will prompt you asking whether you want to download the message (-1 = do not prompt)
    @objc optional var delayedMessageDeletionInterval: Int { get } // Number of days before messages that have been downloaded will be deleted from the server (0 = delete immediately after downloading)
    @objc optional var deleteMailOnServer: Bool { get } // Indicates whether POP account deletes messages on the server after downloading
    @objc optional var deleteMessagesWhenMovedFromInbox: Bool { get } // Indicates whether messages will be deleted from the server when moved from your POP inbox
    @objc optional func setBigMessageWarningSize(_ bigMessageWarningSize: Int) // If message size (in bytes) is over this amount, Mail will prompt you asking whether you want to download the message (-1 = do not prompt)
    @objc optional func setDelayedMessageDeletionInterval(_ delayedMessageDeletionInterval: Int) // Number of days before messages that have been downloaded will be deleted from the server (0 = delete immediately after downloading)
    @objc optional func setDeleteMailOnServer(_ deleteMailOnServer: Bool) // Indicates whether POP account deletes messages on the server after downloading
    @objc optional func setDeleteMessagesWhenMovedFromInbox(_ deleteMessagesWhenMovedFromInbox: Bool) // Indicates whether messages will be deleted from the server when moved from your POP inbox
}
extension SBObject: MailPopAccount {}

// MARK: MailSmtpServer
@objc public protocol MailSmtpServer: SBObjectProtocol, MailGenericMethods {
    @objc optional var name: String { get } // The name of an account
    @objc optional var password: String { get } // Password for this account. Can be set, but not read via scripting
    @objc optional var accountType: MailTypeOfAccount { get } // The type of an account
    @objc optional var authentication: MailAuthentication { get } // Preferred authentication scheme for account
    @objc optional var enabled: Bool { get } // Indicates whether the account is enabled or not
    @objc optional var userName: String { get } // The user name used to connect to an account
    @objc optional var port: Int { get } // The port used to connect to an account
    @objc optional var serverName: String { get } // The host name used to connect to an account
    @objc optional var usesSsl: Bool { get } // Indicates whether SSL is enabled for this receiving account
    @objc optional func setPassword(_ password: String!) // Password for this account. Can be set, but not read via scripting
    @objc optional func setAuthentication(_ authentication: MailAuthentication) // Preferred authentication scheme for account
    @objc optional func setEnabled(_ enabled: Bool) // Indicates whether the account is enabled or not
    @objc optional func setUserName(_ userName: String!) // The user name used to connect to an account
    @objc optional func setPort(_ port: Int) // The port used to connect to an account
    @objc optional func setServerName(_ serverName: String!) // The host name used to connect to an account
    @objc optional func setUsesSsl(_ usesSsl: Bool) // Indicates whether SSL is enabled for this receiving account
}
extension SBObject: MailSmtpServer {}

// MARK: MailMailbox
@objc public protocol MailMailbox: SBObjectProtocol, MailGenericMethods {
    @objc optional func mailboxes() -> SBElementArray
    @objc optional func messages() -> SBElementArray
    @objc optional var name: String { get } // The name of a mailbox
    @objc optional var unreadCount: Int { get } // The number of unread messages in the mailbox
    @objc optional var account: MailAccount { get }
    @objc optional var container: MailMailbox { get }
    @objc optional func setName(_ name: String!) // The name of a mailbox
}
extension SBObject: MailMailbox {}

// MARK: MailRule
@objc public protocol MailRule: SBObjectProtocol, MailGenericMethods {
    @objc optional func ruleConditions() -> SBElementArray
    @objc optional var colorMessage: MailHighlightColors { get } // If rule matches, apply this color
    @objc optional var deleteMessage: Bool { get } // If rule matches, delete message
    @objc optional var forwardText: String { get } // If rule matches, prepend this text to the forwarded message. Set to empty string to include no prepended text
    @objc optional var forwardMessage: String { get } // If rule matches, forward message to this address, or multiple addresses, separated by commas. Set to empty string to disable this action
    @objc optional var markFlagged: Bool { get } // If rule matches, mark message as flagged
    @objc optional var markFlagIndex: Int { get } // If rule matches, mark message with the specified flag. Set to -1 to disable this action
    @objc optional var markRead: Bool { get } // If rule matches, mark message as read
    @objc optional var playSound: String { get } // If rule matches, play this sound (specify name of sound or path to sound)
    @objc optional var redirectMessage: String { get } // If rule matches, redirect message to this address or multiple addresses, separate by commas. Set to empty string to disable this action
    @objc optional var replyText: String { get } // If rule matches, reply to message and prepend with this text. Set to empty string to disable this action
    @objc optional var runScript: Any { get } // If rule matches, run this compiled AppleScript file. Set to empty string to disable this action
    @objc optional var allConditionsMustBeMet: Bool { get } // Indicates whether all conditions must be met for rule to execute
    @objc optional var copyMessage: MailMailbox { get } // If rule matches, copy to this mailbox
    @objc optional var moveMessage: MailMailbox { get } // If rule matches, move to this mailbox
    @objc optional var highlightTextUsingColor: Bool { get } // Indicates whether the color will be used to highlight the text or background of a message in the message list
    @objc optional var enabled: Bool { get } // Indicates whether the rule is enabled
    @objc optional var name: String { get } // Name of rule
    @objc optional var shouldCopyMessage: Bool { get } // Indicates whether the rule has a copy action
    @objc optional var shouldMoveMessage: Bool { get } // Indicates whether the rule has a move action
    @objc optional var stopEvaluatingRules: Bool { get } // If rule matches, stop rule evaluation for this message
    @objc optional func setColorMessage(_ colorMessage: MailHighlightColors) // If rule matches, apply this color
    @objc optional func setDeleteMessage(_ deleteMessage: Bool) // If rule matches, delete message
    @objc optional func setForwardText(_ forwardText: String!) // If rule matches, prepend this text to the forwarded message. Set to empty string to include no prepended text
    @objc optional func setForwardMessage(_ forwardMessage: String!) // If rule matches, forward message to this address, or multiple addresses, separated by commas. Set to empty string to disable this action
    @objc optional func setMarkFlagged(_ markFlagged: Bool) // If rule matches, mark message as flagged
    @objc optional func setMarkFlagIndex(_ markFlagIndex: Int) // If rule matches, mark message with the specified flag. Set to -1 to disable this action
    @objc optional func setMarkRead(_ markRead: Bool) // If rule matches, mark message as read
    @objc optional func setPlaySound(_ playSound: String!) // If rule matches, play this sound (specify name of sound or path to sound)
    @objc optional func setRedirectMessage(_ redirectMessage: String!) // If rule matches, redirect message to this address or multiple addresses, separate by commas. Set to empty string to disable this action
    @objc optional func setReplyText(_ replyText: String!) // If rule matches, reply to message and prepend with this text. Set to empty string to disable this action
    @objc optional func setRunScript(_ runScript: Any!) // If rule matches, run this compiled AppleScript file. Set to empty string to disable this action
    @objc optional func setAllConditionsMustBeMet(_ allConditionsMustBeMet: Bool) // Indicates whether all conditions must be met for rule to execute
    @objc optional func setCopyMessage(_ copyMessage: MailMailbox!) // If rule matches, copy to this mailbox
    @objc optional func setMoveMessage(_ moveMessage: MailMailbox!) // If rule matches, move to this mailbox
    @objc optional func setHighlightTextUsingColor(_ highlightTextUsingColor: Bool) // Indicates whether the color will be used to highlight the text or background of a message in the message list
    @objc optional func setEnabled(_ enabled: Bool) // Indicates whether the rule is enabled
    @objc optional func setName(_ name: String!) // Name of rule
    @objc optional func setShouldCopyMessage(_ shouldCopyMessage: Bool) // Indicates whether the rule has a copy action
    @objc optional func setShouldMoveMessage(_ shouldMoveMessage: Bool) // Indicates whether the rule has a move action
    @objc optional func setStopEvaluatingRules(_ stopEvaluatingRules: Bool) // If rule matches, stop rule evaluation for this message
}
extension SBObject: MailRule {}

// MARK: MailRuleCondition
@objc public protocol MailRuleCondition: SBObjectProtocol, MailGenericMethods {
    @objc optional var expression: String { get } // Rule expression field
    @objc optional var header: String { get } // Rule header key
    @objc optional var qualifier: MailRuleQualifier { get } // Rule qualifier
    @objc optional var ruleType: MailRuleType { get } // Rule type
    @objc optional func setExpression(_ expression: String!) // Rule expression field
    @objc optional func setHeader(_ header: String!) // Rule header key
    @objc optional func setQualifier(_ qualifier: MailRuleQualifier) // Rule qualifier
    @objc optional func setRuleType(_ ruleType: MailRuleType) // Rule type
}
extension SBObject: MailRuleCondition {}

// MARK: MailRecipient
@objc public protocol MailRecipient: SBObjectProtocol, MailGenericMethods {
    @objc optional var address: String { get } // The recipients email address
    @objc optional var name: String { get } // The name used for display
    @objc optional func setAddress(_ address: String!) // The recipients email address
    @objc optional func setName(_ name: String!) // The name used for display
}
extension SBObject: MailRecipient {}

// MARK: MailBccRecipient
@objc public protocol MailBccRecipient: MailRecipient {
}
extension SBObject: MailBccRecipient {}

// MARK: MailCcRecipient
@objc public protocol MailCcRecipient: MailRecipient {
}
extension SBObject: MailCcRecipient {}

// MARK: MailToRecipient
@objc public protocol MailToRecipient: MailRecipient {
}
extension SBObject: MailToRecipient {}

// MARK: MailContainer
@objc public protocol MailContainer: MailMailbox {
}
extension SBObject: MailContainer {}

// MARK: MailHeader
@objc public protocol MailHeader: SBObjectProtocol, MailGenericMethods {
    @objc optional var content: String { get } // Contents of the header
    @objc optional var name: String { get } // Name of the header value
    @objc optional func setContent(_ content: String!) // Contents of the header
    @objc optional func setName(_ name: String!) // Name of the header value
}
extension SBObject: MailHeader {}

// MARK: MailMailAttachment
@objc public protocol MailMailAttachment: SBObjectProtocol, MailGenericMethods {
    @objc optional var name: String { get } // Name of the attachment
    @objc optional var MIMEType: String { get } // MIME type of the attachment E.g. text/plain.
    @objc optional var fileSize: Int { get } // Approximate size in bytes.
    @objc optional var downloaded: Bool { get } // Indicates whether the attachment has been downloaded.
    @objc optional func id() -> String // The unique identifier of the attachment.
}
extension SBObject: MailMailAttachment {}

