
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
            tab.appendLog("Cancelled by user. \(queueCount) queued task(s) cleared.")
        } else {
            tab.appendLog("Cancelled by user.")
        }
        tab.flush()
    }

    // MARK: - Tab Task Execution Loop

    func executeTabTask(tab: ScriptTab, prompt: String) async {
        tab.isLLMRunning = true
        tabTaskLog.info("[\(tab.displayTitle)] executeTabTask started: \(prompt.prefix(80))")

        tab.appendLog("--- Tab Task ---")
        tab.appendLog("User: \(prompt)")
        tab.flush()

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
        let projectFolder = tab.projectFolder.isEmpty ? self.projectFolder : tab.projectFolder

        let (provider, modelId) = resolvedLLMConfig(for: tab)
        tabTaskLog.info("[\(tab.displayTitle)] resolved LLM: \(provider.displayName) / \(modelId)")
        tab.appendLog("Model: \(provider.displayName) / \(modelId)")
        tab.flush()

        let claude: ClaudeService?
        if provider == .claude {
            claude = ClaudeService(apiKey: apiKey, model: modelId, historyContext: tabHistoryContext, projectFolder: projectFolder)
        } else if provider == .lmStudio && lmStudioProtocol == .anthropic {
            claude = ClaudeService(apiKey: lmStudioAPIKey, model: modelId, historyContext: tabHistoryContext, projectFolder: projectFolder, baseURL: lmStudioEndpoint)
        } else {
            claude = nil
        }
        let openAICompatible: OpenAICompatibleService?
        switch provider {
        case .openAI:
            openAICompatible = OpenAICompatibleService(apiKey: openAIAPIKey, model: modelId, baseURL: "https://api.openai.com/v1/chat/completions", historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .openAI)
        case .deepSeek:
            openAICompatible = OpenAICompatibleService(apiKey: deepSeekAPIKey, model: modelId, baseURL: "https://api.deepseek.com/chat/completions", historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .deepSeek)
        case .huggingFace:
            openAICompatible = OpenAICompatibleService(apiKey: huggingFaceAPIKey, model: modelId, baseURL: "https://router.huggingface.co/v1/chat/completions", historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .huggingFace)
        case .vLLM:
            openAICompatible = OpenAICompatibleService(apiKey: vLLMAPIKey, model: modelId, baseURL: vLLMEndpoint, historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .vLLM)
        case .lmStudio where lmStudioProtocol != .anthropic:
            let key = lmStudioProtocol == .lmStudio ? "input" : "messages"
            openAICompatible = OpenAICompatibleService(apiKey: lmStudioAPIKey, model: modelId, baseURL: lmStudioEndpoint, historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .lmStudio, messagesKey: key)
        default:
            openAICompatible = nil
        }
        let ollama: OllamaService?
        switch provider {
        case .ollama:
            ollama = OllamaService(apiKey: ollamaAPIKey, model: modelId, endpoint: ollamaEndpoint, supportsVision: false, historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .ollama)
        case .localOllama:
            ollama = OllamaService(apiKey: "", model: modelId, endpoint: localOllamaEndpoint, supportsVision: false, historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .localOllama)
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
            messages.append(["role": "user", "content": prompt])
        }

        // All tool groups available — user controls via UI toggles
        let activeGroups: Set<String>? = nil

        var iterations = 0
        let maxIter = maxIterations
        var consecutiveNoTool = 0
        var timeoutRetryCount = 0
        let maxTimeoutRetries = 2

        // Apple Intelligence mediator for contextual annotations (same as main task)
        let mediator = AppleIntelligenceMediator.shared
        var appleAIAnnotations: [AppleIntelligenceMediator.Annotation] = []

        // Apple AI conversation triage — answer simple prompts directly without hitting the LLM
        var triageHandled = false
        if mediator.isEnabled {
            let triageResult = await mediator.triagePrompt(prompt)
            if case .answered(let reply) = triageResult {
                tabTaskLog.info("[\(tab.displayTitle)] Apple AI answered directly — skipping LLM")
                tab.appendLog(reply)
                tab.flush()
                tab.isLLMRunning = false
                tab.isLLMThinking = false
                return
            }
            triageHandled = true
        }

        // Add Apple Intelligence context only if triage didn't already evaluate the prompt
        if !triageHandled && mediator.isEnabled && mediator.injectContextToLLM {
            tabTaskLog.info("[\(tab.displayTitle)] Apple AI mediator: contextualizing user message...")
            if let contextAnnotation = await mediator.contextualizeUserMessage(prompt) {
                appleAIAnnotations.append(contextAnnotation)
                tab.currentAppleAIPrompt = contextAnnotation.content
                if mediator.trainingEnabled {
                    TrainingDataStore.shared.captureAppleAIDecision(contextAnnotation.content)
                }
                // Inject rephrased context into LLM messages
                let contextMessage: [String: Any] = [
                    "role": "user",
                    "content": contextAnnotation.formatted
                ]
                messages.insert(contextMessage, at: messages.count)
                tab.appendLog(contextAnnotation.formatted)
                tab.flush()
            }
        }

        while !Task.isCancelled && iterations < maxIter {
            iterations += 1
            tabTaskLog.info("[\(tab.displayTitle)] iteration \(iterations)/\(maxIter)")

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
                tab.isLLMThinking = false
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

                        let result = await handleTabToolCall(
                            tab: tab, name: name, input: input, toolId: toolId
                        )
                        if result.isComplete {
                            tab.llmMessages = messages
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
                    let truncatedResults = Self.truncateToolResults(toolResults)
                    messages.append(["role": "user", "content": truncatedResults])
                    tab.llmMessages = messages
                    consecutiveNoTool = 0
                } else if !hasToolUse {
                    // LM Studio Native/Anthropic local have no tool support — accept text response immediately
                    if provider == .lmStudio && (lmStudioProtocol == .lmStudio || lmStudioProtocol == .anthropic) {
                        break
                    }
                    consecutiveNoTool += 1
                    if consecutiveNoTool >= 3 {
                        tab.appendLog("LLM not calling tools after \(consecutiveNoTool) attempts — stopping.")
                        break
                    }
                    // No tool use this iteration — just nudge and continue
                    messages.append(["role": "user", "content": "Continue. You MUST use tools — do not output code as text. Use agent (action: create/update) for scripts, write_file/edit_file for files. Call task_complete when finished."])
                    tab.llmMessages = messages
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
                    
                    // Auto-retry on 429 rate limit after 10 seconds
                    if errMsg.contains("429") || errMsg.lowercased().contains("rate limit") || errMsg.lowercased().contains("concurrent request") {
                        tab.appendLog("Rate limited — retrying in 10 seconds...")
                        try? await Task.sleep(for: .seconds(10))
                        if Task.isCancelled { break }
                        continue
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
                                tab.appendLog("Ollama restart attempted. Please check Ollama application status.")
                            }
                            
                            let timeoutMessage = "\(errorSource) timeout after \(maxTimeoutRetries) retries. Please check your network connection or try a different LLM provider."
                            tab.appendLog(timeoutMessage)
                        }
                    } else {
                        // Non-timeout error
                        tab.appendLog("\(errorSource) Error: \(errMsg)")
                    }
                }
                break
            }
        }

        if iterations >= maxIter {
            tabTaskLog.warning("[\(tab.displayTitle)] hit max iterations (\(maxIter))")
            tab.appendLog("Reached maximum iterations (\(maxIter))")
        }

        tabTaskLog.info("[\(tab.displayTitle)] executeTabTask finished after \(iterations) iteration(s), cancelled=\(Task.isCancelled)")

        // If Messages tab task ended without task_complete, still send a reply
        if tab.isMessagesTab, let handle = tab.replyHandle {
            tab.replyHandle = nil
            let reason = Task.isCancelled ? "(cancelled)" : iterations >= maxIter ? "(max iterations)" : "(incomplete)"
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
    func executeForTab(command: String) async -> (status: Int32, output: String) {
        await userService.execute(command: command)
    }
}
