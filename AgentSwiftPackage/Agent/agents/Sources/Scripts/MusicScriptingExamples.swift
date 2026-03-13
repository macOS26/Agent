import Foundation
import MusicBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    musicScriptingExamples()
    return 0
}

func musicScriptingExamples() {
    // Music Scripting Dictionary Examples
    // This demonstrates key features from the Music app's AppleScript dictionary

    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("Could not connect to Music")
        return
    }

    // MARK: - Application Properties
    print("=== Application Properties ===")
    print("Current track: \(music.currentTrack?.name ?? "None")")
    print("Player state: \(music.playerState ?? .stopped)")
    print("Volume: \(music.soundVolume ?? 0)")
    print("Shuffle: \(music.shuffleEnabled ?? false)")
    print("Repeat: \(music.songRepeat ?? .off)")
    print("")

    // MARK: - Playback Control
    print("=== Playback Commands ===")
    // music.play?()          // Start playback
    // music.pause?()         // Pause playback
    // music.playpause?()     // Toggle play/pause
    // music.nextTrack?()     // Skip to next
    // music.previousTrack?() // Go to previous
    // music.stop?()          // Stop playback

    // MARK: - Current Track Info
    if let track = music.currentTrack {
        print("\n=== Current Track Details ===")
        print("Name: \(track.name ?? "Unknown")")
        print("Artist: \(track.artist ?? "Unknown")")
        print("Album: \(track.album ?? "Unknown")")
        print("Duration: \(track.time ?? "0:00")")
        print("Rating: \(track.rating ?? 0)")
        print("Play count: \(track.playedCount ?? 0)")
        print("Genre: \(track.genre ?? "Unknown")")
        print("Year: \(track.year ?? 0)")
    }

    // MARK: - Playlists
    print("\n=== Playlists ===")
    if let playlists = music.playlists?() {
        for i in 0..<min(10, playlists.count) {
            if let playlist = playlists.object(at: i) as? MusicPlaylist {
                print("\(i+1). \(playlist.name ?? "Unnamed") - \(playlist.specialKind ?? .none)")

                // Check playlist type
                if let userPlaylist = playlist as? MusicUserPlaylist {
                    print("   User playlist - Smart: \(userPlaylist.smart ?? false), Shared: \(userPlaylist.shared ?? false)")
                } else if let _ = playlist as? MusicLibraryPlaylist {
                    print("   Library playlist")
                } else if let _ = playlist as? MusicSubscriptionPlaylist {
                    print("   Apple Music subscription playlist")
                }
            }
        }
    }

    // MARK: - Search Example
    print("\n=== Search Example ===")
    // Get the main library playlist
    if let playlists = music.playlists?(),
       playlists.count > 0,
       let library = playlists.object(at: 0) as? MusicLibraryPlaylist {

        // Search for tracks
        if let results = library.searchFor?("Beatles", only: .all) {
            print("Search results for 'Beatles':")

            // The search returns an SBObject that acts as a track array
            if let tracks = (results as? SBObject)?.value(forKey: "get") as? [SBObject] {
                for (index, track) in tracks.prefix(5).enumerated() {
                    if let t = track as? MusicTrack {
                        print("\(index+1). \(t.name ?? "Unknown") by \(t.artist ?? "Unknown")")
                    }
                }
            }
        }
    }

    // MARK: - Creating a Playlist
    print("\n=== Creating Playlist (example code) ===")
    print("To create a new playlist:")
    print("// if let newPlaylist = music.make?(with: nil, data: nil) {")
    print("//     newPlaylist.setValue(\"My New Playlist\", forKey: \"name\")")
    print("// }")

    // MARK: - Track Properties
    print("\n=== Track Property Categories ===")
    print("Basic: name, artist, album, genre, year")
    print("Playback: duration, playedCount, skippedCount, rating")
    print("Technical: bitRate, sampleRate, size, kind")
    print("Organization: grouping, albumArtist, composer, compilation")
    print("Cloud: cloudStatus, downloaderAccount, purchaserAccount")
    print("Media: mediaKind, episodeID, season, show")
    print("Classical: work, movement, movementNumber, movementCount")

    // MARK: - AirPlay Devices
    print("\n=== AirPlay Devices ===")
    if let devices = music.airPlayDevices?() {
        for i in 0..<devices.count {
            if let device = devices.object(at: i) as? MusicAirPlayDevice {
                print("Device: \(device.name ?? "Unknown")")
                print("  Kind: \(device.kind ?? .unknown)")
                print("  Active: \(device.active ?? false)")
                print("  Available: \(device.available ?? false)")
            }
        }
    }

    // MARK: - Sources
    print("\n=== Sources ===")
    if let sources = music.sources?() {
        for i in 0..<sources.count {
            if let source = sources.object(at: i) as? MusicSource {
                print("Source: \(source.name ?? "Unknown") - Kind: \(source.kind ?? .unknown)")
            }
        }
    }
}