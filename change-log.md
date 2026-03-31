# Change Log — March 30-31, 2026

## Performance

- **Fix AgentViewModel init called 260+ times** — `@State` default expression was creating a new AgentViewModel on every SwiftUI body evaluation, each running 250ms of SwiftData queries. Added static guard so init work runs exactly once; duplicates return in nanoseconds.
- **Move heavy work off main thread** — NSAppleScript execution, Process calls, and ScriptService operations moved to background threads across 14 files. WebAutomationService JS execution, NativeToolHandler AppleScript, LoRA terminal open, and AccessibilityService screenshot/click/wait/drag all moved off MainActor.
- **ScriptService no longer @MainActor** — Git clone and file I/O no longer block the UI thread. All call sites wrapped in `offMain`.
- **Background rendering** — ColorSyntax and TerminalNeo render on background queues via Combine-based text updates.
- **ActivityLogView rendering moved out of updateNSView** — All rendering dispatched async via `scheduleRender()`, zero work during SwiftUI layout pass.
- **Throttle optimizations** — Timer reduced from 10x to 1x/sec, scroll observer throttled, link detection disabled, log trimmed at 50K chars.
- **Batch flushLog mutations** — `activityLog` now mutated once per flush instead of multiple times, reducing SwiftUI observation churn.

## Tab System

- **Fix live tab updates** — `@State` with shared singleton broke SwiftUI observation chain. Restored proper `@State` ownership with guarded init.
- **Fix tab switch rendering** — Switching to uncached tabs now renders full markdown/code/tables instead of plain text that never got re-rendered.
- **Per-tab project folder** — Force view refresh on tab switch, inherit main folder when empty, prevent updateNSView from overwriting during editing.
- **Tab switching data flow** — Removed callback system, simplified data flow, restored activityLog as @Observable.

## Architecture Refactor

- **Dispatch table** — O(1) dictionary lookup for tool routing, replacing if-name-== chains. All tool routing is hash-based.
- **File splits** — AccessibilityService (2125 to 99 + 5 extensions), AgentViewModel (2345 to 980 + 6 extensions), TaskExecution (2333 to 705 + ToolDispatch), WebAutomationService (1608 to 796 + 3 extensions), CodingService (1202 to 329 + 3 extensions), ScriptService (974 to 340 + 3 extensions), NativeToolHandler (969 to 859, switch conversion).
- **3 local Swift packages** — AgentColorSyntax, AgentTools, AgentTerminalNeo moved to local packages.
- **All packages now local** — Including AgentMCP, D1F-swift-multi-line-diff, xcf-swift, AgentEventBridges.

## LLM / Tool Improvements

- **Coding mode** — AI can toggle coding_mode tool; auto-enables after iteration 1, filters to Core+Workflow+Coding+UserAgent tools. Compact tool descriptions (40-char props, 60-char descriptions). Minimal 1-line system prompt after iter 1.
- **Rate limit handling** — 429 errors now retry once after 30s then stop, instead of 20 retries.
- **Pruning** — Messages pruned every 4 iterations, truncation lowered to 4K, use-when hints added.
- **Consolidated tools** — write_text, transform_text, fix_text, about_self merged into conversation tool.
- **Tool gap closure** — web_search, lookup_sdef, undo_edit, diff_and_apply, project_folder now work in both main and tab execution paths.
- **Xcode tools** — Added bump_version, bump_build, get_version actions. ScriptingBridge invalid reuse error fixed with delegate error suppression.
- **diff_and_apply promoted** — LLMs pushed to use diff_apply for multi-line edits instead of edit.
- **Apple AI** — Skip short prompts, fix typos only (no rephrasing), removed context injection at task start (keep only on task_complete), timeout reduced to 1s/2s.

## UI

- **LLM output box** — Markdown tables rendered as box-drawn terminal tables. Height capped at 50% of window.
- **Retro neo terminal** — Green terminal styling with TerminalNeo 1.2.2 auto-sizing.
- **Relative paths** — list_files, search_files, read_dir all output relative paths with home directory trimmed.
- **Color syntax** — Added ~/path colorization for trimmed home directory paths.
- **Queue indicator** — Shows queue count next to Thinking status, teal color for light mode visibility.
- **Plan mode fix** — Use tab's plan when LLM sends wrong plan_id.

## Services

- **Messages monitor** — Gated on Full Disk Access, disabled if not granted. Warning and Open Settings button in Messages popover.
- **execute_daemon_command** — Documentation clarified: runs as ROOT, no sudo needed.

## Versions

- v1.0.7: Optimizations, rate limit handling, AI improvements
- v1.0.9: Dispatch table refactor, file splits, Swift packages
- v1.0.10: Messages monitor Full Disk Access gate
