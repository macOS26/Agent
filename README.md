# Agent! — The Autonomous macOS 26 AI Assistant

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

#### 🌟 Recommended: GLM-5

**GLM-5** is highly recommended for use with Agent! This open-source model has been extensively tested and provides:

- ✅ Excellent vision capabilities for image analysis
- ✅ Strong reasoning and coding abilities
- ✅ Efficient local deployment
- ✅ Full compatibility with Agent!'s tool use format
- ✅ Cost-effective alternative to cloud providers

Download GLM-5 from [Hugging Face](https://huggingface.co/models?search=glm-5) and configure it as a Local Ollama or LM Studio model in Settings.

### 🎤 Voice Control

Control Agent! using your voice with speech recognition:

- **Voice Commands**: Speak naturally to interact with Agent!
- **Real-time Transcription**: Your voice is transcribed and sent to the LLM
- **Accessibility**: Perfect for hands-free operation
- **Multi-language Support**: Works with your system language settings

To use voice control:
1. Click the microphone icon in the toolbar
2. Speak your command clearly
3. Agent! will transcribe and process your request

### 📨 iMessage Control

In addition to the Messages Monitor, you can send commands directly through iMessage:

- Send messages and commands via iMessage from within Agent!
- Use the `send_message` tool to communicate with other iMessage users
- Supports sending to phone numbers, email addresses, or contact names
- Fully integrated with your Mac's Messages app

### 👁️ Vision Support for Vision-Capable LLMs

Agent! supports vision-capable LLMs that can analyze images:

- **Image Analysis**: Send screenshots or images to vision-capable models
- **Screenshot Integration**: Take screenshots and have the LLM analyze them
- **Supported Models**: GPT-4o, Claude 3.5 Sonnet, GLM-5, and other vision-capable models
- **Use Cases**: 
  - Debug UI issues by sharing screenshots
  - Analyze charts and graphs
  - Describe image content
  - Extract text from images (OCR)

To use vision features, simply include images in your conversation with a vision-capable model.

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

### 📝 D1F MultiLineDiff Capability

Agent! uses the **D1F MultiLineDiff library** for powerful and safe file editing operations. This advanced diff engine provides:

#### How It Works

D1F (Delta-1-Format) uses a specialized format for representing file changes:

```
=  Keep line unchanged
-  Remove line
+  Add new line
```

This format allows for precise, multi-line edits with built-in verification:

```
=== Original File ===
1: func calculate() {
2:     let x = 10
3:     return x * 2
4: }

=== D1F Diff ===
= func calculate() {
-     let x = 10
+     let x = 20
=     return x * 2
= }

=== Result ===
1: func calculate() {
2:     let x = 20
3:     return x * 2
4: }
```

#### Key Features

| Feature | Description |
|---------|-------------|
| **SHA Verification** | Every diff includes SHA hash for change verification |
| **Line-Number Tracking** | Automatic line number adjustment after edits |
| **Undo Support** | Diffs are reversible — undo any change |
| **Preview Mode** | See changes before applying with `create_diff` |
| **Multi-Line Edits** | Replace entire blocks of code safely |
| **Context Preservation** | Maintains surrounding code structure |

#### Available Diff Tools

| Tool | Use Case |
|------|----------|
| `edit_file` | Simple string replacement (old_string → new_string) |
| `diff_and_apply` | Line-range editing with preview (one-shot) |
| `create_diff` | Preview changes before committing |
| `apply_diff` | Apply a created or inline D1F diff |
| `undo_edit` | Reverse a previous diff by ID |

#### Example Workflow

```swift
// Step 1: Create a preview diff
create_diff(file_path: "/src/Main.swift", start_line: 10, end_line: 15, 
            destination: "new code here")
// Returns: diff_id for review

// Step 2: Review the preview
// D1F shows exactly what changes with =/-/+ markers

// Step 3: Apply if correct
apply_diff(file_path: "/src/Main.swift", diff_id: "uuid-here")

// Step 4: Need to undo? 
undo_edit(file_path: "/src/Main.swift", diff_id: "uuid-here")
```

#### Safety Benefits

- **No accidental overwrites** — SHA verification ensures changes match expectations
- **Atomic operations** — Each edit is self-contained
- **Full audit trail** — Every change is logged with its diff
- **Reversible** — Any edit can be undone with the diff_id

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

## Apple Intelligence Integration — C3PO Moderator/Translator

Agent! integrates with **Apple Intelligence (macOS 26+)** as a **C3PO Moderator/Translator** — named after the Star Wars protocol droid known for translation and etiquette. Like C-3PO, Apple Intelligence serves as an intermediary that:

1. **Moderates** — Acts as a smart intermediary between the user and the primary LLM
2. **Translates** — Rephrases and clarifies user requests to improve LLM understanding
3. **Mediates Context** — Helps translate user intent into well-structured prompts
4. **LoRA Training** — Optionally captures training data for fine-tuning models

### Why C3PO?

Just as C-3PO was fluent in over 6 million forms of communication, Apple Intelligence helps bridge the gap between human intent and machine understanding:

| C-3PO Role | Apple Intelligence Role |
|------------|------------------------|
| Translator | Rephrases user requests for clarity |
| Protocol Droid | Ensures proper communication format |
| Mediator | Bridges user intent and LLM understanding |
| Advisor | Provides context-aware suggestions |

### How It Works

```
┌─────────────┐      ┌─────────────────┐      ┌─────────────┐
│   User      │ ───▶ │ C3PO (Apple     │ ───▶ │  Primary    │
│   Request   │      │ Intelligence)   │      │  LLM        │
└─────────────┘      └─────────────────┘      └─────────────┘
                            │
                            ▼
                     ┌─────────────────┐
                     │ • Clarifies     │
                     │ • Rephrases     │
                     │ • Adds Context  │
                     │ • Translates    │
                     └─────────────────┘
```

### Enabling C3PO (Apple Intelligence)

1. Open **System Settings → Apple Intelligence & Siri**
2. Enable Apple Intelligence
3. In Agent!, open Settings → Apple Intelligence
4. Toggle **Enable Mediator (C3PO)**
5. Optionally enable **Training Mode** to capture LoRA data

### Benefits of C3PO Mode

- **Better Understanding** — Apple Intelligence rephrases ambiguous requests
- **Context Preservation** — Maintains conversation context across messages
- **Intent Clarification** — Helps when user requests are unclear
- **Privacy-First** — All processing happens on-device with Apple Silicon

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
| /clear | Clear conversation history |

---

## Voice Control

Agent! supports voice input for hands-free operation. Use your voice to:

- **Dictate tasks** — Speak naturally to enter prompts
- **Execute commands** — Voice-activated tool execution
- **Control the app** — Start, stop, and manage tasks with voice

Voice Control leverages macOS's built-in speech recognition for accurate transcription and command processing. Enable Voice Control in Settings to start using voice commands.

---

## iMessage Control

In addition to the Messages Monitor for remote control, Agent! now features **direct iMessage control** for seamless integration with your messaging workflow:

- **Send messages** — Agent! can compose and send iMessages via the `send_message` tool
- **Receive commands** — Messages Monitor receives and processes commands from approved contacts
- **Channel support** — iMessage (default), email, SMS, or clipboard output

```
# Example: Send a message
send_message(content: "Build completed successfully!", recipient: "me", channel: "imessage")
```

### Supported Channels

| Channel | Description |
|---------|-------------|
| `imessage` | Send via iMessage (default) |
| `email` | Send via email |
| `sms` | Send via SMS |
| `clipboard` | Copy to clipboard |

---

## Vision Support

Agent! supports **Vision-capable LLMs** for image understanding and analysis. This enables Agent! to:

- **Analyze screenshots** — Understand screen contents for UI automation
- **Process images** — Extract text, describe visual content, and answer questions about images
- **Visual debugging** — Identify UI issues from screenshots
- **Document analysis** — Read and extract information from image-based documents

### Vision-Capable Models

Agent! supports vision models from multiple providers:

| Provider | Vision Models |
|----------|---------------|
| **Anthropic** | Claude 3.5 Sonnet, Claude 3 Opus |
| **OpenAI** | GPT-4o, GPT-4 Turbo Vision |
| **DeepSeek** | DeepSeek Vision |
| **Hugging Face** | Various vision models |
| **Local Ollama** | LLaVA, BakLLaVA, Moondream |
| **LM Studio** | OpenAI-compatible vision models |

### Recommended: GLM-5

**GLM-5** is highly recommended for use with Agent! This open-source model has been extensively tested and provides:

- ✅ Excellent vision capabilities
- ✅ Strong reasoning and coding abilities
- ✅ Efficient local deployment
- ✅ Compatible with Agent!'s tool use format

To use GLM-5 with Agent!:
1. Download from [Hugging Face](https://huggingface.co/models?search=glm-5)
2. Configure as a Local Ollama or LM Studio model
3. Enable vision features in Settings

---

## Advanced UI — Self-Writing Agents

Agent! features an advanced native SwiftUI interface that enables the AI to **write its own automation agents**. This is a groundbreaking capability that no other AI tool offers.

### The Self-Writing Agent Concept

Agent! can autonomously create, modify, and execute automation scripts:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Agent! Self-Writing Workflow                            │
│                                                                             │
│   ┌─────────────┐     ┌─────────────────┐     ┌─────────────────────────┐   │
│   │  User       │ ──▶ │  Agent! LLM      │ ──▶ │  Analyzes Request      │   │
│   │  Request    │     │  (Claude/GPT/etc)│     │  • What needs to       │   │
│   └─────────────┘     └─────────────────┘     │    automate?           │   │
│                                               │  • Which apps?          │   │
│                                               │  • What APIs?           │   │
│                                               └───────────┬─────────────┘   │
│                                                           │                  │
│   ┌───────────────────────────────────────────────────────▼──────────────┐  │
│   │                    Agent! Generates Code                               │  │
│   │                                                                       │  │
│   │   ┌─────────────┐   ┌─────────────┐   ┌─────────────────────────┐   │  │
│   │   │ Swift Agent │   │ AppleScript │   │ JavaScript (JXA)       │   │  │
│   │   │ Script      │   │ Script      │   │ Script                  │   │  │
│   │   │             │   │             │   │                         │   │  │
│   │   │ • Full      │   │ • Native    │   │ • Web automation        │   │  │
│   │   │   Swift     │   │   macOS     │   │ • Safari control       │   │  │
│   │   │ • Scripting │   │   scripting  │   │ • Chrome/Firefox       │   │  │
│   │   │   Bridge    │   │ • GUI apps   │   │ • Complex workflows    │   │  │
│   │   │ • Compiled  │   │ • Automator  │   │                         │   │  │
│   │   │   dylib     │   │   actions    │   │                         │   │  │
│   │   └─────────────┘   └─────────────┘   └─────────────────────────┘   │  │
│   └───────────────────────────────────────────────────────────────────────┘  │
│                                   │                                         │
│   ┌───────────────────────────────▼───────────────────────────────────────┐ │
│   │                         Execution                                      │ │
│   │                                                                        │ │
│   │   ┌─────────────────┐   ┌─────────────────┐   ┌───────────────────┐  │ │
│   │   │ AgentScript     │   │ AppleScript     │   │ JavaScript        │  │ │
│   │   │ Runtime         │   │ via NSApple     │   │ via JXA Framework  │  │ │
│   │   │ (dlopen dylib)  │   │ Script          │   │                    │  │ │
│   │   └─────────────────┘   └─────────────────┘   └───────────────────┘  │ │
│   └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Writing Swift Agents with ScriptingBridge

Agent! can create **compiled Swift agents** that control macOS apps via ScriptingBridge:

#### How It Works

1. **Agent! analyzes your request** — "Control Music to play my workout playlist"
2. **Generates Swift code** using the appropriate bridge modules
3. **Compiles to dylib** at runtime
4. **Executes with full TCC permissions**

#### Example: Music Control Agent

```swift
// Agent! generates this automatically
import Foundation
import MusicBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    guard let music = SBApplication(bundleIdentifier: "com.apple.Music") else {
        print("Music not available")
        return 1
    }
    
    // Find and play playlist
    let playlists = music.sources?[0].playlists ?? []
    for playlist in playlists {
        if playlist.name == "Workout" {
            playlist.play?()
            return 0
        }
    }
    
    return 0
}
```

#### Supported ScriptingBridge Bridges

| Bridge | App | Capabilities |
|--------|-----|--------------|
| **MusicBridge** | Apple Music | Play, pause, skip, playlists, tracks |
| **FinderBridge** | Finder | File operations, windows, selections |
| **MailBridge** | Mail | Send, read, organize emails |
| **CalendarBridge** | Calendar | Events, reminders, calendars |
| **ContactsBridge** | Contacts | Read, create, update contacts |
| **SafariBridge** | Safari | Tabs, URLs, JavaScript execution |
| **ChromeBridge** | Chrome | Tabs, URLs (limited scripting) |
| **FirefoxBridge** | Firefox | Tabs, URLs (limited scripting) |
| **MessagesBridge** | Messages | Send, read iMessages |
| **NotesBridge** | Notes | Create, read, modify notes |
| **XcodeScriptingBridge** | Xcode | Build, run, schemes |
| **TerminalBridge** | Terminal | Execute commands, tabs |
| **SystemEventsBridge** | System Events | UI scripting, processes |

**Plus 40+ more bridges** for macOS apps.

### Writing AppleScript Agents

For apps without ScriptingBridge support or for GUI automation, Agent! generates **AppleScript**:

```applescript
-- Agent! generates this automatically
tell application "Finder"
    set theFiles to every file of folder "Documents"
    repeat with aFile in theFiles
        if name extension of aFile is "pdf" then
            move aFile to folder "PDFs"
        end if
    end repeat
end tell
```

#### AppleScript Tool Actions

| Action | Description |
|--------|-------------|
| `execute` | Run inline AppleScript source code |
| `lookup_sdef` | Read an app's scripting dictionary |
| `list` | List saved AppleScripts |
| `run` | Run a saved script by name |
| `save` | Save a script for reuse |
| `delete` | Remove a saved script |

#### Example: GUI Automation with AppleScript

```applescript
-- Agent! generates this for UI automation
tell application "System Events"
    tell process "Safari"
        click menu item "New Window" of menu "File" of menu bar 1
        delay 1
        keystroke "t" using {command down}
    end tell
end tell
```

### Writing JavaScript (JXA) Agents

Agent! supports **JavaScript for Automation (JXA)** for JavaScript-native automation:

```javascript
// Agent! generates this automatically
const safari = Application('Safari');
safari.activate();

const tab = safari.Document().make();
safari.windows[0].currentTab.url = 'https://github.com';
```

#### JavaScript Tool Actions

| Action | Description |
|--------|-------------|
| `execute` | Run inline JXA source code |
| `list` | List saved JXA scripts |
| `run` | Run a saved script by name |
| `save` | Save a script for reuse |
| `delete` | Remove a saved script |

### Web Automation — HTML Page Control

Agent! can automate **most HTML webpages** including Google Search, GitHub, and more. The `web` tool provides comprehensive browser control:

#### Web Tool Actions

| Action | Description | Example |
|--------|-------------|---------|
| `open` | Open a URL | `web(action: "open", url: "https://google.com")` |
| `google_search` | Search Google | `web(action: "google_search", query: "Swift tutorials")` |
| `click` | Click an element | `web(action: "click", selector: "#submit-button")` |
| `type` | Type text into input | `web(action: "type", selector: "input[name='q']", text: "hello")` |
| `read_content` | Extract page content | `web(action: "read_content")` |
| `execute_js` | Run JavaScript | `web(action: "execute_js", script: "document.title")` |
| `get_url` | Get current URL | `web(action: "get_url")` |
| `get_title` | Get page title | `web(action: "get_title")` |
| `find` | Find elements | `web(action: "find", selector: ".result")` |
| `scroll_to` | Scroll to element | `web(action: "scroll_to", selector: "#footer")` |
| `select` | Select dropdown option | `web(action: "select", selector: "select", value: "option1")` |
| `submit` | Submit a form | `web(action: "submit", selector: "form")` |
| `navigate` | Navigate back/forward | `web(action: "navigate", direction: "back")` |
| `list_tabs` | List open tabs | `web(action: "list_tabs")` |
| `switch_tab` | Switch to tab | `web(action: "switch_tab", index: 2)` |
| `list_windows` | List browser windows | `web(action: "list_windows")` |
| `new_window` | Open new window | `web(action: "new_window")` |
| `close_window` | Close window | `web(action: "close_window")` |

#### Example: Google Search and Data Extraction

Agent! can autonomously:
1. Open Google Search
2. Enter a search query
3. Navigate results
4. Extract data from result pages

```swift
// Step 1: Open Google
web(action: "open", url: "https://google.com")

// Step 2: Type search query
web(action: "type", selector: "input[name='q']", text: "best Swift UI tutorials")

// Step 3: Submit search
web(action: "submit", selector: "form")

// Step 4: Wait and read results
web(action: "read_content")  // Returns page content

// Step 5: Extract specific data
web(action: "execute_js", script: """
    Array.from(document.querySelectorAll('.g a'))
         .map(a => ({ title: a.innerText, url: a.href }))
""")
```

#### Example: GitHub Repository Analysis

```swift
// Open a repository
web(action: "open", url: "https://github.com/toddbruss/Agent")

// Get repository stats
web(action: "execute_js", script: """
    ({
        stars: document.querySelector('[href="/toddbruss/Agent/stargazers"]').innerText,
        forks: document.querySelector('[href="/toddbruss/Agent/forks"]').innerText,
        watchers: document.querySelector('[href="/toddbruss/Agent/watchers"]').innerText
    })
""")

// Navigate to issues
web(action: "click", selector: 'a[href="/toddbruss/Agent/issues"]')

// List all open issues
web(action: "read_content")
```

#### Safari Deep Integration

Safari has the deepest integration because it supports **AppleScript JavaScript execution**:

```applescript
-- Execute JavaScript in Safari via AppleScript
tell application "Safari"
    tell front document
        do JavaScript "document.querySelectorAll('.price').map(e => e.innerText)"
    end tell
end tell
```

This enables:
- **Form filling** — Auto-fill complex forms
- **Data scraping** — Extract structured data from pages
- **UI testing** — Click, type, verify page state
- **Content extraction** — Pull article text, prices, tables
- **Navigation automation** — Complex multi-page workflows

#### Workflow Example: Research Assistant

```
User: "Research the top 5 Swift UI libraries and summarize them"

Agent!:
1. Opens Google Search
2. Searches "Swift UI libraries"
3. Reads result titles and snippets
4. Opens top 5 results
5. Extracts key information from each page
6. Compiles a summary

All automated — no manual browsing required.
```

### Combining Self-Writing Agents with Web Automation

Agent! can combine all three automation types:

```swift
// Agent! generates a complete workflow:

// 1. Swift AgentScript for file operations
@_cdecl("script_main")
public func scriptMain() -> Int32 {
    // Create directory for scraped data
    try! FileManager.default.createDirectory(
        at: URL(fileURLWithPath: "/tmp/scraped"),
        withIntermediateDirectories: true
    )
    return 0
}

// 2. Web automation for data collection
// Opens URLs, extracts data, saves results

// 3. AppleScript to organize results
tell application "Finder"
    set theFolder to folder "/tmp/scraped"
    sort files of theFolder by name
end tell
```

### Why This Matters

| Feature | Agent! | Other AI Tools |
|---------|--------|----------------|
| **Write Swift scripts** | ✅ Compiles dylibs at runtime | ❌ Terminal only |
| **ScriptingBridge support** | ✅ 50+ app bridges | ❌ None |
| **AppleScript generation** | ✅ Native execution | ⚠️ Via MCP (add-on) |
| **JXA support** | ✅ Built-in | ❌ None |
| **Web automation** | ✅ Safari + partial Chrome/Firefox | ⚠️ Via Playwright add-on |
| **Self-writing agents** | ✅ Full autonomy | ❌ No agent system |
| **TCC permissions** | ✅ Full access | ❌ Sandboxed |

### Agent Creation Workflow

```
┌───────────────────────────────────────────────────────────────────────────┐
│                     Creating an Agent in Agent!                           │
│                                                                           │
│   User: "Create an agent that monitors my email for messages from         │
│          John and saves the attachments to a folder"                      │
│                                                                           │
│   ┌─────────────────────────────────────────────────────────────────┐     │
│   │ Step 1: Agent! Analyzes Request                                 │     │
│   │         • Needs Mail access → MailBridge                        │     │
│   │         • Needs file operations → Foundation                    │     │
│   │         • Needs persistence → Run periodically                  │     │
│   └─────────────────────────────────────────────────────────────────┘     │
│                              │                                            │
│   ┌──────────────────────────▼──────────────────────────────────────┐     │
│   │ Step 2: Agent! Generates Swift Code                              │     │
│   │                                                                  │     │
│   │   import Foundation                                              │     │
│   │   import MailBridge                                              │     │
│   │                                                                  │     │
│   │   @_cdecl("script_main")                                         │     │
│   │   public func scriptMain() -> Int32 {                            │     │
│   │       let mail = SBApplication(                                  │     │
│   │           bundleIdentifier: "com.apple.Mail")!                  │     │
│   │       // Check for John's emails                                │     │
│   │       // Save attachments                                         │     │
│   │       return 0                                                   │     │
│   │   }                                                              │     │
│   └──────────────────────────────────────────────────────────────────┘     │
│                              │                                            │
│   ┌──────────────────────────▼──────────────────────────────────────┐     │
│   │ Step 3: Save & Compile                                           │     │
│   │         agent(action: "create", name: "JohnMailMonitor",         │     │
│   │               content: "generated Swift code")                   │     │
│   │                                                                  │     │
│   │         → ~/Documents/AgentScript/agents/Sources/Scripts/       │     │
│   │           JohnMailMonitor.swift                                  │     │
│   │         → swift build → JohnMailMonitor.dylib                   │     │
│   └──────────────────────────────────────────────────────────────────┘     │
│                              │                                            │
│   ┌──────────────────────────▼──────────────────────────────────────┐     │
│   │ Step 4: Run On Demand or Schedule                                │     │
│   │         agent(action: "run", name: "JohnMailMonitor")            │     │
│   │                                                                  │     │
│   │         The agent is now available for:                          │     │
│   │         • Manual execution                                       │     │
│   │         • Integration with other workflows                       │     │
│   │         • Remote execution via iMessage                           │     │
│   └──────────────────────────────────────────────────────────────────┘     │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting
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
