# AgentAccess

macOS Accessibility automation framework. Control any app via the Accessibility API — inspect elements, click buttons, type text, manage windows, capture screenshots, and more.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/macOS26/AgentAccess.git", from: "1.0.0"),
]
```

## Quick Start

```swift
import AgentAccess

let ax = AccessibilityService.shared

// Check permission first
guard AccessibilityService.hasAccessibilityPermission() else {
    AccessibilityService.requestAccessibilityPermission()
    return
}
```

## Features

### Inspect Elements

```swift
// Inspect element at screen coordinates
let info = ax.inspectElementAt(x: 500, y: 300, depth: 3)

// Find element by role and title
let result = ax.findElement(role: "AXButton", title: "OK", value: nil, appBundleId: nil, timeout: 5)

// Get focused element
let focused = ax.getFocusedElement(appBundleId: "com.apple.Safari")

// Get children of an element
let children = ax.getChildren(role: "AXGroup", title: nil, value: nil, appBundleId: nil, depth: 2)

// Get element properties
let props = ax.getElementProperties(role: "AXTextField", title: "Search", value: nil, appBundleId: nil)
```

### Click, Type, Scroll

```swift
// Click at coordinates
ax.clickAt(x: 100, y: 200, button: "left", clicks: 1)

// Click an element by description
ax.clickElement(role: "AXButton", title: "Submit", value: nil, appBundleId: nil, timeout: 5, verify: true)

// Type text at coordinates
ax.typeText("Hello world", at: 100, y: 200)

// Type into a specific element
ax.typeTextIntoElement(role: "AXTextField", title: "Email", text: "user@example.com", appBundleId: nil, verify: true)

// Scroll
ax.scrollAt(x: 500, y: 400, deltaX: 0, deltaY: -5)

// Key press
ax.pressKey(virtualKey: 36, modifiers: []) // Return key

// Drag
ax.drag(fromX: 100, fromY: 200, toX: 300, toY: 400, button: "left")
```

### Wait for Elements

```swift
// Wait with fixed polling
let found = ax.waitForElement(role: "AXButton", title: "Done", value: nil, appBundleId: nil, timeout: 10, pollInterval: 0.5)

// Wait with adaptive polling (starts fast, slows down)
let found = ax.waitForElementAdaptive(role: "AXSheet", title: nil, value: nil, appBundleId: nil, timeout: 10, initialDelay: 0.1, maxDelay: 1.0)
```

### Window Management

```swift
// List all visible windows
let windows = ax.listWindows(limit: 50)

// Get window frame
let frame = ax.getWindowFrame(windowId: 12345)

// Resize and move a window
ax.setWindowFrame(appBundleId: "com.apple.Safari", x: 0, y: 0, width: 1200, height: 800)

// Highlight an element (visual overlay)
ax.highlightElement(role: "AXButton", title: "OK", value: nil, appBundleId: nil, x: nil, y: nil, duration: 2.0, color: "green")
```

### Menu Bar

```swift
// Click a menu item by path
ax.clickMenuItem(appBundleId: "com.apple.Safari", menuPath: ["File", "New Window"])

// Show a menu
ax.showMenu(role: nil, title: "File", value: nil, appBundleId: "com.apple.Safari")
```

### App Management

```swift
// Launch, activate, quit, list apps
ax.manageApp(action: "launch", bundleId: "com.apple.Safari", name: nil)
ax.manageApp(action: "activate", bundleId: "com.apple.Safari", name: nil)
ax.manageApp(action: "quit", bundleId: "com.apple.Safari", name: nil)
ax.manageApp(action: "list", bundleId: nil, name: nil)
```

### Screenshots

```swift
// Capture a screen region
ax.captureScreenshot(x: 0, y: 0, width: 800, height: 600)

// Capture a specific window
ax.captureScreenshot(windowID: 12345)

// Capture all visible windows
ax.captureAllWindows()
```

### Element Properties

```swift
// Set properties on an element
ax.setProperties(role: "AXSlider", title: nil, value: nil, appBundleId: nil, properties: ["AXValue": 0.75])

// Read focused element content
ax.readFocusedElement(appBundleId: "com.apple.TextEdit")

// Scroll to an element
ax.scrollToElement(role: "AXButton", title: "Save", appBundleId: nil)
```

## Permission Gating

Users can disable specific AX actions for safety:

```swift
let perms = AccessibilityPermissions.shared

// Check if restricted
perms.isRestricted("AXPress")     // false (enabled by default)

// Disable an action
perms.toggle("AXDelete")          // now restricted

// Re-enable all
perms.enableAll()
```

## AX Actions (30)

| Group | Actions |
|---|---|
| Core | AXPress, AXConfirm, AXActivate, AXCancel, AXShowMenu, AXDismiss |
| Values | AXIncrement, AXDecrement |
| Disclosure | AXExpand, AXCollapse, AXOpen |
| Window | AXRaise, AXZoom, AXMinimize |
| Text | AXCopy, AXCut, AXPaste, AXSelect, AXSelectAll |
| Scroll | AXScrollToVisible, AXScrollPageUp/Down/Left/Right |
| Focus | AXFocus |
| UI | AXShowDefaultUI, AXShowAlternateUI |
| Content | AXDelete, AXPick |

## AX Roles Reference

### Web Content (browser automation)

| Role | Element |
|---|---|
| AXWebArea | Root of web page content |
| AXLink | Clickable hyperlink |
| AXImage | Image |
| AXTable, AXRow, AXColumn, AXCell | Table structure |
| AXHeading | h1-h6 headings |
| AXList, AXListItem | Lists |
| AXBlockQuote | Blockquote |
| AXForm | Form element |

### App UI

| Role | Element |
|---|---|
| AXApplication | App root |
| AXWindow, AXSheet, AXDialog, AXPopover | Windows |
| AXToolbar, AXTabGroup, AXSplitGroup | Layout |
| AXScrollArea, AXGroup, AXOutline | Containers |
| AXMenuBar, AXMenu, AXMenuItem | Menus |
| AXButton, AXCheckBox, AXRadioButton | Controls |
| AXTextField, AXTextArea, AXStaticText | Text |
| AXSlider, AXStepper, AXProgressIndicator | Values |
| AXPopUpButton, AXComboBox | Dropdowns |
| AXColorWell, AXDateField | Pickers |
| AXDisclosureTriangle | Disclosure |

## Audit Logging

All operations are logged via [AgentAudit](https://github.com/macOS26/AgentAudit) to `os.log`. View in Console.app under subsystem `Agent.app.toddbruss.audit`, category `Accessibility`.

## Requirements

- macOS 26+
- Swift 6.2+
- Accessibility permission (System Settings > Privacy & Security > Accessibility)
