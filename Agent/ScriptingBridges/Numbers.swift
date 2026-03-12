// MARK: NumbersSaveOptions
@objc public enum NumbersSaveOptions : AEKeyword {
    case yes = 0x79657320 /* b'yes ' */
    case no = 0x6e6f2020 /* b'no  ' */
    case ask = 0x61736b20 /* b'ask ' */
}

// MARK: NumbersPrintingErrorHandling
@objc public enum NumbersPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* b'lwst' */
    case detailed = 0x6c776474 /* b'lwdt' */
}

// MARK: NumbersTAVT
@objc public enum NumbersTAVT : AEKeyword {
    case bottom = 0x61766274 /* b'avbt' */
    case center = 0x61637472 /* b'actr' */
    case top = 0x61767470 /* b'avtp' */
}

// MARK: NumbersTAHT
@objc public enum NumbersTAHT : AEKeyword {
    case autoAlign = 0x61617574 /* b'aaut' */
    case center = 0x61637472 /* b'actr' */
    case justify = 0x616a7374 /* b'ajst' */
    case left = 0x616c6674 /* b'alft' */
    case right = 0x61726974 /* b'arit' */
}

// MARK: NumbersNMSD
@objc public enum NumbersNMSD : AEKeyword {
    case ascending = 0x6173636e /* b'ascn' */
    case descending = 0x6473636e /* b'dscn' */
}

// MARK: NumbersNMCT
@objc public enum NumbersNMCT : AEKeyword {
    case automatic = 0x66617574 /* b'faut' */
    case checkbox = 0x66636368 /* b'fcch' */
    case currency = 0x66637572 /* b'fcur' */
    case dateAndTime = 0x6664746d /* b'fdtm' */
    case fraction = 0x66667261 /* b'ffra' */
    case number = 0x6e6d6272 /* b'nmbr' */
    case percent = 0x66706572 /* b'fper' */
    case popUpMenu = 0x66637070 /* b'fcpp' */
    case scientific = 0x66736369 /* b'fsci' */
    case slider = 0x6663736c /* b'fcsl' */
    case stepper = 0x66637374 /* b'fcst' */
    case text = 0x63747874 /* b'ctxt' */
    case duration = 0x66647572 /* b'fdur' */
    case rating = 0x66726174 /* b'frat' */
    case numeralSystem = 0x66636e73 /* b'fcns' */
}

// MARK: NumbersItemFillOptions
@objc public enum NumbersItemFillOptions : AEKeyword {
    case noFill = 0x66696e6f /* b'fino' */
    case colorFill = 0x6669636f /* b'fico' */
    case gradientFill = 0x66696772 /* b'figr' */
    case advancedGradientFill = 0x66696167 /* b'fiag' */
    case imageFill = 0x6669696d /* b'fiim' */
    case advancedImageFill = 0x66696169 /* b'fiai' */
}

// MARK: NumbersPlaybackRepetitionMethod
@objc public enum NumbersPlaybackRepetitionMethod : AEKeyword {
    case none = 0x6d76726e /* b'mvrn' */
    case loop = 0x6d766c70 /* b'mvlp' */
    case loopBackAndForth = 0x6d766266 /* b'mvbf' */
}

// MARK: NumbersSaveableFileFormat
@objc public enum NumbersSaveableFileFormat : AEKeyword {
    case numbers = 0x4e756666 /* b'Nuff' */
}

// MARK: NumbersExportFormat
@objc public enum NumbersExportFormat : AEKeyword {
    case pdf = 0x4e706466 /* b'Npdf' */
    case microsoftExcel = 0x4e65786c /* b'Nexl' */
    case csv = 0x4e637376 /* b'Ncsv' */
    case numbers09 = 0x4e6e6d62 /* b'Nnmb' */
}

// MARK: NumbersImageQuality
@objc public enum NumbersImageQuality : AEKeyword {
    case good = 0x4b6e5030 /* b'KnP0' */
    case better = 0x4b6e5031 /* b'KnP1' */
    case best = 0x4b6e5032 /* b'KnP2' */
}

// MARK: NumbersGenericMethods
@objc public protocol NumbersGenericMethods {
    @objc optional func closeSaving(_ saving: NumbersSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ in_: URL!, as: NumbersSaveableFileFormat) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: NumbersApplication
@objc public protocol NumbersApplication: SBApplicationProtocol {
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
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
    @objc optional func exportTo(_ to: URL!, as: NumbersExportFormat, withProperties: [AnyHashable : Any]!) // Export a document to another file
    @objc optional var selection: [NumbersIWorkItem] { get } // A list of the currently selected items.
    @objc optional var passwordProtected: Bool { get } // Whether the document is password protected or not.
    @objc optional func setSelection(_ selection: [NumbersIWorkItem]!) // A list of the currently selected items.
    @objc optional func sheets() -> SBElementArray
    @objc optional func id() -> String // Document ID.
    @objc optional var documentTemplate: NumbersTemplate { get } // The template assigned to the document.
    @objc optional var activeSheet: NumbersSheet { get } // The active sheet.
    @objc optional func setActiveSheet(_ activeSheet: NumbersSheet!) // The active sheet.
}
extension SBObject: NumbersDocument {}

// MARK: NumbersWindow
@objc public protocol NumbersWindow: SBObjectProtocol, NumbersGenericMethods {
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
    @objc optional var document: NumbersDocument { get } // The document whose contents are displayed in the window.
    @objc optional func setIndex(_ index: Int) // The index of the window, ordered front to back.
    @objc optional func setBounds(_ bounds: NSRect) // The bounding rectangle of the window.
    @objc optional func setMiniaturized(_ miniaturized: Bool) // Is the window minimized right now?
    @objc optional func setVisible(_ visible: Bool) // Is the window visible right now?
    @objc optional func setZoomed(_ zoomed: Bool) // Is the window zoomed right now?
}
extension SBObject: NumbersWindow {}

// MARK: NumbersRichText
@objc public protocol NumbersRichText: SBObjectProtocol, NumbersGenericMethods {
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
    @objc optional var color: NSColor { get } // The color of the font. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
    @objc optional var font: String { get } // The name of the font.  Can be the PostScript name, such as: “TimesNewRomanPS-ItalicMT”, or display name: “Times New Roman Italic”. TIP: Use the Font Book application get the information about a typeface.
    @objc optional var size: Double { get } // The size of the font.
    @objc optional func setColor(_ color: NSColor!) // The color of the font. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
    @objc optional func setFont(_ font: String!) // The name of the font.  Can be the PostScript name, such as: “TimesNewRomanPS-ItalicMT”, or display name: “Times New Roman Italic”. TIP: Use the Font Book application get the information about a typeface.
    @objc optional func setSize(_ size: Double) // The size of the font.
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
    @objc optional func setHeight(_ height: Int) // The height of the iWork item.
    @objc optional func setLocked(_ locked: Bool) // Whether the object is locked.
    @objc optional func setPosition(_ position: NSPoint) // The horizontal and vertical coordinates of the top left point of the iWork item.
    @objc optional func setWidth(_ width: Int) // The width of the iWork item.
}
extension SBObject: NumbersIWorkItem {}

// MARK: NumbersAudioClip
@objc public protocol NumbersAudioClip: NumbersIWorkItem {
    @objc optional var fileName: Any { get } // The name of the audio file.
    @objc optional var clipVolume: Int { get } // The volume setting for the audio clip, from 0 (none) to 100 (full volume).
    @objc optional var repetitionMethod: NumbersPlaybackRepetitionMethod { get } // If or how the audio clip repeats.
    @objc optional func setFileName(_ fileName: Any!) // The name of the audio file.
    @objc optional func setClipVolume(_ clipVolume: Int) // The volume setting for the audio clip, from 0 (none) to 100 (full volume).
    @objc optional func setRepetitionMethod(_ repetitionMethod: NumbersPlaybackRepetitionMethod) // If or how the audio clip repeats.
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
    @objc optional func setObjectText(_ objectText: NumbersRichText!) // The text contained within the shape.
    @objc optional func setReflectionShowing(_ reflectionShowing: Bool) // Is the iWork item displaying a reflection?
    @objc optional func setReflectionValue(_ reflectionValue: Int) // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional func setRotation(_ rotation: Int) // The rotation of the iWork item, in degrees from 0 to 359.
    @objc optional func setOpacity(_ opacity: Int) // The opacity of the object, in percent.
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
    @objc optional func setObjectDescription(_ objectDescription: String!) // Text associated with the image, read aloud by VoiceOver.
    @objc optional func setFileName(_ fileName: Any!) // The name of the image file.
    @objc optional func setOpacity(_ opacity: Int) // The opacity of the object, in percent.
    @objc optional func setReflectionShowing(_ reflectionShowing: Bool) // Is the iWork item displaying a reflection?
    @objc optional func setReflectionValue(_ reflectionValue: Int) // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional func setRotation(_ rotation: Int) // The rotation of the iWork item, in degrees from 0 to 359.
}
extension SBObject: NumbersImage {}

// MARK: NumbersGroup
@objc public protocol NumbersGroup: NumbersIWorkContainer {
    @objc optional var height: Int { get } // The height of the iWork item.
    @objc optional var parent: NumbersIWorkContainer { get } // The iWork container containing this iWork item.
    @objc optional var position: NSPoint { get } // The horizontal and vertical coordinates of the top left point of the iWork item.
    @objc optional var width: Int { get } // The width of the iWork item.
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
    @objc optional func setHeight(_ height: Int) // The height of the iWork item.
    @objc optional func setPosition(_ position: NSPoint) // The horizontal and vertical coordinates of the top left point of the iWork item.
    @objc optional func setWidth(_ width: Int) // The width of the iWork item.
    @objc optional func setRotation(_ rotation: Int) // The rotation of the iWork item, in degrees from 0 to 359.
}
extension SBObject: NumbersGroup {}

// MARK: NumbersLine
@objc public protocol NumbersLine: NumbersIWorkItem {
    @objc optional var endPoint: NSPoint { get } // A list of two numbers indicating the horizontal and vertical position of the line ending point.
    @objc optional var reflectionShowing: Bool { get } // Is the iWork item displaying a reflection?
    @objc optional var reflectionValue: Int { get } // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional var rotation: Int { get } // The rotation of the iWork item, in degrees from 0 to 359.
    @objc optional var startPoint: NSPoint { get } // A list of two numbers indicating the horizontal and vertical position of the line starting point.
    @objc optional func setEndPoint(_ endPoint: NSPoint) // A list of two numbers indicating the horizontal and vertical position of the line ending point.
    @objc optional func setReflectionShowing(_ reflectionShowing: Bool) // Is the iWork item displaying a reflection?
    @objc optional func setReflectionValue(_ reflectionValue: Int) // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional func setRotation(_ rotation: Int) // The rotation of the iWork item, in degrees from 0 to 359.
    @objc optional func setStartPoint(_ startPoint: NSPoint) // A list of two numbers indicating the horizontal and vertical position of the line starting point.
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
    @objc optional func setFileName(_ fileName: Any!) // The name of the movie file.
    @objc optional func setMovieVolume(_ movieVolume: Int) // The volume setting for the movie, from 0 (none) to 100 (full volume).
    @objc optional func setOpacity(_ opacity: Int) // The opacity of the object, in percent.
    @objc optional func setReflectionShowing(_ reflectionShowing: Bool) // Is the iWork item displaying a reflection?
    @objc optional func setReflectionValue(_ reflectionValue: Int) // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional func setRepetitionMethod(_ repetitionMethod: NumbersPlaybackRepetitionMethod) // If or how the movie repeats.
    @objc optional func setRotation(_ rotation: Int) // The rotation of the iWork item, in degrees from 0 to 359.
}
extension SBObject: NumbersMovie {}

// MARK: NumbersTable
@objc public protocol NumbersTable: NumbersIWorkItem {
    @objc optional func cells() -> SBElementArray
    @objc optional func rows() -> SBElementArray
    @objc optional func columns() -> SBElementArray
    @objc optional func ranges() -> SBElementArray
    @objc optional var name: String { get } // The item's name.
    @objc optional var cellRange: NumbersRange { get } // The range describing every cell in the table.
    @objc optional var selectionRange: NumbersRange { get } // The cells currently selected in the table.
    @objc optional var rowCount: Int { get } // The number of rows in the table.
    @objc optional var columnCount: Int { get } // The number of columns in the table.
    @objc optional var headerRowCount: Int { get } // The number of header rows in the table.
    @objc optional var headerColumnCount: Int { get } // The number of header columns in the table.
    @objc optional var footerRowCount: Int { get } // The number of footer rows in the table.
    @objc optional func sortBy(_ by: NumbersColumn!, direction: NumbersNMSD, inRows: NumbersRange!) // Sort the rows of the table.
    @objc optional func transpose() // Transpose the rows and columns of the table.
    @objc optional func setName(_ name: String!) // The item's name.
    @objc optional func setSelectionRange(_ selectionRange: NumbersRange!) // The cells currently selected in the table.
    @objc optional func setRowCount(_ rowCount: Int) // The number of rows in the table.
    @objc optional func setColumnCount(_ columnCount: Int) // The number of columns in the table.
    @objc optional func setHeaderRowCount(_ headerRowCount: Int) // The number of header rows in the table.
    @objc optional func setHeaderColumnCount(_ headerColumnCount: Int) // The number of header columns in the table.
    @objc optional func setFooterRowCount(_ footerRowCount: Int) // The number of footer rows in the table.
    @objc optional var filtered: Bool { get } // Whether the table is currently filtered.
    @objc optional var headerRowsFrozen: Bool { get } // Whether header rows are frozen.
    @objc optional var headerColumnsFrozen: Bool { get } // Whether header columns are frozen.
    @objc optional func setFiltered(_ filtered: Bool) // Whether the table is currently filtered.
    @objc optional func setHeaderRowsFrozen(_ headerRowsFrozen: Bool) // Whether header rows are frozen.
    @objc optional func setHeaderColumnsFrozen(_ headerColumnsFrozen: Bool) // Whether header columns are frozen.
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
    @objc optional func setObjectText(_ objectText: NumbersRichText!) // The text contained within the text item.
    @objc optional func setOpacity(_ opacity: Int) // The opacity of the object, in percent.
    @objc optional func setReflectionShowing(_ reflectionShowing: Bool) // Is the iWork item displaying a reflection?
    @objc optional func setReflectionValue(_ reflectionValue: Int) // The percentage of reflection of the iWork item, from 0 (none) to 100 (full).
    @objc optional func setRotation(_ rotation: Int) // The rotation of the iWork item, in degrees from 0 to 359.
}
extension SBObject: NumbersTextItem {}

// MARK: NumbersRange
@objc public protocol NumbersRange: SBObjectProtocol, NumbersGenericMethods {
    @objc optional func cells() -> SBElementArray
    @objc optional func columns() -> SBElementArray
    @objc optional func rows() -> SBElementArray
    @objc optional var fontName: String { get } // The font of the range's cells.
    @objc optional var fontSize: Double { get } // The font size of the range's cells.
    @objc optional var format: NumbersNMCT { get } // The format of the range's cells.
    @objc optional var alignment: NumbersTAHT { get } // The horizontal alignment of content in the range's cells.
    @objc optional var name: String { get } // The range's coordinates.
    @objc optional var textColor: NSColor { get } // The text color of the range's cells.
    @objc optional var textWrap: Bool { get } // Whether text should wrap in the range's cells.
    @objc optional var backgroundColor: NSColor { get } // The background color of the range's cells.
    @objc optional var verticalAlignment: NumbersTAVT { get } // The vertical alignment of content in the range's cells.
    @objc optional func clear() // Clear the contents of a specified range of cells, including formatting and style.
    @objc optional func merge() // Merge a specified range of cells.
    @objc optional func unmerge() // Unmerge all merged cells in a specified range.
    @objc optional func addColumnAfter() -> SBObject // Add a column to the table after a specified range of cells.
    @objc optional func addColumnBefore() -> SBObject // Add a column to the table before a specified range of cells.
    @objc optional func addRowAbove() -> SBObject // Add a row to the table below a specified range of cells.
    @objc optional func addRowBelow() -> SBObject // Add a row to the table below a specified range of cells.
    @objc optional func remove() // Remove specified rows or columns from a table.
    @objc optional func setFontName(_ fontName: String!) // The font of the range's cells.
    @objc optional func setFontSize(_ fontSize: Double) // The font size of the range's cells.
    @objc optional func setFormat(_ format: NumbersNMCT) // The format of the range's cells.
    @objc optional func setAlignment(_ alignment: NumbersTAHT) // The horizontal alignment of content in the range's cells.
    @objc optional func setTextColor(_ textColor: NSColor!) // The text color of the range's cells.
    @objc optional func setTextWrap(_ textWrap: Bool) // Whether text should wrap in the range's cells.
    @objc optional func setBackgroundColor(_ backgroundColor: NSColor!) // The background color of the range's cells.
    @objc optional func setVerticalAlignment(_ verticalAlignment: NumbersTAVT) // The vertical alignment of content in the range's cells.
}
extension SBObject: NumbersRange {}

// MARK: NumbersCell
@objc public protocol NumbersCell: NumbersRange {
    @objc optional var column: NumbersColumn { get } // The cell's column.
    @objc optional var row: NumbersRow { get } // The cell's row.
    @objc optional var value: Any { get } // The actual value in the cell, or missing value if the cell is empty.
    @objc optional var formattedValue: String { get } // The formatted value in the cell, or missing value if the cell is empty.
    @objc optional var formula: String { get } // The formula in the cell, as text, e.g. =SUM(40+2). If the cell does not contain a formula, returns missing value. To set the value of a cell to a formula as text, use the value property.
    @objc optional func setValue(_ value: Any!) // The actual value in the cell, or missing value if the cell is empty.
}
extension SBObject: NumbersCell {}

// MARK: NumbersRow
@objc public protocol NumbersRow: NumbersRange {
    @objc optional var address: Int { get } // The row's index in the table (e.g., the second row has address 2).
    @objc optional var height: Double { get } // The height of the row.
    @objc optional func setHeight(_ height: Double) // The height of the row.
}
extension SBObject: NumbersRow {}

// MARK: NumbersColumn
@objc public protocol NumbersColumn: NumbersRange {
    @objc optional var address: Int { get } // The column's index in the table (e.g., the second column has address 2).
    @objc optional var width: Double { get } // The width of the column.
    @objc optional func setWidth(_ width: Double) // The width of the column.
}
extension SBObject: NumbersColumn {}

// MARK: NumbersSheet
@objc public protocol NumbersSheet: NumbersIWorkContainer {
    @objc optional var name: String { get } // The sheet's name.
    @objc optional func setName(_ name: String!) // The sheet's name.
}
extension SBObject: NumbersSheet {}

// MARK: NumbersTemplate
@objc public protocol NumbersTemplate: SBObjectProtocol, NumbersGenericMethods {
    @objc optional func id() -> String // The identifier used by the application.
    @objc optional var name: String { get } // The localized name displayed to the user.
}
extension SBObject: NumbersTemplate {}

