
<div align="center">
<img width="256" height="256" alt="Agent! icon" src="https://github.com/user-attachments/assets/7a452184-6b31-49fa-9b24-d450d2889f66" />

# Agent! for macOS

### AI for your  Mac Desktop

[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE) [![Stars](https://img.shields.io/github/stars/macos26/Agent?style=for-the-badge&color=yellow)](https://github.com/macos26/Agent/stargazers) [![Downloads](https://img.shields.io/github/downloads/macos26/Agent/total?style=for-the-badge&color=brightgreen)](https://github.com/macos26/Agent/releases)
[![Agent!](https://img.shields.io/badge/Agent!-v1.0.GM-blue?style=for-the-badge)](https://github.com/macos26/Agent) [![Website](https://img.shields.io/badge/Website-agent.macos26.com-purple?style=for-the-badge)](https://agent.macos26.com) ![Platform](https://img.shields.io/badge/Platform-macOS%2026%2B-cyan?style=for-the-badge) ![Swift](https://img.shields.io/badge/Swift-6.2-orange?style=for-the-badge)

**Your AI-powered Mac assistant that works autonomously.**
**Build apps, write code, manage files, and automate workflows.**
**All through natural language. 100% native Swift. Zero Electron overhead.**

[Download](https://github.com/macOS26/Agent/releases) | [Website](https://agent.macos26.com) | [Documentation](docs/)

<img width="1058" height="672" alt="Agent! screenshot" src="https://github.com/user-attachments/assets/f3d191de-28f8-449a-a71e-79e9b32dc81d" />

</div>

---

## Tell Your Mac What To Do

Agent! isn't a chatbot. It's an autonomous AI assistant that takes action on your Mac. Click buttons, open apps, play music, check email, build Xcode projects, browse the web, and automate your entire workflow -- all from one app.

**Free and open source.** No subscription. No account required for local AI models.

---

## Quick Start

1. **Download** [Agent!](https://github.com/macOS26/Agent/releases) and drag to Applications
2. **Open Agent!** -- it sets up everything automatically
3. **Pick your AI** -- Settings > choose a provider > enter API key
4. **Type a task and press Enter**

> **No API key?** Use **Ollama** with **GLM-5** -- completely free, runs offline, no account needed. Requires 32GB+ RAM.

---

## What Can It Do?

> "Play my Workout playlist in Music"

> "Build the Xcode project and fix any errors"

> "Take a photo with Photo Booth"

> "Send an iMessage to Mom saying I'll be home at 6"

> "Open Safari and search for flights to Tokyo"

> "Refactor this class into smaller files"

> "What calendar events do I have today?"

Just type what you want. Agent! figures out how and makes it happen.

---

## Key Features

### Agentic Coding
Full coding environment built in. Reads codebases, edits files with precision, runs shell commands, builds Xcode projects, manages git, and auto-enables coding mode to focus the AI on development tools. Replaces Claude Code, Cursor, and Cline -- no terminal, no IDE plugins, no monthly fee.

### Desktop Automation (AXorcist)
Control any Mac app through the Accessibility API. Click buttons, type into fields, navigate menus, scroll, drag -- all programmatically. Powered by [AXorcist](https://github.com/steipete/AXorcist) for reliable, fuzzy-matched element finding.

### 10 AI Providers
| Provider | Cost | Best For |
|---|---|---|
| **GLM-5 / GLM-5.1** (Ollama) | Free | Recommended starting point |
| **Claude** (Anthropic) | Paid | Complex tasks |
| **ChatGPT** (OpenAI) | Paid | General purpose |
| **Apple Intelligence** | Free | On-device, private |
| **DeepSeek** | Paid | Budget cloud AI |
| **Local Ollama** | Free | Full privacy, offline |
| **LM Studio** | Free | Easy local setup |
| **Hugging Face** | Varies | Open-source models |
| **Z.ai** | Paid | Fast, versatile |
| **Ollama Cloud / vLLM** | Varies | Self-hosted |

### Voice Control
Click the microphone and speak. Agent! transcribes in real time and executes your request.

### Remote Control via iMessage
Text your Mac from your iPhone:
```
Agent! What song is playing?
Agent! Check my email
Agent! Next Song
```
Your Mac runs the task and texts back the result. Only approved contacts can send commands.

### Web Automation
Drives Safari hands-free -- search Google, click links, fill forms, read pages, extract information.

### Smart Planning
For complex tasks, Agent! creates a step-by-step plan, works through each step, and checks them off in real time.

### Tabs
Work on multiple tasks simultaneously. Each tab has its own project folder and conversation history.

### Screenshot & Vision
Take screenshots or paste images. Vision-capable AI models analyze what they see -- describe content, read text, spot UI issues.

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
| Enter | Run task |
| Command + . | Stop task |
| Command + , | Settings |
| Command + F | Search activity log |
| Command + T | New tab |
| Command + W | Close tab |
| /clear | Clear conversation |

---

## FAQ

**Do I need to know how to code?** No. Just type what you want in plain English.

**Is it safe?** Yes. Standard macOS automation, full activity logging, you approve permissions.

**How much does it cost?** Agent! is free (MIT License). Cloud AI providers charge for API usage. Local models are free.

**What Mac do I need?** macOS 26+. Apple Silicon recommended. 32GB+ RAM for local models.

**How is this different from Siri?** Siri answers questions. Agent! performs actions -- controls apps, manages files, builds code, automates workflows.

---

## Documentation

- [Technical Architecture](docs/TECHNICAL.md) -- Tools, scripting, developer details
- [Comparisons](docs/COMPARISON.md) -- vs Claude Code, Cursor, Cline, OpenClaw
- [Security Model](docs/SECURITY.md) -- XPC architecture, privilege separation
- [FAQ](docs/FAQ.md) -- Common questions

---

## License

MIT -- free and open source.

---

<div align="center">

**Agent! -- Not just smart chat. Real action on your Mac.**

</div>
