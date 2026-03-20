
// MARK: QuickTimePlayerSaveOptions
@objc public enum QuickTimePlayerSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: QuickTimePlayerPrintingErrorHandling
@objc public enum QuickTimePlayerPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: QuickTimePlayerGenericMethods
@objc public protocol QuickTimePlayerGenericMethods {
    @objc optional func closeSaving(_ saving: QuickTimePlayerSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ `in`: URL!, `as`: Any!) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: QuickTimePlayerApplication
@objc public protocol QuickTimePlayerApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: QuickTimePlayerSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func openURL(_ x: String!) // Open a URL.
    @objc optional func newMovieRecording() -> QuickTimePlayerDocument // Create a new movie recording document.
    @objc optional func newAudioRecording() -> QuickTimePlayerDocument // Create a new audio recording document.
    @objc optional func newScreenRecording() // Create a new screen recording document.
    @objc optional func videoRecordingDevices() -> SBElementArray
    @objc optional func audioRecordingDevices() -> SBElementArray
    @objc optional func audioCompressionPresets() -> SBElementArray
    @objc optional func movieCompressionPresets() -> SBElementArray
    @objc optional func screenCompressionPresets() -> SBElementArray
}
extension SBApplication: QuickTimePlayerApplication {}

// MARK: QuickTimePlayerDocument
@objc public protocol QuickTimePlayerDocument: SBObjectProtocol, QuickTimePlayerGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
    @objc optional var audioVolume: Double { get } // The volume of the movie from 0 to 1, where 1 is 100%.
    @objc optional var currentTime: Double { get } // The current time of the movie in seconds.
    @objc optional var dataRate: Int { get } // The data rate of the movie in bytes per second.
    @objc optional var dataSize: Int { get } // The data size of the movie in bytes.
    @objc optional var duration: Double { get } // The duration of the movie in seconds.
    @objc optional var looping: Bool { get } // Is the movie playing in a loop?
    @objc optional var muted: Bool { get } // Is the movie muted?
    @objc optional var naturalDimensions: NSPoint { get } // The natural dimensions of the movie.
    @objc optional var playing: Bool { get } // Is the movie playing?
    @objc optional var rate: Double { get } // The current rate of the movie.
    @objc optional var presenting: Bool { get } // Is the movie presented in full screen?
    @objc optional var currentMicrophone: QuickTimePlayerAudioRecordingDevice { get } // The currently previewing audio device.
    @objc optional var currentCamera: QuickTimePlayerVideoRecordingDevice { get } // The currently previewing video device.
    @objc optional var currentAudioCompression: QuickTimePlayerAudioCompressionPreset { get } // The current audio compression preset.
    @objc optional var currentMovieCompression: QuickTimePlayerMovieCompressionPreset { get } // The current movie compression preset.
    @objc optional var currentScreenCompression: QuickTimePlayerScreenCompressionPreset { get } // The current screen compression preset.
    @objc optional func play() // Play the movie.
    @objc optional func start() // Start the movie recording.
    @objc optional func pause() // Pause the recording.
    @objc optional func resume() // Resume the recording.
    @objc optional func stop() // Stop the movie or recording.
    @objc optional func stepBackwardBy(_ by: Int) // Step the movie backward the specified number of steps (default is 1).
    @objc optional func stepForwardBy(_ by: Int) // Step the movie forward the specified number of steps (default is 1).
    @objc optional func trimFrom(_ from: Double, to: Double) // Trim the movie.
    @objc optional func present() // Present the document full screen.
    @objc optional func exportIn(_ `in`: URL!, usingSettingsPreset: String!) // Export a movie to another file
}
extension SBObject: QuickTimePlayerDocument {}

// MARK: QuickTimePlayerWindow
@objc public protocol QuickTimePlayerWindow: SBObjectProtocol, QuickTimePlayerGenericMethods {
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
    @objc optional var document: QuickTimePlayerDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: QuickTimePlayerWindow {}

// MARK: QuickTimePlayerVideoRecordingDevice
@objc public protocol QuickTimePlayerVideoRecordingDevice: SBObjectProtocol, QuickTimePlayerGenericMethods {
    @objc optional var name: String { get } // The name of the device.
    @objc optional func id() -> String // The unique identifier of the device.
}
extension SBObject: QuickTimePlayerVideoRecordingDevice {}

// MARK: QuickTimePlayerAudioRecordingDevice
@objc public protocol QuickTimePlayerAudioRecordingDevice: SBObjectProtocol, QuickTimePlayerGenericMethods {
    @objc optional var name: String { get } // The name of the device.
    @objc optional func id() -> String // The unique identifier of the device.
}
extension SBObject: QuickTimePlayerAudioRecordingDevice {}

// MARK: QuickTimePlayerAudioCompressionPreset
@objc public protocol QuickTimePlayerAudioCompressionPreset: SBObjectProtocol, QuickTimePlayerGenericMethods {
    @objc optional var name: String { get } // The name of the preset.
    @objc optional func id() -> String // The unique identifier of the preset.
}
extension SBObject: QuickTimePlayerAudioCompressionPreset {}

// MARK: QuickTimePlayerMovieCompressionPreset
@objc public protocol QuickTimePlayerMovieCompressionPreset: SBObjectProtocol, QuickTimePlayerGenericMethods {
    @objc optional var name: String { get } // The name of the preset.
    @objc optional func id() -> String // The unique identifier of the preset.
}
extension SBObject: QuickTimePlayerMovieCompressionPreset {}

// MARK: QuickTimePlayerScreenCompressionPreset
@objc public protocol QuickTimePlayerScreenCompressionPreset: SBObjectProtocol, QuickTimePlayerGenericMethods {
    @objc optional var name: String { get } // The name of the preset.
    @objc optional func id() -> String // The unique identifier of the preset.
}
extension SBObject: QuickTimePlayerScreenCompressionPreset {}

