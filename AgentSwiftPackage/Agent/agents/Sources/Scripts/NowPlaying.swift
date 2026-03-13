import Foundation
import MusicBridge
import AppKit

@_cdecl("script_main")
public func script_main() -> Int32 {
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("Could not connect to Music.app")
        return 1
    }

    let state = music.playerState ?? .stopped
    if state != .playing {
        print("Nothing playing")
        return 0
    }

    guard let track = music.currentTrack else {
        print("No track")
        return 0
    }

    let name = track.name ?? "Unknown"
    let artist = track.artist ?? "Unknown"
    let album = track.album ?? "Unknown"
    
    print("🎵 \(name)")
    print("👤 \(artist)")
    print("💿 \(album)")

    // Extract album art using the correct approach from backup scripts
    if let artworks = track.artworks?(), artworks.count > 0 {
        let artworkObj = artworks.object(at: 0)
        guard let sbArtwork = artworkObj as? SBObject else {
            print("Could not get artwork object")
            return 0
        }
        
        // Get the NSImage via value(forKey:)
        if let nsImage = sbArtwork.value(forKey: "data") as? NSImage {
            print("📷 Artwork size: \(Int(nsImage.size.width))x\(Int(nsImage.size.height))")
            
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                print("Could not convert to PNG")
                return 0
            }
            
            let path = "/Users/toddbruss/Music/now_playing.png"
            try? pngData.write(to: URL(fileURLWithPath: path))
            print("✅ Saved: \(path)")
            print("/Users/toddbruss/Music/now_playing.png")
        } else {
            print("No artwork data available")
        }
    } else {
        print("No artworks found for this track")
    }
    
    return 0
}