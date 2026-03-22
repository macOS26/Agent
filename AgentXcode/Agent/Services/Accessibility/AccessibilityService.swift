import Foundation
import AppKit
@preconcurrency import ApplicationServices

/// Accessibility automation service for interacting with UI elements via the Accessibility API.
/// Provides tools for window listing, element inspection, and UI interaction.
/// This is a facade that delegates to specialized helper enums for better organization.
final class AccessibilityService: @unchecked Sendable {
    static let shared = AccessibilityService()
    
    // MARK: - Timeout Constants
    
    static let automationFinishTimeout: TimeInterval = 10.0
    static let automationStartTimeout: TimeInterval = 5.0
    static let automationMaxDelay: TimeInterval = 1.0
    
    // MARK: - Security
    
    static func hasAccessibilityPermission() -> Bool {
        AccessibilityPermissions.hasAccessibilityPermission()
    }
    
    static func requestAccessibilityPermission() -> Bool {
        AccessibilityPermissions.requestAccessibilityPermission()
    }
    
    // MARK: - Window Listing
    
    func listWindows(limit: Int = 50) -> String {
        AccessibilityWindows.listWindows(limit: limit)
    }
    
    // MARK: - Element Inspection
    
    func inspectElementAt(x: CGFloat, y: CGFloat, depth: Int = 3) -> String {
        AccessibilityWindows.inspectElementAt(x: x, y: y, depth: depth)
    }
    
    // MARK: - Get Element Properties
    
    func getElementProperties(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?) -> String {
        AccessibilityProperties.getElementProperties(role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y)
    }
    
    // MARK: - Perform Actions
    
    func performAction(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, action: String) -> String {
        AccessibilityInputSimulation.performAction(role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y, action: action)
    }
    
    // MARK: - Input Simulation
    
    func typeText(_ text: String, at x: CGFloat? = nil, y: CGFloat? = nil) -> String {
        AccessibilityInputSimulation.typeText(text, at: x, y: y)
    }
    
    func clickAt(x: CGFloat, y: CGFloat, button: String = "left", clicks: Int = 1) -> String {
        AccessibilityInputSimulation.clickAt(x: x, y: y, button: button, clicks: clicks)
    }
    
    func scrollAt(x: CGFloat, y: CGFloat, deltaX: Int, deltaY: Int) -> String {
        AccessibilityInputSimulation.scrollAt(x: x, y: y, deltaX: deltaX, deltaY: deltaY)
    }
    
    func pressKey(virtualKey: UInt16, modifiers: [String] = []) -> String {
        AccessibilityInputSimulation.pressKey(virtualKey: virtualKey, modifiers: modifiers)
    }
    
    // MARK: - Screenshot
    
    func captureScreenshot(x: CGFloat? = nil, y: CGFloat? = nil, width: CGFloat? = nil, height: CGFloat? = nil, windowID: Int? = nil) -> String {
        AccessibilityScreenshot.captureScreenshot(x: x, y: y, width: width, height: height, windowID: windowID)
    }
    
    func captureAllWindows() -> String {
        AccessibilityScreenshot.captureAllWindows()
    }
    
    // MARK: - Set Properties
    
    func setProperties(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, properties: [String: Any]) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("setProperties(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), properties: \(properties.keys)")
        
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
        
        var results: [String: Any] = [:]
        var successCount = 0
        
        for (key, value) in properties {
            var axValue: AXValue?
            
            if let stringValue = value as? String {
                // Handle position/size dictionaries
                if let dict = value as? [String: CGFloat] {
                    axValue = AccessibilityProperties.createAXValue(key: key, from: dict)
                } else {
                    // Simple string value
                    axValue = AXValueCreate(.generic, stringValue as CFTypeRef)
                }
            } else if let intValue = value as? Int {
                let num = intValue as CFNumber
                axValue = AXValueCreate(.generic, num)
            } else if let boolValue = value as? Bool {
                let num = (boolValue ? 1 : 0) as CFNumber
                axValue = AXValueCreate(.generic, num)
            }
            
            if let axVal = axValue {
                let result = AXUIElementSetAttributeValue(found, key as CFString, axVal)
                if result == .success {
                    results[key] = "set"
                    successCount += 1
                } else {
                    results[key] = "failed: \(result.rawValue)"
                }
            }
        }
        
        return AccessibilityServiceHelpers.successJSON([
            "message": "Set \(successCount)/\(properties.count) properties",
            "results": results
        ])
    }
    
    // MARK: - Find Element
    
    func findElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = Self.automationFinishTimeout) -> String {
        AccessibilityElementFinding.findElement(role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout)
    }
    
    // MARK: - Get Focused Element
    
    func getFocusedElement(appBundleId: String? = nil) -> String {
        AccessibilityElementFinding.getFocusedElement(appBundleId: appBundleId)
    }
    
    // MARK: - Get Children
    
    func getChildren(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, depth: Int = 3) -> String {
        AccessibilityElementFinding.getChildren(role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y, depth: depth)
    }
    
    // MARK: - Drag
    
    func drag(fromX: CGFloat, fromY: CGFloat, toX: CGFloat, toY: CGFloat, button: String = "left") -> String {
        AccessibilityElementFinding.drag(fromX: fromX, fromY: fromY, toX: toX, toY: toY, button: button)
    }
    
    // MARK: - Wait For Element
    
    func waitForElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = Self.automationFinishTimeout, pollInterval: TimeInterval = 0.5) -> String {
        AccessibilityElementFinding.waitForElement(role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout, pollInterval: pollInterval)
    }
    
    // MARK: - Show Menu
    
    func showMenu(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?) -> String {
        AccessibilityElementFinding.showMenu(role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y)
    }
    
    // MARK: - Smart Element Click
    
    func clickElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = Self.automationFinishTimeout, verify: Bool = false) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("clickElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout), verify: \(verify))")
        
        // Find the element
        let startTime = Date()
        var element: AXUIElement?
        
        while Date().timeIntervalSince(startTime) < timeout {
            if let bundleId = appBundleId {
                let apps = NSWorkspace.shared.runningApplications
                if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
                   let pid = app.processIdentifier as pid_t? {
                    element = AccessibilityElementFinder.findElementInApp(pid: pid, role: role, title: title, value: value)
                }
            } else {
                element = AccessibilityElementFinder.findElementGlobally(role: role, title: title, value: value)
            }
            
            if element != nil { break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        guard let found = element else {
            return AccessibilityServiceHelpers.errorJSON("Element not found within \(timeout)s timeout")
        }
        
        // Check for restricted roles
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXRoleAttribute as CFString, &roleRef) == .success,
           let elRole = roleRef as? String, AccessibilityPermissions.isRestricted(elRole) {
            return AccessibilityServiceHelpers.errorJSON("Cannot interact with \(elRole) — disabled in Accessibility Access")
        }
        
        // Get position
        var positionRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(found, kAXPositionAttribute as CFString, &positionRef) == .success,
              let positionValue = positionRef,
              CFGetTypeID(positionValue) == AXValueGetTypeID() else {
            return AccessibilityServiceHelpers.errorJSON("Could not get element position")
        }
        
        var point = CGPoint.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) else {
            return AccessibilityServiceHelpers.errorJSON("Could not decode element position")
        }
        
        // Get size for center
        var width: CGFloat = 1
        var height: CGFloat = 1
        var sizeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXSizeAttribute as CFString, &sizeRef) == .success,
           let sizeValue = sizeRef,
           CFGetTypeID(sizeValue) == AXValueGetTypeID() {
            var size = CGSize.zero
            if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                width = size.width
                height = size.height
            }
        }
        
        // Click at center
        let centerX = point.x + width / 2
        let centerY = point.y + height / 2
        
        let clickResult = AccessibilityInputSimulation.clickAt(x: centerX, y: centerY, button: "left", clicks: 1)
        
        if verify {
            // Capture screenshot for verification
            Thread.sleep(forTimeInterval: 0.5)
            let screenshotResult = AccessibilityScreenshot.captureAllWindows()
            var result: [String: Any] = [
                "click_position": ["x": centerX, "y": centerY],
                "click_result": clickResult
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: screenshotResult, options: []),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                result["verification"] = "screenshot_captured"
                result["screenshot"] = jsonStr
            }
            return AccessibilityServiceHelpers.successJSON(result)
        }
        
        return AccessibilityServiceHelpers.successJSON([
            "message": "Clicked element at (\(centerX), \(centerY))",
            "position": ["x": centerX, "y": centerY]
        ])
    }
    
    // MARK: - Adaptive Wait for Element
    
    func waitForElementAdaptive(
        role: String?,
        title: String?,
        value: String?,
        appBundleId: String?,
        timeout: TimeInterval = Self.automationFinishTimeout,
        initialDelay: TimeInterval = 0.1,
        maxDelay: TimeInterval = Self.automationMaxDelay,
        multiplier: Double = 1.5
    ) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("waitForElementAdaptive(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")
        
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
                    element = AccessibilityElementFinder.findElementInApp(pid: pid, role: role, title: title, value: value)
                } else {
                    lastError = "App not found: \(bundleId)"
                }
            } else {
                element = AccessibilityElementFinder.findElementGlobally(role: role, title: title, value: value)
            }
            
            if let found = element {
                let elapsed = Date().timeIntervalSince(startTime)
                var props = AccessibilityProperties.getAllProperties(found)
                props["found_after_attempts"] = attempts
                props["elapsed_seconds"] = String(format: "%.2f", elapsed)
                props["final_poll_interval"] = String(format: "%.2f", currentDelay)
                return AccessibilityServiceHelpers.successJSON(props)
            }
            
            // Exponential backoff
            Thread.sleep(forTimeInterval: currentDelay)
            currentDelay = min(currentDelay * multiplier, maxDelay)
        }
        
        let errorMsg = lastError ?? "Element not found"
        return AccessibilityServiceHelpers.errorJSON("\(errorMsg) within \(timeout)s timeout after \(attempts) attempts (adaptive polling)")
    }
    
    // MARK: - Type Text Into Element
    
    func typeTextIntoElement(role: String?, title: String?, text: String, appBundleId: String?, verify: Bool = true) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("typeTextIntoElement(role: \(role ?? "nil"), title: \(title ?? "nil"), text: \(text.count) chars, verify: \(verify))")
        
        // Find element first
        let findResult = AccessibilityElementFinding.findElement(role: role, title: title, value: nil, appBundleId: appBundleId, timeout: Self.automationStartTimeout)
        
        guard findResult.contains("\"success\": true") else {
            return AccessibilityServiceHelpers.errorJSON("Element not found for typing")
        }
        
        // Try to use ax_set_properties for text fields (faster and more reliable)
        let setPropsResult = setProperties(role: role, title: title, value: nil, appBundleId: appBundleId, x: nil, y: nil, properties: ["AXValue": text])
        
        if setPropsResult.contains("\"success\": true") {
            if verify {
                Thread.sleep(forTimeInterval: 0.2)
                let checkResult = AccessibilityProperties.getElementProperties(role: role, title: title, value: nil, appBundleId: appBundleId, x: nil, y: nil)
                
                if checkResult.contains(text) {
                    return AccessibilityServiceHelpers.successJSON([
                        "message": "Text set via AXValue",
                        "method": "ax_set_properties",
                        "verified": true,
                        "text_length": text.count
                    ])
                }
            }
            
            return AccessibilityServiceHelpers.successJSON([
                "message": "Text set via AXValue",
                "method": "ax_set_properties",
                "verified": false,
                "text_length": text.count
            ])
        }
        
        // Fall back to CGEvent typing
        // Find element position and click to focus
        let findResult2 = AccessibilityElementFinding.findElement(role: role, title: title, value: nil, appBundleId: appBundleId, timeout: Self.automationStartTimeout)
        
        // Parse position from JSON result
        if let range = findResult2.range(of: "\"AXPosition\" : \\{[^}]+\\}", options: .regularExpression) {
            let posStr = String(findResult2[range])
            if let xRange = posStr.range(of: "\"x\" : ([0-9.]+)", options: .regularExpression),
               let yRange = posStr.range(of: "\"y\" : ([0-9.]+)", options: .regularExpression) {
                let xStr = String(posStr[xRange].split(separator: ":").last ?? "0").trimmingCharacters(in: .whitespaces)
                let yStr = String(posStr[yRange].split(separator: ":").last ?? "0").trimmingCharacters(in: .whitespaces)
                
                if let x = Double(xStr), let y = Double(yStr) {
                    // Click to focus
                    _ = AccessibilityInputSimulation.clickAt(x: CGFloat(x), y: CGFloat(y), button: "left", clicks: 1)
                    Thread.sleep(forTimeInterval: 0.1)
                    
                    // Type using CGEvent
                    return AccessibilityInputSimulation.typeText(text)
                }
            }
        }
        
        return AccessibilityServiceHelpers.errorJSON("Could not determine element position for typing")
    }
    
    // MARK: - Highlight Element
    
    func highlightElement(
        role: String?,
        title: String?,
        value: String?,
        appBundleId: String?,
        x: CGFloat?,
        y: CGFloat?,
        color: String = "green",
        duration: TimeInterval = 2.0
    ) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("highlightElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), color: \(color), duration: \(duration))")
        
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
        
        // Get position and size
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(found, kAXPositionAttribute as CFString, &positionRef) == .success,
              let positionValue = positionRef,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              AXUIElementCopyAttributeValue(found, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let sizeValue = sizeRef,
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return AccessibilityServiceHelpers.errorJSON("Could not get element bounds")
        }
        
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
            return AccessibilityServiceHelpers.errorJSON("Could not decode element bounds")
        }
        
        // Create overlay window
        DispatchQueue.main.async {
            let overlayWindow = NSWindow(
                contentRect: NSRect(x: point.x, y: point.y, width: size.width, height: size.height),
                styleMask: .borderless,
                backing: .screen,
                defer: false
            )
            
            overlayWindow.backgroundColor = NSColor.clear
            overlayWindow.level = .floating
            overlayWindow.ignoresMouseEvents = true
            overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            // Color
            let nsColor: NSColor
            switch color.lowercased() {
            case "red": nsColor = NSColor.red.withAlphaComponent(0.3)
            case "blue": nsColor = NSColor.blue.withAlphaComponent(0.3)
            case "yellow": nsColor = NSColor.yellow.withAlphaComponent(0.3)
            case "purple": nsColor = NSColor.purple.withAlphaComponent(0.3)
            default: nsColor = NSColor.green.withAlphaComponent(0.3)
            }
            
            let borderView = NSView(frame: NSRect(origin: .zero, size: size))
            borderView.wantsLayer = true
            borderView.layer?.borderColor = nsColor.cgColor
            borderView.layer?.borderWidth = 3.0
            borderView.layer?.backgroundColor = NSColor.clear.cgColor
            
            overlayWindow.contentView = borderView
            overlayWindow.makeKeyAndOrderFront(nil)
            
            // Remove after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                overlayWindow.close()
            }
        }
        
        return AccessibilityServiceHelpers.successJSON([
            "message": "Element highlighted",
            "position": ["x": point.x, "y": point.y],
            "size": ["width": size.width, "height": size.height],
            "color": color,
            "duration": duration
        ])
    }
    
    // MARK: - Get Window Frame
    
    func getWindowFrame(windowId: Int) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("getWindowFrame(windowId: \(windowId))")
        
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        
        for window in windowList {
            guard let wid = window[kCGWindowNumber as String] as? Int,
                  wid == windowId else { continue }
            
            let ownerPID = window[kCGWindowOwnerPID as String] as? Int32 ?? 0
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let windowName = window[kCGWindowName as String] as? String ?? ""
            let bounds = window[kCGWindowBounds as String] as? [String: CGFloat]
            
            return AccessibilityServiceHelpers.successJSON([
                "windowId": windowId,
                "ownerPID": Int(ownerPID),
                "ownerName": AccessibilityServiceHelpers.getProcessName(pid: ownerPID) ?? ownerName,
                "windowName": windowName,
                "bounds": [
                    "x": bounds?["X"] ?? 0,
                    "y": bounds?["Y"] ?? 0,
                    "width": bounds?["Width"] ?? 0,
                    "height": bounds?["Height"] ?? 0
                ]
            ])
        }
        
        return AccessibilityServiceHelpers.errorJSON("Window not found: \(windowId)")
    }
    
    // MARK: - Audit Logging
    
    static func getAuditLog(limit: Int = 50) -> String {
        AccessibilityServiceHelpers.getAuditLog(limit: limit)
    }
}