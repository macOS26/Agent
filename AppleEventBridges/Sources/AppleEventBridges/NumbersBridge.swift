@_exported import ScriptingBridgeCommon

// MARK: NumbersSaveOptions
@objc public enum NumbersSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: NumbersPrintingErrorHandling
@objc public enum NumbersPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: NumbersTAVT
@objc public enum NumbersTAVT : AEKeyword {
    case bottom = 0x61766274 /* Right-align content. */
    case center = 0x61637472 /* Center-align content. */
    case top = 0x61767470 /* Top-align content. */
}

// MARK: NumbersTAHT
@objc public enum NumbersTAHT : AEKeyword {
    case autoAlign = 0x61617574 /* Auto-align based on content type. */
    case center = 0x61637472 /* Center-align content. */
    case justify = 0x616a7374 /* Fully justify (left and right) content. */
    case left = 0x616c6674 /* Left-align content. */
    case right = 0x61726974 /* Right-align content. */
}

// MARK: NumbersNMSD
@objc public enum NumbersNMSD : AEKeyword {
    case ascending = 0x6173636e /* Sort in increasing value order */
    case descending = 0x6473636e /* Sort in decreasing value order */
}

// MARK: NumbersNMCT
@objc public enum NumbersNMCT : AEKeyword {
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

// MARK: NumbersItemFillOptions
@objc public enum NumbersItemFillOptions : AEKeyword {
    case noFill = 0x66696e6f
    case colorFill = 0x6669636f
    case gradientFill = 0x66696772
    case advancedGradientFill = 0x66696167
    case imageFill = 0x6669696d
    case advancedImageFill = 0x66696169
}

// MARK: NumbersPlaybackRepetitionMethod
@objc public enum NumbersPlaybackRepetitionMethod : AEKeyword {
    case none = 0x6d76726e
    case loop = 0x6d766c70
    case loopBackAndForth = 0x6d766266
}

// MARK: NumbersSaveableFileFormat
@objc public enum NumbersSaveableFileFormat : AEKeyword {
    case numbers = 0x4e756666 /* The Numbers native file format */
}

// MARK: NumbersExportFormat
@objc public enum NumbersExportFormat : AEKeyword {
    case pdf = 0x4e706466 /* PDF */
    case microsoftExcel = 0x4e65786c /* Microsoft Excel */
    case csv = 0x4e637376 /* CSV */
    case numbers09 = 0x4e6e6d62 /* Numbers 09 */
}

// MARK: NumbersImageQuality
@objc public enum NumbersImageQuality : AEKeyword {
    case good = 0x4b6e5030 /* Good quality. */
    case better = 0x4b6e5031 /* Better quality. */
    case best = 0x4b6e5032 /* Best quality. */
}

// MARK: NumbersGenericMethods
@objc public protocol NumbersGenericMethods {
    @objc optional func closeSaving(_ saving: NumbersSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ `in`: URL!, `as`: NumbersSaveableFileFormat) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: NumbersApplication
@objc public protocol NumbersApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: NumbersSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func setPassword(_ x: String!, to: NumbersDocument!, hint: String!, savingInKeychain: Bool) // Set a password to an unencrypted document.
    @objc optional func removePassword(_ x: String!, from: NumbersDocument!) // Remove the password from the document.
    @objc optional func templates() -> SBElementArray
}
extension SBApplication: NumbersApplication {}

// MARK: NumbersDocument
@objc public protocol NumbersDocument: SBObjectProtocol, NumbersGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
    @objc optional var selection: [Any] { get } // A list of the currently selected items.
    @objc optional var passwordProtected: Bool { get } // Whether the document is password protected or not.
    @objc optional var documentTemplate: NumbersTemplate { get } // The template assigned to the document.
    @objc optional var activeSheet: NumbersSheet { get } // The active sheet.
    @objc optional func exportTo(_ to: URL!, `as`: NumbersExportFormat, withProperties: [AnyHashable : Any]!) // Export a document to another file
    @objc optional func sheets() -> SBElementArray
    @objc optional func id() -> String // Document ID.
}
extension SBObject: NumbersDocument {}

// MARK: NumbersWindow
@objc public protocol NumbersWindow: SBObjectProtocol, NumbersGenericMethods {
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
    @objc optional var document: NumbersDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: NumbersWindow {}

// MARK: NumbersRichText
@objc public protocol NumbersRichText: SBObjectProtocol, NumbersGenericMethods {
    @objc optional var color: NSColor { get } // The color of the font. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
    @objc optional var font: String { get } // The name of the font.  Can be the PostScript name, such as: “TimesNewRomanPS-ItalicMT”, or display name: “Times New Roman Italic”. TIP: Use the Font Book application get the information about a typeface.
    @objc optional var size: Double { get } // The size of the font.
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: NumbersRichText {}

// MARK: NumbersCharacter
@objc public protocol NumbersCharacter: NumbersRichText {
}
extension SBObject: NumbersCharacter {}

// MARK: NumbersParagraph
@objc public protocol NumbersParagraph: NumbersRichText {
    @objc optional func characters() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: NumbersParagraph {}

// MARK: NumbersWord
@objc public protocol NumbersWord: NumbersRichText {
    @objc optional func characters() -> SBElementArray
}
extension SBObject: NumbersWord {}

// MARK: NumbersIWorkContainer
@objc public protocol NumbersIWorkContainer: SBObjectProtocol, NumbersGenericMethods {
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
extension SBObject: NumbersIWorkContainer {}

// MARK: NumbersIWorkItem
@objc public protocol NumbersIWorkItem: SBObjectProtocol, NumbersGenericMethods {
    @objc optional var height: Int { get } // The height of the iWork item.
    @objc optional var locked: Bool { get } // Whether the object is locked.
    @objc optional var parent: NumbersIWorkContainer { get } // The iWork container containing this iWork item.
    @objc optional var position: NSPoint { get } // The horizontal and vertical coordinates of the top left point of the iWork item.
    @objc optional var width: Int { get } // The width of the iWork item.
}
extension SBObject: NumbersIWorkItem {}

// MARK: NumbersAudioClip
@objc public protocol NumbersAudioClip: NumbersIWorkItem {
    @objc optional var fileName: Any { get } // The name of the audio file.
    @objc optional var clipVolume: Int { get } // The volume setting for the audio clip, from 0 (none) to 100 (full volume).
    @objc optional var repetitionMethod: NumbersPlaybackRepetitionMethod { get } // If or how the audio clip repeats.
}
extension SBObject: NumbersAudioClip {}

// MARK: NumbersShape
@objc public protocol NumbersShape: NumbersIWorkItem {
    @objc optional var backgroundFillType: NumbersItemFillOptions { get } // The background, if any, for the shape.
    @objc optional var objectText: NumbersRichText { get } // The text contained within the shape.
    @objc optional var reflectionShowing: Bool { get } // Is the iWork item displaying a reflection?
    @objc optional var reflectionValue: Int { get } // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
    @objc optional var opacity: Int { get } // The opacity of the object, in percent.
}
extension SBObject: NumbersShape {}

// MARK: NumbersChart
@objc public protocol NumbersChart: NumbersIWorkItem {
}
extension SBObject: NumbersChart {}

// MARK: NumbersImage
@objc public protocol NumbersImage: NumbersIWorkItem {
    @objc optional var objectDescription: String { get } // Text associated with the image, read aloud by VoiceOver.
    @objc optional var file: URL { get } // The image file.
    @objc optional var fileName: Any { get } // The name of the image file.
    @objc optional var opacity: Int { get } // The opacity of the object, in percent.
    @objc optional var reflectionShowing: Bool { get } // Is the iWork item displaying a reflection?
    @objc optional var reflectionValue: Int { get } // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
}
extension SBObject: NumbersImage {}

// MARK: NumbersGroup
@objc public protocol NumbersGroup: NumbersIWorkContainer {
    @objc optional var height: Int { get } // The height of the iWork item.
    @objc optional var parent: NumbersIWorkContainer { get } // The iWork container containing this iWork item.
    @objc optional var position: NSPoint { get } // The horizontal and vertical coordinates of the top left point of the iWork item.
    @objc optional var width: Int { get } // The width of the iWork item.
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
}
extension SBObject: NumbersGroup {}

// MARK: NumbersLine
@objc public protocol NumbersLine: NumbersIWorkItem {
    @objc optional var endPoint: NSPoint { get } // A list of two numbers indicating the horizontal and vertical position of the line ending point.
    @objc optional var reflectionShowing: Bool { get } // Is the iWork item displaying a reflection?
    @objc optional var reflectionValue: Int { get } // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
    @objc optional var startPoint: NSPoint { get } // A list of two numbers indicating the horizontal and vertical position of the line starting point.
}
extension SBObject: NumbersLine {}

// MARK: NumbersMovie
@objc public protocol NumbersMovie: NumbersIWorkItem {
    @objc optional var fileName: Any { get } // The name of the movie file.
    @objc optional var movieVolume: Int { get } // The volume setting for the movie, from 0 (none) to 100 (full volume).
    @objc optional var opacity: Int { get } // The opacity of the object, in percent.
    @objc optional var reflectionShowing: Bool { get } // Is the iWork item displaying a reflection?
    @objc optional var reflectionValue: Int { get } // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional var repetitionMethod: NumbersPlaybackRepetitionMethod { get } // If or how the movie repeats.
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
}
extension SBObject: NumbersMovie {}

// MARK: NumbersTable
@objc public protocol NumbersTable: NumbersIWorkItem {
    @objc optional var name: String { get } // The item's name.
    @objc optional var cellRange: NumbersRange { get } // The range describing every cell in the table.
    @objc optional var selectionRange: NumbersRange { get } // The cells currently selected in the table.
    @objc optional var rowCount: Int { get } // The number of rows in the table.
    @objc optional var columnCount: Int { get } // The number of columns in the table.
    @objc optional var headerRowCount: Int { get } // The number of header rows in the table.
    @objc optional var headerColumnCount: Int { get } // The number of header columns in the table.
    @objc optional var footerRowCount: Int { get } // The number of footer rows in the table.
    @objc optional var filtered: Bool { get } // Whether the table is currently filtered.
    @objc optional var headerRowsFrozen: Bool { get } // Whether header rows are frozen.
    @objc optional var headerColumnsFrozen: Bool { get } // Whether header columns are frozen.
    @objc optional func cells() -> SBElementArray
    @objc optional func rows() -> SBElementArray
    @objc optional func columns() -> SBElementArray
    @objc optional func ranges() -> SBElementArray
    @objc optional func sortBy(_ by: NumbersColumn!, direction: NumbersNMSD, inRows: NumbersRange!) // Sort the rows of the table.
    @objc optional func transpose() // Transpose the rows and columns of the table.
}
extension SBObject: NumbersTable {}

// MARK: NumbersTextItem
@objc public protocol NumbersTextItem: NumbersIWorkItem {
    @objc optional var backgroundFillType: NumbersItemFillOptions { get } // The background, if any, for the text item.
    @objc optional var objectText: NumbersRichText { get } // The text contained within the text item.
    @objc optional var opacity: Int { get } // The opacity of the object, in percent.
    @objc optional var reflectionShowing: Bool { get } // Is the iWork item displaying a reflection?
    @objc optional var reflectionValue: Int { get } // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
}
extension SBObject: NumbersTextItem {}

// MARK: NumbersRange
@objc public protocol NumbersRange: SBObjectProtocol, NumbersGenericMethods {
    @objc optional var fontName: String { get } // The font of the range's cells.
    @objc optional var fontSize: Double { get } // The font size of the range's cells.
    @objc optional var format: NumbersNMCT { get } // The format of the range's cells.
    @objc optional var alignment: NumbersTAHT { get } // The horizontal alignment of content in the range's cells.
    @objc optional var name: String { get } // The range's coordinates.
    @objc optional var textColor: NSColor { get } // The text color of the range's cells.
    @objc optional var textWrap: Bool { get } // Whether text should wrap in the range's cells.
    @objc optional var backgroundColor: NSColor { get } // The background color of the range's cells.
    @objc optional var verticalAlignment: NumbersTAVT { get } // The vertical alignment of content in the range's cells.
    @objc optional func cells() -> SBElementArray
    @objc optional func columns() -> SBElementArray
    @objc optional func rows() -> SBElementArray
    @objc optional func clear() // Clear the contents of a specified range of cells, including formatting and style.
    @objc optional func merge() // Merge a specified range of cells.
    @objc optional func unmerge() // Unmerge all merged cells in a specified range.
    @objc optional func addColumnAfter() -> SBObject // Add a column to the table after a specified range of cells.
    @objc optional func addColumnBefore() -> SBObject // Add a column to the table before a specified range of cells.
    @objc optional func addRowAbove() -> SBObject // Add a row to the table below a specified range of cells.
    @objc optional func addRowBelow() -> SBObject // Add a row to the table below a specified range of cells.
    @objc optional func remove() // Remove specified rows or columns from a table.
}
extension SBObject: NumbersRange {}

// MARK: NumbersCell
@objc public protocol NumbersCell: NumbersRange {
    @objc optional var column: NumbersColumn { get } // The cell's column.
    @objc optional var row: NumbersRow { get } // The cell's row.
    @objc optional var value: Any { get } // The actual value in the cell, or missing value if the cell is empty.
    @objc optional var formattedValue: String { get } // The formatted value in the cell, or missing value if the cell is empty.
    @objc optional var formula: String { get } // The formula in the cell, as text, e.g. =SUM(40+2). If the cell does not contain a formula, returns missing value. To set the value of a cell to a formula as text, use the value property.
}
extension SBObject: NumbersCell {}

// MARK: NumbersRow
@objc public protocol NumbersRow: NumbersRange {
    @objc optional var address: Int { get } // The row's index in the table (e.g., the second row has address 2).
    @objc optional var height: Double { get } // The height of the row.
}
extension SBObject: NumbersRow {}

// MARK: NumbersColumn
@objc public protocol NumbersColumn: NumbersRange {
    @objc optional var address: Int { get } // The column's index in the table (e.g., the second column has address 2).
    @objc optional var width: Double { get } // The width of the column.
}
extension SBObject: NumbersColumn {}

// MARK: NumbersSheet
@objc public protocol NumbersSheet: NumbersIWorkContainer {
    @objc optional var name: String { get } // The sheet's name.
}
extension SBObject: NumbersSheet {}

// MARK: NumbersTemplate
@objc public protocol NumbersTemplate: SBObjectProtocol, NumbersGenericMethods {
    @objc optional var name: String { get } // The localized name displayed to the user.
    @objc optional func id() -> String // The identifier used by the application.
}
extension SBObject: NumbersTemplate {}

