# Accessibility Automation Assessment for Agent!

**Branch:** `exp_accessibility`  
**Date:** March 2026  
**Status:** Phase 6 In Progress 🔄

---

## Implementation Status

### Phase 1: ✅ Complete (Read-Only Operations)
- `ax_check_permission` — Check Accessibility permission status
- `ax_request_permission` — Request Accessibility permission from user
- `ax_list_windows` — List all visible windows with metadata
- `ax_inspect_element` — Inspect accessibility element at screen coordinates
- `ax_get_properties` — Get properties of element by role/title/position

### Phase 2: ✅ Complete (Input Simulation)
- `ax_type_text` — Type text via CGEvent keyboard simulation
- `ax_click` — Mouse click simulation (left/right/middle, single/double)
- `ax_scroll` — Scroll wheel simulation at coordinates
- `ax_press_key` — Key press with optional modifiers (Cmd, Option, Control, Shift)
- `ax_perform_action` — AXUIElementPerformAction for native accessibility actions (requires `allowWrites=true`)

### Phase 4: ✅ Complete (Screenshot Integration)
- `ax_screenshot` — Capture screen region or window (requires Screen Recording permission)
  - Supports fullscreen capture, window capture by ID, and region capture by coordinates
  - Returns path to PNG file for inline display in activity log

### Phase 5: ✅ Complete (Security Hardening)
- Rate limiting — 50ms minimum interval between accessibility actions
- Audit logging — All accessibility operations logged to `~/Documents/Agent/accessibility_audit.log`
- `ax_get_audit_log` — Retrieve recent audit log entries
- Password field blocking — Secure text fields are protected from reading/interaction
- Action filtering — Dangerous operations blocked without `allowWrites=true`

---

## Executive Summary

This document assesses the feasibility, architecture, and implementation strategy for adding **Accessibility (AXUIElement) automation** to Agent! as an experimental feature. Accessibility automation would enable the AI agent to:

- Inspect and interact with any macOS UI element (including non-scriptable apps)
- Simulate keyboard and mouse input
- Read screen contents via accessibility APIs
- Automate apps that don't support AppleScript/ScriptingBridge

This is a significant capability expansion that requires careful security and privacy considerations.

---

## Current State of Automation in Agent!

### What Agent! Already Has

| Capability | Implementation | TCC Permission Required |
|------------|----------------|-------------------------|
| **AppleScript/osascript** | `apple_event_query`, `execute_user_command` | Automation |
| **ScriptingBridge** | Agent scripts (dylibs), `apple_event_query` | Automation |
| **Xcode control** | `xcode_build`, `xcode_run`, XcodeService | Automation |
| **Shell commands** | `execute_user_command` (user), `execute_command` (root) | None |
| **File operations** | `read_file`, `write_file`, `edit_file`, etc. | None |

### What's Missing: Accessibility Automation

Agent! can control **scriptable** apps via AppleScript/ScriptingBridge, but **cannot**:

1. **Interact with non-scriptable apps** — Many modern macOS apps (especially SwiftUI-based) don't expose AppleScript dictionaries
2. **Simulate keyboard input** — No way to type text into text fields
3. **Simulate mouse clicks** — No way to click buttons that aren't accessible via AppleScript
4. **Read screen layout** — Cannot determine UI element positions for apps without scripting support
5. **Perform UI inspections** — Cannot query the accessibility tree

### Why This Matters

- **Safari Web Content**: AppleScript can control Safari tabs, but not web page content
- **Third-Party Apps**: Many Electron-based apps (VS Code, Slack, Discord) have limited AppleScript support
- **Modern SwiftUI Apps**: Often lack comprehensive AppleScript dictionaries
- **UI Testing**: Automated testing of app UIs requires accessibility APIs
- **Screen Readers**: Reading on-screen content requires AXUIElement access

---

## Proposed Architecture

### New Service: `AccessibilityService.swift`

```
Agent.app (SwiftUI)
    |
    |-- AccessibilityService     AXUIElement queries + input simulation
    |       |
    |       |-- AXUIElement API  (inspect UI hierarchy)
    |       |-- CGEvent API      (keyboard/mouse simulation)
    |       |-- AXTextMarker API (text navigation in documents)
    |
    |-- apple_event_query       (existing — for scriptable apps)
    |-- run_agent_script        (existing — compiled dylibs)
```

### New Agent Tools

| Tool | Description | Use Case |
|------|-------------|----------|
| `ax_list_windows` | List all windows with bounds, title, app | Find windows to interact with |
| `ax_inspect_element` | Query accessibility tree at point or by path | Discover UI structure |
| `ax_get_value` | Read text/value from accessible element | Extract content from UI |
| `ax_perform_action` | Trigger action (click, press, etc.) | Interact with UI elements |
| `ax_type_text` | Simulate keyboard input | Type into text fields |
| `ax_click` | Simulate mouse click at coordinates | Click buttons/menus |
| `ax_screenshot` | Capture screen region (requires Screen Recording) | Visual context for AI |

### TCC Permissions Required

| Permission | API | When Required |
|------------|-----|---------------|
| **Accessibility** | AXUIElement, AXUIElementCopyAttributeValue | Reading/interacting with other app UIs |
| **Screen Recording** | CGWindowListCreateImage | Taking screenshots |
| **Automation** | Existing ScriptingBridge | Controlling scriptable apps |

---

## Security Considerations

### High-Risk Capabilities

Accessibility automation is **inherently powerful**:

1. **Keystroke Logging Risk** — `ax_type_text` could be misused to capture passwords
2. **UI Redirection Attacks** — Malicious prompts could trick AI into clicking dangerous UI elements
3. **Data Exfiltration** — Reading any text from any window (including passwords in plaintext)
4. **Privilege Escalation** — Clicking "Allow" in Security & Privacy preferences

### Proposed Safeguards

#### 1. **Explicit User Consent (Required)**

```swift
// User must explicitly enable accessibility features
@AppStorage("accessibilityEnabled") var accessibilityEnabled = false

func enableAccessibility() async -> Bool {
    // Check if we already have permission
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    let trusted = AXIsProcessTrusted()
    
    if !trusted {
        // Prompt user to enable in System Settings
        // Accessibility requires explicit opt-in
    }
    return trusted
}
```

#### 2. **Sandboxed Operations**

```swift
// Restrict what actions can be performed
enum AXAction: String, CaseIterable {
    case click = "AXPress"
    case press = "AXPress"
    case increment = "AXIncrement"
    case decrement = "AXDecrement"
    case confirm = "AXConfirm"
    case cancel = "AXCancel"
    case expand = "AXExpand"
    case collapse = "AXCollapse"
    // Dangerous actions are BLOCKED:
    // case delete = "AXDelete" // ❌ Not allowed
}
```

#### 3. **Prompt-Level Filtering**

The AI system prompt must instruct the LLM to:

- Never use accessibility to interact with password fields
- Never click "Allow" or "OK" in security dialogs without explicit user instruction
- Never extract sensitive data from other apps' windows
- Always explain what it's about to do before performing actions

#### 4. **Audit Logging**

All accessibility operations should be logged:

```
[ACCESSIBILITY] ax_click at (450, 320) in window "Safari"
[ACCESSIBILITY] ax_type_text "hello@world.com" in field "Email"
[ACCESSIBILITY] BLOCKED: attempt to read password field
[ACCESSIBILITY] BLOCKED: attempt to click "Allow" in "Security" dialog
```

#### 5. **Rate Limiting**

```swift
// Prevent rapid-fire automation attacks
private var lastActionTime: Date = .distantPast
private let minActionInterval: TimeInterval = 0.1 // 100ms minimum between actions

func performAction(_ action: AXAction, on element: AXUIElement) -> Bool {
    let now = Date()
    guard now.timeIntervalSince(lastActionTime) >= minActionInterval else {
        return false // Rate limited
    }
    lastActionTime = now
    // ... perform action
}
```

---

## Implementation Plan

### Phase 1: Core Infrastructure (Estimated: 2-3 days)

1. **Create `AccessibilityService.swift`**
   - AXUIElement wrapper with safe error handling
   - Permission checking via `AXIsProcessTrusted()`
   - Basic element inspection (get windows, get children, get attributes)

2. **Add to `AgentTools.swift`**
   - Define new tools in system prompt
   - Document security considerations

3. **Implement in `AgentViewModel+TaskExecution.swift`**
   - Tool dispatch for accessibility tools
   - Permission prompts when tools are first used

### Phase 2: Element Inspection (Estimated: 1-2 days)

4. **`ax_list_windows`** — List all visible windows with metadata
5. **`ax_inspect_element`** — Query element at point or by path
6. **`ax_get_value`** — Extract text/values from elements

### Phase 3: Input Simulation (Estimated: 2-3 days)

7. **`ax_type_text`** — CGEvent keyboard simulation
8. **`ax_click`** — CGEvent mouse simulation with coordinate mapping
9. **`ax_perform_action`** — AXUIElementPerformAction for native actions

### Phase 4: Screenshot Integration (Estimated: 1 day)

10. **`ax_screenshot`** — Integrate with existing screenshot workflow
    - Reuse existing vision attachment handling
    - Requires Screen Recording permission

### Phase 5: Security Hardening (Estimated: 2-3 days)

11. **Action filtering** — Block dangerous operations
12. **Prompt filtering** — Update system prompt with accessibility rules
13. **Audit logging** — Comprehensive operation logging
14. **Rate limiting** — Prevent abuse

### Phase 6: 🔄 In Progress (Testing & Documentation)
    
    15. **Unit tests** — ✅ AccessibilityServiceTests.swift created
        - Permission tests (hasAccessibilityPermission, requestAccessibilityPermission)
        - Window listing tests (JSON structure, limit, permission handling)
        - Element inspection tests (coordinates, depth, fallback)
        - Element properties tests (role/title search, JSON output)
        - Action tests (blocked actions, target requirements)
        - Input simulation tests (typeText, clickAt, scrollAt, pressKey)
        - Screenshot tests (region, window, fullscreen)
        - Rate limiting tests
        - Audit log tests
        - Security tests (blocked roles, blocked actions)
        - Integration smoke tests
    16. **Integration tests** — Planned (test with real apps: Safari, Finder, Notes)
    17. **Documentation** — Planned (README updates, ACCESSIBILITY.md guide)

---

## API Design

### Tool Definitions

```swift
ToolDef(
    name: "ax_list_windows",
    description: "List all visible windows with their bounds, title, and owning application. Requires Accessibility permission.",
    properties: [
        "filter": ["type": "string", "description": "Optional filter: 'visible' (default), 'all', 'focused'"],
    ],
    required: []
)

ToolDef(
    name: "ax_inspect_element",
    description: "Inspect the accessibility tree at a screen coordinate or by traversing from a window. Returns element properties like role, value, title, and children.",
    properties: [
        "x": ["type": "integer", "description": "X coordinate (screen-relative)"],
        "y": ["type": "integer", "description": "Y coordinate (screen-relative)"],
        "window_id": ["type": "integer", "description": "Optional window ID to traverse from root"],
        "max_depth": ["type": "integer", "description": "Maximum traversal depth (default 5)"],
    ],
    required: [] // Either x,y or window_id
)

ToolDef(
    name: "ax_get_value",
    description: "Read the value or text content from an accessibility element. BLOCKED for password fields.",
    properties: [
        "x": ["type": "integer", "description": "X coordinate of the element"],
        "y": ["type": "integer", "description": "Y coordinate of the element"],
    ],
    required: ["x", "y"]
)

ToolDef(
    name: "ax_perform_action",
    description: "Perform an accessibility action on an element. Available actions: click, press, increment, decrement, confirm, cancel.",
    properties: [
        "x": ["type": "integer", "description": "X coordinate of the element"],
        "y": ["type": "integer", "description": "Y coordinate of the element"],
        "action": ["type": "string", "description": "Action to perform: click, press, increment, decrement, confirm, cancel"],
    ],
    required: ["x", "y", "action"]
)

ToolDef(
    name: "ax_type_text",
    description: "Simulate typing text into the focused element or at coordinates. Uses CGEvent keyboard simulation.",
    properties: [
        "text": ["type": "string", "description": "Text to type"],
        "x": ["type": "integer", "description": "Optional X coordinate to click first"],
        "y": ["type": "integer", "description": "Optional Y coordinate to click first"],
    ],
    required: ["text"]
)

ToolDef(
    name: "ax_click",
    description: "Simulate a mouse click at screen coordinates.",
    properties: [
        "x": ["type": "integer", "description": "X coordinate (screen-relative)"],
        "y": ["type": "integer", "description": "Y coordinate (screen-relative)"],
        "button": ["type": "string", "description": "Mouse button: 'left' (default), 'right', 'middle'"],
        "clicks": ["type": "integer", "description": "Number of clicks: 1 (default), 2 for double-click"],
    ],
    required: ["x", "y"]
)
```

---

## Example Use Cases

### Use Case 1: Clicking a Non-Scriptable Button

```json
// AI receives: "Click the 'Submit' button in the Electron app"
// AI calls:
{
    "tool": "ax_list_windows",
    "filter": "visible"
}
// Gets window list, finds the Electron app window
// Then:
{
    "tool": "ax_inspect_element",
    "window_id": 12345,
    "max_depth": 10
}
// Traverses accessibility tree, finds button with title "Submit"
// Then:
{
    "tool": "ax_perform_action",
    "x": 450,
    "y": 320,
    "action": "click"
}
```

### Use Case 2: Typing into a Web Form

```json
// AI receives: "Fill the login form with email test@example.com"
// AI calls:
{
    "tool": "ax_click",
    "x": 200,
    "y": 300
}
// Clicks the email field
// Then:
{
    "tool": "ax_type_text",
    "text": "test@example.com"
}
```

### Use Case 3: Reading Text from a Non-Scriptable App

```json
// AI receives: "What does the status bar say?"
// AI calls:
{
    "tool": "ax_list_windows"
}
// Finds the app window
// Then:
{
    "tool": "ax_inspect_element",
    "window_id": 12345
}
// Finds the status bar element
// Then:
{
    "tool": "ax_get_value",
    "x": 600,
    "y": 50
}
// Returns: "Status: Connected • 3 active users"
```

---

## Risk Assessment

### High Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Password field access | Medium | Critical | Block `ax_get_value` for secure fields |
| Security dialog clicking | Low | Critical | Block clicking in "Security" windows |
| Keystroke logging | Low | High | Audit logging, rate limiting |
| Data exfiltration | Medium | High | Prompt-level warnings, audit logs |

### Medium Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-------------|
| App instability | Medium | Medium | Graceful error handling |
| Permission confusion | Medium | Low | Clear permission prompts |
| Race conditions | Low | Medium | Rate limiting, operation queuing |

### Low Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-------------|
| API changes | Low | Medium | Version-specific code paths |
| Performance impact | Low | Low | Lazy loading, caching |

---

## Compatibility Notes

### macOS Version Requirements

- **AXUIElement**: Available since macOS 10.4, but modern APIs require 10.9+
- **CGEvent**: Available since macOS 10.4
- **AXTextMarker**: Requires macOS 10.13+ for full functionality
- **Screen Recording permission**: Introduced in macOS 10.15 (Catalina)

### Target Compatibility

Agent! currently targets macOS 26 (Tahoe), so all accessibility APIs are available.

---

## Alternative Approaches Considered

### 1. AppleScript UI Scripting

```applescript
tell application "System Events"
    tell process "AppName"
        click button "OK" of window 1
    end tell
end tell
```

**Pros:**
- Already uses Automation permission (same TCC grant)
- Declarative and readable

**Cons:**
- Requires System Events app
- Slower than direct AXUIElement calls
- Less precise control
- Harder to coordinate complex sequences

**Decision:** Keep as fallback, but implement direct AXUIElement for primary accessibility.

### 2. Selenium/Appium via Shell

**Pros:**
- Cross-platform standard
- Rich ecosystem

**Cons:**
- Requires external dependencies
- Not native to macOS
- Overkill for desktop automation

**Decision:** Not suitable for Agent!'s native Swift architecture.

### 3. Shortcuts.app Integration

**Pros:**
- Apple-sanctioned automation
- No additional TCC permissions

**Cons:**
- Limited to predefined actions
- Cannot interact with arbitrary UI elements
- Requires user to create shortcuts manually

**Decision:** Complementary, but not a replacement for direct accessibility.

---

## Recommendations

### Do Implement

1. **Core accessibility tools** (`ax_list_windows`, `ax_inspect_element`, `ax_get_value`)
   - Essential for understanding non-scriptable app UIs
   - Relatively low risk (read-only operations)

2. **Typed input simulation** (`ax_type_text`)
   - High utility for form filling
   - Controllable via prompt instructions

3. **Action-based interaction** (`ax_perform_action`)
   - Uses native accessibility actions when available
   - Safer than raw mouse clicks

### Implement with Caution

4. **Mouse simulation** (`ax_click`)
   - Higher risk of misuse
   - Require explicit logging and rate limiting

5. **Screenshot integration** (`ax_screenshot`)
   - Requires additional Screen Recording permission
   - Already have vision support in Agent!

### Do Not Implement (Phase 1)

6. **Drag and drop** — Complex to implement safely
7. **Gesture simulation** — Low utility for desktop automation
8. **Raw keyboard events** — Use `ax_type_text` instead

---

## Success Metrics

### Phase 1 Success Criteria

- [ ] Agent can list all visible windows
- [ ] Agent can inspect the accessibility tree
- [ ] Agent can read values from non-secure elements
- [ ] All operations are audit-logged
- [ ] Password fields are blocked

### Phase 2 Success Criteria

- [ ] Agent can click buttons in non-scriptable apps
- [ ] Agent can type text into text fields
- [ ] Agent can perform accessibility actions (press, increment, etc.)
- [ ] Rate limiting prevents rapid-fire abuse
- [ ] System prompt prevents unsafe operations

### Phase 3 Success Criteria

- [ ] Agent can automate Safari web forms
- [ ] Agent can interact with Electron apps (VS Code, Slack)
- [ ] Agent can control SwiftUI apps without AppleScript support
- [ ] Comprehensive test coverage for all accessibility tools

---

## Conclusion

Adding accessibility automation to Agent! would significantly expand its capabilities, enabling it to interact with any macOS app — not just those with AppleScript support. This is a powerful feature that requires careful implementation with multiple security layers:

1. **Explicit user consent** (Accessibility permission prompt)
2. **Action filtering** (block dangerous operations)
3. **Prompt-level instructions** (guide AI behavior)
4. **Audit logging** (accountability)
5. **Rate limiting** (prevent abuse)

The proposed implementation is modular, allowing the feature to be rolled out incrementally. Phase 1 (read-only operations) is relatively low-risk and provides immediate value. Phase 2 (input simulation) requires additional safeguards but unlocks the full potential of accessibility automation.

**Recommendation:** Proceed with implementation on the `exp_accessibility` branch. Begin with Phase 1 (core infrastructure + read-only tools), then evaluate security and UX before proceeding to Phase 2 (input simulation).

---

## References

- [Apple Accessibility Programming Guide](https://developer.apple.com/accessibility/)
- [AXUIElement API Reference](https://developer.apple.com/documentation/accessibility/axuielement)
- [CGEvent API Reference](https://developer.apple.com/documentation/coregraphics/cgevent)
- [System Preferences Security & Privacy](https://support.apple.com/guide/mac-help/change-accessibility-preferences-mh43185/mac)

---

*Document created for experimental branch `exp_accessibility`.*