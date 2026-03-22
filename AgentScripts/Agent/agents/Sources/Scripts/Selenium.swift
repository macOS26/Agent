import Foundation
import SeleniumBridge

// ============================================================================
// Selenium - WebDriver-based browser automation
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: JSON string with action and parameters
//     Example: '{"action":"start","browser":"safari"}'
//              '{"action":"navigate","url":"https://example.com"}'
//              '{"action":"find","strategy":"css","value":"#search"}'
//
//   Option 2: JSON input file at ~/Documents/AgentScript/json/Selenium_input.json
//     {
//       "action": "start",
//       "browser": "safari",
//       "capabilities": { "browserName": "Safari" }
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/Selenium_output.json
//   {
//     "success": true,
//     "action": "start",
//     "sessionId": "...",
//     "data": { ... }
//   }
//
// SUPPORTED ACTIONS:
//   start - Start a WebDriver session
//   stop - End the session
//   navigate - Navigate to URL
//   find - Find an element
//   findAll - Find all matching elements
//   click - Click an element
//   type - Type text into element
//   getText - Get element text
//   getAttribute - Get element attribute
//   execute - Execute JavaScript
//   screenshot - Take screenshot
//   waitFor - Wait for element
//   getTitle - Get page title
//   getUrl - Get current URL
//   back - Navigate back
//   forward - Navigate forward
//   refresh - Refresh page
//   getCookies - Get all cookies
//   addCookie - Add a cookie
//   alert - Handle alerts (accept/dismiss/getText/sendText)
// ============================================================================

// Thread-safe result holder
final class SeleniumResultHolder: @unchecked Sendable {
    var success: Bool = false
    var error: String? = nil
    var data: [String: Any]? = nil
}

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    runSelenium()
    return 0
}

func runSelenium() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/Selenium_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/Selenium_output.json"
    let screenshotDir = "\(home)/Documents/AgentScript/screenshots"
    
    // Parse input
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var action = ""
    var params: [String: Any] = [:]
    
    // Try args first
    if !argsString.isEmpty {
        // Try JSON parse
        if let data = argsString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            action = json["action"] as? String ?? ""
            params = json
        } else {
            // Try key=value format
            let pairs = argsString.components(separatedBy: ",")
            for pair in pairs {
                let parts = pair.components(separatedBy: "=")
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    if key == "action" {
                        action = value
                    } else {
                        params[key] = value
                    }
                }
            }
        }
    }
    
    // Try JSON file input
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let a = json["action"] as? String { action = a }
        params.merge(json) { (_, new) in new }
    }
    
    guard !action.isEmpty else {
        print("❌ No action specified")
        printUsage()
        writeOutput(outputPath, success: false, error: "No action specified", action: action, data: nil)
        return
    }
    
    print("🌐 Selenium WebDriver Automation")
    print("═══════════════════════════════════")
    print("Action: \(action)")
    
    // Run the action in a Task for async support
    let semaphore = DispatchSemaphore(value: 0)
    let resultHolder = SeleniumResultHolder()
    
    Task { @MainActor in
        do {
            let data = try await performAction(
                action: action,
                params: params,
                outputPath: outputPath,
                screenshotDir: screenshotDir
            )
            resultHolder.success = true
            resultHolder.data = data
        } catch {
            resultHolder.error = error.localizedDescription
        }
        semaphore.signal()
    }
    
    semaphore.wait()
    
    // Write output
    writeOutput(outputPath, success: resultHolder.success, error: resultHolder.error, action: action, data: resultHolder.data)
}

// MARK: - Actions

@MainActor
func performAction(action: String, params: [String: Any], outputPath: String, screenshotDir: String) async throws -> [String: Any]? {
    // Get or create client - we use a singleton stored in UserDefaults
    let clientKey = "SeleniumClient_Session"
    let defaults = UserDefaults.standard
    
    // Helper to get existing client or create new
    func getOrCreateClient(port: Int = 7055) -> SeleniumClient {
        return SeleniumClient(host: "localhost", port: port)
    }
    
    switch action {
    // MARK: Session Management
    case "start":
        let browser = params["browser"] as? String ?? "safari"
        let port = params["port"] as? Int ?? 7055
        let capabilities = params["capabilities"] as? [String: Any] ?? [:]
        
        print("Browser: \(browser)")
        print("Port: \(port)")
        
        let client = getOrCreateClient(port: port)
        let session = try await client.startSession(capabilities: capabilities)
        
        // Store session ID
        defaults.set(session.sessionId, forKey: clientKey)
        defaults.synchronize()
        
        print("✅ Session started: \(session.sessionId)")
        return ["sessionId": session.sessionId, "browser": browser]
        
    case "stop", "end":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.endSession()
        defaults.removeObject(forKey: clientKey)
        print("✅ Session ended")
        return ["ended": true]
        
    // MARK: Navigation
    case "navigate", "goto":
        guard let url = params["url"] as? String else {
            throw SeleniumError.invalidSelector("URL required for navigate action")
        }
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.navigate(to: url)
        print("✅ Navigated to: \(url)")
        return ["url": url]
        
    case "getUrl":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let url = try await client.getCurrentURL()
        print("Current URL: \(url)")
        return ["url": url]
        
    case "getTitle":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let title = try await client.getTitle()
        print("Page title: \(title)")
        return ["title": title]
        
    case "back":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.back()
        print("✅ Navigated back")
        return ["action": "back"]
        
    case "forward":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.forward()
        print("✅ Navigated forward")
        return ["action": "forward"]
        
    case "refresh":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.refresh()
        print("✅ Page refreshed")
        return ["action": "refresh"]
        
    // MARK: Element Finding
    case "find":
        guard let strategy = params["strategy"] as? String,
              let value = params["value"] as? String else {
            throw SeleniumError.invalidSelector("strategy and value required for find action")
        }
        let locator = parseLocator(strategy)
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let element = try await client.findElement(by: locator, value: value)
        print("✅ Found element: \(element.elementId)")
        return ["elementId": element.elementId]
        
    case "findAll":
        guard let strategy = params["strategy"] as? String,
              let value = params["value"] as? String else {
            throw SeleniumError.invalidSelector("strategy and value required for findAll action")
        }
        let locator = parseLocator(strategy)
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let elements = try await client.findElements(by: locator, value: value)
        print("✅ Found \(elements.count) elements")
        return ["count": elements.count, "elementIds": elements.map { $0.elementId }]
        
    // MARK: Element Actions
    case "click":
        guard let strategy = params["strategy"] as? String,
              let value = params["value"] as? String else {
            throw SeleniumError.invalidSelector("strategy and value required for click action")
        }
        let locator = parseLocator(strategy)
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let element = try await client.findElement(by: locator, value: value)
        try await client.click(element: element)
        print("✅ Clicked element: \(strategy)=\(value)")
        return ["clicked": true, "selector": "\(strategy)=\(value)"]
        
    case "type", "sendKeys":
        guard let strategy = params["strategy"] as? String,
              let value = params["value"] as? String,
              let text = params["text"] as? String else {
            throw SeleniumError.invalidSelector("strategy, value, and text required for type action")
        }
        let locator = parseLocator(strategy)
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let element = try await client.findElement(by: locator, value: value)
        try await client.sendKeys(element: element, text: text)
        print("✅ Typed into element: \(strategy)=\(value)")
        return ["typed": true, "text": text]
        
    case "getText":
        guard let strategy = params["strategy"] as? String,
              let value = params["value"] as? String else {
            throw SeleniumError.invalidSelector("strategy and value required for getText action")
        }
        let locator = parseLocator(strategy)
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let element = try await client.findElement(by: locator, value: value)
        let text = try await client.getText(element: element)
        print("✅ Text: \(text)")
        return ["text": text]
        
    case "getAttribute":
        guard let strategy = params["strategy"] as? String,
              let value = params["value"] as? String,
              let attribute = params["attribute"] as? String else {
            throw SeleniumError.invalidSelector("strategy, value, and attribute required")
        }
        let locator = parseLocator(strategy)
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let element = try await client.findElement(by: locator, value: value)
        let attrValue = try await client.getAttribute(element: element, name: attribute)
        print("✅ Attribute \(attribute): \(attrValue ?? "nil")")
        return ["attribute": attribute, "value": attrValue ?? ""]
        
    case "clear":
        guard let strategy = params["strategy"] as? String,
              let value = params["value"] as? String else {
            throw SeleniumError.invalidSelector("strategy and value required for clear action")
        }
        let locator = parseLocator(strategy)
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let element = try await client.findElement(by: locator, value: value)
        try await client.clear(element: element)
        print("✅ Cleared element: \(strategy)=\(value)")
        return ["cleared": true]
        
    // MARK: JavaScript
    case "execute", "executeScript":
        guard let script = params["script"] as? String else {
            throw SeleniumError.invalidSelector("script required for execute action")
        }
        let args = params["args"] as? [Any] ?? []
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let result = try await client.executeScript(script, args: args)
        print("✅ Script executed")
        return ["result": result ?? NSNull()]
        
    case "executeAsync":
        guard let script = params["script"] as? String else {
            throw SeleniumError.invalidSelector("script required for executeAsync action")
        }
        let args = params["args"] as? [Any] ?? []
        let timeout = params["timeout"] as? Double ?? 90.0
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let result = try await client.executeAsyncScript(script, args: args, timeout: timeout)
        print("✅ Async script executed")
        return ["result": result ?? NSNull()]
        
    // MARK: Screenshot
    case "screenshot":
        let filename = params["filename"] as? String ?? "screenshot_\(Int(Date().timeIntervalSince1970)).png"
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let data = try await client.takeScreenshot()
        
        // Ensure directory exists
        try FileManager.default.createDirectory(atPath: screenshotDir, withIntermediateDirectories: true)
        
        let filepath = "\(screenshotDir)/\(filename)"
        try data.write(to: URL(fileURLWithPath: filepath))
        print("✅ Screenshot saved: \(filepath)")
        return ["path": filepath, "size": data.count]
        
    case "elementScreenshot":
        guard let strategy = params["strategy"] as? String,
              let value = params["value"] as? String else {
            throw SeleniumError.invalidSelector("strategy and value required for elementScreenshot action")
        }
        let filename = params["filename"] as? String ?? "element_\(Int(Date().timeIntervalSince1970)).png"
        let locator = parseLocator(strategy)
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let element = try await client.findElement(by: locator, value: value)
        let data = try await client.takeElementScreenshot(element: element)
        
        try FileManager.default.createDirectory(atPath: screenshotDir, withIntermediateDirectories: true)
        
        let filepath = "\(screenshotDir)/\(filename)"
        try data.write(to: URL(fileURLWithPath: filepath))
        print("✅ Element screenshot saved: \(filepath)")
        return ["path": filepath, "size": data.count]
        
    // MARK: Waiting
    case "waitFor":
        guard let strategy = params["strategy"] as? String,
              let value = params["value"] as? String else {
            throw SeleniumError.invalidSelector("strategy and value required for waitFor action")
        }
        let locator = parseLocator(strategy)
        let timeout = params["timeout"] as? Double ?? 90.0
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let element = try await client.waitForElement(by: locator, value: value, timeout: timeout)
        print("✅ Element found: \(element.elementId)")
        return ["elementId": element.elementId]
        
    case "waitForClickable":
        guard let strategy = params["strategy"] as? String,
              let value = params["value"] as? String else {
            throw SeleniumError.invalidSelector("strategy and value required for waitForClickable action")
        }
        let locator = parseLocator(strategy)
        let timeout = params["timeout"] as? Double ?? 90.0
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let element = try await client.waitForElementClickable(by: locator, value: value, timeout: timeout)
        print("✅ Element clickable: \(element.elementId)")
        return ["elementId": element.elementId]
        
    // MARK: Window Management
    case "getWindowHandle":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let handle = try await client.getWindowHandle()
        print("Window handle: \(handle)")
        return ["handle": handle]
        
    case "getWindowHandles":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let handles = try await client.getWindowHandles()
        print("Window handles: \(handles)")
        return ["handles": handles]
        
    case "switchWindow":
        guard let handle = params["handle"] as? String else {
            throw SeleniumError.invalidSelector("handle required for switchWindow action")
        }
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.switchToWindow(handle: handle)
        print("✅ Switched to window: \(handle)")
        return ["switched": handle]
        
    case "closeWindow":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.closeWindow()
        print("✅ Window closed")
        return ["closed": true]
        
    case "setWindowSize":
        guard let width = params["width"] as? Int,
              let height = params["height"] as? Int else {
            throw SeleniumError.invalidSelector("width and height required for setWindowSize action")
        }
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.setWindowSize(width: width, height: height)
        print("✅ Window size set to \(width)x\(height)")
        return ["width": width, "height": height]
        
    case "maximizeWindow":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.maximizeWindow()
        print("✅ Window maximized")
        return ["maximized": true]
        
    // MARK: Alerts
    case "alertText":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let text = try await client.getAlertText()
        print("Alert text: \(text ?? "nil")")
        return ["text": text ?? ""]
        
    case "alertAccept":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.acceptAlert()
        print("✅ Alert accepted")
        return ["accepted": true]
        
    case "alertDismiss":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.dismissAlert()
        print("✅ Alert dismissed")
        return ["dismissed": true]
        
    case "alertSendText":
        guard let text = params["text"] as? String else {
            throw SeleniumError.invalidSelector("text required for alertSendText action")
        }
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.sendAlertText(text)
        print("✅ Alert text sent: \(text)")
        return ["sent": text]
        
    // MARK: Cookies
    case "getCookies":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        let cookies = try await client.getCookies()
        print("✅ Found \(cookies.count) cookies")
        return ["cookies": cookies]
        
    case "addCookie":
        guard let name = params["name"] as? String,
              let value = params["value"] as? String else {
            throw SeleniumError.invalidSelector("name and value required for addCookie action")
        }
        let domain = params["domain"] as? String
        let path = params["path"] as? String ?? "/"
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.addCookie(name: name, value: value, domain: domain, path: path)
        print("✅ Cookie added: \(name)=\(value)")
        return ["cookie": name]
        
    case "deleteCookie":
        guard let name = params["name"] as? String else {
            throw SeleniumError.invalidSelector("name required for deleteCookie action")
        }
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.deleteCookie(name: name)
        print("✅ Cookie deleted: \(name)")
        return ["deleted": name]
        
    case "deleteAllCookies":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.deleteAllCookies()
        print("✅ All cookies deleted")
        return ["deleted": "all"]
        
    // MARK: Frames
    case "switchFrame":
        let index = params["index"] as? Int ?? 0
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.switchToFrame(index: index)
        print("✅ Switched to frame \(index)")
        return ["frame": index]
        
    case "switchParentFrame":
        let port = params["port"] as? Int ?? 7055
        let client = getOrCreateClient(port: port)
        try await client.switchToParentFrame()
        print("✅ Switched to parent frame")
        return ["parent": true]
        
    default:
        throw SeleniumError.invalidSelector("Unknown action: \(action)")
    }
}

// MARK: - Helpers

func parseLocator(_ strategy: String) -> LocatorStrategy {
    switch strategy.lowercased() {
    case "css", "cssselector", "css-selector":
        return .cssSelector
    case "xpath":
        return .xpath
    case "id":
        return .id
    case "name":
        return .name
    case "linktext", "link":
        return .linkText
    case "partiallinktext", "partial":
        return .partialLinkText
    case "tagname", "tag":
        return .tagName
    case "classname", "class":
        return .className
    default:
        return .cssSelector
    }
}

func printUsage() {
    print("")
    print("USAGE:")
    print("  Selenium '{\"action\":\"start\",\"browser\":\"safari\"}'")
    print("  Selenium '{\"action\":\"navigate\",\"url\":\"https://example.com\"}'")
    print("  Selenium '{\"action\":\"find\",\"strategy\":\"css\",\"value\":\"#search\"}'")
    print("  Selenium '{\"action\":\"click\",\"strategy\":\"xpath\",\"value\":\"//button\"}'")
    print("  Selenium '{\"action\":\"type\",\"strategy\":\"id\",\"value\":\"input\",\"text\":\"hello\"}'")
    print("  Selenium '{\"action\":\"screenshot\",\"filename\":\"page.png\"}'")
    print("  Selenium '{\"action\":\"stop\"}'")
    print("")
    print("LOCATOR STRATEGIES:")
    print("  css, xpath, id, name, linktext, partiallinktext, tagname, classname")
    print("")
    print("ACTIONS:")
    print("  start, stop, navigate, getUrl, getTitle, back, forward, refresh")
    print("  find, findAll, click, type, getText, getAttribute, clear")
    print("  execute, executeAsync, screenshot, elementScreenshot")
    print("  waitFor, waitForClickable")
    print("  getWindowHandle, getWindowHandles, switchWindow, closeWindow")
    print("  setWindowSize, maximizeWindow")
    print("  alertText, alertAccept, alertDismiss, alertSendText")
    print("  getCookies, addCookie, deleteCookie, deleteAllCookies")
    print("  switchFrame, switchParentFrame")
}

func writeOutput(_ path: String, success: Bool, error: String? = nil, action: String, data: [String: Any]?) {
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "action": action
    ]
    
    if let error = error {
        result["error"] = error
    }
    
    if let data = data {
        result["data"] = data
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}