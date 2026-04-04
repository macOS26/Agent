<div align="center">
<img width="256" height="256" alt="Agent! icon" src="https://github.com/user-attachments/assets/7a452184-6b31-49fa-9b24-d450d2889f66" />

# 🦾 Agent! for macOS 26

## **Agentic AI for your  Mac Desktop**
## Open Source replacement for Claude Code, Cursor, Open Claw

[![Latest Release](https://img.shields.io/github/v/release/macOS26/Agent?label=Download&color=blue&style=for-the-badge)](https://github.com/macOS26/Agent/releases/latest)
[![GitHub Stars](https://img.shields.io/github/stars/macOS26/Agent?style=for-the-badge&logo=github&label=Stars&color=hotpink)](https://github.com/macOS26/Agent/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/macOS26/Agent?style=for-the-badge&logo=github&label=Forks&color=white)](https://github.com/macOS26/Agent/fork)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-purple?style=for-the-badge)](https://github.com/apple)
</div>

## What's New 🚀

- **Autonomous Task Loop:** Agent! now reasons, executes, and self-corrects until the task is complete.
- **Agentic Coding:** Advanced code editing with **Time Machine-style backups** for every file change.
- **Native Xcode Tools:** Faster, project-aware builds and runs without external MCP configuration.
- **Privileged Root Access:** Secure, user-approved daemon for executing any system command.
- **Desktop Automation:** Full control of any macOS app via AXorcist (Accessibility API).
- **Expanded AI Support:** Stabilized tool calling for **Mistral** and **Google Gemini** models.
- **Unified Provider Registry:** Centralized model and URL management via `LLMRegistry`.
- **Ollama Pre-warming:** Eliminates cold-start delays by pre-loading models on launch.
- **Enhanced Logging & Diagnostics:** Improved daemon status checks and error reporting in the activity log.
- **Multi-tab LLM Configuration:** Per-tab provider/model settings for flexible multi-agent workflows.
---

A native macOS AI agent that controls your apps, writes code, automates workflows, and runs tasks from your iPhone via iMessage. All powered by the AI provider of your choice.

<img width="1350" height="964" alt="image" src="https://github.com/user-attachments/assets/7ccb2bf9-fa3b-4cde-af53-3bc4c2ab021c" />

---

## Quick Start

1. **Download** [Agent!](https://github.com/macOS26/Agent/releases/latest) and drag to Applications
2. **Open Agent!** -- it sets up everything automatically
3. **Pick your AI** -- Settings → choose a provider → enter API key
## Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/toddbruss/Agent.git
   cd Agent
   ```
2. **Open `Agent.xcodeproj` in Xcode.**
3. **Build and Run the `Agent` target.**
4. **Approve the Helper Tool:** When prompted, authorize the privileged daemon to allow root-level command execution.
5. **Configure your AI Provider:** Go to Settings and enter your API key or select a local provider like Ollama.

> 💡 **No API key?** Use **Ollama** with **GLM-5** -- completely free, runs offline, no account needed. Requires 32GB+ RAM.


## What Can It Do?

> *"Play my Workout playlist in Music"*
> *"Build the Xcode project and fix any errors"*
> *"Take a photo with Photo Booth"*
> *"Send an iMessage to Mom saying I'll be home at 6"*
> *"Open Safari and search for flights to Tokyo"*
> *"Refactor this class into smaller files"*
> *"What calendar events do I have today?"*

Just type what you want. Agent! figures out how and makes it happen.

---

## Key Features

### 🧠 Agentic AI Framework
Built-in autonomous task loop that reasons, executes, and self-corrects. Agent! doesn't just run code; it observes the results, debugs errors, and iterates until the task is complete.

### 🛠 Agentic Coding
Full coding environment built in. Reads codebases, edits files with precision, runs shell commands, builds Xcode projects, manages git, and auto-enables coding mode to focus the AI on development tools. Replaces Claude Code, Cursor, and Cline -- no terminal, no IDE plugins, no monthly fee. Features **Time Machine-style backups** for every file change, letting you revert any edit instantly.

### 🔍 Dynamic Tool Discovery
Automatically detects and uses available tools (Xcode, Playwright, Shell, etc.) based on your prompt. No manual configuration required for core tools.

### 🛡 Privileged Execution
Securely runs root-level commands via a dedicated macOS Launch Daemon. The user approves the daemon once, then the agent can execute commands autonomously via XPC.

62	
63	### 🖥 Desktop Automation (AXorcist)
64	Control any Mac app through the Accessibility API. Click buttons, type into fields, navigate menus, scroll, drag -- all programmatically. Powered by [AXorcist](https://github.com/steipete/AXorcist) for reliable, fuzzy-matched element finding.
65	
### 🤖 12 AI Providers
| Provider | Cost | Best For |
|---|---|---|
| **GLM-5 / GLM-5.1** (Ollama) | Low Cost | Recommended starting point |
| **Claude** (Anthropic) | Paid | Complex tasks |
| **ChatGPT** (OpenAI) | Paid | General purpose |
| **Google Gemini** | Paid/Free | High performance, long context |
| **Apple Intelligence** | Free | On-device, private |
| **DeepSeek** | Paid | Budget cloud AI |
| **Grok-2** (xAI) | Paid | Real-time info |
| **Local Ollama** | Free | Full privacy, offline |
| **LM Studio** | Free | Easy local setup |
| **Hugging Face** | Varies | Open-source models |
| **Z.ai** | Paid | Fast, versatile |
| **Mistral Vibe** | Varies | High-performance open models |

### 🎙 Voice Control
Click the microphone and speak. Agent! transcribes in real time and executes your request.

### 📱 Remote Control via iMessage
Text your Mac from your iPhone:
```
Agent! What song is playing?
Agent! Check my email
Agent! Next Song
```
Your Mac runs the task and texts back the result. Only approved contacts can send commands.

### 🌐 Web Automation
Drives Safari hands-free -- search Google, click links, fill forms, read pages, extract information.

### 📋 Smart Planning
For complex tasks, Agent! creates a step-by-step plan, works through each step, and checks them off in real time.

### 🗂 Tabs
Work on multiple tasks simultaneously. Each tab has its own project folder and conversation history.

### 📸 Screenshot & Vision
Take screenshots or paste images. Vision-capable AI models analyze what they see -- describe content, read text, spot UI issues.

### 🌐 Safari Web Automation (Built-in)

Agent! includes built-in Safari web automation via JavaScript and AppleScript. Search Google, click links, fill forms, read page content, and execute JavaScript -- all hands-free.

**To enable:** Open Safari → Settings → Advanced → check "Show features for web developers". Then go to Developer menu → check "Allow JavaScript from Apple Events".

### 🎭 Playwright Web Automation (Optional)

Full cross-browser automation via [Microsoft Playwright MCP](https://github.com/microsoft/playwright-mcp). Click, type, screenshot, and navigate any website in Chrome, Firefox, or WebKit -- all controlled by the AI.

**Setup (one-time):**

```bash
# 1. Install Node.js (if not already installed)
brew install node

# 2. Install Playwright MCP server globally
npm install -g @playwright/mcp@latest

# 3. Install browser binaries (pick one or all)
npx playwright install chromium          # Chrome (~165MB)
npx playwright install firefox           # Firefox (~97MB)
npx playwright install webkit            # Safari/WebKit (~75MB)
npx playwright install                   # All browsers
```

**Configure in Agent!:**

Go to Settings → MCP Servers → Add Server, paste this JSON:

```json
{
    "mcpServers": {
        "playwright": {
            "command": "npx",
            "args": ["@playwright/mcp"],
            "transport": "stdio"
        }
    }
}
```

> **Note:** If `npx` is not found, use the full path: run `which npx` in Terminal and replace `"npx"` with the result (e.g. `"/opt/homebrew/bin/npx"`).

Toggle ON and Playwright tools appear automatically. The AI can now control browsers directly.

---

## Privacy & Safety

- **Your data stays on your Mac.** Files, screen contents, and personal data are never uploaded.
- **Cloud AI only sees your prompt text.** Use local AI to stay 100% offline.
- **You're in control.** Agent! shows everything it does and logs every action.
- **Built on Apple's security model.** macOS permissions protect your system.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Enter` | Run task |
| `⌘ R` | Run current task |
| `⌘ .` | Stop task |
| `Escape` | Cancel active task |
| `⌘ D` | Toggle LLM output panel |
| `⌘ T` | New tab |
| `⌘ W` | Close tab |
| `⌘ 1-9` | Switch to tab |
| `⌘ [` / `⌘ ]` | Previous / next tab |
| `⌘ F` | Search activity log |
| `⌘ L` | Clear conversation |
| `⌘ H` | Task history |
| `⌘ ,` | Settings |
| `⌘ V` | Paste image |
| `↑` / `↓` | Prompt history |

---

## FAQ

**Do I need to know how to code?** No. Just type what you want in plain English.

**Is it safe?** Yes. Standard macOS automation, full activity logging, you approve permissions.

**How much does it cost?** Agent! is free (MIT License). Cloud AI providers charge for API usage. Local models are free.

**What Mac do I need?** macOS 26+. Apple Silicon recommended. 32GB+ RAM for local models.

**How is this different from Siri?** Siri answers questions. Agent! *performs actions* -- controls apps, manages files, builds code, automates workflows.

---

## Documentation

- [Technical Architecture](docs/TECHNICAL.md) -- Tools, scripting, developer details
- [Comparisons](docs/COMPARISON.md) -- vs Claude Code, Cursor, Cline, OpenClaw
- [Security Model](docs/SECURITY.md) -- XPC architecture, privilege separation
- [FAQ](docs/FAQ.md) -- Common questions

---

## Built-in Xcode Tools

Agent! includes native Xcode integration that works without any MCP server setup. These built-in tools are often faster and more reliable than the MCP alternative since they run directly inside the app.

| Tool | What It Does |
|---|---|
| **xcode build** | Build the current Xcode project, capture errors and warnings. Errors in the activity log are **clickable** and open directly in Xcode. |
| **xcode run** | Build and run the app |
| **xcode list_projects** | Discover open Xcode workspaces and projects |
| **xcode select_project** | Switch the active project |
| **xcode grant_permission** | Grant file access to the Xcode project folder |

The AI automatically uses these when you ask it to build, fix errors, or work with Xcode projects. No configuration needed -- just have your project open in Xcode.

> 🚀 **iOS/iPadOS Support:** Coming soon! Native support for building, running, and testing iOS and iPadOS apps directly from Agent! is in development.

> **Tip:** For most coding workflows, the built-in tools are all you need. The MCP Xcode server below adds extras like SwiftUI Preview rendering and documentation search.


---

<img width="1349" height="1438" alt="Screenshot 2026-04-02 at 12 00 03 PM" src="https://github.com/user-attachments/assets/b0d9346e-f807-4089-bab3-29c7058868d8" />

## Model Context Protocol (MCP)

Agent! supports [MCP](https://modelcontextprotocol.io) servers for extended capabilities. Configure in Settings → MCP Servers.

### Xcode MCP Server

Connect Agent! directly to Xcode for project-aware operations:

```json
{
  "mcpServers" : {
    "xcode" : {
      "command" : "xcrun",
      "args" : [
        "mcpbridge"
      ],
      "transport" : "stdio"
    }
  }
}
```

**Xcode MCP provides:**
- Project-aware file operations (read/write/edit/delete)
- Build and test integration
- SwiftUI Preview rendering
- Code snippet execution
- Apple Developer Documentation search
- Real-time issue tracking


---

## License

MIT - free and open source.

---

<div align="center">

### **Agent! for macOS 26 - Agentic AI for your  Mac Desktop**

</div>
