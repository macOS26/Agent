// MARK: PixelmatorProSaveOptions
@objc public enum PixelmatorProSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: PixelmatorProPrintingErrorHandling
@objc public enum PixelmatorProPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: PixelmatorProSaveableFileFormat
@objc public enum PixelmatorProSaveableFileFormat : AEKeyword {
    case pixelmatorPro = 0x50707864 /* The native Pixelmator Pro file format. */
    case heic = 0x50686963 /* HEIC */
    case jpeg = 0x506a7067 /* JPEG */
    case png = 0x50706e67 /* PNG */
    case webP = 0x50776270 /* WebP */
    case tiff = 0x50746966 /* TIFF */
    case svg = 0x50737667 /* SVG */
    case gif = 0x50676966 /* GIF */
    case psd = 0x50707364 /* Adobe Photoshop document. */
}

// MARK: PixelmatorProExportFormat
@objc public enum PixelmatorProExportFormat : AEKeyword {
    case png = 0x50706e67 /* PNG */
    case tiff = 0x50746966 /* TIFF */
    case jpeg = 0x506a7067 /* JPEG */
    case heic = 0x50686963 /* HEIC */
    case gif = 0x50676966 /* GIF */
    case jpeg2000 = 0x506a7032 /* JPEG 2000 */
    case bmp = 0x50626d70 /* BMP */
    case webP = 0x50776270 /* WebP */
    case svg = 0x50737667 /* SVG */
    case pdf = 0x50706466 /* PDF */
    case psd = 0x50707364 /* Adobe Photoshop document. */
    case pixelmatorPro = 0x50707864 /* The native Pixelmator Pro file format. */
    case motion = 0x506d746e /* Motion project. */
    case mp4 = 0x6d703476 /* MP4 */
    case quickTimeMovie = 0x51546d76 /* QuickTime Movie */
    case animatedGIF = 0x61474946 /* Animated GIF */
    case animatedPNG = 0x61504e47 /* Animated PNG */
    case openEXR = 0x50657872 /* OpenEXR */
    case hdrjpeg = 0x50686a70 /* HDR JPEG */
    case hdrheic = 0x50686964 /* HDR HEIC */
    case hdravif = 0x50617664 /* HDR AVIF */
    case hdrpng = 0x50706e64 /* HDR PNG */
}

// MARK: PixelmatorProExportForWebFormat
@objc public enum PixelmatorProExportForWebFormat : AEKeyword {
    case png = 0x50706e67 /* PNG */
    case jpeg = 0x506a7067 /* JPEG */
    case gif = 0x50676966 /* GIF */
    case svg = 0x50737667 /* SVG */
    case webP = 0x50776270 /* WebP */
}

// MARK: PixelmatorProBlendMode
@objc public enum PixelmatorProBlendMode : AEKeyword {
    case normal = 0x6e6f726d /* Normal */
    case darken = 0x426d646b /* Darken */
    case multiply = 0x426d6d70 /* Multiply */
    case colorBurn = 0x426d6362 /* Color Burn */
    case linearBurn = 0x426d6c62 /* Linear Burn */
    case darkerColor = 0x426d6463 /* Darken */
    case lighten = 0x426d6c67 /* Lighten */
    case screen = 0x66697473 /* Screen */
    case colorDodge = 0x426d6364 /* Color Dodge */
    case linearDodge = 0x426d6c64 /* Linear Dodge */
    case lighterColor = 0x426d6c63 /* Lighter Color */
    case overlay = 0x426d6f72 /* Overlay */
    case softLight = 0x426d736c /* Soft Light */
    case hardLight = 0x426d686c /* Hard Light */
    case vividLight = 0x426d766c /* Vivid Light */
    case linearLight = 0x426d6c6c /* Linear Light */
    case pinLight = 0x426d706c /* Pin Light */
    case hardMix = 0x426d6878 /* Hard Mix */
    case difference = 0x426d6466 /* Difference */
    case exclusion = 0x426d6578 /* Exclusion */
    case subtract = 0x426d7362 /* Subtract */
    case divide = 0x426d6476 /* Divide */
    case hueBlendMode = 0x426d6875 /* Hue */
    case saturationBlendMode = 0x426d7361 /* Saturation */
    case colorBlendMode = 0x426d636c /* Color */
    case luminosity = 0x426d6c75 /* Luminosity */
    case passThrough = 0x426d7074 /* Pass Through */
    case behindBlendMode = 0x62656848 /* Behind */
}

// MARK: PixelmatorProResamplingAlgorithm
@objc public enum PixelmatorProResamplingAlgorithm : AEKeyword {
    case none = 0x4e6f7273 /* None */
    case bilinear = 0x426c6e72 /* Bilinear */
    case lanczos = 0x4c6e637a /* Lanczos */
    case nearest = 0x4e727374 /* Nearest Neighbor */
    case mlSuperResolution = 0x4d6c7372 /* Super Resolution */
}

// MARK: PixelmatorProSelectionMode
@objc public enum PixelmatorProSelectionMode : AEKeyword {
    case newSelection = 0x4e657720 /* Create a new selection. */
    case addSelection = 0x41646420 /* Add to the existing selection. */
    case subtractSelection = 0x53627472 /* Subtract from the existing selection. */
    case intersectSelection = 0x496e7472 /* Intersect with the existing selection. */
}

// MARK: PixelmatorProScaleMode
@objc public enum PixelmatorProScaleMode : AEKeyword {
    case original = 0x4f72676e /* Original scale. */
    case stretch = 0x53747274 /* Stretch to fill */
    case scaleToFill = 0x5366696c /* Scale to fill */
    case scaleToFit = 0x53666974 /* Scale to fit */
}

// MARK: PixelmatorProMaskMode
@objc public enum PixelmatorProMaskMode : AEKeyword {
    case revealAll = 0x5276616c /* A mask that is solid white and reveals all the contents of a layer. */
    case hideAll = 0x4864616c /* A mask that is solid black and hides all the contents of a layer. */
}

// MARK: PixelmatorProStrokePosition
@objc public enum PixelmatorProStrokePosition : AEKeyword {
    case inside = 0x5374696e /* Inside stroke */
    case center = 0x63656e74 /* Center stroke */
    case outside = 0x53746f74 /* Outisde stroke */
}

// MARK: PixelmatorProStrokeType
@objc public enum PixelmatorProStrokeType : AEKeyword {
    case line = 0x4c696e65 /* Line stroke */
    case dash = 0x44617368 /* Dashed stroke */
    case dot = 0x446f7420 /* Dotted stroke */
}

// MARK: PixelmatorProAnchor
@objc public enum PixelmatorProAnchor : AEKeyword {
    case topLeft = 0x54706c66
    case topCenter = 0x5470636e
    case topRight = 0x54707267
    case middleLeft = 0x4d646c66
    case middleCenter = 0x436e7472
    case middleRight = 0x4d647267
    case bottomLeft = 0x42746c66
    case bottomCenter = 0x4274636e
    case bottomRight = 0x42747267
}

// MARK: PixelmatorProTrimMode
@objc public enum PixelmatorProTrimMode : AEKeyword {
    case transparency = 0x54727472
    case topLeftColor = 0x5472746c
    case bottomRightColor = 0x54726272
}

// MARK: PixelmatorProColorProfileMode
@objc public enum PixelmatorProColorProfileMode : AEKeyword {
    case assign = 0x43706173
    case match = 0x43706d74
}

// MARK: PixelmatorProDiUr
@objc public enum PixelmatorProDiUr : AEKeyword {
    case none = 0x444e6e65
    case high = 0x65313037
    case two = 0x54776f20
    case three = 0x65313033
    case four = 0x466f7572
    case normal = 0x4e726d6c
    case six = 0x65313035
    case seven = 0x65313036
    case low = 0x65313031
}

// MARK: PixelmatorProDiCp
@objc public enum PixelmatorProDiCp : AEKeyword {
    case unmarked = 0x43703033
    case copyrightedWork = 0x43703031
    case publicDomain = 0x43703032
}

// MARK: PixelmatorProApplicationAppearance
@objc public enum PixelmatorProApplicationAppearance : AEKeyword {
    case auto = 0x41757461 /* Adjust Pixelmator Pro appearance automatically to match system appearance. */
    case dark = 0x4164726b /* Dark appearace. */
    case light = 0x416c6768 /* Light appearance. */
}

// MARK: PixelmatorProImageOpeningWorkflow
@objc public enum PixelmatorProImageOpeningWorkflow : AEKeyword {
    case openInOriginalFormat = 0x41696f6f /* Open non-Pixelmator Pro files (JPEG, PNG, etc.) in their original format whenever possible. */
    case importAsPixelmatorPro = 0x41696f69 /* Create a new Pixelmator Pro file for every image opened in a non-native format. */
}

// MARK: PixelmatorProSidecarLocation
@objc public enum PixelmatorProSidecarLocation : AEKeyword {
    case icloudDrive = 0x41736469 /* A folder in the Pixelmator Pro folder in iCloud Drive. */
    case picturesFolder = 0x41736470 /* A folder in the Pictures folder. */
}

// MARK: PixelmatorProTAHT
@objc public enum PixelmatorProTAHT : AEKeyword {
    case left = 0x6c655441 /* Left-align content. */
    case center = 0x63656e74 /* Center-align content. */
    case right = 0x72695441 /* Right-align content. */
    case justify = 0x6a755441 /* Fully justify (left and right) content. */
}

// MARK: PixelmatorProTAVT
@objc public enum PixelmatorProTAVT : AEKeyword {
    case top = 0x746f7041 /* Top-align content. */
    case center = 0x63656e74 /* Center-align content. */
    case bottom = 0x626f7441 /* Bottom-align content. */
}

// MARK: PixelmatorProGenericMethods
@objc public protocol PixelmatorProGenericMethods {
    @objc optional func closeSaving(_ saving: PixelmatorProSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ `in`: URL!, `as`: PixelmatorProSaveableFileFormat) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
    @objc optional func select() // Select one or multiple layers.
}

// MARK: PixelmatorProApplication
@objc public protocol PixelmatorProApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional var autosaveEnabled: Bool { get } // Is autosave enabled?
    @objc optional var appearance: PixelmatorProApplicationAppearance { get } // The appearance of the application.
    @objc optional var loadHdrContent: Bool { get } // Is HDR content loading enabled?
    @objc optional var imageOpeningWorkflow: PixelmatorProImageOpeningWorkflow { get } // How images in non-native formats are opened – whether they're opened in their original format whenever possible, or always imported as Pixelmator Pro files.
    @objc optional var sidecarEnabled: Bool { get } // Whether layers and edits will be preserved in a sidecar file linked to the original image file. Returns true only if the image the opening workflow is set to "open in original format" and sidecar is enabled, false otherwise.
    @objc optional var sidecarLocation: PixelmatorProSidecarLocation { get } // The location (iCloud or Pictures) that sidecar files are currently being saved in.
    @objc optional var buildNumber: String { get } // The build number of the current version.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: PixelmatorProSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func makeDocumentFromClipboard() -> PixelmatorProDocument // Make a new document from an image in  the clipboard.
}
extension SBApplication: PixelmatorProApplication {}

// MARK: PixelmatorProDocument
@objc public protocol PixelmatorProDocument: SBObjectProtocol, PixelmatorProGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
    @objc optional var properties: [AnyHashable : Any] { get } // All of this object's properties returned in a single record.
    @objc optional var dataReference: String { get } // Used for automated publishing, the data reference may hold a reference to a disk item, or database record, related to the contents of the layer.
    @objc optional var width: Double { get } // The width of the document (in pixels).
    @objc optional var height: Double { get } // The height of the document (in pixels).
    @objc optional var resolution: Double { get } // The resolution of the document (in pixels per inch).
    @objc optional var bitsPerChannel: Int { get } // The color depth of the document.
    @objc optional var colorProfile: String { get } // The name of the document's color profile.
    @objc optional var displayHdrContent: Bool { get } // Is display HDR content enabled?
    @objc optional var documentInfo: PixelmatorProDocumentInfo { get } // The document's metada information.
    @objc optional var currentLayer: PixelmatorProLayer { get } // The top-most selected layer.
    @objc optional var selectedLayers: [Any] { get } // A list of all selected layers.
    @objc optional var selectionBounds: [Any] { get } // The bounds of any currently active selection.
    @objc optional func exportTo(_ to: URL!, `as`: PixelmatorProExportFormat, withProperties: [AnyHashable : Any]!) // Export an image to another file.
    @objc optional func exportForWebTo(_ to: URL!, `as`: PixelmatorProExportForWebFormat, withProperties: [AnyHashable : Any]!) // Export an image to another file, optimizing it for the web.
    @objc optional func undo() // Undo changes.
    @objc optional func redo() // Redo changes.
    @objc optional func cut() // Cut the selected layer or image area, copying it to the clipboard.
    @objc optional func copy() // Copy the selected layer or image area to the clipboard.
    @objc optional func paste() // Paste the contents of the clipboard into the document.
    @objc optional func selectAll() // Draw a selection around the entire image.
    @objc optional func deselect() // Deselect any active selections.
    @objc optional func reselect() // Reselect the most recent selection.
    @objc optional func invertSelection() // Invert a selection, changing the unselected areas into selected and vice versa.
    @objc optional func selectSubjectSmartRefine(_ smartRefine: Bool) // Automatically select the main subject of a document or layer.
    @objc optional func refineSelectionRoundness(_ roundness: Int, softness: Int, expand: Int) // Refine a selection, adjusting its roundness, softness, and size.
    @objc optional func smartRefineSelection() // Automatically refine the edges of a selection.
    @objc optional func selectColorRangeColor(_ color: [Any]!, range: Int, mode: PixelmatorProSelectionMode, smoothEdges: Bool) // Select all areas of a specified color. This command can be executed on the document (in which case every layer is sampled) or on a layer, in which case the selection is created based on the layer's content.
    @objc optional func drawSelectionBounds(_ bounds: [Any]!, mode: PixelmatorProSelectionMode) // Draw a rectangular selection.
    @objc optional func drawEllipticalSelectionBounds(_ bounds: [Any]!, mode: PixelmatorProSelectionMode) // Draw an elliptical selection.
    @objc optional func convertSelectionIntoShape() -> PixelmatorProShapeLayer // Convert a selection into a shape.
    @objc optional func fillWithColor(_ withColor: [Any]!, preserveTransparency: Bool) // Fill the current layer or selected area with a color.
    @objc optional func clear() // Delete the currently selected areas of a layer.
    @objc optional func replaceText(_ text: String!, with: String!, withProperties: [AnyHashable : Any]!) // Replace text in the text layers of a document.
    @objc optional func pickColorAt(_ at: NSPoint) -> [Any] // Pick a color at specific coordinates in a document.
    @objc optional func cropBounds(_ bounds: [Any]!, deleteMode: Bool) // Crop a document.
    @objc optional func resizeImageWidth(_ width: Int, height: Int, resolution: Double, algorithm: PixelmatorProResamplingAlgorithm) // Change the size of an image.
    @objc optional func resizeCanvasWidth(_ width: Int, height: Int, relative: Bool, anchorPosition: PixelmatorProAnchor) // Change the size of the image canvas.
    @objc optional func rotate180() // Rotate the entire image by 180 degrees.
    @objc optional func rotateRight() // Rotate the entire image by 90 degrees clockwise.
    @objc optional func rotateLeft() // Rotate the entire image by 90 degrees counterclockwise.
    @objc optional func flipHorizontally() // Flip the entire image horizontally.
    @objc optional func flipVertically() // Flip the entire image vertically.
    @objc optional func superResolution() // Increase the resolution of the image by 300% using the Super Resolution algorithm.
    @objc optional func trimCanvasMode(_ mode: PixelmatorProTrimMode) // Trim away colored or transparent pixels at the edges of the image.
    @objc optional func revealCanvas() // Expand the canvas to reveal any image areas beyond the canvas edges.
    @objc optional func changeColorProfileTo(_ to: String!, mode: PixelmatorProColorProfileMode) // Change the color profile of the image.
    @objc optional func detectFace() -> [AnyHashable : Any] // Find the location of a face in a document.
    @objc optional func detectQRCode() -> [AnyHashable : Any] // Find the location of a QR code in a document.
    @objc optional func enhance() // Automatically enhance the colors of a layer in the image using the ML Enhance algorithm.
    @objc optional func matchColorsTo(_ to: URL!) // Automatically edit the colors of an image to copy the look and feel of another image using the Match Colors algorithm.
    @objc optional func autoWhiteBalance() // Automatically adjust the white balance of a layer.
    @objc optional func autoLight() // Automaticaly edit the colors of the image using the Lightness adjustment to improve its lighting.
    @objc optional func autoColorBalance() // Automatically enhance the colors of the image using the Color Balance adjustment.
    @objc optional func autoHueAndSaturation() // Automatically enhance the colors of the image using the Hue & Saturation adjustment.
    @objc optional func denoiseIntensity(_ intensity: Int) // Automatically remove noise from an image using ML Denoise.
    @objc optional func deband()
    @objc optional func removeBackground() // Automatically remove the background from an image or layer.
    @objc optional func ungroup() // Ungroup a group layer.
    @objc optional func mergeLayers(_ layers: [Any]!) -> PixelmatorProLayer // Merge multiple layers into one.
    @objc optional func mergeAll() -> PixelmatorProLayer // Merge every layer into one.
    @objc optional func mergeVisible() -> PixelmatorProLayer // Merge every visible layer into one.
    @objc optional func selectAllLayers() // Select all layers in a document,
    @objc optional func layers() -> SBElementArray
    @objc optional func imageLayers() -> SBElementArray
    @objc optional func groupLayers() -> SBElementArray
    @objc optional func colorAdjustmentsLayers() -> SBElementArray
    @objc optional func effectsLayers() -> SBElementArray
    @objc optional func shapeLayers() -> SBElementArray
    @objc optional func videoLayers() -> SBElementArray
    @objc optional func textLayers() -> SBElementArray
    @objc optional func id() -> String // The unique identifier of the document.
}
extension SBObject: PixelmatorProDocument {}

// MARK: PixelmatorProWindow
@objc public protocol PixelmatorProWindow: SBObjectProtocol, PixelmatorProGenericMethods {
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
    @objc optional var document: PixelmatorProDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: PixelmatorProWindow {}

// MARK: PixelmatorProLayer
@objc public protocol PixelmatorProLayer: SBObjectProtocol, PixelmatorProGenericMethods {
    @objc optional var properties: [AnyHashable : Any] { get } // All of this layer's properties returned in a single record.
    @objc optional var index: Int { get } // The index of this instance of the object.
    @objc optional var dataReference: String { get } // Used for automated publishing, the data reference may hold a reference to a disk item, or database record, related to the contents of the layer.
    @objc optional var name: String { get } // The name of the layer.
    @objc optional var opacity: Int { get } // The opacity of the layer.
    @objc optional var visible: Bool { get } // Whether the layer is visible.
    @objc optional var locked: Bool { get } // Whether the layer is locked.
    @objc optional var selected: Bool { get } // Whether the layer is selected.
    @objc optional var clippingMask: Bool { get } // Whether the layer is a clipping mask.
    @objc optional var blendMode: PixelmatorProBlendMode { get } // The layer's blend mode.
    @objc optional var width: Double { get } // The width of the layer.
    @objc optional var height: Double { get } // The height of the layer.
    @objc optional var position: NSPoint { get } // The position of the top left corner of the layer.
    @objc optional var rotation: Double { get } // The rotation of the layer, in degrees from 0 to 359.
    @objc optional var colorAdjustments: PixelmatorProColorAdjustments { get } // The color adjustments of the layer.
    @objc optional var styles: PixelmatorProStyles { get } // The layer styles of the layer.
    @objc optional var parent: PixelmatorProLayer { get } // The layer's parent layer.
    @objc optional var layerMask: PixelmatorProLayer { get } // The layer's layer mask.
    @objc optional func effects() -> SBElementArray
    @objc optional func id() -> String // The unique identifier of the layer.
    @objc optional func loadSelectionMode(_ mode: PixelmatorProSelectionMode) // Load the outline of a layer as a selection.
    @objc optional func maskFrom(_ from: URL!, scaleMode: PixelmatorProScaleMode, maskMode: PixelmatorProMaskMode) // Add a layer mask to a layer.
    @objc optional func unmask() // Remove a layer mask from a layer.
    @objc optional func convertIntoPixels() // Convert a layer into pixels. This can be used to both convert text and shapes into pixels or flatten all nondestructive edits.
    @objc optional func applyColorAdjustmentsPresetName(_ name: String!) // Apply a color adjustment preset to a layer.
    @objc optional func applyEffectsPresetName(_ name: String!) // Apply an effect preset to a layer.
}
extension SBObject: PixelmatorProLayer {}

// MARK: PixelmatorProImageLayer
@objc public protocol PixelmatorProImageLayer: PixelmatorProLayer {
    @objc optional var file: URL { get } // The file property is used to create new layers from image files.
    @objc optional var preserveTransparency: Bool { get } // Whether or not preserve transparency is enabled.
    @objc optional var constrainProportions: Bool { get } // Whether or not constrain proportions is enabled.
    @objc optional func replaceImageWith(_ with: URL!, scaleMode: PixelmatorProScaleMode) // Replace an image layer with another, while preserving its adjustments, effects, and layer styles.
    @objc optional func invertColors() // Invert the colors of an image layer.
    @objc optional func decontaminateColors() // Remove colored tinting (a.k.a. fringing) from the edges of an image layer.
}
extension SBObject: PixelmatorProImageLayer {}

// MARK: PixelmatorProGroupLayer
@objc public protocol PixelmatorProGroupLayer: PixelmatorProLayer {
    @objc optional func layers() -> SBElementArray
    @objc optional func imageLayers() -> SBElementArray
    @objc optional func groupLayers() -> SBElementArray
    @objc optional func colorAdjustmentsLayers() -> SBElementArray
    @objc optional func effectsLayers() -> SBElementArray
    @objc optional func shapeLayers() -> SBElementArray
    @objc optional func videoLayers() -> SBElementArray
    @objc optional func textLayers() -> SBElementArray
}
extension SBObject: PixelmatorProGroupLayer {}

// MARK: PixelmatorProColorAdjustmentsLayer
@objc public protocol PixelmatorProColorAdjustmentsLayer: PixelmatorProLayer {
}
extension SBObject: PixelmatorProColorAdjustmentsLayer {}

// MARK: PixelmatorProEffectsLayer
@objc public protocol PixelmatorProEffectsLayer: PixelmatorProLayer {
}
extension SBObject: PixelmatorProEffectsLayer {}

// MARK: PixelmatorProShapeLayer
@objc public protocol PixelmatorProShapeLayer: PixelmatorProLayer {
    @objc optional var constrainProportions: Bool { get } // Whether or not constraint proportions is enabled.
}
extension SBObject: PixelmatorProShapeLayer {}

// MARK: PixelmatorProRectangleShapeLayer
@objc public protocol PixelmatorProRectangleShapeLayer: PixelmatorProShapeLayer {
}
extension SBObject: PixelmatorProRectangleShapeLayer {}

// MARK: PixelmatorProRoundedRectangleShapeLayer
@objc public protocol PixelmatorProRoundedRectangleShapeLayer: PixelmatorProShapeLayer {
    @objc optional var cornerRadius: Double { get } // The corner radius. A valid value is from 0 to the width or height of the rectangle (whichever is smaller) divided by 2.
}
extension SBObject: PixelmatorProRoundedRectangleShapeLayer {}

// MARK: PixelmatorProEllipseShapeLayer
@objc public protocol PixelmatorProEllipseShapeLayer: PixelmatorProShapeLayer {
}
extension SBObject: PixelmatorProEllipseShapeLayer {}

// MARK: PixelmatorProPolygonShapeLayer
@objc public protocol PixelmatorProPolygonShapeLayer: PixelmatorProShapeLayer {
    @objc optional var sides: Int { get } // The number (from 3 to 11) of polygon sides.
}
extension SBObject: PixelmatorProPolygonShapeLayer {}

// MARK: PixelmatorProStarShapeLayer
@objc public protocol PixelmatorProStarShapeLayer: PixelmatorProShapeLayer {
    @objc optional var starPoints: Int { get } // The number (from 3 to 20) of star points.
    @objc optional var starRadius: Double { get } // The radius of the star in percent, from 10 to 100.
}
extension SBObject: PixelmatorProStarShapeLayer {}

// MARK: PixelmatorProLineShapeLayer
@objc public protocol PixelmatorProLineShapeLayer: PixelmatorProShapeLayer {
}
extension SBObject: PixelmatorProLineShapeLayer {}

// MARK: PixelmatorProTextLayer
@objc public protocol PixelmatorProTextLayer: PixelmatorProLayer {
    @objc optional var textContent: PixelmatorProRichText { get } // The text of the text layer.
    @objc optional var horizontalAlignment: PixelmatorProTAHT { get } // The horizontal alignment of text content in the text layer.
    @objc optional var verticalAlignment: PixelmatorProTAVT { get } // The vertical alignment of text content in the text layer.
    @objc optional func convertIntoShape() // Convert a text layer into a shape.
}
extension SBObject: PixelmatorProTextLayer {}

// MARK: PixelmatorProVideoLayer
@objc public protocol PixelmatorProVideoLayer: PixelmatorProLayer {
}
extension SBObject: PixelmatorProVideoLayer {}

// MARK: PixelmatorProColorAdjustments
@objc public protocol PixelmatorProColorAdjustments: SBObjectProtocol, PixelmatorProGenericMethods {
    @objc optional var temperature: Int { get } // Add a blue (from -1 to -200) or yellow (from 1 to 200) tint to a layer to adjust its white balance.
    @objc optional var tint: Int { get } // Add a green (from -1 to -200) or magenta (from 1 to 200) tint to a layer to adjust its white balance.
    @objc optional var hue: Int { get } // Shift the hues of every color in a layer along the color spectrum. Supported values are from -100 to 100.
    @objc optional var saturation: Int { get } // Adjust the saturation of a layer. Supported values are from -100 to 100.
    @objc optional var vibrance: Int { get } // Adjust the vibrance of a layer. Supported values are from -200 to 200.
    @objc optional var exposure: Int { get } // Adjust the exposure of a layer. Supported values are from -400 to 400.
    @objc optional var highlights: Int { get } // Adjust the highlights of a layer. Supported values are from -100 to 100.
    @objc optional var shadows: Int { get } // Adjust the shadows of a layer. Supported values are from -100 to 100.
    @objc optional var brightness: Int { get } // Adjust the brightness of a layer. Supported values are from -200 to 200.
    @objc optional var contrast: Int { get } // Adjust the contrast of a layer. Supported values are from -200 to 200.
    @objc optional var blackPoint: Int { get } // Adjust the highlights of a layer. Supported values are from -200 to 200.
    @objc optional var texture: Int { get } // Adjust the texture of a layer. Supported values are from -100 to 100.
    @objc optional var clarity: Int { get } // Adjust the clarity of a layer. Supported values are from -100 to 100.
    @objc optional var blackAndWhite: Bool { get } // Turn the colors of a layer to black and white.
    @objc optional var sepia: Bool { get } // Convert the colors of a layer to shades of sepia.
    @objc optional var invert: Bool { get } // Invert the colors of a layer.
    @objc optional var fade: Int { get } // Fade the shadows of a layer. Supported values are from 0 to 200.
    @objc optional var vignette: Bool { get } // Apply a vignette to a layer.
    @objc optional var vignetteExposure: Int { get } // Adjust the exposure of the vignette. Supported values are from -200 to 200.
    @objc optional var vignetteBlackPoint: Int { get } // Adjust the black point of the vignette. Supported values are from -200 to 200.
    @objc optional var vignetteSoftness: Int { get } // Adjust the softness of the vignette. Supported values are from 0 to 100.
    @objc optional var grain: Int { get } // Add film grain to a layer and adjust its intensity. Supported values are from 0 to 100.
    @objc optional var grainSize: Int { get } // Adjust the size of grain particles. Supported values are from 0 to 400.
    @objc optional var sharpen: Int { get } // Sharpen a layer. Supported values are from 0 to 100.
    @objc optional var sharpenRadius: Double { get } // Adjust the radius of the sharpening effect. Supported values are from 0 to 100.
    @objc optional var customLut: Any { get } // Apply a 3D LUT to a layer. The value of this property must be set to a LUT file in a supported format.
    @objc optional func flatten() // Flatten the color adjustments of a layer.
    @objc optional func reset() // Reset the color adjustments of a layer.
    @objc optional func exportAsLutTo(_ to: URL!) // Export the color adjustments of a layer to a 3D LUT file.
}
extension SBObject: PixelmatorProColorAdjustments {}

// MARK: PixelmatorProStyles
@objc public protocol PixelmatorProStyles: SBObjectProtocol, PixelmatorProGenericMethods {
    @objc optional var fillColor: NSColor { get } // The color of the layer fill. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
    @objc optional var fillOpacity: Int { get } // The opacity of the layer fill. Supported values are from 0 to 100.
    @objc optional var fillBlendMode: PixelmatorProBlendMode { get } // The blend mode of the color fill.
    @objc optional var strokeWidth: Double { get } // The width of the stroke around a layer. Supported values are from 0 to 200.
    @objc optional var strokePosition: PixelmatorProStrokePosition { get } // The position of the stroke.
    @objc optional var strokeColor: NSColor { get } // The color fo the stroke. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
    @objc optional var strokeOpacity: Int { get } // The opacity of the layer stroke. Supported values are from 0 to 100.
    @objc optional var shadowBlur: Double { get } // The strength of the blur of the shadow layer style, in pixels from 0 to 100.
    @objc optional var shadowDistance: Double { get } // The distance of the shadow from the layer, in pixels from 0 to 400.
    @objc optional var shadowAngle: Double { get } // The angle of the shadow, in degrees from 0 to 359.
    @objc optional var shadowColor: NSColor { get } // The color of the shadow. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
    @objc optional var shadowOpacity: Int { get } // The opacity of the shadow. Supported values are from 0 to 100.
    @objc optional var innerShadowBlur: Double { get } // The strength of the blur of the inner shadow layer style, in pixels from 0 to 100.
    @objc optional var innerShadowDistance: Double { get } // The distance of the inner shadow from the layer, in pixels from 0 to 400.
    @objc optional var innerShadowAngle: Double { get } // The angle of the inner shadow, in degrees from 0 to 359.
    @objc optional var innerShadowColor: NSColor { get } // The color of the inner shadow. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
    @objc optional var innerShadowOpacity: Int { get } // The opacity of the inner shadow. Supported values are from 0 to 100.
    @objc optional var innerShadowBlendMode: PixelmatorProBlendMode { get } // The blend mode of the inner shadow.
    @objc optional func flatten() // Flatten the styles of a layer.
    @objc optional func reset() // Reset the styles of a layer.
}
extension SBObject: PixelmatorProStyles {}

// MARK: PixelmatorProDocumentInfo
@objc public protocol PixelmatorProDocumentInfo: SBObjectProtocol, PixelmatorProGenericMethods {
    @objc optional var properties: [AnyHashable : Any] { get } // All of this object's properties returned in a single record.
    @objc optional var author: String { get }
    @objc optional var authorPosition: String { get }
    @objc optional var caption: String { get }
    @objc optional var captionWriter: String { get }
    @objc optional var category: String { get }
    @objc optional var city: String { get }
    @objc optional var copyrightNotice: String { get }
    @objc optional var copyrighted: PixelmatorProDiCp { get }
    @objc optional var country: String { get }
    @objc optional var creationDate: String { get }
    @objc optional var credit: String { get }
    @objc optional var headline: String { get }
    @objc optional var instructions: String { get }
    @objc optional var jobName: String { get }
    @objc optional var keywords: [Any] { get } // list of keywords
    @objc optional var ownerUrl: String { get }
    @objc optional var provinceOrState: String { get }
    @objc optional var source: String { get }
    @objc optional var supplementalCategories: [Any] { get }
    @objc optional var title: String { get }
    @objc optional var transmissionReference: String { get }
    @objc optional var urgency: PixelmatorProDiUr { get }
    @objc optional var location: Any { get } // The GPS latitude and longitude, in an ordered list of 2 numbers or missing values.  Latitude in range -90.0 to 90.0, longitude in range -180.0 to 180.0.
    @objc optional var altitude: Double { get } // The GPS altitude in meters.
}
extension SBObject: PixelmatorProDocumentInfo {}

// MARK: PixelmatorProEffect
@objc public protocol PixelmatorProEffect: SBObjectProtocol, PixelmatorProGenericMethods {
    @objc optional var properties: [AnyHashable : Any] { get } // All of this object's properties returned in a single record.
    @objc optional var index: Int { get } // The index of this instance of the object.
    @objc optional var name: String { get } // The name of the effect.
    @objc optional var enabled: Bool { get } // Whether or not the effect is currently turned on.
    @objc optional func id() -> String // The unique identifier of the effect.
}
extension SBObject: PixelmatorProEffect {}

// MARK: PixelmatorProGaussianEffect
@objc public protocol PixelmatorProGaussianEffect: PixelmatorProEffect {
    @objc optional var radius: Double { get } // How many pixels are used to create the blur. The larger the number, the blurrier the result.
}
extension SBObject: PixelmatorProGaussianEffect {}

// MARK: PixelmatorProBoxEffect
@objc public protocol PixelmatorProBoxEffect: PixelmatorProEffect {
    @objc optional var radius: Double { get } // How many pixels are used to create the blur. The larger the number, the blurrier the result.
}
extension SBObject: PixelmatorProBoxEffect {}

// MARK: PixelmatorProDiscEffect
@objc public protocol PixelmatorProDiscEffect: PixelmatorProEffect {
    @objc optional var radius: Double { get } // How many pixels are used to create the blur. The larger the number, the blurrier the result.
}
extension SBObject: PixelmatorProDiscEffect {}

// MARK: PixelmatorProMotionEffect
@objc public protocol PixelmatorProMotionEffect: PixelmatorProEffect {
    @objc optional var radius: Double { get } // How many pixels are used to create the blur. The larger the number, the blurrier the result.
    @objc optional var angle: Double { get } // The angle of the motion blur.
}
extension SBObject: PixelmatorProMotionEffect {}

// MARK: PixelmatorProZoomEffect
@objc public protocol PixelmatorProZoomEffect: PixelmatorProEffect {
    @objc optional var position: NSPoint { get } // The position of the zoom blur effect.
    @objc optional var amount: Double { get } // The intensity of the zoom blur effect.
}
extension SBObject: PixelmatorProZoomEffect {}

// MARK: PixelmatorProSpinEffect
@objc public protocol PixelmatorProSpinEffect: PixelmatorProEffect {
    @objc optional var position: NSPoint { get } // The position of the spin blur effect.
    @objc optional var amount: Int { get } // The intensity of the spin blur effect.
}
extension SBObject: PixelmatorProSpinEffect {}

// MARK: PixelmatorProTiltShiftEffect
@objc public protocol PixelmatorProTiltShiftEffect: PixelmatorProEffect {
    @objc optional var blur: Double { get } // The intensity of the tilt shift blur effect.
    @objc optional var transition: Int { get } // The size of the transition between blurred and unblurred areas.
}
extension SBObject: PixelmatorProTiltShiftEffect {}

// MARK: PixelmatorProFocusEffect
@objc public protocol PixelmatorProFocusEffect: PixelmatorProEffect {
    @objc optional var blur: Double { get } // The intensity of the focus blur effect.
    @objc optional var transition: Int { get } // The size of the transition between blurred and unblurred areas.
}
extension SBObject: PixelmatorProFocusEffect {}

// MARK: PixelmatorProBumpEffect
@objc public protocol PixelmatorProBumpEffect: PixelmatorProEffect {
    @objc optional var position: NSPoint { get } // The position of the bump effect.
    @objc optional var radius: Int { get } // The size of the area affected by the bump effect.
    @objc optional var scale: Int { get } // The intensity of the bump effect.
}
extension SBObject: PixelmatorProBumpEffect {}

// MARK: PixelmatorProPinchEffect
@objc public protocol PixelmatorProPinchEffect: PixelmatorProEffect {
    @objc optional var position: NSPoint { get } // The position of the pinch effect.
    @objc optional var radius: Int { get } // The size of the area affected by the pinch effect.
    @objc optional var scale: Int { get } // The intensity of the pinch effect.
}
extension SBObject: PixelmatorProPinchEffect {}

// MARK: PixelmatorProCircleSplashEffect
@objc public protocol PixelmatorProCircleSplashEffect: PixelmatorProEffect {
    @objc optional var position: NSPoint { get } // The position of the circle splash effect.
    @objc optional var radius: Int { get } // The radius of the splash's center circle.
}
extension SBObject: PixelmatorProCircleSplashEffect {}

// MARK: PixelmatorProHoleEffect
@objc public protocol PixelmatorProHoleEffect: PixelmatorProEffect {
    @objc optional var position: NSPoint { get } // The position of the hole effect.
    @objc optional var radius: Int { get } // The radius of the hole.
}
extension SBObject: PixelmatorProHoleEffect {}

// MARK: PixelmatorProLightTunnelEffect
@objc public protocol PixelmatorProLightTunnelEffect: PixelmatorProEffect {
    @objc optional var position: NSPoint { get } // The position of the light tunnel effect.
    @objc optional var radius: Int { get } // The radius of the light tunnel effect.
    @objc optional var rotation: Double { get } // The rotation of the light tunnel effec.
}
extension SBObject: PixelmatorProLightTunnelEffect {}

// MARK: PixelmatorProTwirlEffect
@objc public protocol PixelmatorProTwirlEffect: PixelmatorProEffect {
    @objc optional var position: NSPoint { get } // The position of the twirl effect.
    @objc optional var radius: Int { get } // The radius of the twirl effect.
    @objc optional var angle: Double { get } // The angle of the twirl effect.
}
extension SBObject: PixelmatorProTwirlEffect {}

// MARK: PixelmatorProVortexEffect
@objc public protocol PixelmatorProVortexEffect: PixelmatorProEffect {
    @objc optional var position: NSPoint { get } // The position of the vortex effect.
    @objc optional var radius: Int { get } // The radius of the vortex effect.
    @objc optional var angle: Double { get } // The angle of the vortex effect.
}
extension SBObject: PixelmatorProVortexEffect {}

// MARK: PixelmatorProPixelateEffect
@objc public protocol PixelmatorProPixelateEffect: PixelmatorProEffect {
    @objc optional var scale: Double { get } // The size of the pixels used to create the pixelation effect.
}
extension SBObject: PixelmatorProPixelateEffect {}

// MARK: PixelmatorProPointillizeEffect
@objc public protocol PixelmatorProPointillizeEffect: PixelmatorProEffect {
    @objc optional var radius: Double { get } // The size of the points used to create the pointillize effect.
}
extension SBObject: PixelmatorProPointillizeEffect {}

// MARK: PixelmatorProCrystallizeEffect
@objc public protocol PixelmatorProCrystallizeEffect: PixelmatorProEffect {
    @objc optional var radius: Double { get } // The size of the crystals used to create the crystallize effect.
}
extension SBObject: PixelmatorProCrystallizeEffect {}

// MARK: PixelmatorProCheckerboardEffect
@objc public protocol PixelmatorProCheckerboardEffect: PixelmatorProEffect {
    @objc optional var position: NSPoint { get } // The position of the center of the checkerboard effect.
    @objc optional var color1: [Any] { get } // The first color of the squares of the effect. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
    @objc optional var color2: [Any] { get } // The second color of the squares of the effect. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
    @objc optional var width: Double { get } // The size of the checkerboard's squares.
    @objc optional var sharpness: Int { get } // The sharpness of the edges of the squares.
    @objc optional var opacity: Int { get } // The opacity of the checkerboard effect.
}
extension SBObject: PixelmatorProCheckerboardEffect {}

// MARK: PixelmatorProStripesEffect
@objc public protocol PixelmatorProStripesEffect: PixelmatorProEffect {
    @objc optional var position: NSPoint { get } // The position of the center of the stripes effect.
    @objc optional var color1: [Any] { get } // The first color of the stripes of the effect. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
    @objc optional var color2: [Any] { get } // The first color of the stripes of the effect. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
    @objc optional var width: Double { get } // The width of the stripes.
    @objc optional var sharpness: Int { get } // The sharpness of the edges of the stripes.
    @objc optional var opacity: Int { get } // The opacity of the stripes effect.
}
extension SBObject: PixelmatorProStripesEffect {}

// MARK: PixelmatorProColorFillEffect
@objc public protocol PixelmatorProColorFillEffect: PixelmatorProEffect {
    @objc optional var fillColor: [Any] { get } // The color of the color fill effect. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
}
extension SBObject: PixelmatorProColorFillEffect {}

// MARK: PixelmatorProImageFillEffect
@objc public protocol PixelmatorProImageFillEffect: PixelmatorProEffect {
    @objc optional var image: URL { get } // The image used for the image fill effect.
    @objc optional var position: NSPoint { get } // The position of the center of the image fill effect.
    @objc optional var scale: Int { get } // The scale of the image used for the fill effect.
    @objc optional var angle: Double { get } // The angle of the image used for the fill effect.
    @objc optional var opacity: Int { get } // The opacity of the image fill effect.
    @objc optional var blendMode: PixelmatorProBlendMode { get } // The blend mode of the image fill effect.
}
extension SBObject: PixelmatorProImageFillEffect {}

// MARK: PixelmatorProPatternFillEffect
@objc public protocol PixelmatorProPatternFillEffect: PixelmatorProEffect {
    @objc optional var image: URL { get } // The image tiled to create the pattern.
    @objc optional var position: NSPoint { get } // The position of the center of the effect.
    @objc optional var scale: Int { get } // The scale of the image used to create the pattern.
    @objc optional var angle: Double { get } // The angle of the image image used to create the pattern.
    @objc optional var opacity: Int { get } // The opacity of the pattern fill effect.
    @objc optional var blendMode: PixelmatorProBlendMode { get } // The blend mode of the pattern fill effect.
}
extension SBObject: PixelmatorProPatternFillEffect {}

// MARK: PixelmatorProRichText
@objc public protocol PixelmatorProRichText: SBObjectProtocol, PixelmatorProGenericMethods {
    @objc optional var color: NSColor { get } // The color of the font. Expressed as an RGB value consisting of a list of three color values from 0 to 65535. ex: Blue = {0, 0, 65535}.
    @objc optional var font: String { get } // The name of the font.  Can be the PostScript name, such as: “TimesNewRomanPS-ItalicMT”, or display name: “Times New Roman Italic”. TIP: Use the Font Book application get the information about a typeface.
    @objc optional var size: Int { get } // The size of the font.
    @objc optional func characters() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: PixelmatorProRichText {}

// MARK: PixelmatorProCharacter
@objc public protocol PixelmatorProCharacter: PixelmatorProRichText {
}
extension SBObject: PixelmatorProCharacter {}

// MARK: PixelmatorProParagraph
@objc public protocol PixelmatorProParagraph: PixelmatorProRichText {
    @objc optional func characters() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: PixelmatorProParagraph {}

// MARK: PixelmatorProWord
@objc public protocol PixelmatorProWord: PixelmatorProRichText {
    @objc optional func characters() -> SBElementArray
}
extension SBObject: PixelmatorProWord {}

