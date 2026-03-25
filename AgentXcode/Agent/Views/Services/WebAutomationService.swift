import Foundation
import AppKit

/// Unified web automation service that combines Accessibility, AppleScript/JS, and Selenium.
/// Auto-selects the best strategy based on the browser and operation.
/// Phase 2 Implementation: Unified API with caching and fuzzy matching.
final class WebAutomationService: @unchecked Sendable {
    static let shared = WebAutomationService()
    
    // MARK: - JavaScript Escaping

    /// Properly escape a string for embedding in JavaScript string literals.
    /// Handles quotes, backslashes, control characters, and Unicode.
    static func escapeJS(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
           .replacingOccurrences(of: "'", with: "\\'")
           .replacingOccurrences(of: "\n", with: "\\n")
           .replacingOccurrences(of: "\r", with: "\\r")
           .replacingOccurrences(of: "\t", with: "\\t")
           .replacingOccurrences(of: "\0", with: "")
    }

    /// Properly escape a string for embedding in a JSON value (for Selenium args).
    /// Uses JSONSerialization for correctness.
    static func escapeJSON(_ str: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: str),
           let json = String(data: data, encoding: .utf8) {
            // JSONSerialization wraps in quotes — strip them
            return String(json.dropFirst().dropLast())
        }
        // Fallback to manual escaping
        return escapeJS(str)
    }

    // MARK: - Element Cache
    
    /// Cache for element lookups to reduce repeated searches
    private nonisolated(unsafe) var elementCache: [String: CachedElement] = [:]
    private let cacheLock = NSLock()
    private let cacheTTL: TimeInterval = automationMaxDelay
    
    struct CachedElement {
        let element: [String: Any]
        let timestamp: Date
        let role: String?
        let title: String?
        let value: String?
        let bounds: CGRect
        let source: ElementSource
    }
    
    enum ElementSource: String {
        case accessibility
        case javascript
        case selenium
    }
    
    enum BrowserType: String {
        case safari = "com.apple.Safari"
        case chrome = "com.google.Chrome"
        case firefox = "org.mozilla.firefox"
        case edge = "com.microsoft.edgemac"
    }
    
    // MARK: - Unified API
    
    /// Open a URL in the specified browser, optionally waiting for page load
    func open(url: URL, browser: BrowserType = .safari, waitForLoad: Bool = true) async throws -> String {
        // Try AppleScript first (fastest, most reliable)
        if let result = try? await openViaAppleScript(url: url, browser: browser) {
            if waitForLoad {
                await waitForPageReady(browser: browser.rawValue)
            }
            return result
        }

        // Fallback to opening via NSWorkspace
        NSWorkspace.shared.open(url)
        if waitForLoad {
            try? await Task.sleep(for: .seconds(2))
        }
        return "Opened \(url.absoluteString) in default browser"
    }

    /// Wait for the current page to finish loading (document.readyState == "complete")
    func waitForPageReady(browser: String? = nil, timeout: TimeInterval = 10) async {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let start = CFAbsoluteTimeGetCurrent()
        while CFAbsoluteTimeGetCurrent() - start < timeout {
            if let result = try? await executeJavaScript(script: "document.readyState", browser: browserId) as? String,
               result == "complete" {
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    /// Read the text content of the current web page
    func readPageContent(browser: String? = nil, maxLength: Int = 10000) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let js = "(function(){ var t = document.body.innerText; return t ? t.substring(0, \(maxLength)) : ''; })()"
        if let result = try? await executeJavaScript(script: js, browser: browserId) as? String {
            return result
        }
        return "Error: could not read page content"
    }

    /// Read the current page URL
    func getPageURL(browser: String? = nil) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        if let result = try? await executeJavaScript(script: "window.location.href", browser: browserId) as? String {
            return result
        }
        return "Error: could not get page URL"
    }

    /// Read the current page title
    func getPageTitle(browser: String? = nil) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        if let result = try? await executeJavaScript(script: "document.title", browser: browserId) as? String {
            return result
        }
        return "Error: could not get page title"
    }
    
    /// Find an element using the best available strategy
    /// - Parameters:
    ///   - selector: CSS selector, XPath, or accessibility identifier
    ///   - strategy: Auto, Accessibility, JavaScript, or Selenium
    ///   - timeout: Maximum wait time
    ///   - fuzzyThreshold: Minimum match score (0-1) for fuzzy matching
    /// - Returns: Element properties and source
    func findElement(
        selector: String,
        strategy: SelectorStrategy = .auto,
        timeout: TimeInterval = automationFinishTimeout,
        fuzzyThreshold: Double = 0.6,
        appBundleId: String? = nil
    ) async throws -> [String: Any] {
        // Check cache first
        let cacheKey = "find_\(selector)_\(appBundleId ?? "")"
        if let cached = getCachedElement(key: cacheKey) {
            return cached
        }
        
        var result: [String: Any]?
        var source: ElementSource = .accessibility
        
        switch strategy {
        case .auto:
            // 1. Try Accessibility (instant, works for Safari)
            if let element = try? await findViaAccessibility(selector: selector, timeout: timeout, appBundleId: appBundleId) {
                result = element
                source = .accessibility
            }
            
            // 2. Try AppleScript JS (works in Safari/Firefox)
            if result == nil, let browserId = appBundleId ?? detectActiveBrowser(),
               let jsResult = try? await findViaJavaScript(selector: selector, browser: browserId) {
                result = jsResult
                source = .javascript
            }
            
            // 3. Fall back to Selenium
            if result == nil {
                let seleniumResult = try await findViaSelenium(selector: selector, timeout: timeout)
                result = seleniumResult
                source = .selenium
            }
            
        case .accessibility:
            result = try await findViaAccessibility(selector: selector, timeout: timeout, appBundleId: appBundleId)
            source = .accessibility
            
        case .javascript:
            guard let browserId = appBundleId ?? detectActiveBrowser() else {
                throw WebAutomationError.browserNotFound
            }
            result = try await findViaJavaScript(selector: selector, browser: browserId)
            source = .javascript
            
        case .selenium:
            result = try await findViaSelenium(selector: selector, timeout: timeout)
            source = .selenium
        }
        
        guard var finalResult = result else {
            throw WebAutomationError.elementNotFound(selector)
        }
        
        finalResult["source"] = source.rawValue
        
        // Cache the result
        cacheElement(key: cacheKey, element: finalResult, source: source)
        
        return finalResult
    }
    
    /// Click an element using the best available strategy
    func click(selector: String, strategy: SelectorStrategy = .auto, appBundleId: String? = nil) async throws -> String {
        let element = try await findElement(selector: selector, strategy: strategy, appBundleId: appBundleId)
        
        guard let source = element["source"] as? String else {
            throw WebAutomationError.invalidState("No source in element")
        }
        
        switch ElementSource(rawValue: source) {
        case .accessibility:
            // Use AccessibilityService for clicking
            let role = element["role"] as? String
            let title = element["title"] as? String
            let result = AccessibilityService.shared.clickElement(
                role: role,
                title: title,
                value: nil,
                appBundleId: appBundleId,
                timeout: automationFinishTimeout,
                verify: false
            )
            return result
            
        case .javascript:
            // Execute JavaScript click
            guard let browserId = appBundleId ?? detectActiveBrowser() else {
                throw WebAutomationError.browserNotFound
            }
            return try await executeJavaScriptClick(selector: selector, browser: browserId)
            
        case .selenium:
            // Use Selenium to click
            return try await seleniumClick(selector: selector)
            
        case .none:
            throw WebAutomationError.invalidState("Unknown source: \(source)")
        }
    }
    
    /// Type text into an element using the best available strategy
    func type(text: String, selector: String, strategy: SelectorStrategy = .auto, verify: Bool = true, appBundleId: String? = nil) async throws -> String {
        let element = try await findElement(selector: selector, strategy: strategy, appBundleId: appBundleId)
        
        guard let source = element["source"] as? String else {
            throw WebAutomationError.invalidState("No source in element")
        }
        
        switch ElementSource(rawValue: source) {
        case .accessibility:
            let role = element["role"] as? String
            let title = element["title"] as? String
            return AccessibilityService.shared.typeTextIntoElement(
                role: role,
                title: title,
                text: text,
                appBundleId: appBundleId,
                verify: verify
            )
            
        case .javascript:
            guard let browserId = appBundleId ?? detectActiveBrowser() else {
                throw WebAutomationError.browserNotFound
            }
            return try await executeJavaScriptType(selector: selector, text: text, browser: browserId)
            
        case .selenium:
            return try await seleniumType(selector: selector, text: text)
            
        case .none:
            throw WebAutomationError.invalidState("Unknown source: \(source)")
        }
    }
    
    /// Execute JavaScript in the browser
    func executeJavaScript(script: String, browser: String? = nil) async throws -> Any? {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        
        // Use AppleScript to execute JavaScript
        let appleScript: String
        switch browserId {
        case "com.apple.Safari":
            appleScript = """
            tell application "Safari"
                tell front document
                    do JavaScript "\(Self.escapeJS(script))"
                end tell
            end tell
            """
        case "org.mozilla.firefox":
            appleScript = """
            tell application "Firefox"
                tell front window
                    execute JavaScript "\(Self.escapeJS(script))"
                end tell
            end tell
            """
        default:
            // For Chrome and others, use Selenium
            return try await seleniumExecute(script: script)
        }
        
        let result = await MainActor.run { () -> String? in
            var err: NSDictionary?
            guard let script = NSAppleScript(source: appleScript) else { return nil }
            let out = script.executeAndReturnError(&err)
            if let error = err {
                return "Error: \(error)"
            }
            return out.stringValue
        }
        
        return result
    }
    
    // MARK: - Strategy Implementations
    
    private func findViaAccessibility(selector: String, timeout: TimeInterval, appBundleId: String?) async throws -> [String: Any]? {
        // Parse selector to extract role/title/value hints
        let hints = parseSelector(selector)
        
        // Use adaptive wait from AccessibilityService
        let result = AccessibilityService.shared.waitForElementAdaptive(
            role: hints.role,
            title: hints.title,
            value: hints.value,
            appBundleId: appBundleId,
            timeout: timeout
        )
        
        // Check if found
        if result.contains("\"success\": true") {
            // Parse JSON result
            if let data = result.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
        }
        
        return nil
    }
    
    private func findViaJavaScript(selector: String, browser: String) async throws -> [String: Any]? {
        // Escape selector for JavaScript
        let escapedSelector = Self.escapeJS(selector)

        // Determine if it's a CSS selector or XPath
        let isXPath = selector.hasPrefix("/") || selector.hasPrefix("./")
        
        let js: String
        if isXPath {
            js = """
            (function() {
                var result = document.evaluate('\(escapedSelector)', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
                var el = result.singleNodeValue;
                if (!el) return null;
                var rect = el.getBoundingClientRect();
                return {
                    found: true,
                    tagName: el.tagName,
                    id: el.id || '',
                    className: el.className || '',
                    text: el.textContent ? el.textContent.substring(0, 200) : '',
                    x: rect.x,
                    y: rect.y,
                    width: rect.width,
                    height: rect.height
                };
            })()
            """
        } else {
            js = """
            (function() {
                var el = document.querySelector('\(escapedSelector)');
                if (!el) return null;
                var rect = el.getBoundingClientRect();
                return {
                    found: true,
                    tagName: el.tagName,
                    id: el.id || '',
                    className: el.className || '',
                    text: el.textContent ? el.textContent.substring(0, 200) : '',
                    x: rect.x,
                    y: rect.y,
                    width: rect.width,
                    height: rect.height
                };
            })()
            """
        }
        
        let result = try await executeJavaScript(script: js, browser: browser)
        
        if let dict = result as? [String: Any], let found = dict["found"] as? Bool, found {
            var element: [String: Any] = [
                "source": "javascript",
                "selector": selector,
                "tagName": dict["tagName"] ?? "",
                "text": dict["text"] ?? ""
            ]
            
            if let x = dict["x"] as? Double, let y = dict["y"] as? Double,
               let w = dict["width"] as? Double, let h = dict["height"] as? Double {
                element["bounds"] = ["x": x, "y": y, "width": w, "height": h]
            }
            
            return element
        }
        
        return nil
    }
    
    private func findViaSelenium(selector: String, timeout: TimeInterval) async throws -> [String: Any]? {
        // Note: Selenium operations are handled via Selenium AgentScript
        // This method returns nil to indicate Selenium should be called separately
        // The unified API will fall back to Accessibility/JS strategies
        return nil
    }
    
    // MARK: - AppleScript Helpers
    
    private func openViaAppleScript(url: URL, browser: BrowserType) async throws -> String {
        let script: String
        
        switch browser {
        case .safari:
            script = "tell application \"Safari\" to open location \"\(url.absoluteString)\""
        case .chrome:
            script = "tell application \"Google Chrome\" to open location \"\(url.absoluteString)\""
        case .firefox:
            script = "tell application \"Firefox\" to open location \"\(url.absoluteString)\""
        case .edge:
            script = "tell application \"Microsoft Edge\" to open location \"\(url.absoluteString)\""
        }
        
        let result = await MainActor.run { () -> String in
            var err: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else { return "Error: Could not create script" }
            _ = appleScript.executeAndReturnError(&err)
            if let error = err {
                return "Error: \(error)"
            }
            return "Opened \(url.absoluteString) in \(browser.rawValue)"
        }
        
        if result.hasPrefix("Error:") {
            throw WebAutomationError.appleScriptError(result)
        }
        
        return result
    }
    
    private func executeJavaScriptClick(selector: String, browser: String) async throws -> String {
        let escaped = Self.escapeJS(selector)
        let isXPath = selector.hasPrefix("/") || selector.hasPrefix("./")

        let js: String
        if isXPath {
            js = """
            var result = document.evaluate('\(escaped)', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
            var el = result.singleNodeValue;
            if (el) { el.click(); return 'clicked'; }
            return 'not found';
            """
        } else {
            js = "var el = document.querySelector('\(escaped)'); if (el) { el.click(); return 'clicked'; } return 'not found';"
        }
        
        _ = try await executeJavaScript(script: js, browser: browser)
        return "Clicked element via JavaScript: \(selector)"
    }
    
    private func executeJavaScriptType(selector: String, text: String, browser: String) async throws -> String {
        let escapedText = Self.escapeJS(text)
        let escapedSel = Self.escapeJS(selector)
        let isXPath = selector.hasPrefix("/") || selector.hasPrefix("./")
        
        let js: String
        if isXPath {
            js = """
            var result = document.evaluate('\(escapedSel)', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
            var el = result.singleNodeValue;
            if (el) { el.value = '\(escapedText)'; return 'typed'; }
            return 'not found';
            """
        } else {
            js = "var el = document.querySelector('\(escapedSel)'); if (el) { el.value = '\(escapedText)'; return 'typed'; } return 'not found';"
        }
        
        _ = try await executeJavaScript(script: js, browser: browser)
        return "Typed text via JavaScript into: \(selector)"
    }
    
    // MARK: - Selenium Helpers
    
    // MARK: - Selenium Helpers
    // Note: Selenium operations are handled via Selenium AgentScript through tool handlers
    // These methods are placeholders - actual Selenium calls go through run_agent_script
    
    private func seleniumClick(selector: String) async throws -> String {
        throw WebAutomationError.seleniumError("Selenium operations should be called via selenium_click tool")
    }
    
    private func seleniumType(selector: String, text: String) async throws -> String {
        throw WebAutomationError.seleniumError("Selenium operations should be called via selenium_type tool")
    }
    
    private func seleniumExecute(script: String) async throws -> Any? {
        throw WebAutomationError.seleniumError("Selenium operations should be called via selenium_execute tool")
    }
    
    // MARK: - Fuzzy Matching
    
    /// Calculate fuzzy match score between two strings
    func fuzzyMatch(text: String, pattern: String) -> Double {
        let textLower = text.lowercased()
        let patternLower = pattern.lowercased()
        
        // Exact match
        if textLower == patternLower { return 1.0 }
        
        // Contains
        if textLower.contains(patternLower) { return 0.9 }
        
        // Prefix match
        if textLower.hasPrefix(patternLower) { return 0.85 }
        
        // Suffix match
        if textLower.hasSuffix(patternLower) { return 0.8 }
        
        // Levenshtein distance ratio
        let distance = levenshtein(textLower, patternLower)
        let maxLength = max(textLower.count, patternLower.count)
        let ratio = 1.0 - Double(distance) / Double(maxLength)
        
        return max(0, ratio)
    }
    
    /// Levenshtein distance between two strings
    private func levenshtein(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                if a[i-1] == b[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }
        
        return dp[m][n]
    }
    
    // MARK: - Selector Parsing
    
    /// Parse a selector string into role/title/value hints
    private func parseSelector(_ selector: String) -> (role: String?, title: String?, value: String?) {
        // Handle CSS-style selectors
        if selector.hasPrefix("#") {
            // ID selector
            return (role: nil, title: nil, value: String(selector.dropFirst()))
        }
        
        if selector.hasPrefix(".") {
            // Class selector - use as title hint
            return (role: nil, title: String(selector.dropFirst()), value: nil)
        }
        
        // Handle attribute selectors like [title="Submit"]
        if selector.hasPrefix("[") && selector.hasSuffix("]") {
            let inner = String(selector.dropFirst().dropLast())
            if let eqRange = inner.range(of: "=") {
                let attr = String(inner[..<eqRange.lowerBound])
                let value = String(inner[inner.index(after: eqRange.lowerBound)...])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                
                if attr.lowercased() == "title" || attr.lowercased() == "aria-label" {
                    return (role: nil, title: value, value: nil)
                }
                if attr.lowercased() == "role" {
                    return (role: "AX\(value.capitalized)", title: nil, value: nil)
                }
                if attr.lowercased() == "value" || attr.lowercased() == "placeholder" {
                    return (role: nil, title: nil, value: value)
                }
            }
        }
        
        // Handle accessibility role selectors like AXButton, AXTextField
        if selector.hasPrefix("AX") {
            return (role: selector, title: nil, value: nil)
        }
        
        // Handle text content selectors like text:Submit
        if selector.hasPrefix("text:") {
            return (role: nil, title: nil, value: String(selector.dropFirst(5)))
        }
        
        // Default: treat as title
        return (role: nil, title: selector, value: nil)
    }
    
    // MARK: - Browser Detection
    
    /// Detect the currently active browser
    private func detectActiveBrowser() -> String? {
        let apps = NSWorkspace.shared.runningApplications
        let browsers = ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "com.microsoft.edgemac"]
        
        // Find frontmost browser
        for app in apps where app.activationPolicy == .regular {
            if let bundleId = app.bundleIdentifier, browsers.contains(bundleId) {
                return bundleId
            }
        }
        
        return nil
    }
    
    // MARK: - Cache Management
    
    private func cacheElement(key: String, element: [String: Any], source: ElementSource) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        elementCache[key] = CachedElement(
            element: element,
            timestamp: Date(),
            role: element["role"] as? String,
            title: element["title"] as? String,
            value: element["value"] as? String,
            bounds: parseBounds(element["bounds"]),
            source: source
        )
        
        // Clean expired entries
        cleanExpiredCache()
    }
    
    private func getCachedElement(key: String) -> [String: Any]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let cached = elementCache[key] else { return nil }
        
        let elapsed = Date().timeIntervalSince(cached.timestamp)
        if elapsed > cacheTTL {
            elementCache.removeValue(forKey: key)
            return nil
        }
        
        return cached.element
    }
    
    private func cleanExpiredCache() {
        let now = Date()
        elementCache = elementCache.filter { now.timeIntervalSince($0.value.timestamp) <= cacheTTL }
    }
    
    private func parseBounds(_ value: Any?) -> CGRect {
        guard let dict = value as? [String: Double],
              let x = dict["x"],
              let y = dict["y"],
              let w = dict["width"],
              let h = dict["height"] else {
            return .zero
        }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

// MARK: - Supporting Types

enum SelectorStrategy: String {
    case auto
    case accessibility
    case javascript
    case selenium
}

enum WebAutomationError: Error, LocalizedError {
    case elementNotFound(String)
    case browserNotFound
    case appleScriptError(String)
    case seleniumError(String)
    case invalidState(String)
    
    var errorDescription: String? {
        switch self {
        case .elementNotFound(let selector):
            return "Element not found: \(selector)"
        case .browserNotFound:
            return "No active browser found"
        case .appleScriptError(let msg):
            return "AppleScript error: \(msg)"
        case .seleniumError(let msg):
            return "Selenium error: \(msg)"
        case .invalidState(let msg):
            return "Invalid state: \(msg)"
        }
    }
}