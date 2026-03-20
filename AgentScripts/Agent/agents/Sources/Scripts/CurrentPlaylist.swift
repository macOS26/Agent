import Foundation
import MusicBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    getCurrentPlaylist()
    return 0
}

func getCurrentPlaylist() {
    let home = NSHomeDirectory()
    let jsonOutputPath = "\(home)/Documents/AgentScript/json/CurrentPlaylist_output.json"
    
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("❌ Could not connect to Music.app")
        return
    }
    
    let state = music.playerState ?? .stopped
    
    print("🎵 Music.app Status")
    print("═══════════════════════════════════════")
    
    // Show player state
    let stateString: String
    switch state {
    case .playing:
        stateString = "playing"
        print("Status: ▶️ Playing")
    case .paused:
        stateString = "paused"
        print("Status: ⏸️ Paused")
    case .stopped:
        stateString = "stopped"
        print("Status: ⏹️ Stopped")
    case .fastForwarding:
        stateString = "fastForwarding"
        print("Status: ⏩ Fast Forwarding")
    case .rewinding:
        stateString = "rewinding"
        print("Status: ⏪ Rewinding")
    default:
        stateString = "unknown"
        print("Status: Unknown")
    }
    
    // Get current track
    if let track = music.currentTrack {
        // Show track info
        let trackName = track.name ?? "Unknown"
        let trackArtist = track.artist ?? "Unknown"
        let trackAlbum = track.album ?? ""
        
        print("\n📀 Now Playing:")
        print("   Track:  \(trackName)")
        print("   Artist: \(trackArtist)")
        if !trackAlbum.isEmpty {
            print("   Album:  \(trackAlbum)")
        }
        
        // Get current playlist
        if let playlist = music.currentPlaylist {
            let playlistName = playlist.name ?? "Unknown"
            
            print("\n📂 Playlist:")
            print("   Name:       \(playlistName)")
            
            if let specialKind = playlist.specialKind {
                print("   Kind:       \(specialKindName(specialKind))")
            }
            
            if let duration = playlist.duration {
                let mins = duration / 60
                let secs = duration % 60
                print("   Duration:   \(mins):\(String(format: "%02d", secs))")
            }
            
            if let timeStr = playlist.time {
                print("   Total Time: \(timeStr)")
            }
        }
    } else {
        print("\n⚠️ No track currently playing")
        print("\n💡 Tip: Play a track in Music.app to see playlist info")
        
        // List available playlists when nothing is playing
        if let playlists = music.playlists?() {
            let count = playlists.count
            if count > 0 {
                print("\n📚 Available Playlists (\(count) total):")
                let limit = min(10, Int(count))
                for i in 0..<limit {
                    if let pl = playlists.object(at: i) as? MusicPlaylist {
                        let name = pl.name ?? "Unknown"
                        let kind = pl.specialKind.map { specialKindName($0) } ?? "Standard"
                        print("   • \(name) (\(kind))")
                    }
                }
                if count > limit {
                    print("   ... and \(count - limit) more")
                }
            }
        }
    }
    
    print("═══════════════════════════════════════")
    
    // Write JSON output
    var result: [String: Any] = [
        "success": true,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "playerState": stateString
    ]
    
    if let track = music.currentTrack {
        var trackInfo: [String: Any] = [
            "name": track.name ?? "Unknown",
            "artist": track.artist ?? "Unknown"
        ]
        if let album = track.album, !album.isEmpty { trackInfo["album"] = album }
        result["track"] = trackInfo
        
        if let playlist = music.currentPlaylist {
            var playlistInfo: [String: Any] = ["name": playlist.name ?? "Unknown"]
            if let kind = playlist.specialKind { playlistInfo["kind"] = specialKindName(kind) }
            result["playlist"] = playlistInfo
        }
    }
    
    try? FileManager.default.createDirectory(atPath: (jsonOutputPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: jsonOutputPath))
        print("\n📄 JSON saved to: \(jsonOutputPath)")
    }
}

func specialKindName(_ kind: MusicESpK) -> String {
    switch kind {
    case .none: return "Standard Playlist"
    case .folder: return "Folder"
    case .genius: return "Genius"
    case .library: return "Library"
    case .music: return "Music"
    case .purchasedMusic: return "Purchased Music"
    @unknown default: return "Unknown (\(kind.rawValue))"
    }
}