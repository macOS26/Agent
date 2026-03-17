import Foundation
import MusicBridge

// ============================================================================
// WhatsPlaying - Show detailed info about current track with JSON output
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "json=true" or "verbose=true"
//     Example: "json=true"
//
//   Option 2: JSON input file at ~/Documents/Agent/json/WhatsPlaying_input.json
//     {
//       "json": true,
//       "verbose": true
//     }
//
// OUTPUT: ~/Documents/Agent/json/WhatsPlaying_output.json
//   {
//     "success": true,
//     "playerState": "playing",
//     "track": { "name": "...", "artist": "...", "album": "...", ... },
//     "position": { "current": 120, "total": 240, "percent": 50 },
//     "volume": 75
//   }
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    whatsPlaying()
    return 0
}

func whatsPlaying() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/Agent/json/WhatsPlaying_input.json"
    let outputPath = "\(home)/Documents/Agent/json/WhatsPlaying_output.json"
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var outputJSON = false
    var verbose = false
    
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "json": outputJSON = value.lowercased() == "true"
                case "verbose": verbose = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let j = json["json"] as? Bool { outputJSON = j }
        if let v = json["verbose"] as? Bool { verbose = v }
    }
    
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("❌ Could not connect to Music.app")
        writeOutput(outputPath, success: false, error: "Could not connect to Music.app", outputJSON: outputJSON)
        return
    }
    
    let state = music.playerState ?? .stopped
    
    // Print header with state
    print("🎵 What's Playing")
    print("═══════════════════════════════════════")
    
    let stateStr: String
    switch state {
    case .playing:
        stateStr = "playing"
        print("Status: ▶️ Playing")
    case .paused:
        stateStr = "paused"
        print("Status: ⏸️ Paused")
    case .stopped:
        stateStr = "stopped"
        print("Status: ⏹️ Stopped")
    case .fastForwarding:
        stateStr = "fastForwarding"
        print("Status: ⏩ Fast Forwarding")
    case .rewinding:
        stateStr = "rewinding"
        print("Status: ⏪ Rewinding")
    default:
        stateStr = "unknown"
        print("Status: Unknown")
    }
    
    var trackInfo: [String: Any] = [:]
    var positionInfo: [String: Any] = [:]
    var extrasInfo: [String: Any] = [:]
    
    // Show track info if available
    if let track = music.currentTrack {
        let name = track.name ?? "Unknown"
        let artist = track.artist ?? "Unknown"
        let album = track.album ?? "Unknown"
        let year = track.year ?? 0
        let genre = track.genre ?? ""
        let duration = track.duration ?? 0
        let trackNum = track.trackNumber ?? 0
        let trackCount = track.trackCount ?? 0
        let rating = track.rating ?? 0
        let playCount = track.playedCount ?? 0
        
        print("\n📀 Now Playing:")
        print("   Track:  \(name)")
        print("   Artist: \(artist)")
        print("   Album:  \(album)")
        
        if year > 0 {
            print("   Year:   \(year)")
        }
        
        if !genre.isEmpty {
            print("   Genre:  \(genre)")
        }
        
        // Duration
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        print("   Duration: \(mins):\(String(format: "%02d", secs))")
        
        // Track number
        if trackNum > 0 {
            var trackInfoStr = "   Track #: \(trackNum)"
            if trackCount > 0 {
                trackInfoStr += " of \(trackCount)"
            }
            print(trackInfoStr)
        }
        
        // Rating
        if rating > 0 {
            let stars = rating / 20
            let starString = String(repeating: "⭐", count: stars)
            print("   Rating: \(starString) (\(rating)/100)")
        }
        
        // Play count
        if playCount > 0 {
            print("   Plays: \(playCount)")
        }
        
        // Build track info for JSON
        trackInfo = [
            "name": name,
            "artist": artist,
            "album": album,
            "year": year,
            "genre": genre,
            "duration": duration,
            "durationFormatted": "\(mins):\(String(format: "%02d", secs))",
            "trackNumber": trackNum,
            "trackCount": trackCount,
            "rating": rating,
            "playCount": playCount
        ]
    } else {
        print("\n⚠️ No track currently selected")
    }
    
    // Player position
    if let pos = music.playerPosition, let duration = music.currentTrack?.duration, duration > 0 {
        let posMins = Int(pos) / 60
        let posSecs = Int(pos) % 60
        let totalMins = Int(duration) / 60
        let totalSecs = Int(duration) % 60
        print("\n📍 Position: \(posMins):\(String(format: "%02d", posSecs)) / \(totalMins):\(String(format: "%02d", totalSecs))")
        
        // Progress bar
        let progress = pos / duration
        let barWidth = 30
        let filled = Int(progress * Double(barWidth))
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: barWidth - filled)
        print("   [\(bar)] \(Int(progress * 100))%")
        
        positionInfo = [
            "current": pos,
            "total": duration,
            "percent": Int(progress * 100)
        ]
    }
    
    // Volume
    if let vol = music.soundVolume {
        let volBars = Int(Double(vol) / 100.0 * 10.0)
        let volBar = String(repeating: "🔊", count: volBars)
        print("\n🔈 Volume: \(vol)% \(volBar)")
        
        extrasInfo["volume"] = vol
    }
    
    // Shuffle/Repeat status
    var extras: [String] = []
    if music.shuffleEnabled == true {
        extras.append("Shuffle 🔀")
        extrasInfo["shuffle"] = true
    }
    if let repeatMode = music.songRepeat {
        switch repeatMode {
        case .one:
            extras.append("Repeat One 🔁")
            extrasInfo["repeat"] = "one"
        case .all:
            extras.append("Repeat All 🔁")
            extrasInfo["repeat"] = "all"
        default:
            extrasInfo["repeat"] = "off"
        }
    }
    if !extras.isEmpty {
        print("   " + extras.joined(separator: " | "))
    }
    
    if verbose {
        print("\n═══════════════════════════════════════")
        print("Verbose Info:")
        print("   Player State: \(stateStr)")
        if let track = music.currentTrack {
            print("   Bit Rate: \(track.bitRate ?? 0) kbps")
            print("   Sample Rate: \(track.sampleRate ?? 0) Hz")
            print("   Kind: \(track.kind ?? "")")
            print("   Size: \(track.size ?? 0) bytes")
        }
    }
    
    print("═══════════════════════════════════════")
    
    // Write JSON output if requested
    if outputJSON {
        writeFullOutput(outputPath, success: true, playerState: stateStr, track: trackInfo, position: positionInfo, extras: extrasInfo)
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

func writeFullOutput(_ path: String, success: Bool, playerState: String, track: [String: Any], position: [String: Any], extras: [String: Any]) {
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "playerState": playerState
    ]
    
    if !track.isEmpty { result["track"] = track }
    if !position.isEmpty { result["position"] = position }
    if !extras.isEmpty { result["extras"] = extras }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}