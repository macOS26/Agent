# AgentAccess

macOS Accessibility automation framework. Control any app via the Accessibility API — inspect elements, click buttons, type text, manage windows, capture screenshots, and more.

## Features

- **Element inspection** — inspect at coordinates, find by role/title/value, get properties
- **Actions** — click, type, scroll, key press, drag
- **Element interaction** — click element by description, type into element, wait for element
- **Window management** — list, resize, move, highlight, get frame
- **Menu bar** — click menu items by path
- **App management** — launch, activate, quit, list running apps
- **Screenshots** — capture screen region, window, or all windows
- **Permission checking** — verify and request Accessibility permission
- **Action gating** — enable/disable specific AX actions per user preference
- **Audit logging** — all operations logged via AgentAudit (os.log)

## Usage

```swift
import AgentAccess

let ax = AccessibilityService.shared

// Check permission
if AccessibilityService.hasAccessibilityPermission() {
    // List windows
    let windows = ax.listWindows()
    
    // Click at coordinates
    ax.clickAt(x: 100, y: 200)
    
    // Find and click an element
    ax.clickElement(role: "AXButton", title: "OK")
    
    // Type text into a field
    ax.typeTextIntoElement(role: "AXTextField", title: nil, text: "Hello")
    
    // Capture screenshot
    ax.captureScreenshot(windowID: 123)
    
    // Manage windows
    ax.setWindowFrame(appBundleId: "com.apple.Safari", x: 0, y: 0, width: 1200, height: 800)
    
    // Click menu items
    ax.clickMenuItem(appBundleId: "com.apple.Safari", menuPath: ["File", "New Window"])
}
```

## Permission Gating

Users can disable specific AX actions:

```swift
// Check if an action is restricted
AccessibilityPermissions.shared.isRestricted("AXPress")  // false by default

// Toggle an action off
AccessibilityPermissions.shared.toggle("AXPress")
```

## Requirements

- macOS 26+
- Swift 6.2+
- Accessibility permission (System Settings > Privacy & Security > Accessibility)
