import Foundation
import MCPClient
import os.log

private let processLog = Logger(subsystem: "Agent.app.toddbruss", category: "ProcessTools")

// MARK: - Process Execution Tools Extension
extension AgentViewModel {

    // MARK: - Tool Discovery Handlers

    /// Handle list_native_tools tool
    func handleListNativeTools(toolId: String) async -> [String: Any] {
        let prefs = ToolPreferencesService.shared
        let enabled = AgentTools.tools(for: selectedProvider)
            .filter { prefs.isEnabled(selectedProvider, $0.name) }
            .sorted(by: { $0.name < $1.name })
        let output = enabled.map { $0.name }.joined(separator: "\n")
        appendLog("🔧 Native tools: \(enabled.count) enabled")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle list_mcp_tools tool
    func handleListMCPTools(toolId: String) async -> [String: Any] {
        let mcpService = MCPService.shared
        let enabled = mcpService.discoveredTools
            .filter { mcpService.isToolEnabled(serverName: $0.serverName, toolName: $0.name) }
            .sorted(by: { $0.name < $1.name })

        if enabled.isEmpty {
            let output = "No MCP tools enabled."
            appendLog("🔧 MCP tools: 0")
            return ["type": "tool_result", "tool_use_id": toolId, "content": output]
        } else {
            let output = enabled.map { "mcp_\($0.serverName)_\($0.name)" }.joined(separator: "\n")
            appendLog("🔧 MCP tools: \(enabled.count) enabled")
            return ["type": "tool_result", "tool_use_id": toolId, "content": output]
        }
    }

    // MARK: - MCP Tool Execution

    /// Handle MCP tool call
    func handleMCPTool(name: String, input: [String: Any], toolId: String, consecutiveNoTool: inout Int) async -> [String: Any]? {
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
            return ["type": "tool_result", "tool_use_id": toolId, "content": msg]
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
            consecutiveNoTool = 0
            return ["type": "tool_result", "tool_use_id": toolId, "content": mcpOutput]
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
        consecutiveNoTool = 0
        return ["type": "tool_result", "tool_use_id": toolId, "content": mcpOutput]
    }
}
