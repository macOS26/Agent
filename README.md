<div align="center">
<img width="256" height="256" alt="Agent! icon" src="https://github.com/user-attachments/assets/7a452184-6b31-49fa-9b24-d450d2889f66" />

# 🦾 Agent! for macOS 26

## **Agentic AI for your  Mac Desktop**
## Open Source replacement for Claude Code, Cursor, Open Claw

[![Latest Release](https://img.shields.io/github/v/release/macOS26/Agent?label=Download&color=blue&style=for-the-badge)](https://github.com/macOS26/Agent/releases/latest)
[![GitHub Stars](https://img.shields.io/github/stars/macOS26/Agent?style=for-the-badge&logo=github&label=Stars&color=hotpink)](https://github.com/macOS26/Agent/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/macOS26/Agent?style=for-the-badge&logo=github&label=Forks&color=white)](https://github.com/macOS26/Agent/fork)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-purple?style=for-the-badge)](https://github.com/apple)
[![Swift](https://img.shields.io/badge/Swift-6.2-CC5500?style=for-the-badge&logo=swift)](https://github.com/apple/swift)
[![MIT License](https://img.shields.io/badge/License-MIT-228B22?style=for-the-badge)](LICENSE)

A native macOS AI agent that controls your apps, writes code, automates workflows, and runs tasks from your iPhone via iMessage. All powered by the AI provider of your choice.

</div>

<img width="1349" height="1438" alt="Screenshot 2026-04-02 at 12 00 03 PM" src="https://github.com/user-attachments/assets/b0d9346e-f807-4089-bab3-29c7058868d8" />

---

## Quick Start

1. **Download** [Agent!](https://github.com/macOS26/Agent/releases/latest) and drag to Applications
2. **Open Agent!** -- it sets up everything automatically
3. **Pick your AI** -- Settings → choose a provider → enter API key
4. **Type a task and press Enter**

> 💡 **No API key?** Use **Ollama** with **GLM-5** -- completely free, runs offline, no account needed. Requires 32GB+ RAM.

---

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

### 🛠 Agentic Coding
Full coding environment built in. Reads codebases, edits files with precision, runs shell commands, builds Xcode projects, manages git, and auto-enables coding mode to focus the AI on development tools. Replaces Claude Code, Cursor, and Cline -- no terminal, no IDE plugins, no monthly fee.

### 🖥 Desktop Automation (AXorcist)
Control any Mac app through the Accessibility API. Click buttons, type into fields, navigate menus, scroll, drag -- all programmatically. Powered by [AXorcist](https://github.com/steipete/AXorcist) for reliable, fuzzy-matched element finding.

### 🤖 10 AI Providers
| Provider | Cost | Best For |
|---|---|---|
| **GLM-5 / GLM-5.1** (Ollama) | Low Cost | Recommended starting point |
| **Claude** (Anthropic) | Paid | Complex tasks |
| **ChatGPT** (OpenAI) | Paid | General purpose |
| **Apple Intelligence** | Free | On-device, private |
| **DeepSeek** | Paid | Budget cloud AI |
| **Local Ollama** | Free | Full privacy, offline |
| **LM Studio** | Free | Easy local setup |
| **Hugging Face** | Varies | Open-source models |
| **Z.ai** | Paid | Fast, versatile |
| **Ollama Cloud / vLLM** | Varies | Self-hosted |

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
            "command": "/opt/homebrew/bin/playwright-mcp",
            "transport": "stdio",
            "env": {
                "HOME": "/Users/YOURUSERNAME"
            }
        }
    }
}
```

> **Note:** Replace `YOURUSERNAME` with your macOS username (run `whoami` in Terminal). If you installed Node.js via nvm, replace the command path with the output of `which playwright-mcp`.

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
| `⌘ .` | Stop task |
| `⌘ ,` | Settings |
| `⌘ F` | Search activity log |
| `⌘ T` | New tab |
| `⌘ W` | Close tab |
| `/clear` | Clear conversation |

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
