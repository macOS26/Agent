@_exported import ScriptingBridgeCommon

// MARK: VoiceOverClickCount
@objc public enum VoiceOverClickCount : AEKeyword {
    case once = 0x6f6e6365 /* One mouse click */
    case twice = 0x74776963 /* Double mouse click */
    case thrice = 0x74687269 /* Triple mouse click */
}

// MARK: VoiceOverClickButton
@objc public enum VoiceOverClickButton : AEKeyword {
    case leftButton = 0x6c656674 /* Left mouse button */
    case rightButton = 0x72696768 /* Right mouse button */
}

// MARK: VoiceOverPlace
@objc public enum VoiceOverPlace : AEKeyword {
    case dock = 0x646f6356 /* The dock */
    case desktop = 0x64657356 /* The desktop */
    case menubar = 0x6d656e56 /* The menubar */
    case statusMenu = 0x6d656556 /* Status menu */
    case spotlight = 0x73706f56 /* Spotlight */
    case linkedItem = 0x6c696e56 /* Linked item */
    case firstItem = 0x46697256 /* First item */
    case lastItem = 0x4c617356 /* Last item */
}

// MARK: VoiceOverDirection
@objc public enum VoiceOverDirection : AEKeyword {
    case up = 0x75702056 /* Up */
    case down = 0x646f7756 /* Down */
    case left = 0x6c656656 /* Left */
    case right = 0x72696756 /* Right */
}

// MARK: VoiceOverContainment
@objc public enum VoiceOverContainment : AEKeyword {
    case intoItem = 0x696e2056 /* Interact in */
    case outOfItem = 0x6f757456 /* Interact out */
}

// MARK: VoiceOverMenu
@objc public enum VoiceOverMenu : AEKeyword {
    case helpMenu = 0x68656c70 /* Help menu */
    case applicationsMenu = 0x61707073 /* Applications menu */
    case windowsMenu = 0x77696e64 /* Windows menu */
    case commandsMenu = 0x636d6473 /* Commands menu */
    case itemChooser = 0x6974656d /* Item chooser */
    case webMenu = 0x7765626d /* Web menu */
    case contextualMenu = 0x6374786d /* Contextual menu */
}

// MARK: VoiceOverResource
@objc public enum VoiceOverResource : AEKeyword {
    case utility = 0x7574696c /* VoiceOver Utility */
    case quickstart = 0x7175696b /* Quickstart */
    case voiceOverHelp = 0x7668656c /* Quickstart */
}

// MARK: VoiceOverOutputables
@objc public enum VoiceOverOutputables : AEKeyword {
    case mouseSummary = 0x6d6f7355 /* Summary of the item under the mouse */
    case workspaceOverview = 0x776f7253 /* The overview of the working environment */
    case windowOverview = 0x77696e4f /* The overview of the current window */
    case webOverview = 0x7765624f /* The overview of the web page */
    case announcementHistory = 0x616e6e48 /* Causes the display to show recent announcement */
}

// MARK: VoiceOverSpellingType
@objc public enum VoiceOverSpellingType : AEKeyword {
    case alphabeticSpelling = 0x616c7053 /* Alphabetic spelling */
    case phoneticSpelling = 0x70686f53 /* Phoenetic spelling */
}

// MARK: VoiceOverApplication
@objc public protocol VoiceOverApplication: SBApplicationProtocol {
    @objc optional var voCursor: VoiceOverVoCursorObject { get } // The VoiceOver cursor
    @objc optional var commander: VoiceOverCommanderObject { get } // The VoiceOver commander
    @objc optional var mouseCursor: VoiceOverMouseCursorObject { get } // The mouse cursor
    @objc optional var keyboardCursor: VoiceOverKeyboardCursorObject { get } // The keyboard cursor
    @objc optional var captionWindow: VoiceOverCaptionWindowObject { get } // The VoiceOver caption window
    @objc optional var brailleWindow: VoiceOverBrailleWindowObject { get } // The VoiceOver Braille window
    @objc optional var lastPhrase: VoiceOverLastPhraseObject { get } // The last phrase VoiceOver output
    @objc optional func performCommand(_ x: String!)
    @objc optional func click(_ x: VoiceOverClickCount, with: VoiceOverClickButton)
    @objc optional func quit()
    @objc optional func moveTo(_ to: VoiceOverPlace) // Move the vo cursor to a new location.
    @objc optional func outputWith(_ with: VoiceOverSpellingType) // Output
    @objc optional func `open`(_ x: Any!)
    @objc optional func closeMenu() // Closes open menus
}
extension SBApplication: VoiceOverApplication {}

// MARK: VoiceOverVoCursorObject
@objc public protocol VoiceOverVoCursorObject: SBObjectProtocol {
    @objc optional var bounds: NSRect { get } // The bounds of the VoiceOver cursor
    @objc optional var textUnderCursor: String { get } // The text of the item in the VoiceOver cursor
    @objc optional var magnification: Double { get } // The magnification factor of the VoiceOver cursor
    @objc optional func grabScreenshot() -> String // Takes a screenshot of the VO cursor and returns the path to the file
    @objc optional func performAction()
    @objc optional func select()
}
extension SBObject: VoiceOverVoCursorObject {}

// MARK: VoiceOverCommanderObject
@objc public protocol VoiceOverCommanderObject: SBObjectProtocol {
}
extension SBObject: VoiceOverCommanderObject {}

// MARK: VoiceOverCaptionWindowObject
@objc public protocol VoiceOverCaptionWindowObject: SBObjectProtocol {
    @objc optional var enabled: Bool { get } // The visibility of the caption window
}
extension SBObject: VoiceOverCaptionWindowObject {}

// MARK: VoiceOverBrailleWindowObject
@objc public protocol VoiceOverBrailleWindowObject: SBObjectProtocol {
    @objc optional var enabled: Bool { get } // The visibility of the Braille window
}
extension SBObject: VoiceOverBrailleWindowObject {}

// MARK: VoiceOverMouseCursorObject
@objc public protocol VoiceOverMouseCursorObject: SBObjectProtocol {
    @objc optional var position: NSPoint { get } // Position of the mouse
    @objc optional func press()
    // @objc optional func release()
}
// extension SBObject: VoiceOverMouseCursorObject {}

// MARK: VoiceOverLastPhraseObject
@objc public protocol VoiceOverLastPhraseObject: SBObjectProtocol {
    @objc optional var content: String { get } // The text of the last phrase
    @objc optional func save() // Save last phrase
    @objc optional func copyToPasteboard() // Copy last phrase to pasteboard
}
extension SBObject: VoiceOverLastPhraseObject {}

// MARK: VoiceOverKeyboardCursorObject
@objc public protocol VoiceOverKeyboardCursorObject: SBObjectProtocol {
    @objc optional var bounds: NSRect { get } // The bounds of the keyboard cursor
    @objc optional var textUnderCursor: String { get } // The text of the item in the keyboard cursor
}
extension SBObject: VoiceOverKeyboardCursorObject {}

