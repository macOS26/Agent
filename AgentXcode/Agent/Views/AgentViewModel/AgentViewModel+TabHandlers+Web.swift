@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log
import Cocoa

extension AgentViewModel {

    /// Handle Web tool calls for tab tasks.
    func handleTabWebTool(
        tab: ScriptTab, name: String, input: [String: Any], toolId: String
    ) async -> TabToolResult {

        if name == "web_open" {
            guard let urlString = input["url"] as? String,
                  let url = URL(string: urlString) else {
                let errorMsg = "Error: Invalid or missing URL"
                tab.appendLog(errorMsg)
                return TabToolResult(
                    toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": errorMsg],
                    isComplete: false
                )
            }
            let browserStr = input["browser"] as? String ?? "safari"
            let browser = WebAutomationService.BrowserType(rawValue: browserStr) ?? .safari
            tab.appendLog("Opening \(urlString) in \(browser.rawValue)...")
            tab.flush()
            do {
                let output = try await WebAutomationService.shared.open(url: url, browser: browser)
                tab.appendLog(output)
            } catch {
                tab.appendLog("Error: \(error.localizedDescription)")
            }
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": tab.logBuffer],
                isComplete: false
            )
        }

        if name == "web_find" {
            let selector = input["selector"] as? String ?? ""
            let strategyStr = input["strategy"] as? String ?? "auto"
            let strategy = SelectorStrategy(rawValue: strategyStr) ?? .auto
            let timeout = input["timeout"] as? Double ?? 10.0
            let fuzzyThreshold = input["fuzzyThreshold"] as? Double ?? 0.6
            let appBundleId = input["appBundleId"] as? String
            tab.appendLog("Finding element: \(selector)...")
            tab.flush()
            do {
                let output = try await WebAutomationService.shared.findElement(
                    selector: selector, strategy: strategy, timeout: timeout,
                    fuzzyThreshold: fuzzyThreshold, appBundleId: appBundleId
                )
                if let jsonData = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
                   let jsonStr = String(data: jsonData, encoding: .utf8) {
                    tab.appendLog(jsonStr)
                } else {
                    tab.appendLog("Found element: \(output)")
                }
            } catch {
                tab.appendLog("Error: \(error.localizedDescription)")
            }
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": tab.logBuffer],
                isComplete: false
            )
        }

        if name == "web_click" {
            let selector = input["selector"] as? String ?? ""
            let strategyStr = input["strategy"] as? String ?? "auto"
            let strategy = SelectorStrategy(rawValue: strategyStr) ?? .auto
            let appBundleId = input["appBundleId"] as? String
            tab.appendLog("Clicking element: \(selector)...")
            tab.flush()
            do {
                let output = try await WebAutomationService.shared.click(
                    selector: selector, strategy: strategy, appBundleId: appBundleId
                )
                tab.appendLog(output)
            } catch {
                tab.appendLog("Error: \(error.localizedDescription)")
            }
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": tab.logBuffer],
                isComplete: false
            )
        }

        if name == "web_type" {
            let selector = input["selector"] as? String ?? ""
            let text = input["text"] as? String ?? ""
            let strategyStr = input["strategy"] as? String ?? "auto"
            let strategy = SelectorStrategy(rawValue: strategyStr) ?? .auto
            let verify = input["verify"] as? Bool ?? true
            let appBundleId = input["appBundleId"] as? String
            tab.appendLog("Typing \(text.count) chars into: \(selector)...")
            tab.flush()
            do {
                let output = try await WebAutomationService.shared.type(
                    text: text, selector: selector, strategy: strategy, verify: verify, appBundleId: appBundleId
                )
                tab.appendLog(output)
            } catch {
                tab.appendLog("Error: \(error.localizedDescription)")
            }
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": tab.logBuffer],
                isComplete: false
            )
        }

        if name == "web_execute_js" {
            let script = input["script"] as? String ?? ""
            let browser = input["browser"] as? String
            tab.appendLog("Executing JavaScript...")
            tab.flush()
            do {
                let output = try await WebAutomationService.shared.executeJavaScript(script: script, browser: browser)
                tab.appendLog(output as? String ?? "Script executed")
            } catch {
                tab.appendLog("Error: \(error.localizedDescription)")
            }
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": tab.logBuffer],
                isComplete: false
            )
        }

        if name == "web_get_url" || name == "web_get_title" {
            let action = name == "web_get_url" ? "getUrl" : "getTitle"
            tab.appendLog("\(name == "web_get_url" ? "Getting URL" : "Getting title")...")
            tab.flush()
            let args = "{\"action\":\"\(action)\"}"
            // Run Selenium agent script
            guard let compileCmd = scriptService.compileCommand(name: "Selenium") else {
                let err = "Error: Selenium script not found"
                tab.appendLog(err)
                return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": err], isComplete: false)
            }
            let compileResult = await executeForTab(command: compileCmd)
            if compileResult.status != 0 {
                tab.appendLog("Compile failed: \(compileResult.output)")
                return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": compileResult.output], isComplete: false)
            }
            let cancelFlag = tab._cancelFlag
            let result = await scriptService.loadAndRunScriptViaProcess(name: "Selenium", arguments: args, captureStderr: false, isCancelled: { cancelFlag.value }) { chunk in }
            tab.appendLog(result.output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": result.output], isComplete: false)
        }

        // Fallback
        let output = await executeNativeTool(name, input: input)
        tab.appendLog(output); tab.flush()
        return tabResult(output, toolId: toolId)
    }
}
