
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
        request.timeoutInterval = 90
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
        request.timeoutInterval = 90
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
    func executeDirectCommand(_ cmd: AppleIntelligenceMediator.DirectCommand) async -> String {
        let name = scriptService.resolveScriptName(cmd.argument)

        switch cmd.name {
        case "list_agents":
            let list = scriptService.numberedList()
            let count = scriptService.listScripts().count
            appendLog("🦾 Agents: \(count) found")
            appendLog(list)
            return list

        case "read_agent":
            guard let content = scriptService.readScript(name: name) else {
                let err = "Error: agent '\(name)' not found."
                appendLog(err)
                return err
            }
            appendLog("📖 Read: \(name)")
            appendLog(Self.codeFence(content, language: "swift"))
            return content

        case "delete_agent":
            let output = scriptService.deleteScript(name: name)
            appendLog(output)
            return output

        case "run_agent":
            // Only called when canRunDirectly returned true (no args needed)
            guard let compileCmd = scriptService.compileCommand(name: name) else {
                let err = "Error: agent '\(name)' not found."
                appendLog(err)
                return err
            }
            appendLog("🦾 Compiling: \(name)")
            flushLog()
            let compileResult = await userService.execute(command: compileCmd)
            if compileResult.status != 0 {
                appendLog("Compile error:\n\(compileResult.output)")
                return compileResult.output
            }
            appendLog("🦾 Running: \(name)")
            flushLog()
            let runResult = await scriptService.loadAndRunScriptViaProcess(name: name)
            appendLog(runResult.output)
            return runResult.output

        case "google_search":
            let query = cmd.argument
            appendLog("🔍 Google search: \(query)")
            flushLog()
            let output = await WebAutomationService.shared.safariGoogleSearch(query: query)
            return output

        case "safari_open":
            let url = cmd.argument
            appendLog("🌐 Opening: \(url)")
            flushLog()
            let fullURL = url.hasPrefix("http") ? url : "https://\(url)"
            do {
                let output = try await WebAutomationService.shared.open(url: URL(string: fullURL)!)
                return output
            } catch {
                return "Error: \(error.localizedDescription)"
            }

        case "safari_read":
            appendLog("📖 Reading page...")
            flushLog()
            let url = await WebAutomationService.shared.getPageURL()
            let title = await WebAutomationService.shared.getPageTitle()
            let content = await WebAutomationService.shared.readPageContent(maxLength: 3000)
            return "{\"url\": \"\(WebAutomationService.escapeJS(url))\", \"title\": \"\(WebAutomationService.escapeJS(title))\", \"content\": \"\(WebAutomationService.escapeJS(content))\"}"

        case "safari_click":
            let selector = cmd.argument
            appendLog("👆 Clicking: \(selector)")
            flushLog()
            do {
                return try await WebAutomationService.shared.click(selector: selector, strategy: .javascript)
            } catch {
                return "Error: \(error.localizedDescription)"
            }

        case "safari_type":
            // argument format: "selector|text"
            let parts = cmd.argument.components(separatedBy: "|")
            guard parts.count >= 2 else { return "Error: format is selector|text" }
            let selector = parts[0].trimmingCharacters(in: .whitespaces)
            let text = parts.dropFirst().joined(separator: "|").trimmingCharacters(in: .whitespaces)
            appendLog("⌨️ Typing into \(selector): \(text.prefix(50))")
            flushLog()
            do {
                return try await WebAutomationService.shared.type(text: text, selector: selector, strategy: .javascript)
            } catch {
                return "Error: \(error.localizedDescription)"
            }

        case "safari_js":
            let script = cmd.argument
            appendLog("📜 Running JS...")
            flushLog()
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
}

