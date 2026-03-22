@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log

private let taskLog = Logger(subsystem: "Agent.app.toddbruss", category: "WebAutomation")

// MARK: - Web Automation Tools

extension AgentViewModel {
    
    // MARK: - Web Automation (Phase 2) for Apple AI
    
    /// Handle web automation tool calls
    func handleWebAutomationTool(_ name: String, input: sending [String: Any]) async -> String {
        // web_open
        if name == "web_open" {
            guard let urlString = input["url"] as? String,
                  let url = URL(string: urlString) else {
                return "Error: Invalid or missing URL"
            }
            let browserStr = input["browser"] as? String ?? "safari"
            let browser = WebAutomationService.BrowserType(rawValue: browserStr) ?? .safari
            do {
                return try await WebAutomationService.shared.open(url: url, browser: browser)
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }
        
        // web_find
        if name == "web_find" {
            let selector = input["selector"] as? String ?? ""
            let strategyStr = input["strategy"] as? String ?? "auto"
            let strategy = SelectorStrategy(rawValue: strategyStr) ?? .auto
            let timeout = input["timeout"] as? Double ?? 10.0
            let fuzzyThreshold = input["fuzzyThreshold"] as? Double ?? 0.6
            let appBundleId = input["appBundleId"] as? String
            do {
                let output = try await WebAutomationService.shared.findElement(
                    selector: selector, strategy: strategy, timeout: timeout,
                    fuzzyThreshold: fuzzyThreshold, appBundleId: appBundleId
                )
                if let jsonData = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
                   let jsonStr = String(data: jsonData, encoding: .utf8) {
                    return jsonStr
                }
                return "Found element: \(output)"
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }
        
        // web_click
        if name == "web_click" {
            let selector = input["selector"] as? String ?? ""
            let strategyStr = input["strategy"] as? String ?? "auto"
            let strategy = SelectorStrategy(rawValue: strategyStr) ?? .auto
            let appBundleId = input["appBundleId"] as? String
            do {
                return try await WebAutomationService.shared.click(
                    selector: selector, strategy: strategy, appBundleId: appBundleId
                )
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }
        
        // web_type
        if name == "web_type" {
            let selector = input["selector"] as? String ?? ""
            let text = input["text"] as? String ?? ""
            let strategyStr = input["strategy"] as? String ?? "auto"
            let strategy = SelectorStrategy(rawValue: strategyStr) ?? .auto
            let verify = input["verify"] as? Bool ?? true
            let appBundleId = input["appBundleId"] as? String
            do {
                return try await WebAutomationService.shared.type(
                    text: text, selector: selector, strategy: strategy, verify: verify, appBundleId: appBundleId
                )
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }
        
        // web_execute_js
        if name == "web_execute_js" {
            let script = input["script"] as? String ?? ""
            let browser = input["browser"] as? String
            do {
                let result = try await WebAutomationService.shared.executeJavaScript(script: script, browser: browser)
                return result as? String ?? "Script executed"
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }
        
        // web_get_url / web_get_title (via Selenium AgentScript)
        if name == "web_get_url" || name == "web_get_title" {
            let action = name == "web_get_url" ? "getUrl" : "getTitle"
            let args = "{\"action\":\"\(action)\"}"
            // Run Selenium via compile and execute (compile via User LaunchAgent)
            guard let compileCmd = scriptService.compileCommand(name: "Selenium") else {
                return "Error: Selenium script not found"
            }
            let compileResult = await executeViaUserAgent(command: compileCmd)
            if compileResult.status != 0 {
                return "Compile failed: \(compileResult.output)"
            }
            let result = await scriptService.loadAndRunScript(name: "Selenium", arguments: args, captureStderr: false, isCancelled: nil) { _ in }
            return result.output
        }
        
        // Tool not found in web automation
        return ""
    }
    
    // MARK: - Selenium WebDriver for Apple AI (via AgentScript)
    
    /// Handle Selenium WebDriver tool calls
    func handleSeleniumTool(_ name: String, input: sending [String: Any]) async -> String {
        // Helper for Selenium operations (compile via User LaunchAgent)
        func runSeleniumNative(action: String, args: String) async -> String {
            let fullArgs = args.isEmpty ? "{\"action\":\"\(action)\"}" : args
            guard let compileCmd = scriptService.compileCommand(name: "Selenium") else {
                return "Error: Selenium script not found"
            }
            let compileResult = await executeViaUserAgent(command: compileCmd)
            if compileResult.status != 0 {
                return "Compile failed: \(compileResult.output)"
            }
            let result = await scriptService.loadAndRunScript(name: "Selenium", arguments: fullArgs, captureStderr: false, isCancelled: nil) { _ in }
            return result.output
        }
        
        // selenium_start
        if name == "selenium_start" {
            let browser = input["browser"] as? String ?? "safari"
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"start\",\"browser\":\"\(browser)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "start", args: args)
        }
        
        // selenium_stop
        if name == "selenium_stop" {
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"stop\",\"port\":\(port)}"
            return await runSeleniumNative(action: "stop", args: args)
        }
        
        // selenium_navigate
        if name == "selenium_navigate" {
            guard let url = input["url"] as? String else { return "Error: URL required" }
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"navigate\",\"url\":\"\(url)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "navigate", args: args)
        }
        
        // selenium_find
        if name == "selenium_find" {
            let strategy = input["strategy"] as? String ?? "css"
            let value = input["value"] as? String ?? ""
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"find\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "find", args: args)
        }
        
        // selenium_click
        if name == "selenium_click" {
            let strategy = input["strategy"] as? String ?? "css"
            let value = input["value"] as? String ?? ""
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"click\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "click", args: args)
        }
        
        // selenium_type
        if name == "selenium_type" {
            let strategy = input["strategy"] as? String ?? "css"
            let value = input["value"] as? String ?? ""
            let text = input["text"] as? String ?? ""
            let port = input["port"] as? Int ?? 7055
            let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let args = "{\"action\":\"type\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"text\":\"\(escapedText)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "type", args: args)
        }
        
        // selenium_execute
        if name == "selenium_execute" {
            let script = input["script"] as? String ?? ""
            let port = input["port"] as? Int ?? 7055
            let escapedScript = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let args = "{\"action\":\"execute\",\"script\":\"\(escapedScript)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "execute", args: args)
        }
        
        // selenium_screenshot
        if name == "selenium_screenshot" {
            let filename = input["filename"] as? String ?? "selenium_\(Int(Date().timeIntervalSince1970)).png"
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"screenshot\",\"filename\":\"\(filename)\",\"port\":\(port)}"
            return await runSeleniumNative(action: "screenshot", args: args)
        }
        
        // selenium_wait
        if name == "selenium_wait" {
            let strategy = input["strategy"] as? String ?? "css"
            let value = input["value"] as? String ?? ""
            let timeout = input["timeout"] as? Double ?? 10.0
            let port = input["port"] as? Int ?? 7055
            let args = "{\"action\":\"waitFor\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"timeout\":\(timeout),\"port\":\(port)}"
            return await runSeleniumNative(action: "waitFor", args: args)
        }
        
        // Tool not found in Selenium
        return ""
    }
}