@_exported import ScriptingBridgeCommon
import Foundation

// MARK: - WebDriver Protocol Implementation
// Selenium-style browser automation via WebDriver REST API
// Supports: SafariDriver (built-in), ChromeDriver, GeckoDriver, EdgeDriver

public typealias WebElementID = String

// MARK: - Error Types
public enum SeleniumError: Error, CustomStringConvertible {
    case sessionNotCreated(String)
    case invalidSession
    case elementNotFound(String)
    case elementNotInteractable
    case timeout(String)
    case invalidSelector(String)
    case javascriptError(String)
    case screenshotFailed
    case connectionFailed(String)
    case unexpectedResponse(String)
    
    public var description: String {
        switch self {
        case .sessionNotCreated(let msg): return "Session not created: \(msg)"
        case .invalidSession: return "Invalid or expired session"
        case .elementNotFound(let sel): return "Element not found: \(sel)"
        case .elementNotInteractable: return "Element not interactable"
        case .timeout(let msg): return "Timeout: \(msg)"
        case .invalidSelector(let sel): return "Invalid selector: \(sel)"
        case .javascriptError(let msg): return "JavaScript error: \(msg)"
        case .screenshotFailed: return "Screenshot failed"
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .unexpectedResponse(let msg): return "Unexpected response: \(msg)"
        }
    }
}

// MARK: - Locator Strategy
public enum LocatorStrategy: String, Encodable {
    case cssSelector = "css selector"
    case xpath = "xpath"
    case id = "id"
    case name = "name"
    case linkText = "link text"
    case partialLinkText = "partial link text"
    case tagName = "tag name"
    case className = "class name"
}

// MARK: - Browser Type
public enum BrowserType: String, Encodable {
    case safari = "Safari"
    case chrome = "Chrome"
    case firefox = "Firefox"
    case edge = "MicrosoftEdge"
    
    public var defaultPort: Int {
        switch self {
        case .safari: return 7055  // safaridriver default
        case .chrome: return 9515 // chromedriver default
        case .firefox: return 4444 // geckodriver default
        case .edge: return 9515   // same as chrome
        }
    }
    
    public var defaultHost: String {
        return "localhost"
    }
}

// MARK: - WebDriver Session
public struct WebDriverSession {
    public let sessionId: String
    public let capabilities: [String: Any]?
    
    public init(sessionId: String, capabilities: [String: Any]? = nil) {
        self.sessionId = sessionId
        self.capabilities = capabilities
    }
}

// MARK: - WebElement
public struct WebElement {
    public let elementId: String
    public let sessionId: String
    
    public init(elementId: String, sessionId: String) {
        self.elementId = elementId
        self.sessionId = sessionId
    }
    
    public init?(from dict: [String: Any], sessionId: String) {
        guard let id = dict["element-6066-11e4-a52e-4f735466cecf"] as? String ??
                  dict["ELEMENT"] as? String else {
            return nil
        }
        self.elementId = id
        self.sessionId = sessionId
    }
}

// MARK: - Selenium Client
@MainActor
public class SeleniumClient {
    private let baseURL: URL
    private var session: WebDriverSession?
    private let sessionQueue = DispatchQueue(label: "com.agent.selenium")
    
    public init(host: String = "localhost", port: Int = 7055) {
        baseURL = URL(string: "http://\(host):\(port)")!
    }
    
    public convenience init(browser: BrowserType) {
        self.init(host: browser.defaultHost, port: browser.defaultPort)
    }
    
    // MARK: - Session Management
    
    public func startSession(capabilities: [String: Any] = [:]) async throws -> WebDriverSession {
        var caps = capabilities
        caps["browserName"] = capabilities["browserName"] ?? "Safari"
        
        let body: [String: Any] = [
            "capabilities": [
                "alwaysMatch": caps
            ]
        ]
        
        let response = try await sendRequest("POST", "/session", body)
        
        guard let sessionId = response["sessionId"] as? String,
              let value = response["value"] as? [String: Any] else {
            if let error = response["value"] as? [String: Any],
               let msg = error["message"] as? String {
                throw SeleniumError.sessionNotCreated(msg)
            }
            throw SeleniumError.unexpectedResponse("Missing sessionId in response")
        }
        
        session = WebDriverSession(sessionId: sessionId, capabilities: value)
        return session!
    }
    
    public func endSession() async throws {
        guard let sessionId = session?.sessionId else { return }
        _ = try? await sendRequest("DELETE", "/session/\(sessionId)")
        session = nil
    }
    
    public func getSession() -> WebDriverSession? {
        return session
    }
    
    // MARK: - Navigation
    
    public func navigate(to url: String) async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let body: [String: Any] = ["url": url]
        _ = try await sendRequest("POST", "/session/\(sessionId)/url", body)
    }
    
    public func getCurrentURL() async throws -> String {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/url")
        guard let url = response["value"] as? String else {
            throw SeleniumError.unexpectedResponse("Missing URL in response")
        }
        return url
    }
    
    public func getTitle() async throws -> String {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/title")
        guard let title = response["value"] as? String else {
            throw SeleniumError.unexpectedResponse("Missing title in response")
        }
        return title
    }
    
    public func back() async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        _ = try await sendRequest("POST", "/session/\(sessionId)/back")
    }
    
    public func forward() async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        _ = try await sendRequest("POST", "/session/\(sessionId)/forward")
    }
    
    public func refresh() async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        _ = try await sendRequest("POST", "/session/\(sessionId)/refresh")
    }
    
    // MARK: - Element Finding
    
    public func findElement(by strategy: LocatorStrategy, value: String) async throws -> WebElement {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let body: [String: Any] = [
            "using": strategy.rawValue,
            "value": value
        ]
        
        let response = try await sendRequest("POST", "/session/\(sessionId)/element", body)
        
        guard let value = response["value"] as? [String: Any],
              let element = WebElement(from: value, sessionId: sessionId) else {
            throw SeleniumError.elementNotFound("\(strategy.rawValue): \(value)")
        }
        
        return element
    }
    
    public func findElements(by strategy: LocatorStrategy, value: String) async throws -> [WebElement] {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let body: [String: Any] = [
            "using": strategy.rawValue,
            "value": value
        ]
        
        let response = try await sendRequest("POST", "/session/\(sessionId)/elements", body)
        
        guard let values = response["value"] as? [[String: Any]] else {
            return []
        }
        
        return values.compactMap { WebElement(from: $0, sessionId: sessionId) }
    }
    
    public func findElement(in parent: WebElement, by strategy: LocatorStrategy, value: String) async throws -> WebElement {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let body: [String: Any] = [
            "using": strategy.rawValue,
            "value": value
        ]
        
        let response = try await sendRequest("POST", "/session/\(sessionId)/element/\(parent.elementId)/element", body)
        
        guard let value = response["value"] as? [String: Any],
              let element = WebElement(from: value, sessionId: sessionId) else {
            throw SeleniumError.elementNotFound("\(strategy.rawValue): \(value)")
        }
        
        return element
    }
    
    // MARK: - Element Actions
    
    public func click(element: WebElement) async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        _ = try await sendRequest("POST", "/session/\(sessionId)/element/\(element.elementId)/click")
    }
    
    public func sendKeys(element: WebElement, text: String) async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let body: [String: Any] = ["text": text]
        _ = try await sendRequest("POST", "/session/\(sessionId)/element/\(element.elementId)/value", body)
    }
    
    public func clear(element: WebElement) async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        _ = try await sendRequest("POST", "/session/\(sessionId)/element/\(element.elementId)/clear")
    }
    
    public func getText(element: WebElement) async throws -> String {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/element/\(element.elementId)/text")
        guard let text = response["value"] as? String else {
            throw SeleniumError.unexpectedResponse("Missing text in response")
        }
        return text
    }
    
    public func getAttribute(element: WebElement, name: String) async throws -> String? {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/element/\(element.elementId)/attribute/\(name)")
        return response["value"] as? String
    }
    
    public func getProperty(element: WebElement, name: String) async throws -> Any? {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/element/\(element.elementId)/property/\(name)")
        return response["value"]
    }
    
    public func isDisplayed(element: WebElement) async throws -> Bool {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/element/\(element.elementId)/displayed")
        return response["value"] as? Bool ?? false
    }
    
    public func isEnabled(element: WebElement) async throws -> Bool {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/element/\(element.elementId)/enabled")
        return response["value"] as? Bool ?? false
    }
    
    public func isSelected(element: WebElement) async throws -> Bool {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/element/\(element.elementId)/selected")
        return response["value"] as? Bool ?? false
    }
    
    // MARK: - JavaScript Execution
    
    public func executeScript(_ script: String, args: [Any] = []) async throws -> Any? {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let body: [String: Any] = [
            "script": script,
            "args": args
        ]
        
        let response = try await sendRequest("POST", "/session/\(sessionId)/execute/sync", body)
        return response["value"]
    }
    
    public func executeAsyncScript(_ script: String, args: [Any] = [], timeout: TimeInterval = 30) async throws -> Any? {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        // Set script timeout
        let timeoutBody: [String: Any] = ["script": Int(timeout * 1000)]
        _ = try await sendRequest("POST", "/session/\(sessionId)/timeouts", timeoutBody)
        
        let body: [String: Any] = [
            "script": script,
            "args": args
        ]
        
        let response = try await sendRequest("POST", "/session/\(sessionId)/execute/async", body)
        return response["value"]
    }
    
    // MARK: - Screenshot
    
    public func takeScreenshot() async throws -> Data {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/screenshot")
        
        guard let base64 = response["value"] as? String,
              let data = Data(base64Encoded: base64) else {
            throw SeleniumError.screenshotFailed
        }
        
        return data
    }
    
    public func takeElementScreenshot(element: WebElement) async throws -> Data {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/element/\(element.elementId)/screenshot")
        
        guard let base64 = response["value"] as? String,
              let data = Data(base64Encoded: base64) else {
            throw SeleniumError.screenshotFailed
        }
        
        return data
    }
    
    // MARK: - Window Management
    
    public func getWindowHandle() async throws -> String {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/window")
        guard let handle = response["value"] as? String else {
            throw SeleniumError.unexpectedResponse("Missing window handle")
        }
        return handle
    }
    
    public func getWindowHandles() async throws -> [String] {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/window/handles")
        guard let handles = response["value"] as? [String] else {
            return []
        }
        return handles
    }
    
    public func switchToWindow(handle: String) async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let body: [String: Any] = ["handle": handle]
        _ = try await sendRequest("POST", "/session/\(sessionId)/window", body)
    }
    
    public func closeWindow() async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        _ = try await sendRequest("DELETE", "/session/\(sessionId)/window")
    }
    
    public func setWindowSize(width: Int, height: Int) async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let body: [String: Any] = ["width": width, "height": height]
        _ = try await sendRequest("POST", "/session/\(sessionId)/window/rect", body)
    }
    
    public func maximizeWindow() async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        _ = try await sendRequest("POST", "/session/\(sessionId)/window/maximize")
    }
    
    // MARK: - Alerts
    
    public func getAlertText() async throws -> String? {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/alert/text")
        return response["value"] as? String
    }
    
    public func sendAlertText(_ text: String) async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let body: [String: Any] = ["text": text]
        _ = try await sendRequest("POST", "/session/\(sessionId)/alert/text", body)
    }
    
    public func acceptAlert() async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        _ = try await sendRequest("POST", "/session/\(sessionId)/alert/accept")
    }
    
    public func dismissAlert() async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        _ = try await sendRequest("POST", "/session/\(sessionId)/alert/dismiss")
    }
    
    // MARK: - Frames
    
    public func switchToFrame(index: Int) async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let body: [String: Any] = ["id": index]
        _ = try await sendRequest("POST", "/session/\(sessionId)/frame", body)
    }
    
    public func switchToParentFrame() async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        _ = try await sendRequest("POST", "/session/\(sessionId)/frame/parent")
    }
    
    // MARK: - Cookies
    
    public func getCookies() async throws -> [[String: Any]] {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        let response = try await sendRequest("GET", "/session/\(sessionId)/cookie")
        guard let cookies = response["value"] as? [[String: Any]] else {
            return []
        }
        return cookies
    }
    
    public func addCookie(name: String, value: String, domain: String? = nil, path: String = "/") async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        var cookie: [String: Any] = ["name": name, "value": value, "path": path]
        if let domain = domain {
            cookie["domain"] = domain
        }
        
        let body: [String: Any] = ["cookie": cookie]
        _ = try await sendRequest("POST", "/session/\(sessionId)/cookie", body)
    }
    
    public func deleteCookie(name: String) async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        _ = try await sendRequest("DELETE", "/session/\(sessionId)/cookie/\(name)")
    }
    
    public func deleteAllCookies() async throws {
        guard let sessionId = session?.sessionId else {
            throw SeleniumError.invalidSession
        }
        
        _ = try await sendRequest("DELETE", "/session/\(sessionId)/cookie")
    }
    
    // MARK: - Waits
    
    public func waitForElement(by strategy: LocatorStrategy, value: String, timeout: TimeInterval = 10) async throws -> WebElement {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let element = try await findElement(by: strategy, value: value)
                if try await isDisplayed(element: element) {
                    return element
                }
            } catch {
                // Element not found yet, continue waiting
            }
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        
        throw SeleniumError.timeout("Element not found: \(strategy.rawValue): \(value)")
    }
    
    public func waitForElementClickable(by strategy: LocatorStrategy, value: String, timeout: TimeInterval = 10) async throws -> WebElement {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let element = try await findElement(by: strategy, value: value)
                let displayed = try await isDisplayed(element: element)
                let enabled = try await isEnabled(element: element)
                if displayed && enabled {
                    return element
                }
            } catch {
                // Element not found yet, continue waiting
            }
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        
        throw SeleniumError.timeout("Element not clickable: \(strategy.rawValue): \(value)")
    }
    
    public func waitForElementPresent(by strategy: LocatorStrategy, value: String, timeout: TimeInterval = 10) async throws -> WebElement {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                return try await findElement(by: strategy, value: value)
            } catch {
                // Element not found yet, continue waiting
            }
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        
        throw SeleniumError.timeout("Element not present: \(strategy.rawValue): \(value)")
    }
    
    // MARK: - Low-level Request
    
    private func sendRequest(_ method: String, _ path: String, _ body: [String: Any]? = nil) async throws -> [String: Any] {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SeleniumError.connectionFailed("Invalid response")
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw SeleniumError.unexpectedResponse("Invalid JSON response")
            }
            
            // Check for WebDriver error
            if let error = json["value"] as? [String: Any],
               let errorMsg = error["message"] as? String,
               httpResponse.statusCode >= 400 {
                if errorMsg.contains("no such element") {
                    throw SeleniumError.elementNotFound(errorMsg)
                } else if errorMsg.contains("stale element") {
                    throw SeleniumError.elementNotFound("Stale element reference")
                }
                throw SeleniumError.javascriptError(errorMsg)
            }
            
            return json
            
        } catch let error as SeleniumError {
            throw error
        } catch {
            throw SeleniumError.connectionFailed(error.localizedDescription)
        }
    }
}

// MARK: - Convenience Extensions

extension SeleniumClient {
    // Quick element finding shortcuts
    public func findById(_ id: String) async throws -> WebElement {
        try await findElement(by: .id, value: id)
    }
    
    public func findByCSS(_ selector: String) async throws -> WebElement {
        try await findElement(by: .cssSelector, value: selector)
    }
    
    public func findByXPath(_ xpath: String) async throws -> WebElement {
        try await findElement(by: .xpath, value: xpath)
    }
    
    public func findByName(_ name: String) async throws -> WebElement {
        try await findElement(by: .name, value: name)
    }
    
    public func findByClassName(_ className: String) async throws -> WebElement {
        try await findElement(by: .className, value: className)
    }
    
    public func findByTagName(_ tagName: String) async throws -> WebElement {
        try await findElement(by: .tagName, value: tagName)
    }
    
    public func findByLinkText(_ text: String) async throws -> WebElement {
        try await findElement(by: .linkText, value: text)
    }
    
    // Quick action shortcuts
    public func click(by strategy: LocatorStrategy, value: String) async throws {
        let element = try await findElement(by: strategy, value: value)
        try await click(element: element)
    }
    
    public func type(into strategy: LocatorStrategy, value: String, text: String) async throws {
        let element = try await findElement(by: strategy, value: value)
        try await sendKeys(element: element, text: text)
    }
    
    public func getText(by strategy: LocatorStrategy, value: String) async throws -> String {
        let element = try await findElement(by: strategy, value: value)
        return try await getText(element: element)
    }
    
    // Form helpers
    public func fillForm(_ fields: [(LocatorStrategy, String, String)]) async throws {
        for (strategy, selector, value) in fields {
            let element = try await waitForElementClickable(by: strategy, value: selector)
            try await clear(element: element)
            try await sendKeys(element: element, text: value)
        }
    }
    
    public func submitForm(by strategy: LocatorStrategy, value: String) async throws {
        let submitBtn = try await waitForElementClickable(by: strategy, value: value)
        try await click(element: submitBtn)
    }
}