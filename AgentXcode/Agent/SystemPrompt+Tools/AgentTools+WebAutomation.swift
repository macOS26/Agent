import Foundation

// MARK: - Web Automation Tool Definitions

extension AgentTools {
    
    /// Web browser automation tools
    nonisolated(unsafe) static let webTools: [ToolDef] = [
        ToolDef(
            name: Name.webOpen,
            description: "Open a URL in the specified browser. Uses AppleScript for Safari/Firefox, falls back to NSWorkspace for others. Fastest way to open URLs in web automation.",
            properties: [
                "url": ["type": "string", "description": "URL to open"],
                "browser": ["type": "string", "description": "Browser type: 'safari' (default), 'chrome', 'firefox', 'edge'"],
            ],
            required: ["url"]
        ),
        ToolDef(
            name: Name.webFind,
            description: "Find an element on a web page using the best available strategy. Auto-selects: Accessibility (Safari AX) → JavaScript (Safari/Firefox) → Selenium. Supports CSS selectors, XPath, and accessibility attributes. Returns element properties with source strategy.",
            properties: [
                "selector": ["type": "string", "description": "Element selector: CSS (#id, .class), XPath (//div), or accessibility (AXButton, [title='Submit'])"],
                "strategy": ["type": "string", "description": "Strategy: 'auto' (default), 'accessibility', 'javascript', 'selenium'"],
                "timeout": ["type": "number", "description": "Maximum wait time in seconds (default 10.0)"],
                "fuzzyThreshold": ["type": "number", "description": "Minimum match score 0-1 for fuzzy matching (default 0.6)"],
                "appBundleId": ["type": "string", "description": "Optional browser bundle ID (auto-detected if not specified)"],
            ],
            required: ["selector"]
        ),
        ToolDef(
            name: Name.webClick,
            description: "Click a web element by selector. Auto-selects best strategy: AX click, JavaScript click, or Selenium click. Use after web_find to verify element exists.",
            properties: [
                "selector": ["type": "string", "description": "Element selector to click"],
                "strategy": ["type": "string", "description": "Strategy: 'auto' (default), 'accessibility', 'javascript', 'selenium'"],
                "appBundleId": ["type": "string", "description": "Optional browser bundle ID"],
            ],
            required: ["selector"]
        ),
        ToolDef(
            name: Name.webType,
            description: "Type text into a web element by selector. Auto-selects best strategy: AXValue set (fastest), JavaScript value set, or Selenium sendKeys. Verifies text was entered.",
            properties: [
                "selector": ["type": "string", "description": "Element selector for input field"],
                "text": ["type": "string", "description": "Text to type"],
                "strategy": ["type": "string", "description": "Strategy: 'auto' (default), 'accessibility', 'javascript', 'selenium'"],
                "verify": ["type": "boolean", "description": "Verify text was entered (default true)"],
                "appBundleId": ["type": "string", "description": "Optional browser bundle ID"],
            ],
            required: ["selector", "text"]
        ),
        ToolDef(
            name: Name.webExecuteJs,
            description: "Execute JavaScript in the active browser. Works in Safari and Firefox via AppleScript, Chrome via Selenium. Returns the result of the script execution.",
            properties: [
                "script": ["type": "string", "description": "JavaScript code to execute"],
                "browser": ["type": "string", "description": "Browser bundle ID (auto-detected if not specified)"],
            ],
            required: ["script"]
        ),
        ToolDef(
            name: Name.webGetUrl,
            description: "Get the current URL from the active browser. Works via AppleScript for Safari/Firefox/Chrome or via Selenium session.",
            properties: [
                "browser": ["type": "string", "description": "Optional browser bundle ID"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.webGetTitle,
            description: "Get the page title from the active browser.",
            properties: [
                "browser": ["type": "string", "description": "Optional browser bundle ID"],
            ],
            required: []
        ),
    ]
    
    /// Selenium WebDriver tools
    nonisolated(unsafe) static let seleniumTools: [ToolDef] = [
        ToolDef(
            name: Name.seleniumStart,
            description: "Start a Selenium WebDriver session. SafariDriver is built into macOS. For Chrome/Firefox, install chromedriver/geckodriver. Returns session ID for subsequent calls.",
            properties: [
                "browser": ["type": "string", "description": "Browser: 'safari' (default), 'chrome', 'firefox'"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
                "capabilities": ["type": "object", "description": "Optional WebDriver capabilities"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.seleniumStop,
            description: "End the Selenium WebDriver session.",
            properties: [
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.seleniumNavigate,
            description: "Navigate to a URL via Selenium WebDriver. More reliable than AppleScript for complex pages.",
            properties: [
                "url": ["type": "string", "description": "URL to navigate to"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: ["url"]
        ),
        ToolDef(
            name: Name.seleniumFind,
            description: "Find element via Selenium WebDriver with CSS or XPath selector. Returns element ID for subsequent operations.",
            properties: [
                "strategy": ["type": "string", "description": "Locator strategy: 'css', 'xpath', 'id', 'name', 'linktext', 'tagname', 'classname'"],
                "value": ["type": "string", "description": "Selector value"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: ["strategy", "value"]
        ),
        ToolDef(
            name: Name.seleniumClick,
            description: "Click an element via Selenium WebDriver. More reliable for dynamically loaded content.",
            properties: [
                "strategy": ["type": "string", "description": "Locator strategy: 'css', 'xpath', 'id', 'name'"],
                "value": ["type": "string", "description": "Selector value"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: ["strategy", "value"]
        ),
        ToolDef(
            name: Name.seleniumType,
            description: "Type text into an element via Selenium WebDriver. Simulates actual keyboard input.",
            properties: [
                "strategy": ["type": "string", "description": "Locator strategy: 'css', 'xpath', 'id', 'name'"],
                "value": ["type": "string", "description": "Selector value"],
                "text": ["type": "string", "description": "Text to type"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: ["strategy", "value", "text"]
        ),
        ToolDef(
            name: Name.seleniumExecute,
            description: "Execute JavaScript in the Selenium session. Useful for scrolling, DOM manipulation, or extracting data.",
            properties: [
                "script": ["type": "string", "description": "JavaScript code to execute"],
                "args": ["type": "array", "description": "Optional arguments for the script"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: ["script"]
        ),
        ToolDef(
            name: Name.seleniumScreenshot,
            description: "Take a screenshot via Selenium WebDriver. Saves to ~/Documents/Agent/screenshots/.",
            properties: [
                "filename": ["type": "string", "description": "Screenshot filename (default: auto-generated)"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.seleniumWait,
            description: "Wait for an element to appear via Selenium WebDriver. Uses explicit wait with timeout.",
            properties: [
                "strategy": ["type": "string", "description": "Locator strategy: 'css', 'xpath', 'id', 'name'"],
                "value": ["type": "string", "description": "Selector value"],
                "timeout": ["type": "number", "description": "Maximum wait time in seconds (default 10.0)"],
                "port": ["type": "integer", "description": "WebDriver port (default 7055)"],
            ],
            required: ["strategy", "value"]
        ),
    ]
    
    /// Web search tool (Ollama/Tavily)
    nonisolated(unsafe) static let webSearchTools: [ToolDef] = [
        ToolDef(
            name: Name.webSearch,
            description: "Search the web for current information. Returns relevant web page titles, URLs, and content snippets. Use when you need up-to-date information or facts you're unsure about.",
            properties: [
                "query": ["type": "string", "description": "The search query"],
            ],
            required: ["query"]
        ),
    ]
}