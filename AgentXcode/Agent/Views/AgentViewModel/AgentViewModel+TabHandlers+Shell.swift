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

        switch name {
        case "batch_commands":
            let tabFolder = Self.resolvedWorkingDirectory(tab.projectFolder.isEmpty ? projectFolder : tab.projectFolder)
            let rawCommands = input["commands"] as? String ?? ""
            let commands = rawCommands.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            var batchOutput = ""
            for (idx, rawCmd) in commands.enumerated() {
                let cmd = Self.prependWorkingDirectory(rawCmd, projectFolder: tabFolder)
                if let pathErr = Self.preflightCommand(cmd) {
                    batchOutput += "[\(idx + 1)] $ \(rawCmd)\n\(pathErr)\n\n"
                    continue
                }
                tab.appendLog("🔧 [\(idx + 1)/\(commands.count)] $ \(Self.collapseHeredocs(cmd))")
                tab.flush()
                let result = await executeForTab(command: cmd)
                guard !Task.isCancelled else { return TabToolResult(toolResult: nil, isComplete: false) }
                let output = result.output.isEmpty ? "(no output)" : result.output
                batchOutput += "[\(idx + 1)] $ \(rawCmd)\n"
                if result.status != 0 { batchOutput += "exit code: \(result.status)\n" }
                batchOutput += output + "\n\n"
            }
            let truncated = batchOutput.count > 50_000
                ? String(batchOutput.prefix(50_000)) + "\n...(truncated)"
                : batchOutput
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": truncated],
                isComplete: false
            )

        case "execute_agent_command", "execute_daemon_command":
            let tabFolder = Self.resolvedWorkingDirectory(tab.projectFolder.isEmpty ? projectFolder : tab.projectFolder)
            let command = Self.prependWorkingDirectory(
                input["command"] as? String ?? "", projectFolder: tabFolder)
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

        default:
        let output = await executeNativeTool(name, input: input)
        tab.appendLog(output); tab.flush()
        return tabResult(output, toolId: toolId)
        }
    }
}
