import AgentAudit
import AXorcist
import Foundation
import AppKit
@preconcurrency import ApplicationServices

extension AccessibilityService {
    // MARK: - Frontmost Window

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

    // MARK: - Highlight Element

    @MainActor
    public func highlightElement(
        role: String?, title: String?, value: String?, appBundleId: String?,
        x: CGFloat?, y: CGFloat?,
        duration: TimeInterval = 2.0, color: String = "green"
    ) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "highlightElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), duration: \(duration)s)")

        var element: Element?

        if let x = x, let y = y {
            element = Element.elementAtPoint(CGPoint(x: x, y: y))
        } else {
            element = findAXElement(role: role, title: title, value: value, appBundleId: appBundleId)
        }

        guard let found = element else {
            return errorJSON("Element not found for highlighting")
        }

        guard let frame = found.frame() else {
            return errorJSON("Could not get element position")
        }

        let highlightColor: NSColor
        switch color.lowercased() {
        case "red": highlightColor = NSColor.red.withAlphaComponent(0.3)
        case "blue": highlightColor = NSColor.blue.withAlphaComponent(0.3)
        case "yellow": highlightColor = NSColor.yellow.withAlphaComponent(0.3)
        case "purple": highlightColor = NSColor.purple.withAlphaComponent(0.3)
        default: highlightColor = NSColor.green.withAlphaComponent(0.3)
        }

        DispatchQueue.main.async {
            let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.level = .floating
            window.backgroundColor = highlightColor
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.makeKeyAndOrderFront(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { window.close() }
        }

        return successJSON([
            "message": "Element highlighted for \(duration) seconds",
            "bounds": ["x": frame.origin.x, "y": frame.origin.y, "width": frame.width, "height": frame.height],
            "color": color, "duration": duration
        ])
    }

    // MARK: - Get Window Frame

    public func getWindowFrame(windowId: Int) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "getWindowFrame(windowId: \(windowId))")

        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return errorJSON("Could not get window list")
        }

        for window in windowList {
            guard let wid = window[kCGWindowNumber as String] as? Int, wid == windowId else { continue }
            let ownerPID = window[kCGWindowOwnerPID as String] as? Int32 ?? 0
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let windowName = window[kCGWindowName as String] as? String ?? ""
            let layer = window[kCGWindowLayer as String] as? Int ?? 0

            if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] {
                let appName = getProcessName(pid: ownerPID) ?? ownerName
                return successJSON([
                    "windowId": windowId, "ownerPID": Int(ownerPID), "ownerName": appName,
                    "windowName": windowName, "layer": layer,
                    "frame": ["x": bounds["X"] ?? 0, "y": bounds["Y"] ?? 0, "width": bounds["Width"] ?? 0, "height": bounds["Height"] ?? 0]
                ])
            }
        }
        return errorJSON("Window \(windowId) not found")
    }

    // MARK: - Menu Bar Navigation

    @MainActor
    public func clickMenuItem(appBundleId: String?, menuPath: [String]) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "clickMenuItem(app: \(appBundleId ?? "frontmost"), path: \(menuPath.joined(separator: " > ")))")
        guard !menuPath.isEmpty else { return errorJSON("Menu path cannot be empty") }

        let appElement: Element?
        if let bundleId = appBundleId,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            appElement = Element.application(for: app)
        } else if let app = NSWorkspace.shared.frontmostApplication {
            appElement = Element.application(for: app)
        } else {
            return errorJSON("No frontmost app")
        }

        guard let root = appElement, let menuBar = root.mainMenu() else {
            return errorJSON("Could not access menu bar")
        }

        var current = menuBar
        for (i, menuName) in menuPath.enumerated() {
            guard let children = current.children() else {
                return errorJSON("Could not get children at level \(i)")
            }
            var found = false
            for child in children {
                if child.title() == menuName {
                    if i == menuPath.count - 1 {
                        do {
                            try child.performAction("AXPress")
                            return successJSON(["message": "Clicked menu: \(menuPath.joined(separator: " > "))"])
                        } catch {
                            return errorJSON("Failed to press menu item: \(menuName)")
                        }
                    } else {
                        _ = try? child.performAction("AXPress")
                        Thread.sleep(forTimeInterval: 0.15)
                        if let subs = child.children(), let first = subs.first {
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

    @MainActor
    public func setWindowFrame(appBundleId: String?, x: CGFloat?, y: CGFloat?, width: CGFloat?, height: CGFloat?) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "setWindowFrame(app: \(appBundleId ?? "frontmost"), x: \(x ?? -1), y: \(y ?? -1), w: \(width ?? -1), h: \(height ?? -1))")

        let appElement: Element?
        if let bundleId = appBundleId,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            appElement = Element.application(for: app)
        } else if let app = NSWorkspace.shared.frontmostApplication {
            appElement = Element.application(for: app)
        } else {
            return errorJSON("No frontmost app")
        }

        guard let root = appElement,
              let children = root.children(),
              let window = children.first(where: { $0.role() == "AXWindow" }) else {
            return errorJSON("No windows found")
        }

        if let x, let y {
            _ = window.setPosition(CGPoint(x: x, y: y))
        }
        if let width, let height {
            _ = window.setSize(CGSize(width: width, height: height))
        }

        return successJSON(["message": "Window frame updated"])
    }

    // MARK: - App Launch / Activate / Quit

    public func manageApp(action: String, bundleId: String?, name: String?) -> String {
        AuditLog.log(.accessibility, "manageApp(action: \(action), bundleId: \(bundleId ?? "nil"), name: \(name ?? "nil"))")

        switch action {
        case "launch":
            if let bid = bundleId, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
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
            if let bid = bundleId, let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bid }) {
                app.activate()
                return successJSON(["message": "Activated \(bid)"])
            } else if let n = name, let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == n }) {
                app.activate()
                return successJSON(["message": "Activated \(n)"])
            }
            return errorJSON("App not running")
        case "quit":
            if let bid = bundleId, let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bid }) {
                app.terminate()
                return successJSON(["message": "Quit \(bid)"])
            } else if let n = name, let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == n }) {
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

    @MainActor
    public func scrollToElement(role: String?, title: String?, appBundleId: String?, maxScrolls: Int = 20) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "scrollToElement(role: \(role ?? "nil"), title: \(title ?? "nil"), app: \(appBundleId ?? "nil"))")

        if findAXElement(role: role, title: title, value: nil, appBundleId: appBundleId) != nil {
            return successJSON(["message": "Element already visible", "scrolls": 0])
        }

        // Get window center for scroll
        let appElement: Element?
        if let bundleId = appBundleId,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            appElement = Element.application(for: app)
        } else if let app = NSWorkspace.shared.frontmostApplication {
            appElement = Element.application(for: app)
        } else {
            return errorJSON("No app to scroll in")
        }

        var scrollX: CGFloat = 400
        var scrollY: CGFloat = 400
        if let root = appElement,
           let children = root.children(),
           let window = children.first(where: { $0.role() == "AXWindow" }),
           let frame = window.frame() {
            scrollX = frame.midX
            scrollY = frame.midY
        }

        for i in 0..<maxScrolls {
            _ = scrollAt(x: scrollX, y: scrollY, deltaX: 0, deltaY: -5)
            Thread.sleep(forTimeInterval: 0.3)
            if findAXElement(role: role, title: title, value: nil, appBundleId: appBundleId) != nil {
                return successJSON(["message": "Found element after scrolling", "scrolls": i + 1])
            }
        }

        return errorJSON("Element not found after \(maxScrolls) scrolls")
    }

    // MARK: - Read Focused Element

    @MainActor
    public func readFocusedElement(appBundleId: String? = nil) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "readFocusedElement(app: \(appBundleId ?? "frontmost"))")

        let appElement: Element?
        if let bundleId = appBundleId,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            appElement = Element.application(for: app)
        } else if let app = NSWorkspace.shared.frontmostApplication {
            appElement = Element.application(for: app)
        } else {
            return errorJSON("No frontmost app")
        }

        guard let root = appElement else { return errorJSON("No app element") }

        // AXorcist: use focusedApplicationElement
        if let focused = root.focusedApplicationElement() {
            return successJSON(elementProperties(focused))
        }
        return errorJSON("No focused element")
    }

    /// Get recent audit log entries
    public func getAuditLog(limit: Int = 50) -> String {
        AuditLog.recentEntries(limit: limit).joined(separator: "\n")
    }
}
