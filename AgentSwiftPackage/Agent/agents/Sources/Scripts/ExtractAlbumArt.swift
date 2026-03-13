import Foundation
import MusicBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    extractAlbumArt()
    return 0
}

func extractAlbumArt() {
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("Could not connect to Music.app")
        return
    }

    guard let track = music.currentTrack else {
        print("No track currently playing")
        return
    }

    let name = track.name ?? "Unknown"
    let artist = track.artist ?? "Unknown"
    let album = track.album ?? "Unknown"

    print("Now Playing: \(name) by \(artist)")
    print("Album: \(album)")
    print("")

    // Get artwork
    guard let artworks = track.artworks?() else {
        print("No artwork available")
        return
    }

    for i in 0..<artworks.count {
        guard let artwork = artworks.object(at: i) as? MusicArtwork else { continue }

        // Get raw data
        if let data = artwork.data {
            // Save to file
            let filename = "album_art_\(name.replacingOccurrences(of: "/", with: "_")).jpg"
            let filepath = "/Users/toddbruss/Music/\(filename)"
            let url = URL(fileURLWithPath: filepath)

            do {
                // Convert to raw data
                if let raw = data as? Data {
                    try raw.write(to: url)
                    print("Album art saved to: \(filepath)")
                } else {
                    // Try as TIFF
                    let tiffPath = filepath.replacingOccurrences(of: ".jpg", with: ".tiff")
                    try (data as? Data)?.write(to: URL(fileURLWithPath: tiffPath))
                    print("Album art saved as TIFF: \(tiffPath)")
                }
            } catch {
                print("Error saving artwork: \(error)")
            }
        } else {
            print("Artwork found but no data available")
        }
    }
}