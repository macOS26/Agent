
// MARK: MusicEKnd
@objc public enum MusicEKnd : AEKeyword {
    case trackListing = 0x6b54726b /* a basic listing of tracks within a playlist */
    case albumListing = 0x6b416c62 /* a listing of a playlist grouped by album */
    case cdInsert = 0x6b434469 /* a printout of the playlist for jewel case inserts */
}

// MARK: MusicEnum
@objc public enum MusicEnum : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: MusicEPlS
@objc public enum MusicEPlS : AEKeyword {
    case stopped = 0x6b505353
    case playing = 0x6b505350
    case paused = 0x6b505370
    case fastForwarding = 0x6b505346
    case rewinding = 0x6b505352
}

// MARK: MusicERpt
@objc public enum MusicERpt : AEKeyword {
    case off = 0x6b52704f
    case one = 0x6b527031
    case all = 0x6b416c6c
}

// MARK: MusicEShM
@objc public enum MusicEShM : AEKeyword {
    case songs = 0x6b536853
    case albums = 0x6b536841
    case groupings = 0x6b536847
}

// MARK: MusicESrc
@objc public enum MusicESrc : AEKeyword {
    case library = 0x6b4c6962
    case audioCD = 0x6b414344
    case mp3CD = 0x6b4d4344
    case radioTuner = 0x6b54756e
    case sharedLibrary = 0x6b536864
    case iTunesStore = 0x6b495453
    case unknown = 0x6b556e6b
}

// MARK: MusicESrA
@objc public enum MusicESrA : AEKeyword {
    case albums = 0x6b53724c /* albums only */
    case all = 0x6b416c6c /* all text fields */
    case artists = 0x6b537252 /* artists only */
    case composers = 0x6b537243 /* composers only */
    case displayed = 0x6b537256 /* visible text fields */
    case names = 0x6b537253 /* track names only */
}

// MARK: MusicESpK
@objc public enum MusicESpK : AEKeyword {
    case none = 0x6b4e6f6e
    case folder = 0x6b537046
    case genius = 0x6b537047
    case library = 0x6b53704c
    case music = 0x6b53705a
    case purchasedMusic = 0x6b53704d
}

// MARK: MusicEMdK
@objc public enum MusicEMdK : AEKeyword {
    case song = 0x6b4d6453 /* music track */
    case musicVideo = 0x6b566456 /* music video track */
    case movie = 0x6b56644d /* movie track */
    case tvShow = 0x6b566454 /* TV show track */
    case unknown = 0x6b556e6b
}

// MARK: MusicERtK
@objc public enum MusicERtK : AEKeyword {
    case user = 0x6b527455 /* user-specified rating */
    case computed = 0x6b527443 /* computed rating */
}

// MARK: MusicEAPD
@objc public enum MusicEAPD : AEKeyword {
    case computer = 0x6b415043
    case airPortExpress = 0x6b415058
    case appleTV = 0x6b415054
    case airPlayDevice = 0x6b41504f
    case bluetoothDevice = 0x6b415042
    case homePod = 0x6b415048
    case tv = 0x6b415056
    case unknown = 0x6b415055
}

// MARK: MusicEClS
@objc public enum MusicEClS : AEKeyword {
    case unknown = 0x6b556e6b
    case purchased = 0x6b507572
    case matched = 0x6b4d6174
    case uploaded = 0x6b55706c
    case ineligible = 0x6b52656a
    case removed = 0x6b52656d
    case error = 0x6b457272
    case duplicate = 0x6b447570
    case subscription = 0x6b537562
    case prerelease = 0x6b507252
    case noLongerAvailable = 0x6b526576
    case notUploaded = 0x6b557050
}

// MARK: MusicEExF
@objc public enum MusicEExF : AEKeyword {
    case plainText = 0x6b545854
    case unicodeText = 0x6b554354
    case xml = 0x6b584d4c
    case m3U = 0x6b4d3355
    case m3U8 = 0x6b4d3338
}

// MARK: MusicGenericMethods
@objc public protocol MusicGenericMethods {
    @objc optional func printPrintDialog(_ printDialog: Bool, withProperties: [AnyHashable : Any]!, kind: MusicEKnd, theme: String!) // Print the specified object(s)
    @objc optional func close() // Close an object
    @objc optional func delete() // Delete an element from an object
    @objc optional func duplicateTo(_ to: SBObject!) -> SBObject // Duplicate one or more object(s)
    @objc optional func exists() -> Bool // Verify if an object exists
    @objc optional func `open`() // Open the specified object(s)
    @objc optional func save() // Save the specified object(s)
    @objc optional func playOnce(_ once: Bool) // play the current track or the specified track or file.
    @objc optional func select() // select the specified object(s)
}

// MARK: MusicApplication
@objc public protocol MusicApplication: SBApplicationProtocol {
    @objc optional var AirPlayEnabled: Bool { get } // is AirPlay currently enabled?
    @objc optional var converting: Bool { get } // is a track currently being converted?
    @objc optional var currentAirPlayDevices: [Any] { get } // the currently selected AirPlay device(s)
    @objc optional var currentEncoder: MusicEncoder { get } // the currently selected encoder (MP3, AIFF, WAV, etc.)
    @objc optional var currentEQPreset: MusicEQPreset { get } // the currently selected equalizer preset
    @objc optional var currentPlaylist: MusicPlaylist { get } // the playlist containing the currently targeted track
    @objc optional var currentStreamTitle: String { get } // the name of the current track in the playing stream (provided by streaming server)
    @objc optional var currentStreamURL: String { get } // the URL of the playing stream or streaming web site (provided by streaming server)
    @objc optional var currentTrack: MusicTrack { get } // the current targeted track
    @objc optional var currentVisual: MusicVisual { get } // the currently selected visual plug-in
    @objc optional var EQEnabled: Bool { get } // is the equalizer enabled?
    @objc optional var fixedIndexing: Bool { get } // true if all AppleScript track indices should be independent of the play order of the owning playlist.
    @objc optional var frontmost: Bool { get } // is this the active application?
    @objc optional var fullScreen: Bool { get } // is the application using the entire screen?
    @objc optional var name: String { get } // the name of the application
    @objc optional var mute: Bool { get } // has the sound output been muted?
    @objc optional var playerPosition: Double { get } // the player’s position within the currently playing track in seconds.
    @objc optional var playerState: MusicEPlS { get } // is the player stopped, paused, or playing?
    @objc optional var selection: SBObject { get } // the selection visible to the user
    @objc optional var shuffleEnabled: Bool { get } // are songs played in random order?
    @objc optional var shuffleMode: MusicEShM { get } // the playback shuffle mode
    @objc optional var songRepeat: MusicERpt { get } // the playback repeat mode
    @objc optional var soundVolume: Int { get } // the sound output volume (0 = minimum, 100 = maximum)
    @objc optional var version: String { get } // the version of the application
    @objc optional var visualsEnabled: Bool { get } // are visuals currently being displayed?
    @objc optional func AirPlayDevices() -> SBElementArray
    @objc optional func browserWindows() -> SBElementArray
    @objc optional func encoders() -> SBElementArray
    @objc optional func EQPresets() -> SBElementArray
    @objc optional func EQWindows() -> SBElementArray
    @objc optional func miniplayerWindows() -> SBElementArray
    @objc optional func playlists() -> SBElementArray
    @objc optional func playlistWindows() -> SBElementArray
    @objc optional func sources() -> SBElementArray
    @objc optional func tracks() -> SBElementArray
    @objc optional func videoWindows() -> SBElementArray
    @objc optional func visuals() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func printPrintDialog(_ printDialog: Bool, withProperties: [AnyHashable : Any]!, kind: MusicEKnd, theme: String!) // Print the specified object(s)
    @objc optional func run() // Run the application
    @objc optional func quit() // Quit the application
    @objc optional func add(_ x: [Any]!, to: SBObject!) -> MusicTrack // add one or more files to a playlist
    @objc optional func backTrack() // reposition to beginning of current track or go to previous track if already at start of current track
    @objc optional func convert(_ x: [Any]!) -> MusicTrack // convert one or more files or tracks
    @objc optional func fastForward() // skip forward in a playing track
    @objc optional func nextTrack() // advance to the next track in the current playlist
    @objc optional func pause() // pause playback
    @objc optional func playOnce(_ once: Bool) // play the current track or the specified track or file.
    @objc optional func playpause() // toggle the playing/paused state of the current track
    @objc optional func previousTrack() // return to the previous track in the current playlist
    @objc optional func resume() // disable fast forward/rewind and resume playback, if playing.
    @objc optional func rewind() // skip backwards in a playing track
    @objc optional func stop() // stop playback
    @objc optional func openLocation(_ x: String!) // Opens an iTunes Store or audio stream URL
}
extension SBApplication: MusicApplication {}

// MARK: MusicItem
@objc public protocol MusicItem: SBObjectProtocol, MusicGenericMethods {
    @objc optional var container: SBObject { get } // the container of the item
    @objc optional var index: Int { get } // the index of the item in internal application order
    @objc optional var name: String { get } // the name of the item
    @objc optional var persistentID: String { get } // the id of the item as a hexadecimal string. This id does not change over time.
    @objc optional var properties: [AnyHashable : Any] { get } // every property of the item
    @objc optional func id() -> Int // the id of the item
    @objc optional func download() // download a cloud track or playlist
    @objc optional func exportAs(_ `as`: MusicEExF, to: URL!) -> String // export a source or playlist
    @objc optional func reveal() // reveal and select a track or playlist
}
extension SBObject: MusicItem {}

// MARK: MusicAirPlayDevice
@objc public protocol MusicAirPlayDevice: MusicItem {
    @objc optional var active: Bool { get } // is the device currently being played to?
    @objc optional var available: Bool { get } // is the device currently available?
    @objc optional var kind: MusicEAPD { get } // the kind of the device
    @objc optional var networkAddress: String { get } // the network (MAC) address of the device
    @objc optional var selected: Bool { get } // is the device currently selected?
    @objc optional var supportsAudio: Bool { get } // does the device support audio playback?
    @objc optional var supportsVideo: Bool { get } // does the device support video playback?
    @objc optional var soundVolume: Int { get } // the output volume for the device (0 = minimum, 100 = maximum)
    @objc optional func protected() -> Bool // is the device password- or passcode-protected?
}
extension SBObject: MusicAirPlayDevice {}

// MARK: MusicArtwork
@objc public protocol MusicArtwork: MusicItem {
    @objc optional var data: NSImage { get } // data for this artwork, in the form of a picture
    @objc optional var objectDescription: String { get } // description of artwork as a string
    @objc optional var downloaded: Bool { get } // was this artwork downloaded by Music?
    @objc optional var format: NSNumber { get } // the data format for this piece of artwork
    @objc optional var kind: Int { get } // kind or purpose of this piece of artwork
    @objc optional var rawData: Any { get } // data for this artwork, in original format
}
extension SBObject: MusicArtwork {}

// MARK: MusicEncoder
@objc public protocol MusicEncoder: MusicItem {
    @objc optional var format: String { get } // the data format created by the encoder
}
extension SBObject: MusicEncoder {}

// MARK: MusicEQPreset
@objc public protocol MusicEQPreset: MusicItem {
    @objc optional var band1: Double { get } // the equalizer 32 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional var band2: Double { get } // the equalizer 64 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional var band3: Double { get } // the equalizer 125 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional var band4: Double { get } // the equalizer 250 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional var band5: Double { get } // the equalizer 500 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional var band6: Double { get } // the equalizer 1 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional var band7: Double { get } // the equalizer 2 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional var band8: Double { get } // the equalizer 4 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional var band9: Double { get } // the equalizer 8 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional var band10: Double { get } // the equalizer 16 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional var modifiable: Bool { get } // can this preset be modified?
    @objc optional var preamp: Double { get } // the equalizer preamp level (-12.0 dB to +12.0 dB)
    @objc optional var updateTracks: Bool { get } // should tracks which refer to this preset be updated when the preset is renamed or deleted?
}
extension SBObject: MusicEQPreset {}

// MARK: MusicPlaylist
@objc public protocol MusicPlaylist: MusicItem {
    @objc optional var objectDescription: String { get } // the description of the playlist
    @objc optional var disliked: Bool { get } // is this playlist disliked?
    @objc optional var duration: Int { get } // the total length of all tracks (in seconds)
    @objc optional var name: String { get } // the name of the playlist
    @objc optional var favorited: Bool { get } // is this playlist favorited?
    @objc optional var parent: MusicPlaylist { get } // folder which contains this playlist (if any)
    @objc optional var size: Int { get } // the total size of all tracks (in bytes)
    @objc optional var specialKind: MusicESpK { get } // special playlist kind
    @objc optional var time: String { get } // the length of all tracks in MM:SS format
    @objc optional var visible: Bool { get } // is this playlist visible in the Source list?
    @objc optional func tracks() -> SBElementArray
    @objc optional func artworks() -> SBElementArray
    @objc optional func moveTo(_ to: SBObject!) // Move playlist(s) to a new location
    @objc optional func searchFor(_ `for`: String!, only: MusicESrA) -> MusicTrack // search a playlist for tracks matching the search string. Identical to entering search text in the Search field.
}
extension SBObject: MusicPlaylist {}

// MARK: MusicAudioCDPlaylist
@objc public protocol MusicAudioCDPlaylist: MusicPlaylist {
    @objc optional var artist: String { get } // the artist of the CD
    @objc optional var compilation: Bool { get } // is this CD a compilation album?
    @objc optional var composer: String { get } // the composer of the CD
    @objc optional var discCount: Int { get } // the total number of discs in this CD’s album
    @objc optional var discNumber: Int { get } // the index of this CD disc in the source album
    @objc optional var genre: String { get } // the genre of the CD
    @objc optional var year: Int { get } // the year the album was recorded/released
    @objc optional func audioCDTracks() -> SBElementArray
}
extension SBObject: MusicAudioCDPlaylist {}

// MARK: MusicLibraryPlaylist
@objc public protocol MusicLibraryPlaylist: MusicPlaylist {
    @objc optional func fileTracks() -> SBElementArray
    @objc optional func URLTracks() -> SBElementArray
    @objc optional func sharedTracks() -> SBElementArray
}
extension SBObject: MusicLibraryPlaylist {}

// MARK: MusicRadioTunerPlaylist
@objc public protocol MusicRadioTunerPlaylist: MusicPlaylist {
    @objc optional func URLTracks() -> SBElementArray
}
extension SBObject: MusicRadioTunerPlaylist {}

// MARK: MusicSource
@objc public protocol MusicSource: MusicItem {
    @objc optional var capacity: Int64 { get } // the total size of the source if it has a fixed size
    @objc optional var freeSpace: Int64 { get } // the free space on the source if it has a fixed size
    @objc optional var kind: MusicESrc { get }
    @objc optional func audioCDPlaylists() -> SBElementArray
    @objc optional func libraryPlaylists() -> SBElementArray
    @objc optional func playlists() -> SBElementArray
    @objc optional func radioTunerPlaylists() -> SBElementArray
    @objc optional func subscriptionPlaylists() -> SBElementArray
    @objc optional func userPlaylists() -> SBElementArray
}
extension SBObject: MusicSource {}

// MARK: MusicSubscriptionPlaylist
@objc public protocol MusicSubscriptionPlaylist: MusicPlaylist {
    @objc optional func fileTracks() -> SBElementArray
    @objc optional func URLTracks() -> SBElementArray
}
extension SBObject: MusicSubscriptionPlaylist {}

// MARK: MusicTrack
@objc public protocol MusicTrack: MusicItem {
    @objc optional var album: String { get } // the album name of the track
    @objc optional var albumArtist: String { get } // the album artist of the track
    @objc optional var albumDisliked: Bool { get } // is the album for this track disliked?
    @objc optional var albumFavorited: Bool { get } // is the album for this track favorited?
    @objc optional var albumRating: Int { get } // the rating of the album for this track (0 to 100)
    @objc optional var albumRatingKind: MusicERtK { get } // the rating kind of the album rating for this track
    @objc optional var artist: String { get } // the artist/source of the track
    @objc optional var bitRate: Int { get } // the bit rate of the track (in kbps)
    @objc optional var bookmark: Double { get } // the bookmark time of the track in seconds
    @objc optional var bookmarkable: Bool { get } // is the playback position for this track remembered?
    @objc optional var bpm: Int { get } // the tempo of this track in beats per minute
    @objc optional var category: String { get } // the category of the track
    @objc optional var cloudStatus: MusicEClS { get } // the iCloud status of the track
    @objc optional var comment: String { get } // freeform notes about the track
    @objc optional var compilation: Bool { get } // is this track from a compilation album?
    @objc optional var composer: String { get } // the composer of the track
    @objc optional var databaseID: Int { get } // the common, unique ID for this track. If two tracks in different playlists have the same database ID, they are sharing the same data.
    @objc optional var dateAdded: Date { get } // the date the track was added to the playlist
    @objc optional var objectDescription: String { get } // the description of the track
    @objc optional var discCount: Int { get } // the total number of discs in the source album
    @objc optional var discNumber: Int { get } // the index of the disc containing this track on the source album
    @objc optional var disliked: Bool { get } // is this track disliked?
    @objc optional var downloaderAccount: String { get } // the account of the person who downloaded this track
    @objc optional var downloaderName: String { get } // the name of the person who downloaded this track
    @objc optional var duration: Double { get } // the length of the track in seconds
    @objc optional var enabled: Bool { get } // is this track checked for playback?
    @objc optional var episodeID: String { get } // the episode ID of the track
    @objc optional var episodeNumber: Int { get } // the episode number of the track
    @objc optional var EQ: String { get } // the name of the EQ preset of the track
    @objc optional var finish: Double { get } // the stop time of the track in seconds
    @objc optional var gapless: Bool { get } // is this track from a gapless album?
    @objc optional var genre: String { get } // the music/audio genre (category) of the track
    @objc optional var grouping: String { get } // the grouping (piece) of the track. Generally used to denote movements within a classical work.
    @objc optional var kind: String { get } // a text description of the track
    @objc optional var longDescription: String { get } // the long description of the track
    @objc optional var favorited: Bool { get } // is this track favorited?
    @objc optional var lyrics: String { get } // the lyrics of the track
    @objc optional var mediaKind: MusicEMdK { get } // the media kind of the track
    @objc optional var modificationDate: Date { get } // the modification date of the content of this track
    @objc optional var movement: String { get } // the movement name of the track
    @objc optional var movementCount: Int { get } // the total number of movements in the work
    @objc optional var movementNumber: Int { get } // the index of the movement in the work
    @objc optional var playedCount: Int { get } // number of times this track has been played
    @objc optional var playedDate: Date { get } // the date and time this track was last played
    @objc optional var purchaserAccount: String { get } // the account of the person who purchased this track
    @objc optional var purchaserName: String { get } // the name of the person who purchased this track
    @objc optional var rating: Int { get } // the rating of this track (0 to 100)
    @objc optional var ratingKind: MusicERtK { get } // the rating kind of this track
    @objc optional var releaseDate: Date { get } // the release date of this track
    @objc optional var sampleRate: Int { get } // the sample rate of the track (in Hz)
    @objc optional var seasonNumber: Int { get } // the season number of the track
    @objc optional var shufflable: Bool { get } // is this track included when shuffling?
    @objc optional var skippedCount: Int { get } // number of times this track has been skipped
    @objc optional var skippedDate: Date { get } // the date and time this track was last skipped
    @objc optional var show: String { get } // the show name of the track
    @objc optional var sortAlbum: String { get } // override string to use for the track when sorting by album
    @objc optional var sortArtist: String { get } // override string to use for the track when sorting by artist
    @objc optional var sortAlbumArtist: String { get } // override string to use for the track when sorting by album artist
    @objc optional var sortName: String { get } // override string to use for the track when sorting by name
    @objc optional var sortComposer: String { get } // override string to use for the track when sorting by composer
    @objc optional var sortShow: String { get } // override string to use for the track when sorting by show name
    @objc optional var size: Int64 { get } // the size of the track (in bytes)
    @objc optional var start: Double { get } // the start time of the track in seconds
    @objc optional var time: String { get } // the length of the track in MM:SS format
    @objc optional var trackCount: Int { get } // the total number of tracks on the source album
    @objc optional var trackNumber: Int { get } // the index of the track on the source album
    @objc optional var unplayed: Bool { get } // is this track unplayed?
    @objc optional var volumeAdjustment: Int { get } // relative volume adjustment of the track (-100% to 100%)
    @objc optional var work: String { get } // the work name of the track
    @objc optional var year: Int { get } // the year the track was recorded/released
    @objc optional func artworks() -> SBElementArray
}
extension SBObject: MusicTrack {}

// MARK: MusicAudioCDTrack
@objc public protocol MusicAudioCDTrack: MusicTrack {
    @objc optional var location: URL { get } // the location of the file represented by this track
}
extension SBObject: MusicAudioCDTrack {}

// MARK: MusicFileTrack
@objc public protocol MusicFileTrack: MusicTrack {
    @objc optional var location: URL { get } // the location of the file represented by this track
    @objc optional func refresh() // update file track information from the current information in the track’s file
}
extension SBObject: MusicFileTrack {}

// MARK: MusicSharedTrack
@objc public protocol MusicSharedTrack: MusicTrack {
}
extension SBObject: MusicSharedTrack {}

// MARK: MusicURLTrack
@objc public protocol MusicURLTrack: MusicTrack {
    @objc optional var address: String { get } // the URL for this track
}
extension SBObject: MusicURLTrack {}

// MARK: MusicUserPlaylist
@objc public protocol MusicUserPlaylist: MusicPlaylist {
    @objc optional var shared: Bool { get } // is this playlist shared?
    @objc optional var smart: Bool { get } // is this a Smart Playlist?
    @objc optional var genius: Bool { get } // is this a Genius Playlist?
    @objc optional func fileTracks() -> SBElementArray
    @objc optional func URLTracks() -> SBElementArray
    @objc optional func sharedTracks() -> SBElementArray
}
extension SBObject: MusicUserPlaylist {}

// MARK: MusicFolderPlaylist
@objc public protocol MusicFolderPlaylist: MusicUserPlaylist {
}
extension SBObject: MusicFolderPlaylist {}

// MARK: MusicVisual
@objc public protocol MusicVisual: MusicItem {
}
extension SBObject: MusicVisual {}

// MARK: MusicWindow
@objc public protocol MusicWindow: MusicItem {
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
extension SBObject: MusicWindow {}

// MARK: MusicBrowserWindow
@objc public protocol MusicBrowserWindow: MusicWindow {
    @objc optional var selection: SBObject { get } // the selected tracks
    @objc optional var view: MusicPlaylist { get } // the playlist currently displayed in the window
}
extension SBObject: MusicBrowserWindow {}

// MARK: MusicEQWindow
@objc public protocol MusicEQWindow: MusicWindow {
}
extension SBObject: MusicEQWindow {}

// MARK: MusicMiniplayerWindow
@objc public protocol MusicMiniplayerWindow: MusicWindow {
}
extension SBObject: MusicMiniplayerWindow {}

// MARK: MusicPlaylistWindow
@objc public protocol MusicPlaylistWindow: MusicWindow {
    @objc optional var selection: SBObject { get } // the selected tracks
    @objc optional var view: MusicPlaylist { get } // the playlist displayed in the window
}
extension SBObject: MusicPlaylistWindow {}

// MARK: MusicVideoWindow
@objc public protocol MusicVideoWindow: MusicWindow {
}
extension SBObject: MusicVideoWindow {}

