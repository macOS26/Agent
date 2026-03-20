import Foundation
import MusicBridge

// ============================================================================
// PlayPlaylist - Play a playlist in Music.app with optional shuffle
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "param1=value1,param2=value2"
//     Parameters:
//       - playlist=Rock Playlist (name or partial match, required)
//       - shuffle=true (enable shuffle, default: true)
//       - random=true (start at random track, default: true)
//       - json=true (output to JSON file)
//     Example: "playlist=Rock,shuffle=false,random=true,json=true"
//
//   Option 2: JSON input file at ~/Documents/AgentScript/json/PlayPlaylist_input.json
//     {
//       "playlist": "Rock Playlist",
//       "shuffle": true,
//       "random": true,
//       "json": true
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/PlayPlaylist_output.json
//   {
//     "success": true,
//     "playlist": "Rock Playlist",
//     "trackCount": 50,
//     "nowPlaying": {
//       "name": "Song Name",
//       "artist": "Artist",
//       "album": "Album"
//     },
//     "timestamp": "2026-03-16T..."
//   }
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    playPlaylist()
    return 0
}

func playPlaylist() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/PlayPlaylist_input.json"
    let jsonOutputPath = "\(home)/Documents/AgentScript/json/PlayPlaylist_output.json"
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var playlistName = ""
    var shuffle = true
    var randomStart = true
    var outputJSON = false
    
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "playlist", "name", "pl":
                    playlistName = value
                case "shuffle":
                    shuffle = value.lowercased() == "true"
                case "random", "randomStart":
                    randomStart = value.lowercased() == "true"
                case "json":
                    outputJSON = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let name = json["playlist"] as? String { playlistName = name }
        if let s = json["shuffle"] as? Bool { shuffle = s }
        if let r = json["random"] as? Bool { randomStart = r }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    // Validate required parameter
    if playlistName.isEmpty {
        print("❌ No playlist specified")
        print("Usage: playlist=\"Playlist Name\" OR json input file")
        writeOutput(jsonOutputPath, success: false, error: "No playlist specified", outputJSON: outputJSON)
        return
    }
    
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("❌ Could not connect to Music.app")
        writeOutput(jsonOutputPath, success: false, error: "Could not connect to Music.app", outputJSON: outputJSON)
        return
    }
    
    print("🎵 Play Playlist")
    print("═══════════════════════════════════════")
    print("Playlist: \(playlistName)")
    print("Shuffle: \(shuffle ? "ON" : "OFF")")
    print("Random Start: \(randomStart ? "YES" : "NO")")
    
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
        print("❌ Could not get playlists")
        writeOutput(jsonOutputPath, success: false, error: "Could not get playlists", outputJSON: outputJSON)
        return
    }
    
    for i in 0..<playlists.count {
        if let playlist = playlists.object(at: i) as? MusicPlaylist,
           let plName = playlist.name,
           plName.lowercased().contains(playlistName.lowercased()) {
            
            print("\n✅ Found playlist: \(plName)")
            
            // Get tracks in playlist
            guard let tracks = playlist.tracks?() else {
                print("❌ Could not get tracks")
                writeOutput(jsonOutputPath, success: false, error: "Could not get tracks", outputJSON: outputJSON)
                return
            }
            
            let trackCount = tracks.count
            print("📊 \(trackCount) tracks")
            
            if trackCount == 0 {
                print("❌ Playlist is empty")
                writeOutput(jsonOutputPath, success: false, error: "Playlist is empty", outputJSON: outputJSON)
                return
            }
            
            var nowPlaying: [String: Any]? = nil
            
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
                let album = track.album ?? ""
                
                print("\n▶️ NOW PLAYING:")
                print("   🎶 \(trackName)")
                print("   👤 \(artist)")
                if !album.isEmpty {
                    print("   💿 \(album)")
                }
                
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
                
                nowPlaying = [
                    "name": trackName,
                    "artist": artist
                ]
                if !album.isEmpty {
                    nowPlaying?["album"] = album
                }
            }
            
            print("═══════════════════════════════════════")
            
            // Write JSON output if requested
            if outputJSON {
                var result: [String: Any] = [
                    "success": true,
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "playlist": plName,
                    "trackCount": trackCount
                ]
                
                if let nowPlaying = nowPlaying {
                    result["nowPlaying"] = nowPlaying
                }
                
                try? FileManager.default.createDirectory(atPath: (jsonOutputPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
                if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
                    try? out.write(to: URL(fileURLWithPath: jsonOutputPath))
                    print("\n📄 JSON saved to: \(jsonOutputPath)")
                }
            }
            
            return
        }
    }
    
    print("❌ Playlist '\(playlistName)' not found")
    
    // List available playlists
    print("\n📁 Available playlists:")
    for i in 0..<min(playlists.count, 15) {
        if let playlist = playlists.object(at: i) as? MusicPlaylist,
           let plName = playlist.name {
            print("   • \(plName)")
        }
    }
    
    writeOutput(jsonOutputPath, success: false, error: "Playlist '\(playlistName)' not found", outputJSON: outputJSON)
}

func writeOutput(_ path: String, success: Bool, error: String? = nil, outputJSON: Bool) {
    guard outputJSON else { return }
    
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    
    if let error = error {
        result["error"] = error
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}