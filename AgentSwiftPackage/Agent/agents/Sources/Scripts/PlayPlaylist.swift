import Foundation
import MusicBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    // Parse arguments
    let args = CommandLine.arguments
    var playlistName = "Rock Playlist"
    var shuffle = true
    var randomStart = true
    
    // Skip the first argument (script path) and filter valid args
    let validArgs = args.dropFirst().filter { !$0.contains(".dylib") && !$0.contains("Package.swift") }
    
    for arg in validArgs {
        if arg == "--no-shuffle" {
            shuffle = false
        } else if arg == "--no-random" {
            randomStart = false
        } else if !arg.hasPrefix("--") && !arg.isEmpty && arg != "YES" && arg != "NO" {
            // Only accept non-flag arguments that aren't YES/NO (build artifacts)
            playlistName = arg
        }
    }
    
    playPlaylist(named: playlistName, shuffle: shuffle, randomStart: randomStart)
    return 0
}

func playPlaylist(named name: String, shuffle: Bool, randomStart: Bool) {
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("Could not connect to Music.app")
        return
    }
    
    print("🎵 Playlist: \(name)")
    print("🔀 Shuffle: \(shuffle ? "ON" : "OFF")")
    print("🎲 Random Start: \(randomStart ? "YES" : "NO")")
    
    // Enable shuffle mode if requested
    if shuffle {
        let shuffleScript = """
        tell application "Music"
            set shuffle enabled to true
            set shuffle mode to songs
        end tell
        """
        let appleScript = NSAppleScript(source: shuffleScript)
        var errorDict: NSDictionary?
        appleScript?.executeAndReturnError(&errorDict)
        if let error = errorDict {
            print("Note: Could not set shuffle: \(error)")
        } else {
            print("✅ Shuffle enabled")
        }
    }
    
    // Find the playlist
    guard let playlists = music.playlists?() else {
        print("Could not get playlists")
        return
    }
    
    for i in 0..<playlists.count {
        if let playlist = playlists.object(at: i) as? MusicPlaylist,
           let plName = playlist.name,
           plName.lowercased().contains(name.lowercased()) {
            
            print("\n✅ Found playlist: \(plName)")
            
            // Get tracks in playlist
            guard let tracks = playlist.tracks?() else {
                print("Could not get tracks")
                return
            }
            
            let trackCount = tracks.count
            print("📊 \(trackCount) tracks")
            
            if trackCount == 0 {
                print("Playlist is empty!")
                return
            }
            
            if randomStart {
                // Pick a random track to start from
                let randomIndex = Int.random(in: 0..<trackCount)
                print("🎲 Random track index: \(randomIndex)")
                
                if let randomTrack = tracks.object(at: randomIndex) as? MusicTrack {
                    let trackName = randomTrack.name ?? "Unknown"
                    let artist = randomTrack.artist ?? "Unknown"
                    print("🎵 Starting with: \(trackName) - \(artist)")
                    
                    // Play the random track
                    randomTrack.playOnce?(false)
                }
            } else {
                // Play from beginning
                playlist.playOnce?(false)
            }
            
            // Small delay to let playback start
            Thread.sleep(forTimeInterval: 1.5)
            
            // Show what's playing
            if let track = music.currentTrack {
                let trackName = track.name ?? "Unknown"
                let artist = track.artist ?? "Unknown"
                let album = track.album ?? "Unknown"
                print("\n▶️ NOW PLAYING:")
                print("   🎶 \(trackName)")
                print("   👤 \(artist)")
                print("   💿 \(album)")
                
                // Show shuffle state
                if let shuffleEnabled = music.shuffleEnabled {
                    print("   🔀 Shuffle: \(shuffleEnabled ? "ON" : "OFF")")
                }
                
                // Show player state
                if let state = music.playerState {
                    let stateStr: String
                    switch state {
                    case .playing: stateStr = "Playing"
                    case .paused: stateStr = "Paused"
                    case .stopped: stateStr = "Stopped"
                    case .fastForwarding: stateStr = "Fast Forwarding"
                    case .rewinding: stateStr = "Rewinding"
                    }
                    print("   📻 State: \(stateStr)")
                }
            }
            return
        }
    }
    
    print("❌ Playlist '\(name)' not found")
    
    // List available playlists
    print("\n📁 Available playlists:")
    for i in 0..<min(playlists.count, 15) {
        if let playlist = playlists.object(at: i) as? MusicPlaylist,
           let plName = playlist.name {
            print("   • \(plName)")
        }
    }
}