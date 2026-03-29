# Swift File Audit - Files Over 1000 Lines
**AgentXcode Project**
**Date: $(date)**

## Summary

**5 files exceed 1000 lines** in the AgentXcode project.

## Files Over 1000 Lines

| File | Lines | Location | Description |
|------|-------|----------|-------------|
| AgentViewModel+TaskExecution.swift | ~3,200+ | Agent/Views/AgentViewModel/ | Main LLM task execution loop, tool handling |
| AgentViewModel.swift | ~1,909 | Agent/Views/AgentViewModel/ | Primary view model state and coordination |
| AgentViewModel+TabTask.swift | ~1,902 | Agent/Views/AgentViewModel/ | Tab-based task execution for script tabs |
| AccessibilityService.swift | ~1,841 | Agent/Services/ | Accessibility automation service |
| AgentTools.swift | ~1,491 | Agent/SystemPrompt+Tools/ | Tool definitions for LLM providers |

## Detailed Analysis

### 1. AgentViewModel+TaskExecution.swift (~3,200+ lines)
**Purpose**: Handles the main LLM task execution loop with extensive tool dispatching.

**Key Sections**:
- Tool execution routing (file, git, accessibility, scripts, MCP)
- Accessibility tool implementations (ax_list_windows, ax_inspect_element, etc.)
- Agent script compilation and execution
- Web automation (Selenium helpers)
- MCP tool integration
- Shell command execution via UserService

**Recommendation**: Consider further modularization:
- `TaskExecution+FileTools.swift` - File and git operations
- `TaskExecution+AccessibilityTools.swift` - Accessibility tool handlers
- `TaskExecution+ScriptTools.swift` - Agent script operations
- `TaskExecution+MCPTools.swift` - MCP tool routing

### 2. AgentViewModel.swift (~1,909 lines)
**Purpose**: Core view model with state management, service coordination, and UI bindings.

**Key Sections**:
- LLM configuration and provider management
- Service initialization (Claude, Ollama, UserService, etc.)
- Tab management (script tabs, main tabs)
- Settings persistence
- Streaming state management
- Apple Intelligence integration

**Status**: Large but well-organized; extensions help manage complexity.

### 3. AgentViewModel+TabTask.swift (~1,902 lines)
**Purpose**: Tab-specific task execution for script tabs.

**Key Sections**:
- Tab task execution loop
- Native tool execution for tabs
- Selenium/web automation tools
- MCP tool execution in tab context
- TCC permission handling for tabs

**Recommendation**: Consider extracting web automation tools to separate file.

### 4. AccessibilityService.swift (~1,841 lines)
**Purpose**: Comprehensive accessibility automation via macOS Accessibility API.

**Key Sections**:
- Window listing and inspection
- Element traversal and property access
- UI interaction (click, type, scroll, drag)
- Permission management
- Audit logging

**Status**: Focused service; appropriate size for its scope.

### 5. AgentTools.swift (~1,491 lines)
**Purpose**: Single source of truth for tool definitions across all LLM providers.

**Key Sections**:
- Tool name constants
- Claude-format tool definitions
- OpenAI/Ollama-format tool definitions
- Foundation Models tool definitions
- Native tool implementations

**Status**: Essential central definition file; appropriate size.

## Files Under 1000 Lines (Reference)

| File | Lines | Location |
|------|-------|----------|
| ScriptService.swift | ~900 | Agent/Services/ |
| OllamaService.swift | ~803 | Agent/Services/ |
| AgentViewModel+Logging.swift | ~438 | Agent/Views/AgentViewModel/ |
| ClaudeService.swift | ~283 | Agent/Services/ |
| MCPService.swift | ~261 | Agent/Services/MCP/ |
| TaskExecution+ShellTools.swift | ~137 | Agent/Views/AgentViewModel/ |

## Recommendations

1. **Priority: Refactor AgentViewModel+TaskExecution.swift**
   - Split into domain-specific tool handler files
   - This is the largest file and would benefit most from modularization

2. **Consider Tab Task Extraction**
   - AgentViewModel+TabTask.swift could extract web automation to a separate file

3. **Maintain Current Structure for Others**
   - AccessibilityService.swift and AgentTools.swift are appropriately sized for their scope
   - AgentViewModel.swift extensions pattern is working well

4. **Target File Size**
   - Aim for files under 1500 lines where practical
   - Extension files should ideally stay under 1000 lines

## Conclusion

The AgentXcode project has 5 files exceeding 1000 lines, with AgentViewModel+TaskExecution.swift being the primary concern at 3,200+ lines. The codebase follows good Swift patterns with extensions, but the TaskExecution file has grown significantly and would benefit from further modularization along tool-domain boundaries.