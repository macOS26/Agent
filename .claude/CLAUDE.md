# Agent - macOS Autonomous Agent with Privileged Daemon

## Project Overview
A macOS SwiftUI app that uses SMAppService + a privileged Launch Daemon to give an autonomous Claude-powered agent root-level command execution. The user approves the daemon once, then the agent can execute commands autonomously via XPC.

## Build & Run
- Open `Agent.xcodeproj` in Xcode
- Two targets: **Agent** (app) and **AgentHelper** (privileged daemon tool)
- Development Team: **469UCUB275**
- Deployment target: macOS 26.0, Swift 6.0
- Build with XCF: `xcf build` (ensure Agent.xcodeproj is selected, NOT CloneTool)
- After successful xcf build, do a git commit

## Architecture

### Targets
1. **Agent** (main app) - SwiftUI app with @Observable ViewModel pattern
2. **AgentHelper** (command-line tool) - Privileged daemon that executes commands as root

### Key Files
- `Agent/AgentApp.swift` - @main entry point
- `Agent/ContentView.swift` - Main UI (header, activity log, screenshot previews, input)
- `Agent/AgentViewModel.swift` - Orchestrator: task loop, screenshots, clipboard
- `Agent/ClaudeService.swift` - Anthropic Messages API wrapper
- `Agent/HelperService.swift` - XPC client + SMAppService registration
- `Agent/HelperProtocol.swift` - Shared XPC protocol definitions
- `Agent/Models.swift` - AgentError enum + TaskHistory persistence
- `AgentHelper/main.swift` - Privileged daemon with NSXPCListener
- `Agent/LaunchDaemons/Agent.app.toddbruss.helper.plist` - Daemon configuration

### XPC Communication
- Mach service: `Agent.app.toddbruss.helper`
- HelperToolProtocol: `execute(script:instanceID:withReply:)`, `cancelOperation(instanceID:withReply:)`
- HelperProgressProtocol: `progressUpdate(_:)` for streaming output
- Uses `.privileged` option for NSXPCConnection

### Claude API Integration
- Uses Anthropic Messages API (v2023-06-01) with SSE streaming
- Tools: `execute_command` (root shell), `execute_user_command`, `task_complete`, `apple_event_query`, `run_agent_script`, etc.
- Up to 50 iterations per task
- LLM text streams token-by-token to activity log in real time
- System prompt warns that ~ = /var/root in daemon context; uses actual user home path
- Supports vision: screenshots encoded as base64 PNG in content blocks
- Task history injected into system prompt for memory across tasks

### Scripting Priority (in system prompt)
1. **apple_event_query** — zero compilation, instant ObjC dispatch for small queries
2. **run_agent_script** — native Swift AgentScriptingBridge dylibs for persistent automation
3. **NSAppleScript in scripts** — fallback if AgentScriptingBridge has issues with an app
4. **osascript via Agent app** — last resort for one-off AppleScript; runs directly in the Agent app process (not via XPC) to inherit Automation permissions
- Prefer `execute_user_command` for all tasks; only escalate to root when truly needed
- Chown/chmod files back to user after root operations

### Important Patterns
- `@Observable` with stored properties + `didSet` for UserDefaults persistence (NOT computed properties)
- API key persisted in UserDefaults under "agentAPIKey"
- Model selection persisted under "agentModel"
- Activity log persists between tasks (only clears on trash button)
- TaskHistory persists to ~/Library/Application Support/Agent/task_history.json
- Screenshot capture via `/usr/sbin/screencapture -i`
- Clipboard paste: tries NSImage, raw PNG/TIFF/JPEG data, then file URLs
- Cmd+V intercepted via NSEvent.addLocalMonitorForEvents to detect image paste

## Known Issues & Lessons
- SMAppService `.notFound` status is unreliable; always try `register()` directly
- SourceKit may report false "Cannot find type in scope" errors - trust the Xcode build
- `onPasteOf` does not exist in SwiftUI; use NSEvent monitor + dedicated paste button
- TextField ignores image data on paste; cannot detect images via onChange
- SF Symbol "stamp" doesn't exist; use "photo.on.rectangle.angled" instead
