# File Reorganization Plan

## Status: IN PROGRESS

**Last Updated:** March 22, 2025 - Phase 1 nearly complete

## Completed Work:
- ✅ Phase 1: TaskExecution extensions created and added to project
  - TaskExecution+ShellTools.swift (205 lines)
  - TaskExecution+FileTools.swift (272 lines)  
  - TaskExecution+GitTools.swift (77 lines)
  - TaskExecution+ScriptTools.swift (294 lines) - NEW
  - TaskExecution+AutomationTools.swift (559 lines) - NEW
  - TaskExecution+WebTools.swift (216 lines) - NEW
  - TaskExecution+ProcessTools.swift (151 lines) - NEW
- ✅ System prompt reorganized into SystemPrompt+Tools/ directory
- ✅ Build succeeds with all changes (0 errors)

## Files Over 1000 Lines - Current Status

| File | Lines | Status |
|------|-------|--------|
| AgentViewModel+TaskExecution.swift | 2622 | 🔨 Extensions created - need to remove duplicated code from main file |
| AccessibilityService.swift | 1841 | ⏳ Pending split |
| AgentViewModel.swift | 1802 | ⏳ Pending split |
| AgentViewModel+TabTask.swift | 1758 | ⏳ Pending split |
| AgentTools.swift | 1421 | ✅ DONE - Reorganized into SystemPrompt+Tools/ |
| CodeBlockSyntax.swift | 1211 | ⏳ Pending split |
| FoundationModelService.swift | 1025 | ⏳ Pending split |
| ActivityLogView.swift | 1002 | ✅ Keep as-is (UI view) |

## Completed Files:
- Agent/SystemPrompt+Tools/AgentSystemPrompt.swift (138 lines)
- Agent/SystemPrompt+Tools/AgentTools+AccessibilityTools.swift (308 lines)
- Agent/SystemPrompt+Tools/AgentTools+AutomationTools.swift (185 lines)
- Agent/SystemPrompt+Tools/AgentTools+FileTools.swift (76 lines)
- Agent/SystemPrompt+Tools/AgentTools+GitTools.swift (65 lines)
- Agent/SystemPrompt+Tools/AgentTools+Names.swift (118 lines)
- Agent/SystemPrompt+Tools/AgentTools+ShellTools.swift (33 lines)
- Agent/SystemPrompt+Tools/AgentTools+ToolDiscovery.swift (21 lines)
- Agent/SystemPrompt+Tools/AgentTools+WebAutomation.swift (181 lines)
- Agent/SystemPrompt+Tools/AgentTools+XcodeTools.swift (45 lines)
- Agent/Views/AgentViewModel/TaskExecution+ShellTools.swift (205 lines)
- Agent/Views/AgentViewModel/TaskExecution+FileTools.swift (272 lines)
- Agent/Views/AgentViewModel/TaskExecution+GitTools.swift (77 lines)
- Agent/Views/AgentViewModel/TaskExecution+ScriptTools.swift (294 lines) - NEW
- Agent/Views/AgentViewModel/TaskExecution+AutomationTools.swift (559 lines) - NEW
- Agent/Views/AgentViewModel/TaskExecution+WebTools.swift (216 lines) - NEW
- Agent/Views/AgentViewModel/TaskExecution+ProcessTools.swift (151 lines) - NEW

## Execution Order

### Phase 1: AgentViewModel+TaskExecution.swift (2622 → ~8 files) 🔨 IN PROGRESS
1. ✅ TaskExecution+ShellTools.swift - executeViaUserAgent, executeLocal, executeLocalStreaming
2. ✅ TaskExecution+FileTools.swift - file operation handlers
3. ✅ TaskExecution+GitTools.swift - git tool handlers
4. ✅ TaskExecution+ScriptTools.swift - script management tools - CREATED
5. ✅ TaskExecution+AutomationTools.swift - Apple Events, Xcode, accessibility - CREATED
6. ✅ TaskExecution+WebTools.swift - web automation, Selenium - CREATED
7. ✅ TaskExecution+ProcessTools.swift - MCP tools, tool discovery - CREATED
8. ⏳ AgentViewModel+TaskExecution.swift - CLEANUP: Remove duplicated code (keep only executeTask loop)

### Phase 2: AccessibilityService.swift (1841 → ~6 files) ⏳
1. AccessibilityService+Element.swift - element inspection, properties
2. AccessibilityService+Actions.swift - input simulation, actions
3. AccessibilityService+Finding.swift - element finding, waiting
4. AccessibilityService+Screenshot.swift - screenshots, window frames
5. AccessibilityService+Audit.swift - audit logging
6. AccessibilityService.swift - core service, permissions

### Phase 3: AgentViewModel.swift (1800 → ~5 files) ⏳
1. AgentViewModel+Models.swift - model structs
2. AgentViewModel+TabManagement.swift - tab operations
3. AgentViewModel+MessagesMonitor.swift - Messages/iMessage handling
4. AgentViewModel+ModelFetching.swift - model fetching functions
5. AgentViewModel.swift - core properties, init

### Phase 4: AgentViewModel+TabTask.swift (1758 → ~6 files) ⏳
1. TabTask+Execution.swift - main execution loop
2. TabTask+FileTools.swift - file operations
3. TabTask+GitTools.swift - git operations
4. TabTask+ShellTools.swift - shell commands
5. TabTask+AutomationTools.swift - Apple Events, Xcode, accessibility
6. TabTask+WebTools.swift - web automation

### Phase 5: AgentTools.swift (1421 → ~4 files) ✅ DONE
- Reorganized into SystemPrompt+Tools/ directory

### Phase 6: CodeBlockSyntax.swift (1211 → ~3 files) ⏳
1. CodeBlockTheme.swift - theme colors
2. CodeBlockHighlighter.swift - highlighting logic
3. CodeBlockLanguages.swift - language definitions

### Phase 7: FoundationModelService.swift (1025 → ~2 files) ⏳
1. FoundationModelService+Streaming.swift - streaming helpers
2. FoundationModelService.swift - core service