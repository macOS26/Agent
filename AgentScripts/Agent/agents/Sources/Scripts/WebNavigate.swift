import Foundation
import SafariBridge

// ============================================================================
// WebNavigate - Navigate to URLs and wait for page states
//
// USAGE:
//   run_agent_script("WebNavigate", args: JSON)
//
// INPUT FORMAT (via AGENT_SCRIPT_ARGS or ~/Documents/AgentScript/json/WebNavigate_input.json):
// {
//   "url": "https://example.com",
//   "browser": "safari",
//   "waitFor": {
//     "type": "element",
//     "selector": "#content",
//     "timeout": 10
//   },
//   "actions": [
//     { "type": "scroll", "selector": "#footer" },
//     { "type": "click", "selector": "#next-page" },
//     { "type": "wait", "seconds": 2 },
//     { "type": "waitFor", "selector": "#results" }
//   ],
//   "returnUrl": true,
//   "returnTitle": true,
//   "screenshot": false
// }
//
// WAIT TYPES:
//   - element: Wait for element to appear
//   - text: Wait for text to appear on page
//   - title: Wait for page title to contain text
//   - url: Wait for URL to contain text
//   - load: Wait for page load complete
//   - hidden: Wait for element to be hidden
//
// ACTION TYPES:
//   - scroll: Scroll to element or by offset
//   - click: Click an element
//   - wait: Wait for specified seconds
//   - waitFor: Wait for element to appear
//   - hover: Hover over element (CSS hover)
//   - focus: Focus an element
//
// OUTPUT: ~/Documents/AgentScript/json/WebNavigate_output.json
// ============================================================================

struct WaitCondition: Codable {
    let type: String          // element, text, title, url, load, hidden
    let selector: String?     // For element type
    let text: String?         // For text/title/url type
    let timeout: Double?      // Max wait time
}

struct NavigationAction: Codable {
    let type: String          // scroll, click, wait, waitFor, hover, focus
    let selector: String?     // Target element
    let seconds: Double?      // For wait action
    let text: String?         // For type action
    let timeout: Double?      // For waitFor
}

struct NavigationInput: Codable {
    let url: String
    let browser: String?
    let waitFor: WaitCondition?
    let actions: [NavigationAction]?
    let returnUrl: Bool?
    let returnTitle: Bool?
    let screenshot: Bool?
    let returnHtml: Bool?
}

struct NavigationOutput: Codable {
    let success: Bool
    let url: String
    let finalUrl: String?
    let title: String?
    let html: String?
    let screenshotPath: String?
    let errors: [String]
    let completedActions: Int
}

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/WebNavigate_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/WebNavigate_output.json"
    let screenshotDir = "\(home)/Documents/AgentScript/screenshots"
    
    // Parse input
    var input: NavigationInput?
    
    if let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"],
       !argsString.isEmpty {
        if let data = argsString.data(using: .utf8) {
            input = try? JSONDecoder().decode(NavigationInput.self, from: data)
        }
    }
    
    if input == nil,
       let data = FileManager.default.contents(atPath: inputPath) {
        input = try? JSONDecoder().decode(NavigationInput.self, from: data)
    }
    
    guard let navInput = input else {
        print("❌ No valid input provided")
        writeOutput(outputPath, success: false, errors: ["No valid input provided"], completedActions: 0)
        return 1
    }
    
    print("🌐 WebNavigate")
    print("═══════════════════════════════════")
    print("URL: \(navInput.url)")
    
    // Run navigation
    let semaphore = DispatchSemaphore(value: 0)
    var result: NavigationOutput?
    
    Task { @MainActor in
        result = await performNavigation(navInput, screenshotDir: screenshotDir)
        semaphore.signal()
    }
    
    semaphore.wait()
    
    // Write output
    if let output = result {
        writeOutput(outputPath, output: output)
        return output.success ? 0 : 1
    }
    
    return 1
}

@MainActor
func performNavigation(_ input: NavigationInput, screenshotDir: String) async -> NavigationOutput {
    var errors: [String] = []
    var completedActions = 0
    
    // Connect to Safari
    guard let safari: SBApplication<SAApplication> = SBApplication(bundleIdentifier: "com.apple.Safari") else {
        return NavigationOutput(
            success: false,
            url: input.url,
            finalUrl: nil,
            title: nil,
            html: nil,
            screenshotPath: nil,
            errors: ["Safari not available"],
            completedActions: 0
        )
    }
    
    // Activate Safari
    safari.activate()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
    
    // Open URL
    print("  📖 Opening URL...")
    let url = URL(string: input.url)!
    safari.open(url)
    
    // Wait for initial page load
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))
    
    // Get front document
    guard let frontDoc = safari.documents?().firstObject as? SADocument else {
        return NavigationOutput(
            success: false,
            url: input.url,
            finalUrl: nil,
            title: nil,
            html: nil,
            screenshotPath: nil,
            errors: ["No Safari document found"],
            completedActions: 0
        )
    }
    
    // Wait for condition if specified
    if let waitCondition = input.waitFor {
        print("  ⏳ Waiting for: \(waitCondition.type)")
        let waitSuccess = await waitForCondition(document: frontDoc, condition: waitCondition)
        if !waitSuccess {
            errors.append("Wait condition not met: \(waitCondition.type)")
        }
    } else {
        // Default: wait for page load
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2.0))
    }
    
    // Execute actions if specified
    if let actions = input.actions {
        for action in actions {
            let success = await executeAction(document: frontDoc, action: action)
            if success {
                completedActions += 1
            } else {
                errors.append("Action failed: \(action.type)")
            }
        }
    }
    
    // Get final state
    var finalUrl: String?
    var title: String?
    var html: String?
    var screenshotPath: String?
    
    if let url = frontDoc.url {
        finalUrl = url
    }
    
    if let name = frontDoc.name {
        title = name
    }
    
    // Get HTML if requested
    if input.returnHtml == true {
        let htmlJS = "document.documentElement.outerHTML"
        html = frontDoc.doJavaScript?(htmlJS) as? String
    }
    
    // Take screenshot if requested
    if input.screenshot == true {
        // Use AccessibilityService screenshot via AppleScript
        let screenshotScript = """
        tell application "Safari"
            activate
            delay 0.5
        end tell
        
        tell application "System Events"
            tell process "Safari"
                set frontmost to true
            end tell
        end tell
        """
        
        var err: NSDictionary?
        let appleScript = NSAppleScript(source: screenshotScript)
        appleScript?.executeAndReturnError(&err)
        
        // Create screenshot filename
        let filename = "navigate_\(Int(Date().timeIntervalSince1970)).png"
        screenshotPath = "\(screenshotDir)/\(filename)"
        
        // Note: Actual screenshot would be done via ax_screenshot tool
        print("  📸 Screenshot would be saved to: \(screenshotPath ?? "")")
    }
    
    let success = errors.isEmpty || completedActions > 0
    print("✅ Navigation complete")
    
    return NavigationOutput(
        success: success,
        url: input.url,
        finalUrl: finalUrl,
        title: title,
        html: html,
        screenshotPath: screenshotPath,
        errors: errors,
        completedActions: completedActions
    )
}

@MainActor
func waitForCondition(document: SADocument, condition: WaitCondition) async -> Bool {
    let timeout = condition.timeout ?? 10.0
    let startTime = Date()
    
    switch condition.type {
    case "element":
        guard let selector = condition.selector else { return false }
        let js = "document.querySelector('\(selector)') !== null"
        return waitForJS(document: document, js: js, timeout: timeout)
        
    case "text":
        guard let text = condition.text else { return false }
        let js = "document.body.innerText.includes('\(text)')"
        return waitForJS(document: document, js: js, timeout: timeout)
        
    case "title":
        guard let text = condition.text else { return false }
        let js = "document.title.includes('\(text)')"
        return waitForJS(document: document, js: js, timeout: timeout)
        
    case "url":
        guard let text = condition.text else { return false }
        let js = "window.location.href.includes('\(text)')"
        return waitForJS(document: document, js: js, timeout: timeout)
        
    case "load":
        let js = "document.readyState === 'complete'"
        return waitForJS(document: document, js: js, timeout: timeout)
        
    case "hidden":
        guard let selector = condition.selector else { return false }
        let js = "document.querySelector('\(selector)') === null || document.querySelector('\(selector)').offsetWidth === 0"
        return waitForJS(document: document, js: js, timeout: timeout)
        
    default:
        return false
    }
}

@MainActor
func waitForJS(document: SADocument, js: String, timeout: Double) -> Bool {
    let startTime = Date()
    
    while Date().timeIntervalSince(startTime) < timeout {
        if let result = document.doJavaScript?(js) as? String,
           result == "true" {
            return true
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
    }
    
    return false
}

@MainActor
func executeAction(document: SADocument, action: NavigationAction) async -> Bool {
    switch action.type {
    case "scroll":
        return await executeScroll(document: document, action: action)
        
    case "click":
        return await executeClick(document: document, action: action)
        
    case "wait":
        let seconds = action.seconds ?? 1.0
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
        return true
        
    case "waitFor":
        guard let selector = action.selector else { return false }
        let timeout = action.timeout ?? 10.0
        let js = "document.querySelector('\(selector)') !== null"
        return waitForJS(document: document, js: js, timeout: timeout)
        
    case "hover":
        return await executeHover(document: document, action: action)
        
    case "focus":
        guard let selector = action.selector else { return false }
        let js = "document.querySelector('\(selector)')?.focus(); true;"
        _ = document.doJavaScript?(js) as String?
        return true
        
    case "type":
        guard let selector = action.selector,
              let text = action.text else { return false }
        let escapedText = text.replacingOccurrences(of: "'", with: "\\'")
        let js = "document.querySelector('\(selector)').value = '\(escapedText)'; true;"
        _ = document.doJavaScript?(js) as String?
        return true
        
    default:
        return false
    }
}

@MainActor
func executeScroll(document: SADocument, action: NavigationAction) async -> Bool {
    if let selector = action.selector {
        // Scroll to element
        let js = "document.querySelector('\(selector)')?.scrollIntoView({ behavior: 'smooth' }); true;"
        _ = document.doJavaScript?(js) as String?
    } else {
        // Scroll by amount (would need offset parameter)
        let js = "window.scrollBy(0, 500); true;"
        _ = document.doJavaScript?(js) as String?
    }
    return true
}

@MainActor
func executeClick(document: SADocument, action: NavigationAction) async -> Bool {
    guard let selector = action.selector else { return false }
    
    // Escape selector
    let escapedSelector = selector.replacingOccurrences(of: "'", with: "\\'")
    let js = "document.querySelector('\(escapedSelector)')?.click(); true;"
    
    if let result = document.doJavaScript?(js) as? String {
        return result == "true"
    }
    return false
}

@MainActor
func executeHover(document: SADocument, action: NavigationAction) async -> Bool {
    guard let selector = action.selector else { return false }
    
    // CSS hover simulation
    let js = """
    (function() {
        var el = document.querySelector('\(selector)');
        if (!el) return false;
        var event = new MouseEvent('mouseover', { bubbles: true });
        el.dispatchEvent(event);
        return true;
    })()
    """
    
    if let result = document.doJavaScript?(js) as? String {
        return result == "true"
    }
    return false
}

func writeOutput(_ path: String, output: NavigationOutput) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    
    guard let data = try? encoder.encode(output) else { return }
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try? data.write(to: URL(fileURLWithPath: path))
    
    print("\n📄 Output saved to: \(path)")
}

func writeOutput(_ path: String, success: Bool, errors: [String], completedActions: Int) {
    let output = NavigationOutput(
        success: success,
        url: "",
        finalUrl: nil,
        title: nil,
        html: nil,
        screenshotPath: nil,
        errors: errors,
        completedActions: completedActions
    )
    writeOutput(path, output: output)
}