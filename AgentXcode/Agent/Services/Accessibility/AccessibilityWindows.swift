import Foundation
import AppKit
@preconcurrency import ApplicationServices

/// Window listing and element inspection utilities for Accessibility API.
/// Provides tools for discovering windows and inspecting UI elements.
enum AccessibilityWindows {
    
    // MARK: - Window Listing
    
    /// List all visible windows from all applications
    static func listWindows(limit: Int = 50) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("listWindows(limit: \(limit))")

        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        
        var results: [[String: Any]] = []
        for (index, window) in windows.enumerated() {
            guard index < limit else { break }
            guard let windowID = window[kCGWindowNumber as String] as? Int,
                  let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer >= 0 else { continue }
            
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let windowName = window[kCGWindowName as String] as? String ?? ""
            let bounds = window[kCGWindowBounds as String] as? [String: CGFloat]
            let appName = AccessibilityServiceHelpers.getProcessName(pid: ownerPID) ?? ownerName
            
            var windowInfo: [String: Any] = [:]
            windowInfo["windowId"] = windowID
            windowInfo["ownerPID"] = Int(ownerPID)
            windowInfo["ownerName"] = appName
            windowInfo["windowName"] = windowName
            windowInfo["layer"] = layer
            
            var boundsInfo: [String: CGFloat] = [:]
            boundsInfo["x"] = bounds?["X"] ?? 0
            boundsInfo["y"] = bounds?["Y"] ?? 0
            boundsInfo["width"] = bounds?["Width"] ?? 0
            boundsInfo["height"] = bounds?["Height"] ?? 0
            windowInfo["bounds"] = boundsInfo
            
            results.append(windowInfo)
        }
        
        return AccessibilityServiceHelpers.successJSON(["windows": results, "count": results.count])
    }
    
    // MARK: - Element Inspection
    
    /// Timeout for AXUIElementCopyElementAtPosition to prevent hangs on complex text views
    static let elementAtPositionTimeout: TimeInterval = 2.0
    
    static func inspectElementAt(x: CGFloat, y: CGFloat, depth: Int = 3) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("inspectElementAt(x: \(x), y: \(y), depth: \(depth))")

        let point = CGPoint(x: x, y: y)
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        
        // Run AXUIElementCopyElementAtPosition with timeout to prevent hangs on text views
        let copyResult = AccessibilityElementFinder.copyWithTimeout(systemWide: systemWide, x: x, y: y, timeout: elementAtPositionTimeout)
        element = copyResult.element
        
        if copyResult.timedOut {
            return AccessibilityServiceHelpers.errorJSON("Accessibility inspection timed out at (\(x), \(y)) - text view may be complex")
        }
        
        if copyResult.error == .success, let el = element {
            return inspectElement(el, depth: depth)
        }
        
        // Fallback: find windows at point
        let apps = getApplicationsAtPoint(point)
        for appPID in apps {
            let app = AXUIElementCreateApplication(appPID)
            var windowsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let windows = windowsRef as? [AXUIElement] {
                for window in windows {
                    let result = inspectElement(window, depth: depth)
                    return result
                }
            }
        }
        
        return AccessibilityServiceHelpers.errorJSON("No element found at (\(x), \(y))")
    }
    
    static func inspectElement(_ element: AXUIElement, depth: Int, indent: Int = 0) -> String {
        var result = String(repeating: "  ", count: indent)
        
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        result += (roleRef as? String) ?? "Unknown"
        
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        if let title = titleRef as? String, !title.isEmpty {
            result += " \"\(title)\""
        }
        
        var valueRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
        if let value = valueRef as? String, !value.isEmpty {
            let truncated = String(value.prefix(1500))
            result += " [\(truncated)\(truncated.count < value.count ? "..." : "")]"
        }
        
        result += "\n"
        
        if depth > 0 {
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                for child in children {
                    result += inspectElement(child, depth: depth - 1, indent: indent + 1)
                }
            }
        }
        
        return result
    }
    
    static func getApplicationsAtPoint(_ point: CGPoint) -> [pid_t] {
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        var pids: [pid_t] = []
        for window in windowList {
            guard let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let w = bounds["Width"], let h = bounds["Height"],
                  let pid = window[kCGWindowOwnerPID as String] as? pid_t else { continue }
            if CGRect(x: x, y: y, width: w, height: h).contains(point) {
                pids.append(pid)
            }
        }
        return pids
    }
}