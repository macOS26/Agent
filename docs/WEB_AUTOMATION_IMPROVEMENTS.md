# Web Automation Improvements Analysis

## Executive Summary

This document analyzes the Agent codebase and provides recommendations for improving web page automation using Accessibility, System Events, CGEvents, AppleScript, AgentScripts, and tool call patterns.

---

## Current Architecture Overview

### 1. Accessibility Layer (`AccessibilityService.swift`)

**Strengths:**
- Full CGEvent simulation (keyboard, mouse, scroll)
- AXUIElement hierarchy traversal
- Position-based element lookup via `axElementAt(x:y:)`
- Timeout wrapper to prevent hangs on complex text views
- Audit logging for all operations

**Weaknesses:**
- No semantic element understanding (no XPath/CSS selector equivalent)
- No wait strategies beyond polling with fixed intervals
- No automatic retry on transient failures
- Element queries require exact role/title matching (no fuzzy matching)

**Current Tool Mapping:**
```
ax_list_windows      → CGWindowListCopyWindowInfo
ax_inspect_element   → AXUIElementCopyElementAtPosition with depth traversal
ax_find_element      → Recursive hierarchy search with timeout
ax_wait_for_element  → Polling loop with configurable interval
ax_click/ax_type_text → CGEvent mouse/keyboard simulation
ax_set_properties     → AXUIElementSetAttributeValue
```

### 2. Apple Event Layer (`AppleEventService.swift`)

**Strengths:**
- Dynamic ObjC dispatch via KVC and `NSInvocation`
- No compilation needed - instant queries
- NSAppleScript fallback for complex property access
- SDEF-aware key hints via `SDEFService`

**Weaknesses:**
- Only works with scriptable applications
- Web browsers have limited AppleScript support
- No native DOM manipulation
- Cannot interact with non-scriptable web elements

### 3. AgentScript Layer (`ScriptService.swift`)

**Strengths:**
- Compiled Swift dylibs with full TCC inheritance
- ScriptingBridge for type-safe app control
- In-process execution (no subprocess overhead)
- Real-time stdout streaming

**Weaknesses:**
- Requires compilation before first run
- Package.swift dependency management complexity
- Limited to scriptable apps

### 4. Selenium/WebDriver Layer (`SeleniumBridge.swift`)

**Strengths:**
- Full W3C WebDriver spec implementation
- Works with SafariDriver, ChromeDriver, GeckoDriver
- Async/await native Swift implementation
- Proper locator strategies (CSS, XPath, ID, etc.)

**Weaknesses:**
- Requires external driver process running
- No built-in driver management
- Session management is manual

---

## Recommendations for Improvement

### A. Accessibility Improvements

#### 1. Smart Element Location Strategy

```swift
// CURRENT: Simple hierarchy traversal
func findElementInHierarchy(_ parent: AXUIElement, role: String?, title: String?, value: String?, depth: Int) -> AXUIElement?

// PROPOSED: Multi-strategy element finder with scoring
struct ElementMatchCriteria {
    let role: String?
    let title: String?           // Exact or partial match
    let value: String?           // Value content match
    let attributedTitle: String? // AXAttributedTitle for rich text
    let description: String?     // AXDescription
    let identifier: String?      // AXIdentifier
    let position: CGRect?        // Approximate position
    let depth: Int?              // Search depth limit
    let timeout: TimeInterval    // Wait timeout
    let matchScore: Double       // Minimum match score (0.0-1.0)
}

func findElement(criteria: ElementMatchCriteria) async throws -> AXUIElement? {
    // 1. Try exact matches first
    // 2. Fall back to fuzzy matching with scoring
    // 3. Use caching for frequently queried elements
}
```

#### 2. Wait Strategy Improvements

```swift
// CURRENT: Fixed polling
while Date().timeIntervalSince(startTime) < timeout {
    // Check...
    Thread.sleep(forTimeInterval: 0.5)
}

// PROPOSED: Adaptive polling with exponential backoff
struct WaitStrategy {
    let initialDelay: TimeInterval = 0.1
    let maxDelay: TimeInterval = 1.0
    let multiplier: Double = 1.5
    let timeout: TimeInterval
    let conditions: [WaitCondition]
}

enum WaitCondition {
    case elementPresent(role: String, title: String?)
    case elementVisible(role: String, title: String?)
    case elementClickable(role: String, title: String?)
    case elementValue(role: String, value: String)
    case urlContains(String)
    case titleContains(String)
    case custom(() -> Bool)
}
```

#### 3. Caching Layer

```swift
actor AccessibilityCache {
    private var elementCache: [String: CachedElement] = [:]
    private let ttl: TimeInterval = 5.0
    
    struct CachedElement {
        let element: AXUIElement
        let timestamp: Date
        let position: CGRect
        let role: String
        let title: String?
    }
    
    func get(key: String) -> CachedElement? {
        guard let cached = elementCache[key],
              Date().timeIntervalSince(cached.timestamp) < ttl else {
            elementCache.removeValue(forKey: key)
            return nil
        }
        return cached
    }
}
```

### B. CGEvent Improvements

#### 1. Intelligent Typing

```swift
// CURRENT: Character-by-character CGEvent
for char in text {
    // Create key event for each character
}

// PROPOSED: Smart typing with form detection
func intelligentType(text: String, at point: CGPoint? = nil) async throws {
    // 1. Click to focus if point provided
    // 2. Check if target is a text field via AX
    // 3. Use AXValue set for text fields (faster, more reliable)
    // 4. Fall back to CGEvent for non-AX fields
    // 5. Verify input was received via AXValue check
}
```

#### 2. Coordinate System Helpers

```swift
// NEW: Coordinate transformation utilities
struct ScreenCoordinate {
    let x: CGFloat
    let y: CGFloat
    let screen: Int  // Multi-display support
    
    func toGlobal() -> CGPoint { ... }
    func toWindow(_ windowID: Int) -> CGPoint { ... }
    func toElement(_ element: AXUIElement) -> CGPoint { ... }
}

// Window-aware element finding
func findElementInWindow(windowID: Int, role: String, title: String?) -> AXUIElement? {
    // 1. Get window bounds from CGWindowListCopyWindowInfo
    // 2. Calculate window-relative coordinates
    // 3. Find element within window hierarchy
}
```

### C. System Events / AppleScript Improvements

#### 1. Unified Browser Automation

```swift
// NEW: Protocol-based browser abstraction
protocol BrowserAutomation {
    var bundleID: String { get }
    func open(url: URL) async throws
    func currentURL() async throws -> String
    func pageTitle() async throws -> String
    func executeJS(_ script: String) async throws -> Any?
    func findElement(selector: String) async throws -> BrowserElement
    func click(element: BrowserElement) async throws
    func type(text: String, into element: BrowserElement) async throws
    func takeScreenshot() async throws -> Data
}

// Implementations for each browser
class SafariAutomation: BrowserAutomation { ... }
class ChromeAutomation: BrowserAutomation { ... }
class FirefoxAutomation: BrowserAutomation { ... }
```

#### 2. JavaScript Execution Bridge

```swift
// NEW: Direct JS execution via AppleScript
func executeJavaScript(in app: String, script: String) async throws -> Any {
    let appleScript = """
    tell application "\(app)"
        tell front document
            do JavaScript "\(script.replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
    end tell
    """
    return try await NSAppleScriptService.shared.execute(source: appleScript)
}

// Safe JS value conversion
func convertJSResult(_ descriptor: NSAppleEventDescriptor) -> Any? {
    switch descriptor.descriptorType {
    case typeUnicodeText: return descriptor.stringValue
    case typeSInt32: return descriptor.int32Value
    case typeBoolean: return descriptor.booleanValue
    case typeAETEList: return parseJSArray(descriptor)
    case typeAERecord: return parseJSObject(descriptor)
    default: return descriptor.stringValue
    }
}
```

### D. AgentScript Improvements

#### 1. Pre-compiled Script Templates

```swift
// NEW: Web automation templates ready to use
let webTemplates = [
    "WebForm": """
    // Fill a web form with field-value pairs
    @_cdecl("script_main") public func scriptMain() -> Int32 {
        let args = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
        // Parse JSON: [{"field": "#email", "value": "user@example.com"}]
        // Use SafariBridge to fill form
        return 0
    }
    """,
    "WebNavigate": """
    // Navigate to URL and wait for load
    """,
    "WebScrape": """
    // Extract structured data from page
    """,
]
```

#### 2. Script Hot-Reload

```swift
// NEW: Watch for script changes and recompile
class ScriptWatcher {
    let fsmonitor = FileSystemWatcher()
    
    func watch(directory: URL, onChange: @escaping (String) -> Void) {
        fsmonitor.watch(directory) { event in
            guard event.path.hasSuffix(".swift") else { return }
            let name = URL(fileURLWithPath: event.path).deletingPathExtension().lastPathComponent
            onChange(name)
        }
    }
}
```

### E. Tool Call Improvements

#### 1. Context-Aware Tool Selection

The current system prompt lists all tools with equal priority. **Improved approach:**

```swift
// NEW: Context-aware tool hints injected at runtime
func toolHints(for context: TaskContext) -> String {
    switch context {
    case .webAutomation:
        return """
        PRIORITY FOR WEB AUTOMATION:
        1. apple_event_query - For Safari/Firefox ScriptingBridge (fast, direct)
        2. ax_find_element + ax_set_properties - For accessibility-based interaction
        3. ax_type_text + ax_click - For CGEvent-based input (universal)
        4. run_agent_script with Selenium - For full WebDriver protocol
        """
    case .formFilling:
        return """
        FOR FORM FILLING:
        1. ax_find_element to locate fields
        2. ax_set_properties with {"AXValue": "text"} for text fields
        3. ax_perform_action with "AXPress" for buttons
        4. ax_type_text as fallback for non-AX fields
        """
    default:
        return ""
    }
}
```

#### 2. Error Recovery Guidance

```swift
// NEW: Error-specific suggestions
func recoveryHint(for error: ToolError) -> String {
    switch error {
    case .elementNotFound:
        return """
        Element not found. Try:
        1. ax_screenshot to see current screen state
        2. ax_inspect_element at approximate coordinates
        3. ax_get_children to explore element hierarchy
        4. ax_wait_for_element with longer timeout
        """
    case .permissionDenied:
        return "Run ax_request_permission to prompt for Accessibility access"
    case .timeout:
        return "Element may be loading. Try ax_wait_for_element with pollInterval=0.2"
    default:
        return ""
    }
}
```

### F. New Unified Web Automation API

**PROPOSED: High-level web automation combining all approaches**

```swift
// NEW: Unified web automation entry point
actor WebAutomation {
    
    // MARK: - Navigation
    
    /// Open URL in specified browser (defaults to Safari)
    func open(url: URL, browser: BrowserType = .safari) async throws {
        switch browser {
        case .safari:
            try await openViaSafari(url: url)
        case .chrome, .firefox, .edge:
            try await openViaSelenium(url: url, browser: browser)
        }
    }
    
    /// Navigate within current session
    func navigate(to url: URL) async throws {
        // 1. Try via AppleScript (fastest)
        if let safari = try? await openViaSafari(url: url) { return }
        // 2. Fall back to Selenium
        try await seleniumNavigate(to: url)
    }
    
    // MARK: - Element Finding
    
    /// Find element using best available strategy
    func find(
        selector: String,
        strategy: SelectorStrategy = .auto,
        timeout: TimeInterval = 10.0
    ) async throws -> WebElement {
        switch strategy {
        case .auto:
            // 1. Try AX lookup (instant, works for Safari)
            if let element = try? await findViaAX(selector) { return element }
            // 2. Try AppleScript JS execution (works in Safari/Firefox)
            if let element = try? await findViaJS(selector) { return element }
            // 3. Fall back to Selenium
            return try await findViaSelenium(selector)
        case .accessibility:
            return try await findViaAX(selector)
        case .javascript:
            return try await findViaJS(selector)
        case .selenium:
            return try await findViaSelenium(selector)
        }
    }
    
    // MARK: - Interaction
    
    /// Click element with automatic strategy selection
    func click(_ element: WebElement) async throws {
        switch element.source {
        case .accessibility:
            try await ax_click(x: element.position.midX, y: element.position.midY)
        case .javascript:
            _ = try await executeJS("document.querySelector('\(element.selector)').click()")
        case .selenium:
            try await seleniumClient.click(element: element.seleniumElement)
        }
    }
    
    /// Type text with verification
    func type(text: String, into element: WebElement, verify: Bool = true) async throws {
        // 1. Try AXValue set first (fastest, most reliable for text fields)
        if element.source == .accessibility {
            try await ax_set_properties(
                role: element.role,
                title: element.title,
                properties: ["AXValue": text]
            )
            if verify {
                let actual = try await ax_get_properties(role: element.role, title: element.title)
                if actual["AXValue"] as? String != text {
                    throw WebAutomationError.verificationFailed
                }
            }
            return
        }
        
        // 2. Fall back to CGEvent typing
        try await ax_click(x: element.position.midX, y: element.position.midY)
        Thread.sleep(forTimeInterval: 0.1)
        try await ax_type_text(text: text)
    }
}

// MARK: - Supporting Types

enum BrowserType {
    case safari, chrome, firefox, edge
}

enum SelectorStrategy {
    case auto       // Try AX → JS → Selenium
    case accessibility
    case javascript
    case selenium
}

struct WebElement {
    let id: String
    let selector: String
    let role: String?
    let title: String?
    let value: String?
    let position: CGRect
    let source: ElementSource
    
    enum ElementSource {
        case accessibility
        case javascript
        case selenium
    }
}

enum WebAutomationError: Error {
    case elementNotFound(String)
    case verificationFailed
    case timeout(String)
    case permissionDenied
}
```

---

## Implementation Status

### ✅ Phase 1: Quick Wins (COMPLETED)

**New Tools Added:**

1. **`ax_click_element`** - Semantic element clicking
   - Finds element by role/title/value
   - Calculates center point automatically
   - Optional screenshot verification
   - File: `AccessibilityService.swift` - `clickElement()`

2. **`ax_wait_adaptive`** - Adaptive polling with exponential backoff
   - Starts with 0.1s interval, increases by 1.5x up to 1s max
   - More efficient for slow-loading content
   - File: `AccessibilityService.swift` - `waitForElementAdaptive()`

3. **`ax_type_into_element`** - Verified text input
   - Finds element by role/title
   - Tries AXValue set first (faster, more reliable)
   - Falls back to CGEvent typing if needed
   - Optional verification of entered text
   - File: `AccessibilityService.swift` - `typeTextIntoElement()`

4. **`captureVerificationScreenshot()`** - Post-action verification
   - Takes screenshot after action
   - Verifies element state
   - Returns verification status

**Implementation Files:**
- `/Users/toddbruss/Documents/GitHub/Agent/AgentXcode/Agent/Services/AccessibilityService.swift`
- `/Users/toddbruss/Documents/GitHub/Agent/AgentXcode/Agent/SystemPrompt+Tools/AgentTools.swift`
- `/Users/toddbruss/Documents/GitHub/Agent/AgentXcode/Agent/Views/AgentViewModel/AgentViewModel+TabTask.swift`
- `/Users/toddbruss/Documents/GitHub/Agent/AgentXcode/Agent/Views/AgentViewModel/AgentViewModel+TaskExecution.swift`

---

### ✅ Phase 2: Core Improvements (COMPLETED)

**New Service: `WebAutomationService.swift`**

Unified web automation service that auto-selects the best strategy:

```swift
final class WebAutomationService: @unchecked Sendable {
    static let shared = WebAutomationService()
    
    func open(url: URL, browser: BrowserType) async throws -> String
    func findElement(selector: String, strategy: SelectorStrategy) async throws -> [String: Any]
    func click(selector: String, strategy: SelectorStrategy) async throws -> String
    func type(text: String, selector: String, strategy: SelectorStrategy) async throws -> String
    func executeJavaScript(script: String, browser: String?) async throws -> Any?
}
```

**Features Implemented:**

1. **Unified `WebAutomation` API** - Auto-select strategy (AX → JS → Selenium)
   - Accessibility first (instant for Safari)
   - AppleScript JavaScript execution (Safari/Firefox)
   - Selenium WebDriver fallback (Chrome/Edge)
   - File: `WebAutomationService.swift`

2. **Multi-strategy element finder with fuzzy matching**
   - CSS selectors (`#id`, `.class`, `[attr=value]`)
   - XPath support (`//div[@class='foo']`)
   - Accessibility roles (`AXButton`, `AXTextField`)
   - Text content matching (`text:Submit`)
   - Fuzzy matching with Levenshtein distance scoring
   - File: `WebAutomationService.swift` - `fuzzyMatch()`, `parseSelector()`

3. **Element caching with 5-second TTL**
   - Cache reduces repeated element lookups
   - Automatic expiration after TTL
   - Thread-safe cache management
   - File: `WebAutomationService.swift` - `elementCache`, `cacheElement()`, `getCachedElement()`

**New Tools Added:**

- **`web_open`** - Open URL in specified browser (AppleScript for Safari/Firefox, NSWorkspace fallback)
- **`web_find`** - Find element with auto-strategy selection
- **`web_click`** - Click element with auto-strategy selection
- **`web_type`** - Type text with auto-strategy selection
- **`web_execute_js`** - Execute JavaScript in browser
- **`web_get_url`** - Get current page URL
- **`web_get_title`** - Get page title

**Selenium WebDriver Tools:**

- **`selenium_start`** - Start WebDriver session (Safari/Chrome/Firefox)
- **`selenium_stop`** - End WebDriver session
- **`selenium_navigate`** - Navigate to URL
- **`selenium_find`** - Find element by CSS/XPath
- **`selenium_click`** - Click element
- **`selenium_type`** - Type text into element
- **`selenium_execute`** - Execute JavaScript
- **`selenium_screenshot`** - Take screenshot
- **`selenium_wait`** - Wait for element

**Implementation Files:**
- `/Users/toddbruss/Documents/GitHub/Agent/AgentXcode/Agent/Services/WebAutomationService.swift` (NEW)
- `/Users/toddbruss/Documents/GitHub/Agent/AgentXcode/Agent/SystemPrompt+Tools/AgentTools.swift` (tools added)
- `/Users/toddbruss/Documents/GitHub/Agent/AgentXcode/Agent/Views/AgentViewModel/AgentViewModel+TabTask.swift` (handlers added)
- `/Users/toddbruss/Documents/GitHub/Agent/AgentXcode/Agent/Views/AgentViewModel/AgentViewModel+TaskExecution.swift` (handlers added)

---

## Implementation Priority

### Phase 1: Quick Wins (1-2 days) ✅ COMPLETED

1. **Add `ax_click_element` tool** - Click by role/title directly without coordinates
2. **Add adaptive wait polling** - Exponential backoff in `ax_wait_for_element`
3. **Add screenshot verification** - Capture after actions for debugging

### Phase 2: Core Improvements (3-5 days) ✅ COMPLETED

1. **Implement `WebAutomation` unified API** - Auto-select strategy (AX → JS → Selenium)
2. **Add multi-strategy element finder** - Fuzzy matching, scoring, caching
3. **Add element caching with TTL** - Cache elements for 5 seconds, reduce lookups

### Phase 3: Advanced Features (1-2 weeks) ✅ COMPLETED

1. **JavaScript execution bridge for Safari/Firefox** ✅
   - `WebAutomationService.executeJavaScript()` - Direct JS execution in Safari/Firefox
   - AppleScript bridge for Safari `do JavaScript` command
   - Firefox JavaScript execution support
   - File: `WebAutomationService.swift` lines 200-239

2. **Script templates for common patterns** ✅
   - **WebForm** - Fill web forms automatically using Safari ScriptingBridge
     - Text fields, checkboxes, radio buttons, select dropdowns
     - Field verification and retry logic
     - Form submission with success wait
   - **WebNavigate** - Navigate to URLs and wait for page states
     - Element/text/title/URL wait conditions
     - Scroll, click, hover, focus actions
     - Screenshot capture support
   - **WebScrape** - Extract structured data from web pages
     - CSS selector-based extraction
     - Multiple element support
     - Nested data structures
     - Pagination handling
     - Scroll-to-load for infinite scroll pages
   - Files: `~/Documents/AgentScript/agents/WebForm.swift`, `WebNavigate.swift`, `WebScrape.swift`

3. **Hot-reload for AgentScripts** - Watch for changes and recompile
   - Not yet implemented - would require FileSystemWatcher integration

---

## Code Quality Observations

### Good Patterns
- Timeout wrappers for AX operations (`copyWithTimeout`)
- Thread-safe audit logging with `NSLock`
- Permission caching to avoid repeated dialogs
- Blocklist for deleted scripts

### Areas for Improvement
1. **Error messages could be more specific** - Include element path in failures
2. **No retry logic for transient failures** - Add automatic retry with backoff
3. **Coordinate-dependent operations** - Should prefer semantic element access
4. **No state verification after actions** - Add automatic verification

---

## Testing Recommendations

1. **Unit Tests for Element Finding**
   ```swift
   func testFindElementByPartialTitle() { ... }
   func testFindElementByValue() { ... }
   func testFindElementWithTimeout() { ... }
   ```

2. **Integration Tests for Web Flows**
   ```swift
   func testFormFilling() async throws {
       let automation = WebAutomation()
       try await automation.open(url: URL(string: "https://example.com/form")!)
       let emailField = try await automation.find(selector: "#email")
       try await automation.type(text: "test@example.com", into: emailField)
   }
   ```

3. **Stress Tests for Timing**
   ```swift
   func testSlowLoadingPage() async throws {
       // Test with artificially delayed page
       // Verify wait strategies work correctly
   }
   ```

---

## Conclusion

The Agent codebase has a solid foundation with multiple complementary approaches to web automation. The key improvements are:

1. **Unified high-level API** that automatically selects the best strategy
2. **Smarter element finding** with fuzzy matching and caching
3. **Better wait strategies** with adaptive polling
4. **Context-aware tool hints** to guide the LLM toward the right approach
5. **Verification after actions** to ensure operations succeeded

These improvements would significantly increase reliability for web automation tasks while maintaining backward compatibility with existing tools.