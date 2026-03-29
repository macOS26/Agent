import Foundation
import MusicBridge

// ============================================================================
// PlayRandomFromCurrent - Play random track from current playlist
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "json=true" or just run with no args
//     Example: "json=true"
//
//   Option 2: JSON input file at ~/Documents/AgentScript/json/PlayRandomFromCurrent_input.json
//     {
//       "json": true
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/PlayRandomFromCurrent_output.json
//   {
//     "success": true,
//     "playlist": "Playlist Name",
//     "trackCount": 50,
//     "randomIndex": 23,
//     "track": { "name": "...", "artist": "...", "album": "..." }
//   }
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    playRandomFromCurrent()
    return 0
}

func playRandomFromCurrent() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/PlayRandomFromCurrent_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/PlayRandomFromCurrent_output.json"
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var outputJSON = false
    
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                if key == "json" {
                    outputJSON = value.lowercased() == "true"
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("❌ Could not connect to Music.app")
        writeOutput(outputPath, success: false, error: "Could not connect to Music.app", outputJSON: outputJSON)
        return
    }
    
    // Get the current playlist (if any)
    guard let currentPlaylist = music.currentPlaylist else {
        print("❌ No playlist currently selected")
        print("ℹ️ Please select a playlist first")
        writeOutput(outputPath, success: false, error: "No playlist currently selected", outputJSON: outputJSON)
        return
    }
    
    let playlistName = currentPlaylist.name ?? "Unknown"
    print("📁 Current playlist: \(playlistName)")
    
    // Get tracks in the playlist
    guard let tracks = currentPlaylist.tracks?() else {
        print("Could not get tracks from playlist")
        writeOutput(outputPath, success: false, error: "Could not get tracks from playlist", outputJSON: outputJSON)
        return
    }
    
    let trackCount = tracks.count
    print("📊 \(trackCount) tracks")
    
    if trackCount == 0 {
        print("❌ Playlist is empty!")
        writeOutput(outputPath, success: false, error: "Playlist is empty", outputJSON: outputJSON)
        return
    }
    
    // Pick a random track
    let randomIndex = Int.random(in: 0..<trackCount)
    print("🎲 Random track index: \(randomIndex)")
    
    guard let randomTrack = tracks.object(at: randomIndex) as? MusicTrack else {
        print("Could not get random track")
        writeOutput(outputPath, success: false, error: "Could not get random track", outputJSON: outputJSON)
        return
    }
    
    let trackName = randomTrack.name ?? "Unknown"
    let artist = randomTrack.artist ?? "Unknown"
    let album = randomTrack.album ?? "Unknown"
    
    print("\n▶️ Playing random track:")
    print("   🎶 \(trackName)")
    print("   👤 \(artist)")
    print("   💿 \(album)")
    
    // Play the random track
    randomTrack.playOnce?(false)
    
    // Small delay to let playback start
    Thread.sleep(forTimeInterval: 1.0)
    
    // Confirm playback
    var nowPlayingName = trackName
    var nowPlayingArtist = artist
    
    if let nowPlaying = music.currentTrack {
        nowPlayingName = nowPlaying.name ?? "Unknown"
        nowPlayingArtist = nowPlaying.artist ?? "Unknown"
        print("\n✅ Now playing: \(nowPlayingName) - \(nowPlayingArtist)")
    }
    
    // Write JSON output if requested
    if outputJSON {
        let trackInfo: [String: Any] = [
            "name": nowPlayingName,
            "artist": nowPlayingArtist,
            "album": album
        ]
        
        let result: [String: Any] = [
            "success": true,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "playlist": playlistName,
            "trackCount": trackCount,
            "randomIndex": randomIndex,
            "track": trackInfo
        ]
        
        try? FileManager.default.createDirectory(atPath: "\(home)/Documents/AgentScript/json", withIntermediateDirectories: true)
        if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
            try? out.write(to: URL(fileURLWithPath: outputPath))
            print("\n📄 JSON saved to: \(outputPath)")
        }
    }
}

func writeOutput(_ path: String, success: Bool, error: String?, outputJSON: Bool) {
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