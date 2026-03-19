import Foundation
import AppKit
import ApplicationServices

/// Accessibility automation service for interacting with UI elements via the Accessibility API.
/// Provides tools for window listing, element inspection, and UI interaction.
final class AccessibilityService: @unchecked Sendable {
    static let shared = AccessibilityService()
    
    // MARK: - Security

    /// Cached permission — once granted, skip repeated AXIsProcessTrusted() calls.
    /// Rebuilds in Xcode change the binary signature, causing macOS TCC to revoke trust.
    /// Caching prevents the LLM from re-triggering the dialog on every tool call within a session.
    private nonisolated(unsafe) static var _permissionGranted = false

    /// Check if the app has Accessibility permissions (cached once granted)
    static func hasAccessibilityPermission() -> Bool {
        if _permissionGranted { return true }
        let granted = AXIsProcessTrusted()
        if granted { _permissionGranted = true }
        return granted
    }

    /// Request Accessibility permissions — opens System Settings directly.
    /// Only shows the system dialog once per session to avoid repeated prompts.
    private nonisolated(unsafe) static var _promptShown = false
    static func requestAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            _permissionGranted = true
            return true
        }
        if !_promptShown {
            _promptShown = true
            let promptKey = "AXTrustedCheckOptionPrompt" as CFString
            let options: [CFString: Bool] = [promptKey: true]
            let result = AXIsProcessTrustedWithOptions(options as CFDictionary)
            if result { _permissionGranted = true }
            return result
        }
        // Already showed dialog this session — just open System Settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        return false
    }
    
    /// Check whether an ID is restricted. Reads UserDefaults directly (thread-safe).
    private static func isRestricted(_ id: String) -> Bool {
        guard let enabled = UserDefaults.standard.stringArray(forKey: "ax.enabledRestrictions") else {
            // First launch — all enabled (not restricted)
            return false
        }
        return !enabled.contains(id)
    }
    
    // MARK: - Window Listing
    
    /// List all visible windows from all applications
    func listWindows(limit: Int = 50) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("listWindows(limit: \(limit))")

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
        Self.logAudit("inspectElementAt(x: \(x), y: \(y), depth: \(depth))")

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
        Self.logAudit("getElementProperties(role: \(role ?? "nil"), title: \(title ?? "nil"), app: \(appBundleId ?? "nil"))")

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
    
    /// Max recursion depth for AX hierarchy traversal — prevents stack overflow
    /// from deeply nested or circular element trees (browsers, Finder, etc.)
    private static let maxHierarchyDepth = 100

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
    
    // MARK: - Perform Actions
    
    func performAction(role: String?, title: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, action: String, allowWrites: Bool = false) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("performAction(\(action)) role: \(role ?? "nil"), title: \(title ?? "nil"), app: \(appBundleId ?? "nil"), allowWrites: \(allowWrites)")

        if !allowWrites && Self.isRestricted(action) {
            return errorJSON("Action '\(action)' restricted. Enable in Accessibility Access or set allowWrites=true.")
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
    func typeText(_ text: String, at x: CGFloat? = nil, y: CGFloat? = nil) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("typeText(\(text.count) chars) at x: \(x.map(String.init) ?? "nil"), y: \(y.map(String.init) ?? "nil")")

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
                // Regular character - use UniChar array for keyboardSetUnicodeString
                guard let scalar = char.unicodeScalars.first else { continue }
                var uniChars = [UniChar(scalar.value)]
                if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                    event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &uniChars)
                    event.post(tap: CGEventTapLocation.cgSessionEventTap)
                    event.type = .keyUp
                    event.post(tap: CGEventTapLocation.cgSessionEventTap)
                }
            }
        }
        
        return successJSON(["message": "Typed \(text.count) characters"])
    }
    
    /// Simulate a mouse click at screen coordinates
    func clickAt(x: CGFloat, y: CGFloat, button: String = "left", clicks: Int = 1) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("clickAt(x: \(x), y: \(y), button: \(button), clicks: \(clicks))")

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
    func scrollAt(x: CGFloat, y: CGFloat, deltaX: Int, deltaY: Int) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("scrollAt(x: \(x), y: \(y), deltaX: \(deltaX), deltaY: \(deltaY))")

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
    func pressKey(virtualKey: UInt16, modifiers: [String] = []) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("pressKey(\(virtualKey), modifiers: \(modifiers))")

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
    
    // MARK: - Screenshot (Phase 4)
    
    /// Capture a screenshot of a region or window. Requires Screen Recording permission.
    /// Returns the path to the saved PNG file, or an error message.
    func captureScreenshot(x: CGFloat? = nil, y: CGFloat? = nil, width: CGFloat? = nil, height: CGFloat? = nil, windowID: Int? = nil) -> String {
        // Check Accessibility permission (Screen Recording is same TCC category on macOS)
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility/Screen Recording permission required.")
        }
        Self.logAudit("captureScreenshot(x: \(x.map(String.init) ?? "nil"), y: \(y.map(String.init) ?? "nil"), w: \(width.map(String.init) ?? "nil"), h: \(height.map(String.init) ?? "nil"), windowID: \(windowID.map(String.init) ?? "nil"))")

        let home = FileManager.default.homeDirectoryForCurrentUser
        let fileName = "screenshot_\(UUID().uuidString).png"
        let outputPath = home.appendingPathComponent("Documents/AgentScript/screenshots/\(fileName)").path

        // Ensure output directory exists
        try? FileManager.default.createDirectory(atPath: home.appendingPathComponent("Documents/AgentScript/screenshots").path, withIntermediateDirectories: true)
        
        // Build screencapture command
        var args = ["-x", "-t", "png"]  // -x: no sound, -t png: format
        
        if let wid = windowID, wid > 0 {
            // Capture specific window by ID
            args.append("-l")
            args.append("\(wid)")
        } else if let x = x, let y = y, let w = width, let h = height {
            // Capture region
            args.append("-R")
            args.append("\(Int(x)),\(Int(y)),\(Int(w)),\(Int(h))")
        }
        
        args.append(outputPath)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                return errorJSON("screencapture failed with exit code \(process.terminationStatus)")
            }
            
            guard FileManager.default.fileExists(atPath: outputPath) else {
                return errorJSON("Screenshot file not created at \(outputPath)")
            }
            
            // Get file size for confirmation
            let attrs = try FileManager.default.attributesOfItem(atPath: outputPath)
            let fileSize = attrs[.size] as? Int64 ?? 0
            
            return successJSON([
                "path": outputPath,
                "size": fileSize,
                "message": "Screenshot saved to \(outputPath)"
            ])
        } catch {
            return errorJSON("Failed to capture screenshot: \(error.localizedDescription)")
        }
    }
    
    /// Capture a screenshot of all visible windows (requires Screen Recording permission)
    func captureAllWindows() -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility/Screen Recording permission required.")
        }
        Self.logAudit("captureAllWindows()")

        let home = FileManager.default.homeDirectoryForCurrentUser
        let fileName = "screenshot_\(UUID().uuidString).png"
        let outputPath = home.appendingPathComponent("Documents/AgentScript/\(fileName)").path
        
        try? FileManager.default.createDirectory(atPath: home.appendingPathComponent("Documents/AgentScript").path, withIntermediateDirectories: true)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-t", "png", outputPath]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                return errorJSON("screencapture failed with exit code \(process.terminationStatus)")
            }
            
            guard FileManager.default.fileExists(atPath: outputPath) else {
                return errorJSON("Screenshot file not created")
            }
            
            let attrs = try FileManager.default.attributesOfItem(atPath: outputPath)
            let fileSize = attrs[.size] as? Int64 ?? 0
            
            return successJSON([
                "path": outputPath,
                "size": fileSize,
                "message": "Fullscreen screenshot saved to \(outputPath)"
            ])
        } catch {
            return errorJSON("Failed to capture screenshot: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Audit Logging (Phase 5)
    
    private static nonisolated(unsafe) var auditLog: [String] = []
    private static let auditLogLock = NSLock()
    private static let auditLogFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/AgentScript/accessibility_audit.log")
    
    private static func logAudit(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)"
        
        auditLogLock.lock()
        defer { auditLogLock.unlock() }
        
        auditLog.append(entry)
        
        // Keep last 1000 entries in memory
        if auditLog.count > 1000 {
            auditLog.removeFirst(100)
        }
        
        // Append to file asynchronously
        let fileURL = auditLogFile
        DispatchQueue.global().async {
            if let data = (entry + "\n").data(using: .utf8) {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    if let handle = try? FileHandle(forWritingTo: fileURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    try? FileManager.default.createDirectory(
                        at: fileURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true)
                    try? data.write(to: fileURL, options: .atomic)
                }
            }
        }
    }
    
    /// Get recent audit log entries
    func getAuditLog(limit: Int = 50) -> String {
        Self.auditLogLock.lock()
        defer { Self.auditLogLock.unlock() }
        let entries = Array(Self.auditLog.suffix(limit))
        return entries.joined(separator: "\n")
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
