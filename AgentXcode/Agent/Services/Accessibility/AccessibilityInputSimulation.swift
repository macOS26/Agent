import Foundation
import AppKit
@preconcurrency import ApplicationServices

/// Input simulation (click, type, scroll, keypress) for Accessibility API.
/// Provides tools for simulating user input via CGEvent.
enum AccessibilityInputSimulation {
    
    // MARK: - Perform Actions
    
    /// Perform an accessibility action on an element
    static func performAction(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, action: String) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("performAction(\(action)) role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil")")

        // Check settings - if disabled, block
        if AccessibilityPermissions.isRestricted(action) {
            return AccessibilityServiceHelpers.errorJSON("Action '\(action)' is disabled in Accessibility Settings. Enable it in Settings to allow this action.")
        }
        
        var element: AXUIElement?
        
        if let x = x, let y = y {
            let systemWide = AXUIElementCreateSystemWide()
            // Use timeout wrapper to prevent hangs on complex text views
            let copyResult = AccessibilityElementFinder.copyWithTimeout(systemWide: systemWide, x: x, y: y, timeout: AccessibilityWindows.elementAtPositionTimeout)
            if copyResult.timedOut {
                return AccessibilityServiceHelpers.errorJSON("Element lookup timed out at (\(x), \(y)) - text view may be complex")
            }
            element = copyResult.element
        } else if let bundleId = appBundleId {
            let apps = NSWorkspace.shared.runningApplications
            if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
               let pid = app.processIdentifier as pid_t? {
                element = AccessibilityElementFinder.findElementInApp(pid: pid, role: role, title: title, value: value)
            }
        } else {
            element = AccessibilityElementFinder.findElementGlobally(role: role, title: title, value: value)
        }
        
        guard let found = element else {
            return AccessibilityServiceHelpers.errorJSON("Element not found")
        }
        
        // Check for restricted roles
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXRoleAttribute as CFString, &roleRef) == .success,
           let elRole = roleRef as? String, AccessibilityPermissions.isRestricted(elRole) {
            return AccessibilityServiceHelpers.errorJSON("Cannot interact with \(elRole) — disabled in Accessibility Access")
        }
        
        // Perform the action
        let result = AXUIElementPerformAction(found, action as CFString)
        
        if result == .success {
            return AccessibilityServiceHelpers.successJSON([
                "action": action,
                "message": "Action '\(action)' performed successfully"
            ])
        } else {
            return AccessibilityServiceHelpers.errorJSON("Action '\(action)' failed with error: \(result.rawValue)")
        }
    }
    
    // MARK: - Type Text
    
    /// Simulate typing text at the current cursor position or specific coordinates
    static func typeText(_ text: String, at x: CGFloat? = nil, y: CGFloat? = nil) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("typeText(\(text.count) chars) at (\(x.map(String.init) ?? "nil"), \(y.map(String.init) ?? "nil"))")
        
        // Click at position if provided
        if let x = x, let y = y {
            AccessibilityInputSimulation.clickAt(x: x, y: y, button: "left", clicks: 1)
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Use CGEvent to type each character
        let source = CGEventSource(stateID: .combinedSessionState)
        
        for char in text {
            // Handle special characters
            switch char {
            case "\n":
                AccessibilityInputSimulation.pressKey(virtualKey: 36, modifiers: []) // Return
            case "\t":
                AccessibilityInputSimulation.pressKey(virtualKey: 48, modifiers: []) // Tab
            default:
                if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                    event.keyboardSetUnicodeString(string: String(char))
                    event.post(tap: .cgSessionEventTap)
                    
                    if let eventUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                        eventUp.keyboardSetUnicodeString(string: String(char))
                        eventUp.post(tap: .cgSessionEventTap)
                    }
                }
            }
        }
        
        return AccessibilityServiceHelpers.successJSON([
            "message": "Typed \(text.count) characters"
        ])
    }
    
    // MARK: - Click
    
    /// Simulate a mouse click at screen coordinates
    static func clickAt(x: CGFloat, y: CGFloat, button: String = "left", clicks: Int = 1) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("clickAt(\(x), \(y)) button: \(button), clicks: \(clicks)")
        
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Convert button string to CGMouseButton
        let mouseButton: CGMouseButton
        switch button {
        case "right": mouseButton = .right
        case "middle": mouseButton = .center
        default: mouseButton = .left
        }
        
        // Convert click count to CGEventType
        let downType: CGEventType = clicks == 2 ? .leftMouseDown : .leftMouseDown
        let upType: CGEventType = clicks == 2 ? .leftMouseUp : .leftMouseUp
        
        // Create events
        for _ in 0..<clicks {
            // Mouse down
            if let downEvent = CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: mouseButton) {
                downEvent.post(tap: .cgSessionEventTap)
            }
            
            // Mouse up
            if let upEvent = CGEvent(mouseEventSource: source, mouseType: upType, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: mouseButton) {
                upEvent.post(tap: .cgSessionEventTap)
            }
            
            // Small delay between clicks for multi-click
            Thread.sleep(forTimeInterval: 0.05)
        }
        
        return AccessibilityServiceHelpers.successJSON([
            "message": "Clicked at (\(x), \(y)) with \(button) button, \(clicks) click(s)"
        ])
    }
    
    // MARK: - Scroll
    
    /// Simulate a scroll wheel at screen coordinates
    static func scrollAt(x: CGFloat, y: CGFloat, deltaX: Int, deltaY: Int) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("scrollAt(\(x), \(y)) deltaX: \(deltaX), deltaY: \(deltaY)")
        
        if let event = CGEvent(scrollWheelEventSource: nil, units: .pixel, wheelCount: 2, deltaX: deltaX, deltaY: deltaY) {
            event.location = CGPoint(x: x, y: y)
            event.post(tap: .cgSessionEventTap)
        }
        
        return AccessibilityServiceHelpers.successJSON([
            "message": "Scrolled at (\(x), \(y)) by (\(deltaX), \(deltaY))"
        ])
    }
    
    // MARK: - Press Key
    
    /// Press a key with optional modifiers
    static func pressKey(virtualKey: UInt16, modifiers: [String]) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("pressKey(\(virtualKey)) modifiers: \(modifiers)")
        
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Build modifier flags
        var flags: CGEventFlags = []
        for mod in modifiers {
            switch mod.lowercased() {
            case "command", "cmd":
                flags.insert(.maskCommand)
            case "option", "alt":
                flags.insert(.maskAlternate)
            case "control", "ctrl":
                flags.insert(.maskControl)
            case "shift":
                flags.insert(.maskShift)
            default:
                break
            }
        }
        
        // Key down
        if let downEvent = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true) {
            downEvent.flags = flags
            downEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
        }
        
        // Key up
        if let upEvent = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) {
            upEvent.flags = flags
            upEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
        }
        
        return AccessibilityServiceHelpers.successJSON([
            "message": "Pressed key code \(virtualKey) with modifiers: \(modifiers)"
        ])
    }
}