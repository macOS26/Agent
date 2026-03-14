@preconcurrency import Foundation

// MARK: - Task Execution

extension AgentViewModel {

    // MARK: - Local Execution (osascript)

    /// Runs a command directly in the Agent app process (not via XPC).
    /// Used for osascript so it inherits the app's Automation permissions.
    private nonisolated func executeLocal(command: String) async -> (status: Int32, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]

                var env = ProcessInfo.processInfo.environment
                env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
                process.environment = env

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: (-1, "Failed to launch: \(error.localizedDescription)"))
                    return
                }

                // Read pipes then wait — osascript output is small, no deadlock risk
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                var output = String(data: stdoutData, encoding: .utf8) ?? ""
                let errStr = String(data: stderrData, encoding: .utf8) ?? ""
                if !errStr.isEmpty {
                    if !output.isEmpty { output += "\n" }
                    output += errStr
                }

                continuation.resume(returning: (process.terminationStatus, output))
            }
        }
    }

    /// Returns true if the command contains osascript and should run locally.
    private nonisolated static func isOsascriptCommand(_ command: String) -> Bool {
        command.contains("osascript") || command.contains("/usr/bin/osascript")
    }

    // MARK: - Task Execution Loop

    func executeTask(_ prompt: String) async {
        isRunning = true
        userWasActive = false
        rootWasActive = false
        recentOutputHashes.removeAll()

        if !activityLog.isEmpty {
            logBuffer += "\n"
        }
        appendLog("--- New Task ---")
        appendLog("Task: \(prompt)")

        let historyContext = history.contextForPrompt()
        let provider = selectedProvider
        let modelName: String
        let isVision: Bool
        switch provider {
        case .claude:
            modelName = selectedModel
            isVision = false
        case .ollama:
            modelName = ollamaModel
            isVision = selectedOllamaSupportsVision
        case .localOllama:
            modelName = localOllamaModel
            isVision = selectedLocalOllamaSupportsVision
        }
        appendLog("Model: \(provider.displayName) / \(modelName)\(isVision ? " (vision)" : "")")
        flushLog()

        let claude: ClaudeService? = provider == .claude
            ? ClaudeService(apiKey: apiKey, model: selectedModel, historyContext: historyContext) : nil
        let ollama: OllamaService?
        switch provider {
        case .ollama:
            ollama = OllamaService(apiKey: ollamaAPIKey, model: ollamaModel, endpoint: ollamaEndpoint, supportsVision: isVision, historyContext: historyContext)
        case .localOllama:
            ollama = OllamaService(apiKey: "", model: localOllamaModel, endpoint: localOllamaEndpoint, supportsVision: isVision, historyContext: historyContext)
        default:
            ollama = nil
        }

        var messages: [[String: Any]]

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
            contentBlocks.append(["type": "text", "text": prompt])
            messages = [["role": "user", "content": contentBlocks]]
            // Clear attachments after use
            attachedImages.removeAll()
            attachedImagesBase64.removeAll()
        } else {
            messages = [["role": "user", "content": prompt]]
        }

        var commandsRun: [String] = []
        var completionSummary = ""
        var consecutiveNoTool = 0

        var iterations = 0
        let maxIterations = self.maxIterations

        while !Task.isCancelled && iterations < maxIterations {
            iterations += 1

            do {
                isThinking = true
                let response: (content: [[String: Any]], stopReason: String)
                var textWasStreamed = false
                if let claude {
                    response = try await claude.sendStreaming(messages: messages) { [weak self] delta in
                        Task { @MainActor in
                            self?.isThinking = false
                            self?.appendStreamDelta(delta)
                        }
                    }
                    textWasStreamed = true
                    flushStreamBuffer()
                } else if let ollama {
                    response = try await ollama.sendStreaming(messages: messages) { [weak self] delta in
                        Task { @MainActor in
                            self?.isThinking = false
                            self?.appendStreamDelta(delta)
                        }
                    }
                    textWasStreamed = true
                } else {
                    throw AgentError.noAPIKey
                }
                isThinking = false
                guard !Task.isCancelled else { break }

                var toolResults: [[String: Any]] = []
                var hasToolUse = false

                for block in response.content {
                    guard let type = block["type"] as? String else { continue }

                    if type == "text", let text = block["text"] as? String {
                        if !textWasStreamed { appendLog(text) }
                    } else if type == "tool_use" {
                        hasToolUse = true
                        guard let toolId = block["id"] as? String,
                              let name = block["name"] as? String,
                              let input = block["input"] as? [String: Any] else { continue }

                        if name == "task_complete" {
                            let summary = input["summary"] as? String ?? "Done"
                            completionSummary = summary
                            appendLog("Completed: \(summary)")
                            flushLog()
                            history.add(TaskRecord(prompt: prompt, summary: summary, commandsRun: commandsRun), maxBeforeSummary: maxHistoryBeforeSummary)
                            isRunning = false
                            return
                        }

                        // Coding tools — direct file operations via CodingService
                        if name == "read_file" {
                            let filePath = input["file_path"] as? String ?? ""
                            let offset = input["offset"] as? Int
                            let limit = input["limit"] as? Int
                            appendLog("Read: \(filePath)")
                            let output = CodingService.readFile(path: filePath, offset: offset, limit: limit)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "write_file" {
                            let filePath = input["file_path"] as? String ?? ""
                            let content = input["content"] as? String ?? ""
                            appendLog("Write: \(filePath)")
                            let output = CodingService.writeFile(path: filePath, content: content)
                            appendLog(output)
                            commandsRun.append("write_file: \(filePath)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "edit_file" {
                            let filePath = input["file_path"] as? String ?? ""
                            let oldString = input["old_string"] as? String ?? ""
                            let newString = input["new_string"] as? String ?? ""
                            let replaceAll = input["replace_all"] as? Bool ?? false
                            appendLog("Edit: \(filePath)")
                            let output = CodingService.editFile(path: filePath, oldString: oldString, newString: newString, replaceAll: replaceAll)
                            appendLog(output)
                            commandsRun.append("edit_file: \(filePath)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "list_files" {
                            let pattern = input["pattern"] as? String ?? "*"
                            let path = input["path"] as? String
                            appendLog("List: \(pattern)")
                            let output = CodingService.listFiles(pattern: pattern, path: path)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "search_files" {
                            let pattern = input["pattern"] as? String ?? ""
                            let path = input["path"] as? String
                            let include = input["include"] as? String
                            appendLog("Search: \(pattern)")
                            let output = CodingService.searchFiles(pattern: pattern, path: path, include: include)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "execute_command" || name == "execute_user_command" {
                            let command = input["command"] as? String ?? ""
                            let isPrivileged = (name == "execute_command") && rootEnabled
                            commandsRun.append(command)
                            appendLog("\(isPrivileged ? "#" : "$") \(Self.collapseHeredocs(command))")
                            flushLog()

                            let result: (status: Int32, output: String)
                            resetStreamCounters()
                            if isPrivileged {
                                rootServiceActive = true
                                rootWasActive = true
                                helperService.onOutput = { [weak self] chunk in
                                    self?.appendRawOutput(chunk)
                                }
                                result = await helperService.execute(command: command)
                                helperService.onOutput = nil
                                rootServiceActive = false
                            } else if Self.isOsascriptCommand(command) {
                                // Run osascript directly in the Agent app process
                                // so it inherits the app's Automation permissions
                                userServiceActive = true
                                userWasActive = true
                                result = await executeLocal(command: command)
                                userServiceActive = false
                            } else {
                                userServiceActive = true
                                userWasActive = true
                                userService.onOutput = { [weak self] chunk in
                                    self?.appendRawOutput(chunk)
                                }
                                result = await userService.execute(command: command)
                                userService.onOutput = nil
                                userServiceActive = false
                            }
                            flushLog()

                            // Don't log results if task was cancelled
                            guard !Task.isCancelled else { break }

                            if result.status != 0 {
                                appendLog("exit code: \(result.status)")
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

                        // Script management tools
                        if name == "list_agent_scripts" {
                            let scripts = scriptService.listScripts()
                            let output: String
                            if scripts.isEmpty {
                                output = "No scripts found in ~/Documents/Agent/agents/"
                            } else {
                                output = scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
                            }
                            appendLog("Scripts: \(scripts.count) found")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "read_agent_script" {
                            let scriptName = input["name"] as? String ?? ""
                            let output = scriptService.readScript(name: scriptName) ?? "Error: script '\(scriptName)' not found."
                            appendLog("Read: \(scriptName)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "create_agent_script" {
                            let scriptName = input["name"] as? String ?? ""
                            let content = input["content"] as? String ?? ""
                            let output = scriptService.createScript(name: scriptName, content: content)
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "update_agent_script" {
                            let scriptName = input["name"] as? String ?? ""
                            let content = input["content"] as? String ?? ""
                            let output = scriptService.updateScript(name: scriptName, content: content)
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "delete_agent_script" {
                            let scriptName = input["name"] as? String ?? ""
                            let output = scriptService.deleteScript(name: scriptName)
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "run_agent_script" {
                            let scriptName = input["name"] as? String ?? ""
                            let arguments = input["arguments"] as? String ?? ""
                            guard let compileCmd = scriptService.compileCommand(name: scriptName) else {
                                let err = "Error: script '\(scriptName)' not found."
                                appendLog(err)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": err])
                                continue
                            }

                            // Step 1: Compile the script dylib via UserService
                            appendLog("Compiling: \(scriptName)")
                            flushLog()

                            resetStreamCounters()
                            userServiceActive = true
                            userWasActive = true
                            userService.onOutput = { [weak self] chunk in
                                self?.appendRawOutput(chunk)
                            }
                            let compileResult = await userService.execute(command: compileCmd)
                            userService.onOutput = nil
                            userServiceActive = false
                            flushLog()

                            guard !Task.isCancelled else { break }

                            if compileResult.status != 0 {
                                appendLog("Compile failed (exit code: \(compileResult.status))")
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
                            appendLog("Running: \(scriptName) (in-process)")
                            flushLog()

                            let runResult = await scriptService.loadAndRunScript(name: scriptName, arguments: arguments)

                            guard !Task.isCancelled else { break }

                            if runResult.status != 0 {
                                appendLog("exit code: \(runResult.status)")
                            }
                            if !runResult.output.isEmpty {
                                appendLog(runResult.output)
                            }
                            let toolOutput = runResult.output.isEmpty
                                ? "(no output, exit code: \(runResult.status))"
                                : runResult.output
                            let truncated2 = toolOutput.count > 10000
                                ? String(toolOutput.prefix(10000)) + "\n...(truncated)"
                                : toolOutput
                            commandsRun.append("run_agent_script: \(scriptName)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": truncated2])
                        }

                        // Dynamic Apple Event query tool
                        if name == "apple_event_query" {
                            let bundleID = input["bundle_id"] as? String ?? ""
                            let operations = input["operations"] as? [[String: Any]] ?? []
                            let allowWrites = input["allow_writes"] as? Bool ?? false
                            appendLog("AE query: \(bundleID) (\(operations.count) ops)")
                            flushLog()
                            let output = AppleEventService.shared.execute(
                                bundleID: bundleID, operations: operations, allowWrites: allowWrites
                            )
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Xcode ScriptingBridge tools
                        if name == "xcode_grant_permission" {
                            appendLog("Granting Xcode Automation permission...")
                            flushLog()
                            let output = XcodeService.shared.grantPermission()
                            appendLog(output)
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "xcode_build" {
                            let projectPath = input["project_path"] as? String ?? ""
                            appendLog("Building: \(projectPath)")
                            flushLog()
                            let output = XcodeService.shared.buildProject(projectPath: projectPath)
                            appendLog(output)
                            commandsRun.append("xcode_build: \(projectPath)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "xcode_run" {
                            let projectPath = input["project_path"] as? String ?? ""
                            appendLog("Running: \(projectPath)")
                            flushLog()
                            let output = XcodeService.shared.runProject(projectPath: projectPath)
                            appendLog(output)
                            commandsRun.append("xcode_run: \(projectPath)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }
                    }
                }

                // Add assistant response to conversation
                messages.append(["role": "assistant", "content": response.content])

                if hasToolUse && !toolResults.isEmpty {
                    messages.append(["role": "user", "content": toolResults])
                    consecutiveNoTool = 0
                } else if !hasToolUse {
                    consecutiveNoTool += 1
                    // Give the model up to 3 nudges to use tools before giving up
                    if consecutiveNoTool >= 3 {
                        appendLog("(model not using tools — stopping)")
                        break
                    }
                    messages.append(["role": "user", "content": "Continue. You must use execute_user_command or execute_command tools to perform actions. Call task_complete when finished."])
                }

            } catch {
                if !Task.isCancelled {
                    appendLog("Error: \(error.localizedDescription)")
                }
                break
            }
        }

        guard !Task.isCancelled else { return }

        if iterations >= maxIterations {
            appendLog("Reached maximum iterations (\(maxIterations))")
        }

        // Save partial history if task didn't call task_complete
        if completionSummary.isEmpty && !commandsRun.isEmpty {
            history.add(TaskRecord(prompt: prompt, summary: "(incomplete)", commandsRun: commandsRun), maxBeforeSummary: maxHistoryBeforeSummary)
        }

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
