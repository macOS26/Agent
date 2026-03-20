import Foundation
import MusicBridge

// ============================================================================
// MusicScriptingExamples - Demonstrate Music.app scripting features
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "section=playlists" or "limit=5,json=true"
//     Parameters:
//       - section=all|properties|track|playlists|search (default: all)
//       - limit=10 (max items to show, default: 10)
//       - json=true (output to JSON file)
//     Example: "section=playlists,limit=5,json=true"
//
//   Option 2: JSON input file at ~/Documents/AgentScript/json/MusicScriptingExamples_input.json
//     {
//       "section": "playlists",
//       "limit": 5,
//       "json": true
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/MusicScriptingExamples_output.json
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    musicScriptingExamples()
    return 0
}

func musicScriptingExamples() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/MusicScriptingExamples_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/MusicScriptingExamples_output.json"
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var section = "all"
    var limit = 10
    var outputJSON = false
    
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "section": section = value.lowercased()
                case "limit": limit = Int(value) ?? 10
                case "json": outputJSON = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let s = json["section"] as? String { section = s.lowercased() }
        if let l = json["limit"] as? Int { limit = l }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("Could not connect to Music")
        writeOutput(outputPath, success: false, error: "Could not connect to Music", outputJSON: outputJSON)
        return
    }

    var result: [String: Any] = [
        "success": true,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]

    // MARK: - Application Properties
    if section == "all" || section == "properties" {
        print("=== Application Properties ===")
        let currentTrack = music.currentTrack?.name ?? "None"
        let playerState: String
        switch music.playerState ?? .stopped {
        case .playing: playerState = "playing"
        case .paused: playerState = "paused"
        case .stopped: playerState = "stopped"
        case .fastForwarding: playerState = "fastForwarding"
        case .rewinding: playerState = "rewinding"
        @unknown default: playerState = "unknown"
        }
        let volume = music.soundVolume ?? 0
        let shuffle = music.shuffleEnabled ?? false
        let repeatMode: String
        switch music.songRepeat ?? .off {
        case .off: repeatMode = "off"
        case .one: repeatMode = "one"
        case .all: repeatMode = "all"
        @unknown default: repeatMode = "unknown"
        }
        
        print("Current track: \(currentTrack)")
        print("Player state: \(playerState)")
        print("Volume: \(volume)")
        print("Shuffle: \(shuffle)")
        print("Repeat: \(repeatMode)")
        print("")
        
        result["properties"] = [
            "currentTrack": currentTrack,
            "playerState": playerState,
            "volume": volume,
            "shuffle": shuffle,
            "repeat": repeatMode
        ]
    }

    // MARK: - Current Track Info
    if section == "all" || section == "track" {
        if let track = music.currentTrack {
            print("\n=== Current Track Details ===")
            let trackInfo: [String: Any] = [
                "name": track.name ?? "Unknown",
                "artist": track.artist ?? "Unknown",
                "album": track.album ?? "Unknown",
                "duration": track.duration ?? 0,
                "durationFormatted": track.time ?? "0:00",
                "rating": track.rating ?? 0,
                "playCount": track.playedCount ?? 0,
                "genre": track.genre ?? "Unknown",
                "year": track.year ?? 0
            ]
            
            print("Name: \(trackInfo["name"] ?? "")")
            print("Artist: \(trackInfo["artist"] ?? "")")
            print("Album: \(trackInfo["album"] ?? "")")
            print("Duration: \(trackInfo["durationFormatted"] ?? "")")
            print("Rating: \(trackInfo["rating"] ?? 0)")
            print("Play count: \(trackInfo["playCount"] ?? 0)")
            print("Genre: \(trackInfo["genre"] ?? "")")
            print("Year: \(trackInfo["year"] ?? 0)")
            
            result["track"] = trackInfo
        }
    }

    // MARK: - Playlists
    if section == "all" || section == "playlists" {
        print("\n=== Playlists ===")
        var playlistsArray: [[String: Any]] = []
        
        if let playlists = music.playlists?() {
            for i in 0..<min(limit, playlists.count) {
                if let playlist = playlists.object(at: i) as? MusicPlaylist {
                    let name = playlist.name ?? "Unnamed"
                    let kind = specialKindName(playlist.specialKind ?? .none)
                    print("\(i+1). \(name) - \(kind)")
                    
                    var playlistInfo: [String: Any] = [
                        "name": name,
                        "kind": kind
                    ]
                    
                    if let userPlaylist = playlist as? MusicUserPlaylist {
                        playlistInfo["smart"] = userPlaylist.smart ?? false
                        playlistInfo["shared"] = userPlaylist.shared ?? false
                        print("   User playlist - Smart: \(userPlaylist.smart ?? false), Shared: \(userPlaylist.shared ?? false)")
                    } else if let _ = playlist as? MusicLibraryPlaylist {
                        playlistInfo["type"] = "library"
                        print("   Library playlist")
                    } else if let _ = playlist as? MusicSubscriptionPlaylist {
                        playlistInfo["type"] = "subscription"
                        print("   Apple Music subscription playlist")
                    }
                    
                    playlistsArray.append(playlistInfo)
                }
            }
        }
        
        result["playlists"] = playlistsArray
        result["playlistCount"] = playlistsArray.count
    }

    // MARK: - Track Property Categories
    if section == "all" || section == "properties" {
        print("\n=== Track Property Categories ===")
        let categories: [String: [String]] = [
            "Basic": ["name", "artist", "album", "genre", "year"],
            "Playback": ["duration", "playedCount", "skippedCount", "rating"],
            "Technical": ["bitRate", "sampleRate", "size", "kind"],
            "Organization": ["grouping", "albumArtist", "composer", "compilation"],
            "Cloud": ["cloudStatus", "downloaderAccount", "purchaserAccount"],
            "Media": ["mediaKind", "episodeID", "season", "show"],
            "Classical": ["work", "movement", "movementNumber", "movementCount"]
        ]
        
        for (cat, props) in categories {
            print("\(cat): \(props.joined(separator: ", "))")
        }
        
        result["propertyCategories"] = categories
    }

    // Write JSON output if requested
    if outputJSON {
        writeFullOutput(outputPath, result)
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

func writeFullOutput(_ path: String, _ result: [String: Any]) {
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}