import Foundation

extension AgentViewModel {
    // MARK: - Native Tool Handler (Apple AI)
    /// Executes a tool call from Apple AI's Foundation Models native tool system.
    /// Routes to the same execution logic as TaskExecution tool handlers.
    func executeNativeTool(_ rawName: String, input rawInput: sending [String: Any]) async -> String {
        // Expand consolidated CRUDL tools into legacy tool names
        let (name, input) = Self.expandConsolidatedTool(name: rawName, input: rawInput)
        let pf = projectFolder
        NativeToolContext.toolCallCount += 1
        appendLog("🔧 \(name)")
        flushLog()

        // Prevent infinite tool call loops — force completion after max calls
        if name != "task_complete" && NativeToolContext.toolCallCount > NativeToolContext.maxToolCalls {
            NativeToolContext.taskCompleteSummary = "Stopped: too many tool calls"
            return "Error: too many tool calls. Call task_complete now."
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
            let result = await Self.executeTCCStreaming(command: command) { _ in }
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
            let result = await Self.executeTCCStreaming(command: command) { _ in }
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
            let result = await Self.executeTCC(command: fullCmd)
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
        if name == "combine_agent_scripts" {
            let sourceA = input["source_a"] as? String ?? ""
            let sourceB = input["source_b"] as? String ?? ""
            let target = input["target"] as? String ?? ""
            guard let contentA = scriptService.readScript(name: sourceA) else { return "Error: script '\(sourceA)' not found." }
            guard let contentB = scriptService.readScript(name: sourceB) else { return "Error: script '\(sourceB)' not found." }
            let merged = Self.combineScriptSources(contentA: contentA, contentB: contentB, sourceA: sourceA, sourceB: sourceB)
            if scriptService.readScript(name: target) != nil {
                return scriptService.updateScript(name: target, content: merged)
            } else {
                return scriptService.createScript(name: target, content: merged)
            }
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
            let result = await Self.executeTCCStreaming(command: "osascript -l JavaScript -e '\(escaped)'") { _ in }
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }

        // File operations
        if name == "read_file" {
            let path = input["file_path"] as? String ?? ""
            guard let data = FileManager.default.contents(atPath: path),
                  let content = String(data: data, encoding: .utf8) else { return "Error: cannot read \(path)" }
            let lines = content.components(separatedBy: "\n")
            if lines.count > 100 && input["offset"] == nil && input["limit"] == nil {
                return lines.prefix(100).joined(separator: "\n") + "\n\n--- FILE HAS \(lines.count) LINES (showing first 100) ---\nUse read_file with offset and limit for specific sections."
            }
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
                let diff = MultiLineDiff.createDiff(source: old, destination: new, includeMetadata: true)
                var d1f = MultiLineDiff.displayDiff(diff: diff, source: old, format: .ai)
                if d1f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    d1f = "❌ " + old + "\n" + "✅ " + new
                }
                let label = replaceAll ? "\(occurrences) occurrences" : "1 occurrence"
                var result = "Replaced \(label) in \(path)\n\n\(d1f)"
                if let meta = diff.metadata {
                    if let startLine = meta.sourceStartLine {
                        result += "\n📍 Changes start at line \(startLine + 1)"
                    }
                    if let total = meta.sourceTotalLines {
                        result += " (of \(total) lines)"
                    }
                }
                return result
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }

        // D1F Diff
        if name == "create_diff" {
            let source = input["source"] as? String ?? ""
            let destination = input["destination"] as? String ?? ""
            let diff = MultiLineDiff.createDiff(source: source, destination: destination, includeMetadata: true)
            let d1f = MultiLineDiff.displayDiff(diff: diff, source: source, format: .ai)
            var result = d1f
            if let meta = diff.metadata {
                result += "\n\n" + MultiLineDiff.generateDiffSummary(source: source, destination: destination)
                if let startLine = meta.sourceStartLine {
                    result += "\n📍 Changes start at line \(startLine + 1)"
                }
            }
            return result
        }

        // D1F Apply ASCII Diff
        if name == "apply_diff" {
            let path = input["file_path"] as? String ?? ""
            let asciiDiff = input["diff"] as? String ?? ""
            guard let data = FileManager.default.contents(atPath: path),
                  let source = String(data: data, encoding: .utf8) else { return "Error: cannot read \(path)" }
            do {
                let patched = try MultiLineDiff.applyASCIIDiff(to: source, asciiDiff: asciiDiff)
                try patched.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
                let verifyDiff = MultiLineDiff.createAndDisplayDiff(source: source, destination: patched, format: .ai)
                return "Applied diff to \(path)\n\n\(verifyDiff)"
            } catch {
                return "Error applying diff: \(error.localizedDescription)"
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
            // Git tools use User LaunchAgent (no TCC required)
            let result = await executeViaUserAgent(command: cmd)
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }

        // List/search files (via User LaunchAgent - no TCC required)
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
        if name == "read_dir" {
            let dir = input["path"] as? String ?? pf
            let result = await executeViaUserAgent(command: "ls -la '\(dir)' 2>/dev/null")
            return result.output.isEmpty ? "Directory not found or empty" : result.output
        }
        if name == "split_file" {
            let filePath = input["file_path"] as? String ?? ""
            let deleteOriginal = input["delete_original"] as? Bool ?? false
            let mode = input["mode"] as? String ?? "declarations"
            return await Self.offMain { CodingService.splitFile(path: filePath, deleteOriginal: deleteOriginal, mode: mode) }
        }

        // Tool discovery
        if name == "list_tools" {
            let prefs = ToolPreferencesService.shared
            let builtIn = AgentTools.tools(for: selectedProvider)
                .filter { prefs.isEnabled(selectedProvider, $0.name) }
                .sorted { $0.name < $1.name }
                .map { $0.name }
            let mcp = MCPService.shared
            let mcpTools = mcp.discoveredTools
                .filter { mcp.isToolEnabled(serverName: $0.serverName, toolName: $0.name) }
                .sorted { $0.name < $1.name }
                .map { "mcp_\($0.serverName)_\($0.name)" }
            let all = builtIn + (mcpTools.isEmpty ? [] : ["--- MCP Tools ---"] + mcpTools)
            return all.joined(separator: "\n")
        }

        // Apple Event query — flat keys wrapped into single operation
        if name == "apple_event_query" {
            let bundleID = input["bundle_id"] as? String ?? ""
            let operations: [[String: Any]]
            if let ops = input["operations"] as? [[String: Any]] {
                operations = ops // legacy nested format still works
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
                return "Error: action is required"
            }
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
            let compileResult = await Self.executeTCC(command: compileCmd)
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
            let compileResult = await Self.executeTCC(command: compileCmd)
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

        // MARK: - Conversation Tools (Phase 1)
        
        // write_text
        if name == "write_text" {
            guard let subject = input["subject"] as? String, !subject.isEmpty else {
                return "Error: subject is required for write_text"
            }
            
            let style = input["style"] as? String ?? "informative"
            let lengthStr = input["length"] as? String ?? "medium"
            let context = input["context"] as? String ?? ""
            
            // Parse length
            let targetWords: Int
            if let exactWords = Int(lengthStr) {
                targetWords = exactWords
            } else {
                switch lengthStr.lowercased() {
                case "short": targetWords = 100
                case "medium": targetWords = 300
                case "long": targetWords = 600
                default: targetWords = 300
                }
            }
            
            // Build guidance for text generation
            let guidance = """
            Generate \(style) text about "\(subject)" in approximately \(targetWords) words.
            
            Style: \(style)
            \(context.isEmpty ? "" : "Context: \(context)")
            
            Requirements:
            - No emojis - plain text only
            - Well-structured paragraphs
            - Clear and engaging writing
            - Accurate and informative content
            
            Begin your response directly with the text content.
            """
            
            return guidance
        }
        
        // transform_text
        if name == "transform_text" {
            guard let text = input["text"] as? String, !text.isEmpty else {
                return "Error: text is required for transform_text"
            }
            
            guard let transform = input["transform"] as? String, !transform.isEmpty else {
                return "Error: transform type is required for transform_text"
            }
            
            let options = input["options"] as? String ?? ""
            
            // Validate transform type
            let validTransforms = ["grocery_list", "todo_list", "outline", "summary", "bullet_points", "numbered_list", "table", "qa"]
            guard validTransforms.contains(transform.lowercased()) else {
                return "Error: invalid transform type. Valid types: \(validTransforms.joined(separator: ", "))"
            }
            
            let guidance: String
            
            switch transform.lowercased() {
            case "grocery_list":
                guidance = """
                Transform the following text into a grocery list format.
                
                Original text:
                \(text)
                \(options.isEmpty ? "" : "Options: \(options)")
                
                Requirements:
                - Extract all items that could be grocery/shopping items
                - Format as a clean grocery list organized by category (produce, dairy, meat, pantry, etc.)
                - One item per line
                - No emojis - plain text only
                - Include quantities if mentioned
                
                Output the grocery list now:
                """
                
            case "todo_list":
                guidance = """
                Transform the following text into a todo/checklist format.
                
                Original text:
                \(text)
                \(options.isEmpty ? "" : "Options: \(options)")
                
                Requirements:
                - Extract all actionable tasks
                - Format as a numbered or bulleted todo list
                - Each item should start with a verb (Buy, Call, Fix, etc.)
                - Group related tasks if possible
                - No emojis - plain text only
                
                Output the todo list now:
                """
                
            case "outline":
                guidance = """
                Transform the following text into a structured outline.
                
                Original text:
                \(text)
                \(options.isEmpty ? "" : "Options: \(options)")
                
                Requirements:
                - Create hierarchical outline with main topics and subtopics
                - Use Roman numerals (I, II, III) for main sections
                - Use letters (A, B, C) for subsections
                - Use numbers (1, 2, 3) for details
                - No emojis - plain text only
                
                Output the outline now:
                """
                
            case "summary":
                guidance = """
                Summarize the following text concisely.
                
                Original text:
                \(text)
                \(options.isEmpty ? "" : "Options: \(options)")
                
                Requirements:
                - Capture key points in brief
                - Keep summary to about 20% of original length
                - Maintain essential information
                - No emojis - plain text only
                
                Output the summary now:
                """
                
            case "bullet_points":
                guidance = """
                Transform the following text into bullet points.
                
                Original text:
                \(text)
                \(options.isEmpty ? "" : "Options: \(options)")
                
                Requirements:
                - Extract key points as individual bullets
                - Use hyphens (-) for bullet points
                - Keep each point concise
                - No emojis - plain text only
                
                Output the bullet points now:
                """
                
            case "numbered_list":
                guidance = """
                Transform the following text into a numbered list.
                
                Original text:
                \(text)
                \(options.isEmpty ? "" : "Options: \(options)")
                
                Requirements:
                - Extract items as a numbered sequence
                - Use 1., 2., 3. format
                - Maintain logical order
                - No emojis - plain text only
                
                Output the numbered list now:
                """
                
            case "table":
                guidance = """
                Transform the following text into a table format.
                
                Original text:
                \(text)
                \(options.isEmpty ? "" : "Options: \(options)")
                
                Requirements:
                - Organize information into columns
                - Use pipe (|) separators for table format
                - Include header row
                - No emojis - plain text only
                
                Output the table now:
                """
                
            case "qa":
                guidance = """
                Transform the following text into Q&A format.
                
                Original text:
                \(text)
                \(options.isEmpty ? "" : "Options: \(options)")
                
                Requirements:
                - Generate relevant questions from the content
                - Provide clear answers
                - Format as Q: question, A: answer pairs
                - No emojis - plain text only
                
                Output the Q&A now:
                """
                
            default:
                guidance = "Transform this text: \(text)"
            }
            
            return guidance
        }
        
        // send_message
        if name == "send_message" {
            guard let content = input["content"] as? String, !content.isEmpty else {
                return "Error: content is required for send_message"
            }
            
            guard let recipient = input["recipient"] as? String, !recipient.isEmpty else {
                return "Error: recipient is required for send_message"
            }
            
            let channel = input["channel"] as? String ?? "imessage"
            let subject = input["subject"] as? String ?? ""
            
            // Ensure no emojis in content (simple emoji removal)
            let cleanContent = content.unicodeScalars.filter { !isEmoji($0) }.map(String.init).joined()
            
            // Handle different channels
            switch channel.lowercased() {
            case "clipboard":
                // Copy to clipboard
                await MainActor.run {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(cleanContent, forType: .string)
                }
                return "Message copied to clipboard:\n\(cleanContent)"
                
            case "imessage":
                // Use AppleScript to send iMessage (simplified version)
                let escapedRecipient = recipient.replacingOccurrences(of: "\"", with: "\\\"")
                let escapedContent = cleanContent.replacingOccurrences(of: "\"", with: "\\\"")
                
                let script = """
                tell application "Messages"
                    send "\(escapedContent)" to buddy "\(escapedRecipient)"
                end tell
                """
                
                let result = await MainActor.run { () -> String in
                    var err: NSDictionary?
                    guard let applescript = NSAppleScript(source: script) else {
                        return "Error: Failed to create AppleScript"
                    }
                    let _ = applescript.executeAndReturnError(&err)
                    if let e = err {
                        return "AppleScript error: \(e)"
                    }
                    return "iMessage sent to \(recipient)"
                }
                return result
                
            case "email":
                // Open mailto URL
                let escapedSubject = subject.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
                let escapedBody = cleanContent.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
                let mailtoURL: String
                
                if recipient.lowercased() == "me" {
                    mailtoURL = "mailto:?subject=\(escapedSubject)&body=\(escapedBody)"
                } else {
                    let escapedRecipient = recipient.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? recipient
                    mailtoURL = "mailto:\(escapedRecipient)?subject=\(escapedSubject)&body=\(escapedBody)"
                }
                
                await MainActor.run {
                    if let url = URL(string: mailtoURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                return "Email draft opened for \(recipient)"
                
            case "sms":
                // Open SMS URL scheme
                let escapedBody = cleanContent.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
                let smsURL = "sms:\(recipient)?body=\(escapedBody)"
                
                await MainActor.run {
                    if let url = URL(string: smsURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                return "SMS draft opened for \(recipient)"
                
            default:
                return "Error: Unsupported channel '\(channel)'. Use: imessage, email, sms, or clipboard"
            }
        }
        
        // about_self
        if name == "about_self" {
            let topic = input["topic"] as? String ?? "all"
            let detail = input["detail"] as? String ?? "standard"
            
            let detailPrefix = detail == "brief" ? "Brief" : detail == "detailed" ? "Detailed" : ""
            
            let aboutText: String
            
            switch topic.lowercased() {
            case "tools":
                aboutText = """
                \(detailPrefix) Agent! Tools Overview
                
                Agent! provides powerful automation tools for macOS:
                
                FILE & CODING TOOLS:
                - read_file, write_file, edit_file: Read, create, and modify files
                - create_diff, apply_diff: Compare and patch text with visual diffs
                - list_files, search_files: Find files by pattern or content
                - git_status, git_diff, git_log, git_commit: Git version control
                
                AUTOMATION TOOLS:
                - run_applescript, run_osascript: Execute AppleScript with full TCC permissions
                - execute_javascript: JavaScript for Automation (JXA)
                - apple_event_query: Query scriptable apps via Apple Events
                - run_agent_script: Compile and run Swift automation scripts
                
                ACCESSIBILITY TOOLS:
                - ax_click, ax_type_text, ax_press_key: Simulate user input
                - ax_find_element, ax_wait_for_element: Find UI elements
                - ax_screenshot: Capture screen regions or windows
                
                XCODE TOOLS:
                - xcode_build, xcode_run: Build and run Xcode projects
                - xcode_list_projects, xcode_select_project: Manage open projects
                
                WEB AUTOMATION:
                - web_open, web_find, web_click, web_type: Browser automation
                - selenium_start, selenium_navigate: Selenium WebDriver support
                
                CONVERSATION TOOLS:
                - write_text: Generate prose about any subject
                - transform_text: Convert text to lists, outlines, summaries
                - send_message: Send content via iMessage, email, SMS
                - fix_text: Correct spelling and grammar
                - about_self: Learn about Agent's capabilities
                
                Use list_tools to see all available tools.
                """
                
            case "features":
                aboutText = """
                \(detailPrefix) Agent! Features
                
                CORE FEATURES:
                - Multi-provider LLM support (Claude, OpenAI, Ollama, Apple Intelligence)
                - Streaming output with real-time display
                - Task history with AI-powered summarization
                - Chat history management with persistence
                - Screenshot and image attachment support
                
                AUTOMATION FEATURES:
                - Full TCC permissions (Accessibility, Automation, Screen Recording)
                - ScriptingBridge integration for app control
                - MCP (Model Context Protocol) server support
                - Reusable AgentScripts for complex automation
                
                DEVELOPER FEATURES:
                - Xcode project building and running
                - Git integration for version control
                - Code editing with diff visualization
                - Swift script compilation and execution
                
                UI FEATURES:
                - Native macOS design with split-pane interface
                - Conversation history with task tracking
                - Tab-based workflow for multiple tasks
                - Keyboard shortcuts for efficiency
                
                PRIVACY:
                - All automation runs locally on your Mac
                - API keys stored securely in Keychain
                - No data collection or telemetry
                """
                
            case "scripting":
                aboutText = """
                \(detailPrefix) Agent! Scripting Guide
                
                SWIFT AGENTSCRIPTS:
                Agent! can compile and run Swift scripts with full TCC permissions.
                Scripts are stored in ~/Documents/AgentScript/agents/
                
                Script template:
                ```swift
                
                @_cdecl("script_main")
                public func scriptMain() -> Int32 {
                    // Your automation code here
                    print("Hello from AgentScript!")
                    return 0
                }
                ```
                
                Rules:
                - Use @_cdecl("script_main") and return Int32
                - No exit() calls or top-level code
                - Access arguments via AGENT_SCRIPT_ARGS environment variable
                - Or use JSON files: ~/Documents/AgentScript/json/{Name}_input.json
                
                APPLESCRIPT:
                Save reusable scripts with save_apple_script
                Run saved scripts with run_apple_script
                Or execute directly with run_applescript
                
                JXA (JAVASCRIPT FOR AUTOMATION):
                Execute JavaScript with execute_javascript
                Save reusable scripts with save_javascript
                
                SCRIPTINGBRIDGE:
                Use lookup_sdef to read app dictionaries
                Create Swift bridges with GenerateBridge script
                Query apps with apple_event_query
                """
                
            case "automation":
                aboutText = """
                \(detailPrefix) Agent! Automation Capabilities
                
                APP CONTROL:
                Agent! can control macOS apps using:
                - AppleScript (run_applescript, run_osascript)
                - JavaScript for Automation (execute_javascript)
                - ScriptingBridge (via AgentScripts)
                - Apple Events (apple_event_query)
                - Accessibility API (ax_* tools)
                
                ACCESSIBILITY AUTOMATION:
                Full UI automation via Accessibility API:
                - Find elements by role, title, or value
                - Click, type, scroll, and drag
                - Wait for elements to appear
                - Highlight elements for verification
                - Take screenshots
                
                WEB AUTOMATION:
                - Safari/Chrome/Firefox control via AppleScript
                - Selenium WebDriver support
                - Element finding by CSS, XPath, or accessibility
                - Form filling and navigation
                
                SCHEDULED TASKS:
                Create LaunchAgents/LaunchDaemons for recurring automation
                Use cron or launchd for scheduling
                
                SECURITY:
                All automation inherits Agent!'s TCC permissions
                No additional permission prompts needed
                """
                
            case "coding":
                aboutText = """
                \(detailPrefix) Agent! Coding Assistance
                
                CODE OPERATIONS:
                - Read any text file with line numbers
                - Write new files or edit existing ones
                - Search files by content or pattern
                - Apply diffs for precise changes
                
                GIT WORKFLOW:
                - View status, diffs, and history
                - Stage and commit changes
                - Create and switch branches
                - Apply patches
                
                XCODE INTEGRATION:
                - Build projects with xcode_build
                - Run apps with xcode_run
                - List and select open projects
                - View build errors with context
                
                PROJECT STRUCTURE:
                - Navigate complex codebases
                - Understand file relationships
                - Refactor with confidence
                
                BEST PRACTICES:
                Agent! prefers native tools over shell commands
                Edit files directly instead of using sed/awk
                Use git tools instead of git CLI when possible
                Build Xcode projects with xcode_build, not xcodebuild
                """
                
            default: // "all"
                aboutText = """
                \(detailPrefix) About Agent!
                
                Agent! is a native macOS automation assistant that helps you automate tasks, write code, control apps, and manage your Mac.
                
                WHAT I CAN DO:
                - Control apps using AppleScript, JavaScript, or Accessibility
                - Read, write, and edit files in any project
                - Build and run Xcode projects
                - Automate web browsers (Safari, Chrome, Firefox)
                - Execute shell commands with user or root privileges
                - Manage git repositories and commits
                - Generate, transform, and fix text
                - Send messages via iMessage, email, or SMS
                
                HOW TO USE ME:
                Simply describe what you want to accomplish in natural language.
                I will choose the appropriate tools and execute them.
                
                EXAMPLES:
                - "Read the main.swift file and explain it"
                - "Build the Xcode project and fix any errors"
                - "Write a paragraph about machine learning"
                - "Turn this text into a grocery list"
                - "Fix spelling and grammar in this paragraph, no emojis"
                - "Send this summary to me via iMessage"
                - "Automate Safari to fill out this form"
                
                CURRENT CONTEXT:
                - Working directory: \(projectFolder)
                - User: \(NSFullUserName())
                - System: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
                
                Type naturally and I will help you get things done.
                """
            }
            
            return aboutText
        }
        
        // fix_text
        if name == "fix_text" {
            guard let text = input["text"] as? String, !text.isEmpty else {
                return "Error: text is required for fix_text"
            }
            
            let fixes = input["fixes"] as? String ?? "all"
            let preserveStyle = input["preserve_style"] as? Bool ?? true
            
            // Validate fixes type
            let validFixes = ["all", "spelling", "grammar", "punctuation", "capitalization"]
            guard validFixes.contains(fixes.lowercased()) else {
                return "Error: invalid fixes type. Valid types: \(validFixes.joined(separator: ", "))"
            }
            
            let guidance: String
            
            switch fixes.lowercased() {
            case "spelling":
                guidance = """
                Fix spelling errors in the following text.
                
                Original text:
                \(text)
                
                Requirements:
                - Correct all spelling mistakes
                - Preserve original meaning and style: \(preserveStyle ? "yes" : "no")
                - Do NOT add any emojis
                - Do NOT change word choices unless misspelled
                - Return only the corrected text
                
                Corrected text:
                """
                
            case "grammar":
                guidance = """
                Fix grammar errors in the following text.
                
                Original text:
                \(text)
                
                Requirements:
                - Correct grammar, verb tense, and sentence structure
                - Preserve original meaning and style: \(preserveStyle ? "yes" : "no")
                - Do NOT add any emojis
                - Do NOT change wording unless grammatically incorrect
                - Return only the corrected text
                
                Corrected text:
                """
                
            case "punctuation":
                guidance = """
                Fix punctuation in the following text.
                
                Original text:
                \(text)
                
                Requirements:
                - Correct all punctuation errors
                - Fix spacing around punctuation
                - Preserve original meaning and style: \(preserveStyle ? "yes" : "no")
                - Do NOT add any emojis
                - Return only the corrected text
                
                Corrected text:
                """
                
            case "capitalization":
                guidance = """
                Fix capitalization in the following text.
                
                Original text:
                \(text)
                
                Requirements:
                - Correct capitalization (sentences start with capitals, proper nouns, etc.)
                - Preserve original meaning and style: \(preserveStyle ? "yes" : "no")
                - Do NOT add any emojis
                - Return only the corrected text
                
                Corrected text:
                """
                
            default: // "all"
                guidance = """
                Fix all spelling and grammar errors in the following text.
                
                Original text:
                \(text)
                
                Requirements:
                - Correct spelling, grammar, punctuation, and capitalization
                - Preserve original meaning and style: \(preserveStyle ? "yes" : "no")
                - Do NOT add any emojis
                - Keep the same tone and voice
                - Return only the corrected text
                
                Corrected text:
                """
            }
            
            return guidance
        }

        // plan_mode
        if name == "plan_mode" {
            let action: String = input["action"] as? String ?? "read"
            return Self.handlePlanMode(action: action, input: input, projectFolder: pf, tabName: "main")
        }

        // Fallback
        return "Tool \(name) not implemented for Apple AI"
    }


}
