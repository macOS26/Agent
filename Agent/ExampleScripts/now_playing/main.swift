import Foundation
import MusicBridge

// Now Playing — shows current track info from Music.app

guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
    print("Could not connect to Music.app")
    exit(1)
}

print("Music Status")
print("============")

// Player state: MusicEPlS (.stopped, .playing, .paused, .fastForwarding, .rewinding)
let state = music.playerState ?? .stopped
switch state {
case .playing:  print("State: Playing")
case .paused:   print("State: Paused")
case .stopped:  print("State: Stopped")
default:        print("State: \(state)")
}

// Current track info
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

// Volume and position
if let vol = music.soundVolume {
    print("\nVolume:   \(vol)%")
}
if let pos = music.playerPosition {
    let mins = Int(pos) / 60
    let secs = Int(pos) % 60
    print("Position: \(mins):\(String(format: "%02d", secs))")
}

// Playlist count
if let playlists = music.playlists?() {
    print("\nPlaylists: \(playlists.count)")
}
