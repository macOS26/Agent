[< Back to README](../README.md)

# Security Architecture

This document details Agent!'s security model, entitlements, and defense layers.

## Entitlements

Agent! requires the following entitlements in `Agent.entitlements` (developer-signed builds):

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

### Ad-hoc Build Entitlements

`build.sh` (the no-developer-account path) uses `Agent.adhoc.entitlements`,
a deliberately stripped-down subset. The following capabilities are
**excluded** from ad-hoc builds to reduce the attack surface:

- `cs.allow-unsigned-executable-memory` / `cs.disable-library-validation` (no dylib loading)
- `network.server` (no inbound MCP HTTP/SSE)
- Device capabilities: camera, microphone, Bluetooth, USB
- Personal information: contacts, calendars, location, photos
- `keychain-access-groups` (requires Team ID)

## TCC Permissions (Accessibility, Screen Recording, Automation)

Protected macOS APIs require user approval. Agent handles TCC correctly:

| Component | TCC Grants |
|-----------|------------|
| `run_agent_script`, `applescript_tool`, TCC shell commands | **ALL** (Accessibility, Screen Recording, Automation) |
| `execute_user_command` (LaunchAgent) | **None** |
| `execute_command` (root) | **Separate context** |

**Rule:** Use `run_agent_script` or `applescript_tool` for Accessibility/Automation tasks, not shell commands.

## Write Protection (AppleScript)

`NSAppleScriptService` enforces a runtime write-protection gate:

- AppleScript containing destructive verbs (`delete`, `close`, `move`,
  `quit`, `shut down`, `restart`, `log out`, `empty trash`,
  `do shell script`) is **blocked by default**.
- The LLM must explicitly set `allow_writes: true` to execute these.
- This is enforced in code at `NSAppleScriptService.writeProtectionCheck()`,
  not just as a prompt constraint. Both the tab handler
  (`Automation.swift:run_applescript`) and the native handler
  (`NTH-Shell.swift:run_applescript`) pass through the gate.

Source: `Agent/Services/NSAppleScriptService.swift`.

## XPC Sandboxing

All privileged operations go through XPC (Inter-Process Communication):

```
Agent.app (SwiftUI)
    |
    |-- UserService (XPC) → Agent.app.toddbruss.user    (LaunchAgent, runs as user)
    |-- HelperService (XPC) → Agent.app.toddbruss.helper  (LaunchDaemon, runs as root)
```

The XPC boundary ensures:
- The main app runs with minimal privileges
- Root operations are isolated to the daemon
- Each XPC call is a discrete, auditable transaction
- File permissions are restored to the user after root operations

### Peer Authentication

Both daemons refuse XPC connections that are not signed by the same Agent!
bundle. Because the helper runs as root, an unauthenticated Mach listener
would be a local privilege-escalation path — any process on the machine
could dial in and request `execute(script:)`. To close that path:

1. On macOS 13+, the listener calls
   `NSXPCListener.setCodeSigningRequirement(_:)` so the OS drops any peer
   that doesn't match before the delegate is invoked.
2. The `shouldAcceptNewConnection` delegate *also* validates the peer's
   `audit_token_t` via `SecCodeCopyGuestWithAttributes` +
   `SecStaticCodeCheckValidity`. Belt-and-suspenders fallback.
3. The requirement is built at runtime from the daemon's own signing
   identity:
   - **Developer-signed** daemons require
     `anchor apple generic and certificate leaf[subject.OU] = "<TeamID>" and identifier "Agent.app.toddbruss"`.
   - **Ad-hoc signed** local builds fall back to matching the daemon's
     own `cdhash`, so only the exact same build can connect.

Source: `Shared/XPCPeerValidator.swift`, `AgentHelper/main.swift`,
`AgentUser/main.swift`.

### Root Shell Rate Limiting

`HelperService` enforces a per-minute rate limit on root-shell commands
(default: 20 per 60-second rolling window). This prevents an LLM in an
unbounded loop from executing hundreds of root commands. When the limit is
hit, the tool returns an error telling the model to wait or use
`execute_agent_command` (user shell) instead.

Source: `Agent/Services/HelperService.swift` (`RootShellRateLimiter`).

### Daemon-side Shell Safety Backstop

`Shared/DaemonCore.swift` runs a conservative last-mile shell-safety check
(`DaemonShellGuard`) *inside the daemon*, after the XPC boundary and
regardless of which caller made the request. This is a strict subset of
the app's `ShellSafetyService` rules and covers:

- `rm -rf` against `/`, system roots, or `$HOME`
- `rm --no-preserve-root`
- `dd of=/dev/disk*` (and friends)
- `mkfs.*`, `diskutil eraseDisk|zeroDisk|secureErase|eraseVolume`
- Output redirection `> /dev/disk*`
- Classic `:(){ :|:& };:` fork bomb

Even if the listener validator ever mis-installs (e.g. during development
with a malformed requirement string), these patterns never reach
`/bin/zsh -c` as root.

## Shell Safety Service

`ShellSafetyService` is the primary shell guardrail — runs BEFORE every
execution surface and rejects catastrophic commands without dispatching
them. LLM system-prompt instructions are backstops, not the enforcement
layer. Blocked patterns:

| Rule | What it catches |
|------|-----------------|
| `rm.dangerous-target` | `rm -rf /`, `rm -rf ~`, system roots, broad globs |
| `rm.no-preserve-root` | `rm --no-preserve-root` (always blocked) |
| `find.delete-broad-root` | `find / ... -delete`, `find ~ ... -delete` |
| `perms.recursive-on-root` | `chmod -R 777 /`, `chown -R root:root /etc` |
| `dd.raw-disk` | `dd of=/dev/disk2`, `dd of=/dev/sda` |
| `mkfs` | Any `mkfs.*` command |
| `diskutil.erase` | `diskutil eraseDisk`, `zeroDisk`, `secureErase`, `eraseVolume` |
| `redirect.raw-disk` | `> /dev/disk*`, `> /dev/sda` |
| `fork-bomb` | `:(){ :\|:& };:` and variations |
| `mv.to-devnull` | `mv ~ /dev/null`, `mv /etc /dev/null` |
| `sensitive-file-write` | Writes to `/etc/sudoers`, `/etc/passwd`, `~/.ssh/authorized_keys`, `~/.zshrc`, `~/.bashrc`, etc. |
| `piped-remote-exec` | `curl ... \| sh`, `wget ... \| bash`, `curl ... \| python` |
| `launchctl-tmp` | `launchctl load /tmp/...` (persistence from temp dirs) |

Compound commands (`cmd1; cmd2 && cmd3 || cmd4 | cmd5`) are split on shell
separators and each segment is classified independently. Leading
`sudo`/`exec`/`doas`/`eval` wrappers and env-var assignments are stripped
before matching.

Source: `Agent/Services/ShellSafetyService.swift`.

## iMessage Remote Execution Restrictions

When a task originates from iMessage, the following tools are **blocked**:

| Blocked tool | Reason |
|---|---|
| `execute_daemon_command` | No root shell via remote text |
| `batch_commands` | No unbounded shell batches |
| `batch_tools` | No unbounded tool batches |
| `run_osascript` | No arbitrary osascript (use `run_applescript` with write-protection) |
| `execute_javascript` | No arbitrary JXA |

This ensures a compromised or spoofed iMessage sender cannot escalate to
root or drive arbitrary automation. Regular user-shell and file tools
remain available for legitimate remote use.

Source: `Agent/AgentViewModel/TabHandlers/TabToolHandlers.swift`.

## Hooks Security

User-defined hooks (`~/Documents/AgentScript/hooks.json`) execute shell
commands on tool events. To prevent persistence attacks:

- **Permission check on load**: if `hooks.json` is group-writable or
  world-writable, it is **refused** and hooks are not loaded. An NSLog
  warning is emitted.
- **Permission enforcement on save**: every write sets `0o600`
  (owner-only read/write).

Source: `Agent/Services/HooksService.swift`.

## System Prompt Safety Rules

The system prompt includes explicit SAFETY RULES telling the LLM to avoid
patterns that `ShellSafetyService` would block. This reduces unnecessary
tool rejections and teaches the model the "why" behind each guardrail:

- No `rm -rf` on system roots or home
- No `curl | sh` / `wget | bash`
- No writes to `/etc/sudoers`, `~/.ssh/authorized_keys`, shell profiles
- No `dd` to raw disks, no `mkfs`, no `diskutil erase`
- No `launchctl load` from temp dirs
- AppleScript defaults to read-only; destructive verbs require `allow_writes`
- Root shell is for admin tasks only and is rate-limited
- iMessage tasks have a restricted tool set

Source: `Agent/Services/SystemPromptService.swift`.

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
