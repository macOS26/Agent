[< Back to README](../README.md)

# Security Architecture

This document details Agent!'s security model and entitlements.

## Entitlements

Agent! requires the following entitlements in `Agent.entitlements`:

| Entitlement | Purpose |
|-------------|---------|
| `automation.apple-events` | AppleScript and ScriptingBridge automation |
| `cs.allow-unsigned-executable-memory` | Required for dlopen'd AgentScript dylibs |
| `cs.disable-library-validation` | Load user-compiled script dylibs at runtime |
| `assets.music.read-write` | Music library access via MusicBridge |
| `device.audio-input` | Microphone access for audio scripts |
| `device.bluetooth` | Bluetooth device interaction |
| `device.camera` | Camera capture (CapturePhoto script) |
| `device.usb` | USB device access |
| `files.downloads.read-write` | Read/write Downloads folder |
| `files.user-selected.read-write` | Read/write user-selected files |
| `network.client` | Outbound connections (API calls, web search) |
| `network.server` | Inbound connections (MCP HTTP/SSE transport) |
| `personal-information.addressbook` | Contacts access via ContactsBridge |
| `personal-information.calendars` | Calendar access via CalendarBridge |
| `personal-information.location` | Location services |
| `personal-information.photos-library` | Photos access via PhotosBridge |
| `keychain-access-groups` | Secure API key storage |

## TCC Permissions (Accessibility, Screen Recording, Automation)

Protected macOS APIs require user approval. Agent handles TCC correctly:

| Component | TCC Grants |
|-----------|------------|
| `run_agent_script`, `applescript_tool`, TCC shell commands | **ALL** (Accessibility, Screen Recording, Automation) |
| `execute_user_command` (LaunchAgent) | **None** |
| `execute_command` (root) | **Separate context** |

**Rule:** Use `run_agent_script` or `applescript_tool` for Accessibility/Automation tasks, not shell commands.

## XPC Sandboxing

Shell execution goes through two XPC services (Inter-Process Communication):

```
Agent.app (SwiftUI)
    |
    |-- UserService (XPC) → Agent.app.toddbruss.user    (LaunchAgent, runs as current user — not privileged)
    |-- HelperService (XPC) → Agent.app.toddbruss.helper  (LaunchDaemon, runs as root — privileged)
```

The XPC boundary ensures:
- The Launch Agent handles everyday shell tasks as the current user (no elevated privileges)
- Root operations are isolated to the Launch Daemon
- Each XPC call is a discrete, auditable transaction
- File permissions are restored to the user after root operations

## SMAppService — OS-Level Code Signature Enforcement

Agent! registers its Launch Agent and Launch Daemon via Apple's **SMAppService** framework (macOS 13+). This provides OS-enforced security that makes manual XPC audit token validation redundant:

- **Code Signature Chain**: macOS requires the Launch Agent and Launch Daemon to be **embedded inside the signed app bundle** and share the **same Team ID** (469UCUB275). The OS validates this at registration time — unsigned or differently-signed helpers are rejected by launchd before they can run.
- **User Approval**: SMAppService routes through **System Settings → Login Items & Extensions**, giving the user explicit control over which helpers are active.
- **Lifecycle Management**: launchd owns the helper lifecycle. The helpers can only be registered/unregistered through the SMAppService API, not by dropping arbitrary plists.
- **No Manual Audit Token Checks Needed**: Because the OS enforces that only code signed by the same developer can register and communicate through the Mach service, the `shouldAcceptNewConnection` callback does not need to re-verify what the OS has already guaranteed. An unauthorized process cannot connect to the XPC service in the first place.

Agent! wraps SMAppService via `SafeSMAppService` and `SafeSMAppServiceDaemon`, which add plist validation safety checks before calling the framework methods.

### Empirical Proof — Re-signing Breaks the XPC Channel

The signing guarantee is not theoretical. If the helper binaries are re-signed after installation — even by the same developer, same Team ID — the bundle hash changes, the SMAppService-registered identity no longer matches, and every client loses access to the Mach services. We verified this directly: Agent! itself attempted to re-sign its own daemons during an experiment and immediately lost the ability to connect. `NSXPCConnection` to `Agent.app.toddbruss.helper` and `Agent.app.toddbruss.user` fails at the launchd layer before a single byte reaches `listener(_:shouldAcceptNewConnection:)`.

This is exactly the behavior a manual `connection.setCodeSigningRequirement(...)` call would enforce — except SMAppService is already enforcing it one layer down, in the kernel's XPC lookup path, and it cannot be bypassed from userland.

### Why Manual `setCodeSigningRequirement` Is Not Required

A common audit finding on XPC services is the absence of `connection.setCodeSigningRequirement(...)` in `listener(_:shouldAcceptNewConnection:)`. That recommendation comes from the **pre-SMAppService SMJobBless era**, where launchd did not validate identity for you and the XPC server had to set a designated-requirement string itself. SMAppService changed that contract:

- The app-bundle-embedded plist plus the signature-gated registration **is** the code-signing requirement.
- The Mach service name (`Agent.app.toddbruss.helper`, `Agent.app.toddbruss.user`) is namespaced to the signed bundle that registered it — no other bundle can claim it.
- Any signature mismatch (tampering, re-signing, different Team ID, bundle swap) breaks the XPC channel at the launchd layer — the listener delegate is never even invoked.
- Therefore `shouldAcceptNewConnection` returning `true` unconditionally is safe: every connection that reaches it has already passed OS-level signature validation.

Adding `setCodeSigningRequirement` explicitly would be reasonable defense-in-depth (useful only if the app were ever ported off SMAppService, or if SIP were disabled on the machine), but it is **not a gap** in the current architecture — merely optional belt-and-braces.

### Trust Anchors Summary

| Enforcement | Mechanism | Bypassable from userland? |
|---|---|---|
| Helper must be in signed app bundle | Gatekeeper + SMAppService registration | No |
| Helper must match app's Team ID (469UCUB275) | Code signing + SMAppService | No |
| Mach service name bound to signed bundle | launchd / XPC namespace | No |
| Helper binary hash matches registered identity | SMAppService + kernel XPC lookup | No (re-signing breaks the channel) |
| User approved the helper | System Settings → Login Items & Extensions | No (user gesture required) |

### Launch Agent vs. Launch Daemon — User Controlled

Agent! ships with two independent XPC backends, and the user can turn the Launch Daemon off at any time:

- **Launch Agent** (runs in user space) — **recommended, always on**. Handles the vast majority of tasks with the user's own TCC grants and file permissions. No root, no admin approval needed.
- **Launch Daemon** (runs in root space) — **100% optional**. Only needed for admin-level duties (disk cloning, software install, system-wide config). The user approves it once via System Settings → Login Items & Extensions, and can disable or remove it at any time from the same pane. Agent! continues to function fully with only the Launch Agent enabled.

## Action Verification (action_not_performed)

Agent! prevents false-action claims — where an AI reports performing an action it never executed — with three independent layers:

### Layer 1: Prompt Rule
The system prompt instructs the LLM to say "action not performed" if it did not call a tool. It may never claim to have searched, opened, clicked, ran, or found something without a matching `tool_result`.

### Layer 2: App-Layer Detection
If the LLM returns text claiming "I searched", "I opened", "I clicked", etc. but made zero tool calls in that turn, the app injects a correction `tool_result` telling the LLM to use the actual tool or admit it cannot perform the action. This is logged in the activity view as `⚠️ action not performed`.

### Layer 3: Apple AI Gating
Apple Intelligence tool calls (accessibility, applescript, shell) are logged to the activity view with the 🍎 prefix showing exactly what was called and what it returned. If Apple AI's tools produce no substantive output (empty, just an exit code, or error), the request is automatically forwarded to the cloud LLM. Apple AI can only claim task completion when its tools return real evidence of work.

### Architecture
All tool execution flows through the app's `dispatchTool()` layer — the LLM never self-reports tool results. The flow is:

1. LLM returns a `tool_use` JSON block
2. Agent!'s dispatch layer executes the tool via XPC, shell, or in-process
3. The real output goes back as `tool_result`
4. The LLM summarizes the real result

The LLM cannot fabricate tool outputs because it never controls what `tool_result` contains — the app does.