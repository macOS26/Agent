# File Reorganization Plan

## Status: IN PROGRESS

**Last Updated:** March 22, 2025 - Phase 1 complete, proceeding to Phase 2

## Completed Work:
- ✅ Phase 1: TaskExecution extensions created and added to project
  - TaskExecution+ShellTools.swift (205 lines) - executeViaUserAgent, executeLocal, executeLocalStreaming
  - TaskExecution+FileTools.swift (272 lines) - file operation handlers, CodingService helper  
  - TaskExecution+GitTools.swift (77 lines) - git tool handlers
  - TaskExecution+ScriptTools.swift (294 lines) - script management handlers
  - TaskExecution+AutomationTools.swift (559 lines) - Apple Events, Xcode, Accessibility handlers
  - TaskExecution+WebTools.swift (216 lines) - web automation, Selenium handlers
  - TaskExecution+ProcessTools.swift (151 lines) - MCP tools, tool discovery handlers
- ✅ System prompt reorganized into SystemPrompt+Tools/ directory (11 files)
- ✅ Build succeeds with all changes (0 errors)
- ✅ All changes committed and pushed to code-reorganization branch

## Files Over 1000 Lines - Current Status

| File | Lines | Status |
|------|-------|--------|
| AgentViewModel+TaskExecution.swift | 2622 | ✅ EXTENSIONS COMPLETE - Main file has executeTask loop, extensions have handlers |
| AccessibilityService.swift | 1841 | 🔨 NEXT - Note: Accessibility/ folder already has modularized version |
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

### Phase 1: AgentViewModel+TaskExecution.swift ✅ COMPLETE
- Extensions created for all tool handler categories
- Main file keeps executeTask loop and web search helpers
- Build succeeds with 0 errors

### Phase 2: AccessibilityService.swift 🔨 NEXT
- Note: Agent/Services/Accessibility/ folder already contains modularized version (10 files, ~2000 lines total)
- Agent/Services/AccessibilityService.swift (1841 lines) is the monolithic version
- Task: Switch project to use Accessibility/ modular files, delete monolithic file
- Files in Accessibility/:
  - AccessibilityPermissions.swift (62 lines)
  - AccessibilityWindows.swift (145 lines)
  - AccessibilityElementFinder.swift (150 lines)
  - AccessibilityServiceHelpers.swift (92 lines)
  - AccessibilityService+Core.swift (171 lines)
  - AccessibilityProperties.swift (184 lines)
  - AccessibilityScreenshot.swift (119 lines)
  - AccessibilityInputSimulation.swift (216 lines)
  - AccessibilityElementFinding.swift (322 lines)
  - AccessibilityService.swift (556 lines)

### Phase 3: AgentViewModel.swift (1802 → ~5 files) ⏳
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

### Phase 5: AgentTools.swift ✅ DONE
- Reorganized into SystemPrompt+Tools/ directory

### Phase 6: CodeBlockSyntax.swift (1211 → ~3 files) ⏳
1. CodeBlockTheme.swift - theme colors
2. CodeBlockHighlighter.swift - highlighting logic
3. CodeBlockLanguages.swift - language definitions

### Phase 7: FoundationModelService.swift (1025 → ~2 files) ⏳
1. FoundationModelService+Streaming.swift - streaming helpers
2. FoundationModelService.swift - core service