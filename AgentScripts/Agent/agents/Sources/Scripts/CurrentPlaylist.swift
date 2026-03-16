import Foundation
import MusicBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    getCurrentPlaylist()
    return 0
}

func getCurrentPlaylist() {
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("❌ Could not connect to Music.app")
        return
    }
    
    let state = music.playerState ?? .stopped
    
    // Print header
    print("🎵 Current Playlist Info")
    print("═══════════════════════════════════════")
    
    // Show player state
    switch state {
    case .playing:
        print("Status: ▶️ Playing")
    case .paused:
        print("Status: ⏸️ Paused")
    case .stopped:
        print("Status: ⏹️ Stopped")
    case .fastForwarding:
        print("Status: ⏩ Fast Forwarding")
    case .rewinding:
        print("Status: ⏪ Rewinding")
    default:
        print("Status: Unknown")
    }
    
    // Get current track
    guard let track = music.currentTrack else {
        print("\n⚠️ No track currently selected")
        print("═══════════════════════════════════════")
        return
    }
    
    // Show track info
    print("\n📀 Now Playing:")
    print("   Track:  \(track.name ?? "Unknown")")
    print("   Artist: \(track.artist ?? "Unknown")")
    if let album = track.album, !album.isEmpty {
        print("   Album:  \(album)")
    }
    
    // Get the container (playlist) using the same technique as Apple Events
    // currentTrack.container returns the playlist the track is playing from
    if let container = track.container as? SBObject {
        let playlistName = container.value(forKey: "name") as? String ?? "Unknown"
        let playlistId = container.value(forKey: "id") as? Int ?? -1
        let playlistClass = container.value(forKey: "class") as? String ?? "Unknown"
        let specialKind = container.value(forKey: "specialKind") as? Int ?? -1
        
        print("\n📂 Playlist:")
        print("   Name:       \(playlistName)")
        print("   ID:         \(playlistId)")
        print("   Class:      \(playlistClass)")
        
        // Map specialKind to human-readable names
        let specialKindNames: [Int: String] = [
            0: "None",
            1: "Library",
            2: "Purchased",
            3: "Folder",
            4: "Smart",
            5: "Genius",
            6: "Music",
            7: "Movies",
            8: "TV Shows",
            9: "Podcasts",
            10: "Audiobooks",
            11: "Books",
            12: "Purchases",
            13: "Internet Songs",
            14: "Internet Videos",
            15: "Radio",
            16: "Radio Tuner",
            17: "Videos",
            18: "Playlists",
            19: "Devices",
            20: "Shared Library",
            21: "DJ",
            22: "Home Videos",
            23: "Apps",
            24: "Tones",
            25: "Voice Memos",
            26: "Cloud",
            27: "Apple Music",
        ]
        
        if let kindName = specialKindNames[specialKind] {
            print("   Special Kind: \(kindName)")
        }
    } else {
        print("\n⚠️ Could not determine playlist")
    }
    
    print("═══════════════════════════════════════")
}