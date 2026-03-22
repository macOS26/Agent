@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log

private let taskLog = Logger(subsystem: "Agent.app.toddbruss", category: "ScriptManagement")

// MARK: - Script Management Tools

extension AgentViewModel {
    
    // MARK: - Script Management for Apple AI
    
    /// Handle script management tool calls for Apple AI
    func handleScriptManagementTool(_ name: String, input: sending [String: Any]) async -> String {
        // list_agent_scripts
        if name == "list_agent_scripts" {
            let scripts = scriptService.listScripts()
            return scripts.isEmpty ? "No scripts found" : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
        }
        
        // run_agent_script
        if name == "run_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            guard let cmd = scriptService.compileCommand(name: scriptName) else {
                return "Error: script '\(scriptName)' not found"
            }
            var fullCmd = cmd
            if let args = input["arguments"] as? String {
                fullCmd = "AGENT_SCRIPT_ARGS='\(args)' \(cmd)"
            }
            let result = await executeViaUserAgent(command: fullCmd)
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }
        
        // read_agent_script
        if name == "read_agent_script" {
            return scriptService.readScript(name: input["name"] as? String ?? "") ?? "Not found"
        }
        
        // create_agent_script / update_agent_script
        if name == "create_agent_script" || name == "update_agent_script" {
            return scriptService.createScript(name: input["name"] as? String ?? "", content: input["content"] as? String ?? "")
        }
        
        // delete_agent_script
        if name == "delete_agent_script" {
            return scriptService.deleteScript(name: input["name"] as? String ?? "")
        }
        
        // list_apple_scripts
        if name == "list_apple_scripts" {
            let scripts = scriptService.listAppleScripts()
            return scripts.isEmpty ? "No AppleScripts found" : scripts.joined(separator: "\n")
        }
        
        // save_apple_script
        if name == "save_apple_script" {
            let scriptName = input["name"] as? String ?? ""
            let source = input["source"] as? String ?? ""
            return scriptService.saveAppleScript(name: scriptName, source: source)
        }
        
        // delete_apple_script
        if name == "delete_apple_script" {
            let scriptName = input["name"] as? String ?? ""
            return scriptService.deleteAppleScript(name: scriptName)
        }
        
        // run_apple_script
        if name == "run_apple_script" {
            let scriptName = input["name"] as? String ?? ""
            return scriptService.runAppleScript(name: scriptName)
        }
        
        // list_javascript
        if name == "list_javascript" {
            let scripts = scriptService.listJavaScripts()
            return scripts.isEmpty ? "No JavaScript files found" : scripts.joined(separator: "\n")
        }
        
        // save_javascript
        if name == "save_javascript" {
            let scriptName = input["name"] as? String ?? ""
            let source = input["source"] as? String ?? ""
            return scriptService.saveJavaScript(name: scriptName, source: source)
        }
        
        // delete_javascript
        if name == "delete_javascript" {
            let scriptName = input["name"] as? String ?? ""
            return scriptService.deleteJavaScript(name: scriptName)
        }
        
        // run_javascript
        if name == "run_javascript" {
            let scriptName = input["name"] as? String ?? ""
            return scriptService.runJavaScript(name: scriptName)
        }
        
        // Tool not found in script management
        return ""
    }
    
    // MARK: - AppleScript and JavaScript Execution for Apple AI
    
    /// Handle AppleScript and JavaScript execution tool calls for Apple AI
    func handleScriptExecutionTool(_ name: String, input: sending [String: Any]) async -> String {
        // AppleScript (NSAppleScript in-process with TCC)
        if name == "run_applescript" {
            let source = (input["source"] as? String ?? "")
            let result = await MainActor.run { () -> (String, Bool) in
                var err: NSDictionary?
                guard let script = NSAppleScript(source: source) else { return ("Error", false) }
                let out = script.executeAndReturnError(&err)
                if let e = err { return ("AppleScript error: \(e)", false) }
                return (out.stringValue ?? "(no output)", true)
            }
            if result.1 {
                let _ = scriptService.saveAppleScript(name: Self.autoScriptName(from: source), source: source)
            }
            return result.0
        }
        
        // osascript (runs osascript CLI in-process with TCC)
        if name == "run_osascript" {
            let script = input["script"] as? String ?? input["command"] as? String ?? ""
            let escaped = script.replacingOccurrences(of: "'", with: "'\\''")
            let command = "osascript -e '\(escaped)'"
            let result = await executeLocalStreaming(command: command) { _ in }
            if result.status == 0 {
                let _ = scriptService.saveAppleScript(name: Self.autoScriptName(from: script), source: script)
            }
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }
        
        // JavaScript for Automation (JXA via osascript -l JavaScript)
        if name == "execute_javascript" {
            let script = input["source"] as? String ?? input["script"] as? String ?? ""
            let escaped = script.replacingOccurrences(of: "'", with: "'\\''")
            let command = "osascript -l JavaScript -e '\(escaped)'"
            let result = await executeLocalStreaming(command: command) { _ in }
            if result.status == 0 {
                let _ = scriptService.saveJavaScript(name: Self.autoScriptName(from: script), source: script)
            }
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }
        
        // Tool not found in script execution
        return ""
    }
    
    // MARK: - Script Management for Other LLM Providers
    
    /// Handle script management tool calls for other LLM providers (Claude, Ollama, etc.)
    func handleScriptManagementToolForLLM(_ name: String, input: sending [String: Any], toolId: String) async -> (output: String, commandsRun: [String]) {
        var commandsRun: [String] = []
        var output = ""
        
        if name == "list_agent_scripts" {
            appendLog("📜 List AgentScripts")
            let scripts = scriptService.listScripts()
            output = scripts.isEmpty ? "No scripts found" : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
            appendLog(output)
        }
        
        else if name == "read_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            appendLog("📄 Read AgentScript: \(scriptName)")
            output = scriptService.readScript(name: scriptName) ?? "Not found"
            let lang = "swift"
            appendLog(Self.codeFence(Self.preview(output, lines: readFilePreviewLines), language: lang))
        }
        
        else if name == "create_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            appendLog("➕ Create AgentScript: \(scriptName)")
            output = scriptService.createScript(name: scriptName, content: content)
            appendLog(output)
            commandsRun.append("create_agent_script: \(scriptName)")
        }
        
        else if name == "update_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            appendLog("✏️ Update AgentScript: \(scriptName)")
            output = scriptService.createScript(name: scriptName, content: content)
            appendLog(output)
            commandsRun.append("update_agent_script: \(scriptName)")
        }
        
        else if name == "delete_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            appendLog("🗑️ Delete AgentScript: \(scriptName)")
            output = scriptService.deleteScript(name: scriptName)
            appendLog(output)
            commandsRun.append("delete_agent_script: \(scriptName)")
        }
        
        else if name == "run_agent_script" {
            let scriptName = input["name"] as? String ?? ""
            let args = input["arguments"] as? String ?? ""
            appendLog("▶️ Run AgentScript: \(scriptName)")
            output = await scriptService.loadAndRunScript(name: scriptName, arguments: args, captureStderr: false, isCancelled: nil) { chunk in
                self.appendRawOutput(chunk)
            }.output
            commandsRun.append("run_agent_script: \(scriptName)")
        }
        
        // AppleScript management
        else if name == "list_apple_scripts" {
            appendLog("📜 List AppleScripts")
            let scripts = scriptService.listAppleScripts()
            output = scripts.isEmpty ? "No AppleScripts found" : scripts.joined(separator: "\n")
            appendLog(output)
        }
        
        else if name == "save_apple_script" {
            let scriptName = input["name"] as? String ?? ""
            let source = input["source"] as? String ?? ""
            appendLog("💾 Save AppleScript: \(scriptName)")
            output = scriptService.saveAppleScript(name: scriptName, source: source)
            appendLog(output)
            commandsRun.append("save_apple_script: \(scriptName)")
        }
        
        else if name == "delete_apple_script" {
            let scriptName = input["name"] as? String ?? ""
            appendLog("🗑️ Delete AppleScript: \(scriptName)")
            output = scriptService.deleteAppleScript(name: scriptName)
            appendLog(output)
            commandsRun.append("delete_apple_script: \(scriptName)")
        }
        
        else if name == "run_apple_script" {
            let scriptName = input["name"] as? String ?? ""
            appendLog("▶️ Run AppleScript: \(scriptName)")
            output = scriptService.runAppleScript(name: scriptName)
            appendLog(output)
            commandsRun.append("run_apple_script: \(scriptName)")
        }
        
        // JavaScript management
        else if name == "list_javascript" {
            appendLog("📜 List JavaScript files")
            let scripts = scriptService.listJavaScripts()
            output = scripts.isEmpty ? "No JavaScript files found" : scripts.joined(separator: "\n")
            appendLog(output)
        }
        
        else if name == "save_javascript" {
            let scriptName = input["name"] as? String ?? ""
            let source = input["source"] as? String ?? ""
            appendLog("💾 Save JavaScript: \(scriptName)")
            output = scriptService.saveJavaScript(name: scriptName, source: source)
            appendLog(output)
            commandsRun.append("save_javascript: \(scriptName)")
        }
        
        else if name == "delete_javascript" {
            let scriptName = input["name"] as? String ?? ""
            appendLog("🗑️ Delete JavaScript: \(scriptName)")
            output = scriptService.deleteJavaScript(name: scriptName)
            appendLog(output)
            commandsRun.append("delete_javascript: \(scriptName)")
        }
        
        else if name == "run_javascript" {
            let scriptName = input["name"] as? String ?? ""
            appendLog("▶️ Run JavaScript: \(scriptName)")
            output = scriptService.runJavaScript(name: scriptName)
            appendLog(output)
            commandsRun.append("run_javascript: \(scriptName)")
        }
        
        return (output, commandsRun)
    }
}