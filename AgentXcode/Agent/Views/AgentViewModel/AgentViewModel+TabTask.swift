@preconcurrency import Foundation
import MCPClient

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

        tab.appendLog("--- Tab Task ---")
        tab.appendLog("Prompt: \(prompt)")
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

        let provider = selectedProvider

        let claude: ClaudeService? = provider == .claude
            ? ClaudeService(apiKey: apiKey, model: selectedModel, historyContext: tabHistoryContext) : nil
        let ollama: OllamaService?
        switch provider {
        case .ollama:
            ollama = OllamaService(apiKey: ollamaAPIKey, model: ollamaModel, endpoint: ollamaEndpoint, supportsVision: false, historyContext: tabHistoryContext)
        case .localOllama:
            ollama = OllamaService(apiKey: "", model: localOllamaModel, endpoint: localOllamaEndpoint, supportsVision: false, historyContext: tabHistoryContext)
        default:
            ollama = nil
        }

        // Build on existing conversation or start fresh
        var messages: [[String: Any]] = tab.llmMessages
        messages.append(["role": "user", "content": prompt])

        var iterations = 0
        let maxIter = maxIterations
        var consecutiveNoTool = 0

        while !Task.isCancelled && iterations < maxIter {
            iterations += 1

            do {
                tab.isLLMThinking = true
                let response: (content: [[String: Any]], stopReason: String)
                var textWasStreamed = false

                if let claude {
                    response = try await claude.sendStreaming(messages: messages) { [weak tab] delta in
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
                } else {
                    throw AgentError.noAPIKey
                }
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
                    if consecutiveNoTool >= 3 {
                        tab.appendLog("(model not using tools — stopping)")
                        break
                    }
                    messages.append(["role": "user", "content": "Continue. Use tools to perform actions. Call task_complete when finished."])
                    tab.llmMessages = messages
                }

            } catch {
                if !Task.isCancelled {
                    tab.appendLog("Error: \(error.localizedDescription)")
                }
                break
            }
        }

        if iterations >= maxIter {
            tab.appendLog("Reached maximum iterations (\(maxIter))")
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
            let oldPreview = Self.preview(oldString, lines: 3)
            let newPreview = Self.preview(newString, lines: 3)
            tab.appendLog("```diff\n- \(oldPreview)\n+ \(newPreview)\n```")
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
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

        // execute_shell_command — in-process shell with ALL TCC
        if name == "execute_shell_command" {
            let command = input["command"] as? String ?? ""
            tab.appendLog("🐣 \(Self.collapseHeredocs(command))")
            tab.flush()

            let result = await executeLocalStreaming(command: command) { [weak tab] chunk in
                Task { @MainActor in
                    tab?.appendOutput(chunk)
                }
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

        // execute_user_command / execute_command
        if name == "execute_command" || name == "execute_user_command" {
            let command = input["command"] as? String ?? ""
            if let pathErr = Self.preflightCommand(command) {
                tab.appendLog(pathErr)
                tab.flush()
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": pathErr],
                    isComplete: false
                )
            }
            let isPrivileged = (name == "execute_command") && rootEnabled
            tab.appendLog("\(isPrivileged ? "🔴 #" : "🔧 $") \(Self.collapseHeredocs(command))")
            tab.flush()

            let result: (status: Int32, output: String)
            if isPrivileged {
                result = await helperService.execute(command: command)
            } else if Self.isOsascriptCommand(command) {
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

        // apple_event_query
        if name == "apple_event_query" {
            let bundleID = input["bundle_id"] as? String ?? ""
            let operations = input["operations"] as? [[String: Any]] ?? []
            let allowWrites = input["allow_writes"] as? Bool ?? false
            tab.appendLog("🍎 AE query: \(bundleID) (\(operations.count) ops)")
            tab.flush()
            let opsData = try? JSONSerialization.data(withJSONObject: operations)
            let output = await Self.offMain {
                guard let data = opsData,
                      let ops = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    return "Error: failed to process operations"
                }
                return AppleEventService.shared.execute(
                    bundleID: bundleID, operations: ops, allowWrites: allowWrites
                )
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
            let appBundleId = input["appBundleId"] as? String
            let x = (input["x"] as? Double).map { CGFloat($0) }
            let y = (input["y"] as? Double).map { CGFloat($0) }
            tab.appendLog("Getting element properties...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.getElementProperties(
                    role: role, title: title, appBundleId: appBundleId, x: x, y: y
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
            let appBundleId = input["appBundleId"] as? String
            let x = (input["x"] as? Double).map { CGFloat($0) }
            let y = (input["y"] as? Double).map { CGFloat($0) }
            let allowWrites = input["allowWrites"] as? Bool ?? false
            tab.appendLog("Performing action: \(action)...")
            tab.flush()
            let output = await Self.offMain {
                AccessibilityService.shared.performAction(
                    role: role, title: title, appBundleId: appBundleId, x: x, y: y,
                    action: action, allowWrites: allowWrites
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
