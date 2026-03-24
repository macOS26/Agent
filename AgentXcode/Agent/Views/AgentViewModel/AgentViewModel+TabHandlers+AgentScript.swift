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

        if name == "list_agent_scripts" {
            let scripts = scriptService.listScripts()
            let output = scripts.isEmpty
                ? "No scripts found" : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
            tab.appendLog("🦾 AgentScripts: \(scripts.count) found")
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        if name == "read_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            let output = scriptService.readScript(name: scriptName) ?? "Error: script '\(scriptName)' not found."
            tab.appendLog("📖 Read: \(scriptName)")
            tab.appendLog(Self.codeFence(output, language: "swift"))
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        if name == "create_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            let output = scriptService.createScript(name: scriptName, content: content)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        if name == "update_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            let output = scriptService.updateScript(name: scriptName, content: content)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        if name == "delete_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            let output = scriptService.deleteScript(name: scriptName)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        if name == "combine_agent_scripts" {
            let sourceA = input["source_a"] as? String ?? ""
            let sourceB = input["source_b"] as? String ?? ""
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
        }

        if name == "run_agent_script" {
            let scriptName = input["name"] as? String ?? ""
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

            let compileResult = await executeForTab(command: compileCmd)
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
        }

        // Fallback
        let output = await executeNativeTool(name, input: input)
        tab.appendLog(output); tab.flush()
        return tabResult(output, toolId: toolId)
    }
}
