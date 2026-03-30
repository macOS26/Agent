# fix-force-unwraps

- [ ] 1. Replace force unwraps `first!` with safe fallback `first ?? FileManager.default.temporaryDirectory` in these files:
- [ ] 2. 1. ChatModels.swift (line 113)
- [ ] 3. 2. TrainingData.swift (line 81)
- [ ] 4. 3. TokenUsageStore.swift (line 19)
- [ ] 5. 4. LoRAAdapterManager.swift (lines 31, 120, 128, 132)
- [ ] 6. 5. RecentAgentsService.swift (line 70)
- [ ] 7. Build project to verify all fixes

---
*Status: 7 steps pending*
