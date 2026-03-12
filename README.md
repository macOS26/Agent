# Agent

A native macOS autonomous AI agent built entirely in Swift. Agent is the macOS-native competitor to [OpenClaw](https://github.com/openclaw/openclaw) — purpose-built for Apple's platform instead of bolted on as an afterthought.

Where OpenClaw is a Node.js server that you talk to through Telegram or a web interface, Agent is a real macOS app. It uses Apple's own frameworks — SwiftUI, XPC, SMAppService, ScriptingBridge — to give an AI agent deep, native access to your Mac. No Electron. No Docker. No npm install. Just a `.app` that speaks macOS.

## Why Agent over OpenClaw on Mac

| | **Agent** | **OpenClaw** |
|---|---|---|
| **Runtime** | Native Swift binary | Node.js server |
| **UI** | SwiftUI app | Web chat / Telegram / CLI |
| **Privilege escalation** | XPC + Launch Daemon (Apple's official pattern) | Shell commands via Node child_process |
| **macOS integration** | ScriptingBridge, AppleScript via osascript, SMAppService | Generic shell access |
| **Xcode automation** | Built-in: build, run, grant permissions via ScriptingBridge | Not available |
| **Swift scripting** | Full Swift Package-based agent scripts | Python/JS scripts |
| **Architecture** | Two XPC services (user + root), proper sandboxing | Single process with broad permissions |
| **Installation** | Open in Xcode, build, run | `openclaw onboard` wizard |
| **Dependencies** | Zero (ships as .app) | Node.js + npm ecosystem |
| **Apple Silicon** | Native ARM64 | Interpreted (Node.js) |

## What Agent Can Do

### Autonomous Task Execution
Give Agent a task in plain English. It figures out the commands, runs them, reads the output, adapts, and keeps going — up to 50 iterations per task. It remembers previous tasks and builds on past results.

### Dual Privilege Model
Agent runs two XPC services registered through Apple's SMAppService:

- **User Agent** (`com.agent.user`) — runs commands as your user account. Used for everyday tasks: file editing, git, Homebrew, builds, scripts.
- **Privileged Daemon** (`com.agent.helper`) — runs commands as root via a Launch Daemon. Used only when root is truly required: system packages, `/System` or `/Library` modifications, disk operations, launchd services.

The AI defaults to user-level execution and only escalates to root when necessary.

### AppleScript via osascript
Agent can execute AppleScript through `/usr/bin/osascript`, giving it control over any Mac application that supports the Open Scripting Architecture. This is how it bootstraps Xcode Automation permissions — by running an AppleScript that triggers the macOS consent dialog.

### Xcode Automation via ScriptingBridge
Agent controls Xcode directly through Apple's ScriptingBridge framework — the same Objective-C/Swift bridge that powers AppleScript, but called natively without spawning a subprocess:

- **`xcode_build`** — opens a project, triggers a build, polls until completion, and returns all errors and warnings with file paths and line numbers
- **`xcode_run`** — launches the active scheme
- **`xcode_grant_permission`** — triggers the macOS Automation consent dialog so Agent can control Xcode

The full ScriptingBridge protocol layer (`XcodeScriptingBridge.swift`) exposes Xcode's workspace documents, schemes, run destinations, build configurations, projects, and devices — all as native Swift types.

### The "agents" Swift Package
Agent includes a built-in Swift scripting system. Scripts live in `~/Documents/Agent/agents/` as a full Swift Package with `Package.swift` and per-script executable targets under `Sources/`.

The AI can create, read, update, delete, compile, and run these scripts autonomously using dedicated tools:

- `list_agent_scripts` — list all scripts
- `create_agent_script` — write a new script
- `read_agent_script` — read source code
- `update_agent_script` — modify an existing script
- `run_agent_script` — compile with `swift build` and execute
- `delete_agent_script` — remove a script

Scripts can `import Foundation`, `import AppKit`, or `import ScriptingBridge`. This means the AI can write Swift programs that automate any Scriptable Mac application — Xcode, Finder, Safari, Mail, Terminal, and hundreds of others — compile them, and run them, all within a single task.

### Vision: Screenshot and Clipboard Support
Attach screenshots or paste images directly into Agent. Images are encoded as base64 PNG and sent as vision content blocks. The AI can see what's on your screen and act on it.

- Interactive screenshot capture via `screencapture -i`
- Clipboard paste (Cmd+V) for PNG, TIFF, JPEG, or image files
- Automatic downscaling of images larger than 2048px

### Multi-Provider Support
- **Claude** (Anthropic) — Sonnet 4, Opus 4, Haiku 3.5
- **Ollama** — any model available on your Ollama instance, with automatic vision capability detection

### Task Memory
Agent persists task history to `~/Library/Application Support/Agent/task_history.json`. The last 20 tasks are injected into the system prompt, giving the AI memory across sessions. It knows what it did before and can build on it.

## Architecture

```
Agent.app (SwiftUI)
  |
  |-- AgentViewModel        Orchestrates task loop, screenshots, clipboard
  |-- ClaudeService         Anthropic Messages API
  |-- OllamaService         Ollama native API (OpenAI-compatible)
  |-- ScriptService          Swift Package manager for agent scripts
  |-- XcodeService           ScriptingBridge automation for Xcode
  |-- XcodeScriptingBridge   Full SB protocol definitions for Xcode
  |
  |-- UserService (XPC) --> com.agent.user    (LaunchAgent, runs as user)
  |-- HelperService (XPC) --> com.agent.helper (LaunchDaemon, runs as root)
```

## Requirements

- macOS 26.0+
- Xcode Command Line Tools (`xcode-select --install`)
- An Anthropic API key, or a running Ollama instance

## Getting Started

1. Open `Agent.xcodeproj` in Xcode
2. Build and run the **Agent** target
3. Click **Register** to install the user agent and privileged daemon
4. Approve in System Settings > Login Items if prompted
5. Open Settings (gear icon), add your API key
6. Type a task and hit Run

## License

MIT
