
@preconcurrency import Foundation
import AgentTools
import AgentMCP
import AgentD1F
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

        // Prefix-matched tools
        if let result = await handleWebTool(name: name, input: input) { return result }
        if let result = await handleSeleniumTool(name: name, input: input) { return result }

        switch name {
        // AppleScript (NSAppleScript in-process with TCC)
        case "run_applescript":
            let source = (input["source"] as? String ?? "")
            let result = await Self.offMain { () -> (String, Bool) in
                var err: NSDictionary?
                guard let script = NSAppleScript(source: source) else { return ("Error", false) }
                let out = script.executeAndReturnError(&err)
                if let e = err { return ("AppleScript error: \(e)", false) }
                return (out.stringValue ?? "(no output)", true)
            }
            if result.1 {
                let autoName = Self.autoScriptName(from: source)
                let _ = await Self.offMain { [ss = scriptService] in ss.saveAppleScript(name: autoName, source: source) }
            }
            return result.0
        // osascript (runs osascript CLI in-process with TCC)
        case "run_osascript":
            let script = input["script"] as? String ?? input["command"] as? String ?? ""
            let escaped = script.replacingOccurrences(of: "'", with: "'\\''")
            let command = "osascript -e '\(escaped)'"
            let result = await Self.executeTCCStreaming(command: command) { _ in }
            if result.status == 0 {
                let _ = scriptService.saveAppleScript(name: Self.autoScriptName(from: script), source: script)
            }
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        // JavaScript for Automation (JXA via osascript -l JavaScript)
        case "execute_javascript":
            let script = input["source"] as? String ?? input["script"] as? String ?? ""
            let escaped = script.replacingOccurrences(of: "'", with: "'\\''")
            let command = "osascript -l JavaScript -e '\(escaped)'"
            let result = await Self.executeTCCStreaming(command: command) { _ in }
            if result.status == 0 {
                let _ = scriptService.saveJavaScript(name: Self.autoScriptName(from: script), source: script)
            }
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        // Script management
        case "list_agents":
            let scripts = await Self.offMain { [ss = scriptService] in ss.listScripts() }
            return scripts.isEmpty ? "No scripts found" : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
        case "run_agent":
            let scriptName = input["name"] as? String ?? ""
            let arguments = input["arguments"] as? String ?? ""
            guard let cmd = await Self.offMain({ [ss = scriptService] in ss.compileCommand(name: scriptName) }) else {
                return "Error: script '\(scriptName)' not found"
            }
            var fullCmd = cmd
            if !arguments.isEmpty {
                fullCmd = "AGENT_SCRIPT_ARGS='\(arguments)' \(cmd)"
            }
            RecentAgentsService.shared.recordRun(agentName: scriptName, arguments: arguments, prompt: "run \(scriptName) \(arguments)")
            let result = await Self.executeTCC(command: fullCmd)
            // Update agent menu status based on outcome
            let isUsage = result.output.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Usage:")
            if isUsage || result.status != 0 {
                RecentAgentsService.shared.updateStatus(agentName: scriptName, arguments: arguments, status: .failed)
            } else {
                RecentAgentsService.shared.updateStatus(agentName: scriptName, arguments: arguments, status: .success)
            }
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        case "read_agent":
            let readName = input["name"] as? String ?? ""
            return await Self.offMain { [ss = scriptService] in ss.readScript(name: readName) ?? "Not found" }
        case "create_agent", "update_agent":
            let createName = input["name"] as? String ?? ""
            let createContent = input["content"] as? String ?? ""
            return await Self.offMain { [ss = scriptService] in ss.createScript(name: createName, content: createContent) }
        case "delete_agent":
            let deleteName = input["name"] as? String ?? ""
            return await Self.offMain { [ss = scriptService] in ss.deleteScript(name: deleteName) }
        case "combine_agents":
            let sourceA = input["source_a"] as? String ?? ""
            let sourceB = input["source_b"] as? String ?? ""
            let target = input["target"] as? String ?? ""
            guard let contentA = await Self.offMain({ [ss = scriptService] in ss.readScript(name: sourceA) }) else { return "Error: script '\(sourceA)' not found." }
            guard let contentB = await Self.offMain({ [ss = scriptService] in ss.readScript(name: sourceB) }) else { return "Error: script '\(sourceB)' not found." }
            let merged = Self.combineScriptSources(contentA: contentA, contentB: contentB, sourceA: sourceA, sourceB: sourceB)
            if await Self.offMain({ [ss = scriptService] in ss.readScript(name: target) }) != nil {
                return await Self.offMain { [ss = scriptService] in ss.updateScript(name: target, content: merged) }
            } else {
                return await Self.offMain { [ss = scriptService] in ss.createScript(name: target, content: merged) }
            }
        // File operations
        case "read_file":
            let path = input["file_path"] as? String ?? ""
            guard let data = FileManager.default.contents(atPath: path),
                  let content = String(data: data, encoding: .utf8) else { return "Error: cannot read \(path)" }
            let lines = content.components(separatedBy: "\n")
            if lines.count > 100 && input["offset"] == nil && input["limit"] == nil {
                return lines.prefix(100).joined(separator: "\n") + "\n\n--- FILE HAS \(lines.count) LINES (showing first 100) ---\nUse read_file with offset and limit for specific sections."
            }
            return content
        case "write_file":
            let path = input["file_path"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            let url = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            do { try content.write(to: url, atomically: true, encoding: .utf8); return "Wrote \(path)" }
            catch { return "Error: \(error.localizedDescription)" }
        // MARK: edit_file
        case "edit_file":
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
        // MARK: create_diff
        case "create_diff":
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
        // MARK: apply_diff
        case "apply_diff":
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
        // List/search files (via User LaunchAgent - no TCC required)
        case "list_files":
            let pat = CodingService.shellEscape(input["pattern"] as? String ?? "*")
            let rawDir = input["path"] as? String ?? pf
            let dir = CodingService.shellEscape(rawDir)
            let displayDir = CodingService.trimHome(rawDir)
            let result = await executeViaUserAgent(command: "cd \(dir) && find . -maxdepth 8 -type f -name \(pat) ! -path '*/.*' ! -path '*/.build/*' ! -path '*/.git/*' ! -path '*/.swiftpm/*' ! -name '.DS_Store' ! -name '*.xcuserstate' 2>/dev/null | sed 's|^\\./||' | sort | head -100", silent: true)
            let raw = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? "No files found" : "[project folder: \(displayDir)] paths are relative to project folder\n\(CodingService.formatFileTree(raw))"
        case "search_files":
            let pat = CodingService.shellEscape(input["pattern"] as? String ?? "")
            let rawDir = input["path"] as? String ?? pf
            let dir = CodingService.shellEscape(rawDir)
            let displayDir = CodingService.trimHome(rawDir)
            let result = await executeViaUserAgent(command: "grep -rn \(pat) \(dir) 2>/dev/null | head -50")
            return result.output.isEmpty ? "No matches" : "[project folder: \(displayDir)] paths are relative to project folder\n\(result.output)"
        case "read_dir":
            let rawDir = input["path"] as? String ?? pf
            let dir = CodingService.shellEscape(rawDir)
            let displayDir = CodingService.trimHome(rawDir)
            let detail = (input["detail"] as? String ?? "slim") == "more"
            let cmd = detail
                ? "ls -la \(dir) 2>/dev/null"
                : "cd \(dir) && find . -maxdepth 1 -not -name '.*' 2>/dev/null | sed 's|^\\./||' | sort"
            let result = await executeViaUserAgent(command: cmd, silent: !detail)
            let raw = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? "Directory not found or empty" : "[project folder: \(displayDir)]\n\(raw)"
        case "if_to_switch":
            let filePath = input["file_path"] as? String ?? ""
            return await Self.offMain { CodingService.convertIfToSwitch(path: filePath) }
        case "extract_function":
            let filePath = input["file_path"] as? String ?? ""
            let funcName = input["function_name"] as? String ?? ""
            let newFile = input["new_file"] as? String ?? ""
            return await Self.offMain { CodingService.extractFunctionToFile(sourcePath: filePath, functionName: funcName, newFileName: newFile) }
        // Tool discovery
        case "list_tools":
            let prefs = ToolPreferencesService.shared
            let enabledTools = AgentTools.tools(for: selectedProvider)
                .filter { prefs.isEnabled(selectedProvider, $0.name) }
                .sorted { $0.name < $1.name }
            let builtIn = enabledTools.map { tool -> String in
                if let actionProp = tool.properties["action"],
                   let desc = actionProp["description"] as? String,
                   desc.lowercased().contains("action:") {
                    let parts = desc.components(separatedBy: "Action:")
                    if parts.count > 1 {
                        let actions = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        return "\(tool.name) (actions: \(actions))"
                    }
                }
                return tool.name
            }
            let mcp = MCPService.shared
            let mcpTools = mcp.discoveredTools
                .filter { mcp.isToolEnabled(serverName: $0.serverName, toolName: $0.name) }
                .sorted { $0.name < $1.name }
                .map { "mcp_\($0.serverName)_\($0.name)" }
            let all = builtIn + (mcpTools.isEmpty ? [] : ["--- MCP Tools ---"] + mcpTools)
            return all.joined(separator: "\n")
        // Apple Event query — flat keys wrapped into single operation
        case "apple_event_query":
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
        // Memory tool — persistent user preferences the LLM reads at task start
        case "memory":
            let action = input["action"] as? String ?? "read"
            switch action {
            case "read":
                let content = MemoryStore.shared.content
                return content.isEmpty ? "Memory is empty. User can add preferences here." : content
            case "write":
                let text = input["text"] as? String ?? ""
                MemoryStore.shared.write(text)
                return "Memory updated."
            case "append":
                let text = input["text"] as? String ?? ""
                MemoryStore.shared.append(text)
                return "Added to memory."
            case "clear":
                MemoryStore.shared.write("")
                return "Memory cleared."
            default:
                return "Unknown memory action. Use: read, write, append, clear."
            }
        // Task complete — signal via NativeToolContext so the task loop can detect it
        case "task_complete":
            let summary = input["summary"] as? String ?? "Done"
            NativeToolContext.taskCompleteSummary = summary
            return "Task complete: \(summary)"
        // MARK: - Conversation Tools

        // write_text
        case "write_text":
            guard let subject = input["subject"] as? String, !subject.isEmpty else {
                return "Error: subject is required for write_text"
            }

            let style = input["style"] as? String ?? "informative"
            let lengthStr = input["length"] as? String ?? "medium"
            let context = input["context"] as? String ?? ""

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

            let guidance = """
            Generate \(style) text about "\(subject)" in approximately \(targetWords) words.
            Style: \(style)
            \(context.isEmpty ? "" : "Context: \(context)")
            Requirements: No emojis, well-structured paragraphs, clear and accurate.
            Begin your response directly with the text content.
            """

            return guidance
        // transform_text
        case "transform_text":
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
        // send_message
        case "send_message":
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
                
                let result = await Self.offMain { () -> String in
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
        // fix_text
        case "fix_text":
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
        // plan_mode
        case "plan_mode":
            let action: String = input["action"] as? String ?? "read"
            return Self.handlePlanMode(action: action, input: input, projectFolder: pf, tabName: "main")
        // project_folder
        case "project_folder":
            return handleProjectFolder(tab: nil, input: input)
        // coding_mode
        case "coding_mode":
            let enabled = input["enabled"] as? Bool ?? true
            codingModeEnabled = enabled
            return enabled ? "Coding mode ON — only Core+Workflow+Coding+UserAgent tools active." : "Coding mode OFF — all tools restored."
        // MARK: - Xcode Tools
        case "xcode_build":
            let projectPath = input["project_path"] as? String ?? ""
            return await Self.offMain { XcodeService.shared.buildProject(projectPath: projectPath) }
        case "xcode_run":
            let projectPath = input["project_path"] as? String ?? ""
            return await Self.offMain { XcodeService.shared.runProject(projectPath: projectPath) }
        case "xcode_list_projects":
            return await Self.offMain { XcodeService.shared.listProjects() }
        case "xcode_select_project":
            let number = input["number"] as? Int ?? 0
            return await Self.offMain { XcodeService.shared.selectProject(number: number) }
        case "xcode_grant_permission":
            return await Self.offMain { XcodeService.shared.grantPermission() }
        case "xcode_add_file":
            let fp = input["file_path"] as? String ?? ""
            return await Self.offMain { XcodeService.shared.addFileToProject(filePath: fp) }
        case "xcode_remove_file":
            let fp = input["file_path"] as? String ?? ""
            return await Self.offMain { XcodeService.shared.removeFileFromProject(filePath: fp) }
        case "xcode_bump_version":
            let delta = input["delta"] as? Int ?? 1
            return await Self.offMain { XcodeService.shared.bumpVersion(delta: delta) }
        case "xcode_bump_build":
            let delta = input["delta"] as? Int ?? 1
            return await Self.offMain { XcodeService.shared.bumpBuild(delta: delta) }
        case "xcode_get_version":
            return await Self.offMain { XcodeService.shared.getVersionInfo() }
        case "xcode_analyze":
            let fp = input["file_path"] as? String ?? ""
            guard !fp.isEmpty else { return "Error: file_path is required for analyze" }
            guard let data = FileManager.default.contents(atPath: fp),
                  let content = String(data: data, encoding: .utf8) else {
                return "Error: could not read \(fp)"
            }
            // Basic Swift analysis — check for common issues
            let lines = content.components(separatedBy: "\n")
            var issues: [String] = []
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.contains("force_cast") || trimmed.contains("as!") { issues.append("[Warning] Line \(i+1): Force cast (as!)") }
                if trimmed.contains("try!") { issues.append("[Warning] Line \(i+1): Force try (try!)") }
                if trimmed.contains("implicitly unwrapped") || (trimmed.contains("!") && trimmed.contains("var ") && trimmed.contains(": ")) { }
                if trimmed.count > 200 { issues.append("[Style] Line \(i+1): Line too long (\(trimmed.count) chars)") }
            }
            return issues.isEmpty ? "No issues found in \(fp) (\(lines.count) lines)" : issues.joined(separator: "\n")
        case "xcode_snippet":
            let fp = input["file_path"] as? String ?? ""
            guard !fp.isEmpty else { return "Error: file_path is required for snippet" }
            guard let data = FileManager.default.contents(atPath: fp),
                  let content = String(data: data, encoding: .utf8) else {
                return "Error: could not read \(fp)"
            }
            let lines = content.components(separatedBy: "\n")
            let s = (input["start_line"] as? Int ?? 1)
            let e = (input["end_line"] as? Int ?? lines.count)
            let start = max(s - 1, 0)
            let end = min(e, lines.count)
            guard start < end else { return "Error: invalid line range \(s)-\(e)" }
            let ext = (fp as NSString).pathExtension
            let snippet = lines[start..<end].enumerated().map { "\(start + $0 + 1)\t\($1)" }.joined(separator: "\n")
            return "```\(ext)\n\(snippet)\n```"
        // batch_tools — run multiple tool calls in one batch
        case "batch_tools":
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
        // web_search
        case "web_search":
            let query = input["query"] as? String ?? ""
            guard !query.isEmpty else { return "Error: query is required" }
            return await Self.performWebSearchForTask(query: query, apiKey: tavilyAPIKey, provider: selectedProvider)
        // lookup_sdef
        case "lookup_sdef":
            let bundleID = input["bundle_id"] as? String ?? ""
            let className = input["class_name"] as? String
            if bundleID == "list" {
                let names = SDEFService.shared.availableSDEFs()
                return "Available SDEFs (\(names.count)):\n" + names.joined(separator: "\n")
            } else if let cls = className {
                let props = SDEFService.shared.properties(for: bundleID, className: cls)
                let elems = SDEFService.shared.elements(for: bundleID, className: cls)
                var lines = ["\(cls) properties:"]
                for p in props {
                    let ro = p.readonly == true ? " (readonly)" : ""
                    lines.append("  .\(SDEFService.toCamelCase(p.name)): \(p.type ?? "any")\(ro)\(p.description.map { " — \($0)" } ?? "")")
                }
                if !elems.isEmpty { lines.append("elements: \(elems.joined(separator: ", "))") }
                return lines.isEmpty ? "No class '\(cls)' found for \(bundleID)" : lines.joined(separator: "\n")
            } else {
                return SDEFService.shared.summary(for: bundleID)
            }
        // undo_edit
        case "undo_edit":
            let fp = (input["file_path"] as? String ?? "")
            let expanded = (fp as NSString).expandingTildeInPath
            guard let original = DiffStore.shared.lastEdit(for: expanded) else {
                return "Error: no edit history for \(fp)"
            }
            let result = CodingService.undoEdit(path: fp, originalContent: original)
            if !result.hasPrefix("Error") { DiffStore.shared.clearEditHistory(for: expanded) }
            return result
        // diff_and_apply
        case "diff_and_apply":
            let fp = input["file_path"] as? String ?? ""
            let dest = input["destination"] as? String ?? ""
            let source = input["source"] as? String
            let startLine = input["start_line"] as? Int
            let endLine = input["end_line"] as? Int
            let result = CodingService.diffAndApply(path: fp, source: source, destination: dest, startLine: startLine, endLine: endLine)
            return result.output

        default:
            return "⚠️ Tool '\(rawName)' (expanded: '\(name)') not handled — no matching handler found."
        }
    }
}
