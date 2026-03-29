
@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log
import Cocoa

private let taskLog = Logger(subsystem: AppConstants.subsystem, category: "TaskExecution")



// MARK: - Native Tool Handler (Apple AI)

extension AgentViewModel {


    // MARK: - Native Tool Handler (Apple AI)

    /// Executes a tool call from Apple AI's Foundation Models native tool system.
    /// Routes to the same execution logic as TaskExecution tool handlers.
    func executeNativeTool(_ rawName: String, input rawInput: sending [String: Any]) async -> String {
        // Expand consolidated CRUDL tools into legacy tool names
        let (name, input) = Self.expandConsolidatedTool(name: rawName, input: rawInput)
        let pf = projectFolder
        NativeToolContext.toolCallCount += 1

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
        if name == "list_agents" {
            let scripts = scriptService.listScripts()
            return scripts.isEmpty ? "No scripts found" : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
        }
        if name == "run_agent" {
            let scriptName = input["name"] as? String ?? ""
            let arguments = input["arguments"] as? String ?? ""
            guard let cmd = scriptService.compileCommand(name: scriptName) else {
                return "Error: script '\(scriptName)' not found"
            }
            var fullCmd = cmd
            if !arguments.isEmpty {
                fullCmd = "AGENT_SCRIPT_ARGS='\(arguments)' \(cmd)"
            }
            RecentAgentsService.shared.recordRun(agentName: scriptName, arguments: arguments, prompt: "run \(scriptName) \(arguments)")
            let result = await Self.executeTCC(command: fullCmd)
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }
        if name == "read_agent" {
            return scriptService.readScript(name: input["name"] as? String ?? "") ?? "Not found"
        }
        if name == "create_agent" || name == "update_agent" {
            return scriptService.createScript(name: input["name"] as? String ?? "", content: input["content"] as? String ?? "")
        }
        if name == "delete_agent" {
            return scriptService.deleteScript(name: input["name"] as? String ?? "")
        }
        if name == "combine_agents" {
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

        // Saved scripts - delegated to TaskExecution+ScriptTools
        if name == "list_apple_scripts" || name == "save_apple_script" || name == "delete_apple_script" ||
           name == "run_apple_script" || name == "list_javascript" || name == "save_javascript" ||
           name == "delete_javascript" || name == "run_javascript" {
            return await handleSavedScriptTool(name: name, input: input)
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
        // MARK: edit_file
        if name == "edit_file" {
            let path = input["file_path"] as? String ?? ""
            let old = input["old_string"] as? String ?? ""
            let new = input["new_string"] as? String ?? ""
            let replaceAll = input["replace_all"] as? Bool ?? false

            guard old != new else { return "Error: old_string and new_string are identical" }
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
                    d1f = "❌" + old + "\n" + "✅" + new
                }
                let label = replaceAll ? "\(occurrences) occurrences" : "1 occurrence"
                var result = "Replaced \(label) in \(path)\n\n\(d1f)"
                if let meta = diff.metadata {
                    if let startLine = meta.sourceStartLine { result += "\n📍 Changes start at line \(startLine + 1)" }
                    if let total = meta.sourceTotalLines { result += " (of \(total) lines)" }
                }
                return result
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }

        // MARK: create_diff
        if name == "create_diff" {
            var source = input["source"] as? String ?? ""
            let destination = input["destination"] as? String ?? ""
            if let fp = input["file_path"] as? String, !fp.isEmpty {
                let expanded = (fp as NSString).expandingTildeInPath
                if let data = FileManager.default.contents(atPath: expanded),
                   let text = String(data: data, encoding: .utf8) {
                    source = text
                }
            }
            let diff = MultiLineDiff.createDiff(source: source, destination: destination, includeMetadata: true)
            let d1f = MultiLineDiff.displayDiff(diff: diff, source: source, format: .ai)
            let diffId = DiffStore.shared.store(diff: diff, source: source)
            return "diff_id: \(diffId.uuidString)\n\n\(d1f)"
        }

        // MARK: apply_diff
        if name == "apply_diff" {
            let path = input["file_path"] as? String ?? ""
            let diffIdStr = input["diff_id"] as? String ?? ""
            let asciiDiff = input["diff"] as? String ?? ""
            let expanded = (path as NSString).expandingTildeInPath
            guard let data = FileManager.default.contents(atPath: expanded),
                  let source = String(data: data, encoding: .utf8) else { return "Error: cannot read \(path)" }
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
                try patched.write(to: URL(fileURLWithPath: expanded), atomically: true, encoding: .utf8)
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
            let pat = CodingService.shellEscape(input["pattern"] as? String ?? "*")
            let dir = CodingService.shellEscape(input["path"] as? String ?? pf)
            let result = await executeViaUserAgent(command: "find \(dir) -name \(pat) ! -path '*/.build/*' ! -path '*/.git/*' 2>/dev/null | sort | head -100")
            return result.output.isEmpty ? "No files found" : result.output
        }
        if name == "search_files" {
            let pat = CodingService.shellEscape(input["pattern"] as? String ?? "")
            let dir = CodingService.shellEscape(input["path"] as? String ?? pf)
            let result = await executeViaUserAgent(command: "grep -rn \(pat) \(dir) 2>/dev/null | head -50")
            return result.output.isEmpty ? "No matches" : result.output
        }
        if name == "read_dir" {
            let dir = CodingService.shellEscape(input["path"] as? String ?? pf)
            let result = await executeViaUserAgent(command: "ls -la \(dir) 2>/dev/null")
            return result.output.isEmpty ? "Directory not found or empty" : result.output
        }
        if name == "if_to_switch" {
            let filePath = input["file_path"] as? String ?? ""
            return await Self.offMain { CodingService.convertIfToSwitch(path: filePath) }
        }
        if name == "extract_function" {
            let filePath = input["file_path"] as? String ?? ""
            let funcName = input["function_name"] as? String ?? ""
            let newFile = input["new_file"] as? String ?? ""
            return await Self.offMain { CodingService.extractFunctionToFile(sourcePath: filePath, functionName: funcName, newFileName: newFile) }
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
        // Web automation handlers moved to TaskExecution+WebTools.swift
        if let result = await handleWebTool(name: name, input: input) {
            return result
        }

        // MARK: - Selenium WebDriver for Apple AI (via AgentScript)
        // Selenium handlers moved to TaskExecution+Selenium.swift
        if let result = await handleSeleniumTool(name: name, input: input) {
            return result
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
        if let result = await handleAboutSelfTool(name: name, input: input) {
            return result
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

        // batch_tools — run multiple tool calls in one batch
        if name == "batch_tools" {
            let desc = input["description"] as? String ?? "Batch Tasks"
            guard let tasks = input["tasks"] as? [[String: Any]] else {
                return "Error: tasks must be an array of {\"tool\": \"name\", \"input\": {...}} objects"
            }
            var batchOutput = "● \(desc) (\(tasks.count) tasks)\n"
            var completed = 0
            for (idx, task) in tasks.enumerated() {
                var subName = task["tool"] as? String ?? ""
                var subInput = task["input"] as? [String: Any] ?? [:]
                if subName == "batch_tools" || subName == "batch_commands" || subName == "task_complete" {
                    batchOutput += "[\(idx + 1)] \(subName): skipped (not allowed in batch)\n\n"
                    continue
                }
                (subName, subInput) = Self.expandConsolidatedTool(name: subName, input: subInput)
                let output = await executeNativeTool(subName, input: subInput)
                completed += 1
                batchOutput += "[\(idx + 1)] \(subName): \(output)\n\n"
            }
            batchOutput += "● \(completed)/\(tasks.count) tasks completed"
            return batchOutput
        }

        // Silently skip tools not available to Apple AI
        return "(skipped)"
    }
}
