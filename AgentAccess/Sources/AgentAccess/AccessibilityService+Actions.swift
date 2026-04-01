import AgentAudit
import AXorcist
import Foundation
import AppKit
@preconcurrency import ApplicationServices

extension AccessibilityService {
    // MARK: - Perform Actions

    @MainActor
    public func performAction(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, action: String) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "performAction(\(action)) role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil")")

        if Self.isRestricted(action) {
            return errorJSON("Action '\(action)' is disabled in Accessibility Settings. Enable it in Settings to allow this action.")
        }

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

        do {
            try found.performAction(action)
            return successJSON(["message": "Action '\(action)' performed"])
        } catch {
            return errorJSON("Action failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Input Simulation via AXorcist InputDriver

    @MainActor
    public func typeText(_ text: String, at x: CGFloat? = nil, y: CGFloat? = nil) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "typeText(\(text.count) chars) at x: \(x.map(String.init) ?? "nil"), y: \(y.map(String.init) ?? "nil")")

        // If coordinates provided, click first to focus
        if let x = x, let y = y {
            do {
                try InputDriver.click(at: CGPoint(x: x, y: y))
                Thread.sleep(forTimeInterval: 0.1)
            } catch {
                return errorJSON("Click failed: \(error.localizedDescription)")
            }
        }

        do {
            try InputDriver.type(text)
            return successJSON(["message": "Typed \(text.count) characters"])
        } catch {
            return errorJSON("Type failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    public func clickAt(x: CGFloat, y: CGFloat, button: String = "left", clicks: Int = 1) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "clickAt(x: \(x), y: \(y), button: \(button), clicks: \(clicks))")

        let mouseButton: MouseButton
        switch button.lowercased() {
        case "right": mouseButton = .right
        case "middle": mouseButton = .middle
        default: mouseButton = .left
        }

        do {
            try InputDriver.click(at: CGPoint(x: x, y: y), button: mouseButton, count: clicks)
            return successJSON([
                "message": "\(clicks == 2 ? "Double-" : "")\(button) click at (\(x), \(y))",
                "x": x, "y": y, "button": button, "clicks": clicks
            ])
        } catch {
            return errorJSON("Click failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    public func scrollAt(x: CGFloat, y: CGFloat, deltaX: Int, deltaY: Int) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "scrollAt(x: \(x), y: \(y), deltaX: \(deltaX), deltaY: \(deltaY))")

        do {
            try InputDriver.scroll(deltaX: Double(deltaX), deltaY: Double(deltaY), at: CGPoint(x: x, y: y))
            return successJSON([
                "message": "Scrolled (\(deltaX), \(deltaY)) at (\(x), \(y))",
                "x": x, "y": y, "deltaX": deltaX, "deltaY": deltaY
            ])
        } catch {
            return errorJSON("Scroll failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    public func pressKey(virtualKey: UInt16, modifiers: [String] = []) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "pressKey(\(virtualKey), modifiers: \(modifiers))")

        do {
            try InputDriver.hotkey(keys: modifiers + [String(virtualKey)], holdDuration: 0.1)
            return successJSON(["message": "Pressed key code \(virtualKey) with modifiers: \(modifiers)"])
        } catch {
            return errorJSON("Key press failed: \(error.localizedDescription)")
        }
    }
}
