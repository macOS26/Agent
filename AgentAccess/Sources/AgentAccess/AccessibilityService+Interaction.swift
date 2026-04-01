import AgentAudit
import AXorcist
import Foundation
import AppKit
@preconcurrency import ApplicationServices

extension AccessibilityService {
    // MARK: - Set Properties

    @MainActor
    public func setProperties(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, properties: [String: Any]) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "setProperties(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), properties: \(properties.keys)")

        var element: Element?
        if let x = x, let y = y {
            element = Element.elementAtPoint(CGPoint(x: x, y: y))
        } else {
            element = findAXElement(role: role, title: title, value: value, appBundleId: appBundleId)
        }

        guard let found = element else {
            return errorJSON("Element not found")
        }
        if let elRole = found.role(), Self.isRestricted(elRole) {
            return errorJSON("Cannot interact with \(elRole) — disabled in Accessibility Access")
        }

        var results: [String: Any] = [:]
        var successCount = 0

        for (key, val) in properties {
            var success = false
            if key == "AXPosition", let dict = val as? [String: CGFloat],
               let px = dict["x"], let py = dict["y"] {
                success = found.setPosition(CGPoint(x: px, y: py)) == .success
            } else if key == "AXSize", let dict = val as? [String: CGFloat],
                      let w = dict["width"], let h = dict["height"] {
                success = found.setSize(CGSize(width: w, height: h)) == .success
            } else if let s = val as? String {
                success = found.setValue(s, forAttribute: key)
            } else if let b = val as? Bool {
                success = found.setValue(b, forAttribute: key)
            } else if let i = val as? Int {
                success = found.setValue(i, forAttribute: key)
            } else {
                success = found.setValue(String(describing: val), forAttribute: key)
            }
            results[key] = success ? "set" : "failed"
            if success { successCount += 1 }
        }

        return successJSON(["message": "Set \(successCount)/\(properties.count) properties", "results": results])
    }

    // MARK: - Find Element

    @MainActor
    public func findElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = automationFinishTimeout) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "findElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if let found = findAXElement(role: role, title: title, value: value, appBundleId: appBundleId) {
                return successJSON(elementProperties(found))
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return errorJSON("Element not found")
    }

    // MARK: - Get Focused Element

    @MainActor
    public func getFocusedElement(appBundleId: String? = nil) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "getFocusedElement(app: \(appBundleId ?? "nil"))")

        // Use AXorcist's focusedApplication or system-wide element
        let root: Element
        if let bundleId = appBundleId,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
           let appEl = Element.application(for: app) {
            root = appEl
        } else {
            root = Element.systemWide()
        }

        // Use AXorcist's focusedApplicationElement to get focused element
        if let focusedApp = root.focusedApplicationElement() {
            // Get the focused UI element from the focused app
            if let focusedChild = focusedApp.children()?.first(where: { $0.isFocused() == true }) {
                return successJSON(elementProperties(focusedChild))
            }
            return successJSON(elementProperties(focusedApp))
        }

        return errorJSON("No focused element found")
    }

    // MARK: - Get Children

    @MainActor
    public func getChildren(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, depth: Int = 3) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "getChildren(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), depth: \(depth))")

        var element: Element?
        if let x = x, let y = y {
            element = Element.elementAtPoint(CGPoint(x: x, y: y))
        } else {
            element = findAXElement(role: role, title: title, value: value, appBundleId: appBundleId)
        }

        guard let found = element else { return errorJSON("Element not found") }
        guard let children = found.children() else { return errorJSON("Element has no children") }

        var results: [[String: Any]] = []
        for child in children {
            results.append(elementProperties(child))
        }
        return successJSON(["count": results.count, "children": results])
    }

    // MARK: - Drag (AXorcist InputDriver)

    @MainActor
    public func drag(fromX: CGFloat, fromY: CGFloat, toX: CGFloat, toY: CGFloat, button: String = "left") -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "drag(from: (\(fromX), \(fromY)), to: (\(toX), \(toY)), button: \(button))")

        let mouseButton: MouseButton = button.lowercased() == "right" ? .right : .left
        do {
            try InputDriver.drag(from: CGPoint(x: fromX, y: fromY), to: CGPoint(x: toX, y: toY), button: mouseButton, steps: 10)
            return successJSON(["message": "Dragged from (\(fromX), \(fromY)) to (\(toX), \(toY))", "fromX": fromX, "fromY": fromY, "toX": toX, "toY": toY, "button": button])
        } catch {
            return errorJSON("Drag failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Wait For Element

    @MainActor
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
            if let found = findAXElement(role: role, title: title, value: value, appBundleId: appBundleId) {
                let elapsed = Date().timeIntervalSince(startTime)
                return successJSON(["message": "Element found", "attempts": attempts, "elapsed": String(format: "%.2f", elapsed), "properties": elementProperties(found)])
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        return errorJSON("Element not found within \(timeout)s timeout after \(attempts) attempts")
    }

    // MARK: - Show Menu

    @MainActor
    public func showMenu(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "showMenu(role: \(role ?? "nil"), title: \(title ?? "nil"))")

        var element: Element?
        if let x = x, let y = y {
            element = Element.elementAtPoint(CGPoint(x: x, y: y))
        } else {
            element = findAXElement(role: role, title: title, value: value, appBundleId: appBundleId)
        }
        guard let found = element else { return errorJSON("Element not found") }
        if let elRole = found.role(), Self.isRestricted(elRole) {
            return errorJSON("Cannot interact with \(elRole) — disabled in Accessibility Access")
        }

        // AXorcist: try showMenu action
        if found.isActionSupported("AXShowMenu") {
            do {
                try found.performAction("AXShowMenu")
                return successJSON(["message": "Menu shown"])
            } catch {
                return errorJSON("AXShowMenu failed: \(error.localizedDescription)")
            }
        }

        // AXorcist: fallback right-click at element center
        if let frame = found.frame() {
            do {
                try InputDriver.click(at: CGPoint(x: frame.midX, y: frame.midY), button: .right, count: 1)
                return successJSON(["message": "Right-clicked at element center"])
            } catch {
                return errorJSON("Right-click failed: \(error.localizedDescription)")
            }
        }
        return errorJSON("Element does not support showing menu and could not determine position")
    }

    // MARK: - Smart Element Click (AXorcist Element.click)

    @MainActor
    public func clickElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = automationFinishTimeout, verify: Bool = false) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "clickElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")

        let startTime = Date()
        var element: Element?
        while Date().timeIntervalSince(startTime) < timeout {
            element = findAXElement(role: role, title: title, value: value, appBundleId: appBundleId)
            if element != nil { break }
            Thread.sleep(forTimeInterval: 0.1)
        }

        guard let found = element else {
            return errorJSON("Element not found within \(timeout)s timeout")
        }
        if let elRole = found.role(), Self.isRestricted(elRole) {
            return errorJSON("Cannot interact with \(elRole) — disabled in Accessibility Access")
        }

        // AXorcist: wait for enabled
        let enableStart = Date()
        let enableTimeout: TimeInterval = 5.0
        while found.isEnabled() == false, Date().timeIntervalSince(enableStart) < enableTimeout {
            Thread.sleep(forTimeInterval: 0.2)
        }
        if found.isEnabled() == false {
            return errorJSON("Element not enabled after \(enableTimeout)s — may still be loading")
        }

        // AXorcist: prefer AXPress (works without frame), fall back to Element.click()
        if found.isActionSupported("AXPress") {
            do {
                try found.performAction("AXPress")
                return successJSON(["message": "Clicked element (AXPress)", "role": found.role() ?? "Unknown", "title": found.title() ?? "", "description": found.descriptionText() ?? ""])
            } catch {
                // Fall through to Element.click()
            }
        }
        do {
            try found.click()
            return successJSON(["message": "Clicked element", "role": found.role() ?? "Unknown", "title": found.title() ?? "", "description": found.descriptionText() ?? ""])
        } catch {
            return errorJSON("Click failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Adaptive Wait for Element

    @MainActor
    public func waitForElementAdaptive(
        role: String?, title: String?, value: String?, appBundleId: String?,
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
        while Date().timeIntervalSince(startTime) < timeout {
            attempts += 1
            if let found = findAXElement(role: role, title: title, value: value, appBundleId: appBundleId) {
                let elapsed = Date().timeIntervalSince(startTime)
                var props = elementProperties(found)
                props["found_after_attempts"] = attempts
                props["elapsed_seconds"] = String(format: "%.2f", elapsed)
                return successJSON(props)
            }
            Thread.sleep(forTimeInterval: currentDelay)
            currentDelay = min(currentDelay * multiplier, maxDelay)
        }
        return errorJSON("Element not found within \(timeout)s timeout after \(attempts) attempts (adaptive polling)")
    }

    // MARK: - Verification Helpers

    @MainActor
    public func captureVerificationScreenshot(action: String, role: String?, title: String?, appBundleId: String?) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        let screenshotResult = captureAllWindows()
        var elementStatus = "not_verified"
        if (role ?? title) != nil {
            let findResult = findElement(role: role, title: title, value: nil, appBundleId: appBundleId, timeout: 1.0)
            elementStatus = findResult.contains("\"success\": true") ? "verified_present" : "not_found_after_action"
        }
        return successJSON(["action": action, "element_status": elementStatus, "screenshot": screenshotResult])
    }

    // MARK: - Type Text Into Element (AXorcist Element.typeText)

    @MainActor
    public func typeTextIntoElement(role: String?, title: String?, text: String, appBundleId: String?, verify: Bool = true) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "typeTextIntoElement(role: \(role ?? "nil"), title: \(title ?? "nil"), text: \(text.count) chars)")

        guard let found = findAXElement(role: role, title: title, value: nil, appBundleId: appBundleId) else {
            return errorJSON("Element not found for typing")
        }

        // AXorcist: try Element.setValue first (fastest)
        if found.setValue(text, forAttribute: "AXValue") {
            return successJSON(["message": "Text set via AXValue", "method": "element_setValue", "text_length": text.count])
        }

        // AXorcist: fallback to Element.typeText (clicks to focus + types)
        do {
            try found.typeText(text)
            return successJSON(["message": "Typed \(text.count) characters", "method": "element_typeText", "text_length": text.count])
        } catch {
            return errorJSON("Type failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Legacy Compatibility (return AXorcist Element.underlyingElement)

    @MainActor
    public func findElementInApp(pid: pid_t, role: String?, title: String?, value: String?) -> AXUIElement? {
        guard let appElement = Element.application(for: pid) else { return nil }
        return searchInElement(appElement, role: role, title: title, value: value)?.underlyingElement
    }

    @MainActor
    public func findElementGlobally(role: String?, title: String?, value: String?) -> AXUIElement? {
        return findAXElement(role: role, title: title, value: value, appBundleId: nil)?.underlyingElement
    }

    @MainActor
    private func searchInElement(_ root: Element, role: String?, title: String?, value: String?) -> Element? {
        let results = root.findElements(role: role, title: title, label: nil, value: value, identifier: nil, maxDepth: 100)
        if results.isEmpty, let title = title {
            var options = ElementSearchOptions()
            options.maxDepth = 100
            options.caseInsensitive = true
            if let role = role { options.includeRoles = [role] }
            return root.findElement(matching: title, options: options)
        }
        return results.first
    }
}
