import Foundation
import os.log

private let scriptToolsLog = Logger(subsystem: "Agent.app.toddbruss", category: "ScriptTools")

// MARK: - Script Management Tools Extension
extension AgentViewModel {

    // MARK: - Script Management Tool Handlers

    /// Handle list_agent_scripts tool
    func handleListAgentScripts() async -> String {
        let scripts = scriptService.listScripts()
        let output: String
        if scripts.isEmpty {
            output = "No scripts found in ~/Documents/AgentScript/agents/"
        } else {
            output = scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
        }
        appendLog("🦾 AgentScripts: \(scripts.count) found")
        return output
    }

    /// Handle read_agent_script tool
    func handleReadAgentScript(name: String) async -> String {
        let output = scriptService.readScript(name: name) ?? "Error: script '\(name)' not found."
        appendLog("📖 Read: \(name)")
        appendLog(Self.codeFence(Self.preview(output, lines: readFilePreviewLines), language: "swift"))
        return output
    }

    /// Handle create_agent_script tool
    func handleCreateAgentScript(name: String, content: String) async -> String {
        let output = scriptService.createScript(name: name, content: content)
        appendLog(output)
        return output
    }

    /// Handle update_agent_script tool
    func handleUpdateAgentScript(name: String, content: String) async -> String {
        let output = scriptService.updateScript(name: name, content: content)
        appendLog(output)
        return output
    }

    /// Handle delete_agent_script tool
    func handleDeleteAgentScript(name: String) async -> String {
        let output = scriptService.deleteScript(name: name)
        appendLog(output)
        return output
    }

    /// Handle run_agent_script tool - opens a tab and runs the script
    func handleRunAgentScript(name: String, arguments: String, toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        guard let compileCmd = scriptService.compileCommand(name: name) else {
            let err = "Error: script '\(name)' not found."
            appendLog(err)
            return ["type": "tool_result", "tool_use_id": toolId, "content": err]
        }

        // Reuse existing tab for this script, or create one
        let tab: ScriptTab
        if let existing = scriptTabs.first(where: { $0.scriptName == name }) {
            tab = existing
            selectedTabId = tab.id
            tab.isRunning = true
        } else {
            tab = openScriptTab(scriptName: name)
        }

        // Brief note in main log
        appendLog("Running \(name)... (see tab)")
        flushLog()

        // Step 1: Compile the script dylib via User LaunchAgent (no TCC required)
        tab.appendLog("🦾 Compiling: \(name)")
        tab.flush()

        let compileResult = await executeViaUserAgent(command: compileCmd)

        guard !Task.isCancelled && !tab.isCancelled else {
            tab.isRunning = false
            tab.appendLog("Cancelled.")
            tab.flush()
            return ["type": "tool_result", "tool_use_id": toolId, "content": "Script cancelled by user"]
        }

        if compileResult.status != 0 {
            tab.appendLog("Compile failed (exit code: \(compileResult.status))")
            tab.appendOutput(compileResult.output)
            tab.flush()
            tab.isRunning = false
            let toolOutput = compileResult.output.isEmpty
                ? "(compile failed, exit code: \(compileResult.status))"
                : compileResult.output
            let truncated = toolOutput.count > 10000
                ? String(toolOutput.prefix(10000)) + "\n...(truncated)"
                : toolOutput
            commandsRun.append("run_agent_script: \(name) (compile failed)")
            return ["type": "tool_result", "tool_use_id": toolId, "content": truncated]
        }

        // Step 2: Load and run dylib in Agent!'s process
        tab.appendLog("🦾 Running: \(name) (in-process)")
        tab.flush()

        let cancelFlag = tab._cancelFlag
        let runResult = await scriptService.loadAndRunScript(
            name: name,
            arguments: arguments,
            captureStderr: scriptCaptureStderr,
            isCancelled: { cancelFlag.value }
        ) { [weak tab] chunk in
            Task { @MainActor in
                tab?.appendOutput(chunk)
            }
        }

        tab.isRunning = false
        tab.exitCode = runResult.status
        tab.flush()
        persistScriptTabs()

        guard !Task.isCancelled && !tab.isCancelled else {
            return ["type": "tool_result", "tool_use_id": toolId, "content": "Script cancelled by user"]
        }

        // Summary back in main log
        let statusNote = runResult.status == 0 ? "completed" : "exit code: \(runResult.status)"
        appendLog("\(name) \(statusNote)")
        flushLog()

        let toolOutput = runResult.output.isEmpty
            ? "(no output, exit code: \(runResult.status))"
            : runResult.output
        let truncated = toolOutput.count > 10000
            ? String(toolOutput.prefix(10000)) + "\n...(truncated)"
            : toolOutput
        commandsRun.append("run_agent_script: \(name)")
        return ["type": "tool_result", "tool_use_id": toolId, "content": truncated]
    }

    // MARK: - Saved AppleScript Tools

    /// Handle list_apple_scripts tool
    func handleListAppleScripts() async -> String {
        let scripts = scriptService.listAppleScripts()
        let output = scripts.isEmpty
            ? "No saved AppleScripts in ~/Documents/AgentScript/applescript/"
            : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
        appendLog("🍎 Saved AppleScripts: \(scripts.count) found")
        return output
    }

    /// Handle save_apple_script tool
    func handleSaveAppleScript(name: String, source: String) async -> String {
        let output = scriptService.saveAppleScript(name: name, source: source)
        appendLog("🍎 \(output)")
        return output
    }

    /// Handle delete_apple_script tool
    func handleDeleteAppleScript(name: String) async -> String {
        let output = scriptService.deleteAppleScript(name: name)
        appendLog("🍎 \(output)")
        return output
    }

    /// Handle run_apple_script tool (saved AppleScript)
    func handleRunAppleScriptSaved(name: String, toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        guard let source = scriptService.readAppleScript(name: name) else {
            let err = "Error: AppleScript '\(name)' not found. Use list_apple_scripts first."
            appendLog("🍎 \(err)")
            return ["type": "tool_result", "tool_use_id": toolId, "content": err]
        }

        let tab: ScriptTab
        if let existing = scriptTabs.first(where: { $0.scriptName == "applescript" }) {
            tab = existing
            selectedTabId = tab.id
            tab.isRunning = true
        } else {
            tab = openScriptTab(scriptName: "applescript")
        }
        appendLog("🍎 Running saved: \(name) (see tab)")
        flushLog()
        tab.appendLog("🍎 \(name)")
        tab.flush()

        let result = await Self.offMain {
            NSAppleScriptService.shared.execute(source: source)
        }

        tab.isRunning = false
        tab.exitCode = result.success ? 0 : 1
        if !result.output.isEmpty {
            tab.appendOutput(result.output)
        }
        tab.flush()
        persistScriptTabs()

        let statusNote = result.success ? "completed" : "error"
        appendLog("\(name) \(statusNote)")
        flushLog()
        commandsRun.append("run_apple_script: \(name)")
        return ["type": "tool_result", "tool_use_id": toolId, "content": result.output]
    }

    // MARK: - Saved JavaScript/JXA Tools

    /// Handle list_javascript tool
    func handleListJavaScript() async -> String {
        let scripts = scriptService.listJavaScripts()
        let output = scripts.isEmpty
            ? "No saved JXA scripts in ~/Documents/AgentScript/javascript/"
            : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
        appendLog("🟨 Saved JXA: \(scripts.count) found")
        return output
    }

    /// Handle save_javascript tool
    func handleSaveJavaScript(name: String, source: String) async -> String {
        let output = scriptService.saveJavaScript(name: name, source: source)
        appendLog("🟨 \(output)")
        return output
    }

    /// Handle delete_javascript tool
    func handleDeleteJavaScript(name: String) async -> String {
        let output = scriptService.deleteJavaScript(name: name)
        appendLog("🟨 \(output)")
        return output
    }

    /// Handle run_javascript tool (saved JXA)
    func handleRunJavaScriptSaved(name: String, toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        guard let source = scriptService.readJavaScript(name: name) else {
            let err = "Error: JXA script '\(name)' not found. Use list_javascript first."
            appendLog("🟨 \(err)")
            return ["type": "tool_result", "tool_use_id": toolId, "content": err]
        }

        let escaped = source.replacingOccurrences(of: "'", with: "'\\''")
        let command = "osascript -l JavaScript -e '\(escaped)'"

        let tab: ScriptTab
        if let existing = scriptTabs.first(where: { $0.scriptName == "javascript" }) {
            tab = existing
            selectedTabId = tab.id
            tab.isRunning = true
        } else {
            tab = openScriptTab(scriptName: "javascript")
        }
        appendLog("🟨 Running saved: \(name) (see tab)")
        flushLog()
        tab.appendLog("🟨 \(name)")
        tab.flush()

        let result = await executeTCCStreaming(command: command) { [weak tab] chunk in
            Task { @MainActor in tab?.appendOutput(chunk) }
        }

        tab.isRunning = false
        tab.exitCode = result.status
        tab.flush()
        persistScriptTabs()

        let statusNote = result.status == 0 ? "completed" : "exit code: \(result.status)"
        appendLog("\(name) \(statusNote)")
        flushLog()
        commandsRun.append("run_javascript: \(name)")
        return ["type": "tool_result", "tool_use_id": toolId, "content": result.output.isEmpty ? "(no output)" : result.output]
    }

    // MARK: - Utility Functions

    /// Generate an automatic script name from source content
    nonisolated static func autoScriptName(from source: String) -> String {
        // Extract first non-empty, non-comment line as name hint
        let lines = source.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("--") || trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
                continue
            }
            // Use first 30 chars, sanitized for filename
            let name = String(trimmed.prefix(30))
                .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "_").union(.whitespaces))
            return name.isEmpty ? "script_\(Int(Date().timeIntervalSince1970))" : name
        }
        return "script_\(Int(Date().timeIntervalSince1970))"
    }
}