import Foundation
import MusicBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    guard let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("Could not connect to Music.app")
        return 1
    }
    
    // Get the current playlist (if any)
    guard let currentPlaylist = music.currentPlaylist else {
        print("❌ No playlist currently selected")
        print("ℹ️ Please select a playlist first")
        return 1
    }
    
    let playlistName = currentPlaylist.name ?? "Unknown"
    print("📁 Current playlist: \(playlistName)")
    
    // Get tracks in the playlist
    guard let tracks = currentPlaylist.tracks?() else {
        print("Could not get tracks from playlist")
        return 1
    }
    
    let trackCount = tracks.count
    print("📊 \(trackCount) tracks")
    
    if trackCount == 0 {
        print("❌ Playlist is empty!")
        return 1
    }
    
    // Pick a random track
    let randomIndex = Int.random(in: 0..<trackCount)
    print("🎲 Random track index: \(randomIndex)")
    
    guard let randomTrack = tracks.object(at: randomIndex) as? MusicTrack else {
        print("Could not get random track")
        return 1
    }
    
    let trackName = randomTrack.name ?? "Unknown"
    let artist = randomTrack.artist ?? "Unknown"
    let album = randomTrack.album ?? "Unknown"
    
    print("\n▶️ Playing random track:")
    print("   🎶 \(trackName)")
    print("   👤 \(artist)")
    print("   💿 \(album)")
    
    // Play the random track
    randomTrack.playOnce?(false)
    
    // Small delay to let playback start
    Thread.sleep(forTimeInterval: 1.0)
    
    // Confirm playback
    if let nowPlaying = music.currentTrack {
        let npName = nowPlaying.name ?? "Unknown"
        let npArtist = nowPlaying.artist ?? "Unknown"
        print("\n✅ Now playing: \(npName) - \(npArtist)")
    }
    
    return 0
}