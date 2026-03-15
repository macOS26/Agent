# Agent!

[![Swift 6.1](https://img.shields.io/badge/Swift-6.1-orange.svg)](https://swift.org)
[![Website](https://img.shields.io/badge/website-xcf.ai-blue.svg)](https://xcf.ai)
[![Version](https://img.shields.io/badge/version-1.0.5-green.svg)](https://github.com/macOS26/Agent)
[![GitHub downloads](https://img.shields.io/github/downloads/macOS26/Agent/total.svg)](https://github.com/codefreezeai/xcf/releases)
[![GitHub stars](https://img.shields.io/github/stars/macOS26/Agent.svg?style=social)](https://github.com/codefreezeai/xcf/stargazers)

Agentic AI for your entire  Mac Desktop

<img width="340" height="339" alt="Agent! icon" src="https://github.com/user-attachments/assets/5645d8b8-8ce7-4d56-9ede-5eb58f31f227" />

A native macOS autonomous AI agent built entirely in Swift. Agent takes a different approach than projects like [OpenClaw](https://github.com/openclaw/openclaw) — where OpenClaw is a versatile cross-platform assistant that connects to messaging apps and runs on any OS, Agent is purpose-built for macOS, leveraging Apple-native frameworks to go deeper into the platform than a cross-platform tool can.

Agent uses SwiftUI, XPC, SMAppService, Apple Events, and ScriptingBridge to give an AI agent native access to your Mac. No Electron. No Docker. No npm install. Just a `.app` that speaks macOS. Xcode command line tools are required.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Security Hardening](#security-hardening)
- [MCP Servers](#mcp-servers)
- [Architecture](#architecture)
- [What Agent! Can Do](#what-agent-can-do)
- [Requirements](#requirements)
- [Agent! vs. OpenClaw on Mac](#agent-vs-openclaw-on-mac)
- [License](#license)

---

## Getting Started

### 1. Prerequisites

- macOS 26 (Tahoe) or later
- Xcode Command Line Tools (Agent will prompt to install if missing)
- An API key for one of the supported providers:
  - **Claude** (Anthropic API key)
  - **Ollama Pro Cloud** (Ollama API key)
  - **Local Ollama** (no API key required, but requires significant RAM)

### 2. Build and Run

1. Open `Agent.xcodeproj` in Xcode
2. Build and run the **Agent!** target (⌘R)
3. If prompted, install Xcode Command Line Tools via the system check overlay

### 3. Register Background Services

Click the **Register** button in the toolbar to install the background services:

This registers two background services using Apple's SMAppService framework:

1. **User Agent** (`Agent.app.toddbruss.user`) — Runs commands as your user account
2. **Privileged Daemon** (`Agent.app.toddbruss.helper`) — Runs commands as root when needed

### 4. Approve in System Settings

After clicking Register, macOS will prompt you to approve the background services:

1. **System Settings** → **General** → **Login Items**
2. Allow both **Agent** and **AgentHelper** (you may see two prompts)

The privileged daemon requires explicit approval because it runs as root. Agent follows Apple's recommended XPC + SMAppService pattern for secure privilege escalation.

### 5. Configure Your Provider

Click the **gear icon** (⚙️) to open Settings:

#### Claude API
1. Select **Claude** from the provider picker
2. Enter your Anthropic API key (starts with `sk-ant-...`)
3. Select a model (Sonnet 4, Opus 4, or Haiku 3.5)

#### Ollama Pro Cloud
1. Select **Ollama Cloud** from the provider picker
2. Enter your Ollama Pro API key
3. Select or type a model name
4. Click the refresh button to fetch available models

#### Local Ollama
1. Select **Local Ollama** from the provider picker
2. Enter your Ollama endpoint (default: `http://localhost:11434/api/chat`)
3. Ensure you have a local Ollama instance running with at least one model pulled
4. Click the refresh button to fetch available models

> **Note:** Local Ollama requires significant RAM (minimum 32GB, recommended 64-128GB). For Mac minis or devices with limited RAM, cloud-based LLMs are strongly recommended.

### 6. Connect and Run

1. Click **Connect** to test the XPC services
2. Type a task in natural language
3. Press **Run** (or ⌘Enter)

Agent will autonomously execute your task using the appropriate tools.

---

## Security Hardening

Agent! implements a comprehensive security model based on Apple's recommended patterns:

### Dual Privilege Model

Agent runs two XPC services registered through Apple's SMAppService:

| Service | Identifier | Runs As | Purpose |
|---------|------------|---------|---------|
| **User Agent** | `Agent.app.toddbruss.user` | User account | File editing, git, builds, scripts |
| **Privileged Daemon** | `Agent.app.toddbruss.helper` | Root (via LaunchDaemon) | System packages, /Library, launchd, disk operations |

The AI defaults to **user-level execution** and only escalates to root when necessary. This prevents accidental system damage and follows the principle of least privilege.

### XPC Sandboxing

All privileged operations go through XPC (Inter-Process Communication):

```
Agent.app (SwiftUI)
    |
    |-- UserService (XPC) → Agent.app.toddbruss.user    (LaunchAgent, runs as user)
    |-- HelperService (XPC) → Agent.app.toddbruss.helper  (LaunchDaemon, runs as root)
```

The XPC boundary ensures:
- The main app runs with minimal privileges
- Root operations are isolated to the daemon
- Each XPC call is a discrete, auditable transaction
- File permissions are restored to the user after root operations

### Entitlements

Agent uses minimal entitlements:

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
<key>com.apple.security.automation.apple-events</key>
<true/>
```

- **App Sandbox**: Disabled (required for system automation)
- **Apple Events**: Enabled (required for AppleScript and ScriptingBridge)

### TCC Permissions (Accessibility, Screen Recording, Automation)

Protected macOS APIs require user approval. Agent handles this correctly:

| Component | How it inherits TCC permissions |
|-----------|--------------------------------|
| `run_agent_script` (dylib) | Loaded into Agent app process — inherits ALL TCC grants |
| `apple_event_query` | Runs in Agent app process — inherits Automation permissions |
| `execute_user_command` | Child process — does NOT inherit TCC grants |
| `execute_command` (root) | LaunchDaemon process — has separate TCC context |

**Rule:** For Accessibility, Screen Recording, or Automation tasks, always use `run_agent_script` or `apple_event_query`. Do NOT use shell commands for these operations.

### Write Protection

- `apple_event_query` blocks destructive operations (`delete`, `close`, `move`, `quit`) by default
- The AI must explicitly set `allow_writes: true` to permit them
- This prevents accidental data loss from misinterpreted commands

### Root Escalation Audit Trail

When Agent executes commands as root, it logs:
- The exact command executed
- The reason for escalation
- The result

This provides a clear audit trail of privileged operations.

---

## MCP Servers

Agent! supports **MCP (Model Context Protocol)** servers, allowing you to extend its capabilities with custom tools and resources.

### What is MCP?

MCP is an open protocol that lets AI models interact with external tools, APIs, and data sources. Agent acts as an MCP **client**, connecting to MCP servers that expose tools and resources.

### Adding MCP Servers

1. Click the **server icon** ( Rack) in the toolbar
2. Click the **+** button to add a new server
3. Configure the server:

| Field | Description | Example |
|-------|-------------|---------|
| **Name** | Display name for the server | `HelloWorld` |
| **Command** | Executable path | `/usr/local/bin/node` |
| **Arguments** | Command-line arguments | `mcp-server-hello/dist/index.js` |
| **Environment** | Environment variables | `API_KEY=xxx` |
| **Auto-start** | Connect on launch | ✓ |

### Example MCP Server Configurations

#### HelloWorld MCP Server
```json
{
  "name": "HelloWorld",
  "command": "/usr/local/bin/node",
  "arguments": ["/path/to/mcp-server-hello/dist/index.js"],
  "enabled": true,
  "autoStart": true
}
```

#### XCF (Xcode Features) Server
```json
{
  "name": "xcf",
  "command": "/usr/local/bin/node",
  "arguments": ["/path/to/xcf-server/dist/index.js"],
  "enabled": true,
  "autoStart": true
}
```

### Importing Server Configurations

You can import server configurations as JSON:

1. Click the **download icon** in the MCP Servers view
2. Paste your JSON configuration
3. Click **Import**

### How MCP Tools Work

When connected to an MCP server, Agent:

1. Discovers available tools from the server
2. Adds tools to its tool registry
3. Uses them autonomously based on user requests
4. Returns results through the same MCP protocol

### Transport

Currently supported:
- **stdio** — Standard input/output pipes (most common)

Coming soon:
- **HTTP/SSE** — Server-Sent Events over HTTP

### Tool Management

- Enable/disable individual tools per server
- View tool descriptions and input schemas
- See connection status and errors in real-time

---

## Architecture

```
Agent.app (SwiftUI)
  |
  |-- AgentViewModel         Orchestrates task loop, screenshots, clipboard
  |-- ClaudeService          Anthropic Messages API (streaming)
  |-- OllamaService          Ollama native API (OpenAI-compatible)
  |-- MCPService             MCP client for external tool servers
  |-- ScriptService          Swift Package manager for agent scripts
  |-- XcodeService           ScriptingBridge automation for Xcode
  |-- AppleEventService      Dynamic Apple Event queries (zero compilation)
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

---

## What Agent! Can Do

### Autonomous Task Execution

Give Agent! a task in plain English. It figures out the commands, runs them, reads the output, adapts, and keeps going — up to 50 iterations per task. It remembers previous tasks and builds on past results.

### AppleScript via osascript

Agent runs `osascript` commands directly in the app process — not through XPC helpers — so they automatically inherit the app's macOS Automation permissions. This means AppleScript "just works" for controlling any Mac application that supports the Open Scripting Architecture.

### Xcode Automation via ScriptingBridge

Agent controls Xcode directly through Apple's ScriptingBridge framework:

- **`xcode_build`** — opens a project, triggers a build, polls until completion, returns all errors and warnings
- **`xcode_run`** — launches the active scheme
- **`xcode_grant_permission`** — triggers the macOS Automation consent dialog

### Swift Agent Scripts

Agent includes a built-in Swift scripting system. Scripts live in `~/Documents/Agent/agents/` as a Swift Package:

```
~/Documents/Agent/agents/
├── Package.swift
└── Sources/
    ├── Scripts/           ← one .swift file per script
    │   ├── CheckMail.swift
    │   ├── Hello.swift
    │   └── ...
    └── XCFScriptingBridges/  ← one .swift file per app bridge
        ├── ScriptingBridgeCommon.swift
        ├── MailBridge.swift
        └── ...
```

The AI can create, read, update, delete, compile, and run these scripts autonomously:

- `list_agent_scripts` — list all scripts
- `create_agent_script` — write a new script
- `read_agent_script` — read source code
- `update_agent_script` — modify an existing script
- `run_agent_script` — compile with `swift build --product <name>` and execute
- `delete_agent_script` — remove a script

### Dynamic Apple Event Queries

Agent includes an `apple_event_query` tool that lets the AI query any scriptable Mac app **instantly — with zero compilation**. It uses Objective-C dynamic dispatch to walk an app's Apple Event object graph at runtime.

| Operation | Description | Example |
|-----------|-------------|---------|
| `get` | Access a property | `{action: "get", key: "currentTrack"}` |
| `iterate` | Read properties from array items | `{action: "iterate", properties: ["name", "artist"], limit: 10}` |
| `index` | Pick one item from array | `{action: "index", index: 0}` |
| `call` | Invoke a method | `{action: "call", method: "playpause"}` |
| `filter` | NSPredicate filter | `{action: "filter", predicate: "name contains 'inbox'"}` |

### ScriptingBridges Library

Agent ships with pre-generated Swift protocol definitions for 44+ macOS applications:

Adobe Illustrator, Automator, Calendar, Contacts, Finder, Firefox, Google Chrome, Mail, Messages, Music, Notes, Numbers, Pages, Photos, Preview, QuickTime Player, Reminders, Safari, Shortcuts, System Events, Terminal, TV, Xcode, and more.

Each bridge is its own Swift module. Scripts import only what they need (e.g. `import MailBridge`), keeping builds fast and isolated.

### Streaming & Markdown

Agent streams responses token-by-token in real time. The activity log renders markdown inline: **bold**, *italic*, `inline code`, and fenced code blocks with syntax highlighting.

### Vision: Screenshot and Clipboard Support

Attach screenshots or paste images directly into Agent. Images are encoded as base64 PNG and sent as vision content blocks. The AI can see what's on your screen and act on it.

### Multi-Provider Support

| Provider | API Key Required | Vision Support | Notes |
|----------|------------------|----------------|-------|
| **Claude** | Yes (Anthropic) | ✓ | Sonnet 4, Opus 4, Haiku 3.5 |
| **Ollama Cloud** | Yes (Ollama Pro) | Auto-detected | Cloud-hosted Ollama |
| **Local Ollama** | No | Auto-detected | Requires 32-128GB RAM |

### Task Memory

Agent persists task history to `~/Library/Application Support/Agent/task_history.json`. The last 20 tasks are injected into the system prompt, giving the AI memory across sessions.

---

## Requirements

- **macOS 26.0+** (Tahoe)
- **Xcode Command Line Tools** (Agent will prompt to install if missing)
- **API Key** for Claude or Ollama Cloud, OR a local Ollama instance
- **Apple Silicon** recommended for local Ollama (minimum 32GB RAM, 64-128GB recommended)

> **Important:** We are not responsible for token costs incurred via Claude or Ollama Cloud. Monitor your usage.

---

## Agent! vs. OpenClaw on Mac

| | **Agent!** | **OpenClaw** |
|---|---|---|
| **Focus** | macOS-native depth | Cross-platform breadth |
| **Runtime** | Native Swift binary | Node.js server |
| **UI** | SwiftUI app | Web chat / Telegram / CLI |
| **Privilege model** | XPC + Launch Daemon (Apple's official pattern) | Shell commands |
| **macOS integration** | Apple Events, ScriptingBridge, AppleScript, SMAppService | Generic shell access |
| **Xcode automation** | Built-in: build, run, grant permissions | N/A |
| **Scripting language** | Swift Package-based agent scripts | Python/JS scripts |
| **MCP support** | Yes (stdio transport) | Yes |
| **Messaging** | Local app only | WhatsApp, Telegram, Slack, Discord, iMessage, and more |
| **Installation** | Open in Xcode, build, run | `openclaw onboard` wizard |
| **Dependencies** | Xcode Command Line Tools | Node.js + npm ecosystem |
| **Apple Silicon** | Native ARM64 | Interpreted (Node.js) |

Both tools have their strengths. If you want a personal assistant across every messaging platform, OpenClaw is excellent. If you want an AI agent that can drive Xcode, compile Swift, control Mac apps through ScriptingBridge, and escalate to root through a proper Launch Daemon — Agent is built for that.

---

## License

MIT
