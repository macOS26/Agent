import Foundation
import AppKit
import MusicBridge

// ============================================================================
// NowPlayingHTML - Generate HTML display for current track with album art
// Fetches artwork from iTunes Search API when local artwork unavailable
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    generateNowPlayingHTML()
    return 0
}

func generateNowPlayingHTML() {
    let home = NSHomeDirectory()
    let outputDir = "\(home)/Documents/AgentScript/html"
    let artworkFilename = "album_art.jpg"
    let htmlFilename = "now_playing.html"
    let artPath = "\(outputDir)/\(artworkFilename)"
    
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("Could not connect to Music")
        return
    }

    guard let track = music.currentTrack else {
        print("No track currently playing")
        return
    }

    // Get track info
    let name = track.name ?? "Unknown Track"
    let artist = track.artist ?? "Unknown Artist"
    let album = track.album ?? "Unknown Album"
    let year = track.year ?? 0
    let duration = track.duration ?? 0

    let mins = Int(duration) / 60
    let secs = Int(duration) % 60
    let durationStr = "\(mins):\(String(format: "%02d", secs))"

    print("Now Playing: \(name)")
    print("Artist: \(artist)")
    print("Album: \(album)")
    print("Year: \(year)")

    // Ensure output directory exists
    try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

    // Try to extract artwork from track
    var artworkSaved = false
    var artworkSrc = ""
    
    // First try local artwork
    if let artworks = track.artworks?(), artworks.count > 0 {
        if let artworkObj = artworks.object(at: 0) as? SBObject,
           let nsImage = artworkObj.value(forKey: "data") as? NSImage,
           let tiffData = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
            
            do {
                try jpegData.write(to: URL(fileURLWithPath: artPath))
                print("Artwork saved from Music: \(artPath) (\(jpegData.count) bytes)")
                artworkSaved = true
                artworkSrc = artworkFilename
            } catch {
                print("Error saving artwork: \(error)")
            }
        }
    }
    
    // If no local artwork, try iTunes Search API
    if !artworkSaved {
        print("No local artwork - searching iTunes API...")
        let searchTerm = "\(artist) \(album)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let iTunesURL = "https://itunes.apple.com/search?term=\(searchTerm)&media=music&entity=album&limit=1"
        
        if let url = URL(string: iTunesURL),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let results = json["results"] as? [[String: Any]],
           let firstResult = results.first,
           let artworkURL100 = firstResult["artworkUrl100"] as? String {
            
            // Get high-res artwork (replace 100x100 with larger size)
            let artworkURL = artworkURL100.replacingOccurrences(of: "100x100", with: "600x600")
            
            print("Found artwork URL: \(artworkURL)")
            
            if let artURL = URL(string: artworkURL),
               let artData = try? Data(contentsOf: artURL),
               let image = NSImage(data: artData),
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                
                do {
                    try jpegData.write(to: URL(fileURLWithPath: artPath))
                    print("Artwork saved from iTunes: \(artPath) (\(jpegData.count) bytes)")
                    artworkSaved = true
                    artworkSrc = artworkFilename
                } catch {
                    print("Error saving iTunes artwork: \(error)")
                }
            }
        }
    }

    // If still no artwork, use placeholder
    if !artworkSaved {
        print("No artwork available - using placeholder")
        let placeholderSVG = """
<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 240 240'>
  <defs>
    <linearGradient id='bg' x1='0%25' y1='0%25' x2='100%25' y2='100%25'>
      <stop offset='0%25' style='stop-color:%232a2a3e'/>
      <stop offset='100%25' style='stop-color:%231a1a2e'/>
    </linearGradient>
  </defs>
  <rect width='240' height='240' fill='url(%23bg)' rx='12'/>
  <text x='120' y='100' font-family='SF Pro Display, -apple-system, sans-serif' font-size='48' fill='%23e85d04' text-anchor='middle'>🎵</text>
  <text x='120' y='150' font-family='SF Pro Display, -apple-system, sans-serif' font-size='14' fill='rgba(255,255,255,0.4)' text-anchor='middle'>No Artwork</text>
</svg>
"""
        artworkSrc = "data:image/svg+xml,\(placeholderSVG.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? placeholderSVG)"
    }

    // Generate HTML
    let html = """
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  background: linear-gradient(135deg, #0d0d0d 0%, #1a1a2e 50%, #0d0d0d 100%);
  min-height: 100vh;
  display: flex;
  justify-content: center;
  align-items: center;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
  padding: 20px;
}
.card {
  background: linear-gradient(145deg, rgba(255,255,255,0.03), rgba(255,255,255,0.01));
  backdrop-filter: blur(40px);
  border-radius: 20px;
  padding: 20px;
  box-shadow:
    0 25px 80px -20px rgba(0,0,0,0.8),
    0 0 0 1px rgba(255,255,255,0.05),
    inset 0 1px 0 rgba(255,255,255,0.05);
  text-align: center;
  max-width: 340px;
  width: 100%;
}
.artwork-container {
  position: relative;
  display: inline-block;
  margin-bottom: 16px;
}
.artwork {
  width: 240px;
  height: 240px;
  border-radius: 12px;
  box-shadow:
    0 20px 60px rgba(0,0,0,0.5),
    0 0 0 1px rgba(255,255,255,0.1);
  object-fit: cover;
  display: block;
}
.title {
  font-size: 22px;
  font-weight: 600;
  color: #ffffff;
  margin: 0 0 4px 0;
  letter-spacing: -0.3px;
  line-height: 1.2;
}
.artist {
  font-size: 16px;
  font-weight: 400;
  color: #e85d04;
  margin: 0 0 3px 0;
}
.album {
  font-size: 13px;
  font-weight: 300;
  color: rgba(255,255,255,0.5);
  margin: 0 0 12px 0;
}
.meta {
  font-size: 11px;
  color: rgba(255,255,255,0.35);
  font-weight: 400;
  letter-spacing: 0.5px;
}
.playing-badge {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: rgba(232, 93, 4, 0.15);
  padding: 8px 14px;
  border-radius: 20px;
  margin-top: 12px;
  border: 1px solid rgba(232, 93, 4, 0.3);
}
.playing-bars {
  display: flex;
  align-items: flex-end;
  gap: 2px;
  height: 12px;
}
.bar {
  width: 3px;
  background: #e85d04;
  border-radius: 2px;
  animation: bars 0.8s ease-in-out infinite;
}
.bar:nth-child(1) { height: 60%; animation-delay: 0s; }
.bar:nth-child(2) { height: 100%; animation-delay: 0.2s; }
.bar:nth-child(3) { height: 40%; animation-delay: 0.4s; }
.bar:nth-child(4) { height: 80%; animation-delay: 0.1s; }
@keyframes bars {
  0%, 100% { transform: scaleY(1); }
  50% { transform: scaleY(0.5); }
}
.playing-text {
  color: #e85d04;
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 1.5px;
}
</style>
</head>
<body>
<div class="card">
  <div class="artwork-container">
    <img class="artwork" src="\(artworkSrc)">
  </div>
  <h1 class="title">\(name)</h1>
  <p class="artist">\(artist)</p>
  <p class="album">\(album)</p>
  <p class="meta">\(year) • \(durationStr)</p>
  <div class="playing-badge">
    <div class="playing-bars">
      <div class="bar"></div>
      <div class="bar"></div>
      <div class="bar"></div>
      <div class="bar"></div>
    </div>
    <span class="playing-text">Now Playing</span>
  </div>
</div>
</body>
</html>
"""

    let htmlPath = "\(outputDir)/\(htmlFilename)"
    do {
        try html.write(toFile: htmlPath, atomically: true, encoding: .utf8)
        print("HTML saved: \(htmlPath)")
    } catch {
        print("Error saving HTML: \(error)")
        return
    }
    
    print("")
    print("Done! Open in Safari:")
    print("   open -a Safari \(htmlPath)")
}