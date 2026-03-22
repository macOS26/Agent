@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log

private let taskLog = Logger(subsystem: "Agent.app.toddbruss", category: "TaskExecutionCore")

// MARK: - Core Task Execution

extension AgentViewModel {
    
    // MARK: - Native Tool Handler (Apple AI)
    
    /// Executes a tool call from Apple AI's Foundation Models native tool system.
    /// Routes to the same execution logic as TaskExecution tool handlers.
    func executeNativeTool(_ name: String, input: sending [String: Any]) async -> String {
        let pf = projectFolder
        NativeToolContext.toolCallCount += 1
        appendLog("🔧 \(name)")
        flushLog()
        
        // Prevent infinite tool call loops — force completion after max calls
        if name != "task_complete" && NativeToolContext.toolCallCount > NativeToolContext.maxToolCalls {
            NativeToolContext.taskCompleteSummary = "Stopped: too many tool calls"
            return "Error: too many tool calls. Call task_complete now."
        }
        
        // Shell commands - route based on TCC requirements
        if name == "execute_agent_command" || name == "execute_daemon_command" {
            let cmd = input["command"] as? String ?? ""
            let command = Self.prependWorkingDirectory(cmd, projectFolder: pf)
            let isPrivileged = (name == "execute_daemon_command") && rootEnabled
            
            let result: (status: Int32, output: String)
            if isPrivileged {
                // Root commands → LaunchDaemon via XPC
                result = await helperService.execute(command: command)
            } else if Self.needsTCCPermissions(command) {
                // TCC commands → Agent process (inherits TCC permissions)
                result = await executeTCC(command: command)
            } else {
                // Non-TCC, non-root commands → User LaunchAgent via XPC
                result = await executeViaUserAgent(command: command)
            }
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }
        
        // Try script execution tools first
        let scriptExecutionResult = await handleScriptExecutionTool(name, input: input)
        if !scriptExecutionResult.isEmpty {
            return scriptExecutionResult
        }
        
        // Try script management tools
        let scriptManagementResult = await handleScriptManagementTool(name, input: input)
        if !scriptManagementResult.isEmpty {
            return scriptManagementResult
        }
        
        // Try file operations
        let fileOperationResult = await handleFileOperationTool(name, input: input)
        if !fileOperationResult.isEmpty {
            return fileOperationResult
        }
        
        // Try git operations
        let gitOperationResult = await handleGitOperationTool(name, input: input)
        if !gitOperationResult.isEmpty {
            return gitOperationResult
        }
        
        // Try web automation
        let webAutomationResult = await handleWebAutomationTool(name, input: input)
        if !webAutomationResult.isEmpty {
            return webAutomationResult
        }
        
        // Try Selenium
        let seleniumResult = await handleSeleniumTool(name, input: input)
        if !seleniumResult.isEmpty {
            return seleniumResult
        }
        
        // Tool discovery
        if name == "list_native_tools" {
            let prefs = ToolPreferencesService.shared
            return AgentTools.tools(for: selectedProvider)
                .filter { prefs.isEnabled(selectedProvider, $0.name) }
                .sorted { $0.name < $1.name }
                .map { $0.name }
                .joined(separator: "\n")
        }
        if name == "list_mcp_tools" {
            let mcp = MCPService.shared
            let enabled = mcp.enabledServers.flatMap { server in
                server.tools.map { "mcp_\(server.name)_\($0.name)" }
            }
            return enabled.isEmpty ? "No MCP tools enabled" : enabled.joined(separator: "\n")
        }
        
        // Apple Event query — flat keys wrapped into single operation
        if name == "apple_event_query" {
            let bundleID = input["bundle_id"] as? String ?? ""
            let operations: [[String: Any]]
            if let ops = input["operations"] as? [[String: Any]] {
                operations = ops // legacy nested format still works
            } else if let action = input["action"] as? String {
                var op: [String: Any] = ["action": action]
                if let key = input["key"] as? String { op["key"] = key }
                if let props = input["properties"] as? String {
                    op["properties"] = props.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
                if let limit = input["limit"] as? Int { op["limit"] = limit }
                if let index = input["index"] as? Int { op["index"] = index }
                if let method = input["method"] as? String { op["method"] = method }
                if let arg = input["arg"] as? String { op["arg"] = arg }
                if let predicate = input["predicate"] as? String { op["predicate"] = predicate }
                operations = [op]
            } else {
                return "Error: action is required"
            }
            let opsData = try? JSONSerialization.data(withJSONObject: operations)
            return await Self.offMain {
                guard let data = opsData,
                      let ops = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    return "Error: failed to process operations"
                }
                return AppleEventService.shared.execute(bundleID: bundleID, operations: ops)
            }
        }
        
        // Task complete — signal via NativeToolContext so the task loop can detect it
        if name == "task_complete" {
            let summary = input["summary"] as? String ?? "Done"
            NativeToolContext.taskCompleteSummary = summary
            return "Task complete: \(summary)"
        }
        
        // Fallback
        return "Tool \(name) not implemented for Apple AI"
    }
}