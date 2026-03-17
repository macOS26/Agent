@preconcurrency import Foundation
import MCPClient

// MARK: - Task Execution

extension AgentViewModel {

    // MARK: - Helpers

    /// Show first N lines of output, then "..." if there's more.
    static func preview(_ text: String, lines count: Int) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count <= count { return text.trimmingCharacters(in: .newlines) }
        return lines.prefix(count).joined(separator: "\n") + "\n..."
    }

    /// Wrap text in a markdown code fence with language tag for syntax highlighting.
    static func codeFence(_ text: String, language: String = "") -> String {
        "```\(language)\n\(text.trimmingCharacters(in: .newlines))\n```"
    }

    /// Guess language from file extension for syntax highlighting.
    static func langFromPath(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "python"
        case "js", "jsx": return "javascript"
        case "ts", "tsx": return "typescript"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "c", "h": return "c"
        case "cpp", "cc", "cxx", "hpp": return "cpp"
        case "m", "mm": return "objc"
        case "java": return "java"
        case "kt": return "kotlin"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "sql": return "sql"
        case "sh", "bash", "zsh": return "bash"
        case "html", "htm": return "html"
        case "css": return "css"
        case "xml", "plist": return "xml"
        default: return ""
        }
    }

    /// Validate that a path exists. Returns an error string if invalid, nil if OK.
    static func checkPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            return "Error: path does not exist: \(path) — check for typos"
        }
        return nil
    }

    /// Extract user-directory paths from a shell command for preflight validation.
    /// Catches typos like "/Users/foo/Documets/..." before running the command.
    static func preflightCommand(_ command: String) -> String? {
        // Match paths under /Users/ or ~/ — most common source of typos
        guard let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)(/Users/[^\s'";&|><$]+|~/[^\s'";&|><$]+)"#
        ) else { return nil }
        let nsCmd = command as NSString
        let matches = regex.matches(in: command, range: NSRange(location: 0, length: nsCmd.length))
        for match in matches {
            var path = nsCmd.substring(with: match.range(at: 1))
                .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            // Strip trailing wildcards/globs for directory validation (e.g. /path/to/*)
            while path.hasSuffix("*") || path.hasSuffix("?") {
                path = String(path.dropLast())
            }
            if path.hasSuffix("/") { path = String(path.dropLast()) }
            guard !path.isEmpty else { continue }
            let expanded = (path as NSString).expandingTildeInPath
            if !FileManager.default.fileExists(atPath: expanded) {
                return "Error: path does not exist: \(path) — check for typos in the path"
            }
        }
        return nil
    }

    /// Execute a command via UserService XPC with streaming output.
    private func executeViaUserAgent(command: String) async -> (status: Int32, output: String) {
        resetStreamCounters()
        userServiceActive = true
        userWasActive = true
        userService.onOutput = { [weak self] chunk in
            self?.appendRawOutput(chunk)
        }
        let result = await userService.execute(command: command)
        userService.onOutput = nil
        userServiceActive = false

        // Only show exit code on failure; streaming already displayed the output
        if result.status != 0 {
            appendLog("exit code: \(result.status)")
        }
        flushLog()
        return result
    }

    // MARK: - Local Execution (osascript)

    /// Runs a command directly in the Agent app process (not via XPC).
    /// Used for osascript so it inherits the app's Automation permissions.
    nonisolated func executeLocal(command: String) async -> (status: Int32, output: String) {
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

    /// Run a command in the Agent app process with streaming output.
    /// Inherits Agent's TCC permissions (Automation, Accessibility, ScreenRecording).
    nonisolated func executeLocalStreaming(command: String, onOutput: @escaping @Sendable (String) -> Void) async -> (status: Int32, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]

                var env = ProcessInfo.processInfo.environment
                env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
                process.environment = env

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                } catch {
                    let msg = "Failed to launch: \(error.localizedDescription)"
                    onOutput(msg)
                    continuation.resume(returning: (-1, msg))
                    return
                }

                // Stream output chunks as they arrive
                var collected = ""
                let handle = pipe.fileHandleForReading
                while true {
                    let data = handle.availableData
                    if data.isEmpty { break }
                    if let chunk = String(data: data, encoding: .utf8) {
                        collected += chunk
                        onOutput(chunk)
                    }
                }
                process.waitUntilExit()

                continuation.resume(returning: (process.terminationStatus, collected))
            }
        }
    }

    /// Returns true if the command contains osascript and should run locally.
    nonisolated static func isOsascriptCommand(_ command: String) -> Bool {
        command.contains("osascript") || command.contains("/usr/bin/osascript")
    }

    /// Returns true if the command needs TCC permissions and should open in a tab.
    nonisolated static func needsTCCTab(_ command: String) -> Bool {
        let lower = command.lowercased()
        return lower.contains("osascript") || lower.contains("screencapture")
            || lower.contains("applescript") || lower.contains("accessibility")
            || lower.contains("tccutil") || lower.contains("automator")
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
        trimToRecentTasks()
        appendLog("--- New Task ---")
        appendLog("Task: \(prompt)")

        // Use ChatHistoryStore for LLM context (summaries for older tasks, full messages for recent)
        let historyContext = ChatHistoryStore.shared.buildLLMContext()
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
            ? ClaudeService(apiKey: apiKey, model: selectedModel, historyContext: historyContext, projectFolder: projectFolder) : nil
        let ollama: OllamaService?
        switch provider {
        case .ollama:
            ollama = OllamaService(apiKey: ollamaAPIKey, model: ollamaModel, endpoint: ollamaEndpoint, supportsVision: isVision, historyContext: historyContext, projectFolder: projectFolder)
        case .localOllama:
            ollama = OllamaService(apiKey: "", model: localOllamaModel, endpoint: localOllamaEndpoint, supportsVision: isVision, historyContext: historyContext, projectFolder: projectFolder)
        default:
            ollama = nil
        }

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
                              let name = block["name"] as? String,
                              let input = block["input"] as? [String: Any] else { continue }

                        if name == "task_complete" {
                            let summary = input["summary"] as? String ?? "Done"
                            completionSummary = summary
                            appendLog("✅ Completed: \(summary)")
                            flushLog()
                            history.add(TaskRecord(prompt: prompt, summary: summary, commandsRun: commandsRun), maxBeforeSummary: maxHistoryBeforeSummary, apiKey: apiKey, model: selectedModel)
                            // End the task in SwiftData chat history
                            ChatHistoryStore.shared.endCurrentTask(summary: summary)
                            // Reply to the iMessage sender if this was an Agent! prompt
                            sendAgentReply(summary)
                            isRunning = false
                            return
                        }

                        // MARK: MCP tool calls (mcp_ServerName_toolName)

                        if name.hasPrefix("mcp_") {
                            let parts = name.dropFirst(4).split(separator: "_", maxSplits: 1)
                            let serverName = String(parts.first ?? "")
                            let toolName = String(parts.last ?? "")

                            // Snapshot disabled state once to avoid TOCTOU races
                            let disabledSnapshot = MCPService.shared.disabledTools
                            let toolKey = MCPService.toolKey(serverName: serverName, toolName: toolName)

                            // Block disabled tools
                            guard !disabledSnapshot.contains(toolKey) else {
                                let msg = "Tool '\(toolName)' is disabled"
                                appendLog("🖥️ MCP[\(serverName)]: \(msg)")
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": msg])
                                continue
                            }

                            appendLog("🖥️ MCP[\(serverName)]: \(toolName)")
                            flushLog()

                            var mcpOutput = ""

                            // Validate total argument size (1 MB cap)
                            let argData = try? JSONSerialization.data(withJSONObject: input)
                            if let argData, argData.count > 1_024 * 1_024 {
                                mcpOutput = "MCP error: arguments exceed 1 MB limit"
                                appendLog(mcpOutput)
                                flushLog()
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": mcpOutput])
                                consecutiveNoTool = 0
                                continue
                            }

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

                            appendLog(mcpOutput)
                            flushLog()
                            toolResults.append([
                                "type": "tool_result",
                                "tool_use_id": toolId,
                                "content": mcpOutput,
                            ])
                            consecutiveNoTool = 0
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
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
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
                            // Show compact diff preview
                            let oldPreview = Self.preview(oldString, lines: 3)
                            let newPreview = Self.preview(newString, lines: 3)
                            appendLog("```diff\n- \(oldPreview)\n+ \(newPreview)\n```")
                            appendLog(output)
                            commandsRun.append("edit_file: \(filePath)")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // MARK: Process-based tools (routed through UserService XPC)

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

                        // MARK: Git tools (routed through UserService XPC)

                        if name == "git_status" {
                            let path = input["path"] as? String
                            if let pathErr = Self.checkPath(path) {
                                appendLog(pathErr)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": pathErr])
                                continue
                            }
                            appendLog("🔀 $ git status\(path.map { " (\($0))" } ?? "")")
                            flushLog()
                            let cmd = CodingService.buildGitStatusCommand(path: path)
                            let result = await executeViaUserAgent(command: cmd)
                            guard !Task.isCancelled else { break }
                            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "(no output, exit code: \(result.status))" : result.output
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "git_diff" {
                            let path = input["path"] as? String
                            let staged = input["staged"] as? Bool ?? false
                            let target = input["target"] as? String
                            if let pathErr = Self.checkPath(path) {
                                appendLog(pathErr)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": pathErr])
                                continue
                            }
                            appendLog("🔀 $ git diff\(staged ? " --cached" : "")\(target.map { " \($0)" } ?? "")")
                            flushLog()
                            let cmd = CodingService.buildGitDiffCommand(path: path, staged: staged, target: target)
                            let result = await executeViaUserAgent(command: cmd)
                            guard !Task.isCancelled else { break }
                            let output: String
                            if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                output = staged ? "No staged changes" : "No changes"
                                appendLog(output)
                            } else if result.output.count > 50_000 {
                                output = String(result.output.prefix(50_000)) + "\n...(diff truncated)"
                            } else {
                                output = result.output
                            }
                            flushLog()
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "git_log" {
                            let path = input["path"] as? String
                            let count = input["count"] as? Int
                            if let pathErr = Self.checkPath(path) {
                                appendLog(pathErr)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": pathErr])
                                continue
                            }
                            appendLog("🔀 $ git log\(path.map { " (\($0))" } ?? "")")
                            flushLog()
                            let cmd = CodingService.buildGitLogCommand(path: path, count: count)
                            let result = await executeViaUserAgent(command: cmd)
                            guard !Task.isCancelled else { break }
                            let output: String
                            if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                output = "Error: \(result.status == 0 ? "empty log" : "exit code \(result.status)")"
                                appendLog(output)
                            } else {
                                output = result.output
                            }
                            flushLog()
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "git_commit" {
                            let path = input["path"] as? String
                            let message = input["message"] as? String ?? ""
                            let files = input["files"] as? [String]
                            if let pathErr = Self.checkPath(path) {
                                appendLog(pathErr)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": pathErr])
                                continue
                            }
                            appendLog("🔀 Git commit: \(message)")
                            flushLog()
                            let cmd = CodingService.buildGitCommitCommand(path: path, message: message, files: files)
                            let result = await executeViaUserAgent(command: cmd)
                            guard !Task.isCancelled else { break }
                            if !result.output.isEmpty { appendLog(result.output) }
                            commandsRun.append("git_commit: \(message)")
                            let output = result.output.isEmpty
                                ? "(no output, exit code: \(result.status))"
                                : result.output
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "git_diff_patch" {
                            let path = input["path"] as? String
                            let patch = input["patch"] as? String ?? ""
                            appendLog("Git apply patch")
                            flushLog()
                            // Write patch to temp file, apply, clean up
                            let tempName = "agent_patch_\(UUID().uuidString).patch"
                            let tempPath = "/tmp/\(tempName)"
                            let dir = CodingService.shellEscape(path ?? CodingService.defaultDir)
                            let cmd = "cat > \(tempPath) << 'AGENT_PATCH_EOF'\n\(patch)\nAGENT_PATCH_EOF\ncd \(dir) && git apply --verbose \(tempPath); STATUS=$?; rm -f \(tempPath); exit $STATUS"
                            let result = await executeViaUserAgent(command: cmd)
                            guard !Task.isCancelled else { break }
                            if !result.output.isEmpty { appendLog(result.output) }
                            commandsRun.append("git_diff_patch")
                            let output: String
                            if result.status != 0 {
                                output = result.output.isEmpty ? "Patch failed (exit code: \(result.status))" : result.output
                            } else {
                                output = result.output.isEmpty ? "Patch applied successfully" : result.output
                            }
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "git_branch" {
                            let path = input["path"] as? String
                            let branchName = input["name"] as? String ?? ""
                            let checkout = input["checkout"] as? Bool ?? true
                            if let pathErr = Self.checkPath(path) {
                                appendLog(pathErr)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": pathErr])
                                continue
                            }
                            appendLog("Git branch: \(branchName)")
                            flushLog()
                            let cmd = CodingService.buildGitBranchCommand(path: path, name: branchName, checkout: checkout)
                            let result = await executeViaUserAgent(command: cmd)
                            guard !Task.isCancelled else { break }
                            if !result.output.isEmpty { appendLog(result.output) }
                            commandsRun.append("git_branch: \(branchName)")
                            let output = result.output.isEmpty
                                ? (result.status == 0 ? "Created branch '\(branchName)'" : "Error (exit code: \(result.status))")
                                : result.output
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // MARK: Shell execution tools

                        if name == "execute_command" || name == "execute_user_command" {
                            let command = input["command"] as? String ?? ""
                            // Preflight: catch typos in /Users/ and ~/ paths before running
                            if let pathErr = Self.preflightCommand(command) {
                                appendLog(pathErr)
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": pathErr])
                                continue
                            }
                            let isPrivileged = (name == "execute_command") && rootEnabled
                            commandsRun.append(command)
                            appendLog("\(isPrivileged ? "🔴 #" : "🔧 $") \(Self.collapseHeredocs(command))")
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
                                result = await executeViaUserAgent(command: command)
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
                            appendLog("🦾 AgentScripts: \(scripts.count) found")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "read_agent_script" {
                            let scriptName = input["name"] as? String ?? ""
                            let output = scriptService.readScript(name: scriptName) ?? "Error: script '\(scriptName)' not found."
                            appendLog("📖 Read: \(scriptName)")
                            appendLog(Self.codeFence(Self.preview(output, lines: readFilePreviewLines), language: "swift"))
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

                            // Step 1: Compile the script dylib via UserService
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
                        if name == "execute_shell_command" {
                            let command = input["command"] as? String ?? ""

                            if Self.needsTCCTab(command) {
                                // TCC command — reuse existing tab per type, or create one
                                let label: String
                                if command.contains("osascript") {
                                    label = "osascript"
                                } else if command.contains("screencapture") {
                                    label = "screencapture"
                                } else {
                                    let words = command.prefix(30).components(separatedBy: " ")
                                    label = words.first ?? "app_cmd"
                                }

                                // Reuse existing tab for this label, or create a new one
                                let tab: ScriptTab
                                if let existing = scriptTabs.first(where: { $0.scriptName == label }) {
                                    tab = existing
                                    selectedTabId = tab.id
                                    tab.isRunning = true
                                } else {
                                    tab = openScriptTab(scriptName: label)
                                }
                                appendLog("App command... (see tab)")
                                flushLog()

                                tab.appendLog("🐣 $ \(AgentViewModel.collapseHeredocs(command))")
                                tab.flush()

                                let result = await executeLocalStreaming(command: command) { [weak tab] chunk in
                                    Task { @MainActor in
                                        tab?.appendOutput(chunk)
                                    }
                                }

                                tab.isRunning = false
                                tab.exitCode = result.status
                                tab.flush()
                                persistScriptTabs()

                                guard !Task.isCancelled else { break }

                                let statusNote = result.status == 0 ? "completed" : "exit code: \(result.status)"
                                appendLog("\(label) \(statusNote)")
                                flushLog()

                                let toolOutput = result.output.isEmpty
                                    ? "(no output, exit code: \(result.status))"
                                    : result.output
                                let truncated2 = toolOutput.count > 10000
                                    ? String(toolOutput.prefix(10000)) + "\n...(truncated)"
                                    : toolOutput
                                commandsRun.append("execute_shell_command: \(label)")
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": truncated2])
                            } else {
                                // Non-TCC command — route through XPC services
                                let collapsed = Self.collapseHeredocs(command)
                                appendLog("🔧 $ \(collapsed)")
                                flushLog()

                                let result = await userService.execute(command: command)
                                userWasActive = true

                                guard !Task.isCancelled else { break }

                                if result.status != 0 {
                                    appendLog("exit code: \(result.status)")
                                }

                                let toolOutput = result.output.isEmpty
                                    ? "(no output, exit code: \(result.status))"
                                    : result.output
                                let truncated2 = toolOutput.count > 10000
                                    ? String(toolOutput.prefix(10000)) + "\n...(truncated)"
                                    : toolOutput

                                let preview = Self.preview(result.output, lines: 10)
                                if !preview.isEmpty { appendLog(preview) }
                                flushLog()

                                let words = command.prefix(30).components(separatedBy: " ")
                                let label = words.first ?? "app_cmd"
                                commandsRun.append("execute_shell_command: \(label)")
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": truncated2])
                            }
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
                                    lines.append("  .\(p.name): \(p.type ?? "any")\(ro)\(p.description.map { " — \($0)" } ?? "")")
                                }
                                if !elems.isEmpty { lines.append("elements: \(elems.joined(separator: ", "))") }
                                output = lines.isEmpty ? "No class '\(cls)' found for \(bundleID)" : lines.joined(separator: "\n")
                            } else {
                                output = SDEFService.shared.summary(for: bundleID)
                            }
                            appendLog("📖 SDEF: \(bundleID)\(className.map { " → \($0)" } ?? "")")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        // Dynamic Apple Event query tool
                        if name == "apple_event_query" {
                            let bundleID = input["bundle_id"] as? String ?? ""
                            let operations = input["operations"] as? [[String: Any]] ?? []
                            let allowWrites = input["allow_writes"] as? Bool ?? false
                            appendLog("🍎 AE query: \(bundleID) (\(operations.count) ops)")
                            flushLog()
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
                            let appBundleId = input["appBundleId"] as? String
                            let x = (input["x"] as? Double).map { CGFloat($0) }
                            let y = (input["y"] as? Double).map { CGFloat($0) }
                            appendLog("Getting element properties...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.getElementProperties(
                                    role: role, title: title, appBundleId: appBundleId, x: x, y: y
                                )
                            }
                            appendLog(Self.preview(output, lines: 30))
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "ax_perform_action" {
                            let action = input["action"] as? String ?? ""
                            let role = input["role"] as? String
                            let title = input["title"] as? String
                            let appBundleId = input["appBundleId"] as? String
                            let x = (input["x"] as? Double).map { CGFloat($0) }
                            let y = (input["y"] as? Double).map { CGFloat($0) }
                            let allowWrites = input["allowWrites"] as? Bool ?? false
                            appendLog("Performing action: \(action)...")
                            flushLog()
                            let output = await Self.offMain {
                                AccessibilityService.shared.performAction(
                                    role: role, title: title, appBundleId: appBundleId, x: x, y: y,
                                    action: action, allowWrites: allowWrites
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

                        // Client-side web search via Tavily (for Ollama providers)
                        if name == "web_search" {
                            let query = input["query"] as? String ?? ""
                            appendLog("Web search: \(query)")
                            flushLog()
                            let output = await Self.performTavilySearch(query: query, apiKey: tavilyAPIKey)
                            appendLog(Self.preview(output, lines: 5))
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }
                    }
                }

                // Add assistant response to conversation
                messages.append(["role": "assistant", "content": response.content])

                if hasToolUse && !toolResults.isEmpty {
                    messages.append(["role": "user", "content": toolResults])
                    consecutiveNoTool = 0
                } else if hasToolUse && toolResults.isEmpty {
                    // Server-side tools only (web search) — no client results needed
                    consecutiveNoTool = 0
                    messages.append(["role": "user", "content": "Continue with the task. Call task_complete when finished."])
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

        if iterations >= maxIterations {
            appendLog("Reached maximum iterations (\(maxIterations))")
        }

        // Always save history if task didn't call task_complete
        if completionSummary.isEmpty {
            let summary = Task.isCancelled ? "(cancelled)" : commandsRun.isEmpty ? "(no actions)" : "(incomplete)"
            history.add(TaskRecord(prompt: prompt, summary: summary, commandsRun: commandsRun), maxBeforeSummary: maxHistoryBeforeSummary, apiKey: apiKey, model: selectedModel)
        }

        // End the task in SwiftData chat history
        ChatHistoryStore.shared.endCurrentTask(summary: completionSummary.isEmpty ? nil : completionSummary, cancelled: Task.isCancelled)
        
        flushLog()
        persistLogNow()
        isRunning = false
        isThinking = false
        userServiceActive = false
        rootServiceActive = false
        userWasActive = false
        rootWasActive = false
    }

    // MARK: - Tavily Web Search

    nonisolated private static func performTavilySearch(query: String, apiKey: String) async -> String {
        guard !apiKey.isEmpty else {
            return "Error: Tavily API key not set. Add it in Settings."
        }

        guard let url = URL(string: "https://api.tavily.com/search") else {
            return "Error: Invalid Tavily URL"
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "query": query,
            "max_results": 5
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return "Error: Invalid response from Tavily"
            }

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                return "Error: Tavily API returned \(httpResponse.statusCode): \(errorBody)"
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                return "Error: Failed to parse Tavily response"
            }

            if results.isEmpty {
                return "No search results found for '\(query)'"
            }

            var output = ""
            for (i, result) in results.enumerated() {
                let title = result["title"] as? String ?? "Untitled"
                let resultUrl = result["url"] as? String ?? ""
                let content = result["content"] as? String ?? ""
                output += "\(i + 1). \(title)\n   \(resultUrl)\n   \(content)\n\n"
            }

            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}
