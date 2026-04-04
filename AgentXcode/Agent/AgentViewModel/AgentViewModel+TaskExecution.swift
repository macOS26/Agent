
@preconcurrency import Foundation
import AgentTools
import AgentMCP
import AgentD1F
import AgentSwift
import Cocoa


// MARK: - Task Execution Loop

extension AgentViewModel {

    func executeTask(_ prompt: String) async {
        isRunning = true
        userWasActive = false
        rootWasActive = false
        recentOutputHashes.removeAll()
        toolSteps.removeAll()
        DiffStore.shared.clear()

        // Start progress updates for iMessage requests (every 10 minutes)
        if agentReplyHandle != nil {
            startProgressUpdates(for: prompt)
        }

        if !activityLog.isEmpty {
            logBuffer += "\n"
        }
        trimToRecentTasks()
        taskInputTokens = 0
        taskOutputTokens = 0
        Self.clearToolCache()
        // All tool groups available — user controls via UI toggles
        var activeGroups: Set<String>? = codingModeEnabled ? Self.codingModeGroups : automationModeEnabled ? Self.automationModeGroups : nil
        appendLog("--- New Task ---")
        appendLog("👤 \(prompt)")
        flushLog()

        // Use ChatHistoryStore for LLM context (summaries for older tasks, full messages for recent)
        let historyContext = ChatHistoryStore.shared.buildLLMContext()
        let provider = selectedProvider
        let modelName: String
        var isVision: Bool
        switch provider {
        case .claude:
            modelName = selectedModel
            isVision = true  // Claude Sonnet/Opus/Haiku all support vision
        case .openAI:
            modelName = openAIModel
            isVision = true  // GPT-4o, GPT-4 Turbo support vision
        case .deepSeek:
            modelName = deepSeekModel
            isVision = Self.isVisionModel(deepSeekModel)
        case .huggingFace:
            modelName = huggingFaceModel
            isVision = Self.isVisionModel(huggingFaceModel)
        case .ollama:
            modelName = ollamaModel
            isVision = selectedOllamaSupportsVision || Self.isVisionModel(ollamaModel)
        case .localOllama:
            modelName = localOllamaModel
            isVision = selectedLocalOllamaSupportsVision || Self.isVisionModel(localOllamaModel)
        case .vLLM:
            modelName = vLLMModel
            isVision = Self.isVisionModel(vLLMModel)
        case .lmStudio:
            modelName = lmStudioModel
            isVision = Self.isVisionModel(lmStudioModel)
        case .zAI:
            modelName = zAIModel
            isVision = true
        case .bigModel:
            modelName = bigModelModel
            isVision = true
        case .qwen:
            modelName = qwenModel
            isVision = Self.isVisionModel(qwenModel)
        case .gemini:
            modelName = geminiModel
            isVision = true  // Gemini supports vision
        case .grok:
            modelName = grokModel
            isVision = Self.isVisionModel(grokModel)
        case .mistral:
            modelName = mistralModel
            isVision = true
        case .codestral:
            modelName = codestralModel
            isVision = false
        case .vibe:
            modelName = vibeModel
            isVision = false
        case .foundationModel:
            modelName = "Apple Intelligence"
            isVision = false // Apple Intelligence doesn't support image input
        }
        if forceVision { isVision = true }
        appendLog("🧠 \(provider.displayName) / \(modelName)\(isVision ? " (vision)" : "")")

        // Start training data capture for Apple AI LoRA fine-tuning (only when toggle is on)
        if AppleIntelligenceMediator.shared.trainingEnabled {
            TrainingDataStore.shared.startCapture(userPrompt: prompt, modelUsed: modelName)
        }
        flushLog()

        let mt = maxTokens
        let claude: ClaudeService?
        if provider == .claude {
            claude = ClaudeService(apiKey: apiKey, model: selectedModel, historyContext: historyContext, projectFolder: projectFolder, maxTokens: mt)
        } else if provider == .lmStudio && lmStudioProtocol == .anthropic {
            claude = ClaudeService(apiKey: lmStudioAPIKey, model: lmStudioModel, historyContext: historyContext, projectFolder: projectFolder, baseURL: lmStudioEndpoint, maxTokens: mt)
        } else {
            claude = nil
        }
        // OpenAI-compatible service — URLs from LLMRegistry (single source of truth)
        let openAICompatible: OpenAICompatibleService?
        switch provider {
        case .claude, .ollama, .localOllama, .foundationModel:
            openAICompatible = nil
        case .lmStudio where lmStudioProtocol == .anthropic:
            openAICompatible = nil
        case .lmStudio:
            let key = lmStudioProtocol == .lmStudio ? "input" : "messages"
            openAICompatible = OpenAICompatibleService(apiKey: apiKeyForProvider(provider), model: modelName, baseURL: lmStudioEndpoint, historyContext: historyContext, projectFolder: projectFolder, provider: provider, messagesKey: key, maxTokens: mt)
        case .vLLM:
            openAICompatible = OpenAICompatibleService(apiKey: apiKeyForProvider(provider), model: modelName, baseURL: vLLMEndpoint, historyContext: historyContext, projectFolder: projectFolder, provider: provider, maxTokens: mt)
        default:
            let url = chatURLForProvider(provider)
            openAICompatible = url.isEmpty ? nil : OpenAICompatibleService(apiKey: apiKeyForProvider(provider), model: modelName, baseURL: url, supportsVision: isVision, historyContext: historyContext, projectFolder: projectFolder, provider: provider, maxTokens: mt)
        }
        let ollama: OllamaService?
        switch provider {
        case .ollama:
            ollama = OllamaService(apiKey: ollamaAPIKey, model: ollamaModel, endpoint: ollamaEndpoint, supportsVision: isVision, historyContext: historyContext, projectFolder: projectFolder, provider: .ollama)
        case .localOllama:
            ollama = OllamaService(apiKey: "", model: localOllamaModel, endpoint: localOllamaEndpoint, supportsVision: isVision, historyContext: historyContext, projectFolder: projectFolder, provider: .localOllama, contextSize: localOllamaContextSize)
        default:
            ollama = nil
        }
        let foundationModelService: FoundationModelService? = provider == .foundationModel
            ? FoundationModelService(historyContext: historyContext, projectFolder: projectFolder) : nil

        // Set temperature per provider
        claude?.temperature = temperatureForProvider(.claude)
        ollama?.temperature = temperatureForProvider(provider)
        openAICompatible?.temperature = temperatureForProvider(provider)

        // Start fresh — no prior conversation context to avoid corrupted messages
        var messages: [[String: Any]] = []

        // No agent name injection — avoid message format issues with some APIs

        let effectivePrompt = Self.newTaskPrefix(projectFolder: projectFolder, prompt: prompt) + prompt

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

        commandsRun = []
        var completionSummary = ""
        var timeoutRetryCount = 0
        let maxTimeoutRetries = maxRetries
        
        // Apple Intelligence mediator for contextual annotations
        let mediator = AppleIntelligenceMediator.shared
        var appleAIAnnotations: [AppleIntelligenceMediator.Annotation] = []

        // Triage: direct commands, Apple AI conversation, or pass through to LLM
        let triageResult = await mediator.triagePrompt(prompt)
        switch triageResult {
        case .directCommand(let cmd):
            if cmd.name == "run_agent" {
                // Parse "AgentName args" and always run directly — skip LLM
                let parts = cmd.argument.components(separatedBy: " ")
                let agentName = await Self.offMain { [ss = scriptService] in ss.resolveScriptName(parts.first ?? "") }
                let args = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
                if await Self.offMain({ [ss = scriptService] in ss.compileCommand(name: agentName) }) != nil {
                    let success = await runAgentDirect(name: agentName, arguments: args)
                    if success {
                        completionSummary = "Ran \(agentName)"
                        history.add(TaskRecord(prompt: prompt, summary: completionSummary, commandsRun: ["run_agent: \(agentName)"]), maxBeforeSummary: maxHistoryBeforeSummary, apiKey: apiKey, model: selectedModel)
                        ChatHistoryStore.shared.endCurrentTask(summary: completionSummary)
                        stopProgressUpdates()
                        flushLog()
                        persistLogNow()
                        isRunning = false
                        isThinking = false
                        return
                    }
                    // Failed — fall through to LLM to handle
                    appendLog("Direct run failed — passing to LLM")
                    flushLog()
                    break
                }
            }
            // Execute known commands instantly without the LLM
            let output = await executeDirectCommand(cmd)
            flushLog()

            // For safari commands, pass results to LLM for formatting
            if cmd.name == "safari_open_and_search" {
                appendLog("✅ Opened page and searched. Results on screen.")
                flushLog()
            }
            if cmd.name == "google_search" && output.contains("\"success\": true") {
                messages.append(["role": "user", "content": "Format these Google search results for the user. Be concise — show the top results with titles, URLs, and brief descriptions:\n\n\(output)"])
                break  // Fall through to LLM loop
            }
            if cmd.name == "safari_read" && !output.contains("Error") {
                messages.append(["role": "user", "content": "Summarize this web page for the user. Show the title, URL, and key content:\n\n\(output)"])
                break  // Fall through to LLM loop
            }
            // safari_open: if user had additional instructions, read page and pass to LLM
            if cmd.name == "safari_open" {
                appendLog("✅ \(output)")
                // Check if the original prompt has more than just "open <url>"
                let urlArg = cmd.argument.lowercased()
                let remaining = prompt.lowercased().replacingOccurrences(of: urlArg, with: "")
                let noise = Set(["open", "safari", "in", "on", "to", "and", "the", "using", "webpage", "web", "page", "website", "url", "go", "navigate", "visit", "browse"])
                let meaningfulWords = remaining.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty && !noise.contains($0) }
                if !meaningfulWords.isEmpty {
                    // Wait briefly for page to load
                    try? await Task.sleep(for: .seconds(2))
                    let pageContent = await WebAutomationService.shared.readPageContent(maxLength: 3000)
                    let pageTitle = await WebAutomationService.shared.getPageTitle()
                    let pageURL = await WebAutomationService.shared.getPageURL()
                    messages.append(["role": "user", "content": "I opened \(pageURL) (\(pageTitle)). Here is the page content:\n\n\(pageContent)\n\nNow complete this request: \(prompt)"])
                    break  // Fall through to LLM loop
                }
            }

            completionSummary = "Executed \(cmd.name)"
            history.add(TaskRecord(prompt: prompt, summary: completionSummary, commandsRun: [cmd.name]), maxBeforeSummary: maxHistoryBeforeSummary, apiKey: apiKey, model: selectedModel)
            ChatHistoryStore.shared.endCurrentTask(summary: completionSummary)
            stopProgressUpdates()
            if agentReplyHandle != nil { sendProgressUpdate(output) }
            flushLog()
            persistLogNow()
            isRunning = false
            isThinking = false
            return
        case .answered(let reply):
            appendLog(reply)
            flushLog()
            completionSummary = String(reply.prefix(200))
            history.add(TaskRecord(prompt: prompt, summary: completionSummary, commandsRun: []), maxBeforeSummary: maxHistoryBeforeSummary, apiKey: apiKey, model: selectedModel)
            ChatHistoryStore.shared.endCurrentTask(summary: completionSummary)
            stopProgressUpdates()
            if agentReplyHandle != nil { sendProgressUpdate(reply) }
            flushLog()
            persistLogNow()
            isRunning = false
            isThinking = false
            return
        case .passThrough:
            break
        }

        // Apple Intelligence context injection removed — was confusing LLMs at task start
        // Apple AI still runs on task_complete to summarize results for the user

        var iterations = 0
        var textOnlyCount = 0

        while !Task.isCancelled {
            iterations += 1

            // Auto-enable coding mode after iteration 1 if tool calls were made
            // Skip if user is doing automation (accessibility, applescript, javascript)
            let automationTools: Set<String> = ["accessibility", "run_applescript", "run_osascript", "execute_javascript", "lookup_sdef"]
            let isAutomation = commandsRun.contains(where: { cmd in cmd.hasPrefix("ax_") || automationTools.contains(where: { cmd.contains($0) }) })
            if iterations == 2 && !codingModeEnabled && !commandsRun.isEmpty {
                codingModeEnabled = true
                activeGroups = isAutomation ? Self.automationModeGroups : Self.codingModeGroups
                // Switch to minimal system prompt for faster iterations
                let minPrompt = AgentTools.codingModePrompt(projectFolder: projectFolder)
                claude?.overrideSystemPrompt = minPrompt
                claude?.compactTools = true
                ollama?.overrideSystemPrompt = minPrompt
                ollama?.compactTools = true
                openAICompatible?.overrideSystemPrompt = minPrompt
                openAICompatible?.compactTools = true
                appendLog(isAutomation ? "⚡ Automation mode auto-enabled" : "⚡ Coding mode auto-enabled")
                flushLog()
            }

            // Prune old messages every 4 iterations to save tokens
            if iterations > 1 && iterations % 4 == 0 && messages.count > 10 {
                Self.pruneMessages(&messages)
            }
            // Strip base64 images from older messages
            if iterations > 2 {
                Self.stripOldImages(&messages)
            }
            // Drop oldest messages after 25 iterations to prevent unbounded growth
            if iterations >= 25 && messages.count > 12 {
                let keep = 8 // Keep system + recent 8 messages
                let drop = messages.count - keep
                if drop > 1 {
                    messages.removeSubrange(1..<(1 + drop)) // Keep index 0 (system), drop middle
                }
            }

            do {
                isThinking = true
                thinkingDismissed = false

                // Summarize old messages with Apple AI every 10 iterations
                if iterations > 0 && iterations % 10 == 0 {
                    await Self.summarizeOldMessages(&messages)
                }
                let sendMessages = iterations > 1 ? Self.compressMessages(messages) : messages

                let response: (content: [[String: Any]], stopReason: String, inputTokens: Int, outputTokens: Int)
                flushLog()
                if let claude {
                    response = try await claude.sendStreaming(messages: sendMessages, activeGroups: activeGroups) { [weak self] delta in
                        Task { @MainActor in
                            self?.isThinking = false
                            self?.appendStreamDelta(delta)
                        }
                    }

                } else if let openAICompatible {
                    let r = try await openAICompatible.sendStreaming(messages: sendMessages, activeGroups: activeGroups) { [weak self] delta in
                        Task { @MainActor in
                            self?.isThinking = false
                            self?.appendStreamDelta(delta)
                        }
                    }
                    response = (r.content, r.stopReason, r.inputTokens, r.outputTokens)

                } else if let ollama {
                    let r = try await ollama.sendStreaming(messages: sendMessages, activeGroups: activeGroups) { [weak self] delta in
                        Task { @MainActor in
                            self?.isThinking = false
                            self?.appendStreamDelta(delta)
                        }
                    }
                    response = (r.content, r.stopReason, r.inputTokens, r.outputTokens)

                } else if let foundationModelService {
                    let r = try await foundationModelService.sendStreaming(messages: sendMessages) { [weak self] delta in
                        Task { @MainActor in
                            self?.isThinking = false
                            self?.appendStreamDelta(delta)
                        }
                    }
                    response = (r.content, r.stopReason, 0, 0)

                } else {
                    throw AgentError.noAPIKey
                }
                // Track token usage — use reported counts or estimate from text (~4 chars/token)
                let inTok = response.inputTokens > 0 ? response.inputTokens : Self.estimateTokens(messages: messages)
                let outTok = response.outputTokens > 0 ? response.outputTokens : Self.estimateTokens(content: response.content)
                taskInputTokens += inTok
                taskOutputTokens += outTok
                sessionInputTokens += inTok
                sessionOutputTokens += outTok
                TokenUsageStore.shared.record(inputTokens: inTok, outputTokens: outTok)
                flushStreamBuffer()
                isThinking = false
                timeoutRetryCount = 0 // Reset on successful response
                guard !Task.isCancelled else { break }

                var toolResults: [[String: Any]] = []
                var hasToolUse = false
                var pendingTools: [(toolId: String, name: String, input: [String: Any])] = []

                for block in response.content {
                    guard let type = block["type"] as? String else { continue }

                    if type == "text" {
                        // Log LLM text to activity log (skip duplicates across iterations)
                        if let text = block["text"] as? String {
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            let hash = trimmed.hashValue
                            if !trimmed.isEmpty && trimmed.count > 1 && !recentOutputHashes.contains(hash) {
                                recentOutputHashes.insert(hash)
                                appendLog(trimmed)
                                flushLog()
                            }
                        }
                    } else if type == "server_tool_use" {
                        // Server-side tool (web search) — executed by the API, just log it
                        hasToolUse = true
                        if let input = block["input"] as? [String: Any],
                           let query = input["query"] as? String {
                            appendLog("Web search: \(query)")
                        }
                    } else if type == "web_search_tool_result" {
                        // Display search results summary
                        if let content = block["content"] as? [[String: Any]] {
                            let results = content.compactMap { result -> String? in
                                guard result["type"] as? String == "web_search_result",
                                      let title = result["title"] as? String,
                                      let url = result["url"] as? String else { return nil }
                                return "  \(title)\n    \(url)"
                            }
                            if !results.isEmpty {
                                appendLog("📊\n" + results.prefix(5).joined(separator: "\n"))
                            }
                        }
                        flushLog()
                    } else if type == "tool_use" {
                        hasToolUse = true
                        guard let toolId = block["id"] as? String,
                              var name = block["name"] as? String,
                              var input = block["input"] as? [String: Any] else { continue }

                        // Expand consolidated CRUDL tools into legacy tool names
                        (name, input) = Self.expandConsolidatedTool(name: name, input: input)

                        if name == "task_complete" {
                            var summary = input["summary"] as? String ?? "Done"
                            // If model sent a placeholder summary like "...", use the last LLM text instead
                            let stripped = summary.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
                            if stripped.isEmpty || summary == "..." {
                                let lastText = rawLLMOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !lastText.isEmpty { summary = String(lastText.prefix(300)) }
                            }
                            completionSummary = summary

                            // Apple Intelligence summary annotation
                            if mediator.isEnabled && mediator.showAnnotationsToUser && !commandsRun.isEmpty {
                                if let summaryAnnotation = await mediator.summarizeCompletion(summary: summary, commandsRun: commandsRun) {
                                    appleAIAnnotations.append(summaryAnnotation)
                                    appendLog(summaryAnnotation.formatted)
                                    flushLog()
                                    if agentReplyHandle != nil {
                                        sendProgressUpdate(summaryAnnotation.formatted)
                                    }
                                    // Capture Apple AI annotation for training (only when toggle is on)
                                    if mediator.trainingEnabled {
                                        TrainingDataStore.shared.captureAppleAIAnnotation(summaryAnnotation.content)
                                    }
                                }
                            }

                            appendLog("✅ Completed: \(summary)")
                            flushLog()
                            history.add(TaskRecord(prompt: prompt, summary: summary, commandsRun: commandsRun), maxBeforeSummary: maxHistoryBeforeSummary, apiKey: apiKey, model: selectedModel)
                            // End the task in SwiftData chat history
                            ChatHistoryStore.shared.endCurrentTask(summary: summary)
                            // Finish training data capture (only when toggle is on)
                            if mediator.trainingEnabled {
                                TrainingDataStore.shared.finishCapture(taskSummary: summary, successful: true)
                            }
                            // Stop progress updates before sending final reply
                            stopProgressUpdates()
                            // Reply to the iMessage sender if this was an Agent! prompt
                            sendAgentReply(summary)
                            isRunning = false
                            return
                        }

                        pendingTools.append((toolId: toolId, name: name, input: input))
                    }
                }

                // Execute pending tools — parallel if all read-only, sequential otherwise
                if !pendingTools.isEmpty {
                    let allReadOnly = pendingTools.allSatisfy { Self.readOnlyTools.contains($0.name) }

                    if allReadOnly && pendingTools.count > 1 {
                        // Parallel execution for read-only tools
                        // Pre-execute shell-based tools concurrently off MainActor, then dispatch results on MainActor
                        let shellTools: Set<String> = ["read_file", "list_files", "search_files", "read_dir", "git_status", "git_diff", "git_log", "git_diff_patch"]
                        let shellPending = pendingTools.filter { shellTools.contains($0.name) }

                        // Pre-warm shell results concurrently off MainActor
                        if shellPending.count > 1 {
                            // Capture Sendable values before entering TaskGroup
                            let capturedPF = projectFolder
                            let cmds: [(id: String, cmd: String)] = shellPending.map { tool in
                                (tool.toolId, Self.buildReadOnlyCommand(name: tool.name, input: tool.input, projectFolder: capturedPF))
                            }
                            var preResults: [String: String] = [:]
                            await withTaskGroup(of: (String, String).self) { group in
                                for (id, cmd) in cmds {
                                    let capturedId = id
                                    let capturedCmd = cmd
                                    let workDir = capturedPF.isEmpty ? NSHomeDirectory() : capturedPF
                                    group.addTask {
                                        guard !capturedCmd.isEmpty else { return (capturedId, "") }
                                        let pipe = Pipe()
                                        let process = Process()
                                        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                                        process.arguments = ["-c", capturedCmd]
                                        process.currentDirectoryURL = URL(fileURLWithPath: workDir)
                                        var env = ProcessInfo.processInfo.environment
                                        env["HOME"] = NSHomeDirectory()
                                        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                                        env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "")
                                        process.environment = env
                                        process.standardOutput = pipe
                                        process.standardError = pipe
                                        try? process.run()
                                        process.waitUntilExit()
                                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                                        return (capturedId, String(data: data, encoding: .utf8) ?? "")
                                    }
                                }
                                for await (id, result) in group {
                                    preResults[id] = result
                                }
                            }
                            Self.precomputedResults = preResults
                        }

                        // Dispatch all tools sequentially on MainActor (logging etc.) but shell tools use cached results
                        for tool in pendingTools {
                            let ctx = ToolContext(toolId: tool.toolId, projectFolder: projectFolder, selectedProvider: selectedProvider, tavilyAPIKey: tavilyAPIKey)
                            _ = await dispatchTool(name: tool.name, input: tool.input, ctx: ctx, toolResults: &toolResults)
                        }
                        Self.precomputedResults = nil
                    } else {
                        // Sequential execution
                        for tool in pendingTools {
                            let ctx = ToolContext(toolId: tool.toolId, projectFolder: projectFolder, selectedProvider: selectedProvider, tavilyAPIKey: tavilyAPIKey)
                            _ = await dispatchTool(name: tool.name, input: tool.input, ctx: ctx, toolResults: &toolResults)
                        }
                    }
                }

                // Vision verification: auto-screenshot after UI actions so the LLM can see the result
                if isVision && !pendingTools.isEmpty {
                    let uiActions: Set<String> = ["ax_click", "ax_click_element", "ax_perform_action", "ax_type_text",
                        "ax_type_into_element", "ax_open_app", "ax_scroll", "ax_drag",
                        "click", "click_element", "perform_action", "type_text", "open_app",
                        "web_click", "web_type", "web_navigate"]
                    let hadUIAction = pendingTools.contains { uiActions.contains($0.name) }
                    if hadUIAction {
                        let screenshotResult = await Self.captureVerificationScreenshot()
                        if let imageData = screenshotResult {
                            // Append screenshot as image content block to tool results
                            toolResults.append([
                                "type": "tool_result",
                                "tool_use_id": "vision_verify",
                                "content": [
                                    ["type": "text", "text": "[Auto-screenshot after UI action — verify the action succeeded]"],
                                    ["type": "image", "source": ["type": "base64", "media_type": "image/png", "data": imageData]]
                                ]
                            ])
                            appendLog("📸 Vision: auto-screenshot for verification")
                        }
                    }
                }

                // Add assistant response to conversation
                // Guard against empty content — Ollama rejects assistant messages with no content or tool_calls
                let assistantContent: Any = response.content.isEmpty
                    ? "I'll continue with the task." as Any
                    : response.content as Any
                messages.append(["role": "assistant", "content": assistantContent])

                if hasToolUse && !toolResults.isEmpty {
                    // Truncate large tool results to save tokens (cap at 8K chars each)
                    let capped = Self.truncateToolResults(toolResults)
                    messages.append(["role": "user", "content": capped])
                } else if !hasToolUse {
                    // Check if model wrote task_complete/done as text instead of a tool call
                    let responseText = response.content.compactMap { $0["text"] as? String }.joined()
                    if responseText.contains("task_complete") || responseText.contains("done(summary") {
                        if let match = responseText.range(of: #"(?:task_complete|done)\(summary[=:]\s*"([^"]+)""#, options: .regularExpression) {
                            let raw = String(responseText[match])
                            let summary = raw.replacingOccurrences(of: #"(?:task_complete|done)\(summary[=:]\s*""#, with: "", options: .regularExpression).replacingOccurrences(of: "\"", with: "")
                            appendLog("✅ Completed: \(summary)")
                        }
                        flushLog()
                        break
                    }
                    // LLM responded with text only — nudge it to continue or finish
                    textOnlyCount += 1
                    if textOnlyCount >= 3 { break }
                    messages.append(["role": "user", "content": "Continue with the next step. When you are completely done, call task_complete(summary: \"...\")."])
                } else {
                    // Check if LLM signaled it's done via text even though it made tool calls
                    let allText = response.content.compactMap { $0["text"] as? String }.joined().lowercased()
                    let stopPhrases = ["no more content", "no further action", "task is complete", "nothing more to do", "task_complete"]
                    if stopPhrases.contains(where: { allText.contains($0) }) {
                        break
                    }
                }

            } catch {
                if !Task.isCancelled {
                    let errMsg = error.localizedDescription
                    
                    // Detect timeout errors
                    let isNetworkTimeout = errMsg.lowercased().contains("timeout") || errMsg.lowercased().contains("timed out")
                    
                    
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
                                appendLog("🔍 Checking Ollama server health...")
                                flushLog()
                                
                                // Run Ollama health check in background
                                let healthCheckResult = await Self.offMain {
                                    let healthCheckTask = Process()
                                    healthCheckTask.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                                    healthCheckTask.arguments = ["-s", "-f", "http://localhost:11434/api/tags", "--max-time", "5"]
                                    healthCheckTask.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())

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
                                    appendLog("⚠️ Ollama server not responding. Attempting to restart...")
                                    flushLog()
                                    
                                    // Restart Ollama via UserService XPC
                                    _ = await userService.execute(command: "pkill -f 'ollama serve' && sleep 2 && open /Applications/Ollama.app")
                                    appendLog("🔄 Restart command executed")
                                    flushLog()
                                    
                                    // Wait longer for Ollama startup
                                    let startupDelay = TimeInterval(min(10 * timeoutRetryCount, 30)) // Exponential backoff up to 30 seconds
                                    let retryMessage = "\(errorSource) timeout detected (attempt \(timeoutRetryCount)/\(maxTimeoutRetries)) — Ollama restart attempted, waiting \(Int(startupDelay)) seconds..."
                                    appendLog(retryMessage)
                                    flushLog()
                                    if agentReplyHandle != nil {
                                        sendProgressUpdate(retryMessage)
                                    }
                                    
                                    try? await Task.sleep(for: .seconds(startupDelay))
                                    if Task.isCancelled { break }
                                    continue
                                } else {
                                    appendLog("✅ Ollama server is running but API timed out")
                                    flushLog()
                                }
                            }
                            
                            let retryDelay = TimeInterval(min(10 * timeoutRetryCount, 30)) // Exponential backoff up to 30 seconds
                            let retryMessage = "\(errorSource) timeout detected (attempt \(timeoutRetryCount)/\(maxTimeoutRetries)) — retrying in \(Int(retryDelay)) seconds..."
                            appendLog(retryMessage)
                            flushLog()
                            if agentReplyHandle != nil {
                                sendProgressUpdate(retryMessage)
                            }
                            
                            // Log to task log for debugging
                            
                            try? await Task.sleep(for: .seconds(retryDelay))
                            if Task.isCancelled { break }
                            continue
                        } else {
                            // Max retries reached - try final Ollama restart if applicable
                            if (errorSource == "Ollama API" || errorSource == "Local Ollama") && timeoutRetryCount == maxTimeoutRetries {
                                appendLog("🔄 Max retries reached. Attempting final Ollama restart...")
                                flushLog()
                                
                                // Restart Ollama via UserService XPC
                                _ = await userService.execute(command: "pkill -f 'ollama serve' && sleep 3 && open /Applications/Ollama.app && sleep 10")
                                appendLog("Ollama restart attempted. Please check Ollama application status.")
                                flushLog()
                            }
                            
                            let timeoutMessage = "\(errorSource) timeout after \(maxTimeoutRetries) retries. Please check your network connection or try a different LLM provider."
                            appendLog(timeoutMessage)
                            flushLog()
                            if agentReplyHandle != nil {
                                sendProgressUpdate(timeoutMessage)
                            }
                            break
                        }
                    } else if let agentErr = error as? AgentError, agentErr.isRecoverable, timeoutRetryCount < maxTimeoutRetries {
                        // Server/network error — retry every 10 seconds
                        timeoutRetryCount += 1
                        let retryDelay: TimeInterval = 10
                        appendLog("\(errorSource) recoverable error (attempt \(timeoutRetryCount)/\(maxTimeoutRetries)) — retrying in \(Int(retryDelay))s...\n\(errMsg)")
                        flushLog()
                        try? await Task.sleep(for: .seconds(retryDelay))
                        if Task.isCancelled { break }
                        continue
                    } else if errMsg.lowercased().contains("network") || errMsg.lowercased().contains("connection") || errMsg.lowercased().contains("internet") || (error as? URLError)?.code == .networkConnectionLost || (error as? URLError)?.code == .notConnectedToInternet {
                        timeoutRetryCount += 1
                        if timeoutRetryCount <= maxTimeoutRetries {
                            let delay = networkRetryDelay
                            appendLog("🌐 Network connection lost — retrying in \(delay)s (attempt \(timeoutRetryCount)/\(maxTimeoutRetries))...")
                            flushLog()
                            try? await Task.sleep(for: .seconds(Double(delay)))
                            if Task.isCancelled { break }
                            continue
                        } else {
                            appendLog("🌐 Network connection lost after \(maxTimeoutRetries) retries.")
                            flushLog()
                            break
                        }
                    } else {
                        // Non-recoverable error — don't retry (400 bad request, auth errors, etc.)
                        appendLog("\(errorSource) Error: \(errMsg)")
                        flushLog()

                        // Apple Intelligence error explanation
                        if mediator.isEnabled && mediator.showAnnotationsToUser {
                            if let errorAnnotation = await mediator.explainError(toolName: "LLM request", error: errMsg) {
                                appendLog(errorAnnotation.formatted)
                                flushLog()
                            }
                        }
                        break
                    }
                }
                continue
            }
        }

        // Apple Intelligence: suggest next steps after completion (skip for pure conversation)
        if mediator.isEnabled && mediator.showAnnotationsToUser && !completionSummary.isEmpty && !commandsRun.isEmpty {
            let context = "Task: \(prompt)\nResult: \(completionSummary)\nCommands: \(commandsRun.joined(separator: ", "))"
            if let nextSteps = await mediator.suggestNextSteps(context: context) {
                appendLog(nextSteps.formatted)
                flushLog()
                if agentReplyHandle != nil {
                    sendProgressUpdate(nextSteps.formatted)
                }
            }
        }

        // Always save history if task didn't call task_complete
        if completionSummary.isEmpty {
            let summary = Task.isCancelled ? "(cancelled)" : commandsRun.isEmpty ? "(no actions)" : "(incomplete)"
            history.add(TaskRecord(prompt: prompt, summary: summary, commandsRun: commandsRun), maxBeforeSummary: maxHistoryBeforeSummary, apiKey: apiKey, model: selectedModel)
        }

        // End the task in SwiftData chat history
        ChatHistoryStore.shared.endCurrentTask(summary: completionSummary.isEmpty ? nil : completionSummary, cancelled: Task.isCancelled)
        
        // Stop progress updates
        stopProgressUpdates()
        
        flushLog()
        persistLogNow()
        isRunning = false
        isThinking = false
        userServiceActive = false
        rootServiceActive = false
        userWasActive = false
        rootWasActive = false
    }
}
