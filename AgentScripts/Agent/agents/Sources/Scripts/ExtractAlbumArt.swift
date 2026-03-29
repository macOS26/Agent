import Foundation
import MusicBridge
import AppKit

// ============================================================================
// ExtractAlbumArt - Extract album artwork from current track in Music.app
// Falls back to iTunes Search API for URL tracks without local artwork
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "param1=value1,param2=value2"
//     Parameters:
//       - output=/path/to/file.jpg (output path, default: ~/Documents/AgentScript/images/)
//       - format=jpg|png|tiff (output format, default: jpg)
//       - json=true (output to JSON file)
//     Example: "output=~/Desktop/cover.jpg,format=jpg,json=true"
//
//   Option 2: JSON input file at ~/Documents/AgentScript/json/ExtractAlbumArt_input.json
//     {
//       "output": "~/Desktop/cover.jpg",
//       "format": "jpg",
//       "json": true
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/ExtractAlbumArt_output.json
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
    let inputPath = "\(home)/Documents/AgentScript/json/ExtractAlbumArt_input.json"
    let jsonOutputPath = "\(home)/Documents/AgentScript/json/ExtractAlbumArt_output.json"
    
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
    
    // Set default output path if not specified
    let sanitizedTrack = trackName.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "-")
    let imagesDir = "\(home)/Documents/AgentScript/images"
    try? FileManager.default.createDirectory(atPath: imagesDir, withIntermediateDirectories: true)
    
    let extension_: String
    switch format {
    case "png": extension_ = "png"
    case "tiff", "tif": extension_ = "tiff"
    default: extension_ = "jpg"
    }
    
    let finalPath = outputPath ?? "\(imagesDir)/\(sanitizedTrack).\(extension_)"
    let dir = (finalPath as NSString).deletingLastPathComponent
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    
    var artworkSaved = false
    
    // Method 1: Try to get artwork from ScriptingBridge (local tracks)
    if let artworks = track.artworks?(), artworks.count > 0 {
        print("📷 Found \(artworks.count) artwork(s) via ScriptingBridge...")
        
        for i in 0..<artworks.count {
            guard let artwork = artworks.object(at: i) as? SBObject else { continue }
            
            // Try to get NSImage data
            if let nsImage = artwork.value(forKey: "data") as? NSImage {
                print("   Found NSImage: \(Int(nsImage.size.width))x\(Int(nsImage.size.height))")
                
                if let tiffData = nsImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData) {
                    
                    let imageData: Data?
                    switch extension_ {
                    case "png":
                        imageData = bitmap.representation(using: .png, properties: [:])
                    case "tiff":
                        imageData = bitmap.representation(using: .tiff, properties: [:])
                    default:
                        imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
                    }
                    
                    if let data = imageData {
                        do {
                            try data.write(to: URL(fileURLWithPath: finalPath))
                            let fileSize = data.count
                            print("   ✅ Saved from ScriptingBridge: \(fileSize) bytes")
                            artworkSaved = true
                            break
                        } catch {
                            print("   ❌ Error saving: \(error)")
                        }
                    }
                }
            }
            
            // Try raw data
            if let raw = artwork.value(forKey: "data") as? Data {
                do {
                    try raw.write(to: URL(fileURLWithPath: finalPath))
                    print("   ✅ Saved raw data: \(raw.count) bytes")
                    artworkSaved = true
                    break
                } catch {
                    print("   ❌ Error saving raw data: \(error)")
                }
            }
        }
    }
    
    // Method 2: Fallback to iTunes Search API (for URL/Apple Music tracks)
    if !artworkSaved {
        print("📱 No local artwork - searching iTunes API...")
        
        let searchTerm = "\(artist) \(album)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let iTunesURL = "https://itunes.apple.com/search?term=\(searchTerm)&media=music&entity=album&limit=5"
        
        if let url = URL(string: iTunesURL),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let results = json["results"] as? [[String: Any]] {
            
            // Find best matching album
            for result in results {
                if let artworkURL100 = result["artworkUrl100"] as? String {
                    // Get high-res artwork (replace 100x100 with larger size)
                    let artworkURL = artworkURL100.replacingOccurrences(of: "100x100", with: "600x600")
                    print("   Found: \(artworkURL)")
                    
                    if let artURL = URL(string: artworkURL),
                       let artData = try? Data(contentsOf: artURL) {
                        do {
                            try artData.write(to: URL(fileURLWithPath: finalPath))
                            print("   ✅ Saved from iTunes: \(artData.count) bytes")
                            artworkSaved = true
                            break
                        } catch {
                            print("   ❌ Error saving iTunes artwork: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    if !artworkSaved {
        print("❌ Could not extract artwork from any source")
        writeOutput(jsonOutputPath, success: false, error: "Could not extract artwork", outputJSON: outputJSON)
        return
    }
    
    // Get file size
    let fileSize = (try? FileManager.default.attributesOfItem(atPath: finalPath)[.size] as? Int) ?? 0
    
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