# 🦾 Agent! 1.0.64 for macOS
# 🕵🏻‍♂️ the Autonomous AI Assistant 

<div align="center">

![Agent!](https://img.shields.io/badge/Agent!-v1.0-blue?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-macOS%2026%2B-cyan?style=for-the-badge)
![Swift](https://img.shields.io/badge/Swift-6.2-orange?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**Your AI-powered coding partner that actually understands macOS.**

[Features](#features) • [Installation](#installation) • [Comparison](#comparison) • [Architecture](#architecture) • [Security](#security)

</div>

<img width="1322" height="773" alt="Screenshot 2026-03-28 at 1 30 40 AM" src="https://github.com/user-attachments/assets/d81da01a-fa22-4cae-8cc5-6a67b5b49778" />

---

## The Problem

You're a developer on macOS. You want AI assistance that:
- **Actually controls your apps** — not just generates text
- **Builds your Xcode projects** — not just reads files
- **Runs native scripts** — Swift, AppleScript, JavaScript
- **Respects your privacy** — runs locally when you want
- **Uses your preferred LLM** — Claude, OpenAI, DeepSeek, local models

**Every other AI tool fails at this.** They're terminal-focused, web-first, or Windows-centric. They don't understand Apple's ecosystem.

---

## The Solution: Agent!

Agent! is a **native macOS SwiftUI application** designed from the ground up for Apple's ecosystem. It's not a terminal wrapper. It's not an Electron app. It's a first-class macOS citizen.

### What Makes Agent! Different

| Capability | Agent! | Claude Code | Cursor | Cline | OpenClaw |
|------------|:-------|:------------|:------|:-----|:---------|
| **Native macOS App** | ✅ SwiftUI | ❌ Terminal CLI | ❌ Electron | ❌ VS Code Ext | ✅ Electron |
| **Xcode Build/Run** | ✅ Full project | ❌ File edits | ⚠️ Via Sweetpad | ❌ | ❌ |
| **AgentScript (Swift)** | ✅ Compiled dylibs | ❌ | ❌ | ❌ | ❌ |
| **AppleScript/JXA** | ✅ Built-in | ⚠️ Via MCP* | ❌ | ❌ | ❌ |
| **Accessibility API** | ✅ Full control | ❌ | ❌ | ❌ | ❌ |
| **MCP Protocol** | ✅ Stdio + SSE | ✅ Stdio + SSE | ✅ Stdio + SSE | ✅ Stdio | ⚠️ Sandbox* |
| **Multi-LLM** | ✅ 8+ providers | ❌ Claude only | ✅ Multiple | ✅ Multiple | ✅ Claude + Local |
| **Local Models** | ✅ Ollama, vLLM, LM Studio | ❌ | ⚠️ Via OpenRouter* | ✅ Ollama, LM Studio | ✅ Ollama, LM Studio |
| **Apple Intelligence** | ✅ LoRA training | ❌ | ❌ | ❌ | ❌ |
| **iMessage Remote** | ✅ Built-in | ✅ Via Channels* | ❌ | ❌ | ✅ Via MoltBot* |
| **Root Operations** | ✅ XPC daemon | ❌ | ❌ | ❌ | ✅ Docker sandbox |
| **Open Source** | ✅ MIT License | ⚠️ Partial* | ❌ | ✅ Apache 2.0 | ✅ Open Source* |

**Key Accuracy Notes:**
- *Claude Code AppleScript: Available via community MCP servers, not built-in
- *Claude Code Channels: Telegram/Discord messaging added Jan 2026, iMessage via Dispatch
- *Claude Code Open Source: Some components open source (MCP SDK, CLI tools), core proprietary
- *Cursor Local: Via OpenRouter or API passthrough, not direct local model support
- *Cline: Open-source VS Code extension with local model support
- *OpenClaw: Open source with permissive license, Docker sandbox for isolation, MoltBot for multi-platform messaging
---

<img width="1460" height="1031" alt="imagelink" src="https://github.com/user-attachments/assets/6fe745a4-bba5-43c3-9489-957945eeb6da" />

## Features

### 🤖 Multi-LLM Support

Agent! supports **8 LLM providers** out of the box:

| Provider | Cloud/Local | Notes |
|----------|-------------|-------|
| **Anthropic Claude** | Cloud | Works best, but pricey |
| **OpenAI GPT** | Cloud | GPT-4, GPT-4o |
| **DeepSeek** | Cloud | Cost-effective alternative |
| **Hugging Face** | Cloud | Open models |
| **Ollama Cloud** | Cloud | Managed Ollama |
| **Local Ollama** | Local | Requires 32GB+ RAM |
| **vLLM** | Local/Cloud | Self-hosted |
| **LM Studio** | Local | OpenAI/Anthropic compatible |

**Plus**: Apple Intelligence integration for LoRA fine-tuning and context mediation.

### 🦾 AgentScript — Swift at Runtime

Write **100% Swift scripts** that compile at runtime and run with full system access:

```swift
// ~/Documents/AgentScript/agents/Sources/Scripts/MyScript.swift
import Foundation
import MusicBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    let music = SBApplication(bundleIdentifier: "com.apple.Music")!
    let track = music.currentTrack!
    print("Now playing: \(track.name ?? "Unknown")")
    return 0
}
```

**No other AI tool can do this.** AgentScript dylibs load via `dlopen()` and have full access to:
- ScriptingBridge (Music, Finder, Mail, Calendar, etc.)
- Foundation networking and file I/O
- CoreGraphics for screenshots
- AVFoundation for audio/video
- Security framework for keychain access

### 📱 Messages Monitor — Remote Control via iMessage

Control your Mac from anywhere using iMessage:

```
[From your iPhone]
Agent! What song is playing?
Agent! Build my Xcode project
Agent! Check my email
```

Agent! responds with results directly to your iMessage. **Approved contacts only** — you control who can send commands.

### 🛠️ 60+ Built-in Tools

Agent! includes a comprehensive toolset:

<details>
<summary><strong>Direct Tools (no action parameter)</strong></summary>

| Tool | Description |
|------|-------------|
| `read_file` | Read file contents with line numbers |
| `write_file` | Create or overwrite files |
| `edit_file` | Exact string replacement in files |
| `diff_and_apply` | Line-range editing with preview |
| `list_files` | Glob-based file search |
| `search_files` | Regex pattern search in files |
| `read_dir` | Directory listing with sizes |
| `task_complete` | Signal task completion |
| `execute_agent_command` | Shell commands as user |
| `execute_daemon_command` | Shell commands as root |
| `run_shell_script` | Shell script execution |
| `batch_commands` | Multiple commands in one call |
| `batch_tools` | Multiple tool calls in one request |

</details>

<details>
<summary><strong>Action-Based Tools</strong></summary>

| Tool | Actions |
|------|---------|
| `file_manager` | read, write, edit, list, search, read_dir, create, apply, undo, diff_apply, if_to_switch, extract_function |
| `git` | status, diff, log, commit, diff_patch, branch |
| `xcode` | build, run, list_projects, select_project, add_file, remove_file, grant_permission |
| `agent` | list, read, create, update, run, delete, combine |
| `plan_mode` | create, update, read, list, delete |
| `applescript_tool` | execute, lookup_sdef, list, run, save, delete |
| `javascript_tool` | execute, list, run, save, delete |
| `accessibility` | list_windows, get_properties, perform_action, type_text, click, press_key, screenshot, set_properties, find_element, get_children |
| `web` | search, google_search, open, find, click, type, execute_js, get_url, get_title, read_content, scroll_to, select, submit, navigate |

</details>

### 🧩 MCP (Model Context Protocol) Support

Agent! implements the **Anthropic MCP protocol** for extensible tools:

- **Stdio Transport** — Launch local MCP servers
- **HTTP/SSE Transport** — Connect to remote MCP servers
- **Auto-discovery** — Tools and resources discovered automatically
- **Tool Preferences** — Enable/disable tools per provider

```json
{
  "name": "filesystem",
  "command": "/usr/local/bin/mcp-filesystem",
  "args": ["/Users/toddbruss/projects"],
  "autoStart": true
}
```

### 🏗️ Xcode Integration

Agent! deeply integrates with Xcode:

```swift
// List open projects
xcode(action: "list_projects")

// Build current project
xcode(action: "build")

// Run project
xcode(action: "run")

// Add file to project
xcode(action: "add_file", file_path: "/path/to/File.swift")
```

**No other AI tool can build and run Xcode projects.**

### 🌐 Web Automation

Automate Safari, Chrome, Firefox, and Edge:

```swift
// Open URL
web(action: "open", url: "https://github.com")

// Click element
web(action: "click", selector: "#submit-button")

// Read page content
web(action: "read_content")

// Execute JavaScript
web(action: "execute_js", script: "document.title")
```

**Browser Support Status:**

Agent! is an **Apple-focused product** with Safari as the primary browser for full automation.

| Browser | Status | Capabilities |
|---------|--------|--------------|
| **Safari** | ✅ Full | Open URLs, JavaScript execution, click, type, form submit, tabs, windows, page content |
| **Chrome** | ⚠️ Partial | Open URLs, tab/window management via AppleScript — Selenium IDE not yet implemented |
| **Firefox** | ⚠️ Partial | Open URLs via AppleScript — Selenium IDE not yet implemented |
| **Edge** | ⚠️ Partial | Open URLs via AppleScript — Selenium IDE not yet implemented |

> **Note**: Safari has complete AppleScript JavaScript support (`do JavaScript`). Chrome/Firefox/Edge lack this command. **Selenium IDE support for Chrome, Firefox, and Edge is not yet implemented** — click, type, and execute_js for these browsers will be enabled when Selenium WebDriver integration is added.

### 🔐 Security Architecture

Agent! implements a **defense-in-depth security model**:

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Agent.app (SwiftUI)                          │
│                                                                      │
│   ┌──────────────────┐         ┌─────────────────────────────────┐   │
│   │   TCC Context    │         │        XPC Services             │   │
│   │                  │         │                                 │   │
│   │  • Accessibility │         │  ┌──────────────────────────┐   │   │
│   │  • Screen Record │──────-──│  │ UserService (User Agent) │   │   │
│   │  • Automation    │         │  │ agent.app.toddbruss.user │   │   │
│   └──────────────────┘         │  └──────────────────────────┘   │   │
│                                │                                 │   │
│   ┌──────────────────┐         │  ┌───────────────────────── ─┐  │   │
│   │   AgentScript    │         │  │ HelperService (Daemon)    │  │   │
│   │                  │         │  │ agent.app.toddbruss.helper│  │   │
│   │  • dylibs        │───--────│  │     (runs as root)        │  │   │
│   │  • dlopen load   │         │  └───────────────────────────┘  │   │
│   └──────────────────┘         └─────────────────────────────────┘   │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

| Layer | Protection |
|-------|------------|
| **XPC Boundary** | Privileged operations isolated to separate processes |
| **LaunchAgent** | User-level operations (file edits, git, builds) |
| **LaunchDaemon** | Root operations (system packages, /Library) |
| **TCC Permissions** | Accessibility, Screen Recording, Automation |
| **Write Protection** | Destructive operations require explicit opt-in |

<details>
<summary><strong>Full Entitlements List</strong></summary>

| Entitlement | Purpose |
|-------------|---------|
| `automation.apple-events` | AppleScript and ScriptingBridge automation |
| `cs.allow-unsigned-executable-memory` | Required for dlopen'd AgentScript dylibs |
| `cs.disable-library-validation` | Load user-compiled script dylibs at runtime |
| `assets.music.read-write` | Music library access via MusicBridge |
| `device.audio-input` | Microphone access for audio scripts |
| `device.bluetooth` | Bluetooth device interaction |
| `device.camera` | Camera capture |
| `device.usb` | USB device access |
| `files.downloads.read-write` | Read/write Downloads folder |
| `files.user-selected.read-write` | Read/write user-selected files |
| `network.client` | Outbound connections (API calls, web search) |
| `network.server` | Inbound connections (MCP HTTP/SSE transport) |
| `personal-information.addressbook` | Contacts access via ContactsBridge |
| `personal-information.calendars` | Calendar access via CalendarBridge |
| `personal-information.location` | Location services |
| `personal-information.photos-library` | Photos access via PhotosBridge |
| `keychain-access-groups` | Secure API key storage |

</details>

---

## Installation

### Prerequisites

- macOS 26.0 or later
- Xcode 16.0 or later (for AgentScript compilation)
- API key for your preferred LLM provider

### Setup

1. **Download Agent!** from the [Releases](https://github.com/toddbruss/Agent/releases) page

2. **Move to Applications folder** — Required for proper XPC registration

3. **Launch Agent!** — The app will:
   - Create `~/Documents/AgentScript/agents/` for AgentScript dylibs
   - Create `~/Documents/AgentScript/applescript/` for saved AppleScripts
   - Create `~/Documents/AgentScript/javascript/` for saved JXA scripts
   - Install AppleEventBridges package to `~/Documents/AgentScript/bridges/`

4. **Configure your LLM provider**:
   - Open Settings (⌘+,)
   - Select your provider from the dropdown
   - Enter your API key
   - Select your model

5. **Enable XPC services**:
   - Click **Connect** in the toolbar
   - Click **Register** to install LaunchAgent and LaunchDaemon
   - Enter your password when prompted

6. **Start using Agent!** — Type a task and press Run (⌘+Enter)

### Local Models (Optional)

For local LLM support:

1. **Install Ollama** from [ollama.ai](https://ollama.ai)
2. **Pull a model**: `ollama pull llama3.2`
3. **Configure Agent!**:
   - Provider: Local Ollama
   - Endpoint: `http://localhost:11434`
   - Model: `llama3.2`

> **Note**: Local models require significant RAM (minimum 32GB, recommended 64GB+). For Mac minis or devices with limited RAM, cloud-based LLMs are strongly recommended.

---

## Comparison

### Agent! vs Claude Code

| Aspect | Agent! | Claude Code |
|--------|--------|-------------|
| **Interface** | Native macOS SwiftUI app | Terminal-based CLI |
| **Platform Focus** | macOS-first | Cross-platform |
| **Xcode Integration** | Build, run, manage projects | File edits only |
| **App Automation** | Full ScriptingBridge support | Via MCP servers (add-on) |
| **System Access** | Accessibility API, root daemon | Sandboxed terminal |
| **LLM Choice** | 8+ providers | Claude only (Claude API) |
| **Local Models** | Ollama, LM Studio, vLLM | No |
| **Scripting** | Swift, AppleScript, JXA | None native |
| **MCP** | Stdio + HTTP/SSE transports | HTTP/SSE + Stdio |
| **Remote Control** | Built-in iMessage | Claude Dispatch (separate app) |
| **Open Source** | ✅ MIT License | ❌ Proprietary (Commercial Terms of Service) |

**Verdict**: Claude Code is excellent for terminal-based cross-platform development. Agent! is superior for macOS-specific workflows, Xcode projects, and deep system automation.

### Agent! vs Cursor

| Aspect | Agent! | Cursor |
|--------|--------|--------|
| **Technology** | Native Swift | Electron (VS Code fork) |
| **Performance** | Native speed, low memory | Chromium overhead (~150MB+ idle) |
| **macOS Integration** | Deep system integration | Limited to file operations |
| **Xcode Support** | Full project management | Basic file editing, simulator via Sweetpad |
| **LLM Choice** | 8+ providers | OpenAI, DeepSeek, Claude, Gemini |
| **Scripting** | Swift, AppleScript, JXA | None |
| **System Automation** | Accessibility, root operations | None |
| **Privacy** | Local processing options | Cloud-only by default |
| **MCP Support** | Stdio + HTTP/SSE | Stdio + HTTP/SSE |
| **Open Source** | ✅ MIT License | ❌ Proprietary |

**Verdict**: Cursor is a VS Code fork with AI features and multi-LLM support. Agent! is a purpose-built macOS app that deeply integrates with the system. Choose Cursor if you need VS Code; choose Agent! if you need macOS automation and Xcode integration.

### Agent! vs Cline

| Aspect | Agent! | Cline |
|--------|--------|-------|
| **Interface** | Native macOS SwiftUI app | VS Code extension |
| **Platform Focus** | macOS-first | Cross-platform (VS Code) |
| **Xcode Integration** | Build, run, manage projects | File edits only |
| **App Automation** | Full ScriptingBridge support | None |
| **System Access** | Accessibility API, root daemon | Terminal commands only |
| **LLM Choice** | 8+ providers | Multiple (Claude, OpenAI, DeepSeek, local) |
| **Local Models** | Ollama, LM Studio, vLLM | Ollama, LM Studio |
| **Scripting** | Swift, AppleScript, JXA | None |
| **MCP Support** | Stdio + HTTP/SSE | Stdio |
| **Open Source** | ✅ MIT License | ✅ Apache 2.0 |

**Verdict**: Cline is an open-source VS Code extension with strong local model support. Agent! provides native macOS integration with ScriptingBridge, Xcode project management, and Accessibility API control. Choose Cline for VS Code workflows; choose Agent! for deep macOS automation.

### Agent! vs OpenClaw

| Aspect | Agent! | OpenClaw |
|--------|--------|----------|
| **Interface** | Native SwiftUI app | Electron desktop app |
| **Architecture** | Native macOS app | Electron with Docker sandbox |
| **Xcode Integration** | Build, run, projects | File edits only |
| **App Automation** | ScriptingBridge for 50+ apps | None (sandboxed) |
| **LLM Choice** | 8+ providers | Claude API + Local LLMs (Ollama, LM Studio) |
| **Local Models** | Ollama, LM Studio, vLLM | ✅ Full support |
| **Scripting** | Swift, AppleScript, JXA | None |
| **MCP** | Full Stdio + HTTP/SSE | Basic support, sandboxed |
| **Messages** | Built-in iMessage remote | Via MoltBot (WhatsApp, Telegram, Discord, Slack, iMessage) |
| **System Access** | Full access with TCC | Sandboxed Docker containers |
| **Privacy** | Local processing available | Local-first design |
| **Open Source** | ✅ MIT License | ✅ MIT License |

**Verdict**: OpenClaw excels at privacy-focused automation with local LLM support and sandboxed security. Agent! provides deeper macOS integration with native ScriptingBridge, Xcode project management, and Accessibility API control. Choose OpenClaw for privacy-first workflows; choose Agent! for deep macOS automation and Xcode development.

---

## Architecture

### Component Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                  Agent! App                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────────────┐    │
│   │  ContentView    │   │  AgentViewModel │   │  ActivityLogView        │    │
│   │  (SwiftUI)      │   │  (Main Logic)   │   │  (Output Display)       │    │
│   └────────┬────────┘   └────────┬────────┘   └─────────────────────────┘    │
│            │                     │                                           │
│   ┌────────▼────────┐   ┌────────▼─────────┐   ┌─────────────────────────┐   │
│   │  InputSection   │   │  LLM Services    │   │  Tool Handlers          │   │
│   │  (Task Entry)   │   │  (Claude, etc.)  │   │  (60+ tools)            │   │
│   └─────────────────┘   └──────────────────┘   └─────────────────────────┘   │
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│                              Services Layer                                  │
│                                                                              │
│   ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌──────────┐   │
│   │  ScriptService  │ │  CodingService  │ │  XcodeService   │ │ WebAuto  │   │
│   │  (AgentScript)  │ │  (File Ops)     │ │  (Build/Run)    │ │ (Safari) │   │
│   └─────────────────┘ └─────────────────┘ └─────────────────┘ └──────────┘   │
│                                                                              │
│   ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌──────────┐   │
│   │ AppleEventSvc   │ │ AccessibilitySvc│ │  MCPService     │ │UserServic│   │
│   │ (ScriptingBr)   │ │ (UI Control)    │ │ (MCP Protocol)  │ │ (XPC)    │   │
│   └─────────────────┘ └─────────────────┘ └─────────────────┘ └──────────┘   │
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│                                 XPC Layer                                    │
│                                                                              │
│   ┌────────────────────────────┐   ┌────────────────────────────────────┐    │
│   │  UserService (LaunchAgent) │   │  HelperService (LaunchDaemon)      │    │
│   │  agent.app.toddbruss.user  │   │  agent.app.toddbruss.helper        │    │
│   │      (User Context)        │   │        (Root Context)              │    │
│   └────────────────────────────┘   └────────────────────────────────────┘    │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                          User Input                              │
│                              │                                   │
│                              ▼                                   │
│                       AgentViewModel                             │
│                              │                                   │
│          ┌───────────────────┼───────────────────┐               │
│          │                   │                   │               │
│          ▼                   ▼                   ▼               │
│    Parse Tools         LLM API Call       Tool Responses         │
│          │                   │                   │               │
│          ▼                   ▼                   ▼               │
│   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐         │
│   │ Direct Tools │   │ Claude       │   │ Formatted    │         │
│   │ ──────────── │   │ OpenAI       │   │ Output       │         │
│   │ CodingService│   │ Ollama       │   │ ActivityLog  │         │
│   │ XcodeService │   │ Apple Intel. │   │              │         │
│   │ ScriptService│   └──────────────┘   └──────────────┘         │
│   │ WebAutomation│                                               │
│   └──────────────┘                                               │
│          │                                                       │
│          ├──────────────┬──────────────┐                         │
│          ▼              ▼              ▼                         │
│    Shell Cmds      Root Cmds    Execute Tools                    │
│          │              │                                        │
│          ▼              ▼                                        │
│   ┌──────────────┐  ┌──────────────┐                             │
│   │ UserService  │  │HelperService │                             │
│   │ (User XPC)   │  │(Root XPC)    │                             │
│   └──────────────┘  └──────────────┘                             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## AgentScript Deep Dive

### Why AgentScript?

AgentScript solves a fundamental problem: **existing AI tools cannot control macOS apps directly**. They can:
- Generate text
- Edit files
- Run terminal commands

But they **cannot**:
- Control Xcode, Music, Finder, or any macOS app
- Capture screenshots with native APIs
- Respond to system events
- Run with full TCC permissions

AgentScript fixes this by compiling **Swift to dynamic libraries** that load at runtime with full system access.

### How It Works

```
1. User creates script: ~/Documents/AgentScript/agents/Sources/Scripts/MyScript.swift

2. ScriptService.ensurePackage():
   - Discovers all .swift files in Sources/Scripts/
   - Parses import statements for bridge dependencies
   - Generates Package.swift with correct dependencies

3. User runs script:
   - ScriptService.compileAllScripts()
   - swift build (produces .dylib)
   - dlopen() loads dylib into memory
   - dlsym() finds script_main symbol
   - Script executes with @_cdecl calling convention

4. Return value:
   - 0 = success
   - Non-zero = error (logged, returned to LLM)
```

### Bridge Modules

Agent! includes **50+ ScriptingBridge bridges** for app automation:

| Bridge | App |
|--------|-----|
| MusicBridge | Apple Music |
| FinderBridge | Finder |
| MailBridge | Mail |
| CalendarBridge | Calendar |
| ContactsBridge | Contacts |
| SafariBridge | Safari |
| ChromeBridge | Google Chrome |
| FirefoxBridge | Firefox |
| MessagesBridge | Messages |
| NotesBridge | Notes |
| XcodeScriptingBridge | Xcode |
| TerminalBridge | Terminal |
| SystemEventsBridge | System Events |
| ... | 40+ more |

### Example Scripts

<details>
<summary><strong>Screenshot Capture</strong></summary>

```swift
import CoreGraphics
import Foundation
import AppKit

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    guard let cgImage = CGWindowListCreateImage(
        CGRect.null,
        .optionOnScreenOnly,
        CGWindowID(kCGNullWindowID),
        [.boundsIgnoreFraming, .bestResolution]
    ) else {
        print("Failed to capture screen")
        return 1
    }
    
    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    guard let tiffData = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG")
        return 1
    }
    
    let path = "/tmp/screenshot_\(Date().timeIntervalSince1970).png"
    try? pngData.write(to: URL(fileURLWithPath: path))
    print(path)
    return 0
}
```

</details>

<details>
<summary><strong>Music Control</strong></summary>

```swift
import Foundation
import MusicBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    guard let music = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("Music app not running")
        return 1
    }
    
    // Get current track
    if let track = music.currentTrack {
        print("Now playing: \(track.name ?? "Unknown")")
        print("Artist: \(track.artist ?? "Unknown")")
        print("Album: \(track.album ?? "Unknown")")
    }
    
    // Next track
    music.nextTrack?()
    
    return 0
}
```

</details>

---

## MCP (Model Context Protocol)

### What is MCP?

MCP is Anthropic's open standard for connecting AI assistants to external tools and data sources. Agent! implements the full MCP specification.

### Supported Transports

| Transport | Use Case |
|-----------|----------|
| **Stdio** | Local MCP servers launched as subprocesses |
| **HTTP/SSE** | Remote MCP servers, cloud services |

### Configuration

MCP servers are configured in `~/Documents/AgentScript/mcp_servers.json`:

```json
{
  "servers": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "filesystem",
      "command": "/usr/local/bin/mcp-filesystem",
      "args": ["/Users/toddbruss/projects"],
      "env": {},
      "enabled": true,
      "autoStart": true
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "name": "github",
      "url": "https://mcp.github.com/sse",
      "headers": {
        "Authorization": "Bearer YOUR_GITHUB_TOKEN"
      },
      "enabled": true,
      "autoStart": false
    }
  ]
}
```

---

## Messages Monitor

### Remote Control via iMessage

Agent! can receive commands via iMessage from approved contacts:

1. **Enable Messages** in the toolbar (green switch)
2. **Open Messages Monitor** (speech bubble icon)
3. **Approve contacts** by toggling them ON
4. **Send commands** from your iPhone or other device:

```
Agent! What song is playing?
Agent! Build and run my Xcode project
Agent! Check my email for messages from John
Agent! Create a git commit with message "Fix bug"
```

### Security

- **Only approved contacts** can execute commands
- **256 character limit** on responses (iMessage constraint)
- **All commands logged** in activity history
- **Automatic timeout** for long-running tasks

---

## Apple Intelligence Integration

Agent! integrates with Apple Intelligence (macOS 26+) for:

1. **Context Mediation** — Apple AI rephrases user requests to help the primary LLM understand intent
2. **LoRA Training** — Capture training data for fine-tuning models

### Enabling Apple Intelligence

1. Open **System Settings → Apple Intelligence & Siri**
2. Enable Apple Intelligence
3. In Agent!, open Settings → Apple Intelligence
4. Toggle **Enable Mediator**
5. Optionally enable **Training Mode** to capture LoRA data

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘+Enter | Run task |
| ⌘+. | Stop running task |
| ⌘+, | Open Settings |
| ⌘+F | Find in activity log |
| ⌘+Shift+P | System Prompts window |
| ⌘+T | New tab |
| ⌘+W | Close tab |

---

## Troubleshooting

### Common Issues

<details>
<summary><strong>XPC Services Not Connecting</strong></summary>

**Symptoms**: "User Agent: not connected" or "Launch Daemon: not connected"

**Solutions**:
1. Click **Connect** in the toolbar
2. Click **Register** to reinstall XPC services
3. Enter your password when prompted
4. Restart Agent!

If issues persist:
```bash
# Check LaunchAgent status
launchctl list | grep agent.app.toddbruss.user

# Check LaunchDaemon status (requires sudo)
sudo launchctl list | grep agent.app.toddbruss.helper

# Manually load services
launchctl load ~/Library/LaunchAgents/agent.app.toddbruss.user.plist
sudo launchctl load /Library/LaunchDaemons/agent.app.toddbruss.helper.plist
```

</details>

<details>
<summary><strong>AgentScript Compilation Fails</strong></summary>

**Symptoms**: "Script compilation failed" or "dlopen error"

**Solutions**:
1. Ensure Xcode is installed: `xcode-select --install`
2. Check Swift version: `swift --version` (requires 6.2+)
3. Verify Package.swift syntax
4. Check for missing imports

Debug mode:
```bash
cd ~/Documents/AgentScript/agents
swift build 2>&1 | head -50
```

</details>

<details>
<summary><strong>MCP Server Won't Connect</strong></summary>

**Symptoms**: "MCP connection failed" or "Tool discovery timeout"

**Solutions**:
1. Verify the command path exists
2. Check environment variables
3. For HTTP servers, verify the URL and headers
4. Check Agent! logs: `~/Library/Logs/Agent/`

</details>

---

## Contributing

Agent! is open source and welcomes contributions:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit changes: `git commit -am 'Add my feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Submit a Pull Request

### Development Setup

```bash
# Clone the repo
git clone https://github.com/toddbruss/Agent.git
cd Agent

# Open in Xcode
open AgentXcode/Agent.xcodeproj

# Build
xcodebuild -scheme Agent -configuration Debug
```

---

## License

MIT License — See [LICENSE](LICENSE) for details.

---

## Acknowledgments

- **Anthropic** for Claude and the MCP protocol
- **Apple** for Swift, SwiftUI, and the macOS platform
- **MultiLineDiff** for efficient diff algorithms
- **The open source community** for inspiration and contributions

---

<div align="center">

**Agent! — Your AI-powered partner for macOS development.**

[Download Now](https://github.com/toddbruss/Agent/releases) • [Documentation](https://github.com/toddbruss/Agent/wiki) • [Issues](https://github.com/toddbruss/Agent/issues)

</div>
