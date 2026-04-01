import AgentAudit
import Foundation
import AppKit
@preconcurrency import ApplicationServices

extension AccessibilityService {
    // MARK: - Set Properties (Phase 6)

    /// Set accessibility property values on an element. CRITICAL for setting text fields, selections, etc.
    public func setProperties(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, properties: [String: Any]) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "setProperties(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), properties: \(properties.keys)")

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
    public func findElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = automationFinishTimeout) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "findElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")

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

    public func findElementInApp(pid: pid_t, role: String?, title: String?, value: String?) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        return findElementInHierarchy(app, role: role, title: title, value: value)
    }

    public func findElementGlobally(role: String?, title: String?, value: String?) -> AXUIElement? {
        for app in NSWorkspace.shared.runningApplications {
            guard let pid = app.processIdentifier as pid_t? else { continue }
            if let found = findElementInApp(pid: pid, role: role, title: title, value: value) {
                return found
            }
        }
        return nil
    }

    private func findElementInHierarchy(_ parent: AXUIElement, role: String?, title: String?, value: String?, depth: Int = 0) -> AXUIElement? {
        guard depth < Self.maxHierarchyDepth else { return nil }

        // Check role match
        if let targetRole = role {
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(parent, kAXRoleAttribute as CFString, &roleRef) == .success,
               let elementRole = roleRef as? String, elementRole == targetRole {
                // Role matches, check title if provided
                if let targetTitle = title {
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(parent, kAXTitleAttribute as CFString, &titleRef) == .success,
                       let elementTitle = titleRef as? String, elementTitle.contains(targetTitle) {
                        // Title also matches, check value if provided
                        if let targetValue = value {
                            var valueRef: CFTypeRef?
                            if AXUIElementCopyAttributeValue(parent, kAXValueAttribute as CFString, &valueRef) == .success,
                               let elementValue = valueRef as? String, elementValue.contains(targetValue) {
                                return parent
                            }
                        } else {
                            return parent
                        }
                    }
                } else if let targetValue = value {
                    // No title filter, check value
                    var valueRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(parent, kAXValueAttribute as CFString, &valueRef) == .success,
                       let elementValue = valueRef as? String, elementValue.contains(targetValue) {
                        return parent
                    }
                } else {
                    return parent
                }
            }
        } else if let targetTitle = title {
            // No role filter, check title
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(parent, kAXTitleAttribute as CFString, &titleRef) == .success,
               let elementTitle = titleRef as? String, elementTitle.contains(targetTitle) {
                if let targetValue = value {
                    var valueRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(parent, kAXValueAttribute as CFString, &valueRef) == .success,
                       let elementValue = valueRef as? String, elementValue.contains(targetValue) {
                        return parent
                    }
                } else {
                    return parent
                }
            }
        } else if let targetValue = value {
            // No role or title filter, check value
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(parent, kAXValueAttribute as CFString, &valueRef) == .success,
               let elementValue = valueRef as? String, elementValue.contains(targetValue) {
                return parent
            }
        }

        // Recurse into children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findElementInHierarchy(child, role: role, title: title, value: value, depth: depth + 1) {
                    return found
                }
            }
        }
        return nil
    }

    // MARK: - Get Focused Element (Phase 6)

    /// Get the currently focused element
    public func getFocusedElement(appBundleId: String? = nil) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "getFocusedElement(app: \(appBundleId ?? "nil"))")

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
    public func getChildren(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, depth: Int = 3) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "getChildren(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), depth: \(depth))")

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

    // MARK: - Drag (Phase 6)

    /// Perform a drag operation from one point to another
    public func drag(fromX: CGFloat, fromY: CGFloat, toX: CGFloat, toY: CGFloat, button: String = "left") -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "drag(from: (\(fromX), \(fromY)), to: (\(toX), \(toY)), button: \(button))")

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

    // MARK: - Wait For Element (Phase 6)

    /// Wait for an element to appear, polling periodically
    public func waitForElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = automationFinishTimeout, pollInterval: TimeInterval = 0.5) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "waitForElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")

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
    public func showMenu(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "showMenu(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"))")

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
			            let axValue = unsafeDowncast(positionValue, to: AXValue.self)
		            if AXValueGetValue(axValue, .cgPoint, &point) {
	                // Get size for center of element
	                var sizeRef: CFTypeRef?
	                var width: CGFloat = 1
	                var height: CGFloat = 1
	                if AXUIElementCopyAttributeValue(found, kAXSizeAttribute as CFString, &sizeRef) == .success,
	                   let sizeValue = sizeRef,
	                   CFGetTypeID(sizeValue) == AXValueGetTypeID() {
	                    var size = CGSize.zero
			                    let axSizeValue = unsafeDowncast(sizeValue, to: AXValue.self)
		                    if AXValueGetValue(axSizeValue, .cgSize, &size) {
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

    // MARK: - Smart Element Click (Phase 1 Improvement)

    /// Click an element by finding it semantically (role/title) and clicking its center.
    /// This is more reliable than coordinate-based clicking for web automation.
    /// - Parameters:
    ///   - role: Accessibility role to find (e.g., "AXButton", "AXTextField")
    ///   - title: Title or name to match (partial match supported)
    ///   - value: Value content to match (partial match supported)
    ///   - appBundleId: Optional bundle ID to search within a specific app
    ///   - timeout: Maximum time to wait for element to appear (default 5 seconds)
    ///   - verify: Whether to verify the click succeeded via screenshot (default false)
    /// - Returns: JSON result with click position and verification status
    public func clickElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = automationFinishTimeout, verify: Bool = false) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "clickElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout), verify: \(verify))")

        // Find the element
        let startTime = Date()
        var element: AXUIElement?

        while Date().timeIntervalSince(startTime) < timeout {
            if let bundleId = appBundleId {
                let apps = NSWorkspace.shared.runningApplications
                if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
                   let pid = app.processIdentifier as pid_t? {
                    element = findElementInApp(pid: pid, role: role, title: title, value: value)
                }
            } else {
                element = findElementGlobally(role: role, title: title, value: value)
            }

            if element != nil { break }
            Thread.sleep(forTimeInterval: 0.1)
        }

        guard let found = element else {
            return errorJSON("Element not found within \(timeout)s timeout")
        }

        // Check for restricted roles
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXRoleAttribute as CFString, &roleRef) == .success,
           let elRole = roleRef as? String, Self.isRestricted(elRole) {
            return errorJSON("Cannot interact with \(elRole) — disabled in Accessibility Access")
        }

        // Get element position and size
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(found, kAXPositionAttribute as CFString, &positionRef) == .success,
              let positionValue = positionRef,
              CFGetTypeID(positionValue) == AXValueGetTypeID() else {
            return errorJSON("Could not get element position")
        }

		        var point = CGPoint.zero
		        let axPosValue = positionValue as! AXValue
		        guard AXValueGetValue(axPosValue, .cgPoint, &point) else {
		            return errorJSON("Could not decode element position")
		        }

	        var width: CGFloat = 1
	        var height: CGFloat = 1
	        if AXUIElementCopyAttributeValue(found, kAXSizeAttribute as CFString, &sizeRef) == .success,
	           let sizeValue = sizeRef,
		           CFGetTypeID(sizeValue) == AXValueGetTypeID() {
		            let axSizeValue = sizeValue as! AXValue
		            var size = CGSize.zero
		            if AXValueGetValue(axSizeValue, .cgSize, &size) {
	                width = size.width
	                height = size.height
	            }
	        }

        // Calculate center point
        let centerX = point.x + width / 2
        let centerY = point.y + height / 2

        // Capture screenshot before click if verifying
        var beforeScreenshot: String? = nil
        if verify {
            beforeScreenshot = captureScreenshot(x: point.x - 5, y: point.y - 5, width: width + 10, height: height + 10)
        }

        // Perform the click
        _ = clickAt(x: centerX, y: centerY, button: "left", clicks: 1)

        // Small delay for UI to respond
        Thread.sleep(forTimeInterval: 0.1)

        var result: [String: Any] = [
            "message": "Clicked element",
            "role": roleRef as? String ?? "Unknown",
            "centerX": centerX,
            "centerY": centerY,
            "width": width,
            "height": height
        ]

        // Add verification if requested
        if verify, let before = beforeScreenshot, !before.contains("\"success\": false") {
            result["verification"] = "screenshot_captured"
            result["screenshot_before"] = before
        }

        return successJSON(result)
    }

    // MARK: - Adaptive Wait for Element (Phase 1 Improvement)

    /// Wait for an element to appear with exponential backoff polling.
    /// More efficient than fixed-interval polling for slow-loading content.
    /// - Parameters:
    ///   - role: Accessibility role to find
    ///   - title: Title to match (partial)
    ///   - value: Value to match (partial)
    ///   - appBundleId: Optional bundle ID to search within
    ///   - timeout: Maximum wait time (default 10 seconds)
    ///   - initialDelay: Initial polling delay (default 0.1 seconds)
    ///   - maxDelay: Maximum polling delay (default 1.0 seconds)
    ///   - multiplier: Delay multiplier for backoff (default 1.5)
    /// - Returns: JSON result with found element properties
    public func waitForElementAdaptive(
        role: String?,
        title: String?,
        value: String?,
        appBundleId: String?,
        timeout: TimeInterval = automationFinishTimeout,
        initialDelay: TimeInterval = 0.1,
        maxDelay: TimeInterval = automationMaxDelay,
        multiplier: Double = 1.5
    ) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "waitForElementAdaptive(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")

        let startTime = Date()
        var currentDelay = initialDelay
        var attempts = 0
        var lastError: String? = nil

        while Date().timeIntervalSince(startTime) < timeout {
            attempts += 1
            var element: AXUIElement?

            if let bundleId = appBundleId {
                let apps = NSWorkspace.shared.runningApplications
                if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
                   let pid = app.processIdentifier as pid_t? {
                    element = findElementInApp(pid: pid, role: role, title: title, value: value)
                } else {
                    lastError = "App not found: \(bundleId)"
                }
            } else {
                element = findElementGlobally(role: role, title: title, value: value)
            }

            if let found = element {
                let elapsed = Date().timeIntervalSince(startTime)
                var props = getAllProperties(found)
                props["found_after_attempts"] = attempts
                props["elapsed_seconds"] = String(format: "%.2f", elapsed)
                props["final_poll_interval"] = String(format: "%.2f", currentDelay)
                return successJSON(props)
            }

            // Exponential backoff
            Thread.sleep(forTimeInterval: currentDelay)
            currentDelay = min(currentDelay * multiplier, maxDelay)
        }

        let errorMsg = lastError ?? "Element not found"
        return errorJSON("\(errorMsg) within \(timeout)s timeout after \(attempts) attempts (adaptive polling)")
    }

    // MARK: - Verification Helpers (Phase 1 Improvement)

    /// Capture a verification screenshot after an action
    /// - Parameters:
    ///   - action: Description of the action performed
    ///   - role: Role of element acted upon
    ///   - title: Title of element acted upon
    ///   - appBundleId: Optional bundle ID
    /// - Returns: JSON with screenshot path and element verification
    public func captureVerificationScreenshot(action: String, role: String?, title: String?, appBundleId: String?) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "captureVerificationScreenshot(action: \(action))")

        // Take fullscreen screenshot
        let screenshotResult = captureAllWindows()

        // Try to find the element again for verification
        var elementStatus = "not_verified"
        if (role ?? title) != nil {
            let findResult = findElement(role: role, title: title, value: nil, appBundleId: appBundleId, timeout: 1.0)

            if findResult.contains("\"success\": true") {
                elementStatus = "verified_present"
            } else {
                elementStatus = "not_found_after_action"
            }
        }

        let result: [String: Any] = [
            "action": action,
            "element_status": elementStatus,
            "screenshot": screenshotResult
        ]

        return successJSON(result)
    }

    /// Type text into an element with verification
    /// - Parameters:
    ///   - role: Accessibility role of target element
    ///   - title: Title of target element
    ///   - text: Text to type
    ///   - appBundleId: Optional bundle ID
    ///   - verify: Whether to verify the text was entered (default true)
    /// - Returns: JSON result with verification status
    public func typeTextIntoElement(role: String?, title: String?, text: String, appBundleId: String?, verify: Bool = true) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "typeTextIntoElement(role: \(role ?? "nil"), title: \(title ?? "nil"), text: \(text.count) chars, verify: \(verify))")

        // Find element first
        let findResult = findElement(role: role, title: title, value: nil, appBundleId: appBundleId, timeout: automationStartTimeout)

        // Extract position from find result
        guard findResult.contains("\"success\": true") else {
            return errorJSON("Element not found for typing")
        }

        // Try to use ax_set_properties for text fields (faster and more reliable)
        let setPropsResult = setProperties(role: role, title: title, value: nil, appBundleId: appBundleId, x: nil, y: nil, properties: ["AXValue": text])

        if setPropsResult.contains("\"success\": true") {
            if verify {
                // Verify the value was set
                Thread.sleep(forTimeInterval: 0.2)
                let checkResult: String
                if let bundleId = appBundleId {
                    checkResult = getElementProperties(role: role, title: title, value: nil, appBundleId: bundleId, x: nil, y: nil)
                } else {
                    checkResult = getElementProperties(role: role, title: title, value: nil, appBundleId: nil, x: nil, y: nil)
                }

                if checkResult.contains(text) {
                    return successJSON([
                        "message": "Text set via AXValue",
                        "method": "ax_set_properties",
                        "verified": true,
                        "text_length": text.count
                    ])
                } else {
                    // Fall back to CGEvent typing
                    return typeTextFallback(role: role, title: title, text: text, appBundleId: appBundleId)
                }
            }

            return successJSON([
                "message": "Text set via AXValue",
                "method": "ax_set_properties",
                "verified": false,
                "text_length": text.count
            ])
        }

        // Fall back to CGEvent typing
        return typeTextFallback(role: role, title: title, text: text, appBundleId: appBundleId)
    }

    private func typeTextFallback(role: String?, title: String?, text: String, appBundleId: String?) -> String {
        // Find element position and click to focus
        let findResult = findElement(role: role, title: title, value: nil, appBundleId: appBundleId, timeout: automationStartTimeout)

        // Parse position from JSON result
        // Look for "AXPosition" : { "x": ..., "y": ... }
        if let range = findResult.range(of: "\"AXPosition\" : \\{[^}]+\\}", options: .regularExpression) {
            let posStr = String(findResult[range])
            if let xRange = posStr.range(of: "\"x\" : ([0-9.]+)", options: .regularExpression),
               let yRange = posStr.range(of: "\"y\" : ([0-9.]+)", options: .regularExpression) {
                let xStr = String(posStr[xRange].split(separator: ":").last ?? "0").trimmingCharacters(in: .whitespaces)
                let yStr = String(posStr[yRange].split(separator: ":").last ?? "0").trimmingCharacters(in: .whitespaces)

                if let x = Double(xStr), let y = Double(yStr) {
                    // Click to focus
                    _ = clickAt(x: CGFloat(x), y: CGFloat(y), button: "left", clicks: 1)
                    Thread.sleep(forTimeInterval: 0.1)

                    // Type using CGEvent
                    return typeText(text)
                }
            }
        }

        return errorJSON("Could not determine element position for typing")
    }
}
