// MARK: KeynoteSaveOptions
@objc public enum KeynoteSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: KeynotePrintingErrorHandling
@objc public enum KeynotePrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: KeynoteSaveableFileFormat
@objc public enum KeynoteSaveableFileFormat : AEKeyword {
    case keynote = 0x4b6e6666 /* The Keynote native file format */
}

// MARK: KeynoteExportFormat
@objc public enum KeynoteExportFormat : AEKeyword {
    case html = 0x4b68746d /* HTML */
    case quickTimeMovie = 0x4b6d6f76 /* QuickTime movie */
    case pdf = 0x4b706466 /* PDF */
    case slideImages = 0x4b696d67 /* image */
    case microsoftPowerPoint = 0x4b707074 /* Microsoft PowerPoint */
    case keynote09 = 0x4b6b6579 /* Keynote 09 */
}

// MARK: KeynoteImageExportFormats
@objc public enum KeynoteImageExportFormats : AEKeyword {
    case jpeg = 0x4b69666a /* JPEG */
    case png = 0x4b696670 /* PNG */
    case tiff = 0x4b696674 /* TIFF */
}

// MARK: KeynoteMovieExportFormats
@objc public enum KeynoteMovieExportFormats : AEKeyword {
    case format360p = 0x4b6d6633 /* 360p */
    case format540p = 0x4b6d6635 /* 540p */
    case format720p = 0x4b6d6637 /* 720p */
    case format1080p = 0x4b6d6638 /* 1080p */
    case format2160p = 0x4b6d6634 /* DCI 4K (4096x2160) */
    case nativeSize = 0x4b6d664e /* Exported movie will have the same dimensions as the document, up to 4096x2160 */
}

// MARK: KeynoteMovieCodecs
@objc public enum KeynoteMovieCodecs : AEKeyword {
    case h264 = 0x4b6d6331 /* H.264 */
    case appleProRes422 = 0x4b6d6332 /* Apple ProRes 422 */
    case appleProRes4444 = 0x4b6d6333 /* Apple ProRes 4444 */
    case appleProRes422LT = 0x4b6d6334 /* Apple ProRes 422LT */
    case appleProRes422HQ = 0x4b6d6335 /* Apple ProRes 422HQ */
    case appleProRes422Proxy = 0x4b6d6336 /* Apple ProRes 422Proxy */
    case hevc = 0x4b6d6337 /* HEVC */
}

// MARK: KeynoteMovieFramerates
@objc public enum KeynoteMovieFramerates : AEKeyword {
    case fps12 = 0x4b667231 /* 12 FPS */
    case fps2398 = 0x4b667232 /* 23.98 FPS */
    case fps24 = 0x4b667233 /* 24 FPS */
    case fps25 = 0x4b667234 /* 25 FPS */
    case fps2997 = 0x4b667235 /* 29.97 FPS */
    case fps30 = 0x4b667236 /* 30 FPS */
    case fps50 = 0x4b667237 /* 50 FPS */
    case fps5994 = 0x4b667238 /* 59.94 FPS */
    case fps60 = 0x4b667239 /* 60 FPS */
}

// MARK: KeynotePrintWhat
@objc public enum KeynotePrintWhat : AEKeyword {
    case individualSlides = 0x4b707769 /* individual slides */
    case slideWithNotes = 0x4b70776e /* slides with notes */
    case handouts = 0x4b707768 /* handouts */
}

// MARK: KeynotePDFImageQuality
@objc public enum KeynotePDFImageQuality : AEKeyword {
    case good = 0x4b6e5030 /* good quality */
    case better = 0x4b6e5031 /* better quality */
    case best = 0x4b6e5032 /* best quality */
}

// MARK: KeynoteTransitionEffects
@objc public enum KeynoteTransitionEffects : AEKeyword {
    case noTransitionEffect = 0x746e696c
    case magicMove = 0x746d6a76
    case shimmer = 0x7473686d
    case sparkle = 0x7473706b
    case swing = 0x74737767
    case objectCube = 0x746f6362
    case objectFlip = 0x746f6670
    case objectPop = 0x746f7070
    case objectPush = 0x746f7068
    case objectRevolve = 0x746f7276
    case objectZoom = 0x746f7a6d
    case perspective = 0x74707273
    case clothesline = 0x74636c6f
    case confetti = 0x74636674
    case dissolve = 0x74646973
    case drop = 0x74647270
    case droplet = 0x7464706c
    case fadeThroughColor = 0x74667463
    case grid = 0x74677264
    case iris = 0x74697273
    case moveIn = 0x746d7669
    case push = 0x74707368
    case reveal = 0x7472766c
    case `switch` = 0x74737769
    case wipe = 0x74777065
    case blinds = 0x74626c64
    case colorPlanes = 0x7463706c
    case cube = 0x74637562
    case doorway = 0x74647779
    case fall = 0x7466616c
    case flip = 0x74666970
    case flop = 0x74666f70
    case mosaic = 0x746d7363
    case pageFlip = 0x7470666c
    case pivot = 0x74707674
    case reflection = 0x7472666c
    case revolvingDoor = 0x74726576
    case scale = 0x7473636c
    case swap = 0x74737770
    case swoosh = 0x74737773
    case twirl = 0x7474776c
    case twist = 0x74747769
    case fadeAndMove = 0x74666164
}

// MARK: KeynoteTAVT
@objc public enum KeynoteTAVT : AEKeyword {
    case bottom = 0x61766274 /* Right-align content. */
    case center = 0x61637472 /* Center-align content. */
    case top = 0x61767470 /* Top-align content. */
}

// MARK: KeynoteTAHT
@objc public enum KeynoteTAHT : AEKeyword {
    case autoAlign = 0x61617574 /* Auto-align based on content type. */
    case center = 0x61637472 /* Center-align content. */
    case justify = 0x616a7374 /* Fully justify (left and right) content. */
    case left = 0x616c6674 /* Left-align content. */
    case right = 0x61726974 /* Right-align content. */
}

// MARK: KeynoteNMSD
@objc public enum KeynoteNMSD : AEKeyword {
    case ascending = 0x6173636e /* Sort in increasing value order */
    case descending = 0x6473636e /* Sort in decreasing value order */
}

// MARK: KeynoteNMCT
@objc public enum KeynoteNMCT : AEKeyword {
    case automatic = 0x66617574 /* Automatic format */
    case checkbox = 0x66636368 /* Checkbox control format (Numbers only) */
    case currency = 0x66637572 /* Currency number format */
    case dateAndTime = 0x6664746d /* Date and time format */
    case fraction = 0x66667261 /* Fraction number format */
    case number = 0x6e6d6272 /* Decimal number format */
    case percent = 0x66706572 /* Percentage number format */
    case popUpMenu = 0x66637070 /* Pop-up menu control format (Numbers only) */
    case scientific = 0x66736369 /* Scientific notation format */
    case slider = 0x6663736c /* Slider control format (Numbers only) */
    case stepper = 0x66637374 /* Stepper control format (Numbers only) */
    case text = 0x63747874 /* Text format */
    case duration = 0x66647572 /* Duration format */
    case rating = 0x66726174 /* Rating format. (Numbers only) */
    case numeralSystem = 0x66636e73 /* Numeral System */
}

// MARK: KeynoteItemFillOptions
@objc public enum KeynoteItemFillOptions : AEKeyword {
    case noFill = 0x66696e6f
    case colorFill = 0x6669636f
    case gradientFill = 0x66696772
    case advancedGradientFill = 0x66696167
    case imageFill = 0x6669696d
    case advancedImageFill = 0x66696169
}

// MARK: KeynotePlaybackRepetitionMethod
@objc public enum KeynotePlaybackRepetitionMethod : AEKeyword {
    case none = 0x6d76726e
    case loop = 0x6d766c70
    case loopBackAndForth = 0x6d766266
}

// MARK: KeynoteLegacyChartType
@objc public enum KeynoteLegacyChartType : AEKeyword {
    case pie_2d = 0x70696532 /* two-dimensional pie chart */
    case vertical_bar_2d = 0x76627232 /* two-dimensional vertical bar chart */
    case stacked_vertical_bar_2d = 0x73766232 /* two-dimensional stacked vertical bar chart */
    case horizontal_bar_2d = 0x68627232 /* two-dimensional horizontal bar chart */
    case stacked_horizontal_bar_2d = 0x73686232 /* two-dimensional stacked horizontal bar chart */
    case pie_3d = 0x70696533 /* three-dimensional pie chart. */
    case vertical_bar_3d = 0x76627233 /* three-dimensional vertical bar chart */
    case stacked_vertical_bar_3d = 0x73766233 /* three-dimensional stacked bar chart */
    case horizontal_bar_3d = 0x68627233 /* three-dimensional horizontal bar chart */
    case stacked_horizontal_bar_3d = 0x73686233 /* three-dimensional stacked horizontal bar chart */
    case area_2d = 0x61726532 /* two-dimensional area chart. */
    case stacked_area_2d = 0x73617232 /* two-dimensional stacked area chart */
    case line_2d = 0x6c696e32 /*  two-dimensional line chart. */
    case line_3d = 0x6c696e33 /* three-dimensional line chart */
    case area_3d = 0x61726533 /* three-dimensional area chart */
    case stacked_area_3d = 0x73617233 /* three-dimensional stacked area chart */
    case scatterplot_2d = 0x73637032 /* two-dimensional scatterplot chart */
}

// MARK: KeynoteLegacyChartGrouping
@objc public enum KeynoteLegacyChartGrouping : AEKeyword {
    case chartRow = 0x4b436772 /* group by row */
    case chartColumn = 0x4b436763 /* group by column */
}

// MARK: KeynoteGenericMethods
@objc public protocol KeynoteGenericMethods {
    @objc optional func closeSaving(_ saving: KeynoteSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ `in`: URL!, `as`: KeynoteSaveableFileFormat) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: KeynoteApplication
@objc public protocol KeynoteApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: KeynoteSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func setPassword(_ x: String!, to: KeynoteDocument!, hint: String!, savingInKeychain: Bool) // Set a password to an unencrypted document.
    @objc optional func removePassword(_ x: String!, from: KeynoteDocument!) // Remove the password from the document.
    @objc optional func showNext() // Advance one build or slide.
    @objc optional func showPrevious() // Go to the previous slide.
    @objc optional func themes() -> SBElementArray
}
extension SBApplication: KeynoteApplication {}

// MARK: KeynoteDocument
@objc public protocol KeynoteDocument: SBObjectProtocol, KeynoteGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
    @objc optional var slideNumbersShowing: Bool { get } // Are the slide numbers displayed?
    @objc optional var documentTheme: KeynoteTheme { get } // The theme assigned to the document.
    @objc optional var autoLoop: Bool { get } // Make the slideshow play repeatedly.
    @objc optional var autoPlay: Bool { get } // Automatically play the presentation when opening the file.
    @objc optional var autoRestart: Bool { get } // Restart the slideshow if it's inactive for the specified time
    @objc optional var maximumIdleDuration: Int { get } // Restart the slideshow if it's inactive for the specified time
    @objc optional var currentSlide: KeynoteSlide { get } // The currently selected slide, or the slide that would display if the presentation was started.
    @objc optional var height: Int { get } // The height of the document (in points). Standard slide height = 768. Wide slide height = 1080.
    @objc optional var width: Int { get } // The width of the document (in points). Standard slide width = 1024. Wide slide width = 1920.
    @objc optional var selection: [Any] { get } // A list of the currently selected items.
    @objc optional var passwordProtected: Bool { get } // Whether the document is password protected or not.
    @objc optional func exportTo(_ to: URL!, `as`: KeynoteExportFormat, withProperties: [AnyHashable : Any]!) // Export a slideshow to another file
    @objc optional func startFrom(_ from: KeynoteSlide!) // Start playing the presentation.
    @objc optional func makeImageSlidesFiles(_ files: [Any]!, setTitles: Bool, slideLayout: KeynoteSlideLayout!) // Make a series of slides from a list of files.
    @objc optional func stop() // Stop the presentation.
    @objc optional func showSlideSwitcher() // Show the slide switcher in play mode
    @objc optional func hideSlideSwitcher() // Hide the slide switcher in play mode
    @objc optional func moveSlideSwitcherForward() // Move the slide switcher forward one slide
    @objc optional func moveSlideSwitcherBackward() // Move the slide switcher backward one slide
    @objc optional func cancelSlideSwitcher() // Hide the slide switcher without changing slides
    @objc optional func acceptSlideSwitcher() // Hide the slide switcher, going to the slide it has selected
    @objc optional func slides() -> SBElementArray
    @objc optional func slideLayouts() -> SBElementArray
    @objc optional func id() -> String // Document ID.
}
extension SBObject: KeynoteDocument {}

// MARK: KeynoteWindow
@objc public protocol KeynoteWindow: SBObjectProtocol, KeynoteGenericMethods {
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
    @objc optional var document: KeynoteDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: KeynoteWindow {}

// MARK: KeynoteTheme
@objc public protocol KeynoteTheme: SBObjectProtocol, KeynoteGenericMethods {
    @objc optional var name: String { get }
    @objc optional func id() -> String // The identifier used by the application.
}
extension SBObject: KeynoteTheme {}

// MARK: KeynoteRichText
@objc public protocol KeynoteRichText: SBObjectProtocol, KeynoteGenericMethods {
    @objc optional var color: NSColor { get } // The color of the font. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
    @objc optional var font: String { get } // The name of the font.  Can be the PostScript name, such as: “TimesNewRomanPS-ItalicMT”, or display name: “Times New Roman Italic”. TIP: Use the Font Book application get the information about a typeface.
    @objc optional var size: Double { get } // The size of the font.
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: KeynoteRichText {}

// MARK: KeynoteCharacter
@objc public protocol KeynoteCharacter: KeynoteRichText {
}
extension SBObject: KeynoteCharacter {}

// MARK: KeynoteParagraph
@objc public protocol KeynoteParagraph: KeynoteRichText {
    @objc optional func characters() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: KeynoteParagraph {}

// MARK: KeynoteWord
@objc public protocol KeynoteWord: KeynoteRichText {
    @objc optional func characters() -> SBElementArray
}
extension SBObject: KeynoteWord {}

// MARK: KeynoteIWorkContainer
@objc public protocol KeynoteIWorkContainer: SBObjectProtocol, KeynoteGenericMethods {
    @objc optional func audioClips() -> SBElementArray
    @objc optional func charts() -> SBElementArray
    @objc optional func images() -> SBElementArray
    @objc optional func iWorkItems() -> SBElementArray
    @objc optional func groups() -> SBElementArray
    @objc optional func lines() -> SBElementArray
    @objc optional func movies() -> SBElementArray
    @objc optional func shapes() -> SBElementArray
    @objc optional func tables() -> SBElementArray
    @objc optional func textItems() -> SBElementArray
}
extension SBObject: KeynoteIWorkContainer {}

// MARK: KeynoteSlide
@objc public protocol KeynoteSlide: KeynoteIWorkContainer {
    @objc optional var baseLayout: KeynoteSlideLayout { get } // The slide layout this slide is based upon
    @objc optional var bodyShowing: Bool { get } // Is the default body text displayed?
    @objc optional var skipped: Bool { get } // Is the slide skipped?
    @objc optional var slideNumber: Int { get } // index of the slide in the document
    @objc optional var titleShowing: Bool { get } // Is the default slide title displayed?
    @objc optional var defaultBodyItem: KeynoteShape { get } // The default body container of the slide
    @objc optional var defaultTitleItem: KeynoteShape { get } // The default title container of the slide
    @objc optional var presenterNotes: KeynoteRichText { get } // The presenter notes for the slide
    @objc optional var transitionProperties: [AnyHashable : Any] { get } // The transition settings to apply to the slide.
    @objc optional func addChartRowNames(_ rowNames: [Any]!, columnNames: [Any]!, data: [Any]!, type: KeynoteLegacyChartType, groupBy: KeynoteLegacyChartGrouping) // Add a chart to a slide
}
extension SBObject: KeynoteSlide {}

// MARK: KeynoteSlideLayout
@objc public protocol KeynoteSlideLayout: KeynoteSlide {
    @objc optional var name: String { get } // The name of the slide layout
}
extension SBObject: KeynoteSlideLayout {}

// MARK: KeynoteIWorkItem
@objc public protocol KeynoteIWorkItem: SBObjectProtocol, KeynoteGenericMethods {
    @objc optional var height: Int { get } // The height of the iWork item.
    @objc optional var locked: Bool { get } // Whether the object is locked.
    @objc optional var parent: KeynoteIWorkContainer { get } // The iWork container containing this iWork item.
    @objc optional var position: NSPoint { get } // The horizontal and vertical coordinates of the top left point of the iWork item.
    @objc optional var width: Int { get } // The width of the iWork item.
}
extension SBObject: KeynoteIWorkItem {}

// MARK: KeynoteAudioClip
@objc public protocol KeynoteAudioClip: KeynoteIWorkItem {
    @objc optional var fileName: Any { get } // The name of the audio file.
    @objc optional var clipVolume: Int { get } // The volume setting for the audio clip, from 0 (none) to 100 (full volume).
    @objc optional var repetitionMethod: KeynotePlaybackRepetitionMethod { get } // If or how the audio clip repeats.
}
extension SBObject: KeynoteAudioClip {}

// MARK: KeynoteShape
@objc public protocol KeynoteShape: KeynoteIWorkItem {
    @objc optional var backgroundFillType: KeynoteItemFillOptions { get } // The background, if any, for the shape.
    @objc optional var objectText: KeynoteRichText { get } // The text contained within the shape.
    @objc optional var reflectionShowing: Bool { get } // Is the iWork item displaying a reflection?
    @objc optional var reflectionValue: Int { get } // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
    @objc optional var opacity: Int { get } // The opacity of the object, in percent.
}
extension SBObject: KeynoteShape {}

// MARK: KeynoteChart
@objc public protocol KeynoteChart: KeynoteIWorkItem {
}
extension SBObject: KeynoteChart {}

// MARK: KeynoteImage
@objc public protocol KeynoteImage: KeynoteIWorkItem {
    @objc optional var objectDescription: String { get } // Text associated with the image, read aloud by VoiceOver.
    @objc optional var file: URL { get } // The image file.
    @objc optional var fileName: Any { get } // The name of the image file.
    @objc optional var opacity: Int { get } // The opacity of the object, in percent.
    @objc optional var reflectionShowing: Bool { get } // Is the iWork item displaying a reflection?
    @objc optional var reflectionValue: Int { get } // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
}
extension SBObject: KeynoteImage {}

// MARK: KeynoteGroup
@objc public protocol KeynoteGroup: KeynoteIWorkContainer {
    @objc optional var height: Int { get } // The height of the iWork item.
    @objc optional var parent: KeynoteIWorkContainer { get } // The iWork container containing this iWork item.
    @objc optional var position: NSPoint { get } // The horizontal and vertical coordinates of the top left point of the iWork item.
    @objc optional var width: Int { get } // The width of the iWork item.
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
}
extension SBObject: KeynoteGroup {}

// MARK: KeynoteLine
@objc public protocol KeynoteLine: KeynoteIWorkItem {
    @objc optional var endPoint: NSPoint { get } // A list of two numbers indicating the horizontal and vertical position of the line ending point.
    @objc optional var reflectionShowing: Bool { get } // Is the iWork item displaying a reflection?
    @objc optional var reflectionValue: Int { get } // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
    @objc optional var startPoint: NSPoint { get } // A list of two numbers indicating the horizontal and vertical position of the line starting point.
}
extension SBObject: KeynoteLine {}

// MARK: KeynoteMovie
@objc public protocol KeynoteMovie: KeynoteIWorkItem {
    @objc optional var fileName: Any { get } // The name of the movie file.
    @objc optional var movieVolume: Int { get } // The volume setting for the movie, from 0 (none) to 100 (full volume).
    @objc optional var opacity: Int { get } // The opacity of the object, in percent.
    @objc optional var reflectionShowing: Bool { get } // Is the iWork item displaying a reflection?
    @objc optional var reflectionValue: Int { get } // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional var repetitionMethod: KeynotePlaybackRepetitionMethod { get } // If or how the movie repeats.
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
}
extension SBObject: KeynoteMovie {}

// MARK: KeynoteTable
@objc public protocol KeynoteTable: KeynoteIWorkItem {
    @objc optional var name: String { get } // The item's name.
    @objc optional var cellRange: KeynoteRange { get } // The range describing every cell in the table.
    @objc optional var selectionRange: KeynoteRange { get } // The cells currently selected in the table.
    @objc optional var rowCount: Int { get } // The number of rows in the table.
    @objc optional var columnCount: Int { get } // The number of columns in the table.
    @objc optional var headerRowCount: Int { get } // The number of header rows in the table.
    @objc optional var headerColumnCount: Int { get } // The number of header columns in the table.
    @objc optional var footerRowCount: Int { get } // The number of footer rows in the table.
    @objc optional func cells() -> SBElementArray
    @objc optional func rows() -> SBElementArray
    @objc optional func columns() -> SBElementArray
    @objc optional func ranges() -> SBElementArray
    @objc optional func sortBy(_ by: KeynoteColumn!, direction: KeynoteNMSD, inRows: KeynoteRange!) // Sort the rows of the table.
}
extension SBObject: KeynoteTable {}

// MARK: KeynoteTextItem
@objc public protocol KeynoteTextItem: KeynoteIWorkItem {
    @objc optional var backgroundFillType: KeynoteItemFillOptions { get } // The background, if any, for the text item.
    @objc optional var objectText: KeynoteRichText { get } // The text contained within the text item.
    @objc optional var opacity: Int { get } // The opacity of the object, in percent.
    @objc optional var reflectionShowing: Bool { get } // Is the iWork item displaying a reflection?
    @objc optional var reflectionValue: Int { get } // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
}
extension SBObject: KeynoteTextItem {}

// MARK: KeynoteRange
@objc public protocol KeynoteRange: SBObjectProtocol, KeynoteGenericMethods {
    @objc optional var fontName: String { get } // The font of the range's cells.
    @objc optional var fontSize: Double { get } // The font size of the range's cells.
    @objc optional var format: KeynoteNMCT { get } // The format of the range's cells.
    @objc optional var alignment: KeynoteTAHT { get } // The horizontal alignment of content in the range's cells.
    @objc optional var name: String { get } // The range's coordinates.
    @objc optional var textColor: NSColor { get } // The text color of the range's cells.
    @objc optional var textWrap: Bool { get } // Whether text should wrap in the range's cells.
    @objc optional var backgroundColor: NSColor { get } // The background color of the range's cells.
    @objc optional var verticalAlignment: KeynoteTAVT { get } // The vertical alignment of content in the range's cells.
    @objc optional func cells() -> SBElementArray
    @objc optional func columns() -> SBElementArray
    @objc optional func rows() -> SBElementArray
    @objc optional func clear() // Clear the contents of a specified range of cells, including formatting and style.
    @objc optional func merge() // Merge a specified range of cells.
    @objc optional func unmerge() // Unmerge all merged cells in a specified range.
}
extension SBObject: KeynoteRange {}

// MARK: KeynoteCell
@objc public protocol KeynoteCell: KeynoteRange {
    @objc optional var column: KeynoteColumn { get } // The cell's column.
    @objc optional var row: KeynoteRow { get } // The cell's row.
    @objc optional var value: Any { get } // The actual value in the cell, or missing value if the cell is empty.
    @objc optional var formattedValue: String { get } // The formatted value in the cell, or missing value if the cell is empty.
    @objc optional var formula: String { get } // The formula in the cell, as text, e.g. =SUM(40+2). If the cell does not contain a formula, returns missing value. To set the value of a cell to a formula as text, use the value property.
}
extension SBObject: KeynoteCell {}

// MARK: KeynoteRow
@objc public protocol KeynoteRow: KeynoteRange {
    @objc optional var address: Int { get } // The row's index in the table (e.g., the second row has address 2).
    @objc optional var height: Double { get } // The height of the row.
}
extension SBObject: KeynoteRow {}

// MARK: KeynoteColumn
@objc public protocol KeynoteColumn: KeynoteRange {
    @objc optional var address: Int { get } // The column's index in the table (e.g., the second column has address 2).
    @objc optional var width: Double { get } // The width of the column.
}
extension SBObject: KeynoteColumn {}

