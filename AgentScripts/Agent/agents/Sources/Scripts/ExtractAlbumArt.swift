import Foundation
import MusicBridge

// ============================================================================
// ExtractAlbumArt - Extract album artwork from current track in Music.app
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "param1=value1,param2=value2"
//     Parameters:
//       - output=/path/to/file.jpg (output path, default: ~/Documents/Agent/images/)
//       - format=jpg|png|tiff (output format, default: jpg)
//       - json=true (output to JSON file)
//     Example: "output=~/Desktop/cover.jpg,format=jpg,json=true"
//
//   Option 2: JSON input file at ~/Documents/Agent/json/ExtractAlbumArt_input.json
//     {
//       "output": "~/Desktop/cover.jpg",
//       "format": "jpg",
//       "json": true
//     }
//
// OUTPUT: ~/Documents/Agent/json/ExtractAlbumArt_output.json
//   {
//     "success": true,
//     "outputPath": "/Users/.../cover.jpg",
//     "track": { "name": "Song", "artist": "Artist", "album": "Album" },
//     "fileSize": 12345,
//     "timestamp": "2026-03-16T..."
//   }
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    extractAlbumArt()
    return 0
}

func extractAlbumArt() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/Agent/json/ExtractAlbumArt_input.json"
    let jsonOutputPath = "\(home)/Documents/Agent/json/ExtractAlbumArt_output.json"
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var outputPath: String? = nil
    var format = "jpg"
    var outputJSON = false
    
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "output", "path", "file":
                    outputPath = (value as NSString).expandingTildeInPath
                case "format", "fmt":
                    format = value.lowercased()
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
        if let o = json["output"] as? String { outputPath = (o as NSString).expandingTildeInPath }
        if let f = json["format"] as? String { format = f.lowercased() }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("❌ Could not connect to Music.app")
        writeOutput(jsonOutputPath, success: false, error: "Could not connect to Music.app", outputJSON: outputJSON)
        return
    }
    
    guard let track = music.currentTrack else {
        print("❌ No track currently playing")
        writeOutput(jsonOutputPath, success: false, error: "No track currently playing", outputJSON: outputJSON)
        return
    }
    
    let trackName = track.name ?? "Unknown"
    let artist = track.artist ?? "Unknown"
    let album = track.album ?? "Unknown"
    
    print("🎨 Extract Album Art")
    print("═══════════════════════════════════════")
    print("Track: \(trackName)")
    print("Artist: \(artist)")
    print("Album: \(album)")
    print("")
    
    // Get artwork
    guard let artworks = track.artworks?() else {
        print("❌ No artwork available")
        writeOutput(jsonOutputPath, success: false, error: "No artwork available", outputJSON: outputJSON)
        return
    }
    
    // Find artwork with data
    var artworkData: Data? = nil
    for i in 0..<artworks.count {
        guard let artwork = artworks.object(at: i) as? MusicArtwork else { continue }
        if let data = artwork.data as? Data {
            artworkData = data
            break
        }
    }
    
    guard let data = artworkData else {
        print("❌ Artwork found but no data available")
        writeOutput(jsonOutputPath, success: false, error: "Artwork found but no data available", outputJSON: outputJSON)
        return
    }
    
    // Set default output path if not specified
    let sanitizedTrack = trackName.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "-")
    let imagesDir = "\(home)/Documents/Agent/images"
    try? FileManager.default.createDirectory(atPath: imagesDir, withIntermediateDirectories: true)
    
    let extension_: String
    switch format {
    case "png": extension_ = "png"
    case "tiff", "tif": extension_ = "tiff"
    default: extension_ = "jpg"
    }
    
    let finalPath = outputPath ?? "\(imagesDir)/\(sanitizedTrack).\(extension_)"
    
    // Ensure directory exists
    let dir = (finalPath as NSString).deletingLastPathComponent
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    
    // Save the artwork
    do {
        try data.write(to: URL(fileURLWithPath: finalPath))
        let fileSize = data.count
        
        print("✅ Album art saved successfully")
        print("   Format: \(extension_)")
        print("   Size: \(fileSize) bytes")
        print("")
        print("📁 \(finalPath)")
        
        // Write JSON output if requested
        if outputJSON {
            let trackInfo: [String: Any] = [
                "name": trackName,
                "artist": artist,
                "album": album
            ]
            
            let result: [String: Any] = [
                "success": true,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "outputPath": finalPath,
                "track": trackInfo,
                "fileSize": fileSize
            ]
            
            try? FileManager.default.createDirectory(atPath: (jsonOutputPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
                try? out.write(to: URL(fileURLWithPath: jsonOutputPath))
                print("\n📄 JSON saved to: \(jsonOutputPath)")
            }
        }
    } catch {
        print("❌ Error saving artwork: \(error)")
        writeOutput(jsonOutputPath, success: false, error: "Error saving artwork: \(error)", outputJSON: outputJSON)
    }
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