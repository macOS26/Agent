import Foundation
import MusicBridge
import AppKit

// ============================================================================
// NowPlaying - Show current track with album artwork extraction
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "json=true" or "artwork=true" or "artwork=false"
//     Example: "json=true,artwork=true"
//
//   Option 2: JSON input file at ~/Documents/AgentScript/json/NowPlaying_input.json
//     {
//       "json": true,
//       "artwork": true,
//       "saveArtworkTo": "~/Documents/AgentScript/images/custom.png"
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/NowPlaying_output.json
//   {
//     "success": true,
//     "playerState": "playing",
//     "track": { "name": "...", "artist": "...", "album": "...", "duration": 240 },
//     "artwork": { "saved": true, "path": "...", "width": 500, "height": 500 }
//   }
//
// FEATURES:
//   - Shows current track info (name, artist, album)
//   - Extracts and saves album artwork to PNG
//   - JSON output for automation workflows
//   - Customizable artwork save path
// ============================================================================

@_cdecl("script_main")
public func script_main() -> Int32 {
    nowPlaying()
    return 0
}

func nowPlaying() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/NowPlaying_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/NowPlaying_output.json"
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var outputJSON = false
    var extractArtwork = true
    var artworkPath = "\(home)/Documents/AgentScript/images/now_playing.png"
    
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "json": outputJSON = value.lowercased() == "true"
                case "artwork": extractArtwork = value.lowercased() == "true"
                case "saveArtworkTo": 
                    artworkPath = value
                    if artworkPath.hasPrefix("~") {
                        artworkPath = artworkPath.replacingOccurrences(of: "~", with: home)
                    }
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let j = json["json"] as? Bool { outputJSON = j }
        if let a = json["artwork"] as? Bool { extractArtwork = a }
        if let path = json["saveArtworkTo"] as? String {
            artworkPath = path
            if artworkPath.hasPrefix("~") {
                artworkPath = artworkPath.replacingOccurrences(of: "~", with: home)
            }
        }
    }
    
    // Connect to Music app
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("❌ Could not connect to Music.app")
        writeOutput(outputPath, success: false, playerState: nil, track: nil, artwork: nil, outputJSON: outputJSON)
        return
    }
    
    let state = music.playerState ?? .stopped
    let stateStr: String
    switch state {
    case .playing: stateStr = "playing"
    case .paused: stateStr = "paused"
    case .stopped: stateStr = "stopped"
    case .fastForwarding: stateStr = "fastForwarding"
    case .rewinding: stateStr = "rewinding"
    default: stateStr = "unknown"
    }
    
    // Check if playing
    if state != .playing {
        print("⚠️ Nothing currently playing (state: \(stateStr))")
        writeOutput(outputPath, success: true, playerState: stateStr, track: nil, artwork: nil, outputJSON: outputJSON)
        return
    }
    
    // Get current track
    guard let track = music.currentTrack else {
        print("⚠️ No track selected")
        writeOutput(outputPath, success: true, playerState: stateStr, track: nil, artwork: nil, outputJSON: outputJSON)
        return
    }
    
    // Extract track info
    let name = track.name ?? "Unknown"
    let artist = track.artist ?? "Unknown"
    let album = track.album ?? "Unknown"
    let duration = track.duration ?? 0
    
    // Print track info
    print("🎵 Now Playing")
    print("═══════════════════════════════════════")
    print("   Track:  \(name)")
    print("   Artist: \(artist)")
    print("   Album:  \(album)")
    
    let mins = Int(duration) / 60
    let secs = Int(duration) % 60
    print("   Duration: \(mins):\(String(format: "%02d", secs))")
    
    var trackInfo: [String: Any] = [
        "name": name,
        "artist": artist,
        "album": album,
        "duration": duration,
        "durationFormatted": "\(mins):\(String(format: "%02d", secs))"
    ]
    
    // Add optional track details
    if let year = track.year, year > 0 {
        trackInfo["year"] = year
        print("   Year: \(year)")
    }
    if let genre = track.genre, !genre.isEmpty {
        trackInfo["genre"] = genre
        print("   Genre: \(genre)")
    }
    if let trackNum = track.trackNumber, trackNum > 0 {
        trackInfo["trackNumber"] = trackNum
        var trackStr = "   Track #: \(trackNum)"
        if let count = track.trackCount, count > 0 {
            trackStr += " of \(count)"
            trackInfo["trackCount"] = count
        }
        print(trackStr)
    }
    
    // Extract album artwork
    var artworkInfo: [String: Any]? = nil
    
    if extractArtwork {
        print("\n📷 Extracting artwork...")
        
        if let artworks = track.artworks?(), artworks.count > 0 {
            let artworkObj = artworks.object(at: 0)
            if let sbArtwork = artworkObj as? SBObject {
                // Get the NSImage via value(forKey:)
                if let nsImage = sbArtwork.value(forKey: "data") as? NSImage {
                    let width = Int(nsImage.size.width)
                    let height = Int(nsImage.size.height)
                    print("   Size: \(width)x\(height)")
                    
                    // Ensure output directory exists
                    let outputDir = (artworkPath as NSString).deletingLastPathComponent
                    try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
                    
                    // Convert to PNG and save
                    if let tiffData = nsImage.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        do {
                            try pngData.write(to: URL(fileURLWithPath: artworkPath))
                            print("   ✅ Saved: \(artworkPath)")
                            print(artworkPath)  // Print path for easy access
                            
                            artworkInfo = [
                                "saved": true,
                                "path": artworkPath,
                                "width": width,
                                "height": height
                            ]
                        } catch {
                            print("   ❌ Error saving: \(error.localizedDescription)")
                        }
                    } else {
                        print("   ❌ Could not convert to PNG")
                    }
                } else {
                    print("   ⚠️ No artwork data available")
                }
            }
        } else {
            print("   ⚠️ No artworks found for this track")
        }
    }
    
    print("═══════════════════════════════════════")
    
    // Write JSON output if requested
    if outputJSON {
        writeOutput(outputPath, success: true, playerState: stateStr, track: trackInfo, artwork: artworkInfo, outputJSON: true)
    }
}

func writeOutput(_ path: String, success: Bool, playerState: String?, track: [String: Any]?, artwork: [String: Any]?, outputJSON: Bool) {
    guard outputJSON else { return }
    
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    
    if let playerState = playerState {
        result["playerState"] = playerState
    }
    if let track = track {
        result["track"] = track
    }
    if let artwork = artwork {
        result["artwork"] = artwork
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}