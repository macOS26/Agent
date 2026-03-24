@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log
import Cocoa

extension AgentViewModel {

    /// Handle Shell tool calls for tab tasks.
    func handleTabShellTool(
        tab: ScriptTab, name: String, input: [String: Any], toolId: String
    ) async -> TabToolResult {

        if name == "execute_daemon_command" || name == "execute_agent_command" {
            let command = Self.prependWorkingDirectory(
                input["command"] as? String ?? "", projectFolder: projectFolder)
            if let pathErr = Self.preflightCommand(command) {
                tab.appendLog(pathErr)
                tab.flush()
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": pathErr],
                    isComplete: false
                )
            }
            let isPrivileged = (name == "execute_daemon_command") && rootEnabled
            tab.appendLog("\(isPrivileged ? "🔴 #" : "🔧 $") \(Self.collapseHeredocs(command))")
            tab.flush()

            let result: (status: Int32, output: String)
            if isPrivileged {
                // Root commands → LaunchDaemon via XPC
                result = await helperService.execute(command: command)
            } else if Self.needsTCCPermissions(command) {
                // TCC commands → Agent process (inherits TCC permissions)
                result = await Self.executeTCC(command: command)
            } else {
                // Non-TCC, non-root commands → User LaunchAgent via XPC
                result = await executeForTab(command: command)
            }

            guard !Task.isCancelled else { return TabToolResult(toolResult: nil, isComplete: false) }

            if result.status != 0 {
                tab.appendLog("exit code: \(result.status)")
            }

            let toolOutput: String
            if result.output.isEmpty {
                toolOutput = "(no output, exit code: \(result.status))"
            } else {
                toolOutput = result.output
            }

            let truncated = toolOutput.count > 50_000
                ? String(toolOutput.prefix(50_000)) + "\n...(truncated)"
                : toolOutput

            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": truncated],
                isComplete: false
            )
        }

        // Fallback
        let output = await executeNativeTool(name, input: input)
        tab.appendLog(output); tab.flush()
        return tabResult(output, toolId: toolId)
    }
}
