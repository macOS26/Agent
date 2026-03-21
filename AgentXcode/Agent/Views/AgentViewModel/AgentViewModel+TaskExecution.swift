
@preconcurrency import Foundation
import MCPClient

// MARK: - Task Execution

extension AgentViewModel {

    // MARK: - Native Tool Handler (Apple AI)

    /// Executes a tool call from Apple AI's Foundation Models native tool system.
    /// Routes to the same execution logic as TaskExecution tool handlers.
    func executeNativeTool(_ name: String, input: sending [String: Any]) async -> String {
        let pf = projectFolder
        NativeToolContext.toolCallCount += 1
        appendLog("🔧 \(name)")
        flushLog()

        // Prevent infinite tool call loops — force completion after max calls
        if name != "task_complete" && NativeToolContext.toolCallCount > NativeToolContext.maxToolCalls {
            NativeToolContext.taskCompleteSummary = "Stopped: too many tool calls"
            return "Error: too many tool calls. Call task_complete now."
        }

        // Shell commands
        if name == "execute_agent_command" || name == "execute_daemon_command" {
            let cmd = input["command"] as? String ?? ""
            let result = await executeViaUserAgent(command:
                Self.prependWorkingDirectory(cmd, projectFolder: pf))
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }

        // AppleScript (NSAppleScript in-process with TCC)
        if name == "run_applescript" {
            let source = (input["source"] as? String ?? "")
            let result = await MainActor.run { () -> (String, Bool) in
                var err: NSDictionary?
                guard let script = NSAppleScript(source: source) else { return ("Error", false) }
                let out = script.executeAndReturnError(&err)
                if let e = err { return ("AppleScript error: \(e)", false) }
                return (out.stringValue ?? "(no output)", true)
            }
            if result.1 {
                let _ = scriptService.saveAppleScript(name: Self.autoScriptName(from: source), source: source)
            }
            return result.0
        }

        // osascript (runs osascript CLI in-process with TCC)
        if name == "run_osascript" {
            let script = input["script"] as? String ?? input["command"] as? String ?? ""
            let escaped = script.replacingOccurrences(of: "'", with: "'\\''")
            let command = "osascript -e '\(escaped)'"
            let result = await executeLocalStreaming(command: command) { _ in }
            if result.status == 0 {
                let _ = scriptService.saveAppleScript(name: Self.autoScriptName(from: script), source: script)
            }
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }

        // JavaScript for Automation (JXA via osascript -l JavaScript)
        if name == "execute_javascript" {
            let script = input["source"] as? String ?? input["script"] as? String ?? ""
            let escaped = script.replacingOccurrences(of: "'", with: "'\\''")
            let command = "osascript -l JavaScript -e '\(escaped)'"
            let result = await executeLocalStreaming(command: command) { _ in }
            if result.status == 0 {
                let _ = scriptService.saveJavaScript(name: Self.autoScriptName(from: script), source: script)
            }
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }

        // Script management
        if name == "list_agent_scripts" {
            let scripts = scriptService.listScripts()
            return scripts.isEmpty ? "No scripts found" : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
        }
        if name == "run_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            guard let cmd = scriptService.compileCommand(name: scriptName) else {
                return "Error: script '\(scriptName)' not found"
            }
            var fullCmd = cmd
            if let args = input["arguments"] as? String {
                fullCmd = "AGENT_SCRIPT_ARGS='\(args)' \(cmd)"
            }
            let result = await executeViaUserAgent(command: fullCmd)
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }
        if name == "read_agent_script" {
            return scriptService.readScript(name: input["name"] as? String ?? "") ?? "Not found"
        }
        if name == "create_agent_script" || name == "update_agent_script" {
            return scriptService.createScript(name: input["name"] as? String ?? "", content: input["content"] as? String ?? "")
        }
        if name == "delete_agent_script" {
            return scriptService.deleteScript(name: input["name"] as? String ?? "")
        }

        // Saved AppleScripts
        if name == "list_apple_scripts" {
            let scripts = scriptService.listAppleScripts()
            return scripts.isEmpty ? "No saved AppleScripts" : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
        }
        if name == "save_apple_script" {
            return scriptService.saveAppleScript(name: input["name"] as? String ?? "", source: input["source"] as? String ?? "")
        }
        if name == "delete_apple_script" {
            return scriptService.deleteAppleScript(name: input["name"] as? String ?? "")
        }
        if name == "run_apple_script" {
            let scriptName = input["name"] as? String ?? ""
            guard let source = scriptService.readAppleScript(name: scriptName) else {
                return "Error: AppleScript '\(scriptName)' not found. Use list_apple_scripts first."
            }
            let result = await MainActor.run { () -> String in
                var err: NSDictionary?
                guard let script = NSAppleScript(source: source) else { return "Error creating script" }
                let out = script.executeAndReturnError(&err)
                if let e = err { return "AppleScript error: \(e)" }
                return out.stringValue ?? "(no output)"
            }
            return result
        }

        // Saved JavaScript/JXA
        if name == "list_javascript" {
            let scripts = scriptService.listJavaScripts()
            return scripts.isEmpty ? "No saved JXA scripts" : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
        }
        if name == "save_javascript" {
            return scriptService.saveJavaScript(name: input["name"] as? String ?? "", source: input["source"] as? String ?? "")
        }
        if name == "delete_javascript" {
            return scriptService.deleteJavaScript(name: input["name"] as? String ?? "")
        }
        if name == "run_javascript" {
            let scriptName = input["name"] as? String ?? ""
            guard let source = scriptService.readJavaScript(name: scriptName) else {
                return "Error: JXA script '\(scriptName)' not found. Use list_javascript first."
            }
            let escaped = source.replacingOccurrences(of: "'", with: "'\\''")
            let result = await executeLocalStreaming(command: "osascript -l JavaScript -e '\(escaped)'") { _ in }
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }

        // File operations
        if name == "read_file" {
            let path = input["file_path"] as? String ?? ""
            guard let data = FileManager.default.contents(atPath: path),
                  let content = String(data: data, encoding: .utf8) else { return "Error: cannot read \(path)" }
            return content
        }
        if name == "write_file" {
            let path = input["file_path"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            let url = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            do { try content.write(to: url, atomically: true, encoding: .utf8); return "Wrote \(path)" }
            catch { return "Error: \(error.localizedDescription)" }
        }
        if name == "edit_file" {
            let path = input["file_path"] as? String ?? ""
            let old = input["old_string"] as? String ?? ""
            let new = input["new_string"] as? String ?? ""
            let replaceAll = input["replace_all"] as? Bool ?? false
            
            guard old != new else { return "Error: old_string and new_string are identical - no changes needed" }
            
            guard let data = FileManager.default.contents(atPath: path),
                  let content = String(data: data, encoding: .utf8) else { return "Error: cannot read \(path)" }
            
            let occurrences = content.components(separatedBy: old).count - 1
            
            if occurrences == 0 {
                let trimmed = old.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && content.contains(trimmed) {
                    return "Error: old_string not found (exact match). A similar string exists in \(path) — check whitespace/indentation."
                }
                return "Error: old_string not found in \(path)"
            }
            
            if !replaceAll && occurrences > 1 {
                return "Error: old_string appears \(occurrences) times in \(path). Provide more context to make it unique, or set replace_all=true."
            }
            
            let updated: String
            if replaceAll {
                updated = content.replacingOccurrences(of: old, with: new)
            } else {
                guard let range = content.range(of: old) else { return "Error: old_string not found in \(path)" }
                updated = content.replacingCharacters(in: range, with: new)
            }
            
            do {
                try updated.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
                // Build unified diff with more context (up to 10 lines each side)
                let oldLines = old.components(separatedBy: "\n")
                let newLines = new.components(separatedBy: "\n")
                var diffOutput = "Replaced \(replaceAll ? "\(occurrences) occurrences" : "1 occurrence") in \(path)\n\nDiff:\n```diff\n"
                if oldLines.count <= 10 {
                    for line in oldLines { diffOutput += "- \(line)\n" }
                } else {
                    for line in oldLines.prefix(10) { diffOutput += "- \(line)\n" }
                    diffOutput += "- ... (\(oldLines.count) lines total)\n"
                }
                if newLines.count <= 10 {
                    for line in newLines { diffOutput += "+ \(line)\n" }
                } else {
                    for line in newLines.prefix(10) { diffOutput += "+ \(line)\n" }
                    diffOutput += "+ ... (\(newLines.count) lines total)\n"
                }
                diffOutput += "```"
                return diffOutput
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }

        // Git (via shell)
        if name.hasPrefix("git_") {
            let dir = (input["path"] as? String ?? pf).isEmpty ? pf : (input["path"] as? String ?? pf)
            let esc = dir.isEmpty ? "." : "'\(dir)'"
            var cmd = "cd \(esc) && "
            switch name {
            case "git_status": cmd += "git status"
            case "git_log": cmd += "git log --oneline -\(input["count"] as? Int ?? 20)"
            case "git_diff":
                cmd += "git diff"
                if input["staged"] as? Bool == true { cmd += " --staged" }
                if let target = input["target"] as? String { cmd += " \(target)" }
            case "git_commit": cmd += "git add -A && git commit -m '\(input["message"] as? String ?? "update")'"
            case "git_branch": cmd += "git branch -a"
            case "git_diff_patch": cmd += "git diff"
            default: cmd += "git \(name.replacingOccurrences(of: "git_", with: ""))"
            }
            let result = await executeViaUserAgent(command: cmd)
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }

        // List/search files (via shell)
        if name == "list_files" {
            let pat = input["pattern"] as? String ?? "*"
            let dir = input["path"] as? String ?? pf
            let result = await executeViaUserAgent(command: "find '\(dir)' -name '\(pat)' ! -path '*/.build/*' ! -path '*/.git/*' 2>/dev/null | sort | head -100")
            return result.output.isEmpty ? "No files found" : result.output
        }
        if name == "search_files" {
            let pat = input["pattern"] as? String ?? ""
            let dir = input["path"] as? String ?? pf
            let result = await executeViaUserAgent(command: "grep -rn '\(pat)' '\(dir)' 2>/dev/null | head -50")
            return result.output.isEmpty ? "No matches" : result.output
        }

        // Tool discovery
        if name == "list_native_tools" {
            let prefs = ToolPreferencesService.shared
            return AgentTools.tools(for: selectedProvider)
                .filter { prefs.isEnabled(selectedProvider, $0.name) }
                .sorted { $0.name < $1.name }
                .map { $0.name }
                .joined(separator: "\n")
        }
        if name == "list_mcp_tools" {
            let mcp = MCPService.shared
            let enabled = mcp.discoveredTools.filter { mcp.isToolEnabled(serverName: $0.serverName, toolName: $0.name) }
            return enabled.isEmpty ? "No MCP tools enabled" : enabled.map { "mcp_\($0.serverName)_\($0.name)" }.joined(separator: "\n")
        }

        // Apple Event query
        if name == "apple_event_query" {
            let bundleID = input["bundle_id"] as? String ?? ""
            let operations = input["operations"] as? [[String: Any]] ?? []
            let opsData = try? JSONSerialization.data(withJSONObject: operations)
            return await Self.offMain {
                guard let data = opsData,
                      let ops = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    return "Error: failed to process operations"
                }
                return AppleEventService.shared.execute(bundleID: bundleID, operations: ops)
            }
        }

        // Task complete — signal via NativeToolContext so the task loop can detect it
        if name == "task_complete" {
            let summary = input["summary"] as? String ?? "Done"
            NativeToolContext.taskCompleteSummary = summary
            return "Task complete: \(summary)"
        }

        // MARK: - Web Automation (Phase 2) for Apple AI

        // web_open
        if name == "web_open" {
            guard let urlString = input["url"] as? String,
                  let url = URL(string: urlString) else {
                return "Error: Invalid or missing URL"
            }
            let browserStr = input["browser"] as? String ?? "safari"
            let browser = WebAutomationService.BrowserType(rawValue: browserStr) ?? .safari
            do {
                return try await WebAutomationService.shared.open(url: url, browser: browser)
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }

        // web_find
        if name == "web_find" {
            let selector = input["selector"] as? String ?? ""
            let strategyStr = input["strategy"] as? String ?? "auto"
            let strategy = SelectorStrategy(rawValue: strategyStr) ?? .auto
            let timeout = input["timeout"] as? Double ?? 10.0
            let fuzzyThreshold = input["fuzzyThreshold"] as? Double ?? 0.6
            let appBundleId = input["appBundleId"] as? String
            do {
                let output = try await WebAutomationService.shared.findElement(
                    selector: selector, strategy: strategy, timeout: timeout,
                    fuzzyThreshold: fuzzyThreshold, appBundleId: appBundleId
                )
                if let jsonData = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
                   let jsonStr = String(data: jsonData, encoding: .utf8) {
                    return jsonStr
                }
                return "Found element: \(output)"
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }

        // web_click
        if name == "web_click" {
            let selector = input["selector"] as? String ?? ""
            let strategyStr = input["strategy"] as? String ?? "auto"
            let strategy = SelectorStrategy(rawValue: strategyStr) ?? .auto
            let appBundleId = input["appBundleId"] as? String
            do {
                return try await WebAutomationService.shared.click(
                    selector: selector, strategy: strategy, appBundleId: appBundleId
                )
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }

        // web_type
        if name == "web_type" {
            let selector = input["selector"] as? String ?? ""
            let text = input["text"] as? String ?? ""
            let strategyStr = input["strategy"] as? String ?? "auto"
            let strategy = SelectorStrategy(rawValue: strategyStr) ?? .auto
            let verify = input["verify"] as? Bool ?? true
            let appBundleId = input["appBundleId"] as? String
            do {
                return try await WebAutomationService.shared.type(
                    text: text, selector: selector, strategy: strategy, verify: verify, appBundleId: appBundleId
                )
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }

        // web_execute_js
        if name == "web_execute_js" {
            let script = input["script"] as? String ?? ""
            let browser = input["browser"] as? String
            do {
                let result = try await WebAutomationService.shared.executeJavaScript(script: script, browser: browser)
                return result as? String ?? "Script executed"
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }

        // web_get_url / web_get_title (via Selenium AgentScript)
        if name == "web_get_url" || name == "web_get_title" {
            let action = name == "web_get_url" ? "getUrl" : "getTitle"
            let args = "{\"action\":\"\(action)\"}"
            // Run Selenium via compile and execute
            guard let compileCmd = scriptService.compileCommand(name: "Selenium") else {
                return "Error: Selenium script not found"
            }
            let compileResult = await executeLocal(command: compileCmd)
            if compileResult.status != 0 {
                return "Compile failed: \(compileResult.output)"
            }
            let result = await scriptService.loadAndRunScript(name: "Selenium", arguments: args, captureStderr: false, isCancelled: nil) { _ in }
            return result.output
        }

        // MARK: - Selenium WebDriver for Apple AI (via AgentScript)

        // Helper for Selenium operations
        func runSeleniumNative(action: String, args: String) async -> String {
            let fullArgs = args.isEmpty ? "{\"action\":\"\(action)\"}" : args
            guard let compileCmd = scriptService.compileCommand(name: "Selenium") else {
                return "Error: Selenium script not found"
            }
            let compileResult = await executeLocal(command: compileCmd)
            if compileResult.status != 0 {
                return "Compile failed: \(compileResult.output)"
            }
            let result = await scriptService.loadAndRunScript(name: "Selenium", arguments: fullArgs, captureStderr: false, isCancelled: nil) { _ in }
            return result.output
        }

        // selenium_start
        if name == "selenium_start" {
            let browser = input["browser"] as? String ?? "safari"
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"start\",\"browser\":\"\(browser)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "start", args: args)
        }

        // selenium_stop
        if name == "selenium_stop" {
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"stop\",\"port\":\(port)}"
            return await runSeleniumNative(action: "stop", args: args)
        }

        // selenium_navigate
        if name == "selenium_navigate" {
            guard let url = input["url"] as? String else { return "Error: URL required" }
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"navigate\",\"url\":\"\(url)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "navigate", args: args)
        }

        // selenium_find
        if name == "selenium_find" {
            let strategy = input["strategy"] as? String ?? "css"
            let value = input["value"] as? String ?? ""
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"find\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "find", args: args)
        }

        // selenium_click
        if name == "selenium_click" {
            let strategy = input["strategy"] as? String ?? "css"
            let value = input["value"] as? String ?? ""
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"click\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "click", args: args)
        }

        // selenium_type
        if name == "selenium_type" {
            let strategy = input["strategy"] as? String ?? "css"
            let value = input["value"] as? String ?? ""
            let text = input["text"] as? String ?? ""
            let port = input["port"] as? Int ?? 7055
            let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let args = "{\"action\":\"type\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"text\":\"\(escapedText)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "type", args: args)
        }

        // selenium_execute
        if name == "selenium_execute" {
            let script = input["script"] as? String ?? ""
            let port = input["port"] as? Int ?? 7055
            let escapedScript = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let args = "{\"action\":\"execute\",\"script\":\"\(escapedScript)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "execute", args: args)
        }

        // selenium_screenshot
        if name == "selenium_screenshot" {
            let filename = input["filename"] as? String ?? "selenium_\(Int(Date().timeIntervalSince1970)).png"
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"screenshot\",\"filename\":\"\(filename)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "screenshot", args: args)
        }

        // selenium_wait
        if name == "selenium_wait" {
            let strategy = input["strategy"] as? String ?? "css"
            let value = input["value"] as? String ?? ""
            let timeout = input["timeout"] as? Double ?? 10.0
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"waitFor\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"timeout\":\(timeout),\"port\":\(port)}"
            return await runSeleniumNative(action: "waitFor", args: args)
        }

        // Fallback
        return "Tool \(name) not implemented for Apple AI"
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

        // Start progress updates for iMessage requests (every 10 minutes)
        if agentReplyHandle != nil {
            startProgressUpdates(for: prompt)
        }

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
                } else if let openAICompatible {
                    response = try await openAICompatible.sendStreaming(messages: messages) { [weak self] delta in
                        Task { @MainActor in
                            self?.isThinking = false
                            self?.appendStreamDelta(delta)
                        }
                    }
                    textWasStreamed = true
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
                            // Stop progress updates before sending final reply
                            stopProgressUpdates()
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
                                        Self.toJSONValue(value)
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

                            // Capture pre-edit content to find match line number
                            let expandedPath = (filePath as NSString).expandingTildeInPath
                            let preContent = (try? String(contentsOfFile: expandedPath, encoding: .utf8)) ?? ""
                            let preLines = preContent.components(separatedBy: "\n")
                            var matchLineStart: Int? = nil
                            if let matchRange = preContent.range(of: oldString) {
                                let before = preContent[preContent.startIndex..<matchRange.lowerBound]
                                matchLineStart = before.components(separatedBy: "\n").count // 1-based
                            }

                            let output = await Self.offMain { CodingService.editFile(path: filePath, oldString: oldString, newString: newString, replaceAll: replaceAll) }

                            // Show diff with line numbers and context if edit succeeded
                            if output.hasPrefix("Replaced"), let startLine = matchLineStart {
                                let oldLines = oldString.components(separatedBy: "\n")
                                let newLines = newString.components(separatedBy: "\n")
                                let postContent = (try? String(contentsOfFile: expandedPath, encoding: .utf8)) ?? ""
                                let postLines = postContent.components(separatedBy: "\n")
                                let ctx = 3

                                var diffOutput = "```diff\n"
                                // Context before
                                let ctxStart = max(0, startLine - 1 - ctx)
                                for i in ctxStart..<(startLine - 1) {
                                    diffOutput += "\(i + 1)\t\(preLines[i])\n"
                                }
                                // Removed lines
                                for (i, line) in oldLines.enumerated() {
                                    diffOutput += "\(startLine + i) -\t\(line)\n"
                                }
                                // Added lines
                                for (i, line) in newLines.enumerated() {
                                    diffOutput += "\(startLine + i) +\t\(line)\n"
                                }
                                // Context after
                                let afterStart = startLine - 1 + newLines.count
                                let afterEnd = min(postLines.count, afterStart + ctx)
                                for i in afterStart..<afterEnd {
                                    diffOutput += "\(i + 1)\t\(postLines[i])\n"
                                }
                                diffOutput += "```"
                                appendLog(diffOutput)
                            } else if !output.hasPrefix("Replaced") {
                                // Edit failed — show what was attempted
                                var diffOutput = "```diff\n"
                                for line in oldString.components(separatedBy: "\n") {
                                    diffOutput += "- \(line)\n"
                                }
                                for line in newString.components(separatedBy: "\n") {
                                    diffOutput += "+ \(line)\n"
                                }
                                diffOutput += "```"
                                appendLog(diffOutput)
                            }
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
                                rootServiceActive = true
                                rootWasActive = true
                                helperService.onOutput = { [weak self] chunk in
                                    self?.appendRawOutput(chunk)
                                }
                                result = await helperService.execute(command: command)
                                helperService.onOutput = nil
                                rootServiceActive = false
                            } else if Self.needsTCCTab(command) {
                                // Run TCC commands directly in the Agent app process
                                // so they inherit the app's Automation permissions
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
                        if name == "list_native_tools" {
                            let prefs = ToolPreferencesService.shared
                            let enabled = AgentTools.tools(for: selectedProvider)
                                .filter { prefs.isEnabled(selectedProvider, $0.name) }
                                .sorted(by: { $0.name < $1.name })
                            let output = enabled.map { $0.name }.joined(separator: "\n")
                            appendLog("🔧 Native tools: \(enabled.count) enabled")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                        }

                        if name == "list_mcp_tools" {
                            let mcpService = MCPService.shared
                            let enabled = mcpService.discoveredTools
                                .filter { mcpService.isToolEnabled(serverName: $0.serverName, toolName: $0.name) }
                                .sorted(by: { $0.name < $1.name })
                            if enabled.isEmpty {
                                let output = "No MCP tools enabled."
                                appendLog("🔧 MCP tools: 0")
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                            } else {
                                let output = enabled.map { "mcp_\($0.serverName)_\($0.name)" }.joined(separator: "\n")
                                appendLog("🔧 MCP tools: \(enabled.count) enabled")
                                toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": output])
                            }
                        }

                        // Script management tools
                        if name == "list_agent_scripts" {
                            let scripts = scriptService.listScripts()
                            let output: String
                            if scripts.isEmpty {
                                output = "No scripts found in ~/Documents/AgentScript/agents/"
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

                            let result = await executeLocalStreaming(command: command) { [weak tab] chunk in
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

                            let result = await executeLocalStreaming(command: command) { [weak tab] chunk in
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

                            let result = await executeLocalStreaming(command: command) { [weak tab] chunk in
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

                        // Dynamic Apple Event query tool
                        if name == "apple_event_query" {
                            let bundleID = input["bundle_id"] as? String ?? ""
                            let operations = input["operations"] as? [[String: Any]] ?? []
                            let opsPreview = operations.compactMap { op -> String? in
                                let action = op["action"] as? String ?? "?"
                                let key = op["key"] as? String ?? op["method"] as? String ?? op["properties"].flatMap { "\($0)" } ?? ""
                                return key.isEmpty ? action : "\(action) \(key)"
                            }.joined(separator: " → ")
                            appendLog("🍎 AE query: \(bundleID) → \(opsPreview)")
                            flushLog()
                            let opsData = try? JSONSerialization.data(withJSONObject: operations)
                            let output = await Self.offMain {
                                guard let data = opsData,
                                      let ops = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                                    return "Error: failed to process operations"
                                }
                                return AppleEventService.shared.execute(
                                    bundleID: bundleID, operations: ops
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
                // Guard against empty content — Ollama rejects assistant messages with no content or tool_calls
                let assistantContent: Any = response.content.isEmpty
                    ? "I'll continue with the task." as Any
                    : response.content as Any
                messages.append(["role": "assistant", "content": assistantContent])

                if hasToolUse && !toolResults.isEmpty {
                    messages.append(["role": "user", "content": toolResults])
                    consecutiveNoTool = 0
                } else if hasToolUse && toolResults.isEmpty {
                    // Server-side tools only (web search) — no client results needed
                    consecutiveNoTool = 0
                    messages.append(["role": "user", "content": "Continue with the task. Call task_complete when finished."])
                } else if !hasToolUse {
                    consecutiveNoTool += 1
                    // Give models up to 3 nudges to use tools before giving up
                    if consecutiveNoTool >= 3 {
                        appendLog("(model not using tools — stopping)")
                        break
                    }
                    messages.append(["role": "user", "content": "Continue. You must use execute_agent_command or execute_daemon_command tools to perform actions. Call task_complete when finished."])
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
