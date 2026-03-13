@_exported import ScriptingBridgeCommon

// MARK: SystemEventsSaveOptions
@objc public enum SystemEventsSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: SystemEventsPrintingErrorHandling
@objc public enum SystemEventsPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: SystemEventsSaveableFileFormat
@objc public enum SystemEventsSaveableFileFormat : AEKeyword {
    case text = 0x63747874 /* Text File Format */
}

// MARK: SystemEventsScrollPageBehaviors
@objc public enum SystemEventsScrollPageBehaviors : AEKeyword {
    case jumpToHere = 0x746f6872 /* jump to here */
    case jumpToNextPage = 0x6e787067 /* jump to next page */
}

// MARK: SystemEventsFontSmoothingStyles
@objc public enum SystemEventsFontSmoothingStyles : AEKeyword {
    case automatic = 0x6175746d /* automatic */
    case light = 0x6c697465 /* light */
    case medium = 0x6d656469 /* medium */
    case standard = 0x73746e64 /* standard */
    case strong = 0x73747267 /* strong */
}

// MARK: SystemEventsAppearances
@objc public enum SystemEventsAppearances : AEKeyword {
    case blue = 0x626c7565 /* blue */
    case graphite = 0x67726674 /* graphite */
}

// MARK: SystemEventsHighlightColors
@objc public enum SystemEventsHighlightColors : AEKeyword {
    case blue = 0x626c7565 /* blue */
    case gold = 0x676f6c64 /* gold */
    case graphite = 0x67726674 /* graphite */
    case green = 0x6772656e /* green */
    case orange = 0x6f726e67 /* orange */
    case purple = 0x7072706c /* purple */
    case red = 0x72656420 /* red */
    case silver = 0x736c7672 /* silver */
}

// MARK: SystemEventsDhac
@objc public enum SystemEventsDhac : AEKeyword {
    case askWhatToDo = 0x64686173 /* ask what to do */
    case ignore = 0x64686967 /* ignore */
    case openApplication = 0x64686170 /* open application */
    case runAScript = 0x64687273 /* run a script */
}

// MARK: SystemEventsDynamicStyle
@objc public enum SystemEventsDynamicStyle : AEKeyword {
    case auto = 0x61746d74 /* automatic (if supported, follows light/dark appearance) */
    case dynamic = 0x64796e6d /* dynamic (if supported, updates desktop picture based on time and/or location) */
    case light = 0x6c697465 /* light */
    case dark = 0x6461726b /* dark */
    case unknown = 0x756e6b3f /* unknown value */
}

// MARK: SystemEventsDpls
@objc public enum SystemEventsDpls : AEKeyword {
    case bottom = 0x626f7474 /* bottom */
    case left = 0x6c656674 /* left */
    case right = 0x72696768 /* right */
}

// MARK: SystemEventsDpef
@objc public enum SystemEventsDpef : AEKeyword {
    case genie = 0x67656e69 /* genie */
    case scale = 0x7363616c /* scale */
}

// MARK: SystemEventsDpbh
@objc public enum SystemEventsDpbh : AEKeyword {
    case minimize = 0x64646d69 /* minimize */
    case off = 0x64646f66 /* off */
    case zoom = 0x64647a6f /* zoom */
}

// MARK: SystemEventsEdfm
@objc public enum SystemEventsEdfm : AEKeyword {
    case applePhotoFormat = 0x64667068 /* Apple Photo format */
    case appleShareFormat = 0x64666173 /* AppleShare format */
    case audioFormat = 0x64666175 /* audio format */
    case highSierraFormat = 0x64666873 /* High Sierra format */
    case iso9660Format = 0x64663936 /* ISO 9660 format */
    case macOSExtendedFormat = 0x6466682b /* Mac OS Extended format */
    case macOSFormat = 0x64666866 /* Mac OS format */
    case msdosFormat = 0x64666d73 /* MSDOS format */
    case nfsFormat = 0x64666e66 /* NFS format */
    case proDOSFormat = 0x64667072 /* ProDOS format */
    case quickTakeFormat = 0x64667174 /* QuickTake format */
    case udfFormat = 0x64667564 /* UDF format */
    case ufsFormat = 0x64667566 /* UFS format */
    case unknownFormat = 0x64662424 /* unknown format */
    case webDAVFormat = 0x64667764 /* WebDAV format */
}

// MARK: SystemEventsEMds
@objc public enum SystemEventsEMds : AEKeyword {
    case commandDown = 0x4b636d64 /* command down */
    case controlDown = 0x4b63746c /* control down */
    case optionDown = 0x4b6f7074 /* option down */
    case shiftDown = 0x4b736674 /* shift down */
}

// MARK: SystemEventsEMky
@objc public enum SystemEventsEMky : AEKeyword {
    case command = 0x65436d64 /* command */
    case control = 0x65436e74 /* control */
    case option = 0x654f7074 /* option */
    case shift = 0x65536674 /* shift */
}

// MARK: SystemEventsEnum
@objc public enum SystemEventsEnum : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: SystemEventsAccs
@objc public enum SystemEventsAccs : AEKeyword {
    case none = 0x6e6f6e65 /* none */
    case readOnly = 0x72656164 /* read only */
    case readWrite = 0x72647772 /* read write */
    case writeOnly = 0x77726974 /* write only */
}

// MARK: SystemEventsGenericMethods
@objc public protocol SystemEventsGenericMethods {
    @objc optional func closeSaving(_ saving: SystemEventsSaveOptions, savingIn: SystemEventsFile!) // Close a document.
    @objc optional func saveIn(_ `in`: SystemEventsFile!, `as`: SystemEventsSaveableFileFormat) // Save a document.
    @objc optional func printWithProperties(_ withProperties: SystemEventsPrintSettings!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: SystemEventsApplication
@objc public protocol SystemEventsApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional var quitDelay: Int { get } // the time in seconds the application will idle before quitting; if set to zero, idle time will not cause the application to quit
    @objc optional var scriptMenuEnabled: Bool { get } // Is the Script menu installed in the menu bar?
    @objc optional var currentUser: SystemEventsUser { get } // the currently logged in user
    @objc optional var appearancePreferences: SystemEventsAppearancePreferencesObject { get } // a collection of appearance preferences
    @objc optional var CDAndDVDPreferences: SystemEventsCDAndDVDPreferencesObject { get } // the preferences for the current user when a CD or DVD is inserted
    @objc optional var currentDesktop: SystemEventsDesktop { get } // the primary desktop
    @objc optional var dockPreferences: SystemEventsDockPreferencesObject { get } // the preferences for the current user's dock
    @objc optional var networkPreferences: SystemEventsNetworkPreferencesObject { get } // the preferences for the current user's network
    @objc optional var currentScreenSaver: SystemEventsScreenSaver { get } // the currently selected screen saver
    @objc optional var screenSaverPreferences: SystemEventsScreenSaverPreferencesObject { get } // the preferences common to all screen savers
    @objc optional var securityPreferences: SystemEventsSecurityPreferencesObject { get } // a collection of security preferences
    @objc optional var applicationSupportFolder: SystemEventsFolder { get } // The Application Support folder
    @objc optional var applicationsFolder: SystemEventsFolder { get } // The user's Applications folder
    @objc optional var ClassicDomain: SystemEventsClassicDomainObject { get } // the collection of folders belonging to the Classic System
    @objc optional var desktopFolder: SystemEventsFolder { get } // The user's Desktop folder
    @objc optional var desktopPicturesFolder: SystemEventsFolder { get } // The Desktop Pictures folder
    @objc optional var documentsFolder: SystemEventsFolder { get } // The user's Documents folder
    @objc optional var downloadsFolder: SystemEventsFolder { get } // The user's Downloads folder
    @objc optional var favoritesFolder: SystemEventsFolder { get } // The user's Favorites folder
    @objc optional var FolderActionScriptsFolder: SystemEventsFolder { get } // The user's Folder Action Scripts folder
    @objc optional var fontsFolder: SystemEventsFolder { get } // The Fonts folder
    @objc optional var homeFolder: SystemEventsFolder { get } // The Home folder of the currently logged in user
    @objc optional var libraryFolder: SystemEventsFolder { get } // The Library folder
    @objc optional var localDomain: SystemEventsLocalDomainObject { get } // the collection of folders residing on the Local machine
    @objc optional var moviesFolder: SystemEventsFolder { get } // The user's Movies folder
    @objc optional var musicFolder: SystemEventsFolder { get } // The user's Music folder
    @objc optional var networkDomain: SystemEventsNetworkDomainObject { get } // the collection of folders residing on the Network
    @objc optional var picturesFolder: SystemEventsFolder { get } // The user's Pictures folder
    @objc optional var preferencesFolder: SystemEventsFolder { get } // The user's Preferences folder
    @objc optional var publicFolder: SystemEventsFolder { get } // The user's Public folder
    @objc optional var scriptingAdditionsFolder: SystemEventsFolder { get } // The Scripting Additions folder
    @objc optional var scriptsFolder: SystemEventsFolder { get } // The user's Scripts folder
    @objc optional var sharedDocumentsFolder: SystemEventsFolder { get } // The Shared Documents folder
    @objc optional var sitesFolder: SystemEventsFolder { get } // The user's Sites folder
    @objc optional var speakableItemsFolder: SystemEventsFolder { get } // The Speakable Items folder
    @objc optional var startupDisk: SystemEventsDisk { get } // the disk from which Mac OS X was loaded
    @objc optional var systemDomain: SystemEventsSystemDomainObject { get } // the collection of folders belonging to the System
    @objc optional var temporaryItemsFolder: SystemEventsFolder { get } // The Temporary Items folder
    @objc optional var trash: SystemEventsFolder { get } // The user's Trash folder
    @objc optional var userDomain: SystemEventsUserDomainObject { get } // the collection of folders belonging to the User
    @objc optional var utilitiesFolder: SystemEventsFolder { get } // The Utilities folder
    @objc optional var workflowsFolder: SystemEventsFolder { get } // The Automator Workflows folder
    @objc optional var folderActionsEnabled: Bool { get } // Are Folder Actions currently being processed?
    @objc optional var UIElementsEnabled: Bool { get } // Are UI element events currently being processed?
    @objc optional var scriptingDefinition: SystemEventsScriptingDefinitionObject { get } // The scripting definition of the System Events application
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: SystemEventsPrintSettings!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: SystemEventsSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func abortTransaction() // Discard the results of a bounded update session with one or more files.
    @objc optional func beginTransaction() -> Int // Begin a bounded update session with one or more files.
    @objc optional func endTransaction() // Apply the results of a bounded update session with one or more files.
    @objc optional func move(_ x: Any!, to: Any!) -> Any // Move disk item(s) to a new location.
    @objc optional func logOut() // Log out the current user
    @objc optional func restartStateSavingPreference(_ stateSavingPreference: Bool) // Restart the computer
    @objc optional func shutDownStateSavingPreference(_ stateSavingPreference: Bool) // Shut Down the computer
    @objc optional func sleep() // Put the computer to sleep
    @objc optional func clickAt(_ at: [Any]!) -> Any // cause the target process to behave as if the UI element were clicked
    @objc optional func keyCode(_ x: Any!, using: Any!) // cause the target process to behave as if key codes were entered
    @objc optional func keystroke(_ x: String!, using: Any!) // cause the target process to behave as if keystrokes were entered
    @objc optional func users() -> SBElementArray
    @objc optional func desktops() -> SBElementArray
    @objc optional func loginItems() -> SBElementArray
    @objc optional func screenSavers() -> SBElementArray
    @objc optional func aliases() -> SBElementArray
    @objc optional func disks() -> SBElementArray
    @objc optional func diskItems() -> SBElementArray
    @objc optional func domains() -> SBElementArray
    @objc optional func files() -> SBElementArray
    @objc optional func filePackages() -> SBElementArray
    @objc optional func folders() -> SBElementArray
    @objc optional func folderActions() -> SBElementArray
    @objc optional func applicationProcesses() -> SBElementArray
    @objc optional func deskAccessoryProcesses() -> SBElementArray
    @objc optional func processes() -> SBElementArray
    @objc optional func UIElements() -> SBElementArray
    @objc optional func propertyListFiles() -> SBElementArray
    @objc optional func propertyListItems() -> SBElementArray
    @objc optional func XMLDatas() -> SBElementArray
    @objc optional func XMLFiles() -> SBElementArray
}
extension SBApplication: SystemEventsApplication {}

// MARK: SystemEventsDocument
@objc public protocol SystemEventsDocument: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: SystemEventsFile { get } // Its location on disk, if it has one.
}
extension SBObject: SystemEventsDocument {}

// MARK: SystemEventsWindow
@objc public protocol SystemEventsWindow: SBObjectProtocol, SystemEventsGenericMethods {
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
    @objc optional var document: SystemEventsDocument { get } // The document whose contents are displayed in the window.
    @objc optional var accessibilityDescription: Any { get } // a more complete description of the window and its capabilities
    @objc optional var objectDescription: Any { get } // the accessibility description, if available; otherwise, the role description
    @objc optional var enabled: Any { get } // Is the window enabled? ( Does it accept clicks? )
    @objc optional var entireContents: [Any] { get } // a list of every UI element contained in this window and its child UI elements, to the limits of the tree
    @objc optional var focused: Any { get } // Is the focus on this window?
    @objc optional var help: Any { get } // an elaborate description of the window and its capabilities
    @objc optional var maximumValue: Any { get } // the maximum value that the UI element can take on
    @objc optional var minimumValue: Any { get } // the minimum value that the UI element can take on
    @objc optional var orientation: Any { get } // the orientation of the window
    @objc optional var position: Any { get } // the position of the window
    @objc optional var role: String { get } // an encoded description of the window and its capabilities
    @objc optional var roleDescription: String { get } // a more complete description of the window's role
    @objc optional var selected: Any { get } // Is the window selected?
    @objc optional var size: Any { get } // the size of the window
    @objc optional var subrole: Any { get } // an encoded description of the window and its capabilities
    @objc optional var title: String { get } // the title of the window as it appears on the screen
    @objc optional var value: Any { get } // the current value of the window
    @objc optional func id() -> Int // The unique identifier of the window.
    @objc optional func actions() -> SBElementArray
    @objc optional func attributes() -> SBElementArray
    @objc optional func browsers() -> SBElementArray
    @objc optional func busyIndicators() -> SBElementArray
    @objc optional func buttons() -> SBElementArray
    @objc optional func checkboxes() -> SBElementArray
    @objc optional func colorWells() -> SBElementArray
    @objc optional func comboBoxes() -> SBElementArray
    @objc optional func drawers() -> SBElementArray
    @objc optional func groups() -> SBElementArray
    @objc optional func growAreas() -> SBElementArray
    @objc optional func images() -> SBElementArray
    @objc optional func incrementors() -> SBElementArray
    @objc optional func lists() -> SBElementArray
    @objc optional func menuButtons() -> SBElementArray
    @objc optional func outlines() -> SBElementArray
    @objc optional func popOvers() -> SBElementArray
    @objc optional func popUpButtons() -> SBElementArray
    @objc optional func progressIndicators() -> SBElementArray
    @objc optional func radioButtons() -> SBElementArray
    @objc optional func radioGroups() -> SBElementArray
    @objc optional func relevanceIndicators() -> SBElementArray
    @objc optional func scrollAreas() -> SBElementArray
    @objc optional func scrollBars() -> SBElementArray
    @objc optional func sheets() -> SBElementArray
    @objc optional func sliders() -> SBElementArray
    @objc optional func splitters() -> SBElementArray
    @objc optional func splitterGroups() -> SBElementArray
    @objc optional func staticTexts() -> SBElementArray
    @objc optional func tabGroups() -> SBElementArray
    @objc optional func tables() -> SBElementArray
    @objc optional func textAreas() -> SBElementArray
    @objc optional func textFields() -> SBElementArray
    @objc optional func toolbars() -> SBElementArray
    @objc optional func UIElements() -> SBElementArray
}
extension SBObject: SystemEventsWindow {}

// MARK: SystemEventsUser
@objc public protocol SystemEventsUser: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var fullName: String { get } // user's full name
    @objc optional var homeDirectory: Any { get } // path to user's home directory
    @objc optional var name: String { get } // user's short name
    @objc optional var picturePath: Any { get } // path to user's picture. Can be set for current user only!
}
extension SBObject: SystemEventsUser {}

// MARK: SystemEventsAppearancePreferencesObject
@objc public protocol SystemEventsAppearancePreferencesObject: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var appearance: SystemEventsAppearances { get } // the overall look of buttons, menus and windows
    @objc optional var fontSmoothing: Bool { get } // Is font smoothing on?
    @objc optional var fontSmoothingStyle: SystemEventsFontSmoothingStyles { get } // the method used for smoothing fonts
    @objc optional var highlightColor: Any { get } // color used for hightlighting selected text and lists
    @objc optional var recentApplicationsLimit: Int { get } // the number of recent applications to track
    @objc optional var recentDocumentsLimit: Int { get } // the number of recent documents to track
    @objc optional var recentServersLimit: Int { get } // the number of recent servers to track
    @objc optional var scrollBarAction: SystemEventsScrollPageBehaviors { get } // the action performed by clicking the scroll bar
    @objc optional var smoothScrolling: Bool { get } // Is smooth scrolling used?
    @objc optional var darkMode: Bool { get } // use dark menu bar and dock
}
extension SBObject: SystemEventsAppearancePreferencesObject {}

// MARK: SystemEventsCDAndDVDPreferencesObject
@objc public protocol SystemEventsCDAndDVDPreferencesObject: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var blankCD: SystemEventsInsertionPreference { get } // the blank CD insertion preference
    @objc optional var blankDVD: SystemEventsInsertionPreference { get } // the blank DVD insertion preference
    @objc optional var blankBD: SystemEventsInsertionPreference { get } // the blank BD insertion preference
    @objc optional var musicCD: SystemEventsInsertionPreference { get } // the music CD insertion preference
    @objc optional var pictureCD: SystemEventsInsertionPreference { get } // the picture CD insertion preference
    @objc optional var videoDVD: SystemEventsInsertionPreference { get } // the video DVD insertion preference
    @objc optional var videoBD: SystemEventsInsertionPreference { get } // the video BD insertion preference
}
extension SBObject: SystemEventsCDAndDVDPreferencesObject {}

// MARK: SystemEventsInsertionPreference
@objc public protocol SystemEventsInsertionPreference: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var customApplication: Any { get } // application to launch or activate on the insertion of media
    @objc optional var customScript: Any { get } // AppleScript to launch or activate on the insertion of media
    @objc optional var insertionAction: SystemEventsDhac { get } // action to perform on media insertion
}
extension SBObject: SystemEventsInsertionPreference {}

// MARK: SystemEventsDesktop
@objc public protocol SystemEventsDesktop: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // name of the desktop
    @objc optional var changeInterval: Double { get } // number of seconds to wait between changing the desktop picture
    @objc optional var displayName: String { get } // name of display on which this desktop appears
    @objc optional var picture: Any { get } // path to file used as desktop picture
    @objc optional var pictureRotation: Int { get } // never, using interval, using login, after sleep
    @objc optional var picturesFolder: Any { get } // path to folder containing pictures for changing desktop background
    @objc optional var randomOrder: Bool { get } // turn on for random ordering of changing desktop pictures
    @objc optional var translucentMenuBar: Bool { get } // indicates whether the menu bar is translucent
    @objc optional var dynamicStyle: SystemEventsDynamicStyle { get } // desktop picture dynamic style
    @objc optional func id() -> Int // unique identifier of the desktop
}
extension SBObject: SystemEventsDesktop {}

// MARK: SystemEventsDockPreferencesObject
@objc public protocol SystemEventsDockPreferencesObject: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var animate: Bool { get } // is the animation of opening applications on or off?
    @objc optional var autohide: Bool { get } // is autohiding the dock on or off?
    @objc optional var dockSize: Double { get } // size/height of the items (between 0.0 (minimum) and 1.0 (maximum))
    @objc optional var autohideMenuBar: Bool { get } // is autohiding the menu bar on or off?
    @objc optional var doubleClickBehavior: SystemEventsDpbh { get } // behaviour when double clicking window a title bar
    @objc optional var magnification: Bool { get } // is magnification on or off?
    @objc optional var magnificationSize: Double { get } // maximum magnification size when magnification is on (between 0.0 (minimum) and 1.0 (maximum))
    @objc optional var minimizeEffect: SystemEventsDpef { get } // minimization effect
    @objc optional var minimizeIntoApplication: Bool { get } // minimize window into its application?
    @objc optional var screenEdge: SystemEventsDpls { get } // location on screen
    @objc optional var showIndicators: Bool { get } // show indicators for open applications?
    @objc optional var showRecents: Bool { get } // show recent applications?
}
extension SBObject: SystemEventsDockPreferencesObject {}

// MARK: SystemEventsLoginItem
@objc public protocol SystemEventsLoginItem: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var hidden: Bool { get } // Is the Login Item hidden when launched?
    @objc optional var kind: String { get } // the file type of the Login Item
    @objc optional var name: String { get } // the name of the Login Item
    @objc optional var path: String { get } // the file system path to the Login Item
}
extension SBObject: SystemEventsLoginItem {}

// MARK: SystemEventsConfiguration
@objc public protocol SystemEventsConfiguration: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var accountName: String { get } // the name used to authenticate
    @objc optional var connected: Bool { get } // Is the configuration connected?
    @objc optional var name: String { get } // the name of the configuration
    @objc optional func id() -> String // the unique identifier for the configuration
    @objc optional func connect() -> SystemEventsConfiguration // connect a configuration or service
    @objc optional func disconnect() -> SystemEventsConfiguration // disconnect a configuration or service
}
extension SBObject: SystemEventsConfiguration {}

// MARK: SystemEventsInterface
@objc public protocol SystemEventsInterface: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var automatic: Bool { get } // configure the interface speed, duplex, and mtu automatically?
    @objc optional var duplex: String { get } // the duplex setting  half | full | full with flow control
    @objc optional var kind: String { get } // the type of interface
    @objc optional var MACAddress: String { get } // the MAC address for the interface
    @objc optional var mtu: Int { get } // the packet size
    @objc optional var name: String { get } // the name of the interface
    @objc optional var speed: Int { get } // ethernet speed 10 | 100 | 1000
    @objc optional func id() -> String // the unique identifier for the interface
}
extension SBObject: SystemEventsInterface {}

// MARK: SystemEventsLocation
@objc public protocol SystemEventsLocation: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // the name of the location
    @objc optional func services() -> SBElementArray
    @objc optional func id() -> String // the unique identifier for the location
}
extension SBObject: SystemEventsLocation {}

// MARK: SystemEventsNetworkPreferencesObject
@objc public protocol SystemEventsNetworkPreferencesObject: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var currentLocation: SystemEventsLocation { get } // the current location
    @objc optional func interfaces() -> SBElementArray
    @objc optional func locations() -> SBElementArray
    @objc optional func services() -> SBElementArray
}
extension SBObject: SystemEventsNetworkPreferencesObject {}

// MARK: SystemEventsService
@objc public protocol SystemEventsService: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var active: Bool { get } // Is the service active?
    @objc optional var currentConfiguration: SystemEventsConfiguration { get } // the currently selected configuration
    @objc optional var interface: SystemEventsInterface { get } // the interface the service is built on
    @objc optional var kind: Int { get } // the type of service
    @objc optional var name: String { get } // the name of the service
    @objc optional func configurations() -> SBElementArray
    @objc optional func id() -> String // the unique identifier for the service
    @objc optional func connect() -> SystemEventsConfiguration // connect a configuration or service
    @objc optional func disconnect() -> SystemEventsConfiguration // disconnect a configuration or service
}
extension SBObject: SystemEventsService {}

// MARK: SystemEventsScreenSaver
@objc public protocol SystemEventsScreenSaver: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var displayedName: String { get } // name of the screen saver module as displayed to the user
    @objc optional var name: String { get } // name of the screen saver module to be displayed
    @objc optional var path: SystemEventsAlias { get } // path to the screen saver module
    @objc optional var pictureDisplayStyle: String { get } // effect to use when displaying picture-based screen savers (slideshow, collage, or mosaic)
    @objc optional func start() // start the screen saver
    @objc optional func stop() // stop the screen saver
}
extension SBObject: SystemEventsScreenSaver {}

// MARK: SystemEventsScreenSaverPreferencesObject
@objc public protocol SystemEventsScreenSaverPreferencesObject: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var delayInterval: Int { get } // number of seconds of idle time before the screen saver starts; zero for never
    @objc optional var mainScreenOnly: Bool { get } // should the screen saver be shown only on the main screen?
    @objc optional var running: Bool { get } // is the screen saver running?
    @objc optional var showClock: Bool { get } // should a clock appear over the screen saver?
    @objc optional func start() // start the screen saver
    @objc optional func stop() // stop the screen saver
}
extension SBObject: SystemEventsScreenSaverPreferencesObject {}

// MARK: SystemEventsSecurityPreferencesObject
@objc public protocol SystemEventsSecurityPreferencesObject: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var automaticLogin: Bool { get } // Is automatic login allowed?
    @objc optional var logOutWhenInactive: Bool { get } // Will the computer log out when inactive?
    @objc optional var logOutWhenInactiveInterval: Int { get } // The interval of inactivity after which the computer will log out
    @objc optional var requirePasswordToUnlock: Bool { get } // Is a password required to unlock secure preferences?
    @objc optional var requirePasswordToWake: Bool { get } // Is a password required to wake the computer from sleep or screen saver?
    @objc optional var secureVirtualMemory: Bool { get } // Is secure virtual memory being used?
}
extension SBObject: SystemEventsSecurityPreferencesObject {}

// MARK: SystemEventsDiskItem
@objc public protocol SystemEventsDiskItem: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var busyStatus: Bool { get } // Is the disk item busy?
    @objc optional var container: SystemEventsDiskItem { get } // the folder or disk which has this disk item as an element
    @objc optional var creationDate: Date { get } // the date on which the disk item was created
    @objc optional var displayedName: String { get } // the name of the disk item as displayed in the User Interface
    @objc optional var modificationDate: Date { get } // the date on which the disk item was last modified
    @objc optional var name: String { get } // the name of the disk item
    @objc optional var nameExtension: String { get } // the extension portion of the name
    @objc optional var packageFolder: Bool { get } // Is the disk item a package?
    @objc optional var path: String { get } // the file system path of the disk item
    @objc optional var physicalSize: Int { get } // the actual space used by the disk item on disk
    @objc optional var POSIXPath: String { get } // the POSIX file system path of the disk item
    @objc optional var size: Int { get } // the logical size of the disk item
    @objc optional var URL: String { get } // the URL of the disk item
    @objc optional var visible: Bool { get } // Is the disk item visible?
    @objc optional var volume: String { get } // the volume on which the disk item resides
    @objc optional func id() -> String // the unique ID of the disk item
    @objc optional func delete() // Delete disk item(s).
    @objc optional func moveTo(_ to: Any!) -> Any // Move disk item(s) to a new location.
}
extension SBObject: SystemEventsDiskItem {}

// MARK: SystemEventsAlias
@objc public protocol SystemEventsAlias: SystemEventsDiskItem {
    @objc optional var creatorType: Any { get } // the OSType identifying the application that created the alias
    @objc optional var defaultApplication: Any { get } // the application that will launch if the alias is opened
    @objc optional var fileType: Any { get } // the OSType identifying the type of data contained in the alias
    @objc optional var kind: String { get } // The kind of alias, as shown in Finder
    @objc optional var productVersion: String { get } // the version of the product (visible at the top of the "Get Info" window)
    @objc optional var shortVersion: String { get } // the short version of the application bundle referenced by the alias
    @objc optional var stationery: Bool { get } // Is the alias a stationery pad?
    @objc optional var typeIdentifier: String { get } // The type identifier of the alias
    @objc optional var version: String { get } // the version of the application bundle referenced by the alias (visible at the bottom of the "Get Info" window)
    @objc optional func aliases() -> SBElementArray
    @objc optional func diskItems() -> SBElementArray
    @objc optional func files() -> SBElementArray
    @objc optional func filePackages() -> SBElementArray
    @objc optional func folders() -> SBElementArray
}
extension SBObject: SystemEventsAlias {}

// MARK: SystemEventsDisk
@objc public protocol SystemEventsDisk: SystemEventsDiskItem {
    @objc optional var capacity: NSNumber { get } // the total number of bytes (free or used) on the disk
    @objc optional var ejectable: Bool { get } // Can the media be ejected (floppies, CD's, and so on)?
    @objc optional var format: SystemEventsEdfm { get } // the file system format of this disk
    @objc optional var freeSpace: NSNumber { get } // the number of free bytes left on the disk
    @objc optional var ignorePrivileges: Bool { get } // Ignore permissions on this disk?
    @objc optional var localVolume: Bool { get } // Is the media a local volume (as opposed to a file server)?
    @objc optional var server: Any { get } // the server on which the disk resides, AFP volumes only
    @objc optional var startup: Bool { get } // Is this disk the boot disk?
    @objc optional var zone: Any { get } // the zone in which the disk's server resides, AFP volumes only
    @objc optional func aliases() -> SBElementArray
    @objc optional func diskItems() -> SBElementArray
    @objc optional func files() -> SBElementArray
    @objc optional func filePackages() -> SBElementArray
    @objc optional func folders() -> SBElementArray
}
extension SBObject: SystemEventsDisk {}

// MARK: SystemEventsDomain
@objc public protocol SystemEventsDomain: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var applicationSupportFolder: SystemEventsFolder { get } // The Application Support folder
    @objc optional var applicationsFolder: SystemEventsFolder { get } // The Applications folder
    @objc optional var desktopPicturesFolder: SystemEventsFolder { get } // The Desktop Pictures folder
    @objc optional var FolderActionScriptsFolder: SystemEventsFolder { get } // The Folder Action Scripts folder
    @objc optional var fontsFolder: SystemEventsFolder { get } // The Fonts folder
    @objc optional var libraryFolder: SystemEventsFolder { get } // The Library folder
    @objc optional var name: String { get } // the name of the domain
    @objc optional var preferencesFolder: SystemEventsFolder { get } // The Preferences folder
    @objc optional var scriptingAdditionsFolder: SystemEventsFolder { get } // The Scripting Additions folder
    @objc optional var scriptsFolder: SystemEventsFolder { get } // The Scripts folder
    @objc optional var sharedDocumentsFolder: SystemEventsFolder { get } // The Shared Documents folder
    @objc optional var speakableItemsFolder: SystemEventsFolder { get } // The Speakable Items folder
    @objc optional var utilitiesFolder: SystemEventsFolder { get } // The Utilities folder
    @objc optional var workflowsFolder: SystemEventsFolder { get } // The Automator Workflows folder
    @objc optional func folders() -> SBElementArray
    @objc optional func id() -> String // the unique identifier of the domain
}
extension SBObject: SystemEventsDomain {}

// MARK: SystemEventsClassicDomainObject
@objc public protocol SystemEventsClassicDomainObject: SystemEventsDomain {
    @objc optional var appleMenuFolder: SystemEventsFolder { get } // The Apple Menu Items folder
    @objc optional var controlPanelsFolder: SystemEventsFolder { get } // The Control Panels folder
    @objc optional var controlStripModulesFolder: SystemEventsFolder { get } // The Control Strip Modules folder
    @objc optional var desktopFolder: SystemEventsFolder { get } // The Classic Desktop folder
    @objc optional var extensionsFolder: SystemEventsFolder { get } // The Extensions folder
    @objc optional var fontsFolder: SystemEventsFolder { get } // The Fonts folder
    @objc optional var launcherItemsFolder: SystemEventsFolder { get } // The Launcher Items folder
    @objc optional var preferencesFolder: SystemEventsFolder { get } // The Classic Preferences folder
    @objc optional var shutdownFolder: SystemEventsFolder { get } // The Shutdown Items folder
    @objc optional var startupItemsFolder: SystemEventsFolder { get } // The StartupItems folder
    @objc optional var systemFolder: SystemEventsFolder { get } // The System folder
    @objc optional func folders() -> SBElementArray
}
extension SBObject: SystemEventsClassicDomainObject {}

// MARK: SystemEventsFile
@objc public protocol SystemEventsFile: SystemEventsDiskItem {
    @objc optional var creatorType: Any { get } // the OSType identifying the application that created the file
    @objc optional var defaultApplication: Any { get } // the application that will launch if the file is opened
    @objc optional var fileType: Any { get } // the OSType identifying the type of data contained in the file
    @objc optional var kind: String { get } // The kind of file, as shown in Finder
    @objc optional var productVersion: String { get } // the version of the product (visible at the top of the "Get Info" window)
    @objc optional var shortVersion: String { get } // the short version of the file
    @objc optional var stationery: Bool { get } // Is the file a stationery pad?
    @objc optional var typeIdentifier: String { get } // The type identifier of the file
    @objc optional var version: String { get } // the version of the file (visible at the bottom of the "Get Info" window)
    @objc optional func `open`() -> Any // Open a document.
}
extension SBObject: SystemEventsFile {}

// MARK: SystemEventsFilePackage
@objc public protocol SystemEventsFilePackage: SystemEventsFile {
    @objc optional func aliases() -> SBElementArray
    @objc optional func diskItems() -> SBElementArray
    @objc optional func files() -> SBElementArray
    @objc optional func filePackages() -> SBElementArray
    @objc optional func folders() -> SBElementArray
}
extension SBObject: SystemEventsFilePackage {}

// MARK: SystemEventsFolder
@objc public protocol SystemEventsFolder: SystemEventsDiskItem {
    @objc optional func aliases() -> SBElementArray
    @objc optional func diskItems() -> SBElementArray
    @objc optional func files() -> SBElementArray
    @objc optional func filePackages() -> SBElementArray
    @objc optional func folders() -> SBElementArray
}
extension SBObject: SystemEventsFolder {}

// MARK: SystemEventsLocalDomainObject
@objc public protocol SystemEventsLocalDomainObject: SystemEventsDomain {
    @objc optional func folders() -> SBElementArray
}
extension SBObject: SystemEventsLocalDomainObject {}

// MARK: SystemEventsNetworkDomainObject
@objc public protocol SystemEventsNetworkDomainObject: SystemEventsDomain {
    @objc optional func folders() -> SBElementArray
}
extension SBObject: SystemEventsNetworkDomainObject {}

// MARK: SystemEventsSystemDomainObject
@objc public protocol SystemEventsSystemDomainObject: SystemEventsDomain {
    @objc optional func folders() -> SBElementArray
}
extension SBObject: SystemEventsSystemDomainObject {}

// MARK: SystemEventsUserDomainObject
@objc public protocol SystemEventsUserDomainObject: SystemEventsDomain {
    @objc optional var desktopFolder: SystemEventsFolder { get } // The user's Desktop folder
    @objc optional var documentsFolder: SystemEventsFolder { get } // The user's Documents folder
    @objc optional var downloadsFolder: SystemEventsFolder { get } // The user's Downloads folder
    @objc optional var favoritesFolder: SystemEventsFolder { get } // The user's Favorites folder
    @objc optional var homeFolder: SystemEventsFolder { get } // The user's Home folder
    @objc optional var moviesFolder: SystemEventsFolder { get } // The user's Movies folder
    @objc optional var musicFolder: SystemEventsFolder { get } // The user's Music folder
    @objc optional var picturesFolder: SystemEventsFolder { get } // The user's Pictures folder
    @objc optional var publicFolder: SystemEventsFolder { get } // The user's Public folder
    @objc optional var sitesFolder: SystemEventsFolder { get } // The user's Sites folder
    @objc optional var temporaryItemsFolder: SystemEventsFolder { get } // The Temporary Items folder
    @objc optional func folders() -> SBElementArray
}
extension SBObject: SystemEventsUserDomainObject {}

// MARK: SystemEventsFolderAction
@objc public protocol SystemEventsFolderAction: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var enabled: Bool { get } // Is the folder action enabled?
    @objc optional var name: String { get } // the name of the folder action, which is also the name of the folder
    @objc optional var path: String { get } // the path to the folder to which the folder action applies
    @objc optional var volume: String { get } // the volume on which the folder to which the folder action applies resides
    @objc optional func scripts() -> SBElementArray
    @objc optional func enableProcessNewChanges(_ processNewChanges: SystemEventsSaveOptions) // Enable a folder action.
}
extension SBObject: SystemEventsFolderAction {}

// MARK: SystemEventsScript
@objc public protocol SystemEventsScript: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var enabled: Bool { get } // Is the script enabled?
    @objc optional var name: String { get } // the name of the script
    @objc optional var path: String { get } // the file system path of the disk
    @objc optional var POSIXPath: String { get } // the POSIX file system path of the disk
}
extension SBObject: SystemEventsScript {}

// MARK: SystemEventsAction
@objc public protocol SystemEventsAction: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var objectDescription: String { get } // what the action does
    @objc optional var name: String { get } // the name of the action
    @objc optional func perform() -> SystemEventsAction // cause the target process to behave as if the action were applied to its UI element
}
extension SBObject: SystemEventsAction {}

// MARK: SystemEventsAttribute
@objc public protocol SystemEventsAttribute: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // the name of the attribute
    @objc optional var settable: Bool { get } // Can the attribute be set?
    @objc optional var value: Any { get } // the current value of the attribute
}
extension SBObject: SystemEventsAttribute {}

// MARK: SystemEventsUIElement
@objc public protocol SystemEventsUIElement: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var accessibilityDescription: Any { get } // a more complete description of the UI element and its capabilities
    @objc optional var objectDescription: Any { get } // the accessibility description, if available; otherwise, the role description
    @objc optional var enabled: Any { get } // Is the UI element enabled? ( Does it accept clicks? )
    @objc optional var entireContents: [Any] { get } // a list of every UI element contained in this UI element and its child UI elements, to the limits of the tree
    @objc optional var focused: Any { get } // Is the focus on this UI element?
    @objc optional var help: Any { get } // an elaborate description of the UI element and its capabilities
    @objc optional var maximumValue: Any { get } // the maximum value that the UI element can take on
    @objc optional var minimumValue: Any { get } // the minimum value that the UI element can take on
    @objc optional var name: String { get } // the name of the UI Element, which identifies it within its container
    @objc optional var orientation: Any { get } // the orientation of the UI element
    @objc optional var position: Any { get } // the position of the UI element
    @objc optional var role: String { get } // an encoded description of the UI element and its capabilities
    @objc optional var roleDescription: String { get } // a more complete description of the UI element's role
    @objc optional var selected: Any { get } // Is the UI element selected?
    @objc optional var size: Any { get } // the size of the UI element
    @objc optional var subrole: Any { get } // an encoded description of the UI element and its capabilities
    @objc optional var title: String { get } // the title of the UI element as it appears on the screen
    @objc optional var value: Any { get } // the current value of the UI element
    @objc optional func actions() -> SBElementArray
    @objc optional func attributes() -> SBElementArray
    @objc optional func browsers() -> SBElementArray
    @objc optional func busyIndicators() -> SBElementArray
    @objc optional func buttons() -> SBElementArray
    @objc optional func checkboxes() -> SBElementArray
    @objc optional func colorWells() -> SBElementArray
    @objc optional func columns() -> SBElementArray
    @objc optional func comboBoxes() -> SBElementArray
    @objc optional func drawers() -> SBElementArray
    @objc optional func groups() -> SBElementArray
    @objc optional func growAreas() -> SBElementArray
    @objc optional func images() -> SBElementArray
    @objc optional func incrementors() -> SBElementArray
    @objc optional func lists() -> SBElementArray
    @objc optional func menus() -> SBElementArray
    @objc optional func menuBars() -> SBElementArray
    @objc optional func menuBarItems() -> SBElementArray
    @objc optional func menuButtons() -> SBElementArray
    @objc optional func menuItems() -> SBElementArray
    @objc optional func outlines() -> SBElementArray
    @objc optional func popOvers() -> SBElementArray
    @objc optional func popUpButtons() -> SBElementArray
    @objc optional func progressIndicators() -> SBElementArray
    @objc optional func radioButtons() -> SBElementArray
    @objc optional func radioGroups() -> SBElementArray
    @objc optional func relevanceIndicators() -> SBElementArray
    @objc optional func rows() -> SBElementArray
    @objc optional func scrollAreas() -> SBElementArray
    @objc optional func scrollBars() -> SBElementArray
    @objc optional func sheets() -> SBElementArray
    @objc optional func sliders() -> SBElementArray
    @objc optional func splitters() -> SBElementArray
    @objc optional func splitterGroups() -> SBElementArray
    @objc optional func staticTexts() -> SBElementArray
    @objc optional func tabGroups() -> SBElementArray
    @objc optional func tables() -> SBElementArray
    @objc optional func textAreas() -> SBElementArray
    @objc optional func textFields() -> SBElementArray
    @objc optional func toolbars() -> SBElementArray
    @objc optional func UIElements() -> SBElementArray
    @objc optional func valueIndicators() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func clickAt(_ at: [Any]!) -> Any // cause the target process to behave as if the UI element were clicked
    @objc optional func select() -> SystemEventsUIElement // set the selected property of the UI element
}
extension SBObject: SystemEventsUIElement {}

// MARK: SystemEventsBrowser
@objc public protocol SystemEventsBrowser: SystemEventsUIElement {
}
extension SBObject: SystemEventsBrowser {}

// MARK: SystemEventsBusyIndicator
@objc public protocol SystemEventsBusyIndicator: SystemEventsUIElement {
}
extension SBObject: SystemEventsBusyIndicator {}

// MARK: SystemEventsButton
@objc public protocol SystemEventsButton: SystemEventsUIElement {
}
extension SBObject: SystemEventsButton {}

// MARK: SystemEventsCheckbox
@objc public protocol SystemEventsCheckbox: SystemEventsUIElement {
}
extension SBObject: SystemEventsCheckbox {}

// MARK: SystemEventsColorWell
@objc public protocol SystemEventsColorWell: SystemEventsUIElement {
}
extension SBObject: SystemEventsColorWell {}

// MARK: SystemEventsColumn
@objc public protocol SystemEventsColumn: SystemEventsUIElement {
}
extension SBObject: SystemEventsColumn {}

// MARK: SystemEventsComboBox
@objc public protocol SystemEventsComboBox: SystemEventsUIElement {
}
extension SBObject: SystemEventsComboBox {}

// MARK: SystemEventsDrawer
@objc public protocol SystemEventsDrawer: SystemEventsUIElement {
}
extension SBObject: SystemEventsDrawer {}

// MARK: SystemEventsGroup
@objc public protocol SystemEventsGroup: SystemEventsUIElement {
    @objc optional func checkboxes() -> SBElementArray
    @objc optional func staticTexts() -> SBElementArray
}
extension SBObject: SystemEventsGroup {}

// MARK: SystemEventsGrowArea
@objc public protocol SystemEventsGrowArea: SystemEventsUIElement {
}
extension SBObject: SystemEventsGrowArea {}

// MARK: SystemEventsImage
@objc public protocol SystemEventsImage: SystemEventsUIElement {
}
extension SBObject: SystemEventsImage {}

// MARK: SystemEventsIncrementor
@objc public protocol SystemEventsIncrementor: SystemEventsUIElement {
}
extension SBObject: SystemEventsIncrementor {}

// MARK: SystemEventsList
@objc public protocol SystemEventsList: SystemEventsUIElement {
}
extension SBObject: SystemEventsList {}

// MARK: SystemEventsMenu
@objc public protocol SystemEventsMenu: SystemEventsUIElement {
    @objc optional func menuItems() -> SBElementArray
}
extension SBObject: SystemEventsMenu {}

// MARK: SystemEventsMenuBar
@objc public protocol SystemEventsMenuBar: SystemEventsUIElement {
    @objc optional func menus() -> SBElementArray
    @objc optional func menuBarItems() -> SBElementArray
}
extension SBObject: SystemEventsMenuBar {}

// MARK: SystemEventsMenuBarItem
@objc public protocol SystemEventsMenuBarItem: SystemEventsUIElement {
    @objc optional func menus() -> SBElementArray
}
extension SBObject: SystemEventsMenuBarItem {}

// MARK: SystemEventsMenuButton
@objc public protocol SystemEventsMenuButton: SystemEventsUIElement {
}
extension SBObject: SystemEventsMenuButton {}

// MARK: SystemEventsMenuItem
@objc public protocol SystemEventsMenuItem: SystemEventsUIElement {
    @objc optional func menus() -> SBElementArray
}
extension SBObject: SystemEventsMenuItem {}

// MARK: SystemEventsOutline
@objc public protocol SystemEventsOutline: SystemEventsUIElement {
}
extension SBObject: SystemEventsOutline {}

// MARK: SystemEventsPopOver
@objc public protocol SystemEventsPopOver: SystemEventsUIElement {
}
extension SBObject: SystemEventsPopOver {}

// MARK: SystemEventsPopUpButton
@objc public protocol SystemEventsPopUpButton: SystemEventsUIElement {
}
extension SBObject: SystemEventsPopUpButton {}

// MARK: SystemEventsProcess
@objc public protocol SystemEventsProcess: SystemEventsUIElement {
    @objc optional var acceptsHighLevelEvents: Bool { get } // Is the process high-level event aware (accepts open application, open document, print document, and quit)?
    @objc optional var acceptsRemoteEvents: Bool { get } // Does the process accept remote events?
    @objc optional var architecture: String { get } // the architecture in which the process is running
    @objc optional var backgroundOnly: Bool { get } // Does the process run exclusively in the background?
    @objc optional var bundleIdentifier: String { get } // the bundle identifier of the process' application file
    @objc optional var Classic: Bool { get } // Is the process running in the Classic environment?
    @objc optional var creatorType: String { get } // the OSType of the creator of the process (the signature)
    @objc optional var displayedName: String { get } // the name of the file from which the process was launched, as displayed in the User Interface
    @objc optional var file: Any { get } // the file from which the process was launched
    @objc optional var fileType: String { get } // the OSType of the file type of the process
    @objc optional var frontmost: Bool { get } // Is the process the frontmost process
    @objc optional var hasScriptingTerminology: Bool { get } // Does the process have a scripting terminology, i.e., can it be scripted?
    @objc optional var name: String { get } // the name of the process
    @objc optional var partitionSpaceUsed: Int { get } // the number of bytes currently used in the process' partition
    @objc optional var shortName: Any { get } // the short name of the file from which the process was launched
    @objc optional var totalPartitionSize: Int { get } // the size of the partition with which the process was launched
    @objc optional var unixId: Int { get } // The Unix process identifier of a process running in the native environment, or -1 for a process running in the Classic environment
    @objc optional var visible: Bool { get } // Is the process' layer visible?
    @objc optional func menuBars() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func id() -> Int // The unique identifier of the process
}
extension SBObject: SystemEventsProcess {}

// MARK: SystemEventsApplicationProcess
@objc public protocol SystemEventsApplicationProcess: SystemEventsProcess {
    @objc optional var applicationFile: Any { get } // a reference to the application file from which this process was launched
}
extension SBObject: SystemEventsApplicationProcess {}

// MARK: SystemEventsDeskAccessoryProcess
@objc public protocol SystemEventsDeskAccessoryProcess: SystemEventsProcess {
    @objc optional var deskAccessoryFile: SystemEventsAlias { get } // a reference to the desk accessory file from which this process was launched
}
extension SBObject: SystemEventsDeskAccessoryProcess {}

// MARK: SystemEventsProgressIndicator
@objc public protocol SystemEventsProgressIndicator: SystemEventsUIElement {
}
extension SBObject: SystemEventsProgressIndicator {}

// MARK: SystemEventsRadioButton
@objc public protocol SystemEventsRadioButton: SystemEventsUIElement {
}
extension SBObject: SystemEventsRadioButton {}

// MARK: SystemEventsRadioGroup
@objc public protocol SystemEventsRadioGroup: SystemEventsUIElement {
    @objc optional func radioButtons() -> SBElementArray
}
extension SBObject: SystemEventsRadioGroup {}

// MARK: SystemEventsRelevanceIndicator
@objc public protocol SystemEventsRelevanceIndicator: SystemEventsUIElement {
}
extension SBObject: SystemEventsRelevanceIndicator {}

// MARK: SystemEventsRow
@objc public protocol SystemEventsRow: SystemEventsUIElement {
}
extension SBObject: SystemEventsRow {}

// MARK: SystemEventsScrollArea
@objc public protocol SystemEventsScrollArea: SystemEventsUIElement {
}
extension SBObject: SystemEventsScrollArea {}

// MARK: SystemEventsScrollBar
@objc public protocol SystemEventsScrollBar: SystemEventsUIElement {
    @objc optional func buttons() -> SBElementArray
    @objc optional func valueIndicators() -> SBElementArray
}
extension SBObject: SystemEventsScrollBar {}

// MARK: SystemEventsSheet
@objc public protocol SystemEventsSheet: SystemEventsUIElement {
}
extension SBObject: SystemEventsSheet {}

// MARK: SystemEventsSlider
@objc public protocol SystemEventsSlider: SystemEventsUIElement {
}
extension SBObject: SystemEventsSlider {}

// MARK: SystemEventsSplitter
@objc public protocol SystemEventsSplitter: SystemEventsUIElement {
}
extension SBObject: SystemEventsSplitter {}

// MARK: SystemEventsSplitterGroup
@objc public protocol SystemEventsSplitterGroup: SystemEventsUIElement {
}
extension SBObject: SystemEventsSplitterGroup {}

// MARK: SystemEventsStaticText
@objc public protocol SystemEventsStaticText: SystemEventsUIElement {
    @objc optional func images() -> SBElementArray
}
extension SBObject: SystemEventsStaticText {}

// MARK: SystemEventsTabGroup
@objc public protocol SystemEventsTabGroup: SystemEventsUIElement {
}
extension SBObject: SystemEventsTabGroup {}

// MARK: SystemEventsTable
@objc public protocol SystemEventsTable: SystemEventsUIElement {
}
extension SBObject: SystemEventsTable {}

// MARK: SystemEventsTextArea
@objc public protocol SystemEventsTextArea: SystemEventsUIElement {
}
extension SBObject: SystemEventsTextArea {}

// MARK: SystemEventsTextField
@objc public protocol SystemEventsTextField: SystemEventsUIElement {
}
extension SBObject: SystemEventsTextField {}

// MARK: SystemEventsToolbar
@objc public protocol SystemEventsToolbar: SystemEventsUIElement {
}
extension SBObject: SystemEventsToolbar {}

// MARK: SystemEventsValueIndicator
@objc public protocol SystemEventsValueIndicator: SystemEventsUIElement {
}
extension SBObject: SystemEventsValueIndicator {}

// MARK: SystemEventsPropertyListFile
@objc public protocol SystemEventsPropertyListFile: SystemEventsFile {
    @objc optional var contents: SystemEventsPropertyListItem { get } // the contents of the property list file; elements and properties of the property list item may be accessed as if they were elements and properties of the property list file
}
extension SBObject: SystemEventsPropertyListFile {}

// MARK: SystemEventsPropertyListItem
@objc public protocol SystemEventsPropertyListItem: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var kind: NSNumber { get } // the kind of data stored in the property list item: boolean/data/date/list/number/record/string
    @objc optional var name: String { get } // the name of the property list item ( if any )
    @objc optional var text: String { get } // the text representation of the property list data
    @objc optional var value: Any { get } // the value of the property list item
    @objc optional func propertyListItems() -> SBElementArray
}
extension SBObject: SystemEventsPropertyListItem {}

// MARK: SystemEventsXMLAttribute
@objc public protocol SystemEventsXMLAttribute: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // the name of the XML attribute
    @objc optional var value: Any { get } // the value of the XML attribute
}
extension SBObject: SystemEventsXMLAttribute {}

// MARK: SystemEventsXMLData
@objc public protocol SystemEventsXMLData: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // the name of the XML data
    @objc optional var text: String { get } // the text representation of the XML data
    @objc optional func XMLElements() -> SBElementArray
    @objc optional func id() -> String // the unique identifier of the XML data
}
extension SBObject: SystemEventsXMLData {}

// MARK: SystemEventsXMLElement
@objc public protocol SystemEventsXMLElement: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // the name of the XML element
    @objc optional var value: Any { get } // the value of the XML element
    @objc optional func XMLAttributes() -> SBElementArray
    @objc optional func XMLElements() -> SBElementArray
    @objc optional func id() -> String // the unique identifier of the XML element
}
extension SBObject: SystemEventsXMLElement {}

// MARK: SystemEventsXMLFile
@objc public protocol SystemEventsXMLFile: SystemEventsFile {
    @objc optional var contents: SystemEventsXMLData { get } // the contents of the XML file; elements and properties of the XML data may be accessed as if they were elements and properties of the XML file
}
extension SBObject: SystemEventsXMLFile {}

// MARK: SystemEventsPrintSettings
@objc public protocol SystemEventsPrintSettings: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var copies: Int { get } // the number of copies of a document to be printed
    @objc optional var collating: Bool { get } // Should printed copies be collated?
    @objc optional var startingPage: Int { get } // the first page of the document to be printed
    @objc optional var endingPage: Int { get } // the last page of the document to be printed
    @objc optional var pagesAcross: Int { get } // number of logical pages laid across a physical page
    @objc optional var pagesDown: Int { get } // number of logical pages laid out down a physical page
    @objc optional var requestedPrintTime: Date { get } // the time at which the desktop printer should print the document
    @objc optional var errorHandling: SystemEventsEnum { get } // how errors are handled
    @objc optional var faxNumber: String { get } // for fax number
    @objc optional var targetPrinter: String { get } // for target printer
}
extension SBObject: SystemEventsPrintSettings {}

// MARK: SystemEventsScriptingClass
@objc public protocol SystemEventsScriptingClass: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // The name of the class
    @objc optional var objectDescription: String { get } // The description of the class
    @objc optional var hidden: Bool { get } // Is the class hidden?
    @objc optional var pluralName: String { get } // The plural name of the class
    @objc optional var suiteName: String { get } // The name of the suite to which this class belongs
    @objc optional var superclass: SystemEventsScriptingClass { get } // The class from which this class inherits
    @objc optional func scriptingElements() -> SBElementArray
    @objc optional func scriptingProperties() -> SBElementArray
    @objc optional func id() -> String // The unique identifier of the class
}
extension SBObject: SystemEventsScriptingClass {}

// MARK: SystemEventsScriptingCommand
@objc public protocol SystemEventsScriptingCommand: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // The name of the command
    @objc optional var objectDescription: String { get } // The description of the command
    @objc optional var directParameter: SystemEventsScriptingParameter { get } // The direct parameter of the command
    @objc optional var hidden: Bool { get } // Is the command hidden?
    @objc optional var scriptingResult: SystemEventsScriptingResultObject { get } // The object or data returned by this command
    @objc optional var suiteName: String { get } // The name of the suite to which this command belongs
    @objc optional func scriptingParameters() -> SBElementArray
    @objc optional func id() -> String // The unique identifier of the command
}
extension SBObject: SystemEventsScriptingCommand {}

// MARK: SystemEventsScriptingDefinitionObject
@objc public protocol SystemEventsScriptingDefinitionObject: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional func scriptingSuites() -> SBElementArray
}
extension SBObject: SystemEventsScriptingDefinitionObject {}

// MARK: SystemEventsScriptingElement
@objc public protocol SystemEventsScriptingElement: SystemEventsScriptingClass {
}
extension SBObject: SystemEventsScriptingElement {}

// MARK: SystemEventsScriptingEnumeration
@objc public protocol SystemEventsScriptingEnumeration: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // The name of the enumeration
    @objc optional var hidden: Bool { get } // Is the enumeration hidden?
    @objc optional func scriptingEnumerators() -> SBElementArray
    @objc optional func id() -> String // The unique identifier of the enumeration
}
extension SBObject: SystemEventsScriptingEnumeration {}

// MARK: SystemEventsScriptingEnumerator
@objc public protocol SystemEventsScriptingEnumerator: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // The name of the enumerator
    @objc optional var objectDescription: String { get } // The description of the enumerator
    @objc optional var hidden: Bool { get } // Is the enumerator hidden?
    @objc optional func id() -> String // The unique identifier of the enumerator
}
extension SBObject: SystemEventsScriptingEnumerator {}

// MARK: SystemEventsScriptingParameter
@objc public protocol SystemEventsScriptingParameter: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // The name of the parameter
    @objc optional var objectDescription: String { get } // The description of the parameter
    @objc optional var hidden: Bool { get } // Is the parameter hidden?
    @objc optional var kind: String { get } // The kind of object or data specified by this parameter
    @objc optional var optional: Bool { get } // Is the parameter optional?
    @objc optional func id() -> String // The unique identifier of the parameter
}
extension SBObject: SystemEventsScriptingParameter {}

// MARK: SystemEventsScriptingProperty
@objc public protocol SystemEventsScriptingProperty: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // The name of the property
    @objc optional var access: SystemEventsAccs { get } // The type of access to this property
    @objc optional var objectDescription: String { get } // The description of the property
    @objc optional var enumerated: Bool { get } // Is the property's value an enumerator?
    @objc optional var hidden: Bool { get } // Is the property hidden?
    @objc optional var kind: String { get } // The kind of object or data returned by this property
    @objc optional var listed: Bool { get } // Is the property's value a list?
    @objc optional func id() -> String // The unique identifier of the property
}
extension SBObject: SystemEventsScriptingProperty {}

// MARK: SystemEventsScriptingResultObject
@objc public protocol SystemEventsScriptingResultObject: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var objectDescription: String { get } // The description of the property
    @objc optional var enumerated: Bool { get } // Is the scripting result's value an enumerator?
    @objc optional var kind: String { get } // The kind of object or data returned by this property
    @objc optional var listed: Bool { get } // Is the scripting result's value a list?
}
extension SBObject: SystemEventsScriptingResultObject {}

// MARK: SystemEventsScriptingSuite
@objc public protocol SystemEventsScriptingSuite: SBObjectProtocol, SystemEventsGenericMethods {
    @objc optional var name: String { get } // The name of the suite
    @objc optional var objectDescription: String { get } // The description of the suite
    @objc optional var hidden: Bool { get } // Is the suite hidden?
    @objc optional func scriptingCommands() -> SBElementArray
    @objc optional func scriptingClasses() -> SBElementArray
    @objc optional func scriptingEnumerations() -> SBElementArray
    @objc optional func id() -> String // The unique identifier of the suite
}
extension SBObject: SystemEventsScriptingSuite {}

