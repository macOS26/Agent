# Agent Architecture

## Two-Target Design
The app follows Apple's privileged helper pattern (same as CloneTool):

1. **Agent** (main app bundle)
   - SwiftUI interface
   - Connects to daemon via NSXPCConnection (Mach service: "Agent.app.toddbruss.helper")
   - Registers daemon via SMAppService
   - Calls Anthropic Messages API

2. **AgentHelper** (privileged daemon)
   - Embedded in app bundle at Contents/Library/LaunchDaemons/
   - Runs as root via launchd
   - Executes bash commands via Process
   - Communicates back via XPC reply blocks

## Data Flow
```
User Input -> AgentViewModel -> ClaudeService (API call)
                                     |
                              Claude Response (tool_use: execute_command)
                                     |
                              AgentViewModel -> HelperService (XPC)
                                     |
                              AgentHelper (root Process execution)
                                     |
                              Output -> back through XPC -> ActivityLog
                                     |
                              Next API call with tool results
                                     |
                              (loop until task_complete or max iterations)
```

## Build Phases (Agent target)
1. Compile Sources
2. Copy Helper - copies AgentHelper binary to Contents/MacOS/ (dstSubfolderSpec=6)
3. Copy Daemon Plist - copies Agent.app.toddbruss.helper.plist to Contents/Library/LaunchDaemons/ (dstSubfolderSpec=1)

## XPC Protocol
```swift
@objc protocol HelperToolProtocol {
    func execute(script: String, instanceID: String, withReply reply: @escaping (Int32, String) -> Void)
    func cancelOperation(instanceID: String, withReply reply: @escaping () -> Void)
}
```

## Vision Support
- Multiple screenshots can be attached to a single task
- Captured via interactive screencapture or clipboard paste
- Encoded as base64 PNG and sent as image content blocks in the API request
- Attachments cleared after sending to API

## Task History
- Persisted as JSON array at ~/Library/Application Support/Agent/task_history.json
- Last 20 tasks injected into system prompt for cross-task memory
- Records: prompt, summary, commands run, date
