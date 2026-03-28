
@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log

private let tabTaskLog = Logger(subsystem: AppConstants.subsystem, category: "TabTask")

// MARK: - Tab Task Execution

extension AgentViewModel {

    /// Start an LLM task on a specific script tab.
    func runTabTask(tab: ScriptTab) {
        let task = tab.taskInput.trimmingCharacters(in: .whitespaces)
        guard !task.isEmpty else { return }

        // Handle /clear in tab context
        if task.lowercased() == "/clear" {
            tab.taskInput = ""
            tab.activityLog = ""
            tab.logBuffer = ""
            tab.logFlushTask?.cancel()
            tab.logFlushTask = nil
            tab.streamLineCount = 0
            persistScriptTabs()
            return
        }

        tab.addToHistory(task)
        tab.taskInput = ""

        // Queue if already running
        if tab.isLLMRunning {
            tab.taskQueue.append(task)
            tab.appendLog("📋 Queued (\(tab.taskQueue.count)): \(task)")
            tab.flush()
            return
        }

        startTabTask(tab: tab, prompt: task)
    }

    /// Start executing a task on a tab (not queued).
    private func startTabTask(tab: ScriptTab, prompt: String) {
        tab.currentTaskPrompt = prompt
        tab.runningLLMTask = Task {
            await executeTabTask(tab: tab, prompt: prompt)
            // When done, run next queued task
            if !tab.taskQueue.isEmpty && !tab.isCancelled {
                let next = tab.taskQueue.removeFirst()
                startTabTask(tab: tab, prompt: next)
            }
        }
    }

    /// Stop the LLM task running on a script tab and clear its queue.
    func stopTabTask(tab: ScriptTab) {
        let queueCount = tab.taskQueue.count
        tab.taskQueue.removeAll()
        tab.runningLLMTask?.cancel()
        tab.runningLLMTask = nil
        tab.isLLMRunning = false
        tab.isLLMThinking = false
        tab.currentTaskPrompt = ""
        tab.currentAppleAIPrompt = ""
        if queueCount > 0 {
            tab.appendLog("🚫 Cancelled. \(queueCount) queued task(s) cleared.")
        } else {
            tab.appendLog("🚫 Cancelled.")
        }
        tab.flush()
    }

    // MARK: - Tab Task Execution Loop

    func executeTabTask(tab: ScriptTab, prompt: String) async {
        tab.isLLMRunning = true
        tab.llmMessages = []  // Fresh conversation for each task
        tabTaskLog.info("[\(tab.displayTitle)] executeTabTask started: \(prompt.prefix(80))")

        var commandsRun: [String] = []
        var completionSummary = ""
        var directCommandContext: String?

        tab.appendLog("--- Tab Task ---")
        tab.appendLog("🧑 \(prompt)")
        tab.flush()

        // Triage: direct commands and Apple AI conversation (same as main task)
        let mediator = AppleIntelligenceMediator.shared
        let triageResult = await mediator.triagePrompt(prompt)
        switch triageResult {
        case .directCommand(let cmd):
            if cmd.name == "run_agent" {
                // Parse "AgentName args" from cmd.argument
                let parts = cmd.argument.components(separatedBy: " ")
                let agentName = scriptService.resolveScriptName(parts.first ?? "")
                let args = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
                // Always run directly — skip LLM. Args provided by user.
                if scriptService.compileCommand(name: agentName) != nil {
                    let success = await runAgentDirect(name: agentName, arguments: args)
                    if success {
                        tab.isLLMRunning = false
                        tab.isLLMThinking = false
                        return
                    }
                    // Failed — fall through to LLM to handle
                    tab.appendLog("❌ Direct run failed — passing to LLM")
                    tab.flush()
                    break
                }
            }
            tabTaskLog.info("[\(tab.displayTitle)] Direct command: \(cmd.name)")
            let output = await executeDirectCommand(cmd, tab: tab)
            tab.flush()

            // Web commands: show results and complete
            if cmd.name == "web_open" {
                tab.appendLog("✅ \(output)")
                tab.flush()
            }
            if cmd.name == "web_open_and_search" {
                // Show a preview of search results in the log
                if let data = output.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let title = json["title"] as? String,
                   let url = json["url"] as? String {
                    tab.appendLog("✅ \(title)")
                    tab.appendLog("🔗 \(url)")
                    if let content = json["content"] as? String {
                        tab.appendLog(String(content.prefix(1000)))
                    }
                } else {
                    tab.appendLog("✅ Search complete. Results on screen.")
                }
                tab.flush()
            }
            // google_search with results: pass to LLM for formatting
            if cmd.name == "google_search" && output.contains("\"success\": true") {
                tabTaskLog.info("[\(tab.displayTitle)] google_search succeeded — passing to LLM")
                directCommandContext = "Format these Google search results for the user. Be concise — show the top results with titles, URLs, and brief descriptions:\n\n\(output)"
                break
            }

            completionSummary = "Executed \(cmd.name)"
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let time = formatter.string(from: Date())
            tab.tabTaskSummaries.append("[\(time)] \(prompt) → \(completionSummary)")
            history.add(TaskRecord(prompt: prompt, summary: completionSummary, commandsRun: [cmd.name]), maxBeforeSummary: maxHistoryBeforeSummary, apiKey: apiKey, model: selectedModel)
            tab.flush()
            tab.isLLMRunning = false
            tab.isLLMThinking = false
            return
        case .answered(let reply):
            tabTaskLog.info("[\(tab.displayTitle)] Apple AI answered directly")
            tab.appendLog(reply)
            tab.flush()
            completionSummary = String(reply.prefix(200))
            history.add(TaskRecord(prompt: prompt, summary: completionSummary, commandsRun: []), maxBeforeSummary: maxHistoryBeforeSummary, apiKey: apiKey, model: selectedModel)
            tab.flush()
            tab.isLLMRunning = false
            tab.isLLMThinking = false
            return
        case .passThrough:
            break
        }

        // Build tab context from the existing log (cap at 8K characters)
        let tabContext = String(tab.activityLog.suffix(8000))
        let tccNote: String
        let lowerName = tab.scriptName.lowercased()
        if lowerName == "osascript" {
            tccNote = """
            This is a TCC tab with full Automation, Accessibility, and Screen Recording permissions. \
            Commands here run in the Agent app process. Use this tab for osascript, AppleScript, \
            and any commands that need TCC grants. Use lookup_sdef to check an app's scripting dictionary \
            before writing osascript commands.
            """
        } else if lowerName == "screencapture" {
            tccNote = """
            This is a TCC tab for screen capture. Commands run in the Agent app process with \
            Screen Recording permission. Use screencapture or ax_screenshot here.
            """
        } else {
            tccNote = "Help them debug, modify, re-run scripts, or perform any follow-up actions."
        }
        let tabHistoryContext = """

        \nYou are in a tab named "\(tab.scriptName)". The user can see the tab's output.
        \(tccNote)
        The tab's recent output is below for context:

        \(tabContext)
        """

        // Use tab's project folder if set, otherwise fall back to main project folder
        // Resolve to directory (strip filename if path points to a file like .xcodeproj)
        let rawFolder = tab.projectFolder.isEmpty ? self.projectFolder : tab.projectFolder
        let projectFolder = Self.resolvedWorkingDirectory(rawFolder)

        let (provider, modelId) = resolvedLLMConfig(for: tab)
        tabTaskLog.info("[\(tab.displayTitle)] resolved LLM: \(provider.displayName) / \(modelId)")
        tab.appendLog("🧠 \(provider.displayName) / \(modelId)")
        tab.flush()

        let mt = maxTokens
        let claude: ClaudeService?
        if provider == .claude {
            claude = ClaudeService(apiKey: apiKey, model: modelId, historyContext: tabHistoryContext, projectFolder: projectFolder, maxTokens: mt)
        } else if provider == .lmStudio && lmStudioProtocol == .anthropic {
            claude = ClaudeService(apiKey: lmStudioAPIKey, model: modelId, historyContext: tabHistoryContext, projectFolder: projectFolder, baseURL: lmStudioEndpoint, maxTokens: mt)
        } else {
            claude = nil
        }
        let openAICompatible: OpenAICompatibleService?
        switch provider {
        case .openAI:
            openAICompatible = OpenAICompatibleService(apiKey: openAIAPIKey, model: modelId, baseURL: "https://api.openai.com/v1/chat/completions", historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .openAI, maxTokens: mt)
        case .deepSeek:
            openAICompatible = OpenAICompatibleService(apiKey: deepSeekAPIKey, model: modelId, baseURL: "https://api.deepseek.com/chat/completions", historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .deepSeek, maxTokens: mt)
        case .huggingFace:
            openAICompatible = OpenAICompatibleService(apiKey: huggingFaceAPIKey, model: modelId, baseURL: "https://router.huggingface.co/v1/chat/completions", historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .huggingFace, maxTokens: mt)
        case .vLLM:
            openAICompatible = OpenAICompatibleService(apiKey: vLLMAPIKey, model: modelId, baseURL: vLLMEndpoint, historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .vLLM, maxTokens: mt)
        case .lmStudio where lmStudioProtocol != .anthropic:
            let key = lmStudioProtocol == .lmStudio ? "input" : "messages"
            openAICompatible = OpenAICompatibleService(apiKey: lmStudioAPIKey, model: modelId, baseURL: lmStudioEndpoint, historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .lmStudio, messagesKey: key, maxTokens: mt)
        default:
            openAICompatible = nil
        }
        let ollama: OllamaService?
        switch provider {
        case .ollama:
            ollama = OllamaService(apiKey: ollamaAPIKey, model: modelId, endpoint: ollamaEndpoint, supportsVision: false, historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .ollama)
        case .localOllama:
            ollama = OllamaService(apiKey: "", model: modelId, endpoint: localOllamaEndpoint, supportsVision: false, historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .localOllama, contextSize: localOllamaContextSize)
        default:
            ollama = nil
        }
        
        let foundationModelService: FoundationModelService? = provider == .foundationModel
            ? FoundationModelService(historyContext: tabHistoryContext, projectFolder: projectFolder) : nil

        // Set temperature per provider
        claude?.temperature = temperatureForProvider(.claude)
        ollama?.temperature = temperatureForProvider(provider)
        openAICompatible?.temperature = temperatureForProvider(provider)

        // Build on existing conversation or start fresh
        var messages: [[String: Any]] = tab.llmMessages

        // Remove trailing assistant messages — Ollama requires the last message
        // to be user or tool role. Strip any assistant messages at the end
        // (orphaned tool calls or plain text from a previous session/restart).
        while let last = messages.last, last["role"] as? String == "assistant" {
            messages.removeLast()
        }

        // Apple Intelligence context — prepend to user prompt (not separate message)
        var promptPrefix = ""
        if directCommandContext == nil && mediator.isEnabled && mediator.injectContextToLLM {
            if let contextAnnotation = await mediator.contextualizeUserMessage(prompt) {
                tab.currentAppleAIPrompt = contextAnnotation.content
                promptPrefix = contextAnnotation.content + "\n\n"
                tab.appendLog(contextAnnotation.formatted)
                tab.flush()
            }
        }

        // Inject direct command context if set
        if let context = directCommandContext {
            messages.append(["role": "user", "content": context])
            tab.appendLog("📄 Page results passed to LLM (\(context.count) chars)")
            tab.flush()
        }

        if !attachedImagesBase64.isEmpty {
            tab.appendLog("(\(attachedImagesBase64.count) screenshot(s) attached)")
            tab.flush()
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
            contentBlocks.append(["type": "text", "text": prompt])
            messages.append(["role": "user", "content": contentBlocks])
            attachedImages.removeAll()
            attachedImagesBase64.removeAll()
        } else {
            messages.append(["role": "user", "content": promptPrefix + prompt])
        }

        // All tool groups available — user controls via UI toggles
        let activeGroups: Set<String>? = nil

        var iterations = 0
        var timeoutRetryCount = 0
        let maxTimeoutRetries = maxRetries

        while !Task.isCancelled {
            iterations += 1

            // Prune old messages every 8 iterations to save tokens (same as main task)
            if iterations > 1 && iterations % 8 == 0 && messages.count > 14 {
                let beforeCount = messages.count
                Self.pruneMessages(&messages)
                tabTaskLog.info("[\(tab.displayTitle)] pruned messages: \(beforeCount) → \(messages.count)")
            }
            if iterations > 2 { Self.stripOldImages(&messages) }

            tabTaskLog.info("[\(tab.displayTitle)] iteration \(iterations)")

            do {
                tab.isLLMThinking = true
                let response: (content: [[String: Any]], stopReason: String, inputTokens: Int, outputTokens: Int)
                var textWasStreamed = false
                let streamStart = CFAbsoluteTimeGetCurrent()

                if let claude {
                    response = try await claude.sendStreaming(messages: messages, activeGroups: activeGroups) { [weak tab] delta in
                        Task { @MainActor in
                            tab?.isLLMThinking = false
                            tab?.appendStreamDelta(delta)
                        }
                    }
                    textWasStreamed = true
                    tab.flushStreamBuffer()
                } else if let openAICompatible {
                    let r = try await openAICompatible.sendStreaming(messages: messages, activeGroups: activeGroups) { [weak tab] delta in
                        Task { @MainActor in
                            tab?.isLLMThinking = false
                            tab?.appendStreamDelta(delta)
                        }
                    }
                    response = (r.content, r.stopReason, 0, 0)
                    textWasStreamed = true
                    tab.flushStreamBuffer()
                } else if let ollama {
                    let r = try await ollama.sendStreaming(messages: messages, activeGroups: activeGroups) { [weak tab] delta in
                        Task { @MainActor in
                            tab?.isLLMThinking = false
                            tab?.appendStreamDelta(delta)
                        }
                    }
                    response = (r.content, r.stopReason, 0, 0)
                    textWasStreamed = true
                    tab.flushStreamBuffer()
                } else if let foundationModelService {
                    let r = try await foundationModelService.sendStreaming(messages: messages) { [weak tab] delta in
                        Task { @MainActor in
                            tab?.isLLMThinking = false
                            tab?.appendStreamDelta(delta)
                        }
                    }
                    response = (r.content, r.stopReason, 0, 0)
                    textWasStreamed = true
                    tab.flushStreamBuffer()
                } else {
                    throw AgentError.noAPIKey
                }
                // Track token usage
                taskInputTokens += response.inputTokens
                taskOutputTokens += response.outputTokens
                sessionInputTokens += response.inputTokens
                sessionOutputTokens += response.outputTokens
                let streamElapsed = CFAbsoluteTimeGetCurrent() - streamStart
                tabTaskLog.info("[\(tab.displayTitle)] stream completed in \(String(format: "%.2f", streamElapsed))s, stopReason=\(response.stopReason), tokens: \(response.inputTokens)in/\(response.outputTokens)out")
                // Show timing in activity log so user can see what's slow
                tab.appendLog("⏱️ LLM \(String(format: "%.1f", streamElapsed))s | stop: \(response.stopReason) | iter \(iterations)")
                tab.flush()
                tab.isLLMThinking = false
                timeoutRetryCount = 0 // Reset on successful response
                guard !Task.isCancelled else { break }

                var toolResults: [[String: Any]] = []
                var hasToolUse = false

                for block in response.content {
                    guard let type = block["type"] as? String else { continue }

                    if type == "text", let text = block["text"] as? String {
                        if !textWasStreamed { tab.appendLog(text) }
                    } else if type == "tool_use" {
                        hasToolUse = true
                        guard let toolId = block["id"] as? String,
                              let rawName = block["name"] as? String,
                              let rawInput = block["input"] as? [String: Any] else { continue }

                        // Expand consolidated CRUDL tools into legacy tool names
                        let (name, input) = Self.expandConsolidatedTool(name: rawName, input: rawInput)

                        commandsRun.append(name)
                        if name == "task_complete" {
                            completionSummary = input["summary"] as? String ?? "Done"
                        }
                        let toolStart = CFAbsoluteTimeGetCurrent()
                        let result = await handleTabToolCall(
                            tab: tab, name: name, input: input, toolId: toolId
                        )
                        let toolElapsed = CFAbsoluteTimeGetCurrent() - toolStart
                        if toolElapsed > 0.5 {
                            tab.appendLog("⏱️ \(name) \(String(format: "%.1f", toolElapsed))s")
                            tab.flush()
                        }
                        if result.isComplete {
                            tab.llmMessages = messages
                            // Save task history for tab
                            let formatter = DateFormatter()
                            formatter.dateFormat = "HH:mm:ss"
                            let time = formatter.string(from: Date())
                            tab.tabTaskSummaries.append("[\(time)] \(prompt) → \(completionSummary)")
                            history.add(TaskRecord(prompt: prompt, summary: completionSummary, commandsRun: commandsRun), maxBeforeSummary: maxHistoryBeforeSummary, apiKey: apiKey, model: selectedModel)
                            tab.isLLMRunning = false
                            tab.isLLMThinking = false
                            return
                        }
                        if let toolResult = result.toolResult {
                            toolResults.append(toolResult)
                        }
                    }
                }

                messages.append(["role": "assistant", "content": response.content])
                tab.llmMessages = messages

                if hasToolUse && !toolResults.isEmpty {
                    messages.append(["role": "user", "content": toolResults])
                    tab.llmMessages = messages
                } else if !hasToolUse {
                    // LLM responded with text and no tool calls — task is complete
                    // The LLM should have called task_complete but didn't; treat text-only response as done
                    let responseText = response.content.compactMap { $0["text"] as? String }.joined()
                    if !responseText.isEmpty {
                        tab.appendLog(responseText)
                        tab.flush()
                    }
                    break
                }

            } catch {
                if !Task.isCancelled {
                    let errMsg = error.localizedDescription
                    
                    // Detect timeout errors
                    let isNetworkTimeout = errMsg.lowercased().contains("timeout") || errMsg.lowercased().contains("timed out")
                    
                    tabTaskLog.error("[\(tab.displayTitle)] LLM error at iteration \(iterations): \(errMsg) (isTimeout: \(isNetworkTimeout))")
                    
                    // Determine error source for better logging
                    var errorSource = "Unknown"
                    if claude != nil {
                        errorSource = "Claude API"
                    } else if openAICompatible != nil {
                        errorSource = "\(provider.displayName) API"
                    } else if ollama != nil {
                        errorSource = "Ollama API"
                    } else if foundationModelService != nil {
                        errorSource = "Apple Intelligence"
                    }
                    
                    
                    // Handle timeout errors with retry logic
                    if isNetworkTimeout {
                        // Check if we've already retried this timeout
                        if timeoutRetryCount < maxTimeoutRetries {
                            timeoutRetryCount += 1
                            
                            // Special handling for Ollama timeouts - check server health
                            if errorSource == "Ollama API" || errorSource == "Local Ollama" {
                                tab.appendLog("🔍 Checking Ollama server health...")
                                
                                // Run Ollama health check in background
                                let healthCheckResult = await Self.offMain {
                                    let healthCheckTask = Process()
                                    healthCheckTask.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                                    healthCheckTask.arguments = ["-s", "-f", "http://localhost:11434/api/tags", "--max-time", "5"]
                                    
                                    let pipe = Pipe()
                                    healthCheckTask.standardOutput = pipe
                                    healthCheckTask.standardError = pipe
                                    
                                    do {
                                        try healthCheckTask.run()
                                        healthCheckTask.waitUntilExit()
                                        return healthCheckTask.terminationStatus
                                    } catch {
                                        return -1
                                    }
                                }
                                
                                if healthCheckResult != 0 {
                                    tab.appendLog("⚠️ Ollama server not responding. Attempting to restart...")
                                    
                                    // Restart Ollama via UserService XPC
                                    _ = await userService.execute(command: "pkill -f 'ollama serve' && sleep 2 && open /Applications/Ollama.app")
                                    tab.appendLog("🔄 Restart command executed")
                                    
                                    // Wait longer for Ollama startup
                                    let startupDelay = TimeInterval(min(10 * timeoutRetryCount, 30)) // Exponential backoff up to 30 seconds
                                    let retryMessage = "\(errorSource) timeout detected (attempt \(timeoutRetryCount)/\(maxTimeoutRetries)) — Ollama restart attempted, waiting \(Int(startupDelay)) seconds..."
                                    tab.appendLog(retryMessage)
                                    
                                    try? await Task.sleep(for: .seconds(startupDelay))
                                    if Task.isCancelled { break }
                                    continue
                                } else {
                                    tab.appendLog("✅ Ollama server is running but API timed out")
                                }
                            }
                            
                            let retryDelay = TimeInterval(min(10 * timeoutRetryCount, 30)) // Exponential backoff up to 30 seconds
                            let retryMessage = "\(errorSource) timeout detected (attempt \(timeoutRetryCount)/\(maxTimeoutRetries)) — retrying in \(Int(retryDelay)) seconds..."
                            tab.appendLog(retryMessage)
                            
                            // Log to task log for debugging
                            tabTaskLog.info("[\(tab.displayTitle)] \(errorSource) timeout, retry \(timeoutRetryCount)/\(maxTimeoutRetries), waiting \(retryDelay)s")
                            
                            try? await Task.sleep(for: .seconds(retryDelay))
                            if Task.isCancelled { break }
                            continue
                        } else {
                            // Max retries reached - try final Ollama restart if applicable
                            if (errorSource == "Ollama API" || errorSource == "Local Ollama") && timeoutRetryCount == maxTimeoutRetries {
                                tab.appendLog("🔄 Max retries reached. Attempting final Ollama restart...")
                                
                                // Restart Ollama via UserService XPC
                                _ = await userService.execute(command: "pkill -f 'ollama serve' && sleep 3 && open /Applications/Ollama.app && sleep 10")
                                tab.appendLog("🔄 Ollama restart attempted. Check Ollama status.")
                            }
                            
                            let timeoutMessage = "\(errorSource) timeout after \(maxTimeoutRetries) retries. Please check your network connection or try a different LLM provider."
                            tab.appendLog(timeoutMessage)
                            break
                        }
                    } else if let agentErr = error as? AgentError, agentErr.isRecoverable, timeoutRetryCount < maxTimeoutRetries {
                        // Server/network error — retry every 10 seconds
                        timeoutRetryCount += 1
                        let retryDelay: TimeInterval = 10
                        tab.appendLog("\(errorSource) recoverable error (attempt \(timeoutRetryCount)/\(maxTimeoutRetries)) — retrying in \(Int(retryDelay))s...")
                        tab.flush()
                        tabTaskLog.info("[\(tab.displayTitle)] \(errorSource) server error, retry \(timeoutRetryCount)/\(maxTimeoutRetries), waiting \(retryDelay)s")
                        try? await Task.sleep(for: .seconds(retryDelay))
                        if Task.isCancelled { break }
                        continue
                    } else {
                        // Non-recoverable error — don't retry (400 bad request, auth errors, etc.)
                        tab.appendLog("\(errorSource) Error: \(errMsg)")
                        tab.flush()

                        if mediator.isEnabled && mediator.showAnnotationsToUser {
                            if let errorAnnotation = await mediator.explainError(toolName: "LLM request", error: errMsg) {
                                tab.appendLog(errorAnnotation.formatted)
                                tab.flush()
                            }
                        }
                        break
                    }
                }
                continue
            }
        }

        tabTaskLog.info("[\(tab.displayTitle)] executeTabTask finished after \(iterations) iteration(s), cancelled=\(Task.isCancelled)")

        // Save task history if task didn't call task_complete
        if completionSummary.isEmpty {
            let summary = Task.isCancelled ? "(cancelled)" : commandsRun.isEmpty ? "(no actions)" : "(incomplete)"
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let time = formatter.string(from: Date())
            tab.tabTaskSummaries.append("[\(time)] \(prompt) → \(summary)")
            history.add(TaskRecord(prompt: prompt, summary: summary, commandsRun: commandsRun), maxBeforeSummary: maxHistoryBeforeSummary, apiKey: apiKey, model: selectedModel)
        }

        // If Messages tab task ended without task_complete, still send a reply
        if tab.isMessagesTab, let handle = tab.replyHandle {
            tab.replyHandle = nil
            let reason = Task.isCancelled ? "(cancelled)" : "(incomplete)"
            sendMessagesTabReply(reason, handle: handle)
        }

        tab.flush()
        tab.isLLMRunning = false
        tab.isLLMThinking = false
    }

    // MARK: - Tab Tool Call Handler

    struct TabToolResult {
        let toolResult: [String: Any]?
        let isComplete: Bool
    }

    /// Dispatch tab tool calls — handler bodies in AgentViewModel+TabToolHandlers.swift
    func handleTabToolCall(
        tab: ScriptTab, name: String, input: [String: Any], toolId: String
    ) async -> TabToolResult {
        await handleTabToolCallBody(tab: tab, name: name, input: input, toolId: toolId)
    }

    // MARK: - Tab Command Execution

    /// Execute a command via UserService without affecting the main ViewModel's streaming state.
    /// Working directory is set on the Process via XPC — no cd prefix needed.
    func executeForTab(command: String, projectFolder: String = "") async -> (status: Int32, output: String) {
        let dir = projectFolder.isEmpty ? "" : Self.resolvedWorkingDirectory(projectFolder)
        return await userService.execute(command: command, workingDirectory: dir)
    }
}
