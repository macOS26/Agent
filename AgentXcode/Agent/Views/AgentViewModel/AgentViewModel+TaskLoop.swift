@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log

private let taskLog = Logger(subsystem: "Agent.app.toddbruss", category: "TaskLoop")

// MARK: - Task Execution Loop

extension AgentViewModel {
    
    // MARK: - Main Task Execution
    
    func executeTask(_ prompt: String) async {
        taskLog.info("[main] executeTask started: \(prompt.prefix(80))")
        isRunning = true
        userWasActive = false
        rootWasActive = false
        recentOutputHashes.removeAll()
        
        // Start progress updates for iMessage requests (every 10 minutes)
        if agentReplyHandle != nil {
            startProgressUpdates(for: prompt)
        }
        
        if !activityLog.isEmpty {
            logBuffer += "\n"
        }
        trimToRecentTasks()
        appendLog("--- New Task ---")
        appendLog("User: \(prompt)")
        
        // Use ChatHistoryStore for LLM context (summaries for older tasks, full messages for recent)
        let historyContext = ChatHistoryStore.shared.buildLLMContext()
        let provider = selectedProvider
        let modelName: String
        let isVision: Bool
        switch provider {
        case .claude:
            modelName = selectedModel
            isVision = false
        case .openAI:
            modelName = openAIModel
            isVision = false
        case .deepSeek:
            modelName = deepSeekModel
            isVision = false
        case .huggingFace:
            modelName = huggingFaceModel
            isVision = false
        case .ollama:
            modelName = ollamaModel
            isVision = selectedOllamaSupportsVision
        case .localOllama:
            modelName = localOllamaModel
            isVision = selectedLocalOllamaSupportsVision
        case .foundationModel:
            modelName = "Apple Intelligence"
            isVision = false
        }
        appendLog("Model: \(provider.displayName) / \(modelName)\(isVision ? " (vision)" : "")")
        
        // Start training data capture for Apple AI LoRA fine-tuning (only when toggle is on)
        if AppleIntelligenceMediator.shared.trainingEnabled {
            TrainingDataStore.shared.startCapture(userPrompt: prompt, modelUsed: modelName)
        }
        flushLog()
        
        let claude: ClaudeService? = provider == .claude
            ? ClaudeService(apiKey: apiKey, model: selectedModel, historyContext: historyContext, projectFolder: projectFolder) : nil
        let openAICompatible: OpenAICompatibleService?
        switch provider {
        case .openAI:
            openAICompatible = OpenAICompatibleService(apiKey: openAIAPIKey, model: openAIModel, baseURL: "https://api.openai.com/v1/chat/completions", historyContext: historyContext, projectFolder: projectFolder, provider: .openAI)
        case .deepSeek:
            openAICompatible = OpenAICompatibleService(apiKey: deepSeekAPIKey, model: deepSeekModel, baseURL: "https://api.deepseek.com/chat/completions", historyContext: historyContext, projectFolder: projectFolder, provider: .deepSeek)
        case .huggingFace:
            openAICompatible = OpenAICompatibleService(apiKey: huggingFaceAPIKey, model: huggingFaceModel, baseURL: "https://router.huggingface.co/v1/chat/completions", historyContext: historyContext, projectFolder: projectFolder, provider: .huggingFace)
        default:
            openAICompatible = nil
        }
        let ollama: OllamaService?
        switch provider {
        case .ollama:
            ollama = OllamaService(apiKey: ollamaAPIKey, model: ollamaModel, endpoint: ollamaEndpoint, supportsVision: isVision, historyContext: historyContext, projectFolder: projectFolder, provider: .ollama)
        case .localOllama:
            ollama = OllamaService(apiKey: "", model: localOllamaModel, endpoint: localOllamaEndpoint, supportsVision: isVision, historyContext: historyContext, projectFolder: projectFolder, provider: .localOllama)
        default:
            ollama = nil
        }
        let foundationModelService: FoundationModelService? = provider == .foundationModel
            ? FoundationModelService(historyContext: historyContext, projectFolder: projectFolder) : nil
        // Prepend last task as conversation context so the LLM knows what just happened
        var messages: [[String: Any]] = history.lastTaskMessages()
        
        let effectivePrompt = prompt
        
        if !attachedImagesBase64.isEmpty {
            appendLog("(\(attachedImagesBase64.count) screenshot(s) attached)")
            var contentBlocks: [[String: Any]] = attachedImagesBase64.map { base64 in
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/png",
                        "data": base64
                    ] as [String: Any]
                ]
            }
            contentBlocks.append(["type": "text", "text": effectivePrompt])
            messages.append(["role": "user", "content": contentBlocks])
            // Clear attachments after use
            attachedImages.removeAll()
            attachedImagesBase64.removeAll()
        } else {
            messages.append(["role": "user", "content": effectivePrompt])
        }
        
        // Reset tool call counters for this task
        NativeToolContext.toolCallCount = 0
        NativeToolContext.taskCompleteSummary = nil
        
        var finalResult = ""
        var commandsRun: [String] = []
        var toolResults: [[String: Any]] = []
        
        // Main tool-call loop
        toolLoop: while true {
            // Stop if user cancelled
            if isCancelled {
                appendLog("❌ Task cancelled by user")
                finalResult = "Task cancelled"
                break
            }
            
            // Stop if too many tool calls
            if NativeToolContext.toolCallCount > NativeToolContext.maxToolCalls {
                appendLog("⚠️ Stopping: too many tool calls (\(NativeToolContext.maxToolCalls) max)")
                finalResult = "Stopped: too many tool calls"
                break
            }
            
            // Check for task_complete signal from Apple AI
            if let summary = NativeToolContext.taskCompleteSummary {
                appendLog("✅ Task complete: \(summary)")
                finalResult = summary
                break
            }
            
            // Make LLM call
            isThinking = true
            let llmResult: Result<LLMResponse, Error>
            do {
                if let claude = claude {
                    llmResult = .success(try await claude.call(messages: messages, tools: AgentTools.tools(for: .claude), toolResults: toolResults))
                } else if let openAICompatible = openAICompatible {
                    llmResult = .success(try await openAICompatible.call(messages: messages, tools: AgentTools.tools(for: provider), toolResults: toolResults))
                } else if let ollama = ollama {
                    llmResult = .success(try await ollama.call(messages: messages, tools: AgentTools.tools(for: provider), toolResults: toolResults))
                } else if let foundationModelService = foundationModelService {
                    llmResult = .success(try await foundationModelService.call(messages: messages, tools: AgentTools.tools(for: .foundationModel), toolResults: toolResults))
                } else {
                    llmResult = .failure(NSError(domain: "Agent", code: 1, userInfo: [NSLocalizedDescriptionKey: "No LLM service configured"]))
                }
            } catch {
                llmResult = .failure(error)
            }
            isThinking = false
            
            switch llmResult {
            case .success(let response):
                // Add assistant message to history
                if let content = response.content {
                    messages.append(["role": "assistant", "content": content])
                    appendLog("🤖 \(content)")
                }
                
                // Handle tool calls
                if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                    for toolCall in toolCalls {
                        let toolId = toolCall.id
                        let name = toolCall.name
                        let input = toolCall.input
                        
                        appendLog("🔧 \(name)")
                        
                        // Handle tool call based on provider
                        let toolResult: (output: String, commandsRun: [String])
                        
                        // Try different tool handlers
                        let fileOpResult = await handleFileOperationToolForLLM(name, input: input, toolId: toolId)
                        if !fileOpResult.output.isEmpty {
                            toolResult = fileOpResult
                        } else {
                            let gitOpResult = await handleGitOperationToolForLLM(name, input: input, toolId: toolId)
                            if !gitOpResult.output.isEmpty {
                                toolResult = gitOpResult
                            } else {
                                let scriptMgmtResult = await handleScriptManagementToolForLLM(name, input: input, toolId: toolId)
                                if !scriptMgmtResult.output.isEmpty {
                                    toolResult = scriptMgmtResult
                                } else {
                                    let accessibilityResult = await handleAccessibilityToolForLLM(name, input: input, toolId: toolId)
                                    if !accessibilityResult.output.isEmpty {
                                        toolResult = accessibilityResult
                                    } else {
                                        // Handle other tools
                                        toolResult = await handleOtherToolForLLM(name, input: input, toolId: toolId)
                                    }
                                }
                            }
                        }
                        
                        commandsRun.append(contentsOf: toolResult.commandsRun)
                        toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": toolResult.output])
                        
                        // Check for task_complete
                        if name == "task_complete" {
                            if let summary = input["summary"] as? String {
                                finalResult = summary
                            } else {
                                finalResult = "Done"
                            }
                            appendLog("✅ \(finalResult)")
                            break toolLoop
                        }
                    }
                } else {
                    // No tool calls — task is complete
                    if let content = response.content {
                        finalResult = content
                    } else {
                        finalResult = "Done"
                    }
                    appendLog("✅ \(finalResult)")
                    break
                }
                
            case .failure(let error):
                appendLog("❌ LLM error: \(error.localizedDescription)")
                finalResult = "Error: \(error.localizedDescription)"
                break
            }
            
            flushLog()
        }
        
        // End training data capture
        if AppleIntelligenceMediator.shared.trainingEnabled {
            TrainingDataStore.shared.endCapture(assistantResponse: finalResult)
        }
        
        // Save to history
        let taskRecord = ChatHistoryStore.TaskRecord(
            timestamp: Date(),
            userPrompt: prompt,
            assistantResponse: finalResult,
            commandsRun: commandsRun,
            modelUsed: modelName,
            provider: provider.rawValue
        )
        ChatHistoryStore.shared.addTask(taskRecord)
        
        // Update activity log with recent tasks
        activityLog = ChatHistoryStore.shared.buildActivityLogText(maxTasks: 3)
        
        // Send final reply for iMessage requests
        if let handle = agentReplyHandle {
            sendFinalReply(finalResult, to: handle)
            agentReplyHandle = nil
        }
        
        isRunning = false
        taskLog.info("[main] executeTask finished")
    }
    
    // MARK: - Other Tool Handlers for LLM Providers
    
    /// Handle other tool calls for LLM providers (Claude, Ollama, etc.)
    func handleOtherToolForLLM(_ name: String, input: sending [String: Any], toolId: String) async -> (output: String, commandsRun: [String]) {
        var commandsRun: [String] = []
        var output = ""
        
        // Shell execution tools
        if name == "execute_agent_command" || name == "execute_daemon_command" {
            let cmd = input["command"] as? String ?? ""
            let isDaemon = name == "execute_daemon_command"
            appendLog("💻 Execute \(isDaemon ? "daemon" : "agent") command")
            
            if isDaemon {
                rootServiceActive = true
                rootWasActive = true
                let result = await helperService.execute(command: cmd)
                rootServiceActive = false
                output = result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
                if result.status != 0 {
                    appendLog("exit code: \(result.status)")
                }
            } else {
                userServiceActive = true
                userWasActive = true
                userService.onOutput = { [weak self] chunk in
                    self?.appendRawOutput(chunk)
                }
                let result = await userService.execute(command: cmd)
                userService.onOutput = nil
                userServiceActive = false
                output = result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
                if result.status != 0 {
                    appendLog("exit code: \(result.status)")
                }
            }
            commandsRun.append("\(name): \(cmd.prefix(100))")
        }
        
        // Apple Event query
        else if name == "apple_event_query" {
            let bundleID = input["bundle_id"] as? String ?? ""
            let operations: [[String: Any]]
            if let ops = input["operations"] as? [[String: Any]] {
                operations = ops
            } else if let action = input["action"] as? String {
                var op: [String: Any] = ["action": action]
                if let key = input["key"] as? String { op["key"] = key }
                if let props = input["properties"] as? String {
                    op["properties"] = props.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
                if let limit = input["limit"] as? Int { op["limit"] = limit }
                if let index = input["index"] as? Int { op["index"] = index }
                if let method = input["method"] as? String { op["method"] = method }
                if let arg = input["arg"] as? String { op["arg"] = arg }
                if let predicate = input["predicate"] as? String { op["predicate"] = predicate }
                operations = [op]
            } else {
                output = "Error: action is required"
                appendLog(output)
                return (output, commandsRun)
            }
            appendLog("🍎 Apple Event query: \(bundleID)")
            output = await Self.offMain {
                AppleEventService.shared.execute(bundleID: bundleID, operations: operations)
            }
            appendLog(output)
        }
        
        // Tool discovery
        else if name == "list_native_tools" {
            appendLog("🛠️ List native tools")
            let prefs = ToolPreferencesService.shared
            output = AgentTools.tools(for: selectedProvider)
                .filter { prefs.isEnabled(selectedProvider, $0.name) }
                .sorted { $0.name < $1.name }
                .map { $0.name }
                .joined(separator: "\n")
            appendLog(output)
        }
        
        else if name == "list_mcp_tools" {
            appendLog("🛠️ List MCP tools")
            let mcp = MCPService.shared
            let enabled = mcp.enabledServers.flatMap { server in
                server.tools.map { "mcp_\(server.name)_\($0.name)" }
            }
            output = enabled.isEmpty ? "No MCP tools enabled" : enabled.joined(separator: "\n")
            appendLog(output)
        }
        
        // Xcode tools
        else if name == "xcode_list_projects" {
            appendLog("📱 List Xcode projects")
            output = await Self.offMain { XcodeService.shared.listProjects() }
            appendLog(output)
        }
        
        else if name == "xcode_select_project" {
            let number = input["number"] as? Int ?? 0
            appendLog("📱 Select Xcode project: \(number)")
            output = await Self.offMain { XcodeService.shared.selectProject(number: number) }
            appendLog(output)
        }
        
        else if name == "xcode_build" {
            let projectPath = input["project_path"] as? String ?? ""
            appendLog("📱 Build Xcode project: \(projectPath)")
            output = await Self.offMain { XcodeService.shared.build(projectPath: projectPath) }
            appendLog(output)
        }
        
        else if name == "xcode_run" {
            let projectPath = input["project_path"] as? String ?? ""
            appendLog("📱 Run Xcode project: \(projectPath)")
            output = await Self.offMain { XcodeService.shared.run(projectPath: projectPath) }
            appendLog(output)
        }
        
        else if name == "xcode_grant_permission" {
            appendLog("📱 Grant Xcode permission")
            output = await Self.offMain { XcodeService.shared.grantPermission() }
            appendLog(output)
        }
        
        // SDEF lookup
        else if name == "lookup_sdef" {
            let bundleID = input["bundle_id"] as? String ?? ""
            let className = input["class_name"] as? String
            appendLog("📚 Lookup SDEF: \(bundleID)")
            output = await Self.offMain { SDEFService.shared.lookup(bundleID: bundleID, className: className) }
            appendLog(output)
        }
        
        // Web search
        else if name == "web_search" {
            let query = input["query"] as? String ?? ""
            appendLog("🌐 Web search: \(query)")
            output = await Self.offMain { performWebSearch(query: query) }
            appendLog(output)
        }
        
        // MCP tool calls
        else if name.hasPrefix("mcp_") {
            let parts = name.split(separator: "_", maxSplits: 2)
            if parts.count == 3 {
                let serverName = String(parts[1])
                let toolName = String(parts[2])
                appendLog("🔌 MCP: \(serverName).\(toolName)")
                output = await Self.offMain {
                    MCPService.shared.callTool(serverName: serverName, toolName: toolName, arguments: input)
                }
                appendLog(output)
            } else {
                output = "Error: invalid MCP tool name format. Expected mcp_ServerName_ToolName"
                appendLog(output)
            }
        }
        
        // Unknown tool
        else {
            output = "Error: tool '\(name)' not implemented"
            appendLog(output)
        }
        
        return (output, commandsRun)
    }
    
    // MARK: - Helper Methods
    
    private func performWebSearch(query: String) -> String {
        // Implementation would go here
        return "Web search for '\(query)' would be performed here"
    }
}