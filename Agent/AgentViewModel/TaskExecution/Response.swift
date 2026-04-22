
@preconcurrency import Foundation
import AgentTools
import AgentMCP
import AgentD1F
import AgentSwift
import Cocoa

// MARK: - Task Execution — LLM Response Content Parsing

extension AgentViewModel {

    /// / Result of parsing a single LLM response turn's content blocks. / - `taskCompleted`: the LLM issued a
    /// `task_complete` tool call; caller / should `return` immediately from executeTask (all completion side / effects — history, chat store, reply — have already been performed). / - `continueProcessing`: caller should continue with tool batch dispatch.
    struct ResponseParseResult {
        var hasToolUse: Bool
        var pendingTools: [(toolId: String, name: String, input: [String: Any])]
        var taskCompleted: Bool
    }

    /// / Walks the LLM response content blocks, logging server-side web search / activity, collecting tool_use calls
    /// into `pendingTools`, and handling / the terminal `task_complete` tool call inline (history, reply, etc.). / Mirrors the original inline `for block in response.content` loop exactly. / Mutates `filesEditedThisTask` and `completionSummary` inout.
    func parseLLMResponseContent(
        _ responseContent: [[String: Any]],
        prompt: String,
        mediator: AppleIntelligenceMediator,
        appleAIAnnotations: inout [AppleIntelligenceMediator.Annotation],
        filesEditedThisTask: inout Set<String>,
        completionSummary: inout String
    ) async -> ResponseParseResult {
        var hasToolUse = false
        var pendingTools: [(toolId: String, name: String, input: [String: Any])] = []

        for block in responseContent {
            guard let type = block["type"] as? String else { continue }

            if type == "text" {
                // LLM text goes to LLM Output only — LogView is for user status
            } else if type == "server_tool_use" {
                // Server-side tool (web search) — executed by the API, just log it
                hasToolUse = true
                if let input = block["input"] as? [String: Any],
                   let query = input["query"] as? String
                {
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
                        appendLog("📊\n" + results.prefix(5).joined(separator: "\n"))
                    }
                }
                flushLog()
            } else if type == "tool_use" {
                hasToolUse = true
                guard let toolId = block["id"] as? String,
                      var name = block["name"] as? String,
                      var input = block["input"] as? [String: Any] else { continue }

                // Expand consolidated CRUDL tools into legacy tool names
                (name, input) = Self.expandConsolidatedTool(name: name, input: input)

                // Plans are encouraged but never required. Track edited files for task summary purposes. No mid-stream
                // blocking — the LLM decides whether to plan up front.
                let editTools: Set<String> = [
                    "write_file",
                    "edit_file",
                    "diff_apply",
                    "diff_and_apply",
                    "create_diff",
                    "apply_diff"
                ]
                if editTools.contains(name), let filePath = input["file_path"] as? String, !filePath.isEmpty {
                    filesEditedThisTask.insert(filePath)
                }

                if name == "task_complete" {
                    var summary = input["summary"] as? String ?? "Done"
                    let stripped = summary.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
                    if stripped.isEmpty || summary == "..." {
                        let lastText = rawLLMOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !lastText.isEmpty { summary = String(lastText.prefix(300)) }
                    }
                    completionSummary = summary
                    // Show task complete in the LLM Output HUD so the user sees the result. Append to rawLLMOutput and
                    // let the drip task pick up the new chars naturally — DO NOT sync displayedLLMOutput, that would skip the drip.
                    let trimmedRaw = rawLLMOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedRaw.isEmpty {
                        rawLLMOutput = "✅ \(summary)"
                    } else if !trimmedRaw.contains(summary) {
                        rawLLMOutput += "\n\n✅ \(summary)"
                    }
                    // Make sure the drip task is still running so it picks up the appended chars
                    startDripIfNeeded()

                    // Apple Intelligence summary annotation — fire-and-forget.
                    // Blocking on this delayed the ✅ Completed log by ~1-2s for a
                    // nice-to-have 1-sentence rewrite of a summary the LLM already
                    // produced. Kick it off in the background; it posts when ready.
                    if mediator.isEnabled && mediator.showAnnotationsToUser && !commandsRun.isEmpty {
                        let capturedSummary = summary
                        let capturedCommands = commandsRun
                        let capturedHandle = agentReplyHandle
                        Task { [weak self] in
                            guard let self else { return }
                            if let annotation = await mediator.summarizeCompletion(summary: capturedSummary, commandsRun: capturedCommands) {
                                self.appendLog(annotation.formatted)
                                self.flushLog()
                                if capturedHandle != nil {
                                    self.sendProgressUpdate(annotation.formatted)
                                }
                            }
                        }
                    }

                    appendLog("✅ Completed: \(summary)")
                    flushLog()
                    history.add(
                        TaskRecord(prompt: prompt, summary: summary, commandsRun: commandsRun),
                        maxBeforeSummary: maxHistoryBeforeSummary,
                        apiKey: apiKey,
                        model: selectedModel
                    )
                    // End the task in SwiftData chat history
                    ChatHistoryStore.shared.endCurrentTask(summary: summary)
                    // Stop progress updates before sending final reply
                    stopProgressUpdates()
                    // Reply to the iMessage sender if this was an Agent! prompt
                    sendAgentReply(summary)
                    isRunning = false
                    return ResponseParseResult(hasToolUse: hasToolUse, pendingTools: pendingTools, taskCompleted: true)
                }

                appendLog("🔧 " + Self.formatToolCallForLog(rawName: block["name"] as? String ?? name, rawInput: block["input"] as? [String: Any] ?? input))
                flushLog()
                pendingTools.append((toolId: toolId, name: name, input: input))
            }
        }

        return ResponseParseResult(hasToolUse: hasToolUse, pendingTools: pendingTools, taskCompleted: false)
    }

    /// Format a tool call for the activity log in the same shape Apple AI uses:
    ///   tool_name(action, key: "value", key: "value")
    /// Prefers the raw (pre-expansion) call so the user sees what the LLM
    /// actually asked for, not an internal legacy name.
    static func formatToolCallForLog(rawName: String, rawInput: [String: Any]) -> String {
        let action = rawInput["action"] as? String
        let interestingKeys = ["app", "appBundleId", "name", "title", "role", "text",
                               "file_path", "path", "url", "command", "menuPath"]
        var parts: [String] = []
        for key in interestingKeys {
            guard let raw = rawInput[key] else { continue }
            let str: String
            if let s = raw as? String { str = s }
            else { str = String(describing: raw) }
            guard !str.isEmpty else { continue }
            // Collapse the app-pointer fields to a single `app:` label
            let label = (key == "appBundleId" || key == "name") ? "app" : key
            parts.append("\(label): \(str.count > 80 ? String(str.prefix(77)) + "…" : str)")
        }
        let args = parts.joined(separator: ", ")
        switch (action, args.isEmpty) {
        case (.some(let a), true): return "\(rawName)(\(a))"
        case (.some(let a), false): return "\(rawName)(\(a), \(args))"
        case (.none, true): return rawName
        case (.none, false): return "\(rawName)(\(args))"
        }
    }

    /// / Post-tool-dispatch handling: append the assistant turn to the / conversation, append tool results on the user
    /// turn, and detect whether / the model implicitly signaled completion via free-text. Returns `true` / if the outer task loop should `break`.
    func finalizeTurnAndDetectCompletion(
        responseContent: [[String: Any]],
        hasToolUse: Bool,
        toolResults: [[String: Any]],
        messages: inout [[String: Any]]
    ) -> Bool {
        // Add assistant response to conversation
        // Guard against empty content — Ollama rejects assistant messages with no content or tool_calls
        let assistantContent: Any = responseContent.isEmpty
            ? "I'll continue with the task." as Any
            : responseContent as Any
        let assistantMsg: [String: Any] = ["role": "assistant", "content": assistantContent]
        messages.append(assistantMsg)
        SessionStore.shared.appendMessage(assistantMsg)

        if hasToolUse && !toolResults.isEmpty {
            let userMsg: [String: Any] = ["role": "user", "content": toolResults]
            messages.append(userMsg)
            SessionStore.shared.appendMessage(userMsg)
            return false
        } else if !hasToolUse {
            // Check if model wrote task_complete/done as text instead of a tool call
            let responseText = responseContent.compactMap { $0["text"] as? String }.joined()
            if responseText.contains("task_complete") || responseText.contains("done(summary") {
                if let match = responseText.range(
                    of: #"(?:task_complete|done)\(summary[=:]\s*"([^"]+)""#,
                    options: .regularExpression
                ) {
                    let raw = String(responseText[match])
                    let summary = raw.replacingOccurrences(
                        of: #"(?:task_complete|done)\(summary[=:]\s*""#,
                        with: "",
                        options: .regularExpression
                    ).replacingOccurrences(of: "\"", with: "")
                    appendLog("✅ Completed: \(summary)")
                }
                flushLog()
                return true
            }
            // Check if model signaled completion via natural language
            let lower = responseText.lowercased()
            let doneSignals = [
                "conclude this task",
                "i'll conclude",
                "task is complete",
                "no further action",
                "nothing more to do",
                "no more content"
            ]
            if doneSignals.contains(where: { lower.contains($0) }) {
                // Ensure LLM Output shows the response
                displayedLLMOutput = rawLLMOutput
                dripDisplayIndex = rawLLMOutput.count
                let summary = String(responseText.prefix(300))
                appendLog("✅ Completed: \(summary)")
                flushLog()
                return true
            }
            // Text-only response (no tool calls) — complete immediately
            if rawLLMOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rawLLMOutput = responseText
            }
            displayedLLMOutput = rawLLMOutput
            dripDisplayIndex = rawLLMOutput.count
            let summary = String(responseText.prefix(300))
            appendLog("✅ Completed: \(summary)")
            flushLog()
            return true
        } else {
            // Check if LLM signaled it's done via text even though it made tool calls
            let allText = responseContent.compactMap { $0["text"] as? String }.joined().lowercased()
            let stopPhrases = [
                "no more content",
                "no further action",
                "task is complete",
                "nothing more to do",
                "task_complete",
                "conclude this task",
                "i'll conclude",
                "feel free to ask",
                "let me know if"
            ]
            if stopPhrases.contains(where: { allText.contains($0) }) {
                return true
            }
            return false
        }
    }
}
