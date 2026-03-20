@_exported import ScriptingBridgeCommon

// MARK: PhotosApplication
@objc public protocol PhotosApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional var selection: [Any] { get } // The currently selected media items in the application
    @objc optional var favoritesAlbum: PhotosAlbum { get } // Favorited media items album.
    @objc optional var slideshowRunning: Bool { get } // Returns true if a slideshow is currently running.
    @objc optional var recentlyDeletedAlbum: PhotosAlbum { get } // The set of recently deleted media items
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func `open`(_ x: URL!) // Open a photo library
    @objc optional func quit() // Quit the application.
    @objc optional func `import`(_ x: [Any]!, into: PhotosAlbum!, skipCheckDuplicates: Bool) -> [Any] // Import files into the library
    @objc optional func export(_ x: [Any]!, to: URL!, usingOriginals: Bool) // Export media items to the specified location as files
    @objc optional func add(_ x: [Any]!, to: PhotosAlbum!) // Add media items to an album.
    @objc optional func startSlideshowUsing(_ using: [Any]!) // Display an ad-hoc slide show from a list of media items, an album, or a folder.
    @objc optional func stopSlideshow() // End the currently-playing slideshow.
    @objc optional func nextSlide() // Skip to next slide in currently-playing slideshow.
    @objc optional func previousSlide() // Skip to previous slide in currently-playing slideshow.
    @objc optional func pauseSlideshow() // Pause the currently-playing slideshow.
    @objc optional func resumeSlideshow() // Resume the currently-playing slideshow.
    @objc optional func spotlight(_ x: Any!) // Show the image at path in the application, used to show spotlight search results
    @objc optional func searchFor(_ `for`: String!) -> [Any] // search for items matching the search string. Identical to entering search text in the Search field in Photos
    @objc optional func containers() -> SBElementArray
    @objc optional func albums() -> SBElementArray
    @objc optional func folders() -> SBElementArray
    @objc optional func mediaItems() -> SBElementArray
}
extension SBApplication: PhotosApplication {}

// MARK: PhotosMediaItem
@objc public protocol PhotosMediaItem: SBObjectProtocol {
    @objc optional var keywords: [Any] { get } // A list of keywords to associate with a media item
    @objc optional var name: String { get } // The name (title) of the media item.
    @objc optional var objectDescription: String { get } // A description of the media item.
    @objc optional var favorite: Bool { get } // Whether the media item has been favorited.
    @objc optional var date: Date { get } // The date of the media item
    @objc optional var height: Int { get } // The height of the media item in pixels.
    @objc optional var width: Int { get } // The width of the media item in pixels.
    @objc optional var filename: String { get } // The name of the file on disk.
    @objc optional var altitude: Double { get } // The GPS altitude in meters.
    @objc optional var size: Int { get } // The selected media item file size.
    @objc optional var location: Any { get } // The GPS latitude and longitude, in an ordered list of 2 numbers or missing values.  Latitude in range -90.0 to 90.0, longitude in range -180.0 to 180.0.
    @objc optional func id() -> String // The unique ID of the media item
    @objc optional func duplicate() -> PhotosMediaItem // Duplicate an object.  Only media items can be duplicated
    @objc optional func spotlight() // Show the image at path in the application, used to show spotlight search results
}
extension SBObject: PhotosMediaItem {}

// MARK: PhotosContainer
@objc public protocol PhotosContainer: SBObjectProtocol {
    @objc optional var name: String { get } // The name of this container.
    @objc optional var parent: PhotosFolder { get } // This container's parent folder, if any.
    @objc optional func id() -> String // The unique ID of this container.
    @objc optional func spotlight() // Show the image at path in the application, used to show spotlight search results
}
extension SBObject: PhotosContainer {}

// MARK: PhotosAlbum
@objc public protocol PhotosAlbum: PhotosContainer {
    @objc optional func mediaItems() -> SBElementArray
    @objc optional func delete() // Delete an object.  Only albums and folders can be deleted.
}
extension SBObject: PhotosAlbum {}

// MARK: PhotosFolder
@objc public protocol PhotosFolder: PhotosContainer {
    @objc optional func containers() -> SBElementArray
    @objc optional func albums() -> SBElementArray
    @objc optional func folders() -> SBElementArray
    @objc optional func delete() // Delete an object.  Only albums and folders can be deleted.
}
extension SBObject: PhotosFolder {}

