import Foundation

// MARK: - Accessibility Tool Definitions

extension AgentTools {
    
    /// Accessibility tools for UI automation
    nonisolated(unsafe) static let accessibilityTools: [ToolDef] = [
        // === Window & Element Discovery ===
        ToolDef(
            name: Name.axListWindows,
            description: "List all visible windows from all applications with their positions and sizes. Returns JSON array with window ID, owner PID, owner name, window name, and bounds.",
            properties: [
                "limit": ["type": "integer", "description": "Maximum number of windows to return (default 50)"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.axInspectElement,
            description: "Inspect accessibility element at a screen coordinate. Returns the accessibility hierarchy for the element at position (x, y).",
            properties: [
                "x": ["type": "number", "description": "Screen X coordinate"],
                "y": ["type": "number", "description": "Screen Y coordinate"],
                "depth": ["type": "integer", "description": "How deep to traverse the hierarchy (default 3)"],
            ],
            required: ["x", "y"]
        ),
        ToolDef(
            name: Name.axGetProperties,
            description: "Get all properties of an accessibility element. Can find by role/title/value or by screen position. CRITICAL: If you just used ax_wait_for_element or ax_find_element, pass the SAME role/title/value parameters to this function.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXButton', 'AXTextField')"],
                "title": ["type": "string", "description": "Title or name to match (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match) - useful for text fields with specific content"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "x": ["type": "number", "description": "Screen X coordinate for position-based lookup"],
                "y": ["type": "number", "description": "Screen Y coordinate for position-based lookup"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.axPerformAction,
            description: "Perform an accessibility action on an element. SECURITY: Protected roles (AXSecureTextField, AXPasswordField) can be disabled in Accessibility Settings. CRITICAL: If you just used ax_wait_for_element or ax_find_element, pass the SAME role/title/value parameters to this function - the element locator must match exactly.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXButton', 'AXTextField')"],
                "title": ["type": "string", "description": "Title to match (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match) - useful for text fields with specific content"],
                "appBundleId": ["type": "string", "description": "Bundle ID of the target app"],
                "x": ["type": "number", "description": "Screen X coordinate for position-based lookup"],
                "y": ["type": "number", "description": "Screen Y coordinate for position-based lookup"],
                "action": ["type": "string", "description": "Accessibility action to perform (e.g., 'AXPress', 'AXConfirm')"],
            ],
            required: ["action"]
        ),
        
        // === Permission Checks ===
        ToolDef(
            name: Name.axCheckPermission,
            description: "Check if Accessibility permission is granted to Agent.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: Name.axRequestPermission,
            description: "Request Accessibility permission. Shows the macOS system prompt for the user to approve.",
            properties: [:],
            required: []
        ),
        
        // === Input Simulation ===
        ToolDef(
            name: Name.axTypeText,
            description: "Simulate typing text at the current cursor position or at specific coordinates. Uses CGEvent keyboard simulation.",
            properties: [
                "text": ["type": "string", "description": "Text to type"],
                "x": ["type": "number", "description": "Optional X coordinate to click first before typing"],
                "y": ["type": "number", "description": "Optional Y coordinate to click first before typing"],
            ],
            required: ["text"]
        ),
        ToolDef(
            name: Name.axClick,
            description: "Simulate a mouse click at screen coordinates.",
            properties: [
                "x": ["type": "number", "description": "Screen X coordinate (required)"],
                "y": ["type": "number", "description": "Screen Y coordinate (required)"],
                "button": ["type": "string", "description": "Mouse button: 'left' (default), 'right', or 'middle'"],
                "clicks": ["type": "integer", "description": "Number of clicks: 1 (default) or 2 for double-click"],
            ],
            required: ["x", "y"]
        ),
        ToolDef(
            name: Name.axScroll,
            description: "Simulate scroll wheel at screen coordinates.",
            properties: [
                "x": ["type": "number", "description": "Screen X coordinate"],
                "y": ["type": "number", "description": "Screen Y coordinate"],
                "deltaX": ["type": "integer", "description": "Horizontal scroll amount (positive = right, negative = left)"],
                "deltaY": ["type": "integer", "description": "Vertical scroll amount (positive = down, negative = up)"],
            ],
            required: ["x", "y"]
        ),
        ToolDef(
            name: Name.axPressKey,
            description: "Simulate pressing a key with optional modifiers (Cmd, Option, Control, Shift).",
            properties: [
                "keyCode": ["type": "integer", "description": "macOS virtual key code (e.g., 36=Return, 48=Tab, 51=Delete, 53=Escape, 123-126=Arrow keys)"],
                "modifiers": ["type": "array", "description": "Array of modifier keys: 'command', 'option', 'control', 'shift'", "items": ["type": "string"]],
            ],
            required: ["keyCode"]
        ),
        
        // === Screenshots ===
        ToolDef(
            name: Name.axScreenshot,
            description: "Capture a screenshot of a screen region or specific window. Requires Screen Recording permission. Returns the path to the saved PNG file.",
            properties: [
                "x": ["type": "number", "description": "X coordinate of region (optional, required for region capture)"],
                "y": ["type": "number", "description": "Y coordinate of region (optional, required for region capture)"],
                "width": ["type": "number", "description": "Width of region (optional, required for region capture)"],
                "height": ["type": "number", "description": "Height of region (optional, required for region capture)"],
                "windowId": ["type": "integer", "description": "Window ID to capture (optional, from ax_list_windows)"],
            ],
            required: []
        ),
        
        // === Audit Log ===
        ToolDef(
            name: Name.axGetAuditLog,
            description: "Get recent accessibility audit log entries. Shows recent accessibility operations performed by the agent.",
            properties: [
                "limit": ["type": "integer", "description": "Maximum number of entries to return (default 50)"],
            ],
            required: []
        ),
        
        // === Set Properties ===
        ToolDef(
            name: Name.axSetProperties,
            description: "Set accessibility property values on an element. CRITICAL for setting text fields, selections, slider values, etc. Can find element by role/title/value, by position, or within a specific app. CRITICAL: If you just used ax_wait_for_element or ax_find_element, pass the SAME role/title/value parameters to this function.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXTextField', 'AXSlider')"],
                "title": ["type": "string", "description": "Title or name to match (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match) - useful for text fields with specific content"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "x": ["type": "number", "description": "Screen X coordinate for position-based lookup"],
                "y": ["type": "number", "description": "Screen Y coordinate for position-based lookup"],
                "properties": ["type": "object", "description": "Properties to set as key-value pairs. Common: 'AXValue' for text, 'AXSelected' for selection, 'AXValue' (with position dict) for sliders"],
            ],
            required: ["properties"]
        ),
        
        // === Find Element ===
        ToolDef(
            name: Name.axFindElement,
            description: "Find an accessibility element by role, title, or value with optional timeout. Returns element properties when found. Useful for waiting for UI elements to appear.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXButton', 'AXTextField')"],
                "title": ["type": "string", "description": "Title or name to match (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match in element's AXValue)"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "timeout": ["type": "number", "description": "Maximum seconds to wait for element (default 5.0)"],
            ],
            required: []
        ),
        
        // === Get Focused Element ===
        ToolDef(
            name: Name.axGetFocusedElement,
            description: "Get the currently focused accessibility element. Can optionally filter by app. Returns element properties.",
            properties: [
                "appBundleId": ["type": "string", "description": "Optional bundle ID to get focused element within a specific app"],
            ],
            required: []
        ),
        
        // === Get Children ===
        ToolDef(
            name: Name.axGetChildren,
            description: "Get all children of an accessibility element. Useful for exploring UI hierarchy. CRITICAL: If you just used ax_wait_for_element or ax_find_element, pass the SAME role/title/value parameters to this function.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find parent element"],
                "title": ["type": "string", "description": "Title to match for parent element (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match) - useful for text fields with specific content"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "x": ["type": "number", "description": "Screen X coordinate for position-based parent lookup"],
                "y": ["type": "number", "description": "Screen Y coordinate for position-based parent lookup"],
                "depth": ["type": "integer", "description": "How deep to traverse children (default 3)"],
            ],
            required: []
        ),
        
        // === Drag ===
        ToolDef(
            name: Name.axDrag,
            description: "Perform a drag operation from one point to another. Simulates mouse down, drag, and mouse up.",
            properties: [
                "fromX": ["type": "number", "description": "Starting X coordinate"],
                "fromY": ["type": "number", "description": "Starting Y coordinate"],
                "toX": ["type": "number", "description": "Ending X coordinate"],
                "toY": ["type": "number", "description": "Ending Y coordinate"],
                "button": ["type": "string", "description": "Mouse button: 'left' (default), 'right', or 'middle'"],
            ],
            required: ["fromX", "fromY", "toX", "toY"]
        ),
        
        // === Wait For Element ===
        ToolDef(
            name: Name.axWaitForElement,
            description: "Wait for an accessibility element to appear, polling periodically until found or timeout. Returns element properties when found. CRITICAL: When calling ax_perform_action or ax_set_properties after this, use the SAME role/title/value parameters to locate the element.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXButton', 'AXTextField')"],
                "title": ["type": "string", "description": "Title or name to match (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match) - useful for text fields"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "timeout": ["type": "number", "description": "Maximum seconds to wait (default 10.0)"],
                "pollInterval": ["type": "number", "description": "Seconds between polls (default 0.5)"],
            ],
            required: []
        ),
        
        // === Show Menu ===
        ToolDef(
            name: Name.axShowMenu,
            description: "Show context menu for an element. Uses AXShowMenu action if available, otherwise simulates right-click at element center. Protected roles can be disabled in Accessibility Settings. CRITICAL: If you just used ax_wait_for_element or ax_find_element, pass the SAME role/title/value parameters to this function.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find element"],
                "title": ["type": "string", "description": "Title to match for element (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match) - useful for text fields with specific content"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "x": ["type": "number", "description": "Screen X coordinate for position-based lookup"],
                "y": ["type": "number", "description": "Screen Y coordinate for position-based lookup"],
            ],
            required: []
        ),
        
        // === Smart Element Click ===
        ToolDef(
            name: Name.axClickElement,
            description: "Click an element by finding it semantically (role/title) and clicking its center. More reliable than coordinate-based clicking for web automation. Finds element, gets its position/size, calculates center, and clicks.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXButton', 'AXTextField')"],
                "title": ["type": "string", "description": "Title or name to match (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match)"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "timeout": ["type": "number", "description": "Maximum seconds to wait for element (default 5.0)"],
                "verify": ["type": "boolean", "description": "Whether to capture screenshot for verification (default false)"],
            ],
            required: []
        ),
        
        // === Adaptive Wait ===
        ToolDef(
            name: Name.axWaitAdaptive,
            description: "Wait for an element with exponential backoff polling. More efficient than fixed-interval polling for slow-loading content. Starts with short interval and increases up to max.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXButton', 'AXTextField')"],
                "title": ["type": "string", "description": "Title or name to match (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match)"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "timeout": ["type": "number", "description": "Maximum seconds to wait (default 10.0)"],
                "initialDelay": ["type": "number", "description": "Initial polling delay in seconds (default 0.1)"],
                "maxDelay": ["type": "number", "description": "Maximum polling delay in seconds (default 1.0)"],
            ],
            required: []
        ),
        
        // === Type Into Element ===
        ToolDef(
            name: Name.axTypeIntoElement,
            description: "Type text into an element found by role/title. First tries AXValue set (fastest), falls back to CGEvent typing. Can verify the text was entered. Best for web form filling.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role of target element (e.g., 'AXTextField', 'AXTextArea')"],
                "title": ["type": "string", "description": "Title to match (partial match)"],
                "text": ["type": "string", "description": "Text to type into the element"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "verify": ["type": "boolean", "description": "Whether to verify the text was entered (default true)"],
            ],
            required: ["text"]
        ),
        
        // === Highlight Element ===
        ToolDef(
            name: Name.axHighlightElement,
            description: "Temporarily highlight an element on screen with a colored overlay. Useful for verification before performing actions. The highlight appears for a configurable duration then disappears automatically.",
            properties: [
                "role": ["type": "string", "description": "Accessibility role to find (e.g., 'AXButton', 'AXTextField')"],
                "title": ["type": "string", "description": "Title or name to match (partial match)"],
                "value": ["type": "string", "description": "Value to match (partial match) - useful for text fields with specific content"],
                "appBundleId": ["type": "string", "description": "Optional bundle ID to search within a specific app"],
                "x": ["type": "number", "description": "Screen X coordinate for position-based lookup"],
                "y": ["type": "number", "description": "Screen Y coordinate for position-based lookup"],
                "duration": ["type": "number", "description": "How long to show the highlight in seconds (default 2.0)"],
                "color": ["type": "string", "description": "Highlight color: 'red', 'green', 'blue', 'yellow', 'purple' (default 'green')"],
            ],
            required: []
        ),
        
        // === Get Window Frame ===
        ToolDef(
            name: Name.axGetWindowFrame,
            description: "Get the exact position and frame (x, y, width, height) of a window by its ID. Use ax_list_windows first to get window IDs. Returns precise coordinates for positioning screenshots or clicks.",
            properties: [
                "windowId": ["type": "integer", "description": "Window ID from ax_list_windows"],
            ],
            required: ["windowId"]
        ),
    ]
}