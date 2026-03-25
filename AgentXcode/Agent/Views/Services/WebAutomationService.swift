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
    
    /// Open a URL in the specified browser. Returns immediately after the URL is sent — no page load wait.
    func open(url: URL, browser: BrowserType = .safari, waitForLoad: Bool = false) async throws -> String {
        // Try AppleScript first (fastest, most reliable)
        if let result = try? await openViaAppleScript(url: url, browser: browser) {
            if waitForLoad {
                await waitForPageReady(browser: browser.rawValue, timeout: 3)
            }
            return result
        }

        // Fallback to opening via NSWorkspace
        NSWorkspace.shared.open(url)
        if waitForLoad {
            try? await Task.sleep(for: .seconds(1))
        }
        return "Opened \(url.absoluteString) in default browser"
    }

    /// Wait for the current page to finish loading (document.readyState == "complete")
    func waitForPageReady(browser: String? = nil, timeout: TimeInterval = 3) async {
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
            let browserId = appBundleId ?? detectActiveBrowser()
            let isBrowser = browserId != nil && ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "com.microsoft.edgemac"].contains(browserId!)

            if isBrowser {
                // Web page: JS only (fast), skip accessibility (too slow on browser AX trees)
                if let jsResult = try? await findViaJavaScript(selector: selector, browser: browserId!) {
                    result = jsResult
                    source = .javascript
                }
            } else {
                // Native app: accessibility first
                if let element = try? await findViaAccessibility(selector: selector, timeout: min(timeout, 3), appBundleId: appBundleId) {
                    result = element
                    source = .accessibility
                }
            }

            // Fall back to Selenium if nothing found
            if result == nil {
                if let seleniumResult = try? await findViaSelenium(selector: selector, timeout: timeout) {
                    result = seleniumResult
                    source = .selenium
                }
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
        let browserId = appBundleId ?? detectActiveBrowser()
        let isBrowser = browserId != nil && ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "com.microsoft.edgemac"].contains(browserId!)

        // For browsers, skip findElement and click directly via JS (much faster)
        if isBrowser && (strategy == .auto || strategy == .javascript) {
            return try await executeJavaScriptClick(selector: selector, browser: browserId!)
        }

        let element = try await findElement(selector: selector, strategy: strategy, appBundleId: appBundleId)

        guard let source = element["source"] as? String else {
            throw WebAutomationError.invalidState("No source in element")
        }

        switch ElementSource(rawValue: source) {
        case .accessibility:
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
            guard let bid = browserId else {
                throw WebAutomationError.browserNotFound
            }
            return try await executeJavaScriptClick(selector: selector, browser: bid)

        case .selenium:
            return try await seleniumClick(selector: selector)

        case .none:
            throw WebAutomationError.invalidState("Unknown source: \(source)")
        }
    }
    
    /// Type text into an element using the best available strategy
    func type(text: String, selector: String, strategy: SelectorStrategy = .auto, verify: Bool = true, appBundleId: String? = nil) async throws -> String {
        let browserId = appBundleId ?? detectActiveBrowser()
        let isBrowser = browserId != nil && ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "com.microsoft.edgemac"].contains(browserId!)

        // For browsers, skip findElement and type directly via JS (much faster)
        if isBrowser && (strategy == .auto || strategy == .javascript) {
            return try await executeJavaScriptType(selector: selector, text: text, browser: browserId!)
        }

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
            guard let bid = browserId else {
                throw WebAutomationError.browserNotFound
            }
            return try await executeJavaScriptType(selector: selector, text: text, browser: bid)
            
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

        // First try: JS click (works for most buttons)
        let jsClick: String
        if isXPath {
            jsClick = """
            var result = document.evaluate('\(escaped)', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
            var el = result.singleNodeValue;
            if (el) { el.click(); return 'clicked'; }
            return 'not found';
            """
        } else {
            jsClick = """
            (function() {
                var el = \(Self.querySelectorWithIframes("'\(escaped)'"));
                if (el) { el.click(); return 'clicked'; }
                return 'not found';
            })()
            """
        }

        if let result = try? await executeJavaScript(script: jsClick, browser: browser) as? String,
           result == "clicked" {
            return "Clicked element via JavaScript: \(selector)"
        }

        // Second try: dispatch mousedown/mouseup/click events (handles event delegation)
        let jsDispatch: String
        if isXPath {
            jsDispatch = """
            (function() {
                var result = document.evaluate('\(escaped)', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
                var el = result.singleNodeValue;
                if (!el) return 'not found';
                el.dispatchEvent(new MouseEvent('mousedown', {bubbles:true,cancelable:true}));
                el.dispatchEvent(new MouseEvent('mouseup', {bubbles:true,cancelable:true}));
                el.dispatchEvent(new MouseEvent('click', {bubbles:true,cancelable:true}));
                return 'dispatched';
            })()
            """
        } else {
            jsDispatch = """
            (function() {
                var el = \(Self.querySelectorWithIframes("'\(escaped)'"));
                if (!el) return 'not found';
                el.dispatchEvent(new MouseEvent('mousedown', {bubbles:true,cancelable:true}));
                el.dispatchEvent(new MouseEvent('mouseup', {bubbles:true,cancelable:true}));
                el.dispatchEvent(new MouseEvent('click', {bubbles:true,cancelable:true}));
                return 'dispatched';
            })()
            """
        }

        if let result = try? await executeJavaScript(script: jsDispatch, browser: browser) as? String,
           result == "dispatched" {
            return "Clicked element via event dispatch: \(selector)"
        }

        // Third try: get element coordinates and do OS-level click via accessibility
        let jsCoords = isXPath ?
            """
            (function() {
                var result = document.evaluate('\(escaped)', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
                var el = result.singleNodeValue;
                if (!el) return 'not found';
                var r = el.getBoundingClientRect();
                return Math.round(r.x + r.width/2) + ',' + Math.round(r.y + r.height/2);
            })()
            """ :
            """
            (function() {
                var el = \(Self.querySelectorWithIframes("'\(escaped)'"));
                if (!el) return 'not found';
                var r = el.getBoundingClientRect();
                return Math.round(r.x + r.width/2) + ',' + Math.round(r.y + r.height/2);
            })()
            """

        if let coordStr = try? await executeJavaScript(script: jsCoords, browser: browser) as? String,
           coordStr != "not found",
           let commaIdx = coordStr.firstIndex(of: ",") {
            let xStr = String(coordStr[..<commaIdx])
            let yStr = String(coordStr[coordStr.index(after: commaIdx)...])
            if let x = Double(xStr), let y = Double(yStr) {
                // Need to offset by browser window/toolbar position
                // Get browser window bounds via AppleScript
                let boundsJS = "JSON.stringify({scrollX: window.scrollX, scrollY: window.scrollY, screenX: window.screenX, screenY: window.screenY, outerHeight: window.outerHeight, innerHeight: window.innerHeight})"
                if let boundsStr = try? await executeJavaScript(script: boundsJS, browser: browser) as? String,
                   let boundsData = boundsStr.data(using: .utf8),
                   let bounds = try? JSONSerialization.jsonObject(with: boundsData) as? [String: Double] {
                    let screenX = bounds["screenX"] ?? 0
                    let screenY = bounds["screenY"] ?? 0
                    let outerH = bounds["outerHeight"] ?? 0
                    let innerH = bounds["innerHeight"] ?? 0
                    let toolbarH = outerH - innerH
                    let absX = screenX + x
                    let absY = screenY + toolbarH + y
                    _ = AccessibilityService.shared.clickAt(x: CGFloat(absX), y: CGFloat(absY))
                    return "Clicked element via OS click at (\(Int(absX)),\(Int(absY))): \(selector)"
                }
            }
        }

        return "Error: could not click element: \(selector)"
    }
    
    private func executeJavaScriptType(selector: String, text: String, browser: String) async throws -> String {
        let escapedText = Self.escapeJS(text)
        let escapedSel = Self.escapeJS(selector)
        let isXPath = selector.hasPrefix("/") || selector.hasPrefix("./")

        // Set value AND fire input/change/blur events so React/Vue/Angular detect the change
        let eventDispatch = """
        el.dispatchEvent(new Event('input', {bubbles: true}));
        el.dispatchEvent(new Event('change', {bubbles: true}));
        el.dispatchEvent(new Event('blur', {bubbles: true}));
        """

        let js: String
        if isXPath {
            js = """
            var result = document.evaluate('\(escapedSel)', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
            var el = result.singleNodeValue;
            if (el) { el.focus(); el.value = '\(escapedText)'; \(eventDispatch) return 'typed'; }
            return 'not found';
            """
        } else {
            js = """
            (function() {
                var el = \(Self.querySelectorWithIframes("'\(escapedSel)'"));
                if (el) { el.focus(); el.value = '\(escapedText)'; \(eventDispatch) return 'typed'; }
                return 'not found';
            })()
            """
        }

        _ = try await executeJavaScript(script: js, browser: browser)
        return "Typed text via JavaScript into: \(selector)"
    }
    
    // MARK: - iframe Support

    /// JavaScript snippet that queries the main document and all same-origin iframes.
    /// Call with a quoted CSS selector string, e.g. querySelectorWithIframes("'button.submit'")
    static func querySelectorWithIframes(_ selectorExpr: String) -> String {
        """
        (function(sel) {
            var el = document.querySelector(sel);
            if (el) return el;
            var frames = document.querySelectorAll('iframe');
            for (var i = 0; i < frames.length; i++) {
                try {
                    var doc = frames[i].contentDocument;
                    if (doc) { el = doc.querySelector(sel); if (el) return el; }
                } catch(e) {}
            }
            return null;
        })(\(selectorExpr))
        """
    }

    // MARK: - Tab Switching

    /// Switch to a browser tab by index (0-based) or by title substring
    func switchTab(browser: String? = nil, index: Int? = nil, titleContains: String? = nil) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let script: String

        if let idx = index {
            switch browserId {
            case "com.apple.Safari":
                script = "tell application \"Safari\" to set current tab of front window to tab \(idx + 1) of front window"
            case "com.google.Chrome":
                script = "tell application \"Google Chrome\" to set active tab index of front window to \(idx + 1)"
            default:
                return "Error: tab switching not supported for this browser"
            }
        } else if let title = titleContains {
            let escaped = Self.escapeJS(title)
            switch browserId {
            case "com.apple.Safari":
                script = """
                tell application "Safari"
                    repeat with t in tabs of front window
                        if name of t contains "\(escaped)" then
                            set current tab of front window to t
                            return name of t
                        end if
                    end repeat
                    return "Tab not found"
                end tell
                """
            case "com.google.Chrome":
                script = """
                tell application "Google Chrome"
                    repeat with t in tabs of front window
                        if title of t contains "\(escaped)" then
                            set active tab index of front window to (index of t)
                            return title of t
                        end if
                    end repeat
                    return "Tab not found"
                end tell
                """
            default:
                return "Error: tab switching not supported for this browser"
            }
        } else {
            return "Error: specify index or titleContains"
        }

        let result = await MainActor.run { () -> String in
            var err: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else { return "Error: script creation failed" }
            let out = appleScript.executeAndReturnError(&err)
            if let error = err { return "Error: \(error)" }
            return out.stringValue ?? "Switched tab"
        }
        return result
    }

    /// List open browser tabs
    func listTabs(browser: String? = nil) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let script: String

        switch browserId {
        case "com.apple.Safari":
            script = """
            tell application "Safari"
                set tabList to ""
                repeat with i from 1 to count of tabs of front window
                    set t to tab i of front window
                    set tabList to tabList & i & ". " & name of t & " — " & URL of t & linefeed
                end repeat
                return tabList
            end tell
            """
        case "com.google.Chrome":
            script = """
            tell application "Google Chrome"
                set tabList to ""
                repeat with i from 1 to count of tabs of front window
                    set t to tab i of front window
                    set tabList to tabList & i & ". " & title of t & " — " & URL of t & linefeed
                end repeat
                return tabList
            end tell
            """
        default:
            return "Error: tab listing not supported for this browser"
        }

        let result = await MainActor.run { () -> String in
            var err: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else { return "Error: script creation failed" }
            let out = appleScript.executeAndReturnError(&err)
            if let error = err { return "Error: \(error)" }
            return out.stringValue ?? ""
        }
        return result
    }

    // MARK: - Window Management

    /// List all browser windows with their tabs
    func listWindows(browser: String? = nil) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let script: String

        switch browserId {
        case "com.apple.Safari":
            script = """
            tell application "Safari"
                set windowList to ""
                repeat with w from 1 to count of windows
                    set win to window w
                    set windowList to windowList & "Window " & w & ":"
                    if w = 1 then set windowList to windowList & " (front)"
                    set windowList to windowList & linefeed
                    repeat with t from 1 to count of tabs of win
                        set tabInfo to tab t of win
                        set windowList to windowList & "  " & t & ". " & name of tabInfo & " — " & URL of tabInfo & linefeed
                    end repeat
                end repeat
                return windowList
            end tell
            """
        case "com.google.Chrome":
            script = """
            tell application "Google Chrome"
                set windowList to ""
                repeat with w from 1 to count of windows
                    set win to window w
                    set windowList to windowList & "Window " & w & ":"
                    if w = 1 then set windowList to windowList & " (front)"
                    set windowList to windowList & linefeed
                    repeat with t from 1 to count of tabs of win
                        set tabInfo to tab t of win
                        set windowList to windowList & "  " & t & ". " & title of tabInfo & " — " & URL of tabInfo & linefeed
                    end repeat
                end repeat
                return windowList
            end tell
            """
        default:
            return "Error: window listing not supported for this browser"
        }

        return await runAppleScript(script)
    }

    /// Switch to a specific browser window by index (1-based)
    func switchWindow(browser: String? = nil, index: Int) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let script: String

        switch browserId {
        case "com.apple.Safari":
            script = """
            tell application "Safari"
                if \(index) > (count of windows) then return "Error: window \(index) does not exist"
                set index of window \(index) to 1
                return "Switched to window \(index): " & name of current tab of front window
            end tell
            """
        case "com.google.Chrome":
            script = """
            tell application "Google Chrome"
                if \(index) > (count of windows) then return "Error: window \(index) does not exist"
                set index of window \(index) to 1
                return "Switched to window \(index): " & title of active tab of front window
            end tell
            """
        default:
            return "Error: window switching not supported for this browser"
        }

        return await runAppleScript(script)
    }

    /// Open a new browser window
    func newWindow(browser: String? = nil, url: String? = nil) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let script: String

        switch browserId {
        case "com.apple.Safari":
            if let u = url {
                script = """
                tell application "Safari"
                    make new document with properties {URL:"\(Self.escapeJS(u))"}
                    return "New window opened: \(Self.escapeJS(u))"
                end tell
                """
            } else {
                script = """
                tell application "Safari"
                    make new document
                    return "New window opened"
                end tell
                """
            }
        case "com.google.Chrome":
            if let u = url {
                script = """
                tell application "Google Chrome"
                    set newWin to make new window
                    set URL of active tab of newWin to "\(Self.escapeJS(u))"
                    return "New window opened: \(Self.escapeJS(u))"
                end tell
                """
            } else {
                script = """
                tell application "Google Chrome"
                    make new window
                    return "New window opened"
                end tell
                """
            }
        default:
            return "Error: new window not supported for this browser"
        }

        return await runAppleScript(script)
    }

    /// Close a browser window by index (1-based). Defaults to front window.
    func closeWindow(browser: String? = nil, index: Int = 1) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let script: String

        switch browserId {
        case "com.apple.Safari":
            script = """
            tell application "Safari"
                if \(index) > (count of windows) then return "Error: window \(index) does not exist"
                close window \(index)
                return "Closed window \(index)"
            end tell
            """
        case "com.google.Chrome":
            script = """
            tell application "Google Chrome"
                if \(index) > (count of windows) then return "Error: window \(index) does not exist"
                close window \(index)
                return "Closed window \(index)"
            end tell
            """
        default:
            return "Error: close window not supported for this browser"
        }

        return await runAppleScript(script)
    }

    /// Shared AppleScript runner
    private func runAppleScript(_ script: String) async -> String {
        await MainActor.run { () -> String in
            var err: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else { return "Error: script creation failed" }
            let out = appleScript.executeAndReturnError(&err)
            if let error = err { return "Error: \(error)" }
            return out.stringValue ?? "OK"
        }
    }

    // MARK: - Wait for Element

    /// Wait for a CSS selector to appear in the page (polls via JavaScript)
    func waitForElement(selector: String, browser: String? = nil, timeout: TimeInterval = 10) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let escaped = Self.escapeJS(selector)
        let start = CFAbsoluteTimeGetCurrent()

        while CFAbsoluteTimeGetCurrent() - start < timeout {
            let js = "(function(){ var el = \(Self.querySelectorWithIframes("'\(escaped)'")); return el ? 'found' : 'waiting'; })()"
            if let result = try? await executeJavaScript(script: js, browser: browserId) as? String,
               result == "found" {
                return "Element found: \(selector)"
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return "Timeout: element '\(selector)' not found after \(Int(timeout))s"
    }

    // MARK: - Scroll to Element

    /// Scroll until a CSS selector is visible, handling lazy-loaded content
    func scrollToElement(selector: String, browser: String? = nil, maxScrolls: Int = 20) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let escaped = Self.escapeJS(selector)
        let js = """
        (function() {
            var el = \(Self.querySelectorWithIframes("'\(escaped)'"));
            if (el) { el.scrollIntoView({behavior:'smooth',block:'center'}); return 'scrolled'; }
            return 'not found';
        })()
        """
        // First try — element might already exist
        if let result = try? await executeJavaScript(script: js, browser: browserId) as? String,
           result == "scrolled" {
            return "Scrolled to: \(selector)"
        }
        // Scroll down incrementally to trigger lazy loading
        for i in 0..<maxScrolls {
            _ = try? await executeJavaScript(script: "window.scrollBy(0, window.innerHeight * 0.8)", browser: browserId)
            try? await Task.sleep(for: .milliseconds(300))
            if let result = try? await executeJavaScript(script: js, browser: browserId) as? String,
               result == "scrolled" {
                return "Scrolled to: \(selector) (after \(i + 1) scroll(s))"
            }
        }
        return "Element '\(selector)' not found after scrolling \(maxScrolls) times"
    }

    // MARK: - Select Dropdown

    /// Select an option in a <select> dropdown by value, text, or index
    func selectOption(selector: String, value: String? = nil, text: String? = nil, index: Int? = nil, browser: String? = nil) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let escapedSel = Self.escapeJS(selector)

        let setOption: String
        if let val = value {
            setOption = "el.value = '\(Self.escapeJS(val))';"
        } else if let txt = text {
            let esc = Self.escapeJS(txt)
            setOption = "for(var i=0;i<el.options.length;i++){if(el.options[i].text.indexOf('\(esc)')>=0){el.selectedIndex=i;break;}}"
        } else if let idx = index {
            setOption = "el.selectedIndex = \(idx);"
        } else {
            return "Error: specify value, text, or index"
        }

        let js = """
        (function() {
            var el = \(Self.querySelectorWithIframes("'\(escapedSel)'"));
            if (!el || el.tagName !== 'SELECT') return 'not found or not a select';
            \(setOption)
            el.dispatchEvent(new Event('change', {bubbles: true}));
            return 'selected: ' + el.options[el.selectedIndex].text;
        })()
        """
        if let result = try? await executeJavaScript(script: js, browser: browserId) as? String {
            return result
        }
        return "Error: could not select option"
    }

    // MARK: - File Upload

    /// Trigger file upload dialog for an <input type="file"> via accessibility click
    /// Note: JS cannot set file input values (browser security). This clicks the input to open the file picker.
    func triggerFileUpload(selector: String, browser: String? = nil) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let escaped = Self.escapeJS(selector)
        let js = """
        (function() {
            var el = \(Self.querySelectorWithIframes("'\(escaped)'"));
            if (!el) return 'not found';
            el.click();
            return 'file dialog triggered';
        })()
        """
        if let result = try? await executeJavaScript(script: js, browser: browserId) as? String {
            return result
        }
        return "Error: could not trigger file upload"
    }

    // MARK: - Cookie / localStorage

    /// Read cookies or localStorage for the current page
    func readStorage(type: String = "cookies", key: String? = nil, browser: String? = nil) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let js: String
        switch type {
        case "localStorage":
            if let k = key {
                js = "localStorage.getItem('\(Self.escapeJS(k))') || '(not set)'"
            } else {
                js = "(function(){var r={};for(var i=0;i<localStorage.length;i++){var k=localStorage.key(i);r[k]=localStorage.getItem(k);}return JSON.stringify(r);})()"
            }
        case "sessionStorage":
            if let k = key {
                js = "sessionStorage.getItem('\(Self.escapeJS(k))') || '(not set)'"
            } else {
                js = "(function(){var r={};for(var i=0;i<sessionStorage.length;i++){var k=sessionStorage.key(i);r[k]=sessionStorage.getItem(k);}return JSON.stringify(r);})()"
            }
        default: // cookies
            js = "document.cookie || '(no cookies)'"
        }
        if let result = try? await executeJavaScript(script: js, browser: browserId) as? String {
            return result
        }
        return "Error: could not read \(type)"
    }

    // MARK: - Form Submit

    /// Submit a form by selector or find the closest form to an element
    func submitForm(selector: String? = nil, browser: String? = nil) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let js: String
        if let sel = selector {
            let escaped = Self.escapeJS(sel)
            js = """
            (function() {
                var el = \(Self.querySelectorWithIframes("'\(escaped)'"));
                if (!el) return 'not found';
                var form = el.tagName === 'FORM' ? el : el.closest('form');
                if (!form) return 'no form found';
                form.dispatchEvent(new Event('submit', {bubbles:true,cancelable:true}));
                form.submit();
                return 'submitted';
            })()
            """
        } else {
            js = "(function(){var f=document.querySelector('form');if(f){f.submit();return 'submitted';}return 'no form found';})()"
        }
        if let result = try? await executeJavaScript(script: js, browser: browserId) as? String {
            return result
        }
        return "Error: could not submit form"
    }

    // MARK: - Browser Navigation

    /// Navigate back, forward, or reload
    func navigate(action: String, browser: String? = nil) async -> String {
        let browserId = browser ?? detectActiveBrowser() ?? "com.apple.Safari"
        let js: String
        switch action {
        case "back": js = "history.back(); 'navigated back'"
        case "forward": js = "history.forward(); 'navigated forward'"
        case "reload": js = "location.reload(); 'reloaded'"
        default: return "Error: unknown action '\(action)'. Use back, forward, or reload."
        }
        _ = try? await executeJavaScript(script: js, browser: browserId)
        return "Navigated: \(action)"
    }

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

    // MARK: - Safari Google Search

    /// Perform a Google search in Safari and return the results page content.
    /// Opens google.com, types the query, submits, waits for results, returns text.
    func safariGoogleSearch(query: String, maxResults: Int = 3000) async -> String {
        let escaped = Self.escapeJS(query)

        // 1. Open google.com
        let openScript = """
        tell application "Safari"
            activate
            if (count of windows) = 0 then make new document
            set URL of front document to "https://www.google.com"
        end tell
        """
        let openOK = await runAppleScript(openScript)
        guard !openOK.hasPrefix("Error") else { return openOK }

        // 2. Wait for google.com to load
        for _ in 0..<10 {
            try? await Task.sleep(for: .milliseconds(300))
            let ready = await runAppleScript("""
            tell application "Safari" to do JavaScript "document.readyState" in front document
            """)
            if ready == "complete" { break }
        }

        // 3. Type query and submit
        let searchJS = """
        (function() {
            var el = document.querySelector('textarea[name=q], input[name=q]');
            if (!el) return 'not found';
            el.focus();
            el.value = '\(escaped)';
            el.dispatchEvent(new Event('input', {bubbles: true}));
            var form = el.closest('form');
            if (form) { form.submit(); return 'submitted'; }
            return 'no form';
        })()
        """
        let submitResult = await runAppleScript("""
        tell application "Safari" to do JavaScript "\(Self.escapeJS(searchJS))" in front document
        """)
        guard submitResult == "submitted" else {
            return "{\"success\": false, \"error\": \"Search submit failed: \(submitResult)\"}"
        }

        // 4. Wait for results page to load
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(300))
            let title = await runAppleScript("""
            tell application "Safari" to return name of front document
            """)
            if title.contains("Google Search") || title.contains("- Google") { break }
        }

        // Small extra wait for content to render
        try? await Task.sleep(for: .milliseconds(500))

        // 5. Get results
        let url = await runAppleScript("""
        tell application "Safari" to return URL of front document
        """)
        let title = await runAppleScript("""
        tell application "Safari" to return name of front document
        """)
        let content = await runAppleScript("""
        tell application "Safari" to do JavaScript "document.body.innerText.substring(0, \(maxResults))" in front document
        """)

        return """
        {"success": true, "query": "\(Self.escapeJS(query))", "url": "\(Self.escapeJS(url))", "title": "\(Self.escapeJS(title))", "content": "\(Self.escapeJS(content))"}
        """
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
    case timeout(String)
    case appleScriptError(String)
    case seleniumError(String)
    case invalidState(String)
    
    var errorDescription: String? {
        switch self {
        case .elementNotFound(let selector):
            return "Element not found: \(selector)"
        case .timeout(let msg):
            return "Timeout: \(msg)"
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