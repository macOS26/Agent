//
//  AgentViewModel+TaskExecution+SavedScripts.swift
//  Agent
//
//  Saved scripts (AppleScript and JXA) management tools
//

import Foundation

// MARK: - Saved Script Tools

extension AgentViewModel {
    
    /// Handles saved script management tools (AppleScript and JXA)
    func handleSavedScriptTool(name: String, input: [String: Any]) async -> String {
        // Saved AppleScripts
        if name == "list_apple_scripts" {
            let scripts = scriptService.listAppleScripts()
            return scripts.isEmpty ? "No saved AppleScripts" : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
        }
        if name == "save_apple_script" {
            return scriptService.saveAppleScript(name: input["name"] as? String ?? "", source: input["source"] as? String ?? "")
        }
        if name == "delete_apple_script" {
            return scriptService.deleteAppleScript(name: input["name"] as? String ?? "")
        }
        if name == "run_apple_script" {
            let scriptName = input["name"] as? String ?? ""
            guard let source = scriptService.readAppleScript(name: scriptName) else {
                return "Error: AppleScript '\(scriptName)' not found. Use list_apple_scripts first."
            }
            let result = await MainActor.run { () -> String in
                var err: NSDictionary?
                guard let script = NSAppleScript(source: source) else { return "Error creating script" }
                let out = script.executeAndReturnError(&err)
                if let e = err { return "AppleScript error: \(e)" }
                return out.stringValue ?? "(no output)"
            }
            return result
        }
        
        // Saved JavaScript/JXA
        if name == "list_javascript" {
            let scripts = scriptService.listJavaScripts()
            return scripts.isEmpty ? "No saved JXA scripts" : scripts.map { "\($0.name) (\($0.size) bytes)" }.joined(separator: "\n")
        }
        if name == "save_javascript" {
            return scriptService.saveJavaScript(name: input["name"] as? String ?? "", source: input["source"] as? String ?? "")
        }
        if name == "delete_javascript" {
            return scriptService.deleteJavaScript(name: input["name"] as? String ?? "")
        }
        if name == "run_javascript" {
            let scriptName = input["name"] as? String ?? ""
            guard let source = scriptService.readJavaScript(name: scriptName) else {
                return "Error: JXA script '\(scriptName)' not found. Use list_javascript first."
            }
            let escaped = source.replacingOccurrences(of: "'", with: "'\\''")
            let result = await Self.executeTCCStreaming(command: "osascript -l JavaScript -e '\(escaped)'") { _ in }
            return result.output.isEmpty ? "(no output, exit \(result.status))" : result.output
        }
        
        return "Error: Unknown saved script tool: \(name)"
    }
}