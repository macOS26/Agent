# File Reorganization Plan

## Files Over 1000 Lines

| File | Lines | Plan |
|------|-------|------|
| AgentViewModel+TaskExecution.swift | 2622 | Split into 8 files by tool category |
| AccessibilityService.swift | 1841 | Split into 6 files by functionality |
| AgentViewModel.swift | 1800 | Split into 5 files by concern |
| AgentViewModel+TabTask.swift | 1758 | Split into 6 files by tool category |
| AgentTools.swift | 1421 | Split into 4 files by section |
| CodeBlockSyntax.swift | 1211 | Split into 3 files |
| FoundationModelService.swift | 1025 | Split into 2 files |
| ActivityLogView.swift | 1002 | Keep as-is (UI view) |

## Execution Order

### Phase 1: AgentViewModel+TaskExecution.swift (2622 → ~8 files)
1. TaskExecution+ShellTools.swift - executeViaUserAgent, executeLocal, executeLocalStreaming
2. TaskExecution+FileTools.swift - file operation handlers
3. TaskExecution+GitTools.swift - git tool handlers
4. TaskExecution+ScriptTools.swift - script management tools
5. TaskExecution+AutomationTools.swift - Apple Events, Xcode, accessibility
6. TaskExecution+WebTools.swift - web automation, Selenium
7. TaskExecution.swift - main loop and executeNativeTool orchestration

### Phase 2: AccessibilityService.swift (1841 → ~6 files)
1. AccessibilityService+Element.swift - element inspection, properties
2. AccessibilityService+Actions.swift - input simulation, actions
3. AccessibilityService+Finding.swift - element finding, waiting
4. AccessibilityService+Screenshot.swift - screenshots, window frames
5. AccessibilityService+Audit.swift - audit logging
6. AccessibilityService.swift - core service, permissions

### Phase 3: AgentViewModel.swift (1800 → ~5 files)
1. AgentViewModel+Models.swift - model structs
2. AgentViewModel+TabManagement.swift - tab operations
3. AgentViewModel+MessagesMonitor.swift - Messages/iMessage handling
4. AgentViewModel+ModelFetching.swift - model fetching functions
5. AgentViewModel.swift - core properties, init

### Phase 4: AgentViewModel+TabTask.swift (1758 → ~6 files)
1. TabTask+Execution.swift - main execution loop
2. TabTask+FileTools.swift - file operations
3. TabTask+GitTools.swift - git operations
4. TabTask+ShellTools.swift - shell commands
5. TabTask+AutomationTools.swift - Apple Events, Xcode, accessibility
6. TabTask+WebTools.swift - web automation

### Phase 5: AgentTools.swift (1421 → ~4 files)
1. AgentTools+Names.swift - tool name constants
2. AgentTools+SystemPrompt.swift - system prompt generation
3. AgentTools+Definitions.swift - tool definitions
4. AgentTools+Examples.swift - tool examples

### Phase 6: CodeBlockSyntax.swift (1211 → ~3 files)
1. CodeBlockTheme.swift - theme colors
2. CodeBlockHighlighter.swift - highlighting logic
3. CodeBlockLanguages.swift - language definitions

### Phase 7: FoundationModelService.swift (1025 → ~2 files)
1. FoundationModelService+Streaming.swift - streaming helpers
2. FoundationModelService.swift - core service