# Development History

## Initial Build
- Created from scratch following the CloneTool privileged helper pattern
- Two-target Xcode project: Agent (app) + AgentHelper (daemon)
- XPC communication with SMAppService for daemon registration
- Claude API integration with execute_command + task_complete tools

## Feature Additions (in order)

### 1. Daemon Registration Fix
- SMAppService returned .notFound even when daemon was viable
- Fix: always call register() directly, skip pre-checking status

### 2. API Key Persistence
- Originally used computed properties with UserDefaults
- @Observable doesn't track computed property changes
- Fix: switched to stored properties with didSet blocks

### 3. App Icon
- Created SVG icon: Superman-shield style with big "A" in the center
- Saved as icon.svg and added to Assets.xcassets

### 4. Task History & Memory
- Added TaskHistory singleton persisting to Application Support
- TaskRecord: prompt, summary, commandsRun, date
- History context injected into system prompt (last 20 tasks)
- HistoryView popover showing past tasks
- Activity log no longer clears between tasks (only on trash button)

### 5. Home Directory Fix
- Daemon runs as root, so ~ = /var/root
- System prompt now includes actual user home path and username
- Warning in prompt about ~ behavior

### 6. Screenshot Support
- Interactive screenshot via /usr/sbin/screencapture -i (camera button)
- Clipboard paste via dedicated button + Cmd+V interception
- Multiple screenshots supported with preview thumbnails
- Base64 PNG encoding for Claude vision API

### 7. Clipboard Paste Iterations
- Attempt 1: onPasteOf (doesn't exist in SwiftUI) - failed
- Attempt 2: onCommand(#selector(NSResponder.paste(_:))) - failed
- Attempt 3: NSEvent.addLocalMonitorForEvents for Cmd+V - works
- Added dedicated paste button as reliable fallback
- Paste tries: NSImage objects, raw PNG/TIFF/JPEG data, file URLs

### 8. AccentColor Asset
- Build warning about missing AccentColor
- Created AccentColor.colorset/Contents.json with universal idiom

### 9. Project Migration
- Moved from ~/Agent/ to ~/Documents/Github/Agent/ via rsync
- Set up as git repository

## Build Issues
- XCF kept building CloneTool instead of Agent (wrong project selected)
- Fix: explicitly select Agent.xcodeproj via mcp__xcf-server__select_project
