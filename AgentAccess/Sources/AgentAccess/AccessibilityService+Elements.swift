import AgentAudit
import Foundation
import AppKit
@preconcurrency import ApplicationServices

extension AccessibilityService {
    // MARK: - Element Inspection

    /// Timeout for AXUIElementCopyElementAtPosition to prevent hangs on complex text views
    public static let elementAtPositionTimeout: TimeInterval = 2.0

    public func inspectElementAt(x: CGFloat, y: CGFloat, depth: Int = 3) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "inspectElementAt(x: \(x), y: \(y), depth: \(depth))")

        let point = CGPoint(x: x, y: y)
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?

        // Run AXUIElementCopyElementAtPosition with timeout to prevent hangs on text views
        // This can hang when computing accessibility bounds for complex text layouts
        let copyResult = copyWithTimeout(systemWide: systemWide, x: x, y: y, timeout: Self.elementAtPositionTimeout)
        element = copyResult.element

        if copyResult.timedOut {
            return errorJSON("Accessibility inspection timed out at (\(x), \(y)) - text view may be complex")
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

        return errorJSON("No element found at (\(x), \(y))")
    }

    /// Timeout wrapper for AXUIElementCopyElementAtPosition
    /// Returns element if found, whether it timed out, and the AXError code
    nonisolated func copyWithTimeout(systemWide: AXUIElement, x: CGFloat, y: CGFloat, timeout: TimeInterval) -> (element: AXUIElement?, timedOut: Bool, error: AXError) {
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

    public func getElementProperties(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "getElementProperties(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"))")

        if let x = x, let y = y {
            return inspectElementAt(x: x, y: y, depth: 2)
        }

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

    /// Max recursion depth for AX hierarchy traversal — prevents stack overflow
    /// from deeply nested or circular element trees (browsers, Finder, etc.)
    public static let maxHierarchyDepth = 100

    private func findElementInHierarchy(_ parent: AXUIElement, role: String?, title: String?, depth: Int = 0) -> AXUIElement? {
        guard depth < Self.maxHierarchyDepth else { return nil }

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
                if let found = findElementInHierarchy(child, role: role, title: title, depth: depth + 1) {
                    return found
                }
            }
        }
        return nil
    }

    public func getAllProperties(_ element: AXUIElement) -> [String: Any] {
        var result: [String: Any] = [:]
        let attrs: [String] = [
            kAXRoleAttribute, kAXRoleDescriptionAttribute, kAXSubroleAttribute, kAXTitleAttribute,
            kAXValueAttribute, kAXDescriptionAttribute, kAXHelpAttribute,
            kAXEnabledAttribute, kAXFocusedAttribute, kAXSelectedAttribute,
            kAXPositionAttribute, kAXSizeAttribute, kAXIdentifierAttribute,
            "AXURL", "AXDOMIdentifier", "AXDOMClassList", "AXPlaceholderValue"
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
            let av = unsafeDowncast(value, to: AXValue.self)
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

    // MARK: - Web Content Scanning

    /// Scan web content in a browser window. Finds links, inputs, buttons, and text.
    /// Works with Safari and Chrome AXWebArea elements.
    public func scanWebContent(appBundleId: String? = nil, maxDepth: Int = 10) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "scanWebContent(app: \(appBundleId ?? "frontmost"), depth: \(maxDepth))")

        let pid: pid_t
        if let bid = appBundleId,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bid).first {
            pid = app.processIdentifier
        } else if let front = NSWorkspace.shared.frontmostApplication {
            pid = front.processIdentifier
        } else {
            return errorJSON("No app found")
        }

        let appElement = AXUIElementCreateApplication(pid)
        var webElements: [[String: Any]] = []

        // Find AXWebArea in the element tree
        func findWebArea(_ element: AXUIElement, depth: Int) {
            guard depth > 0 else { return }
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
            let role = roleRef as? String ?? ""

            if role == "AXWebArea" {
                // Found web content — scan its children
                scanWebChildren(element, depth: maxDepth, into: &webElements)
                return
            }
            // Keep searching
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                for child in children { findWebArea(child, depth: depth - 1) }
            }
        }

        findWebArea(appElement, depth: 8)

        if webElements.isEmpty {
            return errorJSON("No web content found. Is a browser window open?")
        }
        return successJSON(["elements": webElements, "count": webElements.count])
    }

    /// Recursively scan web content children for interactive/visible elements.
    private func scanWebChildren(_ element: AXUIElement, depth: Int, into results: inout [[String: Any]]) {
        guard depth > 0, results.count < 200 else { return }

        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        // Collect interesting elements
        let interactiveRoles: Set<String> = [
            "AXLink", "AXButton", "AXTextField", "AXTextArea", "AXCheckBox",
            "AXRadioButton", "AXPopUpButton", "AXComboBox", "AXSlider",
            "AXImage", "AXHeading", "AXStaticText", "AXGroup"
        ]

        if interactiveRoles.contains(role) {
            var info: [String: Any] = ["role": role]

            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
               let title = titleRef as? String, !title.isEmpty {
                info["title"] = String(title.prefix(200))
            }

            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success {
                if let val = valueRef as? String, !val.isEmpty {
                    info["value"] = String(val.prefix(200))
                }
            }

            var descRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
               let desc = descRef as? String, !desc.isEmpty {
                info["description"] = String(desc.prefix(200))
            }

            var urlRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, "AXURL" as CFString, &urlRef) == .success,
               let url = urlRef as? String ?? (urlRef as? URL)?.absoluteString {
                info["url"] = String(url.prefix(500))
            }

            var domIdRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, "AXDOMIdentifier" as CFString, &domIdRef) == .success,
               let domId = domIdRef as? String, !domId.isEmpty {
                info["domId"] = domId
            }

            // Get position
            var posRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success {
                let pos = posRef as! AXValue
                var point = CGPoint.zero
                AXValueGetValue(pos, .cgPoint, &point)
                info["x"] = Int(point.x)
                info["y"] = Int(point.y)
            }

            // Skip empty static text (whitespace, line breaks)
            if role == "AXStaticText" {
                let text = info["value"] as? String ?? info["title"] as? String ?? ""
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { /* skip */ }
                else { results.append(info) }
            } else {
                results.append(info)
            }
        }

        // Recurse into children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                scanWebChildren(child, depth: depth - 1, into: &results)
            }
        }
    }
}
