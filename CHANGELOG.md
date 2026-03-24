# Agent! Changelog

All notable changes to the Agent! project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.21] - 2025-03-24

### Added

- Apple AI integration with 6 essential tools for context efficiency
- Plan mode for structured multi-step task execution
- File splitting workflow with extract_function and if_to_switch refactoring tools
- Xcode project management via xcode add_file/remove_file actions
- Tab tool handlers organized into 9 logical group files
- System prompt tabs colored by LLM company brand colors
- Messages monitor for iMessage remote control

### Changed

- Streamlined Apple AI defaults to 6 most important tools
- Removed task modes and Apple AI mediator tool call limit
- Improved tool groups availability - all groups always available
- Centralized all app references through AppConstants
- Enhanced error handling with recovery suggestions

### Fixed

- Green banner and Apple AI prompt visibility when other tabs selected
- EndCurrentTask crash when context has deleted objects
- Tool groups classification and mode handling
- Foundation model service initialization
- CodeBlockSyntax parsing in system prompts
- Plan step completion handling for Ollama API compatibility

### Code Quality

- Split TaskExecution into 3 logical files
- Converted all tab handler if-name blocks to switch/case
- Extracted TabTask tool handlers into dedicated file
- Removed dead TaskMode enum and unused functions

## [1.0.16] - 2025-01-21

### Added

#### New Accessibility Tools
- **`ax_highlight_element`**: Temporarily highlight an element on screen with a colored overlay. Useful for verification before actions.
- **`ax_get_window_frame`**: Get exact window position and frame (x, y, width, height) by window ID from `ax_list_windows`.

#### Enhanced Error Handling
- Expanded `AgentError` enum with 15 new error cases:
  - `timeout(seconds)`: Operation timeout with duration context
  - `serviceUnavailable(service)`: XPC service unavailable
  - `permissionDenied(permission)`: TCC permission issues
  - `toolFailed(tool, reason)`: Tool execution failures
  - `scriptError(script, message)`: Script compilation/runtime errors
  - `xpcError(service, reason)`: XPC communication failures
  - `mcpError(server, reason)`: MCP server errors
  - `accessibilityError(action, reason)`: Accessibility API failures
  - `networkError(underlying)`: Network request failures
  - `fileError(path, reason)`: File system errors
  - `notFound(item)`: Missing resources
  - `invalidInput(field, reason)`: Validation errors
  - `cancelled`: User cancellation
  - `unknown(Error)`: Wrapped errors
- Added `recoverySuggestion` property for actionable error messages
- Added `isRecoverable` property to indicate retry-safe errors

#### Structured Logging System
- New `LoggingService` with OSLog integration:
  - Category-based loggers: `agent`, `xpc`, `accessibility`, `script`, `llm`, `mcp`, `web`, `messages`, `performance`
  - Privacy-aware logging with automatic redaction
  - Performance timing helpers for operation profiling
  - Convenience methods: `logError()`, `logWarning()`, `logInfo()`, `logDebug()`
  - Async timing: `timeAsyncOperation()` for instrumenting async code

#### Keyboard Shortcuts
- **Cmd+R**: Run current task
- **Cmd+.**: Cancel current task
- **Cmd+Shift+P**: Open System Prompts
- **Cmd+Shift+M**: Toggle Messages Monitor
- **Cmd+1-9**: Switch between Main tab (1) and Script tabs (2-9)
- **Cmd+] / Cmd+[**: Navigate to next/previous tab

### Changed

#### Error Messages
- All tool error messages now include actionable recovery suggestions
- Network errors include specific status code handling (401/403/429/5xx)
- Accessibility errors indicate whether permission needs to be granted
- XPC errors suggest re-registration in Settings

#### Code Quality
- Replaced print statements with structured OSLog throughout
- Improved error propagation in AccessibilityService
- Better error context in AccessibilityService timeout handling

### Fixed

- Accessibility element lookup timeouts now return proper error messages
- Tool descriptions clarify `ax_find_element` vs `ax_wait_for_element` usage

## [1.0.15] - 2025-01-20

### Added
- User Launch Agent toggle (enable/disable from UI)
- Improved edit_file error messages with whitespace hints
- AppleEventBridges standalone build fix
- SDEF property hints in Apple Event queries
- Comprehensive README documentation for background services

### Changed
- Increased minimum window width to 900px
- Updated shutdown log messages to guide re-enabling flow

## [1.0.14] - 2025-01-19

### Added
- Initial public release
- Multi-provider LLM support (Claude, OpenAI, DeepSeek, HuggingFace, Ollama, Apple Intelligence)
- 100+ automation tools via ScriptingBridge, AppleScript, JXA, Accessibility API
- 50+ app bridges for macOS automation
- MCP client support for external tool servers
- iMessage remote control via Messages Monitor
- AgentScript dynamic Swift Package compilation
- XPC privilege separation (User Agent + Launch Daemon)

[1.0.21]: https://github.com/macOS26/Agent/compare/v1.0.20...v1.0.21
[1.0.16]: https://github.com/macOS26/Agent/compare/v1.0.15...v1.0.16
[1.0.15]: https://github.com/macOS26/Agent/compare/v1.0.14...v1.0.15
[1.0.14]: https://github.com/macOS26/Agent/releases/tag/v1.0.14