import Foundation
import AppKit
@preconcurrency import ApplicationServices

/// Element property access and manipulation for Accessibility API.
/// Provides tools for getting and setting accessibility properties.
enum AccessibilityProperties {
    
    // MARK: - Get Element Properties
    
    /// Get all properties of an element
    static func getElementProperties(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?) -> String {
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            return AccessibilityServiceHelpers.errorJSON("Accessibility permission required.")
        }
        AccessibilityServiceHelpers.logAudit("getElementProperties(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"))")
        
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
        
        return AccessibilityServiceHelpers.successJSON(getAllProperties(found))
    }
    
    /// Get all properties of an AXUIElement as a dictionary
    static func getAllProperties(_ element: AXUIElement) -> [String: Any] {
        var result: [String: Any] = [:]
        
        // Role
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String {
            result["role"] = role
        }
        
        // Subrole
        var subroleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef) == .success,
           let subrole = subroleRef as? String {
            result["subrole"] = subrole
        }
        
        // Role description
        var roleDescRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &roleDescRef) == .success,
           let roleDesc = roleDescRef as? String {
            result["roleDescription"] = roleDesc
        }
        
        // Title
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
           let title = titleRef as? String {
            result["title"] = title
        }
        
        // Value
        var valueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success {
            result["value"] = formatValue(valueRef)
        }
        
        // Description
        var descRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
           let desc = descRef as? String {
            result["description"] = desc
        }
        
        // Identifier
        var idRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &idRef) == .success,
           let id = idRef as? String {
            result["identifier"] = id
        }
        
        // Help text
        var helpRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXHelpAttribute as CFString, &helpRef) == .success,
           let help = helpRef as? String {
            result["help"] = help
        }
        
        // Enabled
        var enabledRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabledRef) == .success,
           let enabled = enabledRef as? Bool {
            result["enabled"] = enabled
        }
        
        // Focused
        var focusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXFocusedAttribute as CFString, &focusedRef) == .success,
           let focused = focusedRef as? Bool {
            result["focused"] = focused
        }
        
        // Position
        var posRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
           let posValue = posRef,
           CFGetTypeID(posValue) == AXValueGetTypeID() {
            var point = CGPoint.zero
            if AXValueGetValue(posValue as! AXValue, .cgPoint, &point) {
                result["position"] = ["x": point.x, "y": point.y]
            }
        }
        
        // Size
        var sizeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
           let sizeValue = sizeRef,
           CFGetTypeID(sizeValue) == AXValueGetTypeID() {
            var size = CGSize.zero
            if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                result["size"] = ["width": size.width, "height": size.height]
            }
        }
        
        return result
    }
    
    /// Format a CFTypeRef value for JSON serialization
    static func formatValue(_ value: CFTypeRef?) -> Any {
        guard let value = value else { return "" }
        
        if CFGetTypeID(value) == AXValueGetTypeID() {
            let axValue = value as! AXValue
            let type = AXValueGetType(axValue)
            
            switch type {
            case .cgPoint:
                var point = CGPoint.zero
                if AXValueGetValue(axValue, .cgPoint, &point) {
                    return ["x": point.x, "y": point.y]
                }
            case .cgSize:
                var size = CGSize.zero
                if AXValueGetValue(axValue, .cgSize, &size) {
                    return ["width": size.width, "height": size.height]
                }
            case .cgRect:
                var r = CGRect.zero
                if AXValueGetValue(axValue, .cgRect, &r) { return ["x": r.origin.x, "y": r.origin.y, "width": r.width, "height": r.height] }
            default: break
            }
        }
        return String(describing: value)
    }
    
    // MARK: - Create AXValue
    
    /// Create an AXValue from a key string and dictionary of values
    static func createAXValue(key: String, from dict: [String: CGFloat]) -> AXValue? {
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
}