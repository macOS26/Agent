import AgentAudit
import Foundation
import AppKit
@preconcurrency import ApplicationServices

extension AccessibilityService {
    // MARK: - Perform Actions

    public func performAction(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, action: String) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "performAction(\(action)) role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil")")

        // Check settings - if disabled, block
        if Self.isRestricted(action) {
            return errorJSON("Action '\(action)' is disabled in Accessibility Settings. Enable it in Settings to allow this action.")
        }

        var element: AXUIElement?

        if let x = x, let y = y {
            let systemWide = AXUIElementCreateSystemWide()
            // Use timeout wrapper to prevent hangs on complex text views
            let copyResult = copyWithTimeout(systemWide: systemWide, x: x, y: y, timeout: Self.elementAtPositionTimeout)
            if copyResult.timedOut {
                return errorJSON("Element lookup timed out at (\(x), \(y)) - text view may be complex")
            }
            element = copyResult.element
        } else if let bundleId = appBundleId {
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

        let result = AXUIElementPerformAction(found, action as CFString)
        return result == .success ? successJSON(["message": "Action '\(action)' performed"]) : errorJSON("Action failed: \(result.rawValue)")
    }

    // MARK: - Input Simulation

    /// Type text using CGEvent keyboard simulation
    public func typeText(_ text: String, at x: CGFloat? = nil, y: CGFloat? = nil) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "typeText(\(text.count) chars) at x: \(x.map(String.init) ?? "nil"), y: \(y.map(String.init) ?? "nil")")

        // If coordinates provided, click first to focus
        if let x = x, let y = y {
            let clickResult = clickAt(x: x, y: y, button: "left", clicks: 1)
            if clickResult.contains("\"success\": false") {
                return clickResult
            }
            // Small delay to let the click register
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Use CGEvent to simulate keyboard input
        let source = CGEventSource(stateID: .combinedSessionState)

        for char in text {
            // Handle special characters
            switch char {
            case "\n":
                // Return key
                if let event = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true) {
                    event.post(tap: CGEventTapLocation.cgSessionEventTap)
                    event.type = .keyUp
                    event.post(tap: CGEventTapLocation.cgSessionEventTap)
                }
            case "\t":
                // Tab key
                if let event = CGEvent(keyboardEventSource: source, virtualKey: 0x30, keyDown: true) {
                    event.post(tap: CGEventTapLocation.cgSessionEventTap)
                    event.type = .keyUp
                    event.post(tap: CGEventTapLocation.cgSessionEventTap)
                }
            case Character(" "):
                // Space key
                if let event = CGEvent(keyboardEventSource: source, virtualKey: 0x31, keyDown: true) {
                    event.post(tap: CGEventTapLocation.cgSessionEventTap)
                    event.type = .keyUp
                    event.post(tap: CGEventTapLocation.cgSessionEventTap)
                }
            default:
                // Regular character - use CGEventKeyboardSetUnicodeString
                let characters = Array(char.unicodeScalars)
                let uniChars = characters.map { UniChar($0.value) }
                let length = uniChars.count

                if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                    uniChars.withUnsafeBytes { rawBufferPointer in
                        if let baseAddress = rawBufferPointer.baseAddress {
                            event.keyboardSetUnicodeString(stringLength: length, unicodeString: baseAddress.assumingMemoryBound(to: UniChar.self))
                        }
                    }
                    event.post(tap: CGEventTapLocation.cgSessionEventTap)
                    event.type = .keyUp
                    event.post(tap: CGEventTapLocation.cgSessionEventTap)
                }
            }
        }

        return successJSON(["message": "Typed \(text.count) characters"])
    }

    /// Simulate a mouse click at screen coordinates
    public func clickAt(x: CGFloat, y: CGFloat, button: String = "left", clicks: Int = 1) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "clickAt(x: \(x), y: \(y), button: \(button), clicks: \(clicks))")

        let source = CGEventSource(stateID: .combinedSessionState)

        // Map button name to CGMouseButton
        let cgButton: CGMouseButton
        switch button.lowercased() {
        case "left":
            cgButton = .left
        case "right":
            cgButton = .right
        case "middle":
            cgButton = .center
        default:
            cgButton = .left
        }

        // Mouse button event types
        let downEventType: CGEventType
        let upEventType: CGEventType
        switch cgButton {
        case .left:
            downEventType = .leftMouseDown
            upEventType = .leftMouseUp
        case .right:
            downEventType = .rightMouseDown
            upEventType = .rightMouseUp
        case .center:
            downEventType = .otherMouseDown
            upEventType = .otherMouseUp
        @unknown default:
            downEventType = .leftMouseDown
            upEventType = .leftMouseUp
        }

        // Move to position
        let moveEvent = CGEvent(source: source)
        moveEvent?.type = .mouseMoved
        moveEvent?.location = CGPoint(x: x, y: y)
        moveEvent?.post(tap: CGEventTapLocation.cgSessionEventTap)

        // Perform clicks
        for _ in 0..<clicks {
            // Mouse down
            if let downEvent = CGEvent(source: source) {
                downEvent.type = downEventType
                downEvent.location = CGPoint(x: x, y: y)
                downEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(cgButton.rawValue))
                downEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
            }

            // Mouse up
            if let upEvent = CGEvent(source: source) {
                upEvent.type = upEventType
                upEvent.location = CGPoint(x: x, y: y)
                upEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(cgButton.rawValue))
                upEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
            }
        }

        // For double-click, also set the click state
        if clicks == 2 {
            if let event = CGEvent(source: source) {
                event.type = downEventType
                event.location = CGPoint(x: x, y: y)
                event.setIntegerValueField(.mouseEventClickState, value: 2)
                event.post(tap: CGEventTapLocation.cgSessionEventTap)
            }
            if let event = CGEvent(source: source) {
                event.type = upEventType
                event.location = CGPoint(x: x, y: y)
                event.setIntegerValueField(.mouseEventClickState, value: 2)
                event.post(tap: CGEventTapLocation.cgSessionEventTap)
            }
        }

        return successJSON([
            "message": "\(clicks == 2 ? "Double-" : "")\(button) click at (\(x), \(y))",
            "x": x,
            "y": y,
            "button": button,
            "clicks": clicks
        ])
    }

    /// Scroll at a position
    public func scrollAt(x: CGFloat, y: CGFloat, deltaX: Int, deltaY: Int) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "scrollAt(x: \(x), y: \(y), deltaX: \(deltaX), deltaY: \(deltaY))")

        let source = CGEventSource(stateID: .combinedSessionState)

        // Move to position first
        let moveEvent = CGEvent(source: source)
        moveEvent?.type = .mouseMoved
        moveEvent?.location = CGPoint(x: x, y: y)
        moveEvent?.post(tap: CGEventTapLocation.cgSessionEventTap)

        // Scroll event (wheel1 = vertical, wheel2 = horizontal)
        if let scrollEvent = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: Int32(deltaY), wheel2: Int32(deltaX), wheel3: 0) {
            scrollEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
        }

        return successJSON([
            "message": "Scrolled (\(deltaX), \(deltaY)) at (\(x), \(y))",
            "x": x,
            "y": y,
            "deltaX": deltaX,
            "deltaY": deltaY
        ])
    }

    /// Press a key combination (e.g., Cmd+C, Cmd+V)
    public func pressKey(virtualKey: UInt16, modifiers: [String] = []) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "pressKey(\(virtualKey), modifiers: \(modifiers))")

        let source = CGEventSource(stateID: .combinedSessionState)

        // Map modifier names to flags
        var flags: CGEventFlags = []
        for mod in modifiers {
            switch mod.lowercased() {
            case "command", "cmd":
                flags.insert(.maskCommand)
            case "option", "alt":
                flags.insert(.maskAlternate)
            case "control", "ctrl":
                flags.insert(.maskControl)
            case "shift":
                flags.insert(.maskShift)
            default:
                break
            }
        }

        // Key down
        if let downEvent = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true) {
            downEvent.flags = flags
            downEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
        }

        // Key up
        if let upEvent = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) {
            upEvent.flags = flags
            upEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
        }

        return successJSON([
            "message": "Pressed key code \(virtualKey) with modifiers: \(modifiers)"
        ])
    }
}
