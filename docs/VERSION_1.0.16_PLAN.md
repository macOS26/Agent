# Agent! Version 1.0.16 Development Plan

## Code Review Summary

### Architecture Overview

Agent! is a sophisticated macOS automation platform built with:

- **SwiftUI Frontend** (`AgentXcode/Agent/`) - Main app with ~20 views
- **XPC Services** - User-level and root-level command execution
- **LLM Providers** - Claude, OpenAI, DeepSeek, HuggingFace, Ollama Cloud, Local Ollama, Apple Intelligence
- **Automation Stack**:
  - 50+ ScriptingBridges for app automation
  - 22 Accessibility API tools
  - 31 bundled AgentScripts (Swift dylibs)
  - AppleEvent queries for dynamic app control
  - MCP (Model Context Protocol) client for extensibility

### Key Services (by size)

| Service | Lines | Purpose |
|---------|-------|---------|
| AccessibilityService.swift | ~1500 | AXUIElement API for UI automation |
| AgentTools.swift | ~1235 | System prompt + tool definitions |
| AgentViewModel.swift | ~1367 | Main view model + Messages monitor |
| ScriptService.swift | ~700 | Swift Package script management |
| FoundationModelService.swift | ~800 | Apple Intelligence integration |
| OllamaService.swift | ~460 | Ollama API client |
| WebAutomationService.swift | ~470 | Unified web automation |
| AppleEventService.swift | ~380 | Dynamic Apple Event queries |

### Recent Changes (v1.0.15)

1. **User Launch Agent Toggle** - Added ability to enable/disable the User Agent from UI
2. **Improved edit_file Error Messages** - Better hints for whitespace/indentation issues
3. **AppleEventBridges Standalone Build** - Fixed package structure
4. **SDEF Property Hints** - Added property suggestions to Apple Event queries
5. **Documentation Updates** - Comprehensive README improvements

### Current Strengths

1. **Multi-Provider LLM Support** - 7 providers with seamless switching
2. **Comprehensive Automation** - ScriptingBridge, AppleScript, JXA, Accessibility, Selenium
3. **Security Model** - Proper XPC privilege separation, TCC handling
4. **Extensibility** - AgentScripts, MCP servers, Saved Scripts
5. **Messages Monitor** - Remote control via iMessage
6. **Accessibility** - Full AXUIElement API coverage

---

## v1.0.16 Implementation Status

### ✅ Completed Tasks

#### Sprint 1: Foundation

1. **✅ Enhanced Error Types and Recovery**
   - Created expanded `AgentError` enum with 17 error cases
   - Added `timeout`, `serviceUnavailable`, `permissionDenied`, `toolFailed`, `scriptError`, `xpcError`, `mcpError`, `accessibilityError`, `networkError`, `fileError`, `notFound`, `invalidInput`, `cancelled`, `unknown` cases
   - Added `recoverySuggestion` property for actionable error messages
   - Added `isRecoverable` property to indicate retry-safe errors

2. **✅ Structured Logging System**
   - Created `LoggingService.swift` with OSLog integration
   - Category-based loggers: `agent`, `xpc`, `accessibility`, `script`, `llm`, `mcp`, `web`, `messages`, `performance`
   - Privacy-aware logging with automatic redaction
   - Performance timing helpers: `timeOperation()` and `timeAsyncOperation()`
   - Convenience methods: `logError()`, `logWarning()`, `logInfo()`, `logDebug()`

#### Sprint 2: Accessibility Enhancements

3. **✅ New Tool: `ax_highlight_element`**
   - Highlight an element on screen with a colored overlay
   - Configurable duration (default 2.0 seconds)
   - Color options: red, green, blue, yellow, purple
   - Position-based or role/title-based element finding
   - Returns element bounds in response

4. **✅ New Tool: `ax_get_window_frame`**
   - Get exact window position and frame by window ID
   - Returns x, y, width, height for precise positioning
   - Useful for screenshot positioning and click targeting

5. **✅ Tool Definitions Updated**
   - Added `ax_highlight_element` and `ax_get_window_frame` to AgentTools.swift
   - Added tool examples for Apple AI compact prompts
   - Updated system prompt documentation

#### Sprint 4: User Experience

6. **✅ Keyboard Shortcuts**
   - Cmd+R: Run current task
   - Cmd+.: Cancel current task
   - Cmd+Shift+P: Open System Prompts (Settings)
   - Cmd+Shift+M: Toggle Messages Monitor
   - Cmd+1-9: Switch between Main tab (1) and Script tabs (2-9)
   - Cmd+]/Cmd+[: Navigate to next/previous tab

7. **✅ Version Bump**
   - MARKETING_VERSION: 1.0.15 → 1.0.16
   - CURRENT_PROJECT_VERSION: 16 → 17
   - README.md version badge updated

8. **✅ Documentation**
   - Created CHANGELOG.md with version history
   - Updated VERSION_1.0.16_PLAN.md with implementation status

---

## Remaining Work (Future Versions)

### Priority 2: New Features

#### Web Automation Improvements
- **Enhanced `web_find`**: Fuzzy matching for text content
- **New Tool: `web_wait_for_url`**: Wait for URL to match pattern (OAuth flows)
- **Retry with adaptive polling**: Better handling of dynamic pages

#### Task Management
- **New Tool: `task_queue`**: Queue multiple tasks for sequential execution
- **New Tool: `task_template`**: Save and load task templates

### Priority 3: Performance & Stability

#### MCP Server Reliability
- Heartbeat ping every 30 seconds
- Auto-restart on connection loss
- Show connection health indicator

#### Script Compilation Improvements
- Background compilation queue with progress callbacks
- Cache compiled dylibs by source hash
- Add compilation status to UI

### Priority 4: Developer Experience

#### AgentScript Improvements
- Add script templates for common patterns
- Add import suggestions based on SDEF lookup
- Add script debugger with breakpoints
- Add unit test runner for scripts

#### Bridge Generation
- Auto-generate bridges for new app versions
- Add bridge validation tests
- Add documentation generator from SDEF

---

## Version Bump Checklist

- [x] Update `MARKETING_VERSION` to 1.0.16 in project.pbxproj
- [x] Update `CURRENT_PROJECT_VERSION` to 17
- [x] Update README.md version badge
- [x] Create CHANGELOG.md with new features
- [ ] Create Git tag `v1.0.16`
- [ ] Build DMG for distribution
- [ ] Update GitHub release notes

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Accessibility API changes in macOS | Low | High | Test on beta macOS versions |
| Script compilation failures | Medium | Medium | Add compilation error recovery |
| MCP server protocol changes | Low | Medium | Pin server versions |
| Memory pressure with large contexts | Medium | Medium | Implement context compression |

---

## Success Metrics

- Tool execution success rate: >95%
- Script compilation time: <3s (cached: <100ms)
- MCP server uptime: >99.5%
- Accessibility action accuracy: >98%
- User-reported bugs: <5 per week

---

## Conclusion

Version 1.0.16 delivers significant improvements in **error handling, logging infrastructure, accessibility tools, and user experience**. The new structured error types provide actionable guidance, the logging service enables better debugging, and the two new accessibility tools (`ax_highlight_element`, `ax_get_window_frame`) enhance UI automation capabilities. Keyboard shortcuts improve workflow efficiency for power users.

All planned Sprint 1 (Foundation) and Sprint 2 (Accessibility) items have been completed, along with keyboard shortcuts from Sprint 4. Web automation improvements and MCP server reliability remain for future versions.