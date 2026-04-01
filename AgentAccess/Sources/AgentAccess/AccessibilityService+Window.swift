import AgentAudit
import Foundation
import AppKit
@preconcurrency import ApplicationServices

extension AccessibilityService {
    // MARK: - Frontmost Window

    /// Get the CGWindowID of the frontmost window for targeted screenshots.
    public static func frontmostWindowID() -> UInt32? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == pid,
                  let windowID = window[kCGWindowNumber as String] as? UInt32,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue }
            return windowID
        }
        return nil
    }

    // MARK: - Highlight Element (Phase 2 Feature)

    /// Highlight an element on screen with a colored overlay
    /// - Parameters:
    ///   - role: Accessibility role to find
    ///   - title: Title to match (partial match)
    ///   - value: Value to match (partial match)
    ///   - appBundleId: Optional bundle ID to search within
    ///   - x: Optional X coordinate for position-based lookup
    ///   - y: Optional Y coordinate for position-based lookup
    ///   - duration: How long to show the highlight (default 2.0 seconds)
    ///   - color: Highlight color - "red", "green", "blue", "yellow", "purple" (default "green")
    /// - Returns: JSON result with highlight status
    public func highlightElement(
        role: String?,
        title: String?,
        value: String?,
        appBundleId: String?,
        x: CGFloat?,
        y: CGFloat?,
        duration: TimeInterval = 2.0,
        color: String = "green"
    ) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "highlightElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), duration: \(duration)s)")

        // Find element
        var element: AXUIElement?

        if let x = x, let y = y {
            let systemWide = AXUIElementCreateSystemWide()
            let copyResult = copyWithTimeout(systemWide: systemWide, x: x, y: y, timeout: Self.elementAtPositionTimeout)
            if copyResult.timedOut {
                return errorJSON("Element lookup timed out at (\(x), \(y))")
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
            return errorJSON("Element not found for highlighting")
        }

        // Get element position and size to calculate bounds
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        var bounds = CGRect.zero

        // Get position
        guard AXUIElementCopyAttributeValue(found, kAXPositionAttribute as CFString, &positionRef) == .success,
              let positionValue = positionRef,
              CFGetTypeID(positionValue) == AXValueGetTypeID() else {
            return errorJSON("Could not get element position")
        }

		        var position = CGPoint.zero
		        let axPosValue = positionValue as! AXValue
		        guard AXValueGetValue(axPosValue, .cgPoint, &position) else {
		            return errorJSON("Could not decode element position")
		        }

		        // Get size
		        if AXUIElementCopyAttributeValue(found, kAXSizeAttribute as CFString, &sizeRef) == .success,
		           let sizeValue = sizeRef,
		           CFGetTypeID(sizeValue) == AXValueGetTypeID() {
		            let axSizeValue = sizeValue as! AXValue
		            var size = CGSize.zero
		            if AXValueGetValue(axSizeValue, .cgSize, &size) {
	                bounds = CGRect(origin: position, size: size)
	            } else {
	                bounds = CGRect(origin: position, size: CGSize(width: 100, height: 30))
	            }
	        } else {
            // Fallback size if not available
            bounds = CGRect(origin: position, size: CGSize(width: 100, height: 30))
        }

        // Create highlight window
        let highlightColor: NSColor
        switch color.lowercased() {
        case "red": highlightColor = NSColor.red.withAlphaComponent(0.3)
        case "blue": highlightColor = NSColor.blue.withAlphaComponent(0.3)
        case "yellow": highlightColor = NSColor.yellow.withAlphaComponent(0.3)
        case "purple": highlightColor = NSColor.purple.withAlphaComponent(0.3)
        case "green": highlightColor = NSColor.green.withAlphaComponent(0.3)
        default: highlightColor = NSColor.green.withAlphaComponent(0.3)
        }

        DispatchQueue.main.async {
            let window = NSWindow(
                contentRect: bounds,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = .floating
            window.backgroundColor = highlightColor
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.makeKeyAndOrderFront(nil)

            // Auto-close after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                window.close()
            }
        }

        return successJSON([
            "message": "Element highlighted for \(duration) seconds",
            "bounds": [
                "x": bounds.origin.x,
                "y": bounds.origin.y,
                "width": bounds.width,
                "height": bounds.height
            ],
            "color": color,
            "duration": duration
        ])
    }

    // MARK: - Get Window Frame (Phase 2 Feature)

    /// Get the exact position and frame of a window by ID
    /// - Parameter windowId: The window ID (from ax_list_windows)
    /// - Returns: JSON result with window frame details
    public func getWindowFrame(windowId: Int) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "getWindowFrame(windowId: \(windowId))")

        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return errorJSON("Could not get window list")
        }

        for window in windowList {
            guard let wid = window[kCGWindowNumber as String] as? Int,
                  wid == windowId else { continue }

            let ownerPID = window[kCGWindowOwnerPID as String] as? Int32 ?? 0
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let windowName = window[kCGWindowName as String] as? String ?? ""
            let layer = window[kCGWindowLayer as String] as? Int ?? 0

            if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] {
                let appName = getProcessName(pid: ownerPID) ?? ownerName
                return successJSON([
                    "windowId": windowId,
                    "ownerPID": Int(ownerPID),
                    "ownerName": appName,
                    "windowName": windowName,
                    "layer": layer,
                    "frame": [
                        "x": bounds["X"] ?? 0,
                        "y": bounds["Y"] ?? 0,
                        "width": bounds["Width"] ?? 0,
                        "height": bounds["Height"] ?? 0
                    ]
                ])
            }
        }

        return errorJSON("Window \(windowId) not found")
    }

    // MARK: - Menu Bar Navigation

    /// Click a menu item by path, e.g. ["File", "Save"] or ["Edit", "Find", "Find..."]
    public func clickMenuItem(appBundleId: String?, menuPath: [String]) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "clickMenuItem(app: \(appBundleId ?? "frontmost"), path: \(menuPath.joined(separator: " > ")))")
        guard !menuPath.isEmpty else { return errorJSON("Menu path cannot be empty") }

        let pid: pid_t
        if let bundleId = appBundleId {
            guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) else {
                return errorJSON("App not found: \(bundleId)")
            }
            pid = app.processIdentifier
        } else {
            guard let app = NSWorkspace.shared.frontmostApplication else {
                return errorJSON("No frontmost app")
            }
            pid = app.processIdentifier
        }

        let appElement = AXUIElementCreateApplication(pid)
        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef) == .success else {
            return errorJSON("Could not access menu bar")
        }

        var current = menuBarRef as! AXUIElement
        for (i, menuName) in menuPath.enumerated() {
            var childrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                  let children = childrenRef as? [AXUIElement] else {
                return errorJSON("Could not get children at level \(i)")
            }
            var found = false
            for child in children {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let title = titleRef as? String, title == menuName {
                    if i == menuPath.count - 1 {
                        // Last item — press it
                        let err = AXUIElementPerformAction(child, kAXPressAction as CFString)
                        if err == .success {
                            return successJSON(["message": "Clicked menu: \(menuPath.joined(separator: " > "))"])
                        } else {
                            return errorJSON("Failed to press menu item: \(menuName)")
                        }
                    } else {
                        // Intermediate — open submenu
                        AXUIElementPerformAction(child, kAXPressAction as CFString)
                        Thread.sleep(forTimeInterval: 0.15)
                        // Get the submenu children
                        var subRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &subRef) == .success,
                           let subs = subRef as? [AXUIElement], let first = subs.first {
                            current = first
                        } else {
                            current = child
                        }
                        found = true
                        break
                    }
                }
            }
            if !found && i < menuPath.count - 1 {
                return errorJSON("Menu '\(menuName)' not found at level \(i)")
            }
        }
        return errorJSON("Menu item not found: \(menuPath.joined(separator: " > "))")
    }

    // MARK: - Window Move / Resize

    /// Move and/or resize a window by app bundle ID
    public func setWindowFrame(appBundleId: String?, x: CGFloat?, y: CGFloat?, width: CGFloat?, height: CGFloat?) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "setWindowFrame(app: \(appBundleId ?? "frontmost"), x: \(x ?? -1), y: \(y ?? -1), w: \(width ?? -1), h: \(height ?? -1))")

        let pid: pid_t
        if let bundleId = appBundleId {
            guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) else {
                return errorJSON("App not found: \(bundleId)")
            }
            pid = app.processIdentifier
        } else {
            guard let app = NSWorkspace.shared.frontmostApplication else { return errorJSON("No frontmost app") }
            pid = app.processIdentifier
        }

        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement], let window = windows.first else {
            return errorJSON("No windows found")
        }

        // Move
        if let x, let y {
            var point = CGPoint(x: x, y: y)
            if let posValue = AXValueCreate(.cgPoint, &point) {
                AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
            }
        }

        // Resize
        if let width, let height {
            var size = CGSize(width: width, height: height)
            if let sizeValue = AXValueCreate(.cgSize, &size) {
                AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            }
        }

        return successJSON(["message": "Window frame updated"])
    }

    // MARK: - App Launch / Activate / Quit

    /// Launch, activate, or quit an app by bundle ID or name
    public func manageApp(action: String, bundleId: String?, name: String?) -> String {
        AuditLog.log(.accessibility, "manageApp(action: \(action), bundleId: \(bundleId ?? "nil"), name: \(name ?? "nil"))")

        switch action {
        case "launch":
            if let bid = bundleId, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: url, configuration: config)
                return successJSON(["message": "Launched \(bid)"])
            } else if let n = name {
                let url = URL(fileURLWithPath: "/Applications/\(n).app")
                if FileManager.default.fileExists(atPath: url.path) {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                    return successJSON(["message": "Launched \(n)"])
                }
                return errorJSON("App not found: \(n)")
            }
            return errorJSON("Specify bundleId or name")

        case "activate":
            if let bid = bundleId,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bid }) {
                app.activate()
                return successJSON(["message": "Activated \(bid)"])
            } else if let n = name,
                      let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == n }) {
                app.activate()
                return successJSON(["message": "Activated \(n)"])
            }
            return errorJSON("App not running")

        case "quit":
            if let bid = bundleId,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bid }) {
                app.terminate()
                return successJSON(["message": "Quit \(bid)"])
            } else if let n = name,
                      let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == n }) {
                app.terminate()
                return successJSON(["message": "Quit \(n)"])
            }
            return errorJSON("App not running")

        case "list":
            let apps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .map { "\($0.localizedName ?? "?") — \($0.bundleIdentifier ?? "?")\($0.isActive ? " (active)" : "")" }
            return successJSON(["apps": apps])

        default:
            return errorJSON("Unknown action: \(action). Use launch, activate, quit, or list.")
        }
    }

    // MARK: - Scroll to AX Element

    /// Scroll within an app until an element with the given role/title becomes visible
    public func scrollToElement(role: String?, title: String?, appBundleId: String?, maxScrolls: Int = 20) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "scrollToElement(role: \(role ?? "nil"), title: \(title ?? "nil"), app: \(appBundleId ?? "nil"))")

        // Check if already visible
        let existing = findElement(role: role, title: title, value: nil, appBundleId: appBundleId, timeout: 0.5)
        if existing.contains("\"success\": true") {
            return successJSON(["message": "Element already visible", "scrolls": 0])
        }

        // Get the frontmost window's center for scroll events
        let pid: pid_t
        if let bundleId = appBundleId,
           let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
            pid = app.processIdentifier
        } else if let app = NSWorkspace.shared.frontmostApplication {
            pid = app.processIdentifier
        } else {
            return errorJSON("No app to scroll in")
        }

        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        var scrollX: CGFloat = 400
        var scrollY: CGFloat = 400
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windows = windowsRef as? [AXUIElement], let window = windows.first {
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
               AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success {
                var pos = CGPoint.zero
                var size = CGSize.zero
		                if let pv = posRef, CFGetTypeID(pv) == AXValueGetTypeID() { let axPv = pv as! AXValue; AXValueGetValue(axPv, .cgPoint, &pos) }
		                if let sv = sizeRef, CFGetTypeID(sv) == AXValueGetTypeID() { let axSv = sv as! AXValue; AXValueGetValue(axSv, .cgSize, &size) }
                scrollX = pos.x + size.width / 2
                scrollY = pos.y + size.height / 2
            }
        }

        for i in 0..<maxScrolls {
            _ = scrollAt(x: scrollX, y: scrollY, deltaX: 0, deltaY: -5)
            Thread.sleep(forTimeInterval: 0.3)
            let check = findElement(role: role, title: title, value: nil, appBundleId: appBundleId, timeout: 0.3)
            if check.contains("\"success\": true") {
                return successJSON(["message": "Found element after scrolling", "scrolls": i + 1])
            }
        }

        return errorJSON("Element not found after \(maxScrolls) scrolls")
    }

    // MARK: - Read Focused Element

    /// Read the value/text of the currently focused UI element
    public func readFocusedElement(appBundleId: String? = nil) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "readFocusedElement(app: \(appBundleId ?? "frontmost"))")

        let pid: pid_t
        if let bundleId = appBundleId,
           let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
            pid = app.processIdentifier
        } else if let app = NSWorkspace.shared.frontmostApplication {
            pid = app.processIdentifier
        } else {
            return errorJSON("No frontmost app")
        }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success else {
            return errorJSON("No focused element")
        }
        let focused = focusedRef as! AXUIElement

        var result: [String: Any] = [:]
        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(focused, kAXRoleAttribute as CFString, &ref) == .success { result["role"] = ref as? String }
        if AXUIElementCopyAttributeValue(focused, kAXTitleAttribute as CFString, &ref) == .success { result["title"] = ref as? String }
        if AXUIElementCopyAttributeValue(focused, kAXValueAttribute as CFString, &ref) == .success {
            if let val = ref as? String { result["value"] = val }
        }
        if AXUIElementCopyAttributeValue(focused, kAXDescriptionAttribute as CFString, &ref) == .success { result["description"] = ref as? String }
        if AXUIElementCopyAttributeValue(focused, kAXPlaceholderValueAttribute as CFString, &ref) == .success { result["placeholder"] = ref as? String }

        return successJSON(result)
    }

    /// Get recent audit log entries (now powered by AgentAudit)
    public func getAuditLog(limit: Int = 50) -> String {
        AuditLog.recentEntries(limit: limit).joined(separator: "\n")
    }
}
