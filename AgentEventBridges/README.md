# AgentEventBridges

ScriptingBridge protocol definitions for 50+ macOS applications. Use Swift to automate Finder, Safari, Music, Mail, Messages, Xcode, and more — no AppleScript required.

## Supported Apps

Calendar, Contacts, Finder, Mail, Messages, Music, Notes, Numbers, Pages, Photos, Reminders, Safari, Terminal, TextEdit, Xcode, Preview, Keynote, Shortcuts, System Events, System Settings, Script Editor, QuickTime Player, Screen Sharing, TV, VoiceOver, Image Events, Database Events, Adobe Illustrator, Automator, Final Cut Pro, Logic Pro, Google Chrome, Firefox, Microsoft Edge, Pixelmator Pro, Simulator, UTM, and more.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/macOS26/AgentEventBridges.git", from: "1.0.0"),
]
```

```swift
.target(name: "YourApp", dependencies: [
    .product(name: "AgentEventBridges", package: "AgentEventBridges"),
]),
```

## Usage

```swift
import AgentEventBridges
import ScriptingBridge

// Control Music
if let music: MusicApplication = SBApplication(bundleIdentifier: "com.apple.Music") {
    music.playpause?()
    print(music.currentTrack?.name ?? "Nothing playing")
}

// Automate Finder
if let finder: FinderApplication = SBApplication(bundleIdentifier: "com.apple.finder") {
    let desktop = finder.desktop
    print("Desktop items: \(desktop?.files?().count ?? 0)")
}

// Safari JavaScript
if let safari: SafariApplication = SBApplication(bundleIdentifier: "com.apple.Safari") {
    safari.doJavaScript?("document.title", in: safari.windows?().first?.currentTab)
}
```

## Requirements

- macOS 26+ / Swift 6.2
- Apps must have AppleScript/Automation support enabled

## License

MIT
