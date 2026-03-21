import Foundation
import AppKit
@preconcurrency import ApplicationServices

// MARK: - Element Operations

extension AccessibilityService {
    
    // MARK: - Set Properties (Phase 6)
    
    /// Set accessibility property values on an element. CRITICAL for setting text fields, selections, etc.
    func setProperties(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, properties: [String: Any]) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("setProperties(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), properties: \(properties.keys)")
        
        var element: AXUIElement?
        
        if let x = x, let y = y {
            let systemWide = AXUIElementCreateSystemWide()
            let copyResult = copyWithTimeout(systemWide: systemWide, x: x, y: y, timeout: Self.elementAtPositionTimeout)
            if copyResult.timedOut {
                return errorJSON("Element lookup timed out at (\(x), \(y))")
            }
            element = copyResult.element
        } else if let bundleId = appBundleId {
            let apps = NSWorkspace.shared.runningApplications
            if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
               let pid = app.processIdentifier as pid_t? {
                element = findElementInApp(pid: pid, role: role, title: title, value: value)
            }
        } else {
            element = findElementGlobally(role: role, title: title, value: value)
        }
        
        guard let found = element else {
            return errorJSON("Element not found")
        }
        
        // Check for restricted roles
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXRoleAttribute as CFString, &roleRef) == .success,
           let elRole = roleRef as? String, Self.isRestricted(elRole) {
            return errorJSON("Cannot interact with \(elRole) — disabled in Accessibility Access")
        }
        
        var results: [String: Any] = [:]
        var successCount = 0
        
        for (key, value) in properties {
            let cfValue: CFTypeRef
            if let s = value as? String {
                cfValue = s as CFString
            } else if let b = value as? Bool {
                cfValue = NSNumber(value: b)
            } else if let i = value as? Int {
                cfValue = NSNumber(value: i)
            } else if let d = value as? Double {
                cfValue = NSNumber(value: d)
            } else {
                cfValue = String(describing: value) as CFString
            }
            
            // Special handling for AXValue types (position, size)
            if key == kAXPositionAttribute as String || key == kAXSizeAttribute as String {
                guard let dict = value as? [String: CGFloat],
                      let axValue = createAXValue(key: key, from: dict) else {
                    results[key] = "Failed to create AXValue for \(key)"
                    continue
                }
                let result = AXUIElementSetAttributeValue(found, key as CFString, axValue)
                if result == .success {
                    results[key] = "set"
                    successCount += 1
                } else {
                    results[key] = "failed: \(result.rawValue)"
                }
            } else {
                let result = AXUIElementSetAttributeValue(found, key as CFString, cfValue)
                if result == .success {
                    results[key] = "set"
                    successCount += 1
                } else {
                    results[key] = "failed: \(result.rawValue)"
                }
            }
        }
        
        return successJSON([
            "message": "Set \(successCount)/\(properties.count) properties",
            "results": results
        ])
    }
    
    private func createAXValue(key: String, from dict: [String: CGFloat]) -> AXValue? {
        if key == kAXPositionAttribute as String {
            guard let x = dict["x"], let y = dict["y"] else { return nil }
            var point = CGPoint(x: x, y: y)
            return AXValueCreate(.cgPoint, &point)
        } else if key == kAXSizeAttribute as String {
            guard let w = dict["width"], let h = dict["height"] else { return nil }
            var size = CGSize(width: w, height: h)
            return AXValueCreate(.cgSize, &size)
        }
        return nil
    }
    
    // MARK: - Find Element (Phase 6)
    
    /// Find an element by role, title, or other criteria with optional timeout
    func findElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = 5.0) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("findElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")
        
        let startTime = Date()
        let notFoundError = "Element not found"
        
        while Date().timeIntervalSince(startTime) < timeout {
            var element: AXUIElement?
            
            if let bundleId = appBundleId {
                let apps = NSWorkspace.shared.runningApplications
                if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
                   let pid = app.processIdentifier as pid_t? {
                    element = findElementInApp(pid: pid, role: role, title: title, value: value)
                }
            } else {
                element = findElementGlobally(role: role, title: title, value: value)
            }
            
            if let found = element {
                return successJSON(getAllProperties(found))
            }
            
            // Small delay before retrying
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        return errorJSON(notFoundError)
    }
    
    // MARK: - Get Focused Element (Phase 6)
    
    /// Get the currently focused element
    func getFocusedElement(appBundleId: String? = nil) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("getFocusedElement(app: \(appBundleId ?? "nil"))")
        
        var element: AXUIElement?
        
        if let bundleId = appBundleId {
            let apps = NSWorkspace.shared.runningApplications
            if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
               let pid = app.processIdentifier as pid_t? {
                let appElement = AXUIElementCreateApplication(pid)
                var focusedRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
                   focusedRef != nil {
                    element = unsafeBitCast(focusedRef, to: AXUIElement.self)
                }
            }
        } else {
            // System-wide focused element
            let systemWide = AXUIElementCreateSystemWide()
            var focusedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
               focusedRef != nil {
                element = unsafeBitCast(focusedRef, to: AXUIElement.self)
            }
        }
        
        guard let found = element else {
            return errorJSON("No focused element found")
        }
        
        return successJSON(getAllProperties(found))
    }
    
    // MARK: - Get Children (Phase 6)
    
    /// Get all children of an element
    func getChildren(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, depth: Int = 3) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("getChildren(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), depth: \(depth))")
        
        var element: AXUIElement?
        
        if let x = x, let y = y {
            let systemWide = AXUIElementCreateSystemWide()
            let copyResult = copyWithTimeout(systemWide: systemWide, x: x, y: y, timeout: Self.elementAtPositionTimeout)
            if copyResult.timedOut {
                return errorJSON("Element lookup timed out at (\(x), \(y))")
            }
            element = copyResult.element
        } else if let bundleId = appBundleId {
            let apps = NSWorkspace.shared.runningApplications
            if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
               let pid = app.processIdentifier as pid_t? {
                element = findElementInApp(pid: pid, role: role, title: title, value: value)
            }
        } else {
            element = findElementGlobally(role: role, title: title, value: value)
        }
        
        guard let found = element else {
            return errorJSON("Element not found")
        }
        
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXChildrenAttribute as CFString, &childrenRef) != .success {
            return errorJSON("Element has no children")
        }
        
        guard let children = childrenRef as? [AXUIElement] else {
            return errorJSON("Failed to get children")
        }
        
        var results: [[String: Any]] = []
        for child in children {
            results.append(getAllProperties(child))
        }
        
        return successJSON([
            "count": results.count,
            "children": results
        ])
    }
    
    // MARK: - Wait For Element (Phase 6)
    
    /// Wait for an element to appear, polling periodically
    func waitForElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = 10.0, pollInterval: TimeInterval = 0.5) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("waitForElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")
        
        let startTime = Date()
        var attempts = 0
        
        while Date().timeIntervalSince(startTime) < timeout {
            attempts += 1
            
            var element: AXUIElement?
            
            if let bundleId = appBundleId {
                let apps = NSWorkspace.shared.runningApplications
                if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
                   let pid = app.processIdentifier as pid_t? {
                    element = findElementInApp(pid: pid, role: role, title: title, value: value)
                }
            } else {
                element = findElementGlobally(role: role, title: title, value: value)
            }
            
            if let found = element {
                let elapsed = Date().timeIntervalSince(startTime)
                return successJSON([
                    "message": "Element found",
                    "attempts": attempts,
                    "elapsed": String(format: "%.2f", elapsed),
                    "properties": getAllProperties(found)
                ])
            }
            
            Thread.sleep(forTimeInterval: pollInterval)
        }
        
        return errorJSON("Element not found within \(timeout)s timeout after \(attempts) attempts")
    }
    
    // MARK: - Show Menu (Phase 6)
    
    /// Show context menu for an element
    func showMenu(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("showMenu(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"))")
        
        var element: AXUIElement?
        
        if let x = x, let y = y {
            let systemWide = AXUIElementCreateSystemWide()
            let copyResult = copyWithTimeout(systemWide: systemWide, x: x, y: y, timeout: Self.elementAtPositionTimeout)
            if copyResult.timedOut {
                return errorJSON("Element lookup timed out at (\(x), \(y))")
            }
            element = copyResult.element
        } else if let bundleId = appBundleId {
            let apps = NSWorkspace.shared.runningApplications
            if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
               let pid = app.processIdentifier as pid_t? {
                element = findElementInApp(pid: pid, role: role, title: title, value: value)
            }
        } else {
            element = findElementGlobally(role: role, title: title, value: value)
        }
        
        guard let found = element else {
            return errorJSON("Element not found")
        }
        
        // Check for restricted roles
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXRoleAttribute as CFString, &roleRef) == .success,
           let elRole = roleRef as? String, Self.isRestricted(elRole) {
            return errorJSON("Cannot interact with \(elRole) — disabled in Accessibility Access")
        }
        
        // Check if the element supports AXShowMenu
        var actionsRef: CFTypeRef?
        // kAXActionNamesAttribute = "AXActionNames"
        if AXUIElementCopyAttributeValue(found, "AXActionNames" as CFString, &actionsRef) == .success,
           let actions = actionsRef as? [String], actions.contains("AXShowMenu") {
            let result = AXUIElementPerformAction(found, kAXShowMenuAction as CFString)
            if result == .success {
                return successJSON(["message": "Menu shown"])
            } else {
                return errorJSON("AXShowMenu action failed: \(result.rawValue)")
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
                return clickAt(x: centerX, y: centerY, button: "right", clicks: 1)
            }
        }
        
        return errorJSON("Element does not support showing menu and could not determine position")
    }
    
    // MARK: - Drag (Phase 6)
    
    /// Perform a drag operation from one point to another
    func drag(fromX: CGFloat, fromY: CGFloat, toX: CGFloat, toY: CGFloat, button: String = "left") -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("drag(from: (\(fromX), \(fromY)), to: (\(toX), \(toY)), button: \(button))")
        
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Map button name to CGMouseButton
        let cgButton: CGMouseButton
        switch button.lowercased() {
        case "left":
            cgButton = .left
        case "right":
            cgButton = .right
        case "middle":
            cgButton = .center
        default:
            cgButton = .left
        }
        
        // Mouse button event types
        let downEventType: CGEventType
        let upEventType: CGEventType
        let dragEventType: CGEventType
        switch cgButton {
        case .left:
            downEventType = .leftMouseDown
            upEventType = .leftMouseUp
            dragEventType = .leftMouseDragged
        case .right:
            downEventType = .rightMouseDown
            upEventType = .rightMouseUp
            dragEventType = .rightMouseDragged
        case .center:
            downEventType = .otherMouseDown
            upEventType = .otherMouseUp
            dragEventType = .otherMouseDragged
        @unknown default:
            downEventType = .leftMouseDown
            upEventType = .leftMouseUp
            dragEventType = .leftMouseDragged
        }
        
        // Move to start position
        if let moveEvent = CGEvent(source: source) {
            moveEvent.type = .mouseMoved
            moveEvent.location = CGPoint(x: fromX, y: fromY)
            moveEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
        }
        
        // Small delay to ensure position is set
        Thread.sleep(forTimeInterval: 0.05)
        
        // Mouse down at start
        if let downEvent = CGEvent(source: source) {
            downEvent.type = downEventType
            downEvent.location = CGPoint(x: fromX, y: fromY)
            downEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(cgButton.rawValue))
            downEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
        }
        
        // Animate drag with intermediate points
        let steps = 10
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let currentX = fromX + (toX - fromX) * t
            let currentY = fromY + (toY - fromY) * t
            
            if let dragEvent = CGEvent(source: source) {
                dragEvent.type = dragEventType
                dragEvent.location = CGPoint(x: currentX, y: currentY)
                dragEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(cgButton.rawValue))
                dragEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
            }
            
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        // Mouse up at destination
        if let upEvent = CGEvent(source: source) {
            upEvent.type = upEventType
            upEvent.location = CGPoint(x: toX, y: toY)
            upEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(cgButton.rawValue))
            upEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
        }
        
        return successJSON([
            "message": "Dragged from (\(fromX), \(fromY)) to (\(toX), \(toY))",
            "fromX": fromX,
            "fromY": fromY,
            "toX": toX,
            "toY": toY,
            "button": button
        ])
    }
}