import Foundation
import AppKit
@preconcurrency import ApplicationServices

/// Element finding utilities for Accessibility API.
/// Provides timeout-wrapped element lookup and hierarchy traversal.
enum AccessibilityElementFinder {
    
    // MARK: - Timeout Wrapper
    
    /// Timeout wrapper for AXUIElementCopyElementAtPosition
    /// Returns element if found, whether it timed out, and the AXError code
    static nonisolated func copyWithTimeout(systemWide: AXUIElement, x: CGFloat, y: CGFloat, timeout: TimeInterval) -> (element: AXUIElement?, timedOut: Bool, error: AXError) {
        // Use a thread-safe box for results
        final class Box: @unchecked Sendable {
            var result: AXError = .failure
            var element: AXUIElement?
        }
        let box = Box()
        let completed = DispatchSemaphore(value: 0)
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Copy systemWide in the calling context, pass primitives to closure
            var el: AXUIElement?
            box.result = AXUIElementCopyElementAtPosition(systemWide, Float(x), Float(y), &el)
            box.element = el
            completed.signal()
        }
        
        let waitResult = completed.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            return (element: nil, timedOut: true, error: .failure)
        }
        return (element: box.element, timedOut: false, error: box.result)
    }
    
    // MARK: - Element Finding
    
    /// Find element in app by role/title
    static func findElementInApp(pid: pid_t, role: String?, title: String?) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        return findElementInHierarchy(app, role: role, title: title, value: nil)
    }
    
    /// Find element globally (all apps) by role/title
    static func findElementGlobally(role: String?, title: String?) -> AXUIElement? {
        let apps = NSWorkspace.shared.runningApplications
        for app in apps {
            guard let appPID = app.processIdentifier as pid_t? else { continue }
            if let found = findElementInHierarchy(AXUIElementCreateApplication(appPID), role: role, title: title, value: nil) {
                return found
            }
        }
        return nil
    }
    
    /// Find element in app by role/title/value
    static func findElementInApp(pid: pid_t, role: String?, title: String?, value: String?) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        return findElementInHierarchy(app, role: role, title: title, value: value)
    }
    
    /// Find element globally (all apps) by role/title/value
    static func findElementGlobally(role: String?, title: String?, value: String?) -> AXUIElement? {
        let apps = NSWorkspace.shared.runningApplications
        for app in apps {
            guard let appPID = app.processIdentifier as pid_t? else { continue }
            if let found = findElementInHierarchy(AXUIElementCreateApplication(appPID), role: role, title: title, value: value) {
                return found
            }
        }
        return nil
    }
    
    /// Recursively search for element matching criteria
    static func findElementInHierarchy(_ parent: AXUIElement, role: String?, title: String?, value: String?, depth: Int = 0) -> AXUIElement? {
        // Check depth limit to prevent infinite recursion
        guard depth < 50 else { return nil }
        
        // Check if parent matches
        if let r = role {
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(parent, kAXRoleAttribute as CFString, &roleRef) == .success,
               let elRole = roleRef as? String, elRole == r {
                // Role matches, check title if specified
                if let t = title {
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(parent, kAXTitleAttribute as CFString, &titleRef) == .success,
                       let elTitle = titleRef as? String, elTitle.localizedCaseInsensitiveContains(t) {
                        // Title matches, check value if specified
                        if let v = value {
                            var valueRef: CFTypeRef?
                            if AXUIElementCopyAttributeValue(parent, kAXValueAttribute as CFString, &valueRef) == .success,
                               let elValue = valueRef as? String, elValue.localizedCaseInsensitiveContains(v) {
                                return parent
                            }
                        } else {
                            return parent
                        }
                    }
                } else {
                    // No title specified, check value if specified
                    if let v = value {
                        var valueRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(parent, kAXValueAttribute as CFString, &valueRef) == .success,
                           let elValue = valueRef as? String, elValue.localizedCaseInsensitiveContains(v) {
                            return parent
                        }
                    } else {
                        return parent
                    }
                }
            }
        } else if let t = title {
            // No role specified, search by title
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(parent, kAXTitleAttribute as CFString, &titleRef) == .success,
               let elTitle = titleRef as? String, elTitle.localizedCaseInsensitiveContains(t) {
                if let v = value {
                    var valueRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(parent, kAXValueAttribute as CFString, &valueRef) == .success,
                       let elValue = valueRef as? String, elValue.localizedCaseInsensitiveContains(v) {
                        return parent
                    }
                } else {
                    return parent
                }
            }
        } else if let v = value {
            // No role or title specified, search by value
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(parent, kAXValueAttribute as CFString, &valueRef) == .success,
               let elValue = valueRef as? String, elValue.localizedCaseInsensitiveContains(v) {
                return parent
            }
        }
        
        // Recursively search children
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
}