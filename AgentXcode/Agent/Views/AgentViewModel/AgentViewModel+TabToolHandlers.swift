@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log
import Cocoa

extension AgentViewModel {

    /// Helper to create a standard non-completing tool result.
    func tabResult(_ output: String, toolId: String) -> TabToolResult {
        TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)
    }

    /// Dispatch tab tool calls to group handlers.
    func handleTabToolCallBody(
        tab: ScriptTab, name: String, input: [String: Any], toolId: String
    ) async -> TabToolResult {
        switch name {
        // Core
        case "task_complete", "plan_mode":
            return await handleTabCoreTool(tab: tab, name: name, input: input, toolId: toolId)
        // File Manager
        case "read_file", "write_file", "edit_file", "create_diff", "apply_diff", "list_files", "search_files", "read_dir":
            return await handleTabFileManagerTool(tab: tab, name: name, input: input, toolId: toolId)
        // Git
        case "git_status", "git_diff", "git_log", "git_commit", "git_diff_patch", "git_branch":
            return await handleTabGitTool(tab: tab, name: name, input: input, toolId: toolId)
        // Agent Scripts
        case "list_agent_scripts", "read_agent_script", "create_agent_script", "update_agent_script",
             "delete_agent_script", "combine_agent_scripts", "run_agent_script":
            return await handleTabAgentScriptTool(tab: tab, name: name, input: input, toolId: toolId)
        // Shell
        case "execute_agent_command", "execute_daemon_command":
            return await handleTabShellTool(tab: tab, name: name, input: input, toolId: toolId)
        // Automation
        case "run_applescript", "run_osascript", "apple_event_query", "lookup_sdef":
            return await handleTabAutomationTool(tab: tab, name: name, input: input, toolId: toolId)
        // Accessibility (prefix match via default + where)
        case let n where n.hasPrefix("ax_"):
            return await handleTabAccessibilityTool(tab: tab, name: name, input: input, toolId: toolId)
        // Web (prefix match)
        case let n where n.hasPrefix("web_"):
            return await handleTabWebTool(tab: tab, name: name, input: input, toolId: toolId)
        // Selenium (prefix match)
        case let n where n.hasPrefix("selenium_"):
            return await handleTabSeleniumTool(tab: tab, name: name, input: input, toolId: toolId)
        // Xcode (prefix match)
        case let n where n.hasPrefix("xcode_"):
            let output = await executeNativeTool(name, input: input)
            tab.appendLog(output); tab.flush()
            return tabResult(output, toolId: toolId)
        // Fallback
        default:
            let output = await executeNativeTool(name, input: input)
            tab.appendLog(output); tab.flush()
            return tabResult(output, toolId: toolId)
        }
    }
}
