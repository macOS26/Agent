@preconcurrency import Foundation
import AgentMCP
import os.log

private let mcpLog = Logger(subsystem: AppConstants.subsystem, category: "MCPTools")

// MARK: - MCP Tool Execution
extension AgentViewModel {

    /// Handles MCP tool calls (mcp_ServerName_toolName).
    /// Returns true if this was an MCP tool call, false otherwise.
    @MainActor
    func handleMCPTool(
        name: String,
        input: [String: Any],
        toolId: String,
        appendLog: @escaping @MainActor @Sendable (String) -> Void,
        flushLog: @escaping @MainActor @Sendable () -> Void,
        toolResults: inout [[String: Any]]
    ) async -> Bool {
        guard name.hasPrefix("mcp_") else { return false }

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
            return true
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
    
            return true
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

        return true
    }
}