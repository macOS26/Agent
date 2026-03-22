import Foundation
import os.log

private let automationLog = Logger(subsystem: "Agent.app.toddbruss", category: "AutomationTools")

// MARK: - Automation Tools Extension (Apple Events, Xcode, Accessibility)
extension AgentViewModel {

    // MARK: - Apple Event Query Tool

    /// Handle apple_event_query tool
    func handleAppleEventQuery(input: [String: Any], toolId: String) async -> [String: Any] {
        let bundleID = input["bundle_id"] as? String ?? ""
        let operations: [[String: Any]]
        
        if let ops = input["operations"] as? [[String: Any]] {
            operations = ops
        } else if let action = input["action"] as? String {
            var op: [String: Any] = ["action": action]
            if let key = input["key"] as? String { op["key"] = key }
            if let props = input["properties"] as? String {
                op["properties"] = props.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            if let limit = input["limit"] as? Int { op["limit"] = limit }
            if let index = input["index"] as? Int { op["index"] = index }
            if let method = input["method"] as? String { op["method"] = method }
            if let arg = input["arg"] as? String { op["arg"] = arg }
            if let predicate = input["predicate"] as? String { op["predicate"] = predicate }
            operations = [op]
        } else {
            appendLog("Error: action is required")
            return ["type": "tool_result", "tool_use_id": toolId, "content": "Error: action is required"]
        }
        
        let action = input["action"] as? String ?? operations.first?["action"] as? String ?? "?"
        let key = input["key"] as? String ?? operations.first?["key"] as? String ?? ""
        appendLog("🍎 AE: \(bundleID) → \(action) \(key)")
        flushLog()
        
        let opsData = try? JSONSerialization.data(withJSONObject: operations)
        let output = await Self.offMain {
            guard let data = opsData,
                  let ops = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return "Error: failed to process operations"
            }
            return AppleEventService.shared.execute(bundleID: bundleID, operations: ops)
        }
        appendLog(output)
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    // MARK: - Xcode ScriptingBridge Tools

    /// Handle xcode_grant_permission tool
    func handleXcodeGrantPermission(toolId: String) async -> [String: Any] {
        appendLog("Granting Xcode Automation permission...")
        flushLog()
        let output = await Self.offMain { XcodeService.shared.grantPermission() }
        appendLog(output)
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle xcode_build tool
    func handleXcodeBuild(projectPath: String, toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        appendLog("🔨 Building: \(projectPath)")
        flushLog()
        let output = await Self.offMain { XcodeService.shared.buildProject(projectPath: projectPath) }
        appendLog(output)
        commandsRun.append("xcode_build: \(projectPath)")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle xcode_run tool
    func handleXcodeRun(projectPath: String, toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        appendLog("🔨 Running: \(projectPath)")
        flushLog()
        let output = await Self.offMain { XcodeService.shared.runProject(projectPath: projectPath) }
        appendLog(output)
        commandsRun.append("xcode_run: \(projectPath)")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle xcode_list_projects tool
    func handleXcodeListProjects(toolId: String) async -> [String: Any] {
        appendLog("Listing open Xcode projects...")
        let output = await Self.offMain { XcodeService.shared.listProjects() }
        appendLog(output)
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle xcode_select_project tool
    func handleXcodeSelectProject(number: Int, toolId: String) async -> [String: Any] {
        appendLog("Selecting project #\(number)")
        let output = await Self.offMain { XcodeService.shared.selectProject(number: number) }
        appendLog(output)
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    // MARK: - Accessibility Tools - Core

    /// Handle ax_check_permission tool
    func handleAxCheckPermission(toolId: String) async -> [String: Any] {
        let hasPermission = AccessibilityService.hasAccessibilityPermission()
        let output = hasPermission
            ? "Accessibility permission: granted"
            : "Accessibility permission: NOT granted. Use ax_request_permission to prompt the user."
        appendLog(output)
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_request_permission tool
    func handleAxRequestPermission(toolId: String) async -> [String: Any] {
        appendLog("♿️ Requesting Accessibility permission...")
        let granted = AccessibilityService.requestAccessibilityPermission()
        let output = granted
            ? "Accessibility permission granted!"
            : "Accessibility permission denied. Please enable it in System Settings > Privacy & Security > Accessibility."
        appendLog(output)
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_list_windows tool
    func handleAxListWindows(limit: Int, toolId: String) async -> [String: Any] {
        appendLog("Listing windows (limit: \(limit))...")
        flushLog()
        let output = await Self.offMain { AccessibilityService.shared.listWindows(limit: limit) }
        appendLog(Self.preview(output, lines: 20))
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_inspect_element tool
    func handleAxInspectElement(x: Double, y: Double, depth: Int, toolId: String) async -> [String: Any] {
        appendLog("♿️ Inspecting element at (\(x), \(y))...")
        flushLog()
        let output = await Self.offMain { AccessibilityService.shared.inspectElementAt(x: CGFloat(x), y: CGFloat(y), depth: depth) }
        appendLog(Self.preview(output, lines: 30))
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_get_properties tool
    func handleAxGetProperties(input: [String: Any], toolId: String) async -> [String: Any] {
        let role = input["role"] as? String
        let title = input["title"] as? String
        let value = input["value"] as? String
        let appBundleId = input["appBundleId"] as? String
        let x = (input["x"] as? Double).map { CGFloat($0) }
        let y = (input["y"] as? Double).map { CGFloat($0) }
        
        appendLog("Getting element properties...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.getElementProperties(
                role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y
            )
        }
        appendLog(Self.preview(output, lines: 30))
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_perform_action tool
    func handleAxPerformAction(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        let action = input["action"] as? String ?? ""
        let role = input["role"] as? String
        let title = input["title"] as? String
        let value = input["value"] as? String
        let appBundleId = input["appBundleId"] as? String
        let x = (input["x"] as? Double).map { CGFloat($0) }
        let y = (input["y"] as? Double).map { CGFloat($0) }
        
        appendLog("Performing action: \(action)...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.performAction(
                role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y,
                action: action
            )
        }
        appendLog(output)
        commandsRun.append("ax_perform_action: \(action)")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    // MARK: - Accessibility Tools - Input Simulation

    /// Handle ax_type_text tool
    func handleAxTypeText(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        let text = input["text"] as? String ?? ""
        let x = (input["x"] as? Double).map { CGFloat($0) }
        let y = (input["y"] as? Double).map { CGFloat($0) }
        
        appendLog("Typing: \(text.count) characters...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.typeText(text, at: x, y: y)
        }
        appendLog(output)
        commandsRun.append("ax_type_text")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_click tool
    func handleAxClick(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        guard let xVal = input["x"] as? Double,
              let yVal = input["y"] as? Double else {
            return ["type": "tool_result", "tool_use_id": toolId, "content": "Error: x and y coordinates are required"]
        }
        let x = CGFloat(xVal)
        let y = CGFloat(yVal)
        let button = input["button"] as? String ?? "left"
        let clicks = input["clicks"] as? Int ?? 1
        
        appendLog("♿️ Clicking at (\(x), \(y))...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.clickAt(x: x, y: y, button: button, clicks: clicks)
        }
        appendLog(output)
        commandsRun.append("ax_click")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_scroll tool
    func handleAxScroll(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        guard let xVal = input["x"] as? Double,
              let yVal = input["y"] as? Double else {
            return ["type": "tool_result", "tool_use_id": toolId, "content": "Error: x and y coordinates are required"]
        }
        let x = CGFloat(xVal)
        let y = CGFloat(yVal)
        let deltaX = input["deltaX"] as? Int ?? 0
        let deltaY = input["deltaY"] as? Int ?? 0
        
        appendLog("♿️ Scrolling at (\(x), \(y))...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.scrollAt(x: x, y: y, deltaX: deltaX, deltaY: deltaY)
        }
        appendLog(output)
        commandsRun.append("ax_scroll")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_press_key tool
    func handleAxPressKey(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        guard let keyCodeVal = input["keyCode"] as? Int else {
            return ["type": "tool_result", "tool_use_id": toolId, "content": "Error: keyCode is required"]
        }
        let keyCode = UInt16(keyCodeVal)
        let modifiers = input["modifiers"] as? [String] ?? []
        
        appendLog("♿️ Pressing key code: \(keyCodeVal)...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.pressKey(virtualKey: keyCode, modifiers: modifiers)
        }
        appendLog(output)
        commandsRun.append("ax_press_key")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_screenshot tool
    func handleAxScreenshot(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        let x = (input["x"] as? Double).map { CGFloat($0) }
        let y = (input["y"] as? Double).map { CGFloat($0) }
        let width = (input["width"] as? Double).map { CGFloat($0) }
        let height = (input["height"] as? Double).map { CGFloat($0) }
        let windowId = input["windowId"] as? Int
        
        appendLog("Capturing screenshot...")
        flushLog()
        
        let output: String
        if let wid = windowId, wid > 0 {
            output = await Self.offMain {
                AccessibilityService.shared.captureScreenshot(windowID: wid)
            }
        } else if let x = x, let y = y, let w = width, let h = height {
            output = await Self.offMain {
                AccessibilityService.shared.captureScreenshot(x: x, y: y, width: w, height: h)
            }
        } else {
            output = await Self.offMain {
                AccessibilityService.shared.captureAllWindows()
            }
        }
        
        if output.contains("\"path\"") {
            appendLog("♿️ Screenshot captured successfully")
        } else {
            appendLog(output)
        }
        commandsRun.append("ax_screenshot")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    // MARK: - Accessibility Tools - Advanced

    /// Handle ax_get_audit_log tool
    func handleAxGetAuditLog(limit: Int, toolId: String) async -> [String: Any] {
        appendLog("Getting accessibility audit log...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.getAuditLog(limit: limit)
        }
        appendLog(Self.preview(output, lines: 30))
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_set_properties tool
    func handleAxSetProperties(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        guard let propertiesInput = input["properties"] as? [String: Any], !propertiesInput.isEmpty else {
            return ["type": "tool_result", "tool_use_id": toolId, "content": "Error: properties dictionary is required"]
        }
        let role = input["role"] as? String
        let title = input["title"] as? String
        let value = input["value"] as? String
        let appBundleId = input["appBundleId"] as? String
        let x = (input["x"] as? Double).map { CGFloat($0) }
        let y = (input["y"] as? Double).map { CGFloat($0) }
        
        appendLog("Setting element properties...")
        flushLog()
        let propertiesData = try? JSONSerialization.data(withJSONObject: propertiesInput)
        let output = await Self.offMain {
            guard let data = propertiesData,
                  let properties = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return "{\"success\": false, \"error\": \"Failed to serialize properties\"}"
            }
            return AccessibilityService.shared.setProperties(
                role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y,
                properties: properties
            )
        }
        appendLog(output)
        commandsRun.append("ax_set_properties")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_find_element tool
    func handleAxFindElement(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        let role = input["role"] as? String
        let title = input["title"] as? String
        let value = input["value"] as? String
        let appBundleId = input["appBundleId"] as? String
        let timeout = input["timeout"] as? Double ?? 5.0
        
        appendLog("Finding element...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.findElement(
                role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout
            )
        }
        appendLog(Self.preview(output, lines: 30))
        commandsRun.append("ax_find_element")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_get_focused_element tool
    func handleAxGetFocusedElement(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        let appBundleId = input["appBundleId"] as? String
        appendLog("Getting focused element...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.getFocusedElement(appBundleId: appBundleId)
        }
        appendLog(Self.preview(output, lines: 30))
        commandsRun.append("ax_get_focused_element")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_get_children tool
    func handleAxGetChildren(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        let role = input["role"] as? String
        let title = input["title"] as? String
        let value = input["value"] as? String
        let appBundleId = input["appBundleId"] as? String
        let x = (input["x"] as? Double).map { CGFloat($0) }
        let y = (input["y"] as? Double).map { CGFloat($0) }
        let depth = input["depth"] as? Int ?? 3
        
        appendLog("Getting element children...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.getChildren(
                role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y, depth: depth
            )
        }
        appendLog(Self.preview(output, lines: 30))
        commandsRun.append("ax_get_children")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_drag tool
    func handleAxDrag(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        guard let fromXVal = input["fromX"] as? Double,
              let fromYVal = input["fromY"] as? Double,
              let toXVal = input["toX"] as? Double,
              let toYVal = input["toY"] as? Double else {
            return ["type": "tool_result", "tool_use_id": toolId, "content": "Error: fromX, fromY, toX, toY coordinates are required"]
        }
        let fromX = CGFloat(fromXVal)
        let fromY = CGFloat(fromYVal)
        let toX = CGFloat(toXVal)
        let toY = CGFloat(toYVal)
        let button = input["button"] as? String ?? "left"
        
        appendLog("Dragging from (\(fromX), \(fromY)) to (\(toX), \(toY))...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.drag(fromX: fromX, fromY: fromY, toX: toX, toY: toY, button: button)
        }
        appendLog(output)
        commandsRun.append("ax_drag")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_wait_for_element tool
    func handleAxWaitForElement(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        let role = input["role"] as? String
        let title = input["title"] as? String
        let value = input["value"] as? String
        let appBundleId = input["appBundleId"] as? String
        let timeout = input["timeout"] as? Double ?? 10.0
        let pollInterval = input["pollInterval"] as? Double ?? 0.5
        
        appendLog("Waiting for element (timeout: \(timeout)s)...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.waitForElement(
                role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout, pollInterval: pollInterval
            )
        }
        appendLog(Self.preview(output, lines: 30))
        commandsRun.append("ax_wait_for_element")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_click_element tool
    func handleAxClickElement(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        let role = input["role"] as? String
        let title = input["title"] as? String
        let value = input["value"] as? String
        let appBundleId = input["appBundleId"] as? String
        let timeout = input["timeout"] as? Double ?? 5.0
        let verify = input["verify"] as? Bool ?? false
        
        appendLog("Clicking element (role: \(role ?? "any"), title: \(title ?? "any"))...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.clickElement(
                role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout, verify: verify
            )
        }
        appendLog(Self.preview(output, lines: 30))
        commandsRun.append("ax_click_element")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_wait_adaptive tool
    func handleAxWaitAdaptive(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        let role = input["role"] as? String
        let title = input["title"] as? String
        let value = input["value"] as? String
        let appBundleId = input["appBundleId"] as? String
        let timeout = input["timeout"] as? Double ?? 10.0
        let initialDelay = input["initialDelay"] as? Double ?? 0.1
        let maxDelay = input["maxDelay"] as? Double ?? 1.0
        
        appendLog("Waiting for element (adaptive, timeout: \(timeout)s)...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.waitForElementAdaptive(
                role: role, title: title, value: value, appBundleId: appBundleId, timeout: timeout,
                initialDelay: initialDelay, maxDelay: maxDelay
            )
        }
        appendLog(Self.preview(output, lines: 30))
        commandsRun.append("ax_wait_adaptive")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_type_into_element tool
    func handleAxTypeIntoElement(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        let role = input["role"] as? String
        let title = input["title"] as? String
        let text = input["text"] as? String ?? ""
        let appBundleId = input["appBundleId"] as? String
        let verify = input["verify"] as? Bool ?? true
        
        appendLog("Typing \(text.count) chars into element...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.typeTextIntoElement(
                role: role, title: title, text: text, appBundleId: appBundleId, verify: verify
            )
        }
        appendLog(Self.preview(output, lines: 30))
        commandsRun.append("ax_type_into_element")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_highlight_element tool
    func handleAxHighlightElement(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        let role = input["role"] as? String
        let title = input["title"] as? String
        let value = input["value"] as? String
        let appBundleId = input["appBundleId"] as? String
        let x = (input["x"] as? Double).map { CGFloat($0) }
        let y = (input["y"] as? Double).map { CGFloat($0) }
        let duration = input["duration"] as? Double ?? 2.0
        let color = input["color"] as? String ?? "green"
        
        appendLog("Highlighting element (duration: \(duration)s, color: \(color))...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.highlightElement(
                role: role, title: title, value: value, appBundleId: appBundleId,
                x: x, y: y, duration: duration, color: color
            )
        }
        appendLog(Self.preview(output, lines: 30))
        commandsRun.append("ax_highlight_element")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_get_window_frame tool
    func handleAxGetWindowFrame(windowId: Int, toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        appendLog("Getting frame for window \(windowId)...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.getWindowFrame(windowId: windowId)
        }
        appendLog(output)
        commandsRun.append("ax_get_window_frame")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }

    /// Handle ax_show_menu tool
    func handleAxShowMenu(input: [String: Any], toolId: String, commandsRun: inout [String]) async -> [String: Any] {
        let role = input["role"] as? String
        let title = input["title"] as? String
        let value = input["value"] as? String
        let appBundleId = input["appBundleId"] as? String
        let x = (input["x"] as? Double).map { CGFloat($0) }
        let y = (input["y"] as? Double).map { CGFloat($0) }
        
        appendLog("Showing context menu...")
        flushLog()
        let output = await Self.offMain {
            AccessibilityService.shared.showMenu(
                role: role, title: title, value: value, appBundleId: appBundleId, x: x, y: y
            )
        }
        appendLog(output)
        commandsRun.append("ax_show_menu")
        return ["type": "tool_result", "tool_use_id": toolId, "content": output]
    }
}