
// MARK: ImageEventsSaveOptions
@objc public enum ImageEventsSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: ImageEventsPrintingErrorHandling
@objc public enum ImageEventsPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: ImageEventsEdfm
@objc public enum ImageEventsEdfm : AEKeyword {
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

// MARK: ImageEventsBitz
@objc public enum ImageEventsBitz : AEKeyword {
    case best = 0x62657374 /* best */
    case blackWhite = 0x62267720 /* black & white */
    case color = 0x636f6c72 /* color */
    case fourColors = 0x34636c72 /* four colors */
    case fourGrays = 0x34677279 /* four grays */
    case grayscale = 0x67726179 /* grayscale */
    case millionsOfColors = 0x6d696c6c /* millions of colors */
    case millionsOfColorsPlus = 0x6d696c2b /* millions of colors plus */
    case sixteenColors = 0x3136636c /* sixteen colors */
    case sixteenGrays = 0x31366772 /* sixteen grays */
    case thousandsOfColors = 0x74686f75 /* thousands of colors */
    case twoHundredFiftySixColors = 0x32353663 /* two hundred fifty six colors */
    case twoHundredFiftySixGrays = 0x32353667 /* two hundred fifty six grays */
}

// MARK: ImageEventsPCla
@objc public enum ImageEventsPCla : AEKeyword {
    case abstract = 0x61627374 /* abstract profile */
    case colorspace = 0x73706163 /* colorspace profile */
    case input = 0x73636e72 /* input device */
    case link = 0x6c696e6b /* device-link profile */
    case monitor = 0x6d6e7472 /* display device */
    case named = 0x6e6d636c /* named color space profile */
    case output = 0x70727472 /* output device */
}

// MARK: ImageEventsPPCS
@objc public enum ImageEventsPPCS : AEKeyword {
    case lab = 0x4c616220 /* Lab */
    case xyz = 0x58595a20 /* XYZ */
}

// MARK: ImageEventsCmlv
@objc public enum ImageEventsCmlv : AEKeyword {
    case high = 0x68696768 /* High compression */
    case low = 0x6c6f7720 /* Low compression */
    case medium = 0x6d656469 /* Medium compression */
}

// MARK: ImageEventsTypz
@objc public enum ImageEventsTypz : AEKeyword {
    case bmp = 0x424d5066 /* BMP */
    case gif = 0x47494620 /* GIF */
    case jpeg = 0x4a504547 /* JPEG */
    case jpeg2 = 0x6a706732 /* JPEG2 */
    case macPaint = 0x504e5447 /* MacPaint */
    case pdf = 0x50444620 /* PDF */
    case photoshop = 0x38425053 /* Photoshop */
    case pict = 0x50494354 /* PICT */
    case png = 0x504e4766 /* PNG */
    case psd = 0x70736420 /* PSD */
    case quickTimeImage = 0x71746966 /* QuickTime Image */
    case sgi = 0x2e534749 /* SGI */
    case text = 0x54455854 /* Text */
    case tga = 0x74676120 /* TGA */
    case tiff = 0x54494646 /* TIFF */
}

// MARK: ImageEventsPQua
@objc public enum ImageEventsPQua : AEKeyword {
    case best = 0x51756132 /* best */
    case draft = 0x51756131 /* draft */
    case normal = 0x51756130 /* normal */
}

// MARK: ImageEventsPSpc
@objc public enum ImageEventsPSpc : AEKeyword {
    case cmyk = 0x434d594b /* CMYK */
    case eightChannel = 0x4d434838 /* Eight channel */
    case eightColor = 0x38434c52 /* Eight color */
    case fiveChannel = 0x4d434835 /* Five channel */
    case fiveColor = 0x35434c52 /* Five color */
    case gray = 0x47524159 /* Gray */
    case lab = 0x4c616220 /* Lab */
    case named = 0x4e414d45 /* Named */
    case rgb = 0x52474220 /* RGB */
    case sevenChannel = 0x4d434837 /* Seven channel */
    case sevenColor = 0x37434c52 /* Seven color */
    case sixChannel = 0x4d434836 /* Six channel */
    case sixColor = 0x36434c52 /* Six color */
    case xyz = 0x58595a20 /* XYZ */
}

// MARK: ImageEventsPRdr
@objc public enum ImageEventsPRdr : AEKeyword {
    case absoluteColorimetricIntent = 0x52647233 /* absolute colorimetric */
    case perceptualIntent = 0x52647230 /* perceptual */
    case relativeColorimetricIntent = 0x52647231 /* relative colorimetric */
    case saturationIntent = 0x52647232 /* saturation */
}

// MARK: ImageEventsSavo
@objc public enum ImageEventsSavo : AEKeyword {
    case no = 0x6e6f2020 /* Do not save the image. */
    case yes = 0x79657320 /* Save the image. */
}

// MARK: ImageEventsQual
@objc public enum ImageEventsQual : AEKeyword {
    case best = 0x62657374 /* best */
    case high = 0x68696768 /* high */
    case least = 0x6c656173 /* least */
    case low = 0x6c6f7720 /* low */
    case medium = 0x6d656469 /* medium */
}

// MARK: ImageEventsTypv
@objc public enum ImageEventsTypv : AEKeyword {
    case bmp = 0x424d5066 /* BMP */
    case jpeg = 0x4a504547 /* JPEG */
    case jpeg2 = 0x6a706732 /* JPEG2 */
    case pict = 0x50494354 /* PICT */
    case png = 0x504e4766 /* PNG */
    case psd = 0x70736420 /* PSD */
    case quickTimeImage = 0x71746966 /* QuickTime Image */
    case tiff = 0x54494646 /* TIFF */
}

// MARK: ImageEventsSaveableFileFormat
@objc public enum ImageEventsSaveableFileFormat : AEKeyword {
    case text = 0x63747874 /* Text File Format */
}

// MARK: ImageEventsGenericMethods
@objc public protocol ImageEventsGenericMethods {
    @objc optional func closeSaving(_ saving: ImageEventsSaveOptions, savingIn: ImageEventsFile!) // Close a document.
    @objc optional func saveIn(_ `in`: ImageEventsFile!, `as`: ImageEventsSaveableFileFormat) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
    @objc optional func cropToDimensions(_ toDimensions: [Any]!) // Crop an image
    @objc optional func embedWithSource(_ withSource: ImageEventsProfile!) // Embed an image with an ICC profile
    @objc optional func flipHorizontal(_ horizontal: Bool, vertical: Bool) // Flip an image
    @objc optional func matchToDestination(_ toDestination: ImageEventsProfile!) // Match an image
    @objc optional func padToDimensions(_ toDimensions: [Any]!, withPadColor: [Any]!) // Pad an image
    @objc optional func rotateToAngle(_ toAngle: Double) // Rotate an image
    @objc optional func saveAs(_ `as`: ImageEventsTypv, icon: Bool, `in`: String!, PackBits: Bool, withCompressionLevel: ImageEventsCmlv) -> ImageEventsAlias // Save an image to a file in one of various formats
    @objc optional func scaleByFactor(_ byFactor: Double, toSize: Int) // Scale an image
    @objc optional func unembed() // Remove any embedded ICC profiles from an image
}

// MARK: ImageEventsApplication
@objc public protocol ImageEventsApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional var applicationSupportFolder: ImageEventsFolder { get } // The Application Support folder
    @objc optional var applicationsFolder: ImageEventsFolder { get } // The user's Applications folder
    @objc optional var ClassicDomain: ImageEventsClassicDomainObject { get } // the collection of folders belonging to the Classic System
    @objc optional var desktopFolder: ImageEventsFolder { get } // The user's Desktop folder
    @objc optional var desktopPicturesFolder: ImageEventsFolder { get } // The Desktop Pictures folder
    @objc optional var documentsFolder: ImageEventsFolder { get } // The user's Documents folder
    @objc optional var downloadsFolder: ImageEventsFolder { get } // The user's Downloads folder
    @objc optional var favoritesFolder: ImageEventsFolder { get } // The user's Favorites folder
    @objc optional var FolderActionScriptsFolder: ImageEventsFolder { get } // The user's Folder Action Scripts folder
    @objc optional var fontsFolder: ImageEventsFolder { get } // The Fonts folder
    @objc optional var homeFolder: ImageEventsFolder { get } // The Home folder of the currently logged in user
    @objc optional var libraryFolder: ImageEventsFolder { get } // The Library folder
    @objc optional var localDomain: ImageEventsLocalDomainObject { get } // the collection of folders residing on the Local machine
    @objc optional var moviesFolder: ImageEventsFolder { get } // The user's Movies folder
    @objc optional var musicFolder: ImageEventsFolder { get } // The user's Music folder
    @objc optional var networkDomain: ImageEventsNetworkDomainObject { get } // the collection of folders residing on the Network
    @objc optional var picturesFolder: ImageEventsFolder { get } // The user's Pictures folder
    @objc optional var preferencesFolder: ImageEventsFolder { get } // The user's Preferences folder
    @objc optional var publicFolder: ImageEventsFolder { get } // The user's Public folder
    @objc optional var scriptingAdditionsFolder: ImageEventsFolder { get } // The Scripting Additions folder
    @objc optional var scriptsFolder: ImageEventsFolder { get } // The user's Scripts folder
    @objc optional var sharedDocumentsFolder: ImageEventsFolder { get } // The Shared Documents folder
    @objc optional var sitesFolder: ImageEventsFolder { get } // The user's Sites folder
    @objc optional var speakableItemsFolder: ImageEventsFolder { get } // The Speakable Items folder
    @objc optional var startupDisk: ImageEventsDisk { get } // the disk from which Mac OS X was loaded
    @objc optional var systemDomain: ImageEventsSystemDomainObject { get } // the collection of folders belonging to the System
    @objc optional var temporaryItemsFolder: ImageEventsFolder { get } // The Temporary Items folder
    @objc optional var trash: ImageEventsFolder { get } // The user's Trash folder
    @objc optional var userDomain: ImageEventsUserDomainObject { get } // the collection of folders belonging to the User
    @objc optional var utilitiesFolder: ImageEventsFolder { get } // The Utilities folder
    @objc optional var workflowsFolder: ImageEventsFolder { get } // The Automator Workflows folder
    @objc optional var defaultCMYKProfile: ImageEventsProfile { get } // the default CMYK profile
    @objc optional var defaultCMYKProfileLocation: ImageEventsFile { get } // the default CMYK profile location
    @objc optional var defaultGrayProfile: ImageEventsProfile { get } // the default Gray profile
    @objc optional var defaultGrayProfileLocation: ImageEventsFile { get } // the default Gray profile location
    @objc optional var defaultLabProfile: ImageEventsProfile { get } // the default Lab profile
    @objc optional var defaultLabProfileLocation: ImageEventsFile { get } // the default Lab profile location
    @objc optional var defaultRGBProfile: ImageEventsProfile { get } // the default RGB profile
    @objc optional var defaultRGBProfileLocation: ImageEventsFile { get } // the default RGB profile location
    @objc optional var defaultXYZProfile: ImageEventsProfile { get } // the default XYZ profile
    @objc optional var defaultXYZProfileLocation: ImageEventsFile { get } // the default XYZ profile location
    @objc optional var preferredCMM: String { get } // specifies preferred Color Management Module to use, or "automatic"
    @objc optional var profileFolder: Any { get } // the ColorSync profile folder
    @objc optional var quitDelay: Int { get } // the time in seconds the application will idle before quitting; if set to zero, idle time will not cause the application to quit
    @objc optional var systemProfile: ImageEventsProfile { get } // the default system profile
    @objc optional var systemProfileLocation: ImageEventsFile { get } // the default system profile location
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: ImageEventsSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func move(_ x: Any!, to: Any!) -> Any // Move disk item(s) to a new location.
    @objc optional func aliases() -> SBElementArray
    @objc optional func disks() -> SBElementArray
    @objc optional func diskItems() -> SBElementArray
    @objc optional func domains() -> SBElementArray
    @objc optional func files() -> SBElementArray
    @objc optional func filePackages() -> SBElementArray
    @objc optional func folders() -> SBElementArray
    @objc optional func displays() -> SBElementArray
    @objc optional func images() -> SBElementArray
    @objc optional func profiles() -> SBElementArray
}
extension SBApplication: ImageEventsApplication {}

// MARK: ImageEventsDocument
@objc public protocol ImageEventsDocument: SBObjectProtocol, ImageEventsGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: ImageEventsFile { get } // Its location on disk, if it has one.
}
extension SBObject: ImageEventsDocument {}

// MARK: ImageEventsWindow
@objc public protocol ImageEventsWindow: SBObjectProtocol, ImageEventsGenericMethods {
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
    @objc optional var document: ImageEventsDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: ImageEventsWindow {}

// MARK: ImageEventsDiskItem
@objc public protocol ImageEventsDiskItem: SBObjectProtocol, ImageEventsGenericMethods {
    @objc optional var busyStatus: Bool { get } // Is the disk item busy?
    @objc optional var container: ImageEventsDiskItem { get } // the folder or disk which has this disk item as an element
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
extension SBObject: ImageEventsDiskItem {}

// MARK: ImageEventsAlias
@objc public protocol ImageEventsAlias: ImageEventsDiskItem {
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
extension SBObject: ImageEventsAlias {}

// MARK: ImageEventsDisk
@objc public protocol ImageEventsDisk: ImageEventsDiskItem {
    @objc optional var capacity: NSNumber { get } // the total number of bytes (free or used) on the disk
    @objc optional var ejectable: Bool { get } // Can the media be ejected (floppies, CD's, and so on)?
    @objc optional var format: ImageEventsEdfm { get } // the file system format of this disk
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
extension SBObject: ImageEventsDisk {}

// MARK: ImageEventsDomain
@objc public protocol ImageEventsDomain: SBObjectProtocol, ImageEventsGenericMethods {
    @objc optional var applicationSupportFolder: ImageEventsFolder { get } // The Application Support folder
    @objc optional var applicationsFolder: ImageEventsFolder { get } // The Applications folder
    @objc optional var desktopPicturesFolder: ImageEventsFolder { get } // The Desktop Pictures folder
    @objc optional var FolderActionScriptsFolder: ImageEventsFolder { get } // The Folder Action Scripts folder
    @objc optional var fontsFolder: ImageEventsFolder { get } // The Fonts folder
    @objc optional var libraryFolder: ImageEventsFolder { get } // The Library folder
    @objc optional var name: String { get } // the name of the domain
    @objc optional var preferencesFolder: ImageEventsFolder { get } // The Preferences folder
    @objc optional var scriptingAdditionsFolder: ImageEventsFolder { get } // The Scripting Additions folder
    @objc optional var scriptsFolder: ImageEventsFolder { get } // The Scripts folder
    @objc optional var sharedDocumentsFolder: ImageEventsFolder { get } // The Shared Documents folder
    @objc optional var speakableItemsFolder: ImageEventsFolder { get } // The Speakable Items folder
    @objc optional var utilitiesFolder: ImageEventsFolder { get } // The Utilities folder
    @objc optional var workflowsFolder: ImageEventsFolder { get } // The Automator Workflows folder
    @objc optional func folders() -> SBElementArray
    @objc optional func id() -> String // the unique identifier of the domain
}
extension SBObject: ImageEventsDomain {}

// MARK: ImageEventsClassicDomainObject
@objc public protocol ImageEventsClassicDomainObject: ImageEventsDomain {
    @objc optional var appleMenuFolder: ImageEventsFolder { get } // The Apple Menu Items folder
    @objc optional var controlPanelsFolder: ImageEventsFolder { get } // The Control Panels folder
    @objc optional var controlStripModulesFolder: ImageEventsFolder { get } // The Control Strip Modules folder
    @objc optional var desktopFolder: ImageEventsFolder { get } // The Classic Desktop folder
    @objc optional var extensionsFolder: ImageEventsFolder { get } // The Extensions folder
    @objc optional var fontsFolder: ImageEventsFolder { get } // The Fonts folder
    @objc optional var launcherItemsFolder: ImageEventsFolder { get } // The Launcher Items folder
    @objc optional var preferencesFolder: ImageEventsFolder { get } // The Classic Preferences folder
    @objc optional var shutdownFolder: ImageEventsFolder { get } // The Shutdown Items folder
    @objc optional var startupItemsFolder: ImageEventsFolder { get } // The StartupItems folder
    @objc optional var systemFolder: ImageEventsFolder { get } // The System folder
    @objc optional func folders() -> SBElementArray
}
extension SBObject: ImageEventsClassicDomainObject {}

// MARK: ImageEventsFile
@objc public protocol ImageEventsFile: ImageEventsDiskItem {
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
extension SBObject: ImageEventsFile {}

// MARK: ImageEventsFilePackage
@objc public protocol ImageEventsFilePackage: ImageEventsFile {
    @objc optional func aliases() -> SBElementArray
    @objc optional func diskItems() -> SBElementArray
    @objc optional func files() -> SBElementArray
    @objc optional func filePackages() -> SBElementArray
    @objc optional func folders() -> SBElementArray
}
extension SBObject: ImageEventsFilePackage {}

// MARK: ImageEventsFolder
@objc public protocol ImageEventsFolder: ImageEventsDiskItem {
    @objc optional func aliases() -> SBElementArray
    @objc optional func diskItems() -> SBElementArray
    @objc optional func files() -> SBElementArray
    @objc optional func filePackages() -> SBElementArray
    @objc optional func folders() -> SBElementArray
}
extension SBObject: ImageEventsFolder {}

// MARK: ImageEventsLocalDomainObject
@objc public protocol ImageEventsLocalDomainObject: ImageEventsDomain {
    @objc optional func folders() -> SBElementArray
}
extension SBObject: ImageEventsLocalDomainObject {}

// MARK: ImageEventsNetworkDomainObject
@objc public protocol ImageEventsNetworkDomainObject: ImageEventsDomain {
    @objc optional func folders() -> SBElementArray
}
extension SBObject: ImageEventsNetworkDomainObject {}

// MARK: ImageEventsSystemDomainObject
@objc public protocol ImageEventsSystemDomainObject: ImageEventsDomain {
    @objc optional func folders() -> SBElementArray
}
extension SBObject: ImageEventsSystemDomainObject {}

// MARK: ImageEventsUserDomainObject
@objc public protocol ImageEventsUserDomainObject: ImageEventsDomain {
    @objc optional var desktopFolder: ImageEventsFolder { get } // The user's Desktop folder
    @objc optional var documentsFolder: ImageEventsFolder { get } // The user's Documents folder
    @objc optional var downloadsFolder: ImageEventsFolder { get } // The user's Downloads folder
    @objc optional var favoritesFolder: ImageEventsFolder { get } // The user's Favorites folder
    @objc optional var homeFolder: ImageEventsFolder { get } // The user's Home folder
    @objc optional var moviesFolder: ImageEventsFolder { get } // The user's Movies folder
    @objc optional var musicFolder: ImageEventsFolder { get } // The user's Music folder
    @objc optional var picturesFolder: ImageEventsFolder { get } // The user's Pictures folder
    @objc optional var publicFolder: ImageEventsFolder { get } // The user's Public folder
    @objc optional var sitesFolder: ImageEventsFolder { get } // The user's Sites folder
    @objc optional var temporaryItemsFolder: ImageEventsFolder { get } // The Temporary Items folder
    @objc optional func folders() -> SBElementArray
}
extension SBObject: ImageEventsUserDomainObject {}

// MARK: ImageEventsDisplay
@objc public protocol ImageEventsDisplay: SBObjectProtocol, ImageEventsGenericMethods {
    @objc optional var displayNumber: Int { get } // the number of the display
    @objc optional var displayProfile: ImageEventsProfile { get } // the profile for the display
    @objc optional var name: String { get } // the name of the display
}
extension SBObject: ImageEventsDisplay {}

// MARK: ImageEventsImage
@objc public protocol ImageEventsImage: SBObjectProtocol, ImageEventsGenericMethods {
    @objc optional var bitDepth: ImageEventsBitz { get } // bit depth of the image's color representation
    @objc optional var colorSpace: ImageEventsPSpc { get } // color space of the image's color representation
    @objc optional var dimensions: [Any] { get } // the width and height of the image, respectively, in pixels
    @objc optional var embeddedProfile: ImageEventsProfile { get } // the profile, if any, embedded in the image
    @objc optional var fileType: Any { get } // file type of the image's file
    @objc optional var imageFile: ImageEventsFile { get } // the file that contains the image
    @objc optional var location: ImageEventsDiskItem { get } // the folder or disk that encloses the file that contains the image
    @objc optional var name: String { get } // the name of the image
    @objc optional var resolution: [Any] { get } // the horizontal and vertical pixel density of the image, respectively, in dots per inch
    @objc optional func metadataTags() -> SBElementArray
    @objc optional func profiles() -> SBElementArray
}
extension SBObject: ImageEventsImage {}

// MARK: ImageEventsMetadataTag
@objc public protocol ImageEventsMetadataTag: SBObjectProtocol, ImageEventsGenericMethods {
    @objc optional var name: String { get } // the name of the tag
    @objc optional var value: Any { get } // the current setting of the tag
}
extension SBObject: ImageEventsMetadataTag {}

// MARK: ImageEventsProfile
@objc public protocol ImageEventsProfile: SBObjectProtocol, ImageEventsGenericMethods {
    @objc optional var colorSpace: ImageEventsPSpc { get } // the color space of the profile
    @objc optional var connectionSpace: ImageEventsPPCS { get } // the connection space of the profile
    @objc optional var creationDate: Date { get } // the creation date of the profile
    @objc optional var creator: String { get } // the creator type of the profile
    @objc optional var deviceClass: ImageEventsPCla { get } // the device class of the profile
    @objc optional var deviceManufacturer: String { get } // the device manufacturer of the profile
    @objc optional var deviceModel: Int { get } // the device model of the profile
    @objc optional var location: Any { get } // the file location of the profile
    @objc optional var name: String { get } // the description text of the profile
    @objc optional var platform: String { get } // the intended platform of the profile
    @objc optional var preferredCMM: String { get } // the preferred CMM of the profile
    @objc optional var quality: ImageEventsPQua { get } // the quality of the profile
    @objc optional var renderingIntent: ImageEventsPRdr { get } // the rendering intent of the profile
    @objc optional var size: Int { get } // the size of the profile in bytes
    @objc optional var version: String { get } // the version number of the profile
}
extension SBObject: ImageEventsProfile {}

