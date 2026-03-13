# Agent!

<img width="340" height="339" alt="image" src="https://github.com/user-attachments/assets/5645d8b8-8ce7-4d56-9ede-5eb58f31f227" />

A native macOS autonomous AI agent built entirely in Swift. Agent takes a different approach than projects like [OpenClaw](https://github.com/openclaw/openclaw) — where OpenClaw is a versatile cross-platform assistant that connects to messaging apps and runs on any OS, Agent is purpose-built for macOS, leveraging Apple-native frameworks to go deeper into the platform than a cross-platform tool can.

Agent uses SwiftUI, XPC, SMAppService, Apple Events, and ScriptingBridge to give an AI agent native access to your Mac. No Electron. No Docker. No npm install. Just a `.app` that speaks macOS.

<img width="1032" height="700" alt="image" src="https://github.com/user-attachments/assets/c9dddedc-3f9a-4cfd-9f13-d556fd1c52af" />

## Agent! vs. OpenClaw on Mac

OpenClaw is a great project with broad platform reach and a rich ecosystem of messaging integrations. Agent takes a narrower but deeper approach — trading cross-platform flexibility for native macOS integration.

| | **Agent!** | **OpenClaw** |
|---|---|---|
| **Focus** | macOS-native depth | Cross-platform breadth |
| **Runtime** | Native Swift binary | Node.js server |
| **UI** | SwiftUI app | Web chat / Telegram / CLI |
| **Privilege model** | XPC + Launch Daemon (Apple's official pattern) | Shell commands |
| **macOS integration** | Apple Events, ScriptingBridge, AppleScript, SMAppService | Generic shell access |
| **Xcode automation** | Built-in: build, run, grant permissions | N/A |
| **Scripting language** | Swift Package-based agent scripts | Python/JS scripts |
| **Messaging** | Local app only | WhatsApp, Telegram, Slack, Discord, iMessage, and more |
| **Installation** | Open in Xcode, build, run | `openclaw onboard` wizard |
| **Dependencies** | Xcode Command Line Tools | Node.js + npm ecosystem |
| **Apple Silicon** | Native ARM64 | Interpreted (Node.js) |

Both tools have their strengths. If you want a personal assistant across every messaging platform, OpenClaw is excellent. If you want an AI agent that can drive Xcode, compile Swift, control Mac apps through ScriptingBridge, and escalate to root through a proper Launch Daemon — Agent is built for that.

## What Agent! Can Do

### Autonomous Task Execution
Give Agent! a task in plain English. It figures out the commands, runs them, reads the output, adapts, and keeps going — up to 50 iterations per task. It remembers previous tasks and builds on past results.

### Dual Privilege Model
Agent runs two XPC services registered through Apple's SMAppService:

- **User Agent** (`Agent.app.toddbruss.user`) — runs commands as your user account. Used for everyday tasks: file editing, git, Homebrew, builds, scripts.
- **Privileged Daemon** (`Agent.app.toddbruss.helper`) — runs commands as root via a Launch Daemon. Used only when root is truly required: system packages, `/System` or `/Library` modifications, disk operations, launchd services.

The AI defaults to user-level execution and only escalates to root when necessary.

### Xcode Command Line Tools
Agent relies on Xcode Command Line Tools (`clang`, `swiftc`, `swift build`) for compiling and running Swift agent scripts. On launch, Agent runs a system check and detects whether CLT is installed. If missing, it presents an overlay with an **Install** button that triggers `xcode-select --install` — Apple's standard installer dialog — so you can get set up without leaving the app.

### AppleScript via osascript
Agent can execute AppleScript through `/usr/bin/osascript`, giving it control over any Mac application that supports the Open Scripting Architecture. This is how it bootstraps Xcode Automation permissions — by running an AppleScript that triggers the macOS consent dialog.

### Xcode Automation via ScriptingBridge
Agent controls Xcode directly through Apple's ScriptingBridge framework — the same Objective-C/Swift bridge that powers AppleScript, but called natively without spawning a subprocess:

- **`xcode_build`** — opens a project, triggers a build, polls until completion, and returns all errors and warnings with file paths and line numbers
- **`xcode_run`** — launches the active scheme
- **`xcode_grant_permission`** — triggers the macOS Automation consent dialog so Agent can control Xcode

The full ScriptingBridge protocol layer (`XcodeScriptingBridge.swift`) exposes Xcode's workspace documents, schemes, run destinations, build configurations, projects, and devices — all as native Swift types.

### Swift Agent Scripts
Agent includes a built-in Swift scripting system. Scripts live in `~/Documents/Agent/agents/` as a Swift Package with a flat file layout:

```
~/Documents/Agent/agents/
├── Package.swift
└── Sources/
    ├── Scripts/           ← one .swift file per script
    │   ├── CheckMail.swift
    │   ├── Hello.swift
    │   ├── ListNotes.swift
    │   └── ...
    └── XCFScriptingBridges/  ← one .swift file per app bridge
        ├── ScriptingBridgeCommon.swift
        ├── MailBridge.swift
        ├── FinderBridge.swift
        ├── CalendarBridge.swift
        └── ...
```

**Package.swift** ties everything together. It declares two key arrays:

- `bridgeNames` — lists every bridge target (e.g. `"MailBridge"`, `"FinderBridge"`). Each becomes a `.target` that depends on `ScriptingBridgeCommon` and maps to a single `.swift` file in `Sources/XCFScriptingBridges/`.
- `scriptTargets` — lists every script as a `(name, [dependencies])` tuple (e.g. `("CheckMail", ["MailBridge"])`). Each becomes an `.executableTarget` mapping to a single `.swift` file in `Sources/Scripts/`.

When the AI creates a new script, it writes the `.swift` file **and** adds the corresponding entry to `scriptTargets` in Package.swift. When generating a new bridge, it writes the bridge `.swift` file and adds the name to `bridgeNames`. This keeps Package.swift in sync with the files on disk — `swift build` fails if they diverge.

The AI can create, read, update, delete, compile, and run these scripts autonomously using dedicated tools:

- `list_agent_scripts` — list all scripts
- `create_agent_script` — write a new script
- `read_agent_script` — read source code
- `update_agent_script` — modify an existing script
- `run_agent_script` — compile with `swift build --product <name>` and execute
- `delete_agent_script` — remove a script

### Dynamic Apple Event Queries

Agent includes an `apple_event_query` tool that lets the AI query any scriptable Mac app **instantly — with zero compilation**. It uses Objective-C dynamic dispatch (`value(forKey:)`, `perform(_:with:)`) to walk an app's Apple Event object graph at runtime, bypassing the need to compile Swift code entirely.

The tool takes a `bundle_id` and a chain of operations:

| Operation | Description | Example |
|-----------|-------------|---------|
| `get` | Access a property via `value(forKey:)` | `{action: "get", key: "currentTrack"}` |
| `iterate` | Read properties from each item in an array | `{action: "iterate", properties: ["name", "artist"], limit: 10}` |
| `index` | Pick one item from an array by position | `{action: "index", index: 0}` |
| `call` | Invoke a method on the current object | `{action: "call", method: "playpause"}` |
| `filter` | Apply an NSPredicate to filter an array | `{action: "filter", predicate: "name contains 'inbox'"}` |

**Examples:**
```
# What's currently playing in Music?
bundle_id: "com.apple.Music"
operations: [
  {action: "get", key: "currentTrack"},
  {action: "iterate", properties: ["name", "artist", "album"]}
]

# List Safari windows
bundle_id: "com.apple.Safari"
operations: [
  {action: "get", key: "windows"},
  {action: "iterate", properties: ["name"], limit: 10}
]

# First 5 notes
bundle_id: "com.apple.Notes"
operations: [
  {action: "get", key: "notes"},
  {action: "iterate", properties: ["name"], limit: 5}
]
```

Write operations (`delete`, `close`, `move`, `quit`, etc.) are blocked by default. The AI must explicitly set `allow_writes: true` to permit them.

Under the hood, this uses the same Apple Event interface that compiled ScriptingBridge scripts use — just accessed dynamically through `NSObject` instead of through generated Swift protocol types.

### Execution Priority

The AI selects the right scripting approach based on task complexity:

| Priority | Method | When to use |
|----------|--------|-------------|
| 1. `apple_event_query` | Zero compilation, instant ObjC dispatch | Small queries: reading app data (mail, notes, music, calendar, etc.) |
| 2. `run_agent_script` | Native Swift dylib via AgentScriptingBridge | Persistent, repeatable automation needing type-safe compiled code |
| 3. NSAppleScript in scripts | In-process AppleScript fallback | When AgentScriptingBridge has issues with a particular app |
| 4. `osascript` via user agent | Shell-based AppleScript | Last resort for one-off scripts or complex `tell` blocks |

The AI prefers `execute_user_command` for all tasks unless root privileges are truly required. When root is used, files are chown'd back to the user to avoid permission issues.

After the first compilation, SPM caches compiled modules so incremental builds only recompile changed files. The `--product` flag ensures only the target script and its bridge dependencies are built — not the entire package. Never run bare `swift build` — it compiles all 45+ bridges and is extremely slow.

### ScriptingBridges Library
Agent ships with pre-generated Swift protocol definitions for 44 macOS applications, created from each app's scripting dictionary using the [Swift-Scripting](https://github.com/SuperBox64/Swift-Scripting) toolchain. These bridge files live in `Sources/XCFScriptingBridges/` and give scripts type-safe access to:

Adobe Illustrator, Automator, Bluetooth File Exchange, Calendar, Console, Contacts, Database Events, Developer, Final Cut Pro, Finder, Firefox, Folder Actions Setup, Google Chrome, Image Events, Instruments, Keynote, Logic Pro, Mail, Messages, Microsoft Edge, Music, Notes, Numbers, Numbers (Creator Studio), Pages, Pages (Creator Studio), Photos, Pixelmator Pro, Preview, QuickTime Player, Reminders, Safari, Screen Sharing, Script Editor, Shortcuts, Simulator, System Events, System Information, System Settings, Terminal, TextEdit, TV, UTM, VoiceOver, and Xcode.

Each bridge is its own Swift module. Scripts import only what they need (e.g. `import MailBridge`), keeping builds fast and isolated. The common types (`SBObjectProtocol`, `SBApplicationProtocol`, `AEKeyword`) live in `ScriptingBridgeCommon`, which every bridge re-exports via `@_exported import`.

For compiled scripts, ScriptingBridge is the preferred approach — it calls the same Apple Event interface as AppleScript but natively from Swift, without spawning a subprocess. For quick queries, `apple_event_query` accesses the same interface dynamically with zero compilation. AppleScript via `osascript` is still available as a fallback.

To add a bridge for a new app, the AI runs the built-in `GenerateBridge` script with the app path, then adds the new bridge name to `bridgeNames` in Package.swift.

### Streaming & Markdown
Agent streams Claude's responses token-by-token in real time — no waiting for the full response. The activity log renders markdown inline: **bold**, *italic*, `inline code`, and fenced code blocks with syntax-aware background styling.

### Vision: Screenshot and Clipboard Support
Attach screenshots or paste images directly into Agent. Images are encoded as base64 PNG and sent as vision content blocks. The AI can see what's on your screen and act on it.

- Interactive screenshot capture via `screencapture -i`
- Clipboard paste (Cmd+V) for PNG, TIFF, JPEG, or image files
- Automatic downscaling of images larger than 2048px

### Multi-Provider Support
- Cloud based LLMs require a valid API key, each for Claude and Ollama Cloud
- **Claude** (Anthropic) — Sonnet 4, Opus 4, Haiku 3.5
- **Ollama** — cloud-hosted Ollama via API key, with automatic vision capability detection. Local Ollama support is coming soon.

### Task Memory
Agent persists task history to `~/Library/Application Support/Agent/task_history.json`. The last 20 tasks are injected into the system prompt, giving the AI memory across sessions. It knows what it did before and can build on it.

## Architecture

```
Agent.app (SwiftUI)
  |
  |-- AgentViewModel         Orchestrates task loop, screenshots, clipboard
  |-- ClaudeService          Anthropic Messages API
  |-- OllamaService          Ollama native API (OpenAI-compatible)
  |-- ScriptService          Swift Package manager for agent scripts
  |-- XcodeService           ScriptingBridge automation for Xcode
  |-- DependencyChecker      Xcode CLT detection + install trigger
  |
  |-- UserService (XPC) --> Agent.app.toddbruss.user    (LaunchAgent, runs as user)
  |-- HelperService (XPC) --> Agent.app.toddbruss.helper (LaunchDaemon, runs as root)

~/Documents/Agent/agents/   (Swift Package — scripts + bridges)
  |
  |-- Package.swift          Declares all bridge and script targets
  |-- Sources/Scripts/       One .swift file per executable script
  |-- Sources/XCFScriptingBridges/  One .swift file per app bridge + Common
```

## Requirements

- macOS 26.0+
- Xcode Command Line Tools (Agent will prompt to install if missing)
- An Anthropic API key, or an Ollama API key (local Ollama support coming soon)

## Getting Started

1. Open `Agent.xcodeproj` in Xcode
2. Build and run the **Agent** target
3. If prompted, install Xcode Command Line Tools via the system check overlay
4. Click **Register** to install the user agent and privileged daemon
5. Approve in System Settings > Login Items if prompted
6. Open Settings (gear icon), add your API key
7. Type a task and hit Run

## License

MIT
