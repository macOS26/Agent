# Agent! -- Your AI Assistant for Mac

**Agent!** is an AI-powered desktop assistant built exclusively for macOS. Unlike chatbots that just talk, Agent! can actually *do things* on your Mac -- click buttons, open apps, build projects, send messages, browse the web, and automate your daily tasks. Everything runs on your computer, so your data stays private.

---

## What Can Agent! Do?

Think of Agent! as a smart assistant sitting at your keyboard. Just tell it what you want in plain English:

- **Control Your Apps** -- Open and interact with over 50 Mac apps including Mail, Music, Safari, Finder, Calendar, Contacts, Notes, Reminders, and more
- **Build Software** -- Open Xcode projects, build them, run them, and review code for issues
- **Browse the Web** -- Open Safari, search Google, click links, fill out forms, and read web pages
- **Manage Files** -- Read, write, search, and organize files and folders on your Mac
- **Send Messages** -- Send and receive iMessages, even control your Mac remotely from your iPhone
- **Run Scripts** -- Execute AppleScript, JavaScript, and Swift automations on demand
- **Use Your Voice** -- Speak your commands instead of typing them
- **See Your Screen** -- Analyze screenshots and images to understand what's on your display
- **Work in Tabs** -- Run multiple tasks at the same time, each in its own tab with its own project folder
- **Retro Terminal Look** -- A slick green-on-black terminal display for AI output, complete with box-drawn tables

---

## Choose Your AI

Agent! works with **10 AI providers** so you can pick whatever suits your needs and budget:

| Provider | Type | Best For |
|---|---|---|
| **Claude (Anthropic)** | Cloud | Complex tasks and detailed work |
| **ChatGPT (OpenAI)** | Cloud | General-purpose assistant |
| **DeepSeek** | Cloud | Budget-friendly option |
| **Z.ai** | Cloud | Fast, versatile AI models |
| **Hugging Face** | Cloud | Open-source models |
| **Ollama Cloud** | Cloud | Managed cloud hosting |
| **Local Ollama** | Runs on your Mac | Complete privacy, no internet needed |
| **vLLM** | Local or Cloud | Self-hosted option |
| **LM Studio** | Runs on your Mac | Easy local model setup |
| **Apple Intelligence** | On-device | Built into macOS, fully private |

**Highly Recommended Starting Point**: **GLM-5** or **GLM-5.1** -- free, open-source models with excellent vision, reasoning, and coding abilities. Works great with Local Ollama or LM Studio and is the best way to get started.

**Plus**: Apple Intelligence integration provides smart autocomplete suggestions, task summaries, and wrap-up conclusions as you work.

> **Tip**: If privacy is your top priority, use **Local Ollama** or **LM Studio** -- everything stays on your Mac with no internet required. You'll need a Mac with at least 32GB of RAM for local models (64GB or more recommended).

---

## Voice Control

Control Agent! hands-free using your voice:

- **Speak naturally** -- Click the microphone icon in the toolbar and talk
- **Real-time transcription** -- Your words are instantly converted to text and sent to the AI
- **Works with your language** -- Uses your Mac's built-in speech recognition settings
- **Perfect for accessibility** -- Great for hands-free operation or when you're away from the keyboard

Just click the mic, say what you want, and Agent! does the rest.

---

## Remote Control from Your iPhone

One of Agent!'s most unique features is **iMessage remote control**. You can text your Mac from your iPhone and have it do things for you:

```
Agent! What song is playing?
Agent! Build my Xcode project
Agent! Check my email
Agent! Next Song
```

Your Mac will carry out the task and text you back with the result (up to 256 characters). Everything runs locally -- Agent! reads your Messages database directly on your Mac with no external services.

### How to Set It Up

1. Toggle **Messages** ON in the toolbar
2. Click the speech bubble icon to open the Messages Monitor
3. Send a message starting with **Agent!** from your iPhone
4. Your phone number appears in the recipients list -- toggle it ON to approve
5. From now on, any **Agent!** message from that contact will automatically run as a task

You control exactly who can send commands. Unapproved messages are ignored. Use the filter to monitor messages from others, from yourself (great for testing between your own devices), or both.

---

## Getting Started

### What You Need

- A Mac running **macOS 26 (Tahoe)** or later
- An API key from your preferred AI provider (or use a free local model)
- Xcode Command Line Tools (Agent! will prompt you to install them if missing)

### Quick Setup

1. **Download** Agent! from the [Releases page](https://github.com/macOS26/Agent/releases) and move it to your Applications folder
2. **Open Agent!** -- It will set up its folders automatically
3. **Pick your AI** -- Open Settings, choose a provider, and enter your API key
4. **Enable services** -- Click **Connect** in the toolbar, then **Register** to install the background helpers
5. **Approve in System Settings** -- macOS will ask you to allow Agent!'s background services in **System Settings > General > Login Items**
6. **Start using it!** -- Type a request and press **Run** (or Command+Enter)

### Want to Run AI Locally? (Optional)

1. Install [Ollama](https://ollama.ai) on your Mac
2. Open Terminal and type: `ollama pull llama3.2`
3. In Agent! Settings, set Provider to **Local Ollama** and Model to **llama3.2**

Now everything runs 100% offline on your Mac.

---

## Things to Try

Here are some everyday tasks you can ask Agent! to do:

> "Open Safari and search for the weather in San Francisco"

> "Check my email for new messages"

> "Play my Workout playlist in Music"

> "Find all PDF files in my Documents folder"

> "Take a screenshot of my desktop"

> "Create a new note with my grocery list: milk, eggs, bread, butter"

> "Build my Xcode project and tell me if there are errors"

> "What calendar events do I have today?"

> "Send an iMessage to Mom saying I'll be home at 6"

---

## Smart Planning

For bigger tasks, Agent! can create a **step-by-step plan** before it starts working. It breaks complex requests into smaller steps, works through them one by one, and checks off each step as it goes. You can watch the progress in real time.

---

## How It Works (The Simple Version)

```
You type or speak a request in plain English
         |
Agent! figures out what you want using AI
         |
Agent! uses Mac's built-in automation tools to do it
         |
You see the result right in the app
```

Agent! is like a translator between you and your Mac. You speak English, and it turns your words into actions.

---

## Apple Intelligence

If your Mac supports Apple Intelligence (macOS 26+), Agent! uses it to make your experience smoother:

- **Autocomplete Suggestions** -- Predicts what you want to do next and offers task suggestions as you type
- **Task Summaries** -- Writes clear summaries of what was accomplished after each task
- **Wrap-Up Conclusions** -- Provides helpful conclusions when tasks finish, so you know exactly what happened
- All processing happens **on your Mac** -- nothing leaves your device

Enable it in **Settings > Apple Intelligence**.

---

## Privacy and Safety

**Your data stays on your Mac.** Agent! runs locally and doesn't upload your files, screen contents, or personal data anywhere. When you use a cloud AI provider, only your typed prompt is sent to that service.

**You're always in control.** Agent! shows you what it's doing and asks for approval before taking potentially risky actions. It can't delete system files or make dangerous changes without your say-so.

**Security built in.** Agent! follows Apple's recommended security practices. Regular tasks run under your user account. Only specific system-level operations (like installing packages) use elevated permissions, and macOS asks for your approval first.

---

## Keyboard Shortcuts

| Shortcut | What It Does |
|---|---|
| Command + Enter | Run your task |
| Command + . | Stop a running task |
| Command + , | Open Settings |
| Command + F | Search the activity log |
| Command + T | New tab |
| Command + W | Close tab |

---

## Frequently Asked Questions

**Do I need to know how to code?**
Not at all. Just type what you want in plain English. Agent! handles all the technical work.

**Is it safe?**
Yes. Agent! uses standard macOS automation features. It shows you what it's doing and asks before taking any risky actions.

**Does it send my data to the cloud?**
Only your typed prompt goes to cloud AI providers. Use Local Ollama or LM Studio to keep everything 100% offline.

**Can it break my Mac?**
Agent! is designed to be cautious. It won't delete important files or make system changes without your approval. Most actions can be undone with Command+Z.

**What if the AI makes a mistake?**
You can stop any task with Command+Period. Most changes to files and apps can be undone. Agent! also keeps a log of everything it does.

**How much does it cost?**
Agent! itself is free and open source (MIT License). You only pay for the cloud AI provider you choose. Using local models with Ollama or LM Studio is completely free.

**What Mac do I need?**
Any Mac running macOS 26 or later. Apple Silicon (M1/M2/M3/M4) is recommended. For running AI locally, you'll want at least 32GB of RAM.

---

## License

MIT -- free and open source.

---

**Agent! -- Real AI power for your Mac. Not just smart chat -- real action.**
