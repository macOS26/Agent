
@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log
import Cocoa

private let taskLog = Logger(subsystem: AppConstants.subsystem, category: "TaskExecution")



// MARK: - Task Utilities

private let maxToolResultChars = 8_000

extension AgentViewModel {


    static func truncateToolResults(_ results: [[String: Any]]) -> [[String: Any]] {
        results.map { result in
            guard var content = result["content"] as? String,
                  content.count > maxToolResultChars else { return result }
            let keepChars = maxToolResultChars / 2
            let head = String(content.prefix(keepChars))
            let tail = String(content.suffix(keepChars))
            let trimmed = content.count - maxToolResultChars
            content = head + "\n\n... (\(trimmed) chars truncated) ...\n\n" + tail
            var updated = result
            updated["content"] = content
            return updated
        }
    }

    // MARK: - Message Pruning

    /// Prune old messages to reduce token usage on long tasks.
    /// Keeps the first user message and the most recent messages.
    /// Middle messages are summarized into a compact text block.
    static func pruneMessages(_ messages: inout [[String: Any]], keepRecent: Int = 6) {
        guard messages.count > keepRecent + 4 else { return }

        let firstMsg = messages[0]
        let recentMessages = Array(messages.suffix(keepRecent))
        let middleMessages = Array(messages.dropFirst(1).dropLast(keepRecent))

        // Build compact summary of middle messages
        var summaryLines: [String] = []
        for msg in middleMessages {
            let role = msg["role"] as? String ?? "?"
            if let text = msg["content"] as? String {
                summaryLines.append("\(role): \(String(text.prefix(150)))")
            } else if let blocks = msg["content"] as? [[String: Any]] {
                for block in blocks {
                    let type = block["type"] as? String ?? ""
                    if type == "tool_use", let name = block["name"] as? String {
                        summaryLines.append("tool: \(name)")
                    } else if type == "tool_result" {
                        let content = block["content"] as? String ?? ""
                        let preview = content.hasPrefix("Error") ? String(content.prefix(100)) : "OK"
                        summaryLines.append("result: \(preview)")
                    } else if type == "text", let text = block["text"] as? String {
                        summaryLines.append("\(role): \(String(text.prefix(150)))")
                    } else if type == "image" {
                        summaryLines.append("[image removed]")
                    }
                }
            }
        }
        let summary = summaryLines.joined(separator: "\n")

        messages = [firstMsg]
        messages.append(["role": "user", "content": "Summary of previous \(middleMessages.count) messages:\n\(summary)"])
        messages.append(["role": "assistant", "content": "Understood, continuing."])
        messages.append(contentsOf: recentMessages)
    }

    /// Strip base64 image data from older messages to save tokens.
    static func stripOldImages(_ messages: inout [[String: Any]], keepRecentCount: Int = 4) {
        let cutoff = max(0, messages.count - keepRecentCount)
        for i in 0..<cutoff {
            guard var blocks = messages[i]["content"] as? [[String: Any]] else { continue }
            var changed = false
            for j in 0..<blocks.count {
                if blocks[j]["type"] as? String == "image" {
                    blocks[j] = ["type": "text", "text": "[screenshot removed]"]
                    changed = true
                }
            }
            if changed { messages[i]["content"] = blocks }
        }
    }

    // MARK: - Web Search (forwarding to WebSearch extension)

    /// Perform web search using the appropriate API based on provider.
    /// This delegates to the implementation in AgentViewModel+WebSearch.swift.
    nonisolated static func performWebSearchForTask(query: String, apiKey: String, provider: APIProvider) async -> String {
        // For Ollama provider, try Ollama web_search API first
        if provider == .ollama || provider == .localOllama {
            if let ollamaKey = KeychainService.shared.getOllamaAPIKey(), !ollamaKey.isEmpty {
                let ollamaResult = await performOllamaWebSearchInternal(query: query, apiKey: ollamaKey)
                if !ollamaResult.hasPrefix("Error:") {
                    return ollamaResult
                }
            }
        }
        return await performTavilySearchForTask(query: query, apiKey: apiKey)
    }

    nonisolated private static func performOllamaWebSearchInternal(query: String, apiKey: String) async -> String {
        guard !apiKey.isEmpty else { return "Error: Ollama API key not set. Add it in Settings." }
        guard let url = URL(string: "https://ollama.com/api/web_search") else { return "Error: Invalid Ollama search URL" }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = llmAPITimeout
        let body: [String: Any] = ["query": query, "max_results": 5]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return "Error: Invalid response from Ollama" }
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                return "Error: Ollama API returned \(httpResponse.statusCode): \(errorBody)"
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "Error: Failed to parse Ollama response" }
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
        } catch { return "Error: \(error.localizedDescription)" }
    }

    nonisolated private static func performTavilySearchForTask(query: String, apiKey: String) async -> String {
        guard !apiKey.isEmpty else { return "Error: Tavily API key not set. Add it in Settings." }
        guard let url = URL(string: "https://api.tavily.com/search") else { return "Error: Invalid Tavily URL" }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = llmAPITimeout
        let body: [String: Any] = ["query": query, "max_results": 5]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return "Error: Invalid response from Tavily" }
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                return "Error: Tavily API returned \(httpResponse.statusCode): \(errorBody)"
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else { return "Error: Failed to parse Tavily response" }
            if results.isEmpty { return "No search results found for '\(query)'" }
            var output = ""
            for (i, result) in results.enumerated() {
                let title = result["title"] as? String ?? "Untitled"
                let resultUrl = result["url"] as? String ?? ""
                let content = result["content"] as? String ?? ""
                output += "\(i + 1). \(title)\n   \(resultUrl)\n   \(content)\n\n"
            }
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch { return "Error: \(error.localizedDescription)" }
    }

    // MARK: - Direct Command Execution

    /// Execute a direct command matched by triage, without the LLM.
    /// When `tab` is provided, output is logged to that tab; otherwise to the main activity log.
    func executeDirectCommand(_ cmd: AppleIntelligenceMediator.DirectCommand, tab: ScriptTab? = nil) async -> String {
        let name = scriptService.resolveScriptName(cmd.argument)

        // Resolve effective project folder: tab's folder > main folder (always resolve to directory)
        let rawFolder: String
        if let tab, !tab.projectFolder.isEmpty {
            rawFolder = tab.projectFolder
        } else {
            rawFolder = projectFolder
        }
        let effectiveFolder = Self.resolvedWorkingDirectory(rawFolder)

        // Local helpers to route logging to the correct destination
        func log(_ message: String) {
            if let tab { tab.appendLog(message) } else { appendLog(message) }
        }
        func flush() {
            if let tab { tab.flush() } else { flushLog() }
        }

        switch cmd.name {
        case "list_agents":
            let list = scriptService.numberedList()
            let count = scriptService.listScripts().count
            log("🦾 Agents: \(count) found")
            log(list)
            return list

        case "read_agent":
            guard let content = scriptService.readScript(name: name) else {
                let err = "Error: agent '\(name)' not found."
                log(err)
                return err
            }
            log("📖 Read: \(name)")
            log(Self.codeFence(content, language: "swift"))
            return content

        case "delete_agent":
            let output = scriptService.deleteScript(name: name)
            log(output)
            return output

        case "run_agent":
            // Only called when canRunDirectly returned true (no args needed)
            guard let compileCmd = scriptService.compileCommand(name: name) else {
                let err = "Error: agent '\(name)' not found."
                log(err)
                return err
            }
            // Skip compilation if dylib is up to date
            if !scriptService.isDylibCurrent(name: name) {
                log("🦾 Compiling: \(name)")
                flush()
                let compileCmd2 = Self.prependWorkingDirectory(compileCmd, projectFolder: effectiveFolder)
                let compileResult = await userService.execute(command: compileCmd2)
                if compileResult.status != 0 {
                    log("Compile error:\n\(compileResult.output)")
                    return compileResult.output
                }
            }
            log("🦾 Running: \(name)")
            flush()
            RecentAgentsService.shared.recordRun(agentName: name, arguments: "", prompt: "run \(name)")
            let runResult = await scriptService.loadAndRunScriptViaProcess(
                name: name,
                onOutput: { [weak self] chunk in
                    Task { @MainActor in
                        if let tab {
                            tab.appendOutput(chunk)
                        } else {
                            self?.appendRawOutput(chunk)
                        }
                    }
                }
            )
            log(runResult.output)
            return runResult.output

        case "google_search":
            let query = cmd.argument
            log("🔍 Google search: \(query)")
            flush()
            let output = await WebAutomationService.shared.safariGoogleSearch(query: query)
            return output

        case "web_open":
            let url = cmd.argument
            log("🌐 Opening: \(url)")
            flush()
            let fullURL = url.hasPrefix("http") ? url : "https://\(url)"
            guard let parsed = URL(string: fullURL) else {
                return "Error: Invalid URL '\(fullURL)'"
            }
            do {
                let output = try await WebAutomationService.shared.open(url: parsed)
                return output
            } catch {
                return "Error: \(error.localizedDescription)"
            }

        case "web_open_and_search":
            // Format: "url|||query"
            let parts = cmd.argument.components(separatedBy: "|||")
            let url = parts.first ?? ""
            let query = parts.count > 1 ? parts[1] : ""
            log("🌐 Opening: \(url)")
            flush()
            let fullURL = url.hasPrefix("http") ? url : "https://\(url)"
            if let parsed = URL(string: fullURL) {
                do { _ = try await WebAutomationService.shared.open(url: parsed) } catch {}
            }
            // Wait for page load
            try? await Task.sleep(for: .seconds(3))
            log("🔍 Searching page for: \(query)")
            flush()
            let searchResult = await WebAutomationService.shared.safariSiteSearch(query: query)
            return searchResult

        case "web_scan":
            log("🔍 Scanning interactive elements...")
            flush()
            let elements = await WebAutomationService.shared.scanInteractiveElements()
            return elements

        case "web_read":
            log("📖 Reading page...")
            flush()
            let url = await WebAutomationService.shared.getPageURL()
            let title = await WebAutomationService.shared.getPageTitle()
            let content = await WebAutomationService.shared.readPageContent(maxLength: 3000)
            return "{\"url\": \"\(WebAutomationService.escapeJS(url))\", \"title\": \"\(WebAutomationService.escapeJS(title))\", \"content\": \"\(WebAutomationService.escapeJS(content))\"}"

        case "web_click":
            let selector = cmd.argument
            log("👆 Clicking: \(selector)")
            flush()
            do {
                return try await WebAutomationService.shared.click(selector: selector, strategy: .javascript)
            } catch {
                return "Error: \(error.localizedDescription)"
            }

        case "web_type":
            // argument format: "selector|text"
            let parts = cmd.argument.components(separatedBy: "|")
            guard parts.count >= 2 else { return "Error: format is selector|text" }
            let selector = parts[0].trimmingCharacters(in: .whitespaces)
            let text = parts.dropFirst().joined(separator: "|").trimmingCharacters(in: .whitespaces)
            log("⌨️ Typing into \(selector): \(text.prefix(50))")
            flush()
            do {
                return try await WebAutomationService.shared.type(text: text, selector: selector, strategy: .javascript)
            } catch {
                return "Error: \(error.localizedDescription)"
            }

        case "web_page_search":
            let query = cmd.argument
            log("🔍 Page search: \(query)")
            flush()
            let js = "window.find('\(query.replacingOccurrences(of: "'", with: "\\'"))')"
            do {
                let result = try await WebAutomationService.shared.executeJavaScript(script: js)
                let output = (result as? String) ?? "Searched for '\(query)'"
                return output
            } catch {
                return "Error: \(error.localizedDescription)"
            }

        case "web_js":
            let script = cmd.argument
            log("📜 Running JS...")
            flush()
            do {
                let result = try await WebAutomationService.shared.executeJavaScript(script: script)
                return result as? String ?? "(no output)"
            } catch {
                return "Error: \(error.localizedDescription)"
            }

        default:
            return ""
        }
    }

    // MARK: - Main Task Web Tool Handler

    /// Handle web tools for the main task — mirrors TabHandlers+Web logic.
    func handleMainWebTool(name: String, input: [String: Any]) async -> String {
        let ws = WebAutomationService.shared
        let selector = input["selector"] as? String ?? input["query"] as? String ?? ""
        let browser = input["browser"] as? String

        switch name {
        case "web_open":
            guard let urlStr = input["url"] as? String, let url = URL(string: urlStr) else { return "Error: invalid URL" }
            do { return try await ws.open(url: url) } catch { return "Error: \(error.localizedDescription)" }

        case "web_read_content":
            return await ws.readPageContent(browser: browser)

        case "web_get_url":
            return await ws.getPageURL(browser: browser)

        case "web_get_title":
            return await ws.getPageTitle(browser: browser)

        case "web_click":
            do { return try await ws.click(selector: selector, strategy: .javascript) } catch { return "Error: \(error.localizedDescription)" }

        case "web_type":
            let text = input["text"] as? String ?? ""
            do { return try await ws.type(text: text, selector: selector, strategy: .javascript) } catch { return "Error: \(error.localizedDescription)" }

        case "web_find":
            let isPlainText = !selector.contains(".") && !selector.contains("#") && !selector.contains("[") && !selector.contains(":") && !selector.contains("/") && !selector.contains(">")
            if isPlainText {
                let escaped = WebAutomationService.escapeJS(selector)
                let js = """
                JSON.stringify((function() {
                    var all = document.querySelectorAll('a, button, input[type=submit], [role=button]');
                    var matches = [];
                    for (var i = 0; i < all.length; i++) {
                        var el = all[i];
                        var text = el.textContent.trim();
                        if (text.toLowerCase().indexOf('\(escaped.lowercased())') >= 0) {
                            var rect = el.getBoundingClientRect();
                            matches.push({ tag: el.tagName, text: text.substring(0, 100), href: el.href || '', id: el.id || '', className: (el.className || '').substring(0, 80) });
                        }
                    }
                    return matches;
                })())
                """
                if let result = try? await ws.executeJavaScript(script: js) as? String, !result.isEmpty, result != "[]" { return result }
                return "No clickable elements found containing '\(selector)'"
            }
            do {
                let el = try await ws.findElement(selector: selector)
                if let data = try? JSONSerialization.data(withJSONObject: el, options: .prettyPrinted), let s = String(data: data, encoding: .utf8) { return s }
                return "Found: \(el)"
            } catch { return "Error: \(error.localizedDescription)" }

        case "web_execute_js":
            let script = input["script"] as? String ?? input["query"] as? String ?? ""
            let wrappedScript: String
            if script.contains("return ") && !script.contains("JSON.stringify") {
                wrappedScript = "JSON.stringify((function(){" + script + "})())"
            } else if !script.contains("JSON.stringify") && (script.contains("querySelectorAll") || script.contains("document.")) {
                wrappedScript = "JSON.stringify(" + script + ")"
            } else {
                wrappedScript = script
            }
            if let result = try? await ws.executeJavaScript(script: wrappedScript, browser: browser) as? String, !result.isEmpty {
                return result
            }
            return "(no output)"

        case "web_scan":
            return await ws.scanInteractiveElements()

        case "web_scroll_to":
            return await ws.scrollToElement(selector: selector, browser: browser)

        case "web_select":
            return await ws.selectOption(selector: selector, value: input["value"] as? String, text: input["text"] as? String, index: input["index"] as? Int, browser: browser)

        case "web_submit":
            return await ws.submitForm(selector: selector.isEmpty ? nil : selector, browser: browser)

        case "web_navigate":
            return await ws.navigate(action: input["action"] as? String ?? "back", browser: browser)

        case "web_list_tabs":
            return await ws.listTabs(browser: browser)

        case "web_switch_tab":
            let title = input["title"] as? String
            let index = input["index"] as? Int
            return await ws.switchTab(browser: browser, index: index, titleContains: title)

        case "web_list_windows":
            return await ws.listWindows(browser: browser)

        case "web_switch_window":
            return await ws.switchWindow(browser: browser, index: input["index"] as? Int ?? 1)

        case "web_new_window":
            return await ws.newWindow(browser: browser, url: input["url"] as? String)

        case "web_close_window":
            return await ws.closeWindow(browser: browser, index: input["index"] as? Int ?? 1)

        case "web_wait_for_element":
            return await ws.waitForElement(selector: selector, browser: browser, timeout: input["timeout"] as? Double ?? 10)

        case "web_storage":
            return await ws.readStorage(type: input["storage_type"] as? String ?? "cookies", key: input["key"] as? String, browser: browser)

        case "web_upload":
            return await ws.triggerFileUpload(selector: selector, browser: browser)

        case "web_google_search":
            let query = input["query"] as? String ?? ""
            return await ws.safariGoogleSearch(query: query)

        default:
            return await executeNativeTool(name, input: input)
        }
    }

    // MARK: - Conversational Reply Detection

    /// Determines if an LLM text response (with no tool calls) is a valid conversational reply
    /// that should be accepted immediately, rather than nudging the LLM to use tools.
    ///
    /// On iteration 1, the LLM has seen the user's prompt fresh — if it chose text over tools,
    /// it's almost certainly a conversational reply (greeting, answer, explanation).
    /// After iteration 1, the LLM has already been given tool results and is mid-task,
    /// so a text-only response more likely means it forgot to call tools.
    static func isConversationalReply(_ text: String, iteration: Int) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // On iteration 1, if the LLM responded with text and no tools, trust it
        if iteration == 1 { return true }
        // On later iterations, only accept short non-code responses as conversational
        let hasCodeBlock = trimmed.contains("```")
        let isLong = trimmed.count > 1500
        return !hasCodeBlock && !isLong
    }

    /// Helper function to check if a Unicode scalar is an emoji
    func isEmoji(_ scalar: Unicode.Scalar) -> Bool {
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

    // MARK: - Direct Agent Execution (no LLM)

    /// Run an agent script directly — skips the LLM entirely.
    /// Compiles only if the dylib is out of date, then executes.
    /// Returns true on success, false on error (caller should fall through to LLM).
    @discardableResult
    func runAgentDirect(name: String, arguments: String = "") async -> Bool {
        let resolved = scriptService.resolveScriptName(name)
        guard let compileCmd = scriptService.compileCommand(name: resolved) else {
            appendLog("Error: agent '\(resolved)' not found.")
            return false
        }

        // Open or reuse a tab for this agent
        let tab: ScriptTab
        if let existing = scriptTabs.first(where: { $0.scriptName == resolved }) {
            tab = existing
            selectedTabId = tab.id
        } else {
            tab = openScriptTab(scriptName: resolved)
        }

        tab.appendLog("--- Direct Run ---")

        // Compile only if needed
        if !scriptService.isDylibCurrent(name: resolved) {
            tab.appendLog("🦾 Compiling: \(resolved)")
            tab.flush()
            let compileResult = await userService.execute(command: compileCmd)
            if compileResult.status != 0 {
                tab.appendLog("Compile error:\n\(compileResult.output)")
                tab.flush()
                return false
            }
        }

        tab.appendLog("🦾 Running: \(resolved)")
        tab.flush()
        RecentAgentsService.shared.recordRun(agentName: resolved, arguments: arguments, prompt: arguments.isEmpty ? "run \(resolved)" : "run \(resolved) \(arguments)")

        let cancelFlag = tab._cancelFlag
        let runResult = await scriptService.loadAndRunScriptViaProcess(
            name: resolved,
            arguments: arguments,
            isCancelled: { cancelFlag.value }
        ) { [weak tab] chunk in
            Task { @MainActor in
                tab?.appendOutput(chunk)
            }
        }

        tab.flush()
        let statusNote = runResult.status == 0 ? "completed" : "exit code: \(runResult.status)"
        tab.appendLog("\(resolved) \(statusNote)")
        tab.flush()
        return runResult.status == 0
    }
}

