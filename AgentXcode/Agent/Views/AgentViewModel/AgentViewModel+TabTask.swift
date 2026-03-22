
@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log

private let tabTaskLog = Logger(subsystem: "Agent.app.toddbruss", category: "TabTask")

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
            tab.streamTruncated = false
            persistScriptTabs()
            return
        }

        if tab.isLLMRunning {
            stopTabTask(tab: tab)
        }

        tab.addToHistory(task)
        tab.taskInput = ""

        tab.runningLLMTask = Task {
            await executeTabTask(tab: tab, prompt: task)
        }
    }

    /// Stop the LLM task running on a script tab.
    func stopTabTask(tab: ScriptTab) {
        tab.runningLLMTask?.cancel()
        tab.runningLLMTask = nil
        tab.isLLMRunning = false
        tab.isLLMThinking = false
        tab.appendLog("Cancelled by user.")
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

        let claude: ClaudeService? = provider == .claude
            ? ClaudeService(apiKey: apiKey, model: modelId, historyContext: tabHistoryContext, projectFolder: projectFolder) : nil
        let openAICompatible: OpenAICompatibleService?
        switch provider {
        case .openAI:
            openAICompatible = OpenAICompatibleService(apiKey: openAIAPIKey, model: modelId, baseURL: "https://api.openai.com/v1/chat/completions", historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .openAI)
        case .deepSeek:
            openAICompatible = OpenAICompatibleService(apiKey: deepSeekAPIKey, model: modelId, baseURL: "https://api.deepseek.com/chat/completions", historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .deepSeek)
        case .huggingFace:
            openAICompatible = OpenAICompatibleService(apiKey: huggingFaceAPIKey, model: modelId, baseURL: "https://router.huggingface.co/v1/chat/completions", historyContext: tabHistoryContext, projectFolder: projectFolder, provider: .huggingFace)
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

        var iterations = 0
        let maxIter = maxIterations
        var consecutiveNoTool = 0

        // Apple Intelligence mediator for contextual annotations (same as main task)
        let mediator = AppleIntelligenceMediator.shared
        var appleAIAnnotations: [AppleIntelligenceMediator.Annotation] = []

        // Optional: Add Apple Intelligence context to user message
        if mediator.isEnabled && mediator.injectContextToLLM {
            tabTaskLog.info("[\(tab.displayTitle)] Apple AI mediator: contextualizing user message...")
            if let contextAnnotation = await mediator.contextualizeUserMessage(prompt) {
                appleAIAnnotations.append(contextAnnotation)
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
                let response: (content: [[String: Any]], stopReason: String)
                var textWasStreamed = false
                let streamStart = CFAbsoluteTimeGetCurrent()

                if let claude {
                    response = try await claude.sendStreaming(messages: messages) { [weak tab] delta in
                        Task { @MainActor in
                            tab?.isLLMThinking = false
                            tab?.appendStreamDelta(delta)
                        }
                    }
                    textWasStreamed = true
                    tab.flushStreamBuffer()
                } else if let openAICompatible {
                    response = try await openAICompatible.sendStreaming(messages: messages) { [weak tab] delta in
                        Task { @MainActor in
                            tab?.isLLMThinking = false
                            tab?.appendStreamDelta(delta)
                        }
                    }
                    textWasStreamed = true
                    tab.flushStreamBuffer()
                } else if let ollama {
                    response = try await ollama.sendStreaming(messages: messages) { [weak tab] delta in
                        Task { @MainActor in
                            tab?.isLLMThinking = false
                            tab?.appendStreamDelta(delta)
                        }
                    }
                    textWasStreamed = true
                    tab.flushStreamBuffer()
                } else if let foundationModelService {
                    response = try await foundationModelService.sendStreaming(messages: messages) { [weak tab] delta in
                        Task { @MainActor in
                            tab?.isLLMThinking = false
                            tab?.appendStreamDelta(delta)
                        }
                    }
                    textWasStreamed = true
                    tab.flushStreamBuffer()
                } else {
                    throw AgentError.noAPIKey
                }
                let streamElapsed = CFAbsoluteTimeGetCurrent() - streamStart
                tabTaskLog.info("[\(tab.displayTitle)] stream completed in \(String(format: "%.2f", streamElapsed))s, stopReason=\(response.stopReason)")
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
                              let name = block["name"] as? String,
                              let input = block["input"] as? [String: Any] else { continue }

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
                    messages.append(["role": "user", "content": toolResults])
                    tab.llmMessages = messages
                    consecutiveNoTool = 0
                } else if !hasToolUse {
                    consecutiveNoTool += 1
                    // Give models up to 3 nudges to use tools before giving up
                    if consecutiveNoTool >= 3 {
                        tab.appendLog("(model not using tools — stopping)")
                        break
                    }
                    messages.append(["role": "user", "content": "Continue. Use tools to perform actions. Call task_complete when finished."])
                    tab.llmMessages = messages
                }

            } catch {
                if !Task.isCancelled {
                    tabTaskLog.error("[\(tab.displayTitle)] LLM error at iteration \(iterations): \(error.localizedDescription)")
                    tab.appendLog("Error: \(error.localizedDescription)")
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

    private struct TabToolResult {
        let toolResult: [String: Any]?
        let isComplete: Bool
    }

    private func handleTabToolCall(
        tab: ScriptTab, name: String, input: [String: Any], toolId: String
    ) async -> TabToolResult {

        // task_complete
        if name == "task_complete" {
            let summary = input["summary"] as? String ?? "Done"
            tab.appendLog("✅ Completed: \(summary)")
            tab.flush()
            
            // Apple Intelligence mediator summary (same as main task)
            let mediator = AppleIntelligenceMediator.shared
            if mediator.isEnabled && mediator.showAnnotationsToUser {
                tabTaskLog.info("[\(tab.displayTitle)] Apple AI mediator: summarizing completion...")
                if let summaryAnnotation = await mediator.summarizeCompletion(summary: summary, commandsRun: []) {
                    if mediator.trainingEnabled {
                        TrainingDataStore.shared.captureAppleAIDecision(summaryAnnotation.content)
                    }
                    tab.appendLog(summaryAnnotation.formatted)
                    tab.flush()
                }
            }
            
            // If this is the Messages tab, reply to the iMessage sender
            if tab.isMessagesTab, let handle = tab.replyHandle {
                tab.replyHandle = nil
                sendMessagesTabReply(summary, handle: handle)
            }
            return TabToolResult(toolResult: nil, isComplete: true)
        }

        // read_file
        if name == "read_file" {
            let filePath = input["file_path"] as? String ?? ""
            let offset = input["offset"] as? Int
            let limit = input["limit"] as? Int
            tab.appendLog("📖 Read: \(filePath)")
            let output = await Self.offMain { CodingService.readFile(path: filePath, offset: offset, limit: limit) }
            let lang = Self.langFromPath(filePath)
            tab.appendLog(Self.codeFence(Self.preview(output, lines: readFilePreviewLines), language: lang))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // write_file
        if name == "write_file" {
            let filePath = input["file_path"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            tab.appendLog("📝 Write: \(filePath)")
            let output = await Self.offMain { CodingService.writeFile(path: filePath, content: content) }
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // edit_file
        if name == "edit_file" {
            let filePath = input["file_path"] as? String ?? ""
            let oldString = input["old_string"] as? String ?? ""
            let newString = input["new_string"] as? String ?? ""
            let replaceAll = input["replace_all"] as? Bool ?? false
            tab.appendLog("📝 Edit: \(filePath)")
            let output = await Self.offMain { CodingService.editFile(path: filePath, oldString: oldString, newString: newString, replaceAll: replaceAll) }
            let diff = MultiLineDiff.createDiff(source: oldString, destination: newString, includeMetadata: true)
            var d1f = MultiLineDiff.displayDiff(diff: diff, source: oldString, format: .ai)
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
            tab.appendOutput(diffLog + "\n")
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // create_diff
        if name == "create_diff" {
            let source = input["source"] as? String ?? ""
            let destination = input["destination"] as? String ?? ""
            let diff = MultiLineDiff.createDiff(source: source, destination: destination, includeMetadata: true)
            let d1f = MultiLineDiff.displayDiff(diff: diff, source: source, format: .ai)
            let summary = MultiLineDiff.generateDiffSummary(source: source, destination: destination)
            var result = d1f + "\n\n" + summary
            if let meta = diff.metadata, let startLine = meta.sourceStartLine {
                result += "\n📍 Changes start at line \(startLine + 1)"
            }
            tab.appendOutput(result + "\n")
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": result],
                isComplete: false
            )
        }

        // apply_diff
        if name == "apply_diff" {
            let filePath = input["file_path"] as? String ?? ""
            let asciiDiff = input["diff"] as? String ?? ""
            tab.appendLog("📝 Apply D1F diff: \(filePath)")
            let expandedPath = (filePath as NSString).expandingTildeInPath
            guard let data = FileManager.default.contents(atPath: expandedPath),
                  let source = String(data: data, encoding: .utf8) else {
                let err = "Error: cannot read \(filePath)"
                tab.appendLog(err)
                tab.flush()
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": err],
                    isComplete: false
                )
            }
            do {
                let patched = try MultiLineDiff.applyASCIIDiff(to: source, asciiDiff: asciiDiff)
                try patched.write(to: URL(fileURLWithPath: expandedPath), atomically: true, encoding: .utf8)
                let verifyDiff = MultiLineDiff.createAndDisplayDiff(source: source, destination: patched, format: .ai)
                tab.appendOutput(verifyDiff + "\n")
                let output = "Applied diff to \(filePath)"
                tab.appendLog(output)
                tab.flush()
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                    isComplete: false
                )
            } catch {
                let err = "Error applying diff: \(error.localizedDescription)"
                tab.appendLog(err)
                tab.flush()
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": err],
                    isComplete: false
                )
            }
        }

        // list_files
        if name == "list_files" {
            let pattern = input["pattern"] as? String ?? "*"
            let path = input["path"] as? String
            tab.appendLog("🔍 $ find \(path ?? "~") -name '\(pattern)'")
            tab.flush()
            let cmd = CodingService.buildListFilesCommand(pattern: pattern, path: path)
            let result = await executeForTab(command: cmd)
            guard !Task.isCancelled else { return TabToolResult(toolResult: nil, isComplete: false) }
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "No files matching '\(pattern)'" : result.output
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // search_files
        if name == "search_files" {
            let pattern = input["pattern"] as? String ?? ""
            let path = input["path"] as? String
            let include = input["include"] as? String
            tab.appendLog("🔍 $ grep -rn '\(pattern)' \(path ?? "~")")
            tab.flush()
            let cmd = CodingService.buildSearchFilesCommand(pattern: pattern, path: path, include: include)
            let result = await executeForTab(command: cmd)
            guard !Task.isCancelled else { return TabToolResult(toolResult: nil, isComplete: false) }
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "No matches for '\(pattern)'" : result.output
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // git_status
        if name == "git_status" {
            let path = input["path"] as? String
            tab.appendLog("🔀 $ git status")
            tab.flush()
            let cmd = CodingService.buildGitStatusCommand(path: path)
            let result = await executeForTab(command: cmd)
            guard !Task.isCancelled else { return TabToolResult(toolResult: nil, isComplete: false) }
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "(no output, exit code: \(result.status))" : result.output
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // git_diff
        if name == "git_diff" {
            let path = input["path"] as? String
            let staged = input["staged"] as? Bool ?? false
            let target = input["target"] as? String
            tab.appendLog("🔀 $ git diff\(staged ? " --cached" : "")")
            tab.flush()
            let cmd = CodingService.buildGitDiffCommand(path: path, staged: staged, target: target)
            let result = await executeForTab(command: cmd)
            guard !Task.isCancelled else { return TabToolResult(toolResult: nil, isComplete: false) }
            let output: String
            if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                output = staged ? "No staged changes" : "No changes"
            } else if result.output.count > 50_000 {
                output = String(result.output.prefix(50_000)) + "\n...(diff truncated)"
            } else {
                output = result.output
            }
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // git_log
        if name == "git_log" {
            let path = input["path"] as? String
            let count = input["count"] as? Int
            tab.appendLog("🔀 $ git log")
            tab.flush()
            let cmd = CodingService.buildGitLogCommand(path: path, count: count)
            let result = await executeForTab(command: cmd)
            guard !Task.isCancelled else { return TabToolResult(toolResult: nil, isComplete: false) }
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Error: empty log" : result.output
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // git_commit
        if name == "git_commit" {
            let path = input["path"] as? String
            let message = input["message"] as? String ?? ""
            let files = input["files"] as? [String]
            tab.appendLog("🔀 Git commit: \(message)")
            tab.flush()
            let cmd = CodingService.buildGitCommitCommand(path: path, message: message, files: files)
            let result = await executeForTab(command: cmd)
            guard !Task.isCancelled else { return TabToolResult(toolResult: nil, isComplete: false) }
            let output = result.output.isEmpty
                ? "(no output, exit code: \(result.status))" : result.output
            if !result.output.isEmpty { tab.appendLog(result.output) }
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // run_osascript — AppleScript via osascript in-process with full TCC
        if name == "run_osascript" {
            let script = input["script"] as? String ?? input["command"] as? String ?? ""
            let escaped = script.replacingOccurrences(of: "'", with: "'\\''")
            let command = "osascript -e '\(escaped)'"
            tab.appendLog("🍎 \(script)")
            tab.flush()

            let result = await executeLocalStreaming(command: command) { [weak tab] chunk in
                Task { @MainActor in tab?.appendOutput(chunk) }
            }

            guard !Task.isCancelled else { return TabToolResult(toolResult: nil, isComplete: false) }

            if result.status != 0 {
                tab.appendLog("exit code: \(result.status)")
            }

            let toolOutput = result.output.isEmpty
                ? "(no output, exit code: \(result.status))"
                : result.output
            let truncated = toolOutput.count > 50_000
                ? String(toolOutput.prefix(50_000)) + "\n...(truncated)"
                : toolOutput

            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": truncated],
                isComplete: false
            )
        }

        // execute_agent_command / execute_daemon_command
        if name == "execute_daemon_command" || name == "execute_agent_command" {
            let command = Self.prependWorkingDirectory(
                input["command"] as? String ?? "", projectFolder: projectFolder)
            if let pathErr = Self.preflightCommand(command) {
                tab.appendLog(pathErr)
                tab.flush()
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": pathErr],
                    isComplete: false
                )
            }
            let isPrivileged = (name == "execute_daemon_command") && rootEnabled
            tab.appendLog("\(isPrivileged ? "🔴 #" : "🔧 $") \(Self.collapseHeredocs(command))")
            tab.flush()

            let result: (status: Int32, output: String)
            if isPrivileged {
                result = await helperService.execute(command: command)
            } else if Self.needsTCCTab(command) {
                result = await executeLocal(command: command)
            } else {
                result = await executeForTab(command: command)
            }

            guard !Task.isCancelled else { return TabToolResult(toolResult: nil, isComplete: false) }

            if result.status != 0 {
                tab.appendLog("exit code: \(result.status)")
            }

            let toolOutput: String
            if result.output.isEmpty {
                toolOutput = "(no output, exit code: \(result.status))"
            } else {
                toolOutput = result.output
            }

            let truncated = toolOutput.count > 50_000
                ? String(toolOutput.prefix(50_000)) + "\n...(truncated)"
                : toolOutput

            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": truncated],
                isComplete: false
            )
        }

        // list_agent_scripts
        if name == "list_agent_scripts" {
            let scripts = scriptService.listScripts()
            let output = scripts.isEmpty
                ? "No scripts found" : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
            tab.appendLog("🦾 AgentScripts: \(scripts.count) found")
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // read_agent_script
        if name == "read_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            let output = scriptService.readScript(name: scriptName) ?? "Error: script '\(scriptName)' not found."
            tab.appendLog("📖 Read: \(scriptName)")
            tab.appendLog(Self.codeFence(Self.preview(output, lines: readFilePreviewLines), language: "swift"))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // create_agent_script
        if name == "create_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            let output = scriptService.createScript(name: scriptName, content: content)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // update_agent_script
        if name == "update_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            let output = scriptService.updateScript(name: scriptName, content: content)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // delete_agent_script
        if name == "delete_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            let output = scriptService.deleteScript(name: scriptName)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // run_agent_script
        if name == "run_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            let arguments = input["arguments"] as? String ?? ""
            guard let compileCmd = scriptService.compileCommand(name: scriptName) else {
                let err = "Error: script '\(scriptName)' not found."
                tab.appendLog(err)
                tab.flush()
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": err],
                    isComplete: false
                )
            }

            tab.appendLog("🦾 Compiling: \(scriptName)")
            tab.flush()

            let compileResult = await executeForTab(command: compileCmd)
            guard !Task.isCancelled else {
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": "Script cancelled"],
                    isComplete: false
                )
            }

            if compileResult.status != 0 {
                tab.appendLog("Compile failed (exit code: \(compileResult.status))")
                tab.appendOutput(compileResult.output)
                tab.flush()
                let toolOutput = compileResult.output.isEmpty
                    ? "(compile failed, exit code: \(compileResult.status))"
                    : compileResult.output
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": String(toolOutput.prefix(10000))],
                    isComplete: false
                )
            }

            tab.appendLog("🦾 Running: \(scriptName)")
            tab.flush()

            tab.resetLLMStreamCounters()
            let cancelFlag = tab._cancelFlag
            let runResult = await scriptService.loadAndRunScriptViaProcess(
                name: scriptName,
                arguments: arguments,
                captureStderr: scriptCaptureStderr,
                isCancelled: { cancelFlag.value }
            ) { [weak tab] chunk in
                Task { @MainActor in
                    tab?.appendOutput(chunk)
                }
            }

            tab.flush()
            let statusNote = runResult.status == 0 ? "completed" : "exit code: \(runResult.status)"
            tab.appendLog("\(scriptName) \(statusNote)")
            tab.flush()

            let toolOutput = runResult.output.isEmpty
                ? "(no output, exit code: \(runResult.status))"
                : runResult.output
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": String(toolOutput.prefix(10000))],
                isComplete: false
            )
        }

        // lookup_sdef
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
            tab.appendLog("📖 SDEF: \(bundleID)\(className.map { " → \($0)" } ?? "")")
            let preview = output.components(separatedBy: "\n").prefix(20).joined(separator: "\n")
            let truncated = output.components(separatedBy: "\n").count > 20 ? "\n... (\(output.components(separatedBy: "\n").count) lines total)" : ""
            tab.appendLog(preview + truncated)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // run_applescript (in-process, full TCC)
        if name == "run_applescript" {
            let source = input["source"] as? String ?? ""
            tab.appendLog("🍎 AppleScript:\n\(source)")
            tab.flush()
            let result = await Self.offMain {
                NSAppleScriptService.shared.execute(source: source)
            }
            if !result.success {
                tab.appendLog(result.output)
            } else {
                tab.appendOutput(result.output)
            }
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": result.output],
                isComplete: false
            )
        }

        // apple_event_query — flat keys
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
                let err = "Error: action is required"
                tab.appendLog(err)
                tab.flush()
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": err],
                    isComplete: false
                )
            }
            let action = input["action"] as? String ?? operations.first?["action"] as? String ?? "?"
            let key = input["key"] as? String ?? operations.first?["key"] as? String ?? ""
            tab.appendLog("🍎 AE: \(bundleID) → \(action) \(key)")
            tab.flush()
            let opsData = try? JSONSerialization.data(withJSONObject: operations)
            let output = await Self.offMain {
                guard let data = opsData,
                      let ops = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    return "Error: failed to process operations"
                }
                return AppleEventService.shared.execute(bundleID: bundleID, operations: ops)
            }
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_check_permission
        if name == "ax_check_permission" {
            let hasPermission = AccessibilityService.hasAccessibilityPermission()
            let output = hasPermission ? "Accessibility permission: granted" : "Accessibility permission: NOT granted. Use ax_request_permission to prompt the user."
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_request_permission
        if name == "ax_request_permission" {
            tab.appendLog("♿️ Requesting Accessibility permission...")
            let granted = AccessibilityService.requestAccessibilityPermission()
            let output = granted ? "Accessibility permission granted!" : "Accessibility permission denied. Please enable it in System Settings > Privacy & Security > Accessibility."
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_list_windows
        if name == "ax_list_windows" {
            let limit = input["limit"] as? Int ?? 50
            tab.appendLog("Listing windows (limit: \(limit))...")
            tab.flush()
            let output = await Self.offMain { AccessibilityService.shared.listWindows(limit: limit) }
            tab.appendLog(Self.preview(output, lines: 20))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_inspect_element
        if name == "ax_inspect_element" {
            guard let xVal = input["x"] as? Double,
                  let yVal = input["y"] as? Double else {
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": "Error: x and y coordinates are required"],
                    isComplete: false
                )
            }
            let x = CGFloat(xVal)
            let y = CGFloat(yVal)
            let depth = input["depth"] as? Int ?? 3
            tab.appendLog("♿️ Inspecting element at (\(x), \(y))...")
            tab.flush()
            let output = await Self.offMain { AccessibilityService.shared.inspectElementAt(x: x, y: y, depth: depth) }
            tab.appendLog(Self.preview(output, lines: 30))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_get_properties
        if name == "ax_get_properties" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let appBundleId = input["appBundleId"] as? String
            let x = (input["x"] as? Double).map { CGFloat($0) }
            let y = (input["y"] as? Double).map { CGFloat($0) }
            tab.appendLog("Getting element properties...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.getElementProperties(
                    role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y
                )
            }
            tab.appendLog(Self.preview(output, lines: 30))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_perform_action
        if name == "ax_perform_action" {
            let action = input["action"] as? String ?? ""
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let appBundleId = input["appBundleId"] as? String
            let x = (input["x"] as? Double).map { CGFloat($0) }
            let y = (input["y"] as? Double).map { CGFloat($0) }
            tab.appendLog("Performing action: \(action)...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.performAction(
                    role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y,
                    action: action
                )
            }
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_type_text
        if name == "ax_type_text" {
            let text = input["text"] as? String ?? ""
            let x = (input["x"] as? Double).map { CGFloat($0) }
            let y = (input["y"] as? Double).map { CGFloat($0) }
            tab.appendLog("Typing: \(text.count) characters...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.typeText(text, at: x, y: y)
            }
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_click
        if name == "ax_click" {
            guard let xVal = input["x"] as? Double,
                  let yVal = input["y"] as? Double else {
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": "Error: x and y coordinates are required"],
                    isComplete: false
                )
            }
            let x = CGFloat(xVal)
            let y = CGFloat(yVal)
            let button = input["button"] as? String ?? "left"
            let clicks = input["clicks"] as? Int ?? 1
            tab.appendLog("♿️ Clicking at (\(x), \(y))...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.clickAt(x: x, y: y, button: button, clicks: clicks)
            }
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_scroll
        if name == "ax_scroll" {
            guard let xVal = input["x"] as? Double,
                  let yVal = input["y"] as? Double else {
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": "Error: x and y coordinates are required"],
                    isComplete: false
                )
            }
            let x = CGFloat(xVal)
            let y = CGFloat(yVal)
            let deltaX = input["deltaX"] as? Int ?? 0
            let deltaY = input["deltaY"] as? Int ?? 0
            tab.appendLog("♿️ Scrolling at (\(x), \(y))...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.scrollAt(x: x, y: y, deltaX: deltaX, deltaY: deltaY)
            }
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_press_key
        if name == "ax_press_key" {
            guard let keyCodeVal = input["keyCode"] as? Int else {
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": "Error: keyCode is required"],
                    isComplete: false
                )
            }
            let keyCode = UInt16(keyCodeVal)
            let modifiers = input["modifiers"] as? [String] ?? []
            tab.appendLog("♿️ Pressing key code: \(keyCodeVal)...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.pressKey(virtualKey: keyCode, modifiers: modifiers)
            }
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_screenshot
        if name == "ax_screenshot" {
            let x = (input["x"] as? Double).map { CGFloat($0) }
            let y = (input["y"] as? Double).map { CGFloat($0) }
            let width = (input["width"] as? Double).map { CGFloat($0) }
            let height = (input["height"] as? Double).map { CGFloat($0) }
            let windowId = input["windowId"] as? Int

            tab.appendLog("Capturing screenshot...")
            tab.flush()

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
                output = await Self.offMain {
                    AccessibilityService.shared.captureAllWindows()
                }
            }

            if output.contains("\"path\"") {
                tab.appendLog("♿️ Screenshot captured successfully")
            } else {
                tab.appendLog(output)
            }
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_get_audit_log
        if name == "ax_get_audit_log" {
            let limit = input["limit"] as? Int ?? 50
            tab.appendLog("Getting accessibility audit log...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.getAuditLog(limit: limit)
            }
            tab.appendLog(Self.preview(output, lines: 30))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_set_properties
        if name == "ax_set_properties" {
            guard let propertiesInput = input["properties"] as? [String: Any], !propertiesInput.isEmpty else {
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": "Error: properties dictionary is required"],
                    isComplete: false
                )
            }
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let appBundleId = input["appBundleId"] as? String
            let x = (input["x"] as? Double).map { CGFloat($0) }
            let y = (input["y"] as? Double).map { CGFloat($0) }
            tab.appendLog("Setting element properties...")
            tab.flush()
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
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_find_element
        if name == "ax_find_element" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let appBundleId = input["appBundleId"] as? String
            let timeout = input["timeout"] as? Double ?? 5.0
            tab.appendLog("Finding element...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.findElement(
                    role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout
                )
            }
            tab.appendLog(Self.preview(output, lines: 30))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_get_focused_element
        if name == "ax_get_focused_element" {
            let appBundleId = input["appBundleId"] as? String
            tab.appendLog("Getting focused element...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.getFocusedElement(appBundleId: appBundleId)
            }
            tab.appendLog(Self.preview(output, lines: 30))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_get_children
        if name == "ax_get_children" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let appBundleId = input["appBundleId"] as? String
            let x = (input["x"] as? Double).map { CGFloat($0) }
            let y = (input["y"] as? Double).map { CGFloat($0) }
            let depth = input["depth"] as? Int ?? 3
            tab.appendLog("Getting element children...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.getChildren(
                    role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y, depth: depth
                )
            }
            tab.appendLog(Self.preview(output, lines: 30))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_drag
        if name == "ax_drag" {
            guard let fromXVal = input["fromX"] as? Double,
                  let fromYVal = input["fromY"] as? Double,
                  let toXVal = input["toX"] as? Double,
                  let toYVal = input["toY"] as? Double else {
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": "Error: fromX, fromY, toX, toY coordinates are required"],
                    isComplete: false
                )
            }
            let fromX = CGFloat(fromXVal)
            let fromY = CGFloat(fromYVal)
            let toX = CGFloat(toXVal)
            let toY = CGFloat(toYVal)
            let button = input["button"] as? String ?? "left"
            tab.appendLog("Dragging from (\(fromX), \(fromY)) to (\(toX), \(toY))...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.drag(fromX: fromX, fromY: fromY, toX: toX, toY: toY, button: button)
            }
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_wait_for_element
        if name == "ax_wait_for_element" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let appBundleId = input["appBundleId"] as? String
            let timeout = input["timeout"] as? Double ?? 10.0
            let pollInterval = input["pollInterval"] as? Double ?? 0.5
            tab.appendLog("Waiting for element (timeout: \(timeout)s)...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.waitForElement(
                    role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout, pollInterval: pollInterval
                )
            }
            tab.appendLog(Self.preview(output, lines: 30))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_click_element (Phase 1 Improvement)
        if name == "ax_click_element" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let appBundleId = input["appBundleId"] as? String
            let timeout = input["timeout"] as? Double ?? 5.0
            let verify = input["verify"] as? Bool ?? false
            tab.appendLog("Clicking element (role: \(role ?? "any"), title: \(title ?? "any"))...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.clickElement(
                    role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout, verify: verify
                )
            }
            tab.appendLog(Self.preview(output, lines: 30))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_wait_adaptive (Phase 1 Improvement)
        if name == "ax_wait_adaptive" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let appBundleId = input["appBundleId"] as? String
            let timeout = input["timeout"] as? Double ?? 10.0
            let initialDelay = input["initialDelay"] as? Double ?? 0.1
            let maxDelay = input["maxDelay"] as? Double ?? 1.0
            tab.appendLog("Waiting for element (adaptive, timeout: \(timeout)s)...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.waitForElementAdaptive(
                    role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout,
                    initialDelay: initialDelay, maxDelay: maxDelay
                )
            }
            tab.appendLog(Self.preview(output, lines: 30))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_type_into_element (Phase 1 Improvement)
        if name == "ax_type_into_element" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let text = input["text"] as? String ?? ""
            let appBundleId = input["appBundleId"] as? String
            let verify = input["verify"] as? Bool ?? true
            tab.appendLog("Typing \(text.count) chars into element...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.typeTextIntoElement(
                    role: role, title: title, text: text, appBundleId: appBundleId, verify: verify
                )
            }
            tab.appendLog(Self.preview(output, lines: 30))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_highlight_element (Phase 2, v1.0.16)
        if name == "ax_highlight_element" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let appBundleId = input["appBundleId"] as? String
            let x = (input["x"] as? Double).map { CGFloat($0) }
            let y = (input["y"] as? Double).map { CGFloat($0) }
            let duration = input["duration"] as? Double ?? 2.0
            let color = input["color"] as? String ?? "green"
            tab.appendLog("Highlighting element (duration: \(duration)s, color: \(color))...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.highlightElement(
                    role: role, title: title, value: value, appBundleId: appBundleId,
                    x: x, y: y, duration: duration, color: color
                )
            }
            tab.appendLog(Self.preview(output, lines: 30))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_get_window_frame (Phase 2, v1.0.16)
        if name == "ax_get_window_frame" {
            let windowId = input["windowId"] as? Int ?? 0
            tab.appendLog("Getting frame for window \(windowId)...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.getWindowFrame(windowId: windowId)
            }
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // ax_show_menu
        if name == "ax_show_menu" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let appBundleId = input["appBundleId"] as? String
            let x = (input["x"] as? Double).map { CGFloat($0) }
            let y = (input["y"] as? Double).map { CGFloat($0) }
            tab.appendLog("Showing context menu...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.showMenu(
                    role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y
                )
            }
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // MARK: - Web Automation (Phase 2)

        // web_open
        if name == "web_open" {
            guard let urlString = input["url"] as? String,
                  let url = URL(string: urlString) else {
                let errorMsg = "Error: Invalid or missing URL"
                tab.appendLog(errorMsg)
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": errorMsg],
                    isComplete: false
                )
            }
            let browserStr = input["browser"] as? String ?? "safari"
            let browser = WebAutomationService.BrowserType(rawValue: browserStr) ?? .safari
            tab.appendLog("Opening \(urlString) in \(browser.rawValue)...")
            tab.flush()
            do {
                let output = try await WebAutomationService.shared.open(url: url, browser: browser)
                tab.appendLog(output)
            } catch {
                tab.appendLog("Error: \(error.localizedDescription)")
            }
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": tab.logBuffer],
                isComplete: false
            )
        }

        // web_find
        if name == "web_find" {
            let selector = input["selector"] as? String ?? ""
            let strategyStr = input["strategy"] as? String ?? "auto"
            let strategy = SelectorStrategy(rawValue: strategyStr) ?? .auto
            let timeout = input["timeout"] as? Double ?? 10.0
            let fuzzyThreshold = input["fuzzyThreshold"] as? Double ?? 0.6
            let appBundleId = input["appBundleId"] as? String
            tab.appendLog("Finding element: \(selector)...")
            tab.flush()
            do {
                let output = try await WebAutomationService.shared.findElement(
                    selector: selector, strategy: strategy, timeout: timeout,
                    fuzzyThreshold: fuzzyThreshold, appBundleId: appBundleId
                )
                if let jsonData = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
                   let jsonStr = String(data: jsonData, encoding: .utf8) {
                    tab.appendLog(jsonStr)
                } else {
                    tab.appendLog("Found element: \(output)")
                }
            } catch {
                tab.appendLog("Error: \(error.localizedDescription)")
            }
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": tab.logBuffer],
                isComplete: false
            )
        }

        // web_click
        if name == "web_click" {
            let selector = input["selector"] as? String ?? ""
            let strategyStr = input["strategy"] as? String ?? "auto"
            let strategy = SelectorStrategy(rawValue: strategyStr) ?? .auto
            let appBundleId = input["appBundleId"] as? String
            tab.appendLog("Clicking element: \(selector)...")
            tab.flush()
            do {
                let output = try await WebAutomationService.shared.click(
                    selector: selector, strategy: strategy, appBundleId: appBundleId
                )
                tab.appendLog(output)
            } catch {
                tab.appendLog("Error: \(error.localizedDescription)")
            }
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": tab.logBuffer],
                isComplete: false
            )
        }

        // web_type
        if name == "web_type" {
            let selector = input["selector"] as? String ?? ""
            let text = input["text"] as? String ?? ""
            let strategyStr = input["strategy"] as? String ?? "auto"
            let strategy = SelectorStrategy(rawValue: strategyStr) ?? .auto
            let verify = input["verify"] as? Bool ?? true
            let appBundleId = input["appBundleId"] as? String
            tab.appendLog("Typing \(text.count) chars into: \(selector)...")
            tab.flush()
            do {
                let output = try await WebAutomationService.shared.type(
                    text: text, selector: selector, strategy: strategy, verify: verify, appBundleId: appBundleId
                )
                tab.appendLog(output)
            } catch {
                tab.appendLog("Error: \(error.localizedDescription)")
            }
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": tab.logBuffer],
                isComplete: false
            )
        }

        // web_execute_js
        if name == "web_execute_js" {
            let script = input["script"] as? String ?? ""
            let browser = input["browser"] as? String
            tab.appendLog("Executing JavaScript...")
            tab.flush()
            do {
                let output = try await WebAutomationService.shared.executeJavaScript(script: script, browser: browser)
                tab.appendLog(output as? String ?? "Script executed")
            } catch {
                tab.appendLog("Error: \(error.localizedDescription)")
            }
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": tab.logBuffer],
                isComplete: false
            )
        }

        // web_get_url / web_get_title (via Selenium AgentScript)
        if name == "web_get_url" || name == "web_get_title" {
            let action = name == "web_get_url" ? "getUrl" : "getTitle"
            tab.appendLog("\(name == "web_get_url" ? "Getting URL" : "Getting title")...")
            tab.flush()
            let args = "{\"action\":\"\(action)\"}"
            // Run Selenium agent script
            guard let compileCmd = scriptService.compileCommand(name: "Selenium") else {
                let err = "Error: Selenium script not found"
                tab.appendLog(err)
                return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": err], isComplete: false)
            }
            let compileResult = await executeForTab(command: compileCmd)
            if compileResult.status != 0 {
                tab.appendLog("Compile failed: \(compileResult.output)")
                return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": compileResult.output], isComplete: false)
            }
            let cancelFlag = tab._cancelFlag
            let result = await scriptService.loadAndRunScriptViaProcess(name: "Selenium", arguments: args, captureStderr: false, isCancelled: { cancelFlag.value }) { chunk in }
            tab.appendLog(result.output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": result.output], isComplete: false)
        }

        // MARK: - Selenium WebDriver Tools (run via Selenium AgentScript)

        // Helper function for Selenium operations
        func runSeleniumHelper(tab: ScriptTab, args: String, logMessage: String) async -> TabToolResult {
            tab.appendLog(logMessage)
            tab.flush()
            guard let compileCmd = scriptService.compileCommand(name: "Selenium") else {
                let err = "Error: Selenium script not found"
                tab.appendLog(err)
                return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": err], isComplete: false)
            }
            let compileResult = await executeForTab(command: compileCmd)
            if compileResult.status != 0 {
                tab.appendLog("Compile failed: \(compileResult.output)")
                return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": compileResult.output], isComplete: false)
            }
            let cancelFlag = tab._cancelFlag
            let result = await scriptService.loadAndRunScriptViaProcess(name: "Selenium", arguments: args, captureStderr: false, isCancelled: { cancelFlag.value }) { chunk in }
            tab.appendLog(result.output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": result.output], isComplete: false)
        }

        // selenium_start
        if name == "selenium_start" {
            let browser = input["browser"] as? String ?? "safari"
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"start\",\"browser\":\"\(browser)\",\"port\":\(port)}"
            return await runSeleniumHelper(tab: tab, args: args, logMessage: "Starting Selenium session (\(browser))...")
        }

        // selenium_stop
        if name == "selenium_stop" {
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"stop\",\"port\":\(port)}"
            return await runSeleniumHelper(tab: tab, args: args, logMessage: "Stopping Selenium session...")
        }

        // selenium_navigate
        if name == "selenium_navigate" {
            guard let url = input["url"] as? String else {
                let errorMsg = "Error: URL required for selenium_navigate"
                tab.appendLog(errorMsg)
                return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": errorMsg], isComplete: false)
            }
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"navigate\",\"url\":\"\(url)\",\"port\":\(port)}"
            return await runSeleniumHelper(tab: tab, args: args, logMessage: "Navigating to: \(url)...")
        }

        // selenium_find
        if name == "selenium_find" {
            let strategy = input["strategy"] as? String ?? "css"
            let value = input["value"] as? String ?? ""
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"find\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"port\":\(port)}"
            return await runSeleniumHelper(tab: tab, args: args, logMessage: "Finding element: \(strategy)=\(value)...")
        }

        // selenium_click
        if name == "selenium_click" {
            let strategy = input["strategy"] as? String ?? "css"
            let value = input["value"] as? String ?? ""
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"click\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"port\":\(port)}"
            return await runSeleniumHelper(tab: tab, args: args, logMessage: "Clicking element: \(strategy)=\(value)...")
        }

        // selenium_type
        if name == "selenium_type" {
            let strategy = input["strategy"] as? String ?? "css"
            let value = input["value"] as? String ?? ""
            let text = input["text"] as? String ?? ""
            let port = input["port"] as? Int ?? 7055
            let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let args = "{\"action\":\"type\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"text\":\"\(escapedText)\",\"port\":\(port)}"
            return await runSeleniumHelper(tab: tab, args: args, logMessage: "Typing \(text.count) chars into: \(strategy)=\(value)...")
        }

        // selenium_execute
        if name == "selenium_execute" {
            let script = input["script"] as? String ?? ""
            let port = input["port"] as? Int ?? 7055
            let escapedScript = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let args = "{\"action\":\"execute\",\"script\":\"\(escapedScript)\",\"port\":\(port)}"
            return await runSeleniumHelper(tab: tab, args: args, logMessage: "Executing JavaScript via Selenium...")
        }

        // selenium_screenshot
        if name == "selenium_screenshot" {
            let filename = input["filename"] as? String ?? "selenium_\(Int(Date().timeIntervalSince1970)).png"
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"screenshot\",\"filename\":\"\(filename)\",\"port\":\(port)}"
            return await runSeleniumHelper(tab: tab, args: args, logMessage: "Taking screenshot...")
        }

        // selenium_wait
        if name == "selenium_wait" {
            let strategy = input["strategy"] as? String ?? "css"
            let value = input["value"] as? String ?? ""
            let timeout = input["timeout"] as? Double ?? 10.0
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"waitFor\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"timeout\":\(timeout),\"port\":\(port)}"
            return await runSeleniumHelper(tab: tab, args: args, logMessage: "Waiting for element: \(strategy)=\(value)...")
        }

        // MCP tools
        if name.hasPrefix("mcp_") {
            let parts = name.dropFirst(4).split(separator: "_", maxSplits: 1)
            let serverName = String(parts.first ?? "")
            let toolName = String(parts.last ?? "")

            let disabledSnapshot = MCPService.shared.disabledTools
            let toolKey = MCPService.toolKey(serverName: serverName, toolName: toolName)
            guard !disabledSnapshot.contains(toolKey) else {
                let msg = "Tool '\(toolName)' is disabled"
                tab.appendLog("🖥️ MCP[\(serverName)]: \(msg)")
                tab.flush()
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": msg],
                    isComplete: false
                )
            }

            tab.appendLog("🖥️ MCP[\(serverName)]: \(toolName)")
            tab.flush()

            var mcpOutput = ""
            if let mcpTool = MCPService.shared.discoveredTools.first(where: {
                $0.serverName == serverName && $0.name == toolName
            }) {
                do {
                    let args = input.mapValues { value -> JSONValue in
                        if let s = value as? String { return .string(s) }
                        if let i = value as? Int { return .int(i) }
                        if let d = value as? Double { return .double(d) }
                        if let b = value as? Bool { return .bool(b) }
                        return .string(String(describing: value))
                    }
                    let result = try await MCPService.shared.callTool(
                        serverId: mcpTool.serverId,
                        name: toolName,
                        arguments: args
                    )
                    mcpOutput = result.content.compactMap { block -> String? in
                        if case .text(let t) = block { return t }
                        return nil
                    }.joined(separator: "\n")
                } catch {
                    mcpOutput = "MCP error: \(error.localizedDescription)"
                }
            } else {
                mcpOutput = "MCP tool not found: \(serverName)/\(toolName)"
            }

            tab.appendLog(mcpOutput)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": mcpOutput],
                isComplete: false
            )
        }

        // Unhandled tool
        let msg = "Tool '\(name)' is not available in tab context"
        tab.appendLog(msg)
        tab.flush()
        return TabToolResult(
            toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": msg],
            isComplete: false
        )
    }

    // MARK: - Tab Command Execution

    /// Execute a command via UserService without affecting the main ViewModel's streaming state.
    func executeForTab(command: String) async -> (status: Int32, output: String) {
        await userService.execute(command: command)
    }
}
