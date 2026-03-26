
@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log
import Cocoa

private let taskLog = Logger(subsystem: AppConstants.subsystem, category: "TaskExecution")

// MARK: - Task Execution Loop

extension AgentViewModel {

    func executeTask(_ prompt: String) async {
        taskLog.info("[main] executeTask started: \(prompt.prefix(80))")
        isRunning = true
        userWasActive = false
        rootWasActive = false
        recentOutputHashes.removeAll()
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
        // All tool groups available — user controls via UI toggles
        let activeGroups: Set<String>? = nil
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
        case .vLLM:
            modelName = vLLMModel
            isVision = false
        case .lmStudio:
            modelName = lmStudioModel
            isVision = false
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

        let mt = maxTokens
        let claude: ClaudeService?
        if provider == .claude {
            claude = ClaudeService(apiKey: apiKey, model: selectedModel, historyContext: historyContext, projectFolder: projectFolder, maxTokens: mt)
        } else if provider == .lmStudio && lmStudioProtocol == .anthropic {
            claude = ClaudeService(apiKey: lmStudioAPIKey, model: lmStudioModel, historyContext: historyContext, projectFolder: projectFolder, baseURL: lmStudioEndpoint, maxTokens: mt)
        } else {
            claude = nil
        }
        let openAICompatible: OpenAICompatibleService?
        switch provider {
        case .openAI:
            openAICompatible = OpenAICompatibleService(apiKey: openAIAPIKey, model: openAIModel, baseURL: "https://api.openai.com/v1/chat/completions", historyContext: historyContext, projectFolder: projectFolder, provider: .openAI, maxTokens: mt)
        case .deepSeek:
            openAICompatible = OpenAICompatibleService(apiKey: deepSeekAPIKey, model: deepSeekModel, baseURL: "https://api.deepseek.com/chat/completions", historyContext: historyContext, projectFolder: projectFolder, provider: .deepSeek, maxTokens: mt)
        case .huggingFace:
            openAICompatible = OpenAICompatibleService(apiKey: huggingFaceAPIKey, model: huggingFaceModel, baseURL: "https://router.huggingface.co/v1/chat/completions", historyContext: historyContext, projectFolder: projectFolder, provider: .huggingFace, maxTokens: mt)
        case .vLLM:
            openAICompatible = OpenAICompatibleService(apiKey: vLLMAPIKey, model: vLLMModel, baseURL: vLLMEndpoint, historyContext: historyContext, projectFolder: projectFolder, provider: .vLLM, maxTokens: mt)
        case .lmStudio where lmStudioProtocol != .anthropic:
            let key = lmStudioProtocol == .lmStudio ? "input" : "messages"
            openAICompatible = OpenAICompatibleService(apiKey: lmStudioAPIKey, model: lmStudioModel, baseURL: lmStudioEndpoint, historyContext: historyContext, projectFolder: projectFolder, provider: .lmStudio, messagesKey: key, maxTokens: mt)
        default:
            openAICompatible = nil
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

        var commandsRun: [String] = []
        var completionSummary = ""
        var timeoutRetryCount = 0
        let maxTimeoutRetries = 2
        
        // Apple Intelligence mediator for contextual annotations
        let mediator = AppleIntelligenceMediator.shared
        var appleAIAnnotations: [AppleIntelligenceMediator.Annotation] = []

        // Triage: direct commands, Apple AI conversation, or pass through to LLM
        let triageResult = await mediator.triagePrompt(prompt)
        switch triageResult {
        case .directCommand(let cmd):
            // For run_agent, check metadata — only run directly if no args needed
            if cmd.name == "run_agent" {
                let resolved = scriptService.resolveScriptName(cmd.argument)
                if !scriptService.canRunDirectly(name: resolved) {
                    taskLog.info("[main] run_agent '\(resolved)' requires args — passing to LLM")
                    break  // Fall through to LLM
                }
            }
            // Execute known commands instantly without the LLM
            taskLog.info("[main] Direct command: \(cmd.name) arg=\(cmd.argument)")
            let output = await executeDirectCommand(cmd)
            flushLog()

            // For safari commands, pass results to LLM for formatting
            if cmd.name == "safari_open_and_search" {
                appendLog("✅ Opened page and searched. Results on screen.")
                flushLog()
            }
            if cmd.name == "google_search" && output.contains("\"success\": true") {
                taskLog.info("[main] google_search succeeded — passing to LLM for formatting")
                messages.append(["role": "user", "content": "Format these Google search results for the user. Be concise — show the top results with titles, URLs, and brief descriptions:\n\n\(output)"])
                break  // Fall through to LLM loop
            }
            if cmd.name == "safari_read" && !output.contains("Error") {
                taskLog.info("[main] safari_read succeeded — passing to LLM for formatting")
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
                    taskLog.info("[main] safari_open has extra instructions — passing page to LLM")
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
            taskLog.info("[main] Apple AI answered directly — skipping LLM")
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

        // Add Apple Intelligence context to help LLM understand complex prompts
        // Prepend to the existing user message (not a separate message) to avoid
        // consecutive user messages which confuse Ollama/Mistral models.
        if mediator.isEnabled && mediator.injectContextToLLM {
            taskLog.info("[main] Apple AI mediator: contextualizing (available: \(AppleIntelligenceMediator.isAvailable))...")
            if let contextAnnotation = await mediator.contextualizeUserMessage(prompt) {
                appleAIAnnotations.append(contextAnnotation)
                currentAppleAIPrompt = contextAnnotation.content
                if mediator.trainingEnabled {
                    TrainingDataStore.shared.captureAppleAIDecision(contextAnnotation.content)
                }
                // Prepend Apple AI context to the first user message
                if let lastIdx = messages.indices.last {
                    if let existingText = messages[lastIdx]["content"] as? String {
                        messages[lastIdx]["content"] = contextAnnotation.content + "\n\n" + existingText
                    } else if var blocks = messages[lastIdx]["content"] as? [[String: Any]] {
                        // Image message — prepend context as a text block
                        blocks.insert(["type": "text", "text": contextAnnotation.content], at: 0)
                        messages[lastIdx]["content"] = blocks
                    }
                }
                appendLog(contextAnnotation.formatted)
                flushLog()
                if agentReplyHandle != nil {
                    sendProgressUpdate(contextAnnotation.formatted)
                }
            }
        }

        var iterations = 0

        while !Task.isCancelled {
            iterations += 1

            // Prune old messages every 8 iterations to save tokens
            if iterations > 1 && iterations % 8 == 0 && messages.count > 14 {
                let beforeCount = messages.count
                Self.pruneMessages(&messages)
                taskLog.info("[main] pruned messages: \(beforeCount) → \(messages.count)")
            }
            // Strip base64 images from older messages
            if iterations > 2 {
                Self.stripOldImages(&messages)
            }

            taskLog.info("[main] iteration \(iterations), messages=\(messages.count)")

            do {
                isThinking = true

                // Log messages being sent to the LLM
                taskLog.info("[main] Sending \(messages.count) messages to LLM:")
                for (idx, msg) in messages.enumerated() {
                    let role = msg["role"] as? String ?? "?"
                    let preview: String
                    if let text = msg["content"] as? String {
                        preview = String(text.prefix(120))
                    } else if let blocks = msg["content"] as? [[String: Any]] {
                        let types = blocks.compactMap { $0["type"] as? String }
                        preview = "[\(blocks.count) blocks: \(types.joined(separator: ", "))]"
                    } else {
                        preview = "(unknown content type)"
                    }
                    taskLog.info("[main]   [\(idx)] \(role): \(preview)")
                }

                let response: (content: [[String: Any]], stopReason: String, inputTokens: Int, outputTokens: Int)
                var textWasStreamed = false
                let streamStart = CFAbsoluteTimeGetCurrent()
                flushLog()
                if let claude {
                    response = try await claude.sendStreaming(messages: messages, activeGroups: activeGroups) { [weak self] delta in
                        Task { @MainActor in
                            self?.isThinking = false
                            self?.appendStreamDelta(delta)
                        }
                    }
                    textWasStreamed = true
                } else if let openAICompatible {
                    let r = try await openAICompatible.sendStreaming(messages: messages, activeGroups: activeGroups) { [weak self] delta in
                        Task { @MainActor in
                            self?.isThinking = false
                            self?.appendStreamDelta(delta)
                        }
                    }
                    response = (r.content, r.stopReason, 0, 0)
                    textWasStreamed = true
                } else if let ollama {
                    let r = try await ollama.sendStreaming(messages: messages, activeGroups: activeGroups) { [weak self] delta in
                        Task { @MainActor in
                            self?.isThinking = false
                            self?.appendStreamDelta(delta)
                        }
                    }
                    response = (r.content, r.stopReason, 0, 0)
                    textWasStreamed = true
                } else if let foundationModelService {
                    let r = try await foundationModelService.sendStreaming(messages: messages) { [weak self] delta in
                        Task { @MainActor in
                            self?.isThinking = false
                            self?.appendStreamDelta(delta)
                        }
                    }
                    response = (r.content, r.stopReason, 0, 0)
                    textWasStreamed = true
                } else {
                    throw AgentError.noAPIKey
                }
                // Track token usage
                taskInputTokens += response.inputTokens
                taskOutputTokens += response.outputTokens
                sessionInputTokens += response.inputTokens
                sessionOutputTokens += response.outputTokens
                let streamElapsed = CFAbsoluteTimeGetCurrent() - streamStart
                taskLog.info("[main] stream completed in \(String(format: "%.2f", streamElapsed))s, stopReason=\(response.stopReason), tokens: \(response.inputTokens)in/\(response.outputTokens)out")
                flushStreamBuffer()
                isThinking = false
                guard !Task.isCancelled else { break }

                var toolResults: [[String: Any]] = []
                var hasToolUse = false

                for block in response.content {
                    guard let type = block["type"] as? String else { continue }

                    if type == "text", let text = block["text"] as? String {
                        if !textWasStreamed { appendLog(text) }
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
                                appendLog("Results:\n" + results.prefix(5).joined(separator: "\n"))
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
                            let summary = input["summary"] as? String ?? "Done"
                            completionSummary = summary
                            
                            // Apple Intelligence summary annotation
                            if mediator.isEnabled && mediator.showAnnotationsToUser && !commandsRun.isEmpty {
                                taskLog.info("[main] Apple AI mediator: summarizing completion...")
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

                        // MARK: MCP tool calls (mcp_ServerName_toolName)
                        if await handleMCPTool(
                            name: name,
                            input: input,
                            toolId: toolId,
                            appendLog: { @MainActor [weak self] msg in self?.appendLog(msg) },
                            flushLog: { @MainActor [weak self] in self?.flushLog() },
                            toolResults: &toolResults
                        ) {
                            continue
                        }

                        // MARK: Pure file I/O tools (CodingService — no processes)

                        if name == "read_file" {
                            let filePath = input["file_path"] as? String ?? ""
                            let offset = input["offset"] as? Int
                            let limit = input["limit"] as? Int
                            appendLog("📖 Read: \(filePath)")
                            let output = await Self.offMain { CodingService.readFile(path: filePath, offset: offset, limit: limit) }
                            let lang = Self.langFromPath(filePath)
                            appendLog(Self.codeFence(Self.preview(output, lines: readFilePreviewLines), language: lang))
                            // For large files without offset/limit, return a truncated preview
                            // and tell the model to use offset/limit for specific sections
                            let lineCount = output.components(separatedBy: "\n").count
                            let maxLines = 200
                            if lineCount > maxLines && offset == nil && limit == nil {
                                let preview = output.components(separatedBy: "\n").prefix(maxLines).joined(separator: "\n")
                                let toolOutput = preview + "\n\n--- FILE HAS \(lineCount) LINES (showing first \(maxLines)) ---\nUse read_file with offset and limit to read specific sections. Example: offset: 200, limit: 100"
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": toolOutput])
                            } else {
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                            }
                        }

                        if name == "write_file" {
                            let filePath = input["file_path"] as? String ?? ""
                            let content = input["content"] as? String ?? ""
                            appendLog("📝 Write: \(filePath)")
                            let output = await Self.offMain { CodingService.writeFile(path: filePath, content: content) }
                            appendLog(output)
                            commandsRun.append("write_file: \(filePath)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "edit_file" {
                            let filePath = input["file_path"] as? String ?? ""
                            let oldString = input["old_string"] as? String ?? ""
                            let newString = input["new_string"] as? String ?? ""
                            let replaceAll = input["replace_all"] as? Bool ?? false
                            appendLog("📝 Edit: \(filePath)")

                            let output = await Self.offMain { CodingService.editFile(path: filePath, oldString: oldString, newString: newString, replaceAll: replaceAll) }

                            // Show D1F pretty diff with metadata
                            let diff = MultiLineDiff.createDiff(source: oldString, destination: newString, includeMetadata: true)
                            var d1f = MultiLineDiff.displayDiff(diff: diff, source: oldString, format: .ai)
                            // displayDiff can be empty for single-line character changes — show lines directly
                            if d1f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                d1f = "❌ " + oldString + "\n" + "✅ " + newString
                            }
                            var diffLog = d1f
                            if let meta = diff.metadata, let startLine = meta.sourceStartLine {
                                diffLog += "\n📍 Changes start at line \(startLine + 1)"
                                if let total = meta.sourceTotalLines {
                                    diffLog += " (of \(total) lines)"
                                }
                            }
                            appendRawOutput(diffLog + "\n")

                            appendLog(output)
                            commandsRun.append("edit_file: \(filePath)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "create_diff" {
                            var source = input["source"] as? String ?? ""
                            let destination = input["destination"] as? String ?? ""
                            // Read source from file if file_path provided
                            if let fp = input["file_path"] as? String, !fp.isEmpty {
                                let expanded = (fp as NSString).expandingTildeInPath
                                if let data = FileManager.default.contents(atPath: expanded),
                                   let text = String(data: data, encoding: .utf8) {
                                    source = text
                                }
                            }
                            let diff = MultiLineDiff.createDiff(source: source, destination: destination, includeMetadata: true)
                            let d1f = MultiLineDiff.displayDiff(diff: diff, source: source, format: .ai)
                            let summary = MultiLineDiff.generateDiffSummary(source: source, destination: destination)
                            let diffId = DiffStore.shared.store(diff: diff, source: source)
                            var result = "diff_id: \(diffId.uuidString)\n\n" + d1f + "\n\n" + summary
                            if let meta = diff.metadata, let startLine = meta.sourceStartLine {
                                result += "\n📍 Changes start at line \(startLine + 1)"
                            }
                            appendRawOutput(result + "\n")
                            commandsRun.append("create_diff")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": result])
                        }

                        if name == "apply_diff" {
                            let filePath = input["file_path"] as? String ?? ""
                            let diffIdStr = input["diff_id"] as? String ?? ""
                            let asciiDiff = input["diff"] as? String ?? ""
                            appendLog("📝 Apply D1F diff: \(filePath)")
                            let expandedPath = (filePath as NSString).expandingTildeInPath
                            guard let data = FileManager.default.contents(atPath: expandedPath),
                                  let source = String(data: data, encoding: .utf8) else {
                                let err = "Error: cannot read \(filePath)"
                                appendLog(err)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                                continue
                            }
                            do {
                                let patched: String
                                if let uuid = UUID(uuidString: diffIdStr),
                                   let stored = DiffStore.shared.retrieve(uuid) {
                                    patched = try MultiLineDiff.applyDiff(to: source, diff: stored.diff)
                                } else if !asciiDiff.isEmpty {
                                    patched = try MultiLineDiff.applyASCIIDiff(to: source, asciiDiff: asciiDiff)
                                } else {
                                    throw DiffError.invalidDiff
                                }
                                try patched.write(to: URL(fileURLWithPath: expandedPath), atomically: true, encoding: .utf8)
                                let verifyDiff = MultiLineDiff.createAndDisplayDiff(source: source, destination: patched, format: .ai)
                                appendRawOutput(verifyDiff + "\n")
                                let output = "Applied diff to \(filePath)"
                                appendLog(output)
                                commandsRun.append("apply_diff: \(filePath)")
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                            } catch {
                                let err = "Error applying diff: \(error.localizedDescription)"
                                appendLog(err)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                            }
                        }

                        // MARK: Process-based tools (routed through User LaunchAgent via XPC)

                        if name == "list_files" {
                            let pattern = input["pattern"] as? String ?? "*"
                            let path = input["path"] as? String
                            if let pathErr = Self.checkPath(path) {
                                appendLog(pathErr)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": pathErr])
                                continue
                            }
                            appendLog("🔍 $ find \(path ?? "~") -name '\(pattern)'")
                            flushLog()
                            let cmd = CodingService.buildListFilesCommand(pattern: pattern, path: path)
                            let result = await executeViaUserAgent(command: cmd)
                            guard !Task.isCancelled else { break }
                            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "No files matching '\(pattern)'" : result.output
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "search_files" {
                            let pattern = input["pattern"] as? String ?? ""
                            let path = input["path"] as? String
                            let include = input["include"] as? String
                            if let pathErr = Self.checkPath(path) {
                                appendLog(pathErr)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": pathErr])
                                continue
                            }
                            appendLog("🔍 $ grep -rn '\(pattern)' \(path ?? "~")\(include.map { " --include=\($0)" } ?? "")")
                            flushLog()
                            let cmd = CodingService.buildSearchFilesCommand(pattern: pattern, path: path, include: include)
                            let result = await executeViaUserAgent(command: cmd)
                            guard !Task.isCancelled else { break }
                            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "No matches for '\(pattern)'" : result.output
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "read_dir" {
                            let path = input["path"] as? String ?? projectFolder
                            if let pathErr = Self.checkPath(path) {
                                appendLog(pathErr)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": pathErr])
                                continue
                            }
                            appendLog("📂 $ ls -la \(path)")
                            flushLog()
                            let result = await executeViaUserAgent(command: "ls -la '\(path)' 2>/dev/null")
                            guard !Task.isCancelled else { break }
                            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "Directory not found or empty" : result.output
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "if_to_switch" {
                            let filePath = input["file_path"] as? String ?? ""
                            appendLog("🔄 Converting if-chains to switch: \(filePath)")
                            let output = await Self.offMain { CodingService.convertIfToSwitch(path: filePath) }
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "extract_function" {
                            let filePath = input["file_path"] as? String ?? ""
                            let funcName = input["function_name"] as? String ?? ""
                            let newFile = input["new_file"] as? String ?? ""
                            appendLog("✂️ Extracting '\(funcName)' → \(newFile)")
                            let output = await Self.offMain { CodingService.extractFunctionToFile(sourcePath: filePath, functionName: funcName, newFileName: newFile) }
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // MARK: Git tools (routed through User LaunchAgent via XPC)
                        if await handleGitTool(
                            name: name,
                            input: input,
                            toolId: toolId,
                            projectFolder: projectFolder,
                            appendLog: appendLog,
                            flushLog: flushLog,
                            commandsRun: &commandsRun,
                            toolResults: &toolResults
                        ) {
                            continue
                        }

                        // MARK: Shell execution tools

                        if name == "execute_daemon_command" || name == "execute_agent_command" {
                            let rawCommand = input["command"] as? String ?? ""
                            let command = Self.prependWorkingDirectory(
                                rawCommand, projectFolder: projectFolder)
                            // Preflight: catch typos in /Users/ and ~/ paths before running
                            if let pathErr = Self.preflightCommand(command) {
                                appendLog(pathErr)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": pathErr])
                                continue
                            }
                            let isPrivileged = (name == "execute_daemon_command") && rootEnabled
                            commandsRun.append(command)
                            appendLog("\(isPrivileged ? "🔴 #" : "🔧 $") \(Self.collapseHeredocs(command))")
                            flushLog()

                            let result: (status: Int32, output: String)
                            resetStreamCounters()
                            if isPrivileged {
                                // Root commands → LaunchDaemon via XPC
                                rootServiceActive = true
                                rootWasActive = true
                                helperService.onOutput = { [weak self] chunk in
                                    self?.appendRawOutput(chunk)
                                }
                                result = await helperService.execute(command: command)
                                helperService.onOutput = nil
                                rootServiceActive = false
                            } else if Self.needsTCCPermissions(command) {
                                // TCC commands run in Agent process to inherit TCC permissions
                                result = await Self.executeTCC(command: command)
                            } else {
                                // Non-TCC, non-root commands → User LaunchAgent via XPC
                                result = await executeViaUserAgent(command: command)
                            }
                            flushLog()

                            // Don't log results if task was cancelled
                            guard !Task.isCancelled else { break }

                            if result.status != 0 {
                                appendLog("exit code: \(result.status)")
                            }

                            // Update project folder if `cd` succeeded
                            if result.status == 0,
                               let cdTarget = Self.extractCdTarget(rawCommand, relativeTo: projectFolder) {
                                var isDir: ObjCBool = false
                                if FileManager.default.fileExists(atPath: cdTarget, isDirectory: &isDir),
                                   isDir.boolValue {
                                    projectFolder = cdTarget
                                    appendLog("📂 Project folder → \(cdTarget)")
                                }
                            }

                            let toolOutput: String
                            if result.output.isEmpty {
                                toolOutput = "(no output, exit code: \(result.status))"
                            } else {
                                toolOutput = result.output
                            }

                            // Deduplicate: skip display if we've seen this exact output before
                            let outputHash = toolOutput.hashValue
                            if recentOutputHashes.contains(outputHash) {
                                appendLog("(same output as before — not shown)")
                            }
                            recentOutputHashes.insert(outputHash)

                            // Truncate very long outputs for the API (50K keeps full bridge files)
                            let truncated = toolOutput.count > 50_000
                                ? String(toolOutput.prefix(50_000)) + "\n...(truncated)"
                                : toolOutput

                            toolResults.append([
                                "type": "tool_result",
                                "tool_use_id": toolId,
                                "content": truncated
                            ])
                        }

                        // Tool discovery
                        if name == "list_tools" {
                            let prefs = ToolPreferencesService.shared
                            let builtIn = AgentTools.tools(for: selectedProvider)
                                .filter { prefs.isEnabled(selectedProvider, $0.name) }
                                .sorted(by: { $0.name < $1.name })
                                .map { $0.name }
                            let mcpService = MCPService.shared
                            let mcpTools = mcpService.discoveredTools
                                .filter { mcpService.isToolEnabled(serverName: $0.serverName, toolName: $0.name) }
                                .sorted(by: { $0.name < $1.name })
                                .map { "mcp_\($0.serverName)_\($0.name)" }
                            let all = builtIn + (mcpTools.isEmpty ? [] : ["--- MCP Tools ---"] + mcpTools)
                            let output = all.joined(separator: "\n")
                            appendLog("🔧 Tools: \(builtIn.count) built-in, \(mcpTools.count) MCP")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }


                        // Script management tools
                        if name == "list_agents" {
                            let output = scriptService.numberedList()
                            let count = scriptService.listScripts().count
                            appendLog("🦾 Agents: \(count) found")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "read_agent" {
                            let scriptName = scriptService.resolveScriptName(input["name"] as? String ?? "")
                            let rawOutput = scriptService.readScript(name: scriptName) ?? "Error: script '\(scriptName)' not found."
                            // Add line numbers
                            let lines = rawOutput.components(separatedBy: "\n")
                            let width = String(lines.count).count
                            let numbered = lines.enumerated().map { (i, line) in
                                let num = String(i + 1).padding(toLength: width, withPad: " ", startingAt: 0)
                                return "\(num)\t\(line)"
                            }.joined(separator: "\n")
                            appendLog("📖 Read: \(scriptName)")
                            appendLog(Self.codeFence(numbered, language: "swift"))
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": numbered])
                        }

                        if name == "create_agent" {
                            let scriptName = input["name"] as? String ?? ""
                            let content = input["content"] as? String ?? ""
                            let output = scriptService.createScript(name: scriptName, content: content)
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "update_agent" {
                            let scriptName = scriptService.resolveScriptName(input["name"] as? String ?? "")
                            let content = input["content"] as? String ?? ""
                            let output = scriptService.updateScript(name: scriptName, content: content)
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "delete_agent" {
                            let scriptName = scriptService.resolveScriptName(input["name"] as? String ?? "")
                            let output = scriptService.deleteScript(name: scriptName)
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "combine_agents" {
                            let sourceA = scriptService.resolveScriptName(input["source_a"] as? String ?? "")
                            let sourceB = scriptService.resolveScriptName(input["source_b"] as? String ?? "")
                            let target = input["target"] as? String ?? ""
                            appendLog("🔗 Combining: \(sourceA) + \(sourceB) → \(target)")

                            guard let contentA = scriptService.readScript(name: sourceA) else {
                                let err = "Error: script '\(sourceA)' not found."
                                appendLog(err)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                                continue
                            }
                            guard let contentB = scriptService.readScript(name: sourceB) else {
                                let err = "Error: script '\(sourceB)' not found."
                                appendLog(err)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                                continue
                            }

                            let merged = Self.combineScriptSources(contentA: contentA, contentB: contentB, sourceA: sourceA, sourceB: sourceB)

                            // Write to target
                            let existing = scriptService.readScript(name: target)
                            let output: String
                            if existing != nil {
                                output = scriptService.updateScript(name: target, content: merged)
                            } else {
                                output = scriptService.createScript(name: target, content: merged)
                            }
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "run_agent" {
                            let scriptName = scriptService.resolveScriptName(input["name"] as? String ?? "")
                            let arguments = input["arguments"] as? String ?? ""
                            guard let compileCmd = scriptService.compileCommand(name: scriptName) else {
                                let err = "Error: script '\(scriptName)' not found."
                                appendLog(err)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                                continue
                            }

                            // Reuse existing tab for this script, or create one
                            let tab: ScriptTab
                            if let existing = scriptTabs.first(where: { $0.scriptName == scriptName }) {
                                tab = existing
                                selectedTabId = tab.id
                                tab.isRunning = true
                            } else {
                                tab = openScriptTab(scriptName: scriptName)
                            }

                            // Brief note in main log
                            appendLog("Running \(scriptName)... (see tab)")
                            flushLog()

                            // Step 1: Compile the script dylib via User LaunchAgent (no TCC required)
                            tab.appendLog("🦾 Compiling: \(scriptName)")
                            tab.flush()

                            let compileResult = await executeViaUserAgent(command: compileCmd)

                            guard !Task.isCancelled && !tab.isCancelled else {
                                tab.isRunning = false
                                tab.appendLog("Cancelled.")
                                tab.flush()
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "Script cancelled by user"])
                                break
                            }

                            if compileResult.status != 0 {
                                tab.appendLog("Compile failed (exit code: \(compileResult.status))")
                                tab.appendOutput(compileResult.output)
                                tab.flush()
                                tab.isRunning = false
                                let toolOutput = compileResult.output.isEmpty
                                    ? "(compile failed, exit code: \(compileResult.status))"
                                    : compileResult.output
                                let truncated2 = toolOutput.count > 10000
                                    ? String(toolOutput.prefix(10000)) + "\n...(truncated)"
                                    : toolOutput
                                commandsRun.append("run_agent_script: \(scriptName) (compile failed)")
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": truncated2])
                                continue
                            }

                            // Step 2: Load and run dylib in Agent!'s process
                            tab.appendLog("🦾 Running: \(scriptName) (in-process)")
                            tab.flush()

                            let cancelFlag = tab._cancelFlag
                            let runResult = await scriptService.loadAndRunScript(
                                name: scriptName,
                                arguments: arguments,
                                captureStderr: scriptCaptureStderr,
                                isCancelled: { cancelFlag.value }
                            ) { [weak tab] chunk in
                                Task { @MainActor in
                                    tab?.appendOutput(chunk)
                                }
                            }

                            tab.isRunning = false
                            tab.exitCode = runResult.status
                            tab.flush()
                            persistScriptTabs()

                            guard !Task.isCancelled && !tab.isCancelled else {
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "Script cancelled by user"])
                                break
                            }

                            // Summary back in main log
                            let statusNote = runResult.status == 0 ? "completed" : "exit code: \(runResult.status)"
                            appendLog("\(scriptName) \(statusNote)")
                            flushLog()

                            let toolOutput = runResult.output.isEmpty
                                ? "(no output, exit code: \(runResult.status))"
                                : runResult.output
                            let truncated2 = toolOutput.count > 10000
                                ? String(toolOutput.prefix(10000)) + "\n...(truncated)"
                                : toolOutput
                            commandsRun.append("run_agent_script: \(scriptName)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": truncated2])
                        }

                        // In-process shell with TCC (Automation, Accessibility, ScreenRecording)
                        if name == "run_osascript" {
                            let script = input["script"] as? String ?? input["command"] as? String ?? ""
                            let escaped = script.replacingOccurrences(of: "'", with: "'\\''")
                            let command = "osascript -e '\(escaped)'"

                            // Always run via TCC tab — osascript needs in-process TCC
                            let tab: ScriptTab
                            if let existing = scriptTabs.first(where: { $0.scriptName == "osascript" }) {
                                tab = existing
                                selectedTabId = tab.id
                                tab.isRunning = true
                            } else {
                                tab = openScriptTab(scriptName: "osascript")
                            }
                            appendLog("🍏 osascript (see tab)")
                            flushLog()
                            tab.appendLog("🍏 \(script)")
                            tab.flush()

                            let result = await Self.executeTCCStreaming(command: command) { [weak tab] chunk in
                                Task { @MainActor in tab?.appendOutput(chunk) }
                            }

                            tab.isRunning = false
                            tab.exitCode = result.status
                            tab.flush()
                            persistScriptTabs()

                            guard !Task.isCancelled else { break }

                            let statusNote = result.status == 0 ? "completed" : "exit code: \(result.status)"
                            appendLog("osascript \(statusNote)")
                            flushLog()

                            // Auto-save successful scripts for reuse
                            if result.status == 0 {
                                let autoName = Self.autoScriptName(from: script)
                                let _ = scriptService.saveAppleScript(name: autoName, source: script)
                            }

                            let toolOutput = result.output.isEmpty
                                ? "(no output, exit code: \(result.status))"
                                : result.output
                            let truncated2 = toolOutput.count > 10000
                                ? String(toolOutput.prefix(10000)) + "\n...(truncated)"
                                : toolOutput
                            commandsRun.append("run_osascript")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": truncated2])
                        }

                        // JavaScript for Automation (JXA via osascript -l JavaScript)
                        if name == "execute_javascript" {
                            let script = input["source"] as? String ?? input["script"] as? String ?? ""
                            let escaped = script.replacingOccurrences(of: "'", with: "'\\''")
                            let command = "osascript -l JavaScript -e '\(escaped)'"

                            let tab: ScriptTab
                            if let existing = scriptTabs.first(where: { $0.scriptName == "javascript" }) {
                                tab = existing
                                selectedTabId = tab.id
                                tab.isRunning = true
                            } else {
                                tab = openScriptTab(scriptName: "javascript")
                            }
                            appendLog("🟨 JXA (see tab)")
                            flushLog()
                            tab.appendLog("🟨 \(script.prefix(80))...")
                            tab.flush()

                            let result = await Self.executeTCCStreaming(command: command) { [weak tab] chunk in
                                Task { @MainActor in tab?.appendOutput(chunk) }
                            }

                            tab.isRunning = false
                            tab.exitCode = result.status
                            tab.flush()
                            persistScriptTabs()

                            guard !Task.isCancelled else { break }

                            let statusNote = result.status == 0 ? "completed" : "exit code: \(result.status)"
                            appendLog("JXA \(statusNote)")
                            flushLog()

                            // Auto-save successful JXA scripts
                            if result.status == 0 {
                                let _ = scriptService.saveJavaScript(name: Self.autoScriptName(from: script), source: script)
                            }

                            let toolOutput = result.output.isEmpty
                                ? "(no output, exit code: \(result.status))"
                                : result.output
                            let truncated2 = toolOutput.count > 10000
                                ? String(toolOutput.prefix(10000)) + "\n...(truncated)"
                                : toolOutput
                            commandsRun.append("execute_javascript")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": truncated2])
                        }

                        // SDEF lookup tool
                        if name == "lookup_sdef" {
                            let bundleID = input["bundle_id"] as? String ?? ""
                            let className = input["class_name"] as? String

                            let output: String
                            if bundleID == "list" {
                                let names = SDEFService.shared.availableSDEFs()
                                output = "Available SDEFs (\(names.count)):\n" + names.joined(separator: "\n")
                            } else if let cls = className {
                                let props = SDEFService.shared.properties(for: bundleID, className: cls)
                                let elems = SDEFService.shared.elements(for: bundleID, className: cls)
                                var lines = ["\(cls) properties:"]
                                for p in props {
                                    let ro = p.readonly == true ? " (readonly)" : ""
                                    lines.append("  .\(SDEFService.toCamelCase(p.name)): \(p.type ?? "any")\(ro)\(p.description.map { " — \($0)" } ?? "")")
                                }
                                if !elems.isEmpty { lines.append("elements: \(elems.joined(separator: ", "))") }
                                output = lines.isEmpty ? "No class '\(cls)' found for \(bundleID)" : lines.joined(separator: "\n")
                            } else {
                                output = SDEFService.shared.summary(for: bundleID)
                            }
                            appendLog("📖 SDEF: \(bundleID)\(className.map { " → \($0)" } ?? "")")
                            // Show verbose output so user can see what was found
                            let preview = output.components(separatedBy: "\n").prefix(20).joined(separator: "\n")
                            let truncated = output.components(separatedBy: "\n").count > 20 ? "\n... (\(output.components(separatedBy: "\n").count) lines total)" : ""
                            appendLog(preview + truncated)
                            flushLog()
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // NSAppleScript execution (in-process, full TCC, runs in tab)
                        if name == "run_applescript" {
                            let source = input["source"] as? String ?? ""
                            let tab: ScriptTab
                            if let existing = scriptTabs.first(where: { $0.scriptName == "applescript" }) {
                                tab = existing
                                selectedTabId = tab.id
                                tab.isRunning = true
                            } else {
                                tab = openScriptTab(scriptName: "applescript")
                            }
                            appendLog("🍎 AppleScript (see tab)")
                            flushLog()
                            tab.appendLog("🍎 AppleScript:\n\(source)")
                            tab.flush()

                            let result = await Self.offMain {
                                NSAppleScriptService.shared.execute(source: source)
                            }

                            tab.isRunning = false
                            tab.exitCode = result.success ? 0 : 1
                            if !result.output.isEmpty {
                                tab.appendOutput(result.output)
                            }
                            tab.flush()
                            persistScriptTabs()

                            let statusNote = result.success ? "completed" : "error"
                            appendLog("AppleScript \(statusNote)")
                            flushLog()

                            // Auto-save successful scripts for reuse
                            if result.success {
                                let autoName = Self.autoScriptName(from: source)
                                let _ = scriptService.saveAppleScript(name: autoName, source: source)
                            }

                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": result.output])
                        }

                        // Saved AppleScript tools
                        if name == "list_apple_scripts" {
                            let scripts = scriptService.listAppleScripts()
                            let output = scripts.isEmpty
                                ? "No saved AppleScripts in ~/Documents/AgentScript/applescript/"
                                : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
                            appendLog("🍎 Saved AppleScripts: \(scripts.count) found")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }
                        if name == "save_apple_script" {
                            let scriptName = input["name"] as? String ?? ""
                            let source = input["source"] as? String ?? ""
                            let output = scriptService.saveAppleScript(name: scriptName, source: source)
                            appendLog("🍎 \(output)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }
                        if name == "delete_apple_script" {
                            let scriptName = input["name"] as? String ?? ""
                            let output = scriptService.deleteAppleScript(name: scriptName)
                            appendLog("🍎 \(output)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }
                        if name == "run_apple_script" {
                            let scriptName = input["name"] as? String ?? ""
                            guard let source = scriptService.readAppleScript(name: scriptName) else {
                                let err = "Error: AppleScript '\(scriptName)' not found. Use list_apple_scripts first."
                                appendLog("🍎 \(err)")
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                                continue
                            }
                            let tab: ScriptTab
                            if let existing = scriptTabs.first(where: { $0.scriptName == "applescript" }) {
                                tab = existing
                                selectedTabId = tab.id
                                tab.isRunning = true
                            } else {
                                tab = openScriptTab(scriptName: "applescript")
                            }
                            appendLog("🍎 Running saved: \(scriptName) (see tab)")
                            flushLog()
                            tab.appendLog("🍎 \(scriptName)")
                            tab.flush()

                            let result = await Self.offMain {
                                NSAppleScriptService.shared.execute(source: source)
                            }

                            tab.isRunning = false
                            tab.exitCode = result.success ? 0 : 1
                            if !result.output.isEmpty {
                                tab.appendOutput(result.output)
                            }
                            tab.flush()
                            persistScriptTabs()

                            let statusNote = result.success ? "completed" : "error"
                            appendLog("\(scriptName) \(statusNote)")
                            flushLog()
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": result.output])
                        }

                        // Saved JavaScript/JXA tools
                        if name == "list_javascript" {
                            let scripts = scriptService.listJavaScripts()
                            let output = scripts.isEmpty
                                ? "No saved JXA scripts in ~/Documents/AgentScript/javascript/"
                                : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
                            appendLog("🟨 Saved JXA: \(scripts.count) found")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }
                        if name == "save_javascript" {
                            let scriptName = input["name"] as? String ?? ""
                            let source = input["source"] as? String ?? ""
                            let output = scriptService.saveJavaScript(name: scriptName, source: source)
                            appendLog("🟨 \(output)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }
                        if name == "delete_javascript" {
                            let scriptName = input["name"] as? String ?? ""
                            let output = scriptService.deleteJavaScript(name: scriptName)
                            appendLog("🟨 \(output)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }
                        if name == "run_javascript" {
                            let scriptName = input["name"] as? String ?? ""
                            guard let source = scriptService.readJavaScript(name: scriptName) else {
                                let err = "Error: JXA script '\(scriptName)' not found. Use list_javascript first."
                                appendLog("🟨 \(err)")
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                                continue
                            }
                            let escaped = source.replacingOccurrences(of: "'", with: "'\\''")
                            let command = "osascript -l JavaScript -e '\(escaped)'"

                            let tab: ScriptTab
                            if let existing = scriptTabs.first(where: { $0.scriptName == "javascript" }) {
                                tab = existing
                                selectedTabId = tab.id
                                tab.isRunning = true
                            } else {
                                tab = openScriptTab(scriptName: "javascript")
                            }
                            appendLog("🟨 Running saved: \(scriptName) (see tab)")
                            flushLog()
                            tab.appendLog("🟨 \(scriptName)")
                            tab.flush()

                            let result = await Self.executeTCCStreaming(command: command) { [weak tab] chunk in
                                Task { @MainActor in tab?.appendOutput(chunk) }
                            }

                            tab.isRunning = false
                            tab.exitCode = result.status
                            tab.flush()
                            persistScriptTabs()

                            let statusNote = result.status == 0 ? "completed" : "exit code: \(result.status)"
                            appendLog("\(scriptName) \(statusNote)")
                            flushLog()
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": result.output.isEmpty ? "(no output)" : result.output])
                        }

                        // Dynamic Apple Event query tool — flat keys
                        if name == "apple_event_query" {
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
                                appendLog("Error: action is required")
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "Error: action is required"])
                                continue
                            }
                            let action = input["action"] as? String ?? operations.first?["action"] as? String ?? "?"
                            let key = input["key"] as? String ?? operations.first?["key"] as? String ?? ""
                            appendLog("🍎 AE: \(bundleID) → \(action) \(key)")
                            flushLog()
                            let opsData = try? JSONSerialization.data(withJSONObject: operations)
                            let output = await Self.offMain {
                                guard let data = opsData,
                                      let ops = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                                    return "Error: failed to process operations"
                                }
                                return AppleEventService.shared.execute(bundleID: bundleID, operations: ops)
                            }
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Xcode ScriptingBridge tools (in-process, offMain)
                        if name == "xcode_grant_permission" {
                            appendLog("Granting Xcode Automation permission...")
                            flushLog()
                            let output = await Self.offMain { XcodeService.shared.grantPermission() }
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "xcode_build" {
                            let projectPath = input["project_path"] as? String ?? ""
                            appendLog("🔨 Building: \(projectPath)")
                            flushLog()
                            let output = await Self.offMain { XcodeService.shared.buildProject(projectPath: projectPath) }
                            appendLog(output)
                            commandsRun.append("xcode_build: \(projectPath)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "xcode_run" {
                            let projectPath = input["project_path"] as? String ?? ""
                            appendLog("🔨 Running: \(projectPath)")
                            flushLog()
                            let output = await Self.offMain { XcodeService.shared.runProject(projectPath: projectPath) }
                            appendLog(output)
                            commandsRun.append("xcode_run: \(projectPath)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "xcode_list_projects" {
                            appendLog("Listing open Xcode projects...")
                            let output = await Self.offMain { XcodeService.shared.listProjects() }
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "xcode_select_project" {
                            let number = input["number"] as? Int ?? 0
                            appendLog("Selecting project #\(number)")
                            let output = await Self.offMain { XcodeService.shared.selectProject(number: number) }
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "xcode_add_file" {
                            let fp = input["file_path"] as? String ?? ""
                            appendLog("📎 Adding to project: \(fp)")
                            let output = await Self.offMain { XcodeService.shared.addFileToProject(filePath: fp) }
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "xcode_remove_file" {
                            let fp = input["file_path"] as? String ?? ""
                            appendLog("🗑️ Removing from project: \(fp)")
                            let output = await Self.offMain { XcodeService.shared.removeFileFromProject(filePath: fp) }
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Plan mode
                        if name == "plan_mode" {
                            let action: String = input["action"] as? String ?? "read"
                            let output: String = Self.handlePlanMode(action: action, input: input, projectFolder: projectFolder, tabName: "main")
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Accessibility API tools (in-process, offMain)
                        if name == "ax_check_permission" {
                            let hasPermission = AccessibilityService.hasAccessibilityPermission()
                            let output = hasPermission ? "Accessibility permission: granted" : "Accessibility permission: NOT granted. Use ax_request_permission to prompt the user."
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "ax_request_permission" {
                            appendLog("♿️ Requesting Accessibility permission...")
                            let granted = AccessibilityService.requestAccessibilityPermission()
                            let output = granted ? "Accessibility permission granted!" : "Accessibility permission denied. Please enable it in System Settings > Privacy & Security > Accessibility."
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "ax_list_windows" {
                            let limit = input["limit"] as? Int ?? 50
                            appendLog("Listing windows (limit: \(limit))...")
                            flushLog()
                            let output = await Self.offMain { AccessibilityService.shared.listWindows(limit: limit) }
                            appendLog(Self.preview(output, lines: 20))
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "ax_inspect_element" {
                            guard let xVal = input["x"] as? Double,
                                  let yVal = input["y"] as? Double else {
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "Error: x and y coordinates are required"])
                                continue
                            }
                            let x = CGFloat(xVal)
                            let y = CGFloat(yVal)
                            let depth = input["depth"] as? Int ?? 3
                            appendLog("♿️ Inspecting element at (\(x), \(y))...")
                            flushLog()
                            let output = await Self.offMain { AccessibilityService.shared.inspectElementAt(x: x, y: y, depth: depth) }
                            appendLog(Self.preview(output, lines: 30))
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "ax_get_properties" {
                            let role = input["role"] as? String
                            let title = input["title"] as? String
                            let value = input["value"] as? String
                            let appBundleId = input["appBundleId"] as? String
                            let x = (input["x"] as? Double).map { CGFloat($0) }
                            let y = (input["y"] as? Double).map { CGFloat($0) }
                            appendLog("Getting element properties...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.getElementProperties(
                                    role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y
                                )
                            }
                            appendLog(Self.preview(output, lines: 30))
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "ax_perform_action" {
                            let action = input["action"] as? String ?? ""
                            let role = input["role"] as? String
                            let title = input["title"] as? String
                            let value = input["value"] as? String
                            let appBundleId = input["appBundleId"] as? String
                            let x = (input["x"] as? Double).map { CGFloat($0) }
                            let y = (input["y"] as? Double).map { CGFloat($0) }
                            appendLog("Performing action: \(action)...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.performAction(
                                    role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y,
                                    action: action
                                )
                            }
                            appendLog(output)
                            commandsRun.append("ax_perform_action: \(action)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Accessibility input simulation tools (Phase 2)
                        if name == "ax_type_text" {
                            let text = input["text"] as? String ?? ""
                            let x = (input["x"] as? Double).map { CGFloat($0) }
                            let y = (input["y"] as? Double).map { CGFloat($0) }
                            appendLog("Typing: \(text.count) characters...")
                            flushLog()
                            let output = await Self.offMain {
                                // Ensure text is non-nil and handle empty string gracefully
                                AccessibilityService.shared.typeText(text, at: x, y: y)
                            }
                            appendLog(output)
                            commandsRun.append("ax_type_text")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "ax_click" {
                            guard let xVal = input["x"] as? Double,
                                  let yVal = input["y"] as? Double else {
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "Error: x and y coordinates are required"])
                                continue
                            }
                            let x = CGFloat(xVal)
                            let y = CGFloat(yVal)
                            let button = input["button"] as? String ?? "left"
                            let clicks = input["clicks"] as? Int ?? 1
                            appendLog("♿️ Clicking at (\(x), \(y))...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.clickAt(x: x, y: y, button: button, clicks: clicks)
                            }
                            appendLog(output)
                            commandsRun.append("ax_click")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "ax_scroll" {
                            guard let xVal = input["x"] as? Double,
                                  let yVal = input["y"] as? Double else {
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "Error: x and y coordinates are required"])
                                continue
                            }
                            let x = CGFloat(xVal)
                            let y = CGFloat(yVal)
                            let deltaX = input["deltaX"] as? Int ?? 0
                            let deltaY = input["deltaY"] as? Int ?? 0
                            appendLog("♿️ Scrolling at (\(x), \(y))...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.scrollAt(x: x, y: y, deltaX: deltaX, deltaY: deltaY)
                            }
                            appendLog(output)
                            commandsRun.append("ax_scroll")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "ax_press_key" {
                            guard let keyCodeVal = input["keyCode"] as? Int else {
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "Error: keyCode is required"])
                                continue
                            }
                            let keyCode = UInt16(keyCodeVal)
                            let modifiers = input["modifiers"] as? [String] ?? []
                            appendLog("♿️ Pressing key code: \(keyCodeVal)...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.pressKey(virtualKey: keyCode, modifiers: modifiers)
                            }
                            appendLog(output)
                            commandsRun.append("ax_press_key")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Accessibility screenshot tool (Phase 4)
                        if name == "ax_screenshot" {
                            let x = (input["x"] as? Double).map { CGFloat($0) }
                            let y = (input["y"] as? Double).map { CGFloat($0) }
                            let width = (input["width"] as? Double).map { CGFloat($0) }
                            let height = (input["height"] as? Double).map { CGFloat($0) }
                            let windowId = input["windowId"] as? Int
                            
                            appendLog("Capturing screenshot...")
                            flushLog()
                            
                            let output: String
                            if let wid = windowId, wid > 0 {
                                output = await Self.offMain {
                                    AccessibilityService.shared.captureScreenshot(windowID: wid)
                                }
                            } else if let x = x, let y = y, let w = width, let h = height {
                                output = await Self.offMain {
                                    AccessibilityService.shared.captureScreenshot(x: x, y: y, width: w, height: h)
                                }
                            } else {
                                // Fullscreen capture
                                output = await Self.offMain {
                                    AccessibilityService.shared.captureAllWindows()
                                }
                            }
                            
                            // Check if output contains a path - if so, it's an image that can be displayed inline
                            if output.contains("\"path\"") {
                                appendLog("♿️ Screenshot captured successfully")
                            } else {
                                appendLog(output)
                            }
                            commandsRun.append("ax_screenshot")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Accessibility audit log tool (Phase 5)
                        if name == "ax_get_audit_log" {
                            let limit = input["limit"] as? Int ?? 50
                            appendLog("Getting accessibility audit log...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.getAuditLog(limit: limit)
                            }
                            appendLog(Self.preview(output, lines: 30))
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Accessibility set properties (Phase 6)
                        if name == "ax_set_properties" {
                            guard let propertiesInput = input["properties"] as? [String: Any], !propertiesInput.isEmpty else {
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "Error: properties dictionary is required"])
                                continue
                            }
                            let role = input["role"] as? String
                            let title = input["title"] as? String
                            let value = input["value"] as? String
                            let appBundleId = input["appBundleId"] as? String
                            let x = (input["x"] as? Double).map { CGFloat($0) }
                            let y = (input["y"] as? Double).map { CGFloat($0) }
                            appendLog("Setting element properties...")
                            flushLog()
                            // Serialize and deserialize to avoid Sendable issues
                            let propertiesData = try? JSONSerialization.data(withJSONObject: propertiesInput)
                            let output = await Self.offMain {
                                guard let data = propertiesData,
                                      let properties = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                                    return "{\"success\": false, \"error\": \"Failed to serialize properties\"}"
                                }
                                return AccessibilityService.shared.setProperties(
                                    role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y,
                                    properties: properties
                                )
                            }
                            appendLog(output)
                            commandsRun.append("ax_set_properties")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Accessibility find element (Phase 6)
                        if name == "ax_find_element" {
                            let role = input["role"] as? String
                            let title = input["title"] as? String
                            let value = input["value"] as? String
                            let appBundleId = input["appBundleId"] as? String
                            let timeout = input["timeout"] as? Double ?? 5.0
                            appendLog("Finding element...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.findElement(
                                    role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout
                                )
                            }
                            appendLog(Self.preview(output, lines: 30))
                            commandsRun.append("ax_find_element")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Accessibility get focused element (Phase 6)
                        if name == "ax_get_focused_element" {
                            let appBundleId = input["appBundleId"] as? String
                            appendLog("Getting focused element...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.getFocusedElement(appBundleId: appBundleId)
                            }
                            appendLog(Self.preview(output, lines: 30))
                            commandsRun.append("ax_get_focused_element")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Accessibility get children (Phase 6)
                        if name == "ax_get_children" {
                            let role = input["role"] as? String
                            let title = input["title"] as? String
                            let value = input["value"] as? String
                            let appBundleId = input["appBundleId"] as? String
                            let x = (input["x"] as? Double).map { CGFloat($0) }
                            let y = (input["y"] as? Double).map { CGFloat($0) }
                            let depth = input["depth"] as? Int ?? 3
                            appendLog("Getting element children...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.getChildren(
                                    role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y, depth: depth
                                )
                            }
                            appendLog(Self.preview(output, lines: 30))
                            commandsRun.append("ax_get_children")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Accessibility drag (Phase 6)
                        if name == "ax_drag" {
                            guard let fromXVal = input["fromX"] as? Double,
                                  let fromYVal = input["fromY"] as? Double,
                                  let toXVal = input["toX"] as? Double,
                                  let toYVal = input["toY"] as? Double else {
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": "Error: fromX, fromY, toX, toY coordinates are required"])
                                continue
                            }
                            let fromX = CGFloat(fromXVal)
                            let fromY = CGFloat(fromYVal)
                            let toX = CGFloat(toXVal)
                            let toY = CGFloat(toYVal)
                            let button = input["button"] as? String ?? "left"
                            appendLog("Dragging from (\(fromX), \(fromY)) to (\(toX), \(toY))...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.drag(fromX: fromX, fromY: fromY, toX: toX, toY: toY, button: button)
                            }
                            appendLog(output)
                            commandsRun.append("ax_drag")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Accessibility wait for element (Phase 6)
                        if name == "ax_wait_for_element" {
                            let role = input["role"] as? String
                            let title = input["title"] as? String
                            let value = input["value"] as? String
                            let appBundleId = input["appBundleId"] as? String
                            let timeout = input["timeout"] as? Double ?? 10.0
                            let pollInterval = input["pollInterval"] as? Double ?? 0.5
                            appendLog("Waiting for element (timeout: \(timeout)s)...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.waitForElement(
                                    role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout, pollInterval: pollInterval
                                )
                            }
                            appendLog(Self.preview(output, lines: 30))
                            commandsRun.append("ax_wait_for_element")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Smart element click (Phase 1 Improvement)
                        if name == "ax_click_element" {
                            let role = input["role"] as? String
                            let title = input["title"] as? String
                            let value = input["value"] as? String
                            let appBundleId = input["appBundleId"] as? String
                            let timeout = input["timeout"] as? Double ?? 5.0
                            let verify = input["verify"] as? Bool ?? false
                            appendLog("Clicking element (role: \(role ?? "any"), title: \(title ?? "any"))...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.clickElement(
                                    role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout, verify: verify
                                )
                            }
                            appendLog(Self.preview(output, lines: 30))
                            commandsRun.append("ax_click_element")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Adaptive wait (Phase 1 Improvement)
                        if name == "ax_wait_adaptive" {
                            let role = input["role"] as? String
                            let title = input["title"] as? String
                            let value = input["value"] as? String
                            let appBundleId = input["appBundleId"] as? String
                            let timeout = input["timeout"] as? Double ?? 10.0
                            let initialDelay = input["initialDelay"] as? Double ?? 0.1
                            let maxDelay = input["maxDelay"] as? Double ?? 1.0
                            appendLog("Waiting for element (adaptive, timeout: \(timeout)s)...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.waitForElementAdaptive(
                                    role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout,
                                    initialDelay: initialDelay, maxDelay: maxDelay
                                )
                            }
                            appendLog(Self.preview(output, lines: 30))
                            commandsRun.append("ax_wait_adaptive")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Type into element (Phase 1 Improvement)
                        if name == "ax_type_into_element" {
                            let role = input["role"] as? String
                            let title = input["title"] as? String
                            let text = input["text"] as? String ?? ""
                            let appBundleId = input["appBundleId"] as? String
                            let verify = input["verify"] as? Bool ?? true
                            appendLog("Typing \(text.count) chars into element...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.typeTextIntoElement(
                                    role: role, title: title, text: text, appBundleId: appBundleId, verify: verify
                                )
                            }
                            appendLog(Self.preview(output, lines: 30))
                            commandsRun.append("ax_type_into_element")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Highlight element (Phase 2, v1.0.16)
                        if name == "ax_highlight_element" {
                            let role = input["role"] as? String
                            let title = input["title"] as? String
                            let value = input["value"] as? String
                            let appBundleId = input["appBundleId"] as? String
                            let x = (input["x"] as? Double).map { CGFloat($0) }
                            let y = (input["y"] as? Double).map { CGFloat($0) }
                            let duration = input["duration"] as? Double ?? 2.0
                            let color = input["color"] as? String ?? "green"
                            appendLog("Highlighting element (duration: \(duration)s, color: \(color))...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.highlightElement(
                                    role: role, title: title, value: value, appBundleId: appBundleId,
                                    x: x, y: y, duration: duration, color: color
                                )
                            }
                            appendLog(Self.preview(output, lines: 30))
                            commandsRun.append("ax_highlight_element")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Get window frame (Phase 2, v1.0.16)
                        if name == "ax_get_window_frame" {
                            let windowId = input["windowId"] as? Int ?? 0
                            appendLog("Getting frame for window \(windowId)...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.getWindowFrame(windowId: windowId)
                            }
                            appendLog(output)
                            commandsRun.append("ax_get_window_frame")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Accessibility show menu (Phase 6)
                        if name == "ax_show_menu" {
                            let role = input["role"] as? String
                            let title = input["title"] as? String
                            let value = input["value"] as? String
                            let appBundleId = input["appBundleId"] as? String
                            let x = (input["x"] as? Double).map { CGFloat($0) }
                            let y = (input["y"] as? Double).map { CGFloat($0) }
                            appendLog("Showing context menu...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.showMenu(
                                    role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y
                                )
                            }
                            appendLog(output)
                            commandsRun.append("ax_show_menu")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Client-side web search via Ollama API (primary) or Tavily (backup)
                        if name == "web_search" {
                            let query = input["query"] as? String ?? ""
                            appendLog("Web search: \(query)")
                            flushLog()
                            let output = await Self.performWebSearchForTask(query: query, apiKey: tavilyAPIKey, provider: selectedProvider)
                            appendLog(Self.preview(output, lines: 5))
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Web browser tool — handle same as tab tasks
                        if toolResults.isEmpty && (name.hasPrefix("web_") || name == "web") {
                            let webResult = await handleMainWebTool(name: name, input: input)
                            appendLog(String(webResult.prefix(500)))
                            flushLog()
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": webResult])
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
                    // Truncate large tool results to save tokens
                    let truncatedResults = Self.truncateToolResults(toolResults)
                    messages.append(["role": "user", "content": truncatedResults])
                } else if !hasToolUse {
                    // LLM responded with text and no tool calls — task is complete
                    // The LLM should have called task_complete but didn't; treat text-only response as done
                    let responseText = response.content.compactMap { $0["text"] as? String }.joined()
                    if !responseText.isEmpty {
                        appendLog(responseText)
                        flushLog()
                    }
                    break
                }

            } catch {
                if !Task.isCancelled {
                    let errMsg = error.localizedDescription
                    
                    // Detect timeout errors
                    let isNetworkTimeout = errMsg.lowercased().contains("timeout") || errMsg.lowercased().contains("timed out")
                    
                    taskLog.error("[main] LLM error at iteration \(iterations): \(errMsg) (isTimeout: \(isNetworkTimeout))")
                    
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
                    
                    // Log rate limit errors but don't retry — let the user decide
                    if errMsg.contains("429") || errMsg.lowercased().contains("rate limit") || errMsg.lowercased().contains("concurrent request") {
                        appendLog("Rate limited: \(errMsg)")
                        flushLog()
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
                            taskLog.info("[main] \(errorSource) timeout, retry \(timeoutRetryCount)/\(maxTimeoutRetries), waiting \(retryDelay)s")
                            
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
                        }
                    } else {
                        // Non-timeout error
                        appendLog("\(errorSource) Error: \(errMsg)")
                    }
                    
                    // Apple Intelligence error explanation
                    if mediator.isEnabled && mediator.showAnnotationsToUser {
                        taskLog.info("[main] Apple AI mediator: explaining error...")
                        if let errorAnnotation = await mediator.explainError(toolName: "LLM request", error: errMsg) {
                            appendLog(errorAnnotation.formatted)
                            flushLog()
                            if agentReplyHandle != nil {
                                sendProgressUpdate(errorAnnotation.formatted)
                            }
                        }
                    }
                }
                continue
            }
        }

        // Apple Intelligence: suggest next steps after completion (skip for pure conversation)
        if mediator.isEnabled && mediator.showAnnotationsToUser && !completionSummary.isEmpty && !commandsRun.isEmpty {
            taskLog.info("[main] Apple AI mediator: suggesting next steps...")
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
        
        taskLog.info("[main] executeTask finished after \(iterations) iteration(s), cancelled=\(Task.isCancelled)")
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
