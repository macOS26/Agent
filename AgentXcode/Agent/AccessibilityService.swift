import Foundation
import AppKit
import ApplicationServices

/// Accessibility automation service for interacting with UI elements via the Accessibility API.
/// Provides tools for window listing, element inspection, and UI interaction.
final class AccessibilityService: @unchecked Sendable {
    static let shared = AccessibilityService()
    
    // MARK: - Security
    
    /// Check if the app has Accessibility permissions
    static func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Request Accessibility permissions (shows system prompt)
    static func requestAccessibilityPermission() -> Bool {
        // kAXTrustedCheckOptionPrompt is a CFString constant - use the raw string value
        // The constant is defined in AXAttributeConstants.h as "AXTrustedCheckOptionPrompt"
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options: [CFString: Bool] = [promptKey: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// Actions that are blocked by default for safety
    private static let blockedActions: Set<String> = [
        "AXConfirm", "AXPress", "AXShowMenu", "AXIncrement", "AXDecrement",
        "AXActivate", "AXCancel", "AXExpand", "AXCollapse"
    ]
    
    /// Roles that are blocked from interaction (password fields, secure text)
    private static let blockedRoles: Set<String> = [
        "AXSecureTextField", "AXPasswordField", "AXSecureText"
    ]
    
    // MARK: - Window Listing
    
    /// List all visible windows from all applications
    func listWindows(limit: Int = 50) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        
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
            let appName = getProcessName(pid: ownerPID) ?? ownerName
            
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
        
        return successJSON(["windows": results, "count": results.count])
    }
    
    // MARK: - Element Inspection
    
    func inspectElementAt(x: CGFloat, y: CGFloat, depth: Int = 3) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        
        let point = CGPoint(x: x, y: y)
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        
        if AXUIElementCopyElementAtPosition(systemWide, Float(x), Float(y), &element) == .success, let el = element {
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
        
        return errorJSON("No element found at (\(x), \(y))")
    }
    
    private func inspectElement(_ element: AXUIElement, depth: Int, indent: Int = 0) -> String {
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
            let truncated = String(value.prefix(100))
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
    
    private func getApplicationsAtPoint(_ point: CGPoint) -> [pid_t] {
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
    
    // MARK: - Get Element Properties
    
    func getElementProperties(role: String?, title: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        
        if let x = x, let y = y {
            return inspectElementAt(x: x, y: y, depth: 2)
        }
        
        var element: AXUIElement?
        
        if let bundleId = appBundleId {
            let apps = NSWorkspace.shared.runningApplications
            if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
               let pid = app.processIdentifier as pid_t? {
                element = findElementInApp(pid: pid, role: role, title: title)
            }
        } else {
            element = findElementGlobally(role: role, title: title)
        }
        
        guard let found = element else {
            return errorJSON("Element not found")
        }
        
        return successJSON(getAllProperties(found))
    }
    
    private func findElementInApp(pid: pid_t, role: String?, title: String?) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        return findElementInHierarchy(app, role: role, title: title)
    }
    
    private func findElementGlobally(role: String?, title: String?) -> AXUIElement? {
        for app in NSWorkspace.shared.runningApplications {
            guard let pid = app.processIdentifier as pid_t? else { continue }
            if let found = findElementInApp(pid: pid, role: role, title: title) {
                return found
            }
        }
        return nil
    }
    
    private func findElementInHierarchy(_ parent: AXUIElement, role: String?, title: String?) -> AXUIElement? {
        if let role = role {
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(parent, kAXRoleAttribute as CFString, &roleRef) == .success,
               let elementRole = roleRef as? String, elementRole == role {
                if let title = title {
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(parent, kAXTitleAttribute as CFString, &titleRef) == .success,
                       let elementTitle = titleRef as? String, elementTitle.contains(title) {
                        return parent
                    }
                } else {
                    return parent
                }
            }
        }
        
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findElementInHierarchy(child, role: role, title: title) {
                    return found
                }
            }
        }
        return nil
    }
    
    private func getAllProperties(_ element: AXUIElement) -> [String: Any] {
        var result: [String: Any] = [:]
        let attrs: [String] = [
            kAXRoleAttribute, kAXRoleDescriptionAttribute, kAXTitleAttribute,
            kAXValueAttribute, kAXDescriptionAttribute, kAXHelpAttribute,
            kAXEnabledAttribute, kAXFocusedAttribute, kAXSelectedAttribute,
            kAXPositionAttribute, kAXSizeAttribute, kAXIdentifierAttribute
        ]
        for attr in attrs {
            var val: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attr as CFString, &val) == .success {
                result[attr] = formatValue(val)
            }
        }
        return result
    }
    
    private func formatValue(_ value: CFTypeRef?) -> Any {
        guard let value = value else { return NSNull() }
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n }
        if CFGetTypeID(value) == AXValueGetTypeID() {
            // swiftlint:disable:next force_cast
            let av = value as! AXValue
            switch AXValueGetType(av) {
            case .cgPoint:
                var pt = CGPoint.zero
                if AXValueGetValue(av, .cgPoint, &pt) { return ["x": pt.x, "y": pt.y] }
            case .cgSize:
                var sz = CGSize.zero
                if AXValueGetValue(av, .cgSize, &sz) { return ["width": sz.width, "height": sz.height] }
            case .cgRect:
                var r = CGRect.zero
                if AXValueGetValue(av, .cgRect, &r) { return ["x": r.origin.x, "y": r.origin.y, "width": r.width, "height": r.height] }
            default: break
            }
        }
        return String(describing: value)
    }
    
    // MARK: - Perform Actions
    
    func performAction(role: String?, title: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, action: String, allowWrites: Bool = false) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        
        if !allowWrites && Self.blockedActions.contains(action) {
            return errorJSON("Action '\(action)' blocked. Set allowWrites=true.")
        }
        
        var element: AXUIElement?
        
        if let x = x, let y = y {
            let systemWide = AXUIElementCreateSystemWide()
            _ = AXUIElementCopyElementAtPosition(systemWide, Float(x), Float(y), &element)
        } else if let bundleId = appBundleId {
            let apps = NSWorkspace.shared.runningApplications
            if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
               let pid = app.processIdentifier as pid_t? {
                element = findElementInApp(pid: pid, role: role, title: title)
            }
        } else {
            element = findElementGlobally(role: role, title: title)
        }
        
        guard let found = element else {
            return errorJSON("Element not found")
        }
        
        // Check for blocked roles
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXRoleAttribute as CFString, &roleRef) == .success,
           let elRole = roleRef as? String, Self.blockedRoles.contains(elRole) {
            return errorJSON("Cannot interact with \(elRole) elements")
        }
        
        let result = AXUIElementPerformAction(found, action as CFString)
        return result == .success ? successJSON(["message": "Action '\(action)' performed"]) : errorJSON("Action failed: \(result.rawValue)")
    }
    
    // MARK: - Helpers
    
    private func getProcessName(pid: pid_t) -> String? {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        return app.localizedName ?? app.bundleIdentifier
    }
    
    private func successJSON(_ data: Any) -> String {
        if let d = try? JSONSerialization.data(withJSONObject: ["success": true, "data": data], options: .prettyPrinted),
           let s = String(data: d, encoding: .utf8) { return s }
        return "{\"success\": true}"
    }
    
    private func errorJSON(_ msg: String) -> String {
        return "{\"success\": false, \"error\": \"\(msg.replacingOccurrences(of: "\"", with: "\\\""))\"}"
    }
}