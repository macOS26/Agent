import Foundation
import AppKit
import MusicBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    generateNowPlayingHTML()
    return 0
}

func generateNowPlayingHTML() {
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

    // Extract album artwork
    var artworkSaved = false
    if let artworks = track.artworks?(), artworks.count > 0 {
        guard let artworkObj = artworks.object(at: 0) as? SBObject else {
            print("Could not get artwork object")
            return
        }

        if let nsImage = artworkObj.value(forKey: "data") as? NSImage {
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let jpegData = bitmap.representation(using: .jpeg, properties: [:]) else {
                print("Could not convert artwork to JPEG")
                return
            }

            let artPath = NSString("~/Music/album_art.jpg").expandingTildeInPath
            try? jpegData.write(to: URL(fileURLWithPath: artPath))
            print("Artwork saved: \(artPath) (\(jpegData.count) bytes)")
            artworkSaved = true
        }
    }

    if !artworkSaved {
        print("No artwork available")
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
    <img class="artwork" src="album_art.jpg">
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

    let htmlPath = NSString("~/Music/now_playing.html").expandingTildeInPath
    try? html.write(toFile: htmlPath, atomically: true, encoding: .utf8)
    print("HTML saved: \(htmlPath)")
    print("")
    print("Done! Open in Safari:")
    print("   open -a Safari ~/Music/now_playing.html")
}