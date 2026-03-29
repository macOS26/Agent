# Consolidate file tools to file_manager actions

- [ ] 1. 1. Review AgentTools.swift - identify all direct file tool names to remove
- [ ] 2. 2. Update AgentTools.Name - remove direct file tool constants, keep file_manager
- [ ] 3. 3. Update AgentTools systemPrompt - remove DIRECT TOOLS section for file tools
- [ ] 4. 4. Update commonTools array - remove direct file ToolDefs, keep file_manager
- [ ] 5. 5. Update toolExamples - remove direct file tool examples
- [ ] 6. 6. Update AgentViewModel+TabHandlers+FileManager.swift - route file_manager actions to existing handlers
- [ ] 7. 7. Update AgentViewModel+NativeToolHandler.swift - ensure file_manager routing works
- [ ] 8. 8. Build and verify

---
*Status: 8 steps pending*
