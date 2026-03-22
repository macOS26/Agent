import Foundation
import os.log

private let webToolsLog = Logger(subsystem: "Agent.app.toddbruss", category: "WebTools")

// MARK: - Web Automation Tools Extension
extension AgentViewModel {

    // MARK: - Web Automation Tools (Phase 2 for Apple AI)

    /// Handle web_open tool
    func handleWebOpen(input: [String: Any]) async -> String {
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

    /// Handle web_find tool
    func handleWebFind(input: [String: Any]) async -> String {
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

    /// Handle web_click tool
    func handleWebClick(input: [String: Any]) async -> String {
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

    /// Handle web_type tool
    func handleWebType(input: [String: Any]) async -> String {
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

    /// Handle web_execute_js tool
    func handleWebExecuteJS(input: [String: Any]) async -> String {
        let script = input["script"] as? String ?? ""
        let browser = input["browser"] as? String
        
        do {
            let result = try await WebAutomationService.shared.executeJavaScript(script: script, browser: browser)
            return result as? String ?? "Script executed"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    /// Handle web_get_url / web_get_title tools (compile via User LaunchAgent)
    func handleWebGetUrlOrTitle(action: String, browser: String?) async -> String {
        let args = "{\"action\":\"\(action)\"}"
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

    // MARK: - Selenium WebDriver Tools (via AgentScript)

    /// Helper for Selenium operations via AgentScript (compile via User LaunchAgent)
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

    /// Handle selenium_start tool
    func handleSeleniumStart(input: [String: Any]) async -> String {
        let browser = input["browser"] as? String ?? "safari"
        let port = input["port"] as? Int ?? 7055
        let args = "{\"action\":\"start\",\"browser\":\"\(browser)\",\"port\":\(port)}"
        return await runSeleniumNative(action: "start", args: args)
    }

    /// Handle selenium_stop tool
    func handleSeleniumStop(input: [String: Any]) async -> String {
        let port = input["port"] as? Int ?? 7055
        let args = "{\"action\":\"stop\",\"port\":\(port)}"
        return await runSeleniumNative(action: "stop", args: args)
    }

    /// Handle selenium_navigate tool
    func handleSeleniumNavigate(input: [String: Any]) async -> String {
        guard let url = input["url"] as? String else { return "Error: URL required" }
        let port = input["port"] as? Int ?? 7055
        let args = "{\"action\":\"navigate\",\"url\":\"\(url)\",\"port\":\(port)}"
        return await runSeleniumNative(action: "navigate", args: args)
    }

    /// Handle selenium_find tool
    func handleSeleniumFind(input: [String: Any]) async -> String {
        let strategy = input["strategy"] as? String ?? "css"
        let value = input["value"] as? String ?? ""
        let port = input["port"] as? Int ?? 7055
        let args = "{\"action\":\"find\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"port\":\(port)}"
        return await runSeleniumNative(action: "find", args: args)
    }

    /// Handle selenium_click tool
    func handleSeleniumClick(input: [String: Any]) async -> String {
        let strategy = input["strategy"] as? String ?? "css"
        let value = input["value"] as? String ?? ""
        let port = input["port"] as? Int ?? 7055
        let args = "{\"action\":\"click\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"port\":\(port)}"
        return await runSeleniumNative(action: "click", args: args)
    }

    /// Handle selenium_type tool
    func handleSeleniumType(input: [String: Any]) async -> String {
        let strategy = input["strategy"] as? String ?? "css"
        let value = input["value"] as? String ?? ""
        let text = input["text"] as? String ?? ""
        let port = input["port"] as? Int ?? 7055
        let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let args = "{\"action\":\"type\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"text\":\"\(escapedText)\",\"port\":\(port)}"
        return await runSeleniumNative(action: "type", args: args)
    }

    /// Handle selenium_execute tool
    func handleSeleniumExecute(input: [String: Any]) async -> String {
        let script = input["script"] as? String ?? ""
        let port = input["port"] as? Int ?? 7055
        let escapedScript = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let args = "{\"action\":\"execute\",\"script\":\"\(escapedScript)\",\"port\":\(port)}"
        return await runSeleniumNative(action: "execute", args: args)
    }

    /// Handle selenium_screenshot tool
    func handleSeleniumScreenshot(input: [String: Any]) async -> String {
        let filename = input["filename"] as? String ?? "selenium_\(Int(Date().timeIntervalSince1970)).png"
        let port = input["port"] as? Int ?? 7055
        let args = "{\"action\":\"screenshot\",\"filename\":\"\(filename)\",\"port\":\(port)}"
        return await runSeleniumNative(action: "screenshot", args: args)
    }

    /// Handle selenium_wait tool
    func handleSeleniumWait(input: [String: Any]) async -> String {
        let strategy = input["strategy"] as? String ?? "css"
        let value = input["value"] as? String ?? ""
        let timeout = input["timeout"] as? Double ?? 10.0
        let port = input["port"] as? Int ?? 7055
        let args = "{\"action\":\"waitFor\",\"strategy\":\"\(strategy)\",\"value\":\"\(value)\",\"timeout\":\(timeout),\"port\":\(port)}"
        return await runSeleniumNative(action: "waitFor", args: args)
    }

    // MARK: - Web Search Tool

    /// Handle web_search tool
    func handleWebSearch(query: String) async -> String {
        appendLog("Web search: \(query)")
        flushLog()
        let output = await Self.performWebSearch(query: query, apiKey: tavilyAPIKey, provider: selectedProvider)
        appendLog(Self.preview(output, lines: 5))
        return output
    }
}