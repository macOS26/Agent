@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log
import Cocoa

extension AgentViewModel {

    /// Handle AgentScript tool calls for tab tasks.
    func handleTabAgentScriptTool(
        tab: ScriptTab, name: String, input: [String: Any], toolId: String
    ) async -> TabToolResult {

        switch name {
        case "list_agents":
            let output = scriptService.numberedList()
            let count = scriptService.listScripts().count
            tab.appendLog("🦾 Agents: \(count) found")
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )

        case "read_agent":
            let scriptName = scriptService.resolveScriptName(input["name"] as? String ?? "")
            let output = scriptService.readScript(name: scriptName) ?? "Error: script '\(scriptName)' not found."
            tab.appendLog("📖 Read: \(scriptName)")
            tab.appendLog(Self.codeFence(output, language: "swift"))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )

        case "create_agent":
            let scriptName = input["name"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            let output = scriptService.createScript(name: scriptName, content: content)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )

        case "update_agent":
            let scriptName = scriptService.resolveScriptName(input["name"] as? String ?? "")
            let content = input["content"] as? String ?? ""
            let output = scriptService.updateScript(name: scriptName, content: content)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )

        case "delete_agent":
            let scriptName = scriptService.resolveScriptName(input["name"] as? String ?? "")
            let output = scriptService.deleteScript(name: scriptName)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )

        case "combine_agents":
            let sourceA = scriptService.resolveScriptName(input["source_a"] as? String ?? "")
            let sourceB = scriptService.resolveScriptName(input["source_b"] as? String ?? "")
            let target = input["target"] as? String ?? ""
            tab.appendLog("Combining: \(sourceA) + \(sourceB) → \(target)")

            guard let contentA = scriptService.readScript(name: sourceA) else {
                let err = "Error: script '\(sourceA)' not found."
                tab.appendLog(err)
                return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": err], isComplete: false)
            }
            guard let contentB = scriptService.readScript(name: sourceB) else {
                let err = "Error: script '\(sourceB)' not found."
                tab.appendLog(err)
                return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": err], isComplete: false)
            }

            let merged = Self.combineScriptSources(contentA: contentA, contentB: contentB, sourceA: sourceA, sourceB: sourceB)

            let output: String
            if scriptService.readScript(name: target) != nil {
                output = scriptService.updateScript(name: target, content: merged)
            } else {
                output = scriptService.createScript(name: target, content: merged)
            }
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "run_agent":
            let scriptName = scriptService.resolveScriptName(input["name"] as? String ?? "")
            let arguments = input["arguments"] as? String ?? ""
            guard let compileCmd = scriptService.compileCommand(name: scriptName) else {
                let err = "Error: script '\(scriptName)' not found."
                tab.appendLog(err)
                tab.flush()
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": err],
                    isComplete: false
                )
            }

            tab.appendLog("🦾 Compiling: \(scriptName)")
            tab.flush()

            let tabFolder = Self.resolvedWorkingDirectory(tab.projectFolder.isEmpty ? projectFolder : tab.projectFolder)
            let compileResult = await executeForTab(command: compileCmd, projectFolder: tabFolder)
            guard !Task.isCancelled else {
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": "Script cancelled"],
                    isComplete: false
                )
            }

            if compileResult.status != 0 {
                tab.appendLog("Compile failed (exit code: \(compileResult.status))")
                tab.appendOutput(compileResult.output)
                tab.flush()
                let toolOutput = compileResult.output.isEmpty
                    ? "(compile failed, exit code: \(compileResult.status))"
                    : compileResult.output
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": String(toolOutput.prefix(10000))],
                    isComplete: false
                )
            }

            tab.appendLog("🦾 Running: \(scriptName)")
            tab.flush()
            RecentAgentsService.shared.recordRun(agentName: scriptName, arguments: arguments, prompt: arguments.isEmpty ? "run \(scriptName)" : "run \(scriptName) \(arguments)")

            tab.resetLLMStreamCounters()
            let cancelFlag = tab._cancelFlag
            let runResult = await scriptService.loadAndRunScriptViaProcess(
                name: scriptName,
                arguments: arguments,
                captureStderr: scriptCaptureStderr,
                isCancelled: { cancelFlag.value }
            ) { [weak tab] chunk in
                Task { @MainActor in
                    tab?.appendOutput(chunk)
                }
            }

            tab.flush()
            let statusNote = runResult.status == 0 ? "completed" : "exit code: \(runResult.status)"
            tab.appendLog("\(scriptName) \(statusNote)")
            tab.flush()

            let toolOutput = runResult.output.isEmpty
                ? "(no output, exit code: \(runResult.status))"
                : runResult.output
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": String(toolOutput.prefix(10000))],
                isComplete: false
            )

        default:
        let output = await executeNativeTool(name, input: input)
        tab.appendLog(output); tab.flush()
        return tabResult(output, toolId: toolId)
        }
    }
}
