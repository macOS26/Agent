import Foundation
import MusicBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    whatsPlaying()
    return 0
}

func whatsPlaying() {
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("❌ Could not connect to Music.app")
        return
    }
    
    let state = music.playerState ?? .stopped
    
    // Print header with state
    print("🎵 What's Playing")
    print("═══════════════════════════════════════")
    
    switch state {
    case .playing:
        print("Status: ▶️ Playing")
    case .paused:
        print("Status: ⏸️ Paused")
    case .stopped:
        print("Status: ⏹️ Stopped")
    case .fastForwarding:
        print("Status: ⏩ Fast Forwarding")
    case .rewinding:
        print("Status: ⏪ Rewinding")
    default:
        print("Status: Unknown")
    }
    
    // Show track info if available
    if let track = music.currentTrack {
        print("\n📀 Now Playing:")
        print("   Track:  \(track.name ?? "Unknown")")
        print("   Artist: \(track.artist ?? "Unknown")")
        print("   Album:  \(track.album ?? "Unknown")")
        
        if let year = track.year, year > 0 {
            print("   Year:   \(year)")
        }
        
        if let genre = track.genre, !genre.isEmpty {
            print("   Genre:  \(genre)")
        }
        
        // Duration
        if let duration = track.duration {
            let mins = Int(duration) / 60
            let secs = Int(duration) % 60
            print("   Duration: \(mins):\(String(format: "%02d", secs))")
        }
        
        // Track number
        if let trackNum = track.trackNumber, trackNum > 0 {
            var trackInfo = "   Track #: \(trackNum)"
            if let trackCount = track.trackCount, trackCount > 0 {
                trackInfo += " of \(trackCount)"
            }
            print(trackInfo)
        }
        
        // Rating
        if let rating = track.rating, rating > 0 {
            let stars = rating / 20
            let starString = String(repeating: "⭐", count: stars)
            print("   Rating: \(starString) (\(rating)/100)")
        }
        
        // Play count
        if let playCount = track.playedCount, playCount > 0 {
            print("   Plays: \(playCount)")
        }
    } else {
        print("\n⚠️ No track currently selected")
    }
    
    // Player position
    if let pos = music.playerPosition, let duration = music.currentTrack?.duration {
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
    }
    
    // Volume
    if let vol = music.soundVolume {
        let volBars = Int(Double(vol) / 100.0 * 10.0)
        let volBar = String(repeating: "🔊", count: volBars)
        print("\n🔈 Volume: \(vol)% \(volBar)")
    }
    
    // Shuffle/Repeat status
    var extras: [String] = []
    if music.shuffleEnabled == true {
        extras.append("Shuffle 🔀")
    }
    if let repeatMode = music.songRepeat {
        switch repeatMode {
        case .one:
            extras.append("Repeat One 🔁")
        case .all:
            extras.append("Repeat All 🔁")
        default:
            break
        }
    }
    if !extras.isEmpty {
        print("   " + extras.joined(separator: " | "))
    }
    
    print("═══════════════════════════════════════")
}