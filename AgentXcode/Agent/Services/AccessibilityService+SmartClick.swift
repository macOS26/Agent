import Foundation
import AppKit
@preconcurrency import ApplicationServices

// MARK: - Smart Element Click & Adaptive Wait

extension AccessibilityService {
    
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
    func clickElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = 5.0, verify: Bool = false) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("clickElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout), verify: \(verify))")
        
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
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) else {
            return errorJSON("Could not decode element position")
        }
        
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
        
        // Verify click if requested (compare screenshots)
        if verify, let before = beforeScreenshot {
            Thread.sleep(forTimeInterval: 0.3)
            let afterScreenshot = captureScreenshot(x: point.x - 5, y: point.y - 5, width: width + 10, height: height + 10)
            result["verification"] = "Screenshots captured for comparison"
            result["beforePath"] = before
            result["afterPath"] = afterScreenshot
        }
        
        return successJSON(result)
    }
    
    // MARK: - Adaptive Wait for Element (Phase 1 Improvement)
    
    /// Wait for an element with exponential backoff polling. More efficient than fixed-interval polling.
    /// Starts with short interval and increases up to max.
    func waitAdaptive(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = 10.0, initialDelay: TimeInterval = 0.1, maxDelay: TimeInterval = 1.0) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("waitAdaptive(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")
        
        let startTime = Date()
        var currentDelay = initialDelay
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
            
            // Sleep with exponential backoff
            Thread.sleep(forTimeInterval: currentDelay)
            currentDelay = min(currentDelay * 1.5, maxDelay)
        }
        
        return errorJSON("Element not found within \(timeout)s timeout after \(attempts) attempts")
    }
    
    // MARK: - Type Into Element (Phase 1 Improvement)
    
    /// Type text into an element found by role/title.
    /// First tries AXValue set (fastest), falls back to CGEvent typing.
    /// Can verify the text was entered.
    func typeIntoElement(role: String?, title: String?, value: String?, appBundleId: String?, text: String, verify: Bool = true) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("typeIntoElement(role: \(role ?? "nil"), title: \(title ?? "nil"), text: \(text.count) chars, verify: \(verify))")
        
        // Find the element
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
        
        guard let found = element else {
            return errorJSON("Element not found")
        }
        
        // Check for restricted roles
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXRoleAttribute as CFString, &roleRef) == .success,
           let elRole = roleRef as? String, Self.isRestricted(elRole) {
            return errorJSON("Cannot interact with \(elRole) — disabled in Accessibility Access")
        }
        
        // First try AXValue attribute (fastest)
        let setResult = AXUIElementSetAttributeValue(found, kAXValueAttribute as CFString, text as CFString)
        if setResult == .success {
            // Verify if requested
            if verify {
                Thread.sleep(forTimeInterval: 0.1)
                var valueRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(found, kAXValueAttribute as CFString, &valueRef) == .success,
                   let actualValue = valueRef as? String {
                    if actualValue == text {
                        return successJSON([
                            "method": "AXValue",
                            "verified": true,
                            "text": text
                        ])
                    }
                }
            } else {
                return successJSON([
                    "method": "AXValue",
                    "verified": false,
                    "text": text
                ])
            }
        }
        
        // Fall back to CGEvent typing
        // Get element position to click first
        var positionRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXPositionAttribute as CFString, &positionRef) == .success,
           let positionValue = positionRef,
           CFGetTypeID(positionValue) == AXValueGetTypeID() {
            var point = CGPoint.zero
            if AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) {
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
                
                // Click center of element to focus
                let centerX = point.x + width / 2
                let centerY = point.y + height / 2
                _ = clickAt(x: centerX, y: centerY, button: "left", clicks: 1)
                Thread.sleep(forTimeInterval: 0.1)
                
                // Type the text
                _ = typeText(text)
                
                return successJSON([
                    "method": "CGEvent",
                    "verified": false,
                    "text": text
                ])
            }
        }
        
        return errorJSON("Could not type into element - unable to get position")
    }
}