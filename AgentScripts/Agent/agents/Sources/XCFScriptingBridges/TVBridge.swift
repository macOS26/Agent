@_exported import ScriptingBridgeCommon

// MARK: TVEPlS
@objc public enum TVEPlS : AEKeyword {
    case stopped = 0x6b505353
    case playing = 0x6b505350
    case paused = 0x6b505370
    case fastForwarding = 0x6b505346
    case rewinding = 0x6b505352
}

// MARK: TVESrc
@objc public enum TVESrc : AEKeyword {
    case library = 0x6b4c6962
    case sharedLibrary = 0x6b536864
    case iTunesStore = 0x6b495453
    case unknown = 0x6b556e6b
}

// MARK: TVESrA
@objc public enum TVESrA : AEKeyword {
    case albums = 0x6b53724c /* albums only */
    case all = 0x6b416c6c /* all text fields */
    case artists = 0x6b537252 /* artists only */
    case displayed = 0x6b537256 /* visible text fields */
    case names = 0x6b537253 /* track names only */
}

// MARK: TVESpK
@objc public enum TVESpK : AEKeyword {
    case none = 0x6b4e6f6e
    case folder = 0x6b537046
    case library = 0x6b53704c
    case movies = 0x6b537049
    case tvShows = 0x6b537054
}

// MARK: TVEMdK
@objc public enum TVEMdK : AEKeyword {
    case homeVideo = 0x6b566448 /* home video track */
    case movie = 0x6b56644d /* movie track */
    case tvShow = 0x6b566454 /* TV show track */
    case unknown = 0x6b556e6b
}

// MARK: TVERtK
@objc public enum TVERtK : AEKeyword {
    case user = 0x6b527455 /* user-specified rating */
    case computed = 0x6b527443 /* computed rating */
}

// MARK: TVGenericMethods
@objc public protocol TVGenericMethods {
    @objc optional func close() // Close an object
    @objc optional func delete() // Delete an element from an object
    @objc optional func duplicateTo(_ to: SBObject!) -> SBObject // Duplicate one or more object(s)
    @objc optional func exists() -> Bool // Verify if an object exists
    @objc optional func `open`() // Open the specified object(s)
    @objc optional func save() // Save the specified object(s)
    @objc optional func playOnce(_ once: Bool) // play the current track or the specified track or file.
    @objc optional func select() // select the specified object(s)
}

// MARK: TVApplication
@objc public protocol TVApplication: SBApplicationProtocol {
    @objc optional var currentPlaylist: TVPlaylist { get } // the playlist containing the currently targeted track
    @objc optional var currentStreamTitle: String { get } // the name of the current track in the playing stream (provided by streaming server)
    @objc optional var currentStreamURL: String { get } // the URL of the playing stream or streaming web site (provided by streaming server)
    @objc optional var currentTrack: TVTrack { get } // the current targeted track
    @objc optional var fixedIndexing: Bool { get } // true if all AppleScript track indices should be independent of the play order of the owning playlist.
    @objc optional var frontmost: Bool { get } // is this the active application?
    @objc optional var fullScreen: Bool { get } // is the application using the entire screen?
    @objc optional var name: String { get } // the name of the application
    @objc optional var mute: Bool { get } // has the sound output been muted?
    @objc optional var playerPosition: Double { get } // the player’s position within the currently playing track in seconds.
    @objc optional var playerState: TVEPlS { get } // is the player stopped, paused, or playing?
    @objc optional var selection: SBObject { get } // the selection visible to the user
    @objc optional var soundVolume: Int { get } // the sound output volume (0 = minimum, 100 = maximum)
    @objc optional var version: String { get } // the version of the application
    @objc optional func browserWindows() -> SBElementArray
    @objc optional func playlists() -> SBElementArray
    @objc optional func playlistWindows() -> SBElementArray
    @objc optional func sources() -> SBElementArray
    @objc optional func tracks() -> SBElementArray
    @objc optional func videoWindows() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func run() // Run the application
    @objc optional func quit() // Quit the application
    @objc optional func add(_ x: [Any]!, to: SBObject!) -> TVTrack // add one or more files to a playlist
    @objc optional func backTrack() // reposition to beginning of current track or go to previous track if already at start of current track
    @objc optional func convert(_ x: [Any]!) -> TVTrack // convert one or more files or tracks
    @objc optional func fastForward() // skip forward in a playing track
    @objc optional func nextTrack() // advance to the next track in the current playlist
    @objc optional func pause() // pause playback
    @objc optional func playOnce(_ once: Bool) // play the current track or the specified track or file.
    @objc optional func playpause() // toggle the playing/paused state of the current track
    @objc optional func previousTrack() // return to the previous track in the current playlist
    @objc optional func resume() // disable fast forward/rewind and resume playback, if playing.
    @objc optional func rewind() // skip backwards in a playing track
    @objc optional func stop() // stop playback
    @objc optional func openLocation(_ x: String!) // Opens an iTunes Store or stream URL
}
extension SBApplication: TVApplication {}

// MARK: TVItem
@objc public protocol TVItem: SBObjectProtocol, TVGenericMethods {
    @objc optional var container: SBObject { get } // the container of the item
    @objc optional var index: Int { get } // the index of the item in internal application order
    @objc optional var name: String { get } // the name of the item
    @objc optional var persistentID: String { get } // the id of the item as a hexadecimal string. This id does not change over time.
    @objc optional var properties: [AnyHashable : Any] { get } // every property of the item
    @objc optional func id() -> Int // the id of the item
    @objc optional func download() // download a cloud track or playlist
    @objc optional func reveal() // reveal and select a track or playlist
}
extension SBObject: TVItem {}

// MARK: TVArtwork
@objc public protocol TVArtwork: TVItem {
    @objc optional var data: NSImage { get } // data for this artwork, in the form of a picture
    @objc optional var objectDescription: String { get } // description of artwork as a string
    @objc optional var downloaded: Bool { get } // was this artwork downloaded by iTunes?
    @objc optional var format: NSNumber { get } // the data format for this piece of artwork
    @objc optional var kind: Int { get } // kind or purpose of this piece of artwork
    @objc optional var rawData: Any { get } // data for this artwork, in original format
}
extension SBObject: TVArtwork {}

// MARK: TVPlaylist
@objc public protocol TVPlaylist: TVItem {
    @objc optional var objectDescription: String { get } // the description of the playlist
    @objc optional var duration: Int { get } // the total length of all tracks (in seconds)
    @objc optional var name: String { get } // the name of the playlist
    @objc optional var parent: TVPlaylist { get } // folder which contains this playlist (if any)
    @objc optional var size: Int { get } // the total size of all tracks (in bytes)
    @objc optional var specialKind: TVESpK { get } // special playlist kind
    @objc optional var time: String { get } // the length of all tracks in MM:SS format
    @objc optional var visible: Bool { get } // is this playlist visible in the Source list?
    @objc optional func tracks() -> SBElementArray
    @objc optional func artworks() -> SBElementArray
    @objc optional func moveTo(_ to: SBObject!) // Move playlist(s) to a new location
    @objc optional func searchFor(_ `for`: String!, only: TVESrA) -> TVTrack // search a playlist for tracks matching the search string. Identical to entering search text in the Search field.
}
extension SBObject: TVPlaylist {}

// MARK: TVLibraryPlaylist
@objc public protocol TVLibraryPlaylist: TVPlaylist {
    @objc optional func fileTracks() -> SBElementArray
    @objc optional func URLTracks() -> SBElementArray
    @objc optional func sharedTracks() -> SBElementArray
}
extension SBObject: TVLibraryPlaylist {}

// MARK: TVSource
@objc public protocol TVSource: TVItem {
    @objc optional var capacity: Int64 { get } // the total size of the source if it has a fixed size
    @objc optional var freeSpace: Int64 { get } // the free space on the source if it has a fixed size
    @objc optional var kind: TVESrc { get }
    @objc optional func libraryPlaylists() -> SBElementArray
    @objc optional func playlists() -> SBElementArray
    @objc optional func userPlaylists() -> SBElementArray
}
extension SBObject: TVSource {}

// MARK: TVTrack
@objc public protocol TVTrack: TVItem {
    @objc optional var album: String { get } // the album name of the track
    @objc optional var albumRating: Int { get } // the rating of the album for this track (0 to 100)
    @objc optional var albumRatingKind: TVERtK { get } // the rating kind of the album rating for this track
    @objc optional var bitRate: Int { get } // the bit rate of the track (in kbps)
    @objc optional var bookmark: Double { get } // the bookmark time of the track in seconds
    @objc optional var bookmarkable: Bool { get } // is the playback position for this track remembered?
    @objc optional var category: String { get } // the category of the track
    @objc optional var comment: String { get } // freeform notes about the track
    @objc optional var databaseID: Int { get } // the common, unique ID for this track. If two tracks in different playlists have the same database ID, they are sharing the same data.
    @objc optional var dateAdded: Date { get } // the date the track was added to the playlist
    @objc optional var objectDescription: String { get } // the description of the track
    @objc optional var director: String { get } // the artist/source of the track
    @objc optional var discCount: Int { get } // the total number of discs in the source album
    @objc optional var discNumber: Int { get } // the index of the disc containing this track on the source album
    @objc optional var downloaderAccount: String { get } // the account of the person who downloaded this track
    @objc optional var downloaderName: String { get } // the name of the person who downloaded this track
    @objc optional var duration: Double { get } // the length of the track in seconds
    @objc optional var enabled: Bool { get } // is this track checked for playback?
    @objc optional var episodeID: String { get } // the episode ID of the track
    @objc optional var episodeNumber: Int { get } // the episode number of the track
    @objc optional var finish: Double { get } // the stop time of the track in seconds
    @objc optional var genre: String { get } // the genre (category) of the track
    @objc optional var grouping: String { get } // the grouping (piece) of the track. Generally used to denote movements within a classical work.
    @objc optional var kind: String { get } // a text description of the track
    @objc optional var longDescription: String { get } // the long description of the track
    @objc optional var mediaKind: TVEMdK { get } // the media kind of the track
    @objc optional var modificationDate: Date { get } // the modification date of the content of this track
    @objc optional var playedCount: Int { get } // number of times this track has been played
    @objc optional var playedDate: Date { get } // the date and time this track was last played
    @objc optional var purchaserAccount: String { get } // the account of the person who purchased this track
    @objc optional var purchaserName: String { get } // the name of the person who purchased this track
    @objc optional var rating: Int { get } // the rating of this track (0 to 100)
    @objc optional var ratingKind: TVERtK { get } // the rating kind of this track
    @objc optional var releaseDate: Date { get } // the release date of this track
    @objc optional var sampleRate: Int { get } // the sample rate of the track (in Hz)
    @objc optional var seasonNumber: Int { get } // the season number of the track
    @objc optional var skippedCount: Int { get } // number of times this track has been skipped
    @objc optional var skippedDate: Date { get } // the date and time this track was last skipped
    @objc optional var show: String { get } // the show name of the track
    @objc optional var sortAlbum: String { get } // override string to use for the track when sorting by album
    @objc optional var sortDirector: String { get } // override string to use for the track when sorting by artist
    @objc optional var sortName: String { get } // override string to use for the track when sorting by name
    @objc optional var sortShow: String { get } // override string to use for the track when sorting by show name
    @objc optional var size: Int64 { get } // the size of the track (in bytes)
    @objc optional var start: Double { get } // the start time of the track in seconds
    @objc optional var time: String { get } // the length of the track in MM:SS format
    @objc optional var trackCount: Int { get } // the total number of tracks on the source album
    @objc optional var trackNumber: Int { get } // the index of the track on the source album
    @objc optional var unplayed: Bool { get } // is this track unplayed?
    @objc optional var volumeAdjustment: Int { get } // relative volume adjustment of the track (-100% to 100%)
    @objc optional var year: Int { get } // the year the track was recorded/released
    @objc optional func artworks() -> SBElementArray
}
extension SBObject: TVTrack {}

// MARK: TVFileTrack
@objc public protocol TVFileTrack: TVTrack {
    @objc optional var location: URL { get } // the location of the file represented by this track
    @objc optional func refresh() // update file track information from the current information in the track’s file
}
extension SBObject: TVFileTrack {}

// MARK: TVSharedTrack
@objc public protocol TVSharedTrack: TVTrack {
}
extension SBObject: TVSharedTrack {}

// MARK: TVURLTrack
@objc public protocol TVURLTrack: TVTrack {
    @objc optional var address: String { get } // the URL for this track
}
extension SBObject: TVURLTrack {}

// MARK: TVUserPlaylist
@objc public protocol TVUserPlaylist: TVPlaylist {
    @objc optional var shared: Bool { get } // is this playlist shared?
    @objc optional var smart: Bool { get } // is this a Smart Playlist?
    @objc optional func fileTracks() -> SBElementArray
    @objc optional func URLTracks() -> SBElementArray
    @objc optional func sharedTracks() -> SBElementArray
}
extension SBObject: TVUserPlaylist {}

// MARK: TVFolderPlaylist
@objc public protocol TVFolderPlaylist: TVUserPlaylist {
}
extension SBObject: TVFolderPlaylist {}

// MARK: TVWindow
@objc public protocol TVWindow: TVItem {
    @objc optional var bounds: NSRect { get } // the boundary rectangle for the window
    @objc optional var closeable: Bool { get } // does the window have a close button?
    @objc optional var collapseable: Bool { get } // does the window have a collapse button?
    @objc optional var collapsed: Bool { get } // is the window collapsed?
    @objc optional var fullScreen: Bool { get } // is the window full screen?
    @objc optional var position: NSPoint { get } // the upper left position of the window
    @objc optional var resizable: Bool { get } // is the window resizable?
    @objc optional var visible: Bool { get } // is the window visible?
    @objc optional var zoomable: Bool { get } // is the window zoomable?
    @objc optional var zoomed: Bool { get } // is the window zoomed?
}
extension SBObject: TVWindow {}

// MARK: TVBrowserWindow
@objc public protocol TVBrowserWindow: TVWindow {
    @objc optional var selection: SBObject { get } // the selected tracks
    @objc optional var view: TVPlaylist { get } // the playlist currently displayed in the window
}
extension SBObject: TVBrowserWindow {}

// MARK: TVPlaylistWindow
@objc public protocol TVPlaylistWindow: TVWindow {
    @objc optional var selection: SBObject { get } // the selected tracks
    @objc optional var view: TVPlaylist { get } // the playlist displayed in the window
}
extension SBObject: TVPlaylistWindow {}

// MARK: TVVideoWindow
@objc public protocol TVVideoWindow: TVWindow {
}
extension SBObject: TVVideoWindow {}

