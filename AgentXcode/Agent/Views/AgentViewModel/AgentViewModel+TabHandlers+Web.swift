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

        switch name {
        case "web_open":
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

        case "web_find":
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

        case "web_click":
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

        case "web_type":
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

        case "web_execute_js":
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

        case "web_get_url":
            let browser = input["browser"] as? String
            tab.appendLog("Getting page URL...")
            tab.flush()
            let url = await WebAutomationService.shared.getPageURL(browser: browser)
            tab.appendLog(url)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": url], isComplete: false)

        case "web_get_title":
            let browser = input["browser"] as? String
            tab.appendLog("Getting page title...")
            tab.flush()
            let title = await WebAutomationService.shared.getPageTitle(browser: browser)
            tab.appendLog(title)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": title], isComplete: false)

        case "web_read_content":
            let browser = input["browser"] as? String
            let maxLength = input["max_length"] as? Int ?? 10000
            tab.appendLog("Reading page content...")
            tab.flush()
            let content = await WebAutomationService.shared.readPageContent(browser: browser, maxLength: maxLength)
            tab.appendLog(String(content.prefix(500)) + (content.count > 500 ? "... (\(content.count) chars)" : ""))
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": content], isComplete: false)

        case "web_switch_tab":
            let browser = input["browser"] as? String
            let index = input["index"] as? Int
            let title = input["title"] as? String
            tab.appendLog("Switching tab...")
            tab.flush()
            let output = await WebAutomationService.shared.switchTab(browser: browser, index: index, titleContains: title)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_list_tabs":
            let browser = input["browser"] as? String
            tab.appendLog("Listing tabs...")
            tab.flush()
            let output = await WebAutomationService.shared.listTabs(browser: browser)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_wait_for_element":
            let selector = input["selector"] as? String ?? ""
            let browser = input["browser"] as? String
            let timeout = input["timeout"] as? Double ?? 10.0
            tab.appendLog("Waiting for: \(selector)...")
            tab.flush()
            let output = await WebAutomationService.shared.waitForElement(selector: selector, browser: browser, timeout: timeout)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_scroll_to":
            let selector = input["selector"] as? String ?? ""
            let browser = input["browser"] as? String
            tab.appendLog("Scrolling to: \(selector)...")
            tab.flush()
            let output = await WebAutomationService.shared.scrollToElement(selector: selector, browser: browser)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_select":
            let selector = input["selector"] as? String ?? ""
            let value = input["value"] as? String
            let text = input["text"] as? String
            let index = input["index"] as? Int
            let browser = input["browser"] as? String
            tab.appendLog("Selecting option in: \(selector)...")
            tab.flush()
            let output = await WebAutomationService.shared.selectOption(selector: selector, value: value, text: text, index: index, browser: browser)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_upload":
            let selector = input["selector"] as? String ?? ""
            let browser = input["browser"] as? String
            tab.appendLog("Triggering file upload: \(selector)...")
            tab.flush()
            let output = await WebAutomationService.shared.triggerFileUpload(selector: selector, browser: browser)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_storage":
            let storageType = input["storage_type"] as? String ?? "cookies"
            let key = input["key"] as? String
            let browser = input["browser"] as? String
            tab.appendLog("Reading \(storageType)...")
            tab.flush()
            let output = await WebAutomationService.shared.readStorage(type: storageType, key: key, browser: browser)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_submit":
            let selector = input["selector"] as? String
            let browser = input["browser"] as? String
            tab.appendLog("Submitting form...")
            tab.flush()
            let output = await WebAutomationService.shared.submitForm(selector: selector, browser: browser)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_navigate":
            let action = input["action"] as? String ?? "back"
            let browser = input["browser"] as? String
            tab.appendLog("Navigate: \(action)...")
            tab.flush()
            let output = await WebAutomationService.shared.navigate(action: action, browser: browser)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_list_windows":
            let browser = input["browser"] as? String
            tab.appendLog("Listing windows...")
            tab.flush()
            let output = await WebAutomationService.shared.listWindows(browser: browser)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_switch_window":
            let browser = input["browser"] as? String
            let index = input["index"] as? Int ?? 1
            tab.appendLog("Switching to window \(index)...")
            tab.flush()
            let output = await WebAutomationService.shared.switchWindow(browser: browser, index: index)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_new_window":
            let browser = input["browser"] as? String
            let url = input["url"] as? String
            tab.appendLog("Opening new window...")
            tab.flush()
            let output = await WebAutomationService.shared.newWindow(browser: browser, url: url)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_close_window":
            let browser = input["browser"] as? String
            let index = input["index"] as? Int ?? 1
            tab.appendLog("Closing window \(index)...")
            tab.flush()
            let output = await WebAutomationService.shared.closeWindow(browser: browser, index: index)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_google_search":
            let query = input["query"] as? String ?? ""
            let maxResults = input["max_results"] as? Int ?? 3000
            guard !query.isEmpty else {
                let err = "Error: query is required"
                tab.appendLog(err); tab.flush()
                return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": err], isComplete: false)
            }
            tab.appendLog("🔍 Google search: \(query)...")
            tab.flush()
            let output = await WebAutomationService.shared.safariGoogleSearch(query: query, maxResults: maxResults)
            tab.appendLog(Self.preview(output, lines: 40))
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output], isComplete: false)

        case "web_scan":
            tab.appendLog("Scanning page for interactive elements...")
            tab.flush()
            let elements = await WebAutomationService.shared.scanInteractiveElements()
            tab.appendLog(String(elements.prefix(2000)))
            tab.flush()
            return TabToolResult(toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": elements], isComplete: false)

        default:
        let output = await executeNativeTool(name, input: input)
        tab.appendLog(output); tab.flush()
        return tabResult(output, toolId: toolId)
        }
    }
}
