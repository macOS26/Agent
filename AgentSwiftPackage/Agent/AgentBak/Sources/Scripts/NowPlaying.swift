import Foundation
import MusicBridge

@main
struct NowPlaying {
    static func main() {
        nowPlaying()
    }
}

func nowPlaying() {
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("Could not connect to Music.app")
        return
    }

    print("Music Status")
    print("============")

    let state = music.playerState ?? .stopped
    switch state {
    case .playing:  print("State: Playing")
    case .paused:   print("State: Paused")
    case .stopped:  print("State: Stopped")
    default:        print("State: \(state)")
    }

    if let track = music.currentTrack {
        let name = track.name ?? "Unknown"
        let artist = track.artist ?? "Unknown"
        let album = track.album ?? "Unknown"
        let duration = track.duration ?? 0

        let mins = Int(duration) / 60
        let secs = Int(duration) % 60

        print("\nTrack:    \(name)")
        print("Artist:   \(artist)")
        print("Album:    \(album)")
        print("Duration: \(mins):\(String(format: "%02d", secs))")
    }

    if let vol = music.soundVolume {
        print("\nVolume:   \(vol)%")
    }
    if let pos = music.playerPosition {
        let mins = Int(pos) / 60
        let secs = Int(pos) % 60
        print("Position: \(mins):\(String(format: "%02d", secs))")
    }

    if let playlists = music.playlists?() {
        print("\nPlaylists: \(playlists.count)")
    }
}
