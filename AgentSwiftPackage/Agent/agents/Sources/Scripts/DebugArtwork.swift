import Foundation
import MusicBridge
import AppKit

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("Could not connect to Music.app")
        return 1
    }

    guard let track = music.currentTrack else {
        print("No track")
        return 0
    }

    print("Track: \(track.name ?? "?")")
    print("Artist: \(track.artist ?? "?")")
    
    // Check artworks
    if let artworks = track.artworks?() {
        print("Artworks count: \(artworks.count)")
        
        for i in 0..<artworks.count {
            if let art = artworks.object(at: i) as? MusicArtwork {
                print("Artwork \(i):")
                print("  Description: \(art.objectDescription ?? "none")")
                print("  Kind: \(art.kind ?? -1)")
                print("  Downloaded: \(art.downloaded ?? false)")
                print("  Format: \(art.format ?? -1)")
                
                if let image = art.data {
                    print("  Image size: \(image.size)")
                    if let tiffData = image.tiffRepresentation {
                        print("  TIFF data size: \(tiffData.count) bytes")
                    }
                }
                
                // Try rawData
                if let rawData = art.rawData {
                    print("  Raw data type: \(type(of: rawData))")
                }
            }
        }
    } else {
        print("No artworks() method returned")
    }
    
    return 0
}