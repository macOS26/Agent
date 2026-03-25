import Foundation
import AppKit
@preconcurrency import ApplicationServices

/// Accessibility automation service for interacting with UI elements via the Accessibility API.
/// Provides tools for window listing, element inspection, and UI interaction.
final class AccessibilityService: @unchecked Sendable {
    static let shared = AccessibilityService()

    // MARK: - Browser Detection

    /// Bundle IDs of browsers with native JavaScript automation via AppleScript `do JavaScript`.
    /// Accessibility is blocked for these — use the `web` tool instead.
    /// Other browsers (Chrome, Firefox, Edge, etc.) still use accessibility as a fallback
    /// since they lack reliable AppleScript JS injection.
    private static let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
    ]

    /// Check if a bundle ID belongs to a web browser.
    static func isBrowser(_ bundleId: String?) -> Bool {
        guard let bid = bundleId else { return false }
        return browserBundleIDs.contains(bid)
    }

    /// Check if the frontmost app is a web browser.
    static func frontmostAppIsBrowser() -> Bool {
        guard let bid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return browserBundleIDs.contains(bid)
    }

    /// When accessibility targets Safari, auto-fetch page info via JavaScript instead of failing.
    /// Runs synchronously via NSAppleScript so it works from any AccessibilityService method.
    static func safariPageInfo() -> String {
        let script = """
        tell application "Safari"
            set t to name of front document
            set u to URL of front document
            set s to do JavaScript "document.body.innerText.substring(0, 3000)" in front document
            return "URL: " & u & "\\nTitle: " & t & "\\nContent:\\n" & s
        end tell
        """
        var err: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return shared.errorJSON("Could not create AppleScript for Safari page info")
        }
        let out = appleScript.executeAndReturnError(&err)
        if let error = err {
            return shared.errorJSON("Safari JavaScript error: \(error[NSAppleScript.errorMessage] ?? error)")
        }
        let text = out.stringValue ?? "(no content)"
        return shared.successJSON([
            "source": "safari_javascript",
            "pageInfo": text,
            "hint": "For more web interaction use: web(action: 'click', selector: '...'), web(action: 'type', selector: '...', text: '...'), web(action: 'execute_js', script: '...')"
        ])
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

        // If Safari is in the window list, hint the LLM to use the web tool for page content
        let hasSafari = results.contains { ($0["ownerName"] as? String) == "Safari" }
        var response: [String: Any] = ["windows": results, "count": results.count]
        if hasSafari {
            response["hint"] = "Safari detected. Use the safari tool for web page content: safari(action: 'execute_js', script: 'document.body.innerText'), safari(action: 'get_url'), safari(action: 'click', selector: '...'). Accessibility cannot access web page DOM."
        }

        return successJSON(response)
    }
    
    // MARK: - Element Inspection
    
    /// Timeout for AXUIElementCopyElementAtPosition to prevent hangs on complex text views
    private static let elementAtPositionTimeout: TimeInterval = 2.0
    
    func inspectElementAt(x: CGFloat, y: CGFloat, depth: Int = 3) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("inspectElementAt(x: \(x), y: \(y), depth: \(depth))")

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
    private nonisolated func copyWithTimeout(systemWide: AXUIElement, x: CGFloat, y: CGFloat, timeout: TimeInterval) -> (element: AXUIElement?, timedOut: Bool, error: AXError) {
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
    
    func getElementProperties(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("getElementProperties(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"))")

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
    
    func performAction(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, action: String) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("performAction(\(action)) role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil")")

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

        // Try to capture just the frontmost window instead of the entire screen
        let frontWindowID = Self.frontmostWindowID()

        let home = FileManager.default.homeDirectoryForCurrentUser
        let fileName = "screenshot_\(UUID().uuidString).png"
        let outputPath = home.appendingPathComponent("Documents/AgentScript/screenshots/\(fileName)").path

        try? FileManager.default.createDirectory(atPath: home.appendingPathComponent("Documents/AgentScript/screenshots").path, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        if let wid = frontWindowID {
            process.arguments = ["-x", "-t", "png", "-l", "\(wid)", outputPath]
        } else {
            process.arguments = ["-x", "-t", "png", outputPath]
        }
        
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
    
    // MARK: - Set Properties (Phase 6)
    
    /// Set accessibility property values on an element. CRITICAL for setting text fields, selections, etc.
    func setProperties(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, properties: [String: Any]) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("setProperties(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), properties: \(properties.keys)")
        
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
            return errorJSON("Element not found")
        }
        
        // Check for restricted roles
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXRoleAttribute as CFString, &roleRef) == .success,
           let elRole = roleRef as? String, Self.isRestricted(elRole) {
            return errorJSON("Cannot interact with \(elRole) — disabled in Accessibility Access")
        }
        
        var results: [String: Any] = [:]
        var successCount = 0
        
        for (key, value) in properties {
            let cfValue: CFTypeRef
            if let s = value as? String {
                cfValue = s as CFString
            } else if let b = value as? Bool {
                cfValue = NSNumber(value: b)
            } else if let i = value as? Int {
                cfValue = NSNumber(value: i)
            } else if let d = value as? Double {
                cfValue = NSNumber(value: d)
            } else {
                cfValue = String(describing: value) as CFString
            }
            
            // Special handling for AXValue types (position, size)
            if key == kAXPositionAttribute as String || key == kAXSizeAttribute as String {
                guard let dict = value as? [String: CGFloat],
                      let axValue = createAXValue(key: key, from: dict) else {
                    results[key] = "Failed to create AXValue for \(key)"
                    continue
                }
                let result = AXUIElementSetAttributeValue(found, key as CFString, axValue)
                if result == .success {
                    results[key] = "set"
                    successCount += 1
                } else {
                    results[key] = "failed: \(result.rawValue)"
                }
            } else {
                let result = AXUIElementSetAttributeValue(found, key as CFString, cfValue)
                if result == .success {
                    results[key] = "set"
                    successCount += 1
                } else {
                    results[key] = "failed: \(result.rawValue)"
                }
            }
        }
        
        return successJSON([
            "message": "Set \(successCount)/\(properties.count) properties",
            "results": results
        ])
    }
    
    private func createAXValue(key: String, from dict: [String: CGFloat]) -> AXValue? {
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
    
    // MARK: - Find Element (Phase 6)
    
    /// Find an element by role, title, or other criteria with optional timeout
    func findElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = automationFinishTimeout) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("findElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")
        
        let startTime = Date()
        let notFoundError = "Element not found"
        
        while Date().timeIntervalSince(startTime) < timeout {
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
            
            if let found = element {
                return successJSON(getAllProperties(found))
            }
            
            // Small delay before retrying
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        return errorJSON(notFoundError)
    }
    
    private func findElementInApp(pid: pid_t, role: String?, title: String?, value: String?) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        return findElementInHierarchy(app, role: role, title: title, value: value)
    }
    
    private func findElementGlobally(role: String?, title: String?, value: String?) -> AXUIElement? {
        for app in NSWorkspace.shared.runningApplications {
            guard let pid = app.processIdentifier as pid_t? else { continue }
            if let found = findElementInApp(pid: pid, role: role, title: title, value: value) {
                return found
            }
        }
        return nil
    }
    
    private func findElementInHierarchy(_ parent: AXUIElement, role: String?, title: String?, value: String?, depth: Int = 0) -> AXUIElement? {
        guard depth < Self.maxHierarchyDepth else { return nil }
        
        // Check role match
        if let targetRole = role {
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(parent, kAXRoleAttribute as CFString, &roleRef) == .success,
               let elementRole = roleRef as? String, elementRole == targetRole {
                // Role matches, check title if provided
                if let targetTitle = title {
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(parent, kAXTitleAttribute as CFString, &titleRef) == .success,
                       let elementTitle = titleRef as? String, elementTitle.contains(targetTitle) {
                        // Title also matches, check value if provided
                        if let targetValue = value {
                            var valueRef: CFTypeRef?
                            if AXUIElementCopyAttributeValue(parent, kAXValueAttribute as CFString, &valueRef) == .success,
                               let elementValue = valueRef as? String, elementValue.contains(targetValue) {
                                return parent
                            }
                        } else {
                            return parent
                        }
                    }
                } else if let targetValue = value {
                    // No title filter, check value
                    var valueRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(parent, kAXValueAttribute as CFString, &valueRef) == .success,
                       let elementValue = valueRef as? String, elementValue.contains(targetValue) {
                        return parent
                    }
                } else {
                    return parent
                }
            }
        } else if let targetTitle = title {
            // No role filter, check title
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(parent, kAXTitleAttribute as CFString, &titleRef) == .success,
               let elementTitle = titleRef as? String, elementTitle.contains(targetTitle) {
                if let targetValue = value {
                    var valueRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(parent, kAXValueAttribute as CFString, &valueRef) == .success,
                       let elementValue = valueRef as? String, elementValue.contains(targetValue) {
                        return parent
                    }
                } else {
                    return parent
                }
            }
        } else if let targetValue = value {
            // No role or title filter, check value
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(parent, kAXValueAttribute as CFString, &valueRef) == .success,
               let elementValue = valueRef as? String, elementValue.contains(targetValue) {
                return parent
            }
        }
        
        // Recurse into children
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
    
    // MARK: - Get Focused Element (Phase 6)
    
    /// Get the currently focused element
    func getFocusedElement(appBundleId: String? = nil) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("getFocusedElement(app: \(appBundleId ?? "nil"))")
        
        var element: AXUIElement?
        
        if let bundleId = appBundleId {
            let apps = NSWorkspace.shared.runningApplications
            if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
               let pid = app.processIdentifier as pid_t? {
                let appElement = AXUIElementCreateApplication(pid)
                var focusedRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
                   focusedRef != nil {
                    element = unsafeBitCast(focusedRef, to: AXUIElement.self)
                }
            }
        } else {
            // System-wide focused element
            let systemWide = AXUIElementCreateSystemWide()
            var focusedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
               focusedRef != nil {
                element = unsafeBitCast(focusedRef, to: AXUIElement.self)
            }
        }
        
        guard let found = element else {
            return errorJSON("No focused element found")
        }
        
        return successJSON(getAllProperties(found))
    }
    
    // MARK: - Get Children (Phase 6)
    
    /// Get all children of an element
    func getChildren(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?, depth: Int = 3) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("getChildren(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), depth: \(depth))")
        
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
            return errorJSON("Element not found")
        }
        
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXChildrenAttribute as CFString, &childrenRef) != .success {
            return errorJSON("Element has no children")
        }
        
        guard let children = childrenRef as? [AXUIElement] else {
            return errorJSON("Failed to get children")
        }
        
        var results: [[String: Any]] = []
        for child in children {
            results.append(getAllProperties(child))
        }
        
        return successJSON([
            "count": results.count,
            "children": results
        ])
    }
    
    // MARK: - Drag (Phase 6)
    
    /// Perform a drag operation from one point to another
    func drag(fromX: CGFloat, fromY: CGFloat, toX: CGFloat, toY: CGFloat, button: String = "left") -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("drag(from: (\(fromX), \(fromY)), to: (\(toX), \(toY)), button: \(button))")
        
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
        let dragEventType: CGEventType
        switch cgButton {
        case .left:
            downEventType = .leftMouseDown
            upEventType = .leftMouseUp
            dragEventType = .leftMouseDragged
        case .right:
            downEventType = .rightMouseDown
            upEventType = .rightMouseUp
            dragEventType = .rightMouseDragged
        case .center:
            downEventType = .otherMouseDown
            upEventType = .otherMouseUp
            dragEventType = .otherMouseDragged
        @unknown default:
            downEventType = .leftMouseDown
            upEventType = .leftMouseUp
            dragEventType = .leftMouseDragged
        }
        
        // Move to start position
        if let moveEvent = CGEvent(source: source) {
            moveEvent.type = .mouseMoved
            moveEvent.location = CGPoint(x: fromX, y: fromY)
            moveEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
        }
        
        // Small delay to ensure position is set
        Thread.sleep(forTimeInterval: 0.05)
        
        // Mouse down at start
        if let downEvent = CGEvent(source: source) {
            downEvent.type = downEventType
            downEvent.location = CGPoint(x: fromX, y: fromY)
            downEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(cgButton.rawValue))
            downEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
        }
        
        // Animate drag with intermediate points
        let steps = 10
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let currentX = fromX + (toX - fromX) * t
            let currentY = fromY + (toY - fromY) * t
            
            if let dragEvent = CGEvent(source: source) {
                dragEvent.type = dragEventType
                dragEvent.location = CGPoint(x: currentX, y: currentY)
                dragEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(cgButton.rawValue))
                dragEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
            }
            
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        // Mouse up at destination
        if let upEvent = CGEvent(source: source) {
            upEvent.type = upEventType
            upEvent.location = CGPoint(x: toX, y: toY)
            upEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(cgButton.rawValue))
            upEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
        }
        
        return successJSON([
            "message": "Dragged from (\(fromX), \(fromY)) to (\(toX), \(toY))",
            "fromX": fromX,
            "fromY": fromY,
            "toX": toX,
            "toY": toY,
            "button": button
        ])
    }
    
    // MARK: - Wait For Element (Phase 6)
    
    /// Wait for an element to appear, polling periodically
    func waitForElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = automationFinishTimeout, pollInterval: TimeInterval = 0.5) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("waitForElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")
        
        let startTime = Date()
        var attempts = 0
        
        while Date().timeIntervalSince(startTime) < timeout {
            attempts += 1
            
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
            
            if let found = element {
                let elapsed = Date().timeIntervalSince(startTime)
                return successJSON([
                    "message": "Element found",
                    "attempts": attempts,
                    "elapsed": String(format: "%.2f", elapsed),
                    "properties": getAllProperties(found)
                ])
            }
            
            Thread.sleep(forTimeInterval: pollInterval)
        }
        
        return errorJSON("Element not found within \(timeout)s timeout after \(attempts) attempts")
    }
    
    // MARK: - Show Menu (Phase 6)
    
    /// Show context menu for an element
    func showMenu(role: String?, title: String?, value: String?, appBundleId: String?, x: CGFloat?, y: CGFloat?) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && x == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("showMenu(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"))")
        
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
            return errorJSON("Element not found")
        }
        
        // Check for restricted roles
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXRoleAttribute as CFString, &roleRef) == .success,
           let elRole = roleRef as? String, Self.isRestricted(elRole) {
            return errorJSON("Cannot interact with \(elRole) — disabled in Accessibility Access")
        }
        
        // Check if the element supports AXShowMenu
        var actionsRef: CFTypeRef?
        // kAXActionNamesAttribute = "AXActionNames"
        if AXUIElementCopyAttributeValue(found, "AXActionNames" as CFString, &actionsRef) == .success,
           let actions = actionsRef as? [String], actions.contains("AXShowMenu") {
            let result = AXUIElementPerformAction(found, kAXShowMenuAction as CFString)
            if result == .success {
                return successJSON(["message": "Menu shown"])
            } else {
                return errorJSON("AXShowMenu action failed: \(result.rawValue)")
            }
        }
        
        // Fallback: simulate right-click at element position
        var positionRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXPositionAttribute as CFString, &positionRef) == .success,
           let positionValue = positionRef,
           CFGetTypeID(positionValue) == AXValueGetTypeID() {
            var point = CGPoint.zero
            if AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) {
                // Get size for center of element
                var sizeRef: CFTypeRef?
                var width: CGFloat = 1
                var height: CGFloat = 1
                if AXUIElementCopyAttributeValue(found, kAXSizeAttribute as CFString, &sizeRef) == .success,
                   let sizeValue = sizeRef,
                   CFGetTypeID(sizeValue) == AXValueGetTypeID() {
                    var size = CGSize.zero
                    if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                        width = size.width
                        height = size.height
                    }
                }
                
                // Right-click at center of element
                let centerX = point.x + width / 2
                let centerY = point.y + height / 2
                return clickAt(x: centerX, y: centerY, button: "right", clicks: 1)
            }
        }
        
        return errorJSON("Element does not support showing menu and could not determine position")
    }
    
    // MARK: - Smart Element Click (Phase 1 Improvement)
    
    /// Click an element by finding it semantically (role/title) and clicking its center.
    /// This is more reliable than coordinate-based clicking for web automation.
    /// - Parameters:
    ///   - role: Accessibility role to find (e.g., "AXButton", "AXTextField")
    ///   - title: Title or name to match (partial match supported)
    ///   - value: Value content to match (partial match supported)
    ///   - appBundleId: Optional bundle ID to search within a specific app
    ///   - timeout: Maximum time to wait for element to appear (default 5 seconds)
    ///   - verify: Whether to verify the click succeeded via screenshot (default false)
    /// - Returns: JSON result with click position and verification status
    func clickElement(role: String?, title: String?, value: String?, appBundleId: String?, timeout: TimeInterval = automationFinishTimeout, verify: Bool = false) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("clickElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout), verify: \(verify))")
        
        // Find the element
        let startTime = Date()
        var element: AXUIElement?
        
        while Date().timeIntervalSince(startTime) < timeout {
            if let bundleId = appBundleId {
                let apps = NSWorkspace.shared.runningApplications
                if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
                   let pid = app.processIdentifier as pid_t? {
                    element = findElementInApp(pid: pid, role: role, title: title, value: value)
                }
            } else {
                element = findElementGlobally(role: role, title: title, value: value)
            }
            
            if element != nil { break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        guard let found = element else {
            return errorJSON("Element not found within \(timeout)s timeout")
        }
        
        // Check for restricted roles
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(found, kAXRoleAttribute as CFString, &roleRef) == .success,
           let elRole = roleRef as? String, Self.isRestricted(elRole) {
            return errorJSON("Cannot interact with \(elRole) — disabled in Accessibility Access")
        }
        
        // Get element position and size
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(found, kAXPositionAttribute as CFString, &positionRef) == .success,
              let positionValue = positionRef,
              CFGetTypeID(positionValue) == AXValueGetTypeID() else {
            return errorJSON("Could not get element position")
        }
        
        var point = CGPoint.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) else {
            return errorJSON("Could not decode element position")
        }
        
        var width: CGFloat = 1
        var height: CGFloat = 1
        if AXUIElementCopyAttributeValue(found, kAXSizeAttribute as CFString, &sizeRef) == .success,
           let sizeValue = sizeRef,
           CFGetTypeID(sizeValue) == AXValueGetTypeID() {
            var size = CGSize.zero
            if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                width = size.width
                height = size.height
            }
        }
        
        // Calculate center point
        let centerX = point.x + width / 2
        let centerY = point.y + height / 2
        
        // Capture screenshot before click if verifying
        var beforeScreenshot: String? = nil
        if verify {
            beforeScreenshot = captureScreenshot(x: point.x - 5, y: point.y - 5, width: width + 10, height: height + 10)
        }
        
        // Perform the click
        _ = clickAt(x: centerX, y: centerY, button: "left", clicks: 1)
        
        // Small delay for UI to respond
        Thread.sleep(forTimeInterval: 0.1)
        
        var result: [String: Any] = [
            "message": "Clicked element",
            "role": roleRef as? String ?? "Unknown",
            "centerX": centerX,
            "centerY": centerY,
            "width": width,
            "height": height
        ]
        
        // Add verification if requested
        if verify, let before = beforeScreenshot, !before.contains("\"success\": false") {
            result["verification"] = "screenshot_captured"
            result["screenshot_before"] = before
        }
        
        return successJSON(result)
    }
    
    // MARK: - Adaptive Wait for Element (Phase 1 Improvement)
    
    /// Wait for an element to appear with exponential backoff polling.
    /// More efficient than fixed-interval polling for slow-loading content.
    /// - Parameters:
    ///   - role: Accessibility role to find
    ///   - title: Title to match (partial)
    ///   - value: Value to match (partial)
    ///   - appBundleId: Optional bundle ID to search within
    ///   - timeout: Maximum wait time (default 10 seconds)
    ///   - initialDelay: Initial polling delay (default 0.1 seconds)
    ///   - maxDelay: Maximum polling delay (default 1.0 seconds)
    ///   - multiplier: Delay multiplier for backoff (default 1.5)
    /// - Returns: JSON result with found element properties
    func waitForElementAdaptive(
        role: String?,
        title: String?,
        value: String?,
        appBundleId: String?,
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
        Self.logAudit("waitForElementAdaptive(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), timeout: \(timeout))")
        
        let startTime = Date()
        var currentDelay = initialDelay
        var attempts = 0
        var lastError: String? = nil
        
        while Date().timeIntervalSince(startTime) < timeout {
            attempts += 1
            var element: AXUIElement?
            
            if let bundleId = appBundleId {
                let apps = NSWorkspace.shared.runningApplications
                if let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
                   let pid = app.processIdentifier as pid_t? {
                    element = findElementInApp(pid: pid, role: role, title: title, value: value)
                } else {
                    lastError = "App not found: \(bundleId)"
                }
            } else {
                element = findElementGlobally(role: role, title: title, value: value)
            }
            
            if let found = element {
                let elapsed = Date().timeIntervalSince(startTime)
                var props = getAllProperties(found)
                props["found_after_attempts"] = attempts
                props["elapsed_seconds"] = String(format: "%.2f", elapsed)
                props["final_poll_interval"] = String(format: "%.2f", currentDelay)
                return successJSON(props)
            }
            
            // Exponential backoff
            Thread.sleep(forTimeInterval: currentDelay)
            currentDelay = min(currentDelay * multiplier, maxDelay)
        }
        
        let errorMsg = lastError ?? "Element not found"
        return errorJSON("\(errorMsg) within \(timeout)s timeout after \(attempts) attempts (adaptive polling)")
    }
    
    // MARK: - Verification Helpers (Phase 1 Improvement)
    
    /// Capture a verification screenshot after an action
    /// - Parameters:
    ///   - action: Description of the action performed
    ///   - role: Role of element acted upon
    ///   - title: Title of element acted upon
    ///   - appBundleId: Optional bundle ID
    /// - Returns: JSON with screenshot path and element verification
    func captureVerificationScreenshot(action: String, role: String?, title: String?, appBundleId: String?) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("captureVerificationScreenshot(action: \(action))")
        
        // Take fullscreen screenshot
        let screenshotResult = captureAllWindows()
        
        // Try to find the element again for verification
        var elementStatus = "not_verified"
        if (role ?? title) != nil {
            let findResult = findElement(role: role, title: title, value: nil, appBundleId: appBundleId, timeout: 1.0)
            
            if findResult.contains("\"success\": true") {
                elementStatus = "verified_present"
            } else {
                elementStatus = "not_found_after_action"
            }
        }
        
        let result: [String: Any] = [
            "action": action,
            "element_status": elementStatus,
            "screenshot": screenshotResult
        ]
        
        return successJSON(result)
    }
    
    /// Type text into an element with verification
    /// - Parameters:
    ///   - role: Accessibility role of target element
    ///   - title: Title of target element
    ///   - text: Text to type
    ///   - appBundleId: Optional bundle ID
    ///   - verify: Whether to verify the text was entered (default true)
    /// - Returns: JSON result with verification status
    func typeTextIntoElement(role: String?, title: String?, text: String, appBundleId: String?, verify: Bool = true) -> String {
        if Self.isBrowser(appBundleId) || (appBundleId == nil && Self.frontmostAppIsBrowser()) {
            return Self.safariPageInfo()
        }
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("typeTextIntoElement(role: \(role ?? "nil"), title: \(title ?? "nil"), text: \(text.count) chars, verify: \(verify))")
        
        // Find element first
        let findResult = findElement(role: role, title: title, value: nil, appBundleId: appBundleId, timeout: automationStartTimeout)
        
        // Extract position from find result
        guard findResult.contains("\"success\": true") else {
            return errorJSON("Element not found for typing")
        }
        
        // Try to use ax_set_properties for text fields (faster and more reliable)
        let setPropsResult = setProperties(role: role, title: title, value: nil, appBundleId: appBundleId, x: nil, y: nil, properties: ["AXValue": text])
        
        if setPropsResult.contains("\"success\": true") {
            if verify {
                // Verify the value was set
                Thread.sleep(forTimeInterval: 0.2)
                let checkResult: String
                if let bundleId = appBundleId {
                    checkResult = getElementProperties(role: role, title: title, value: nil, appBundleId: bundleId, x: nil, y: nil)
                } else {
                    checkResult = getElementProperties(role: role, title: title, value: nil, appBundleId: nil, x: nil, y: nil)
                }
                
                if checkResult.contains(text) {
                    return successJSON([
                        "message": "Text set via AXValue",
                        "method": "ax_set_properties",
                        "verified": true,
                        "text_length": text.count
                    ])
                } else {
                    // Fall back to CGEvent typing
                    return typeTextFallback(role: role, title: title, text: text, appBundleId: appBundleId)
                }
            }
            
            return successJSON([
                "message": "Text set via AXValue",
                "method": "ax_set_properties",
                "verified": false,
                "text_length": text.count
            ])
        }
        
        // Fall back to CGEvent typing
        return typeTextFallback(role: role, title: title, text: text, appBundleId: appBundleId)
    }
    
    private func typeTextFallback(role: String?, title: String?, text: String, appBundleId: String?) -> String {
        // Find element position and click to focus
        let findResult = findElement(role: role, title: title, value: nil, appBundleId: appBundleId, timeout: automationStartTimeout)
        
        // Parse position from JSON result
        // Look for "AXPosition" : { "x": ..., "y": ... }
        if let range = findResult.range(of: "\"AXPosition\" : \\{[^}]+\\}", options: .regularExpression) {
            let posStr = String(findResult[range])
            if let xRange = posStr.range(of: "\"x\" : ([0-9.]+)", options: .regularExpression),
               let yRange = posStr.range(of: "\"y\" : ([0-9.]+)", options: .regularExpression) {
                let xStr = String(posStr[xRange].split(separator: ":").last ?? "0").trimmingCharacters(in: .whitespaces)
                let yStr = String(posStr[yRange].split(separator: ":").last ?? "0").trimmingCharacters(in: .whitespaces)
                
                if let x = Double(xStr), let y = Double(yStr) {
                    // Click to focus
                    _ = clickAt(x: CGFloat(x), y: CGFloat(y), button: "left", clicks: 1)
                    Thread.sleep(forTimeInterval: 0.1)
                    
                    // Type using CGEvent
                    return typeText(text)
                }
            }
        }
        
        return errorJSON("Could not determine element position for typing")
    }
    
    // MARK: - Frontmost Window

    /// Get the CGWindowID of the frontmost window for targeted screenshots.
    private static func frontmostWindowID() -> UInt32? {
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
    func highlightElement(
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
        Self.logAudit("highlightElement(role: \(role ?? "nil"), title: \(title ?? "nil"), value: \(value ?? "nil"), app: \(appBundleId ?? "nil"), duration: \(duration)s)")
        
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
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) else {
            return errorJSON("Could not decode element position")
        }
        
        // Get size
        if AXUIElementCopyAttributeValue(found, kAXSizeAttribute as CFString, &sizeRef) == .success,
           let sizeValue = sizeRef,
           CFGetTypeID(sizeValue) == AXValueGetTypeID() {
            var size = CGSize.zero
            if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
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
    func getWindowFrame(windowId: Int) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("getWindowFrame(windowId: \(windowId))")
        
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
    func clickMenuItem(appBundleId: String?, menuPath: [String]) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("clickMenuItem(app: \(appBundleId ?? "frontmost"), path: \(menuPath.joined(separator: " > ")))")
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
    func setWindowFrame(appBundleId: String?, x: CGFloat?, y: CGFloat?, width: CGFloat?, height: CGFloat?) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("setWindowFrame(app: \(appBundleId ?? "frontmost"), x: \(x ?? -1), y: \(y ?? -1), w: \(width ?? -1), h: \(height ?? -1))")

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
    func manageApp(action: String, bundleId: String?, name: String?) -> String {
        Self.logAudit("manageApp(action: \(action), bundleId: \(bundleId ?? "nil"), name: \(name ?? "nil"))")

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
    func scrollToElement(role: String?, title: String?, appBundleId: String?, maxScrolls: Int = 20) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("scrollToElement(role: \(role ?? "nil"), title: \(title ?? "nil"), app: \(appBundleId ?? "nil"))")

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
                if let pv = posRef, CFGetTypeID(pv) == AXValueGetTypeID() { AXValueGetValue(pv as! AXValue, .cgPoint, &pos) }
                if let sv = sizeRef, CFGetTypeID(sv) == AXValueGetTypeID() { AXValueGetValue(sv as! AXValue, .cgSize, &size) }
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
    func readFocusedElement(appBundleId: String? = nil) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        Self.logAudit("readFocusedElement(app: \(appBundleId ?? "frontmost"))")

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

    // MARK: - Audit Logging (Phase 5)
    
    private static nonisolated(unsafe) var auditLog: [String] = []
    private static let auditLogLock = NSLock()
    private static let auditLogFile: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/AgentScript/logs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("accessibility_audit.log")
    }()
    
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
    
    func successJSON(_ data: Any) -> String {
        if let d = try? JSONSerialization.data(withJSONObject: ["success": true, "data": data], options: .prettyPrinted),
           let s = String(data: d, encoding: .utf8) { return s }
        return "{\"success\": true}"
    }
    
    func errorJSON(_ msg: String) -> String {
        return "{\"success\": false, \"error\": \"\(msg.replacingOccurrences(of: "\"", with: "\\\""))\"}"
    }
}
