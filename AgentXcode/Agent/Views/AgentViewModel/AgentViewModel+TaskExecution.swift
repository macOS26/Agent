
@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log
import Cocoa

private let taskLog = Logger(subsystem: "Agent.app.toddbruss", category: "TaskExecution")

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
                
                Use list_native_tools to see all available tools.
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
                import Foundation
                
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
        taskLog.info("[main] executeTask started: \(prompt.prefix(80))")
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
        let foundationModelService: FoundationModelService? = provider == .foundationModel
            ? FoundationModelService(historyContext: historyContext, projectFolder: projectFolder) : nil
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
        var timeoutRetryCount = 0
        let maxTimeoutRetries = 2
        
        // Apple Intelligence mediator for contextual annotations
        let mediator = AppleIntelligenceMediator.shared
        var appleAIAnnotations: [AppleIntelligenceMediator.Annotation] = []

        // Optional: Add Apple Intelligence context to user message
        if mediator.isEnabled && mediator.injectContextToLLM {
            taskLog.info("[main] Apple AI mediator: contextualizing user message...")
            if let contextAnnotation = await mediator.contextualizeUserMessage(prompt) {
                appleAIAnnotations.append(contextAnnotation)
                // Capture Apple AI decision for training (only when toggle is on)
                if mediator.trainingEnabled {
                    TrainingDataStore.shared.captureAppleAIDecision(contextAnnotation.content)
                }
                // Inject rephrased context into LLM messages
                let contextMessage: [String: Any] = [
                    "role": "user",
                    "content": contextAnnotation.formatted
                ]
                messages.insert(contextMessage, at: messages.count)
                appendLog(contextAnnotation.formatted)
                flushLog()
                if agentReplyHandle != nil {
                    sendProgressUpdate(contextAnnotation.formatted)
                }
            }
        }

        var iterations = 0
        let maxIterations = self.maxIterations

        while !Task.isCancelled && iterations < maxIterations {
            iterations += 1
            taskLog.info("[main] iteration \(iterations)/\(maxIterations)")

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

                let response: (content: [[String: Any]], stopReason: String)
                var textWasStreamed = false
                let streamStart = CFAbsoluteTimeGetCurrent()
                flushLog()
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
                } else if let foundationModelService {
                    response = try await foundationModelService.sendStreaming(messages: messages) { [weak self] delta in
                        Task { @MainActor in
                            self?.isThinking = false
                            self?.appendStreamDelta(delta)
                        }
                    }
                    textWasStreamed = true
                } else {
                    throw AgentError.noAPIKey
                }
                let streamElapsed = CFAbsoluteTimeGetCurrent() - streamStart
                taskLog.info("[main] stream completed in \(String(format: "%.2f", streamElapsed))s, stopReason=\(response.stopReason)")
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
                            let source = input["source"] as? String ?? ""
                            let destination = input["destination"] as? String ?? ""
                            let diff = MultiLineDiff.createDiff(source: source, destination: destination, includeMetadata: true)
                            let d1f = MultiLineDiff.displayDiff(diff: diff, source: source, format: .ai)
                            let summary = MultiLineDiff.generateDiffSummary(source: source, destination: destination)
                            var result = d1f + "\n\n" + summary
                            if let meta = diff.metadata, let startLine = meta.sourceStartLine {
                                result += "\n📍 Changes start at line \(startLine + 1)"
                            }
                            appendRawOutput(result + "\n")
                            commandsRun.append("create_diff")
                            toolResults.append(["type": "tool_result", "tool_use_id": toolId, "content": result])
                        }

                        if name == "apply_diff" {
                            let filePath = input["file_path"] as? String ?? ""
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
                                let patched = try MultiLineDiff.applyASCIIDiff(to: source, asciiDiff: asciiDiff)
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
                            // Use Ollama web_search API for Ollama provider, Tavily as backup
                            let output = await Self.performWebSearch(query: query, apiKey: tavilyAPIKey, provider: selectedProvider)
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
                    
                    // Auto-retry on 429 rate limit after 10 seconds
                    if errMsg.contains("429") || errMsg.lowercased().contains("rate limit") || errMsg.lowercased().contains("concurrent request") {
                        appendLog("Rate limited — retrying in 10 seconds...")
                        flushLog()
                        if agentReplyHandle != nil {
                            sendProgressUpdate("Rate limited — retrying in 10 seconds...")
                        }
                        try? await Task.sleep(for: .seconds(10))
                        if Task.isCancelled { break }
                        continue
                    }
                    
                    // Handle timeout errors with retry logic
                    if isNetworkTimeout {
                        // Check if we've already retried this timeout
                        if timeoutRetryCount < maxTimeoutRetries {
                            timeoutRetryCount += 1
                            let retryMessage = "\(errorSource) timeout detected (attempt \(timeoutRetryCount)/\(maxTimeoutRetries)) — retrying in 10 seconds..."
                            appendLog(retryMessage)
                            flushLog()
                            if agentReplyHandle != nil {
                                sendProgressUpdate(retryMessage)
                            }
                            
                            // Log to task log for debugging
                            taskLog.info("[main] \(errorSource) timeout, retry \(timeoutRetryCount)/\(maxTimeoutRetries)")
                            
                            try? await Task.sleep(for: .seconds(10))
                            if Task.isCancelled { break }
                            continue
                        } else {
                            // Max retries reached
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
                break
            }
        }

        if iterations >= maxIterations {
            appendLog("Reached maximum iterations (\(maxIterations))")
        }

        // Apple Intelligence: suggest next steps after completion
        if mediator.isEnabled && mediator.showAnnotationsToUser && !completionSummary.isEmpty {
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

    // MARK: - Web Search (Ollama API + Tavily Backup)
    
    /// Perform web search using Ollama API for Ollama provider, Tavily as backup for other providers
    nonisolated private static func performTavilySearch(query: String, apiKey: String) async -> String {
        // Try Tavily as the default implementation
        return await performTavilySearchInternal(query: query, apiKey: apiKey)
    }
    
    /// Perform web search using the appropriate API based on provider
    nonisolated private static func performWebSearch(query: String, apiKey: String, provider: APIProvider) async -> String {
        // For Ollama provider, try Ollama web_search API first
        if provider == .ollama || provider == .localOllama {
            if let ollamaKey = KeychainService.shared.getOllamaAPIKey(), !ollamaKey.isEmpty {
                let ollamaResult = await performOllamaWebSearch(query: query, apiKey: ollamaKey)
                // If Ollama search succeeds, return it
                if !ollamaResult.hasPrefix("Error:") {
                    return ollamaResult
                }
                // Fall back to Tavily if Ollama search fails
            }
        }
        
        // Use Tavily as primary or backup
        return await performTavilySearchInternal(query: query, apiKey: apiKey)
    }
    
    /// Ollama Web Search API (cloud-only, requires API key)
    nonisolated private static func performOllamaWebSearch(query: String, apiKey: String) async -> String {
        guard !apiKey.isEmpty else {
            return "Error: Ollama API key not set. Add it in Settings."
        }
        
        guard let url = URL(string: "https://ollama.com/api/web_search") else {
            return "Error: Invalid Ollama search URL"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 90
        
        let body: [String: Any] = [
            "query": query,
            "max_results": 5
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return "Error: Invalid response from Ollama"
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                // Fall back to Tavily indication
                return "Error: Ollama API returned \(httpResponse.statusCode): \(errorBody)"
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return "Error: Failed to parse Ollama response"
            }
            
            // Ollama web_search returns results in a similar format
            // Structure: {"results": [{"title": "...", "url": "...", "content": "..."}]}
            if let results = json["results"] as? [[String: Any]], !results.isEmpty {
                var output = ""
                for (i, result) in results.enumerated() {
                    let title = result["title"] as? String ?? "Untitled"
                    let resultUrl = result["url"] as? String ?? ""
                    let content = result["content"] as? String ?? result["snippet"] as? String ?? ""
                    output += "\(i + 1). \(title)\n   \(resultUrl)\n   \(content)\n\n"
                }
                return output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Alternative format: {"web_search_results": [...]}
            if let results = json["web_search_results"] as? [[String: Any]], !results.isEmpty {
                var output = ""
                for (i, result) in results.enumerated() {
                    let title = result["title"] as? String ?? "Untitled"
                    let resultUrl = result["url"] as? String ?? ""
                    let content = result["content"] as? String ?? result["snippet"] as? String ?? ""
                    output += "\(i + 1). \(title)\n   \(resultUrl)\n   \(content)\n\n"
                }
                return output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            return "No search results found for '\(query)'"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    /// Tavily Web Search API (backup for all providers)
    nonisolated private static func performTavilySearchInternal(query: String, apiKey: String) async -> String {
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
        request.timeoutInterval = 90

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
    
    /// Helper function to check if a Unicode scalar is an emoji
    private func isEmoji(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x1F600...0x1F64F, // Emoticons
             0x1F300...0x1F5FF, // Misc Symbols and Pictographs
             0x1F680...0x1F6FF, // Transport and Map Symbols
             0x1F1E6...0x1F1FF, // Regional indicator symbols
             0x2600...0x26FF,   // Misc symbols
             0x2700...0x27BF,   // Dingbats
             0xFE00...0xFE0F,   // Variation Selectors
             0x1F900...0x1F9FF, // Supplemental Symbols and Pictographs
             0x1FA00...0x1FA6F, // Chess Symbols
             0x1FA70...0x1FAFF: // Symbols and Pictographs Extended-A
            return true
        default:
            return false
        }
    }
}
