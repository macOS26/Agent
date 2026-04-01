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

        // If coordinates given, use AXorcist Element.elementAtPoint + performAction
        if let x = x, let y = y {
            guard let found = Element.elementAtPoint(CGPoint(x: x, y: y)) else {
                return errorJSON("No element at (\(x), \(y))")
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

        // Use AXorcist PerformActionCommand — atomic find + action
        var criteria: [Criterion] = []
        if let role = role { criteria.append(Criterion(attribute: "AXRole", value: role)) }
        if let title = title { criteria.append(Criterion(attribute: "AXTitle", value: title, matchType: .contains)) }
        if let value = value { criteria.append(Criterion(attribute: "AXValue", value: value, matchType: .contains)) }

        if criteria.isEmpty {
            return errorJSON("No search criteria — provide role, title, value, or coordinates")
        }

        let locator = Locator(matchAll: true, criteria: criteria)
        let cmd = PerformActionCommand(appIdentifier: appBundleId, locator: locator, action: action, maxDepthForSearch: 100)
        let envelope = AXCommandEnvelope(commandID: UUID().uuidString, command: .performAction(cmd))
        let response = AXorcist.shared.runCommand(envelope)

        switch response {
        case .success:
            return successJSON(["message": "Action '\(action)' performed"])
        case .error(let message, _, _):
            return errorJSON("Action failed: \(message)")
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
