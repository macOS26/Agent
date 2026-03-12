# Agent

A native macOS autonomous AI agent built entirely in Swift. Agent takes a different approach than projects like [OpenClaw](https://github.com/openclaw/openclaw) — where OpenClaw is a versatile cross-platform assistant that connects to messaging apps and runs on any OS, Agent is purpose-built for macOS, leveraging Apple-native frameworks to go deeper into the platform than a cross-platform tool can.

Agent uses SwiftUI, XPC, SMAppService, and ScriptingBridge to give an AI agent native access to your Mac. No Electron. No Docker. No npm install. Just a `.app` that speaks macOS.

## Agent vs. OpenClaw on Mac

OpenClaw is a great project with broad platform reach and a rich ecosystem of messaging integrations. Agent takes a narrower but deeper approach — trading cross-platform flexibility for native macOS integration.

| | **Agent** | **OpenClaw** |
|---|---|---|
| **Focus** | macOS-native depth | Cross-platform breadth |
| **Runtime** | Native Swift binary | Node.js server |
| **UI** | SwiftUI app | Web chat / Telegram / CLI |
| **Privilege model** | XPC + Launch Daemon (Apple's official pattern) | Shell commands |
| **macOS integration** | ScriptingBridge, AppleScript, SMAppService | Generic shell access |
| **Xcode automation** | Built-in: build, run, grant permissions | N/A |
| **Scripting language** | Swift Package-based agent scripts | Python/JS scripts |
| **Messaging** | Local app only | WhatsApp, Telegram, Slack, Discord, iMessage, and more |
| **Installation** | Open in Xcode, build, run | `openclaw onboard` wizard |
| **Dependencies** | Xcode Command Line Tools | Node.js + npm ecosystem |
| **Apple Silicon** | Native ARM64 | Interpreted (Node.js) |

Both tools have their strengths. If you want a personal assistant across every messaging platform, OpenClaw is excellent. If you want an AI agent that can drive Xcode, compile Swift, control Mac apps through ScriptingBridge, and escalate to root through a proper Launch Daemon — Agent is built for that.

## What Agent Can Do

### Autonomous Task Execution
Give Agent a task in plain English. It figures out the commands, runs them, reads the output, adapts, and keeps going — up to 50 iterations per task. It remembers previous tasks and builds on past results.

### Dual Privilege Model
Agent runs two XPC services registered through Apple's SMAppService:

- **User Agent** (`com.agent.user`) — runs commands as your user account. Used for everyday tasks: file editing, git, Homebrew, builds, scripts.
- **Privileged Daemon** (`com.agent.helper`) — runs commands as root via a Launch Daemon. Used only when root is truly required: system packages, `/System` or `/Library` modifications, disk operations, launchd services.

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
Agent includes a built-in Swift scripting system. Scripts live in `~/Documents/Agent/agents/` as a Swift Package with per-script executable targets under `Sources/`.

The AI can create, read, update, delete, compile, and run these scripts autonomously using dedicated tools:

- `list_agent_scripts` — list all scripts
- `create_agent_script` — write a new script
- `read_agent_script` — read source code
- `update_agent_script` — modify an existing script
- `run_agent_script` — compile with `swift build` and execute
- `delete_agent_script` — remove a script

### ScriptingBridges Library
Agent ships with a bundled `ScriptingBridges` library — pre-generated Swift protocol definitions for 19 macOS applications, created from each app's scripting dictionary using the [Swift-Scripting](https://github.com/SuperBox64/Swift-Scripting) toolchain. On first launch, these are installed to the agents Swift Package so any script can `import ScriptingBridges` and get type-safe access to:

Automator, Calendar, Contacts, Finder, Image Events, Mail, Messages, Music, Notes, Numbers, Pages, Photos, Reminders, Script Editor, Shortcuts, System Events, Terminal, TV, and Xcode.

ScriptingBridge is the preferred approach for app automation — it calls the same Apple Event interface as AppleScript but natively from Swift, without spawning a subprocess. AppleScript via `osascript` is still available as a fallback.

This means the AI can write Swift programs that automate Mac applications, compile them with `swift build`, and run them — all within a single task.

### Vision: Screenshot and Clipboard Support
Attach screenshots or paste images directly into Agent. Images are encoded as base64 PNG and sent as vision content blocks. The AI can see what's on your screen and act on it.

- Interactive screenshot capture via `screencapture -i`
- Clipboard paste (Cmd+V) for PNG, TIFF, JPEG, or image files
- Automatic downscaling of images larger than 2048px

### Multi-Provider Support
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
  |-- XcodeScriptingBridge   Full SB protocol definitions for Xcode
  |-- ScriptingBridges/      Bundled bridge protocols for 19 macOS apps
  |-- DependencyChecker      Xcode CLT detection + install trigger
  |
  |-- UserService (XPC) --> com.agent.user    (LaunchAgent, runs as user)
  |-- HelperService (XPC) --> com.agent.helper (LaunchDaemon, runs as root)
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
