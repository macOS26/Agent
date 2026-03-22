import Foundation
import AppKit
@preconcurrency import ApplicationServices

/// Element finding, waiting, and advanced interaction utilities.
/// Provides findElement, waitForElement, clickElement, and related methods.
enum AccessibilityElementFinding {
    
    /// Timeout constants (shared with main service)
    static let automationFinishTimeout: TimeInterval = 10.0
    static let automationStartTimeout: TimeInterval = 5.0
    static let automationMaxDelay: TimeInterval = 1.0
    
    // MARK: - Find Element
    
    /// Find an element by role, title, or other criteria with optional timeout
    static func findElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = automationFinishTimeout) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("findElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")
        
        let startTime = Date()
        let notFoundError = "Element not found"
        
        while Date().timeIntervalSince(startTime) < timeout {
            var element: AXUIElement?
            
            if let bundleId = appBundleId {
                let apps = NSWorkspace.shared.runningApplications
                if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
                   let pid = app.processIdentifier as pid_t? {
                    element = AccessibilityElementFinder.findElementInApp(pid: pid, role: role, title: title, value: value)
                }
            } else {
                element = AccessibilityElementFinder.findElementGlobally(role: role, title: title, value: value)
            }
            
            if let found = element {
                return AccessibilityServiceHelpers.successJSON(AccessibilityProperties.getAllProperties(found))
            }
            
            // Small delay before retrying
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        return AccessibilityServiceHelpers.errorJSON(notFoundError)
    }
    
    // MARK: - Get Focused Element
    
    /// Get the currently focused accessibility element
    static func getFocusedElement(appBundleId: String? = nil) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("getFocusedElement(app: \(appBundleId ?? "nil"))")
        
        // Get focused app (either specified or frontmost)
        let focusedApp: AXUIElement?
        if let bundleId = appBundleId {
            let apps = NSWorkspace.shared.runningApplications
            guard let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
                  let pid = app.processIdentifier as pid_t? else {
                return AccessibilityServiceHelpers.errorJSON("App not found: \(bundleId)")
            }
            focusedApp = AXUIElementCreateApplication(pid)
        } else {
            // Get frontmost app
            let apps = NSWorkspace.shared.runningApplications
            guard let frontmost = apps.first(where: { $0.isActive }),
                  let pid = frontmost.processIdentifier as pid_t? else {
                return AccessibilityServiceHelpers.errorJSON("No frontmost app found")
            }
            focusedApp = AXUIElementCreateApplication(pid)
        }
        
        guard let app = focusedApp else {
            return AccessibilityServiceHelpers.errorJSON("Could not get focused app")
        }
        
        // Get focused element
        var focusedRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        
        guard result == .success, let focusedElement = focusedRef else {
            return AccessibilityServiceHelpers.errorJSON("No focused element found")
        }
        
        return AccessibilityServiceHelpers.successJSON(AccessibilityProperties.getAllProperties(focusedElement as! AXUIElement))
    }
    
    // MARK: - Get Children
    
    /// Get all children of an accessibility element
    static func getChildren(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, depth: Int = 3) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("getChildren(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), depth: \(depth))")
        
        var element: AXUIElement?
        
        if let x = x, let y = y {
            let systemWide = AXUIElementCreateSystemWide()
            let copyResult = AccessibilityElementFinder.copyWithTimeout(systemWide: systemWide, x: x, y: y, timeout: AccessibilityWindows.elementAtPositionTimeout)
            if copyResult.timedOut {
                return AccessibilityServiceHelpers.errorJSON("Element lookup timed out at (\(x), \(y))")
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
        
        var children: [[String: Any]] = []
        
        func collectChildren(_ parent: AXUIElement, currentDepth: Int) {
            guard currentDepth < depth else { return }
            
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let childElements = childrenRef as? [AXUIElement] {
                for child in childElements {
                    let props = AccessibilityProperties.getAllProperties(child)
                    children.append(props)
                    collectChildren(child, currentDepth: currentDepth + 1)
                }
            }
        }
        
        collectChildren(found, currentDepth: 0)
        
        return AccessibilityServiceHelpers.successJSON(["children": children, "count": children.count])
    }
    
    // MARK: - Wait For Element
    
    /// Wait for an element to appear with polling
    static func waitForElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = automationFinishTimeout, pollInterval: TimeInterval = 0.5) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("waitForElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")
        
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            var element: AXUIElement?
            
            if let bundleId = appBundleId {
                let apps = NSWorkspace.shared.runningApplications
                if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
                   let pid = app.processIdentifier as pid_t? {
                    element = AccessibilityElementFinder.findElementInApp(pid: pid, role: role, title: title, value: value)
                }
            } else {
                element = AccessibilityElementFinder.findElementGlobally(role: role, title: title, value: value)
            }
            
            if let found = element {
                return AccessibilityServiceHelpers.successJSON(AccessibilityProperties.getAllProperties(found))
            }
            
            Thread.sleep(forTimeInterval: pollInterval)
        }
        
        return AccessibilityServiceHelpers.errorJSON("Element not found within \(timeout)s timeout")
    }
    
    // MARK: - Drag
    
    /// Perform a drag operation from one point to another
    static func drag(fromX: CGFloat, fromY: CGFloat, toX: CGFloat, toY: CGFloat, button: String = "left") -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("drag(from: (\(fromX), \(fromY)), to: (\(toX), \(toY)), button: \(button))")
        
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Convert button string to CGMouseButton
        let mouseButton: CGMouseButton
        switch button {
        case "right": mouseButton = .right
        case "middle": mouseButton = .center
        default: mouseButton = .left
        }
        
        // Mouse down at start position
        if let downEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: fromX, y: fromY), mouseButton: mouseButton) {
            downEvent.post(tap: .cgSessionEventTap)
        }
        
        // Drag to end position
        if let dragEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: CGPoint(x: toX, y: toY), mouseButton: mouseButton) {
            dragEvent.post(tap: .cgSessionEventTap)
        }
        
        // Mouse up at end position
        if let upEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: toX, y: toY), mouseButton: mouseButton) {
            upEvent.post(tap: .cgSessionEventTap)
        }
        
        return AccessibilityServiceHelpers.successJSON([
            "message": "Dragged from (\(fromX), \(fromY)) to (\(toX), \(toY))"
        ])
    }
    
    // MARK: - Show Menu
    
    /// Show context menu for an element
    static func showMenu(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("showMenu(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"))")
        
        var element: AXUIElement?
        
        if let x = x, let y = y {
            let systemWide = AXUIElementCreateSystemWide()
            let copyResult = AccessibilityElementFinder.copyWithTimeout(systemWide: systemWide, x: x, y: y, timeout: AccessibilityWindows.elementAtPositionTimeout)
            if copyResult.timedOut {
                return AccessibilityServiceHelpers.errorJSON("Element lookup timed out at (\(x), \(y))")
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
        
        // Check if the element supports AXShowMenu
        var actionsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, "AXActionNames" as CFString, &actionsRef) == .success,
           let actions = actionsRef as? [String], actions.contains("AXShowMenu") {
            let result = AXUIElementPerformAction(found, kAXShowMenuAction as CFString)
            if result == .success {
                return AccessibilityServiceHelpers.successJSON(["message": "Menu shown"])
            } else {
                return AccessibilityServiceHelpers.errorJSON("AXShowMenu action failed: \(result.rawValue)")
            }
        }
        
        // Fallback: simulate right-click at element position
        var positionRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXPositionAttribute as CFString, &positionRef) == .success,
           let positionValue = positionRef,
           CFGetTypeID(positionValue) == AXValueGetTypeID() {
            var point = CGPoint.zero
            if AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) {
                // Get size for center of element
                var sizeRef: CFTypeRef?
                var width: CGFloat = 1
                var height: CGFloat = 1
                if AXUIElementCopyAttributeValue(found, kAXSizeAttribute as CFString, &sizeRef) == .success,
                   let sizeValue = sizeRef,
                   CFGetTypeID(sizeValue) == AXValueGetTypeID() {
                    var size = CGSize.zero
                    if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                        width = size.width
                        height = size.height
                    }
                }
                
                // Right-click at center of element
                let centerX = point.x + width / 2
                let centerY = point.y + height / 2
                return AccessibilityInputSimulation.clickAt(x: centerX, y: centerY, button: "right", clicks: 1)
            }
        }
        
        return AccessibilityServiceHelpers.errorJSON("Element does not support showing menu and could not determine position")
    }
    
    // MARK: - Frontmost Window ID
    
    /// Get the window ID of the frontmost window
    static func frontmostWindowID() -> UInt32? {
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        
        for window in windowList {
            guard let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0, // Frontmost layer
                  let windowID = window[kCGWindowNumber as String] as? Int,
                  let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  let ownerName = window[kCGWindowOwnerName as String] as? String,
                  !ownerName.isEmpty else { continue }
            
            // Skip system windows
            if ownerName == "Window Server" || ownerName == "Dock" { continue }
            
            return UInt32(windowID)
        }
        
        return nil
    }
}