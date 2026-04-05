@preconcurrency import Foundation
import AgentTools
import AgentLLM

// MARK: - Sub-Agent Spawning

/// Represents an isolated sub-agent execution with its own message history.
@MainActor
final class SubAgent: Identifiable {
    let id = UUID()
    let name: String
    let prompt: String
    let projectFolder: String
    var status: Status = .running
    var result: String = ""
    var task: Task<String, Never>?
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    let startTime = Date()

    enum Status: String {
        case running, completed, failed
    }

    init(name: String, prompt: String, projectFolder: String) {
        self.name = name
        self.prompt = prompt
        self.projectFolder = projectFolder
    }

    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    /// XML notification for parent context (matches Claude Code pattern).
    var notification: String {
        """
        <task-notification>
          <task-id>\(id.uuidString.prefix(8))</task-id>
          <name>\(name)</name>
          <status>\(status.rawValue)</status>
          <result>\(result.prefix(2000))</result>
          <usage>
            <input_tokens>\(inputTokens)</input_tokens>
            <output_tokens>\(outputTokens)</output_tokens>
            <duration_ms>\(Int(duration * 1000))</duration_ms>
          </usage>
        </task-notification>
        """
    }
}

extension AgentViewModel {

    /// Maximum concurrent sub-agents per task.
    static let maxSubAgents = 3

    /// Active sub-agents for the current task.
    var activeSubAgents: [SubAgent] {
        subAgents.filter { $0.status == .running }
    }

    /// Spawn an isolated sub-agent that runs concurrently with the parent task.
    /// Returns immediately with the agent ID. Results arrive via notification.
    func spawnSubAgent(name: String, prompt: String) -> String {
        guard activeSubAgents.count < Self.maxSubAgents else {
            return "Error: Maximum \(Self.maxSubAgents) concurrent sub-agents reached. Wait for one to complete."
        }

        let agent = SubAgent(name: name, prompt: prompt, projectFolder: projectFolder)
        subAgents.append(agent)
        appendLog("🔀 Sub-agent '\(name)' spawned [\(agent.id.uuidString.prefix(8))]")
        flushLog()

        agent.task = Task { [weak self] in
            guard let self else { return "Error: parent deallocated" }
            let result = await self.executeSubAgent(agent)
            return result
        }

        return "Sub-agent '\(name)' spawned (id: \(agent.id.uuidString.prefix(8))). You will receive a <task-notification> when it completes."
    }

    /// Execute a sub-agent's task in isolation using the current provider/model.
    private func executeSubAgent(_ agent: SubAgent) async -> String {
        let provider = selectedProvider
        let modelName = globalModelForProvider(provider)
        let mt = maxTokens

        // Build a minimal service for this sub-agent
        let historyContext = ""  // Sub-agents start with clean context
        let claude: ClaudeService?
        if provider == .claude {
            claude = ClaudeService(apiKey: apiKey, model: selectedModel, historyContext: historyContext, projectFolder: agent.projectFolder, maxTokens: mt)
        } else if provider == .lmStudio && lmStudioProtocol == .anthropic {
            claude = ClaudeService(apiKey: lmStudioAPIKey, model: lmStudioModel, historyContext: historyContext, projectFolder: agent.projectFolder, baseURL: lmStudioEndpoint, maxTokens: mt)
        } else {
            claude = nil
        }
        let openAICompatible: OpenAICompatibleService?
        switch provider {
        case .claude, .ollama, .localOllama, .foundationModel:
            openAICompatible = nil
        case .lmStudio where lmStudioProtocol == .anthropic:
            openAICompatible = nil
        case .vLLM:
            openAICompatible = OpenAICompatibleService(apiKey: apiKeyForProvider(provider), model: modelName, baseURL: vLLMEndpoint, historyContext: historyContext, projectFolder: agent.projectFolder, provider: provider, maxTokens: mt)
        default:
            let url = chatURLForProvider(provider)
            openAICompatible = url.isEmpty ? nil : OpenAICompatibleService(apiKey: apiKeyForProvider(provider), model: modelName, baseURL: url, historyContext: historyContext, projectFolder: agent.projectFolder, provider: provider, maxTokens: mt)
        }
        let ollama: OllamaService?
        switch provider {
        case .ollama:
            ollama = OllamaService(apiKey: ollamaAPIKey, model: ollamaModel, endpoint: ollamaEndpoint, historyContext: historyContext, projectFolder: agent.projectFolder, provider: .ollama)
        case .localOllama:
            ollama = OllamaService(apiKey: "", model: localOllamaModel, endpoint: localOllamaEndpoint, historyContext: historyContext, projectFolder: agent.projectFolder, provider: .localOllama, contextSize: localOllamaContextSize)
        default:
            ollama = nil
        }

        // Set temperature
        claude?.temperature = temperatureForProvider(.claude)
        ollama?.temperature = temperatureForProvider(provider)
        openAICompatible?.temperature = temperatureForProvider(provider)

        // Sub-agent gets read-only tools only (safe for parallel execution)
        let activeGroups: Set<String> = [Tool.Group.core, Tool.Group.work, Tool.Group.code]

        var messages: [[String: Any]] = [
            ["role": "user", "content": agent.prompt]
        ]

        var iterations = 0
        let maxIterations = 15  // Sub-agents have a tighter iteration limit
        var finalResult = ""

        while !Task.isCancelled && iterations < maxIterations {
            iterations += 1

            do {
                let response: (content: [[String: Any]], stopReason: String, inputTokens: Int, outputTokens: Int)
                if let claude {
                    response = try await claude.sendStreaming(messages: messages, activeGroups: activeGroups) { _ in }
                } else if let openAICompatible {
                    let r = try await openAICompatible.sendStreaming(messages: messages, activeGroups: activeGroups) { _ in }
                    response = (r.content, r.stopReason, r.inputTokens, r.outputTokens)
                } else if let ollama {
                    let r = try await ollama.sendStreaming(messages: messages, activeGroups: activeGroups) { _ in }
                    response = (r.content, r.stopReason, r.inputTokens, r.outputTokens)
                } else {
                    agent.status = .failed
                    agent.result = "No LLM service available"
                    return agent.notification
                }

                agent.inputTokens += response.inputTokens
                agent.outputTokens += response.outputTokens

                var toolResults: [[String: Any]] = []
                var hasToolUse = false

                for block in response.content {
                    guard let type = block["type"] as? String else { continue }
                    if type == "text", let text = block["text"] as? String {
                        finalResult = text
                    } else if type == "tool_use" {
                        hasToolUse = true
                        guard let toolId = block["id"] as? String,
                              var name = block["name"] as? String,
                              var input = block["input"] as? [String: Any] else { continue }

                        (name, input) = Self.expandConsolidatedTool(name: name, input: input)

                        if name == "task_complete" {
                            finalResult = input["summary"] as? String ?? finalResult
                            break
                        }

                        // Execute tool (sub-agent shares parent's dispatch)
                        let ctx = ToolContext(toolId: toolId, projectFolder: agent.projectFolder, selectedProvider: selectedProvider, tavilyAPIKey: tavilyAPIKey)
                        var results: [[String: Any]] = []
                        _ = await dispatchTool(name: name, input: input, ctx: ctx, toolResults: &results)
                        toolResults.append(contentsOf: results)
                    }
                }

                let assistantContent: Any = response.content.isEmpty ? "Continuing." as Any : response.content as Any
                messages.append(["role": "assistant", "content": assistantContent])

                if hasToolUse && !toolResults.isEmpty {
                    let capped = Self.truncateToolResults(toolResults)
                    messages.append(["role": "user", "content": capped])
                } else if !hasToolUse {
                    break  // Text-only response = done
                }

            } catch {
                agent.status = .failed
                agent.result = "Error: \(error.localizedDescription)"
                appendLog("🔀 Sub-agent '\(agent.name)' failed: \(error.localizedDescription)")
                flushLog()
                return agent.notification
            }
        }

        agent.status = .completed
        agent.result = String(finalResult.prefix(2000))
        appendLog("🔀 Sub-agent '\(agent.name)' completed (\(agent.inputTokens + agent.outputTokens) tokens, \(String(format: "%.1f", agent.duration))s)")
        flushLog()
        return agent.notification
    }

    /// Collect notifications from completed sub-agents and clear them.
    func collectSubAgentNotifications() -> [String] {
        let completed = subAgents.filter { $0.status != .running }
        let notifications = completed.map(\.notification)
        subAgents.removeAll { $0.status != .running }
        return notifications
    }
}
