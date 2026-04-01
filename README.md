
<div align="center">
<img width="256" height="256" alt="agent_icon_256" src="https://github.com/user-attachments/assets/7a452184-6b31-49fa-9b24-d450d2889f66" />

# 🦾 Agent! Agentic AI for your  Apple Mac Desktop 🖥️
# 🪼 Cursor, Claude Code and Open Claw alternative

[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE) [![Stars](https://img.shields.io/github/stars/macos26/Agent?style=for-the-badge&color=yellow)](https://github.com/macos26/Agent/stargazers) [![Downloads](https://img.shields.io/github/downloads/macos26/Agent/total?style=for-the-badge&color=brightgreen)](https://github.com/macos26/Agent/releases)
[![Agent!](https://img.shields.io/badge/Agent!-v1.0.GM-blue?style=for-the-badge)](https://github.com/macos26/Agent) [![Website](https://img.shields.io/badge/Website-agent.macos26.com-purple?style=for-the-badge)](https://agent.macos26.com) ![Platform](https://img.shields.io/badge/Platform-macOS%2026%2B-cyan?style=for-the-badge) ![Swift](https://img.shields.io/badge/Swift-6.2-orange?style=for-the-badge)


**Tell your Mac what to do in plain English -- and watch it happen.**

[Download](https://github.com/macOS26/Agent/releases) | [Website](https://agent.macos26.com) | [Technical Docs](TECHNICAL.md) | [Comparisons](COMPARISON.md)

<img width="1058" height="672" alt="image" src="https://github.com/user-attachments/assets/f3d191de-28f8-449a-a71e-79e9b32dc81d" />

</div>

---

Agent! isn't another chatbot. It's an AI assistant that can click buttons, open apps, play music, check your email, build projects, browse the web, and automate your daily workflow. All from one app. All on your Mac.

**Free and open source.** No subscription. No account required for local AI models.

---

## See It in Action

> "Play my Workout playlist in Music"

> "Check my email for new messages"

> "Open Safari and search for the weather in San Francisco"

> "Find all PDF files in my Documents folder"

> "Take a screenshot of my desktop"

> "Create a new note with my grocery list: milk, eggs, bread, butter"

> "What calendar events do I have today?"

> "Send an iMessage to Mom saying I'll be home at 6"

Just type (or speak) what you want. Agent! figures out how to do it and makes it happen.

---

## What Makes Agent! Different

**Siri can answer questions. Agent! can do the work.**

| | Siri | Agent! |
|---|---|---|
| Open apps | Yes | Yes |
| Control 50+ Mac apps | No | Yes |
| Browse and fill out web forms | No | Yes |
| Manage your files and folders | No | Yes |
| Send iMessages on command | Limited | Yes |
| Control your Mac from your iPhone via text | No | Yes |
| Use your choice of 10 AI providers | No | Yes |
| Run completely offline with local AI | No | Yes |
| Free and open source | No | Yes |

For detailed comparisons with Claude Code, Cursor, Cline, and OpenClaw, see [COMPARISON.md](COMPARISON.md).

---

## Getting Started

### What You Need

- A Mac running **macOS 26 (Tahoe)** or later
- Apple Silicon recommended (M1, M2, M3, or M4)

### Setup in 5 Minutes

1. **Download** [Agent!](https://github.com/macOS26/Agent/releases) and move it to your Applications folder
2. **Open Agent!** -- It sets up everything automatically
3. **Pick your AI** -- Open Settings, choose a provider, and enter your API key
4. **Click Connect** in the toolbar, then **Register** to enable background services
5. **Approve** when macOS asks to allow Agent! in **System Settings > General > Login Items**
6. **Type a task and press Run** (or press Enter)

That's it. You're ready to go.

> **Don't have an API key?** Use **Local Ollama** or **LM Studio** with **GLM-5.1** -- it's completely free, runs offline, and doesn't need an account. You'll need at least 32GB of RAM for local models.

---

## Choose Your AI

Agent! works with **10 AI providers**. Pick one or try several:

| Provider | Best For | Cost |
|---|---|---|
| **GLM-5 / GLM-5.1** (via Ollama or LM Studio) | Highly recommended starting point -- great vision, reasoning, and coding | Free |
| **Claude (Anthropic)** | Complex tasks and detailed work | Paid |
| **ChatGPT (OpenAI)** | General-purpose assistant | Paid |
| **DeepSeek** | Budget-friendly cloud AI | Paid |
| **Z.ai** | Fast, versatile AI | Paid |
| **Apple Intelligence** | Built into macOS, fully private | Free |
| **Local Ollama** | Complete privacy, no internet needed | Free |
| **LM Studio** | Easy local model setup | Free |
| **Hugging Face** | Access to open-source models | Varies |
| **Ollama Cloud / vLLM** | Advanced self-hosted options | Varies |

> **Our recommendation**: Start with **GLM-5.1** on Local Ollama. It's free, private, and works great. Upgrade to Claude or ChatGPT later if you want cloud power.

---

## Key Features

### Agentic Coding -- Built In

Agent! replaces standalone coding tools like Claude Code, Cursor, Cline, and Windsurf. No terminal required. No IDE plugins. No monthly subscriptions.

| | Claude Code | Cursor | Cline | Agent! |
|---|---|---|---|---|
| Read, write, and edit code | Yes | Yes | Yes | Yes |
| Build and run Xcode projects | No | No | No | Yes |
| Git status, diff, commit, branch | Yes | Yes | Yes | Yes |
| Search files and grep across codebases | Yes | Yes | Yes | Yes |
| Multi-file refactoring | Yes | Yes | Yes | Yes |
| Coding mode (auto-focuses on code tools) | No | No | No | Yes |
| Control Mac apps while coding | No | No | No | Yes |
| 10 AI providers (local + cloud) | No | No | No | Yes |
| Voice input | No | No | No | Yes |
| Free and open source | No | No | No | Yes |

Agent! reads your codebase, edits files with surgical precision, runs shell commands, builds Xcode projects via ScriptingBridge, manages git workflows, and auto-enables coding mode to keep the LLM focused on development tools. It handles everything from single-line fixes to multi-file refactors across Swift, Python, JavaScript, and any language your AI model supports.

> "Build the project" -- Agent! compiles via Xcode, shows errors with file:line:col and code snippets, then fixes them automatically.

> "Refactor this class into smaller files" -- Agent! splits the file, updates imports, and adds each file to the Xcode project.

> "Search for all uses of this function and rename it" -- Agent! greps the codebase, edits every occurrence, and commits the change.

All coding happens alongside Agent!'s other capabilities. You can build your project, check your email, play music, and browse documentation without switching tools.

### Control 50+ Mac Apps
Open and interact with Mail, Music, Safari, Finder, Calendar, Contacts, Notes, Reminders, Messages, and dozens more -- just by asking.

### Voice Control
Click the microphone icon and speak. Agent! transcribes your voice in real time and carries out your request. Works with your Mac's language settings and is great for hands-free use.

### Remote Control from Your iPhone
Text your Mac from anywhere using iMessage:

```
Agent! What song is playing?
Agent! Check my email
Agent! Next Song
```

Your Mac runs the task and texts back the result. Only contacts you approve can send commands.

**Setup**: Toggle Messages ON in the toolbar > Click the speech bubble > Send an "Agent!" message from your iPhone > Approve your number in the recipients list. Done.

### Browse the Web
Agent! drives Safari for you -- search Google, click links, fill out forms, read pages, and extract information. All hands-free.

### Manage Your Files
Find, read, move, and organize files and folders across your Mac using plain English.

### Screenshot and Image Analysis
Agent! can see what's on your screen. Take a screenshot or paste an image, and vision-capable AI models will analyze it -- describe what they see, read text, spot UI issues, or answer questions about it.

### Smart Planning
For bigger tasks, Agent! creates a step-by-step plan, works through each step, and checks them off as it goes. Watch the progress in real time.

### Tabs
Work on multiple tasks at the same time. Each tab has its own project folder and conversation history.

### Apple Intelligence
On supported Macs, Apple Intelligence enhances your experience with:
- **Autocomplete suggestions** as you type
- **Task summaries** after each completed task
- **Wrap-up conclusions** so you know exactly what happened

All processing stays on your Mac.

---

## How It Works

```
You type or speak a request
         |
Agent! understands what you want using AI
         |
Agent! controls your Mac using built-in automation
         |
You see the result
```

No coding required. No terminal. No complex setup. Just plain English in, real action out.

---

## Privacy and Safety

**Your data stays on your Mac.** Agent! doesn't upload your files, screen contents, or personal data. When using cloud AI, only your typed prompt is sent. With local AI, nothing ever leaves your computer.

**You're in control.** Agent! shows what it's doing and asks before taking any risky action. It keeps a full log of everything it does.

**Built on Apple's security model.** Regular tasks run under your user account. System-lol level operations require your explicit approval through macOS.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Enter | Run task |
| /clear | Clear conversation history |
| Command + . | Stop task |
| Command + , | Settings |
| Command + F | Search activity log |
| Command + T | New tab |
| Command + W | Close tab |

---

## FAQ

**Do I need to know how to code?**
No. Just type what you want in plain English.

**How is this different from Siri?**
Siri answers questions. Agent! performs actions -- it can control your apps, manage files, browse the web, build software projects, and automate complex workflows using your choice of AI.

**Is it safe?**
Yes. Agent! uses standard macOS automation features, shows you what it's doing.

**Does it send my data to the cloud?**
Only if you choose a cloud AI provider, and only your prompt text is sent. Use Local Ollama or LM Studio to stay 100% offline.

**How much does it cost?**
Agent! is free and open source (MIT License). Cloud AI providers charge for API usage. Local models are completely free.

**What Mac do I need?**
Any Mac running macOS 26 or later. Apple Silicon (M1/M2/M3/M4) recommended. 32GB+ RAM needed for local AI models. Apple Intelligence recommded. AgentScript requires Xcode commamd line tools to be installed.

---

## More Documentation

- [TECHNICAL.md](TECHNICAL.md) -- Architecture, tools, scripting, and developer details
- [COMPARISON.md](COMPARISON.md) -- Detailed comparisons with Claude Code, Cursor, Cline, and OpenClaw
- [SECURITY.md](SECURITY.md) -- XPC architecture and security model

---

## License

MIT -- free and open source.

---

**Agent! -- Not just smart chat. Real action on your Mac.**
