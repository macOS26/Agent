@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log

private let taskLog = Logger(subsystem: "Agent.app.toddbruss", category: "AccessibilityTools")

// MARK: - Accessibility Tools

extension AgentViewModel {
    
    // MARK: - Accessibility Tools for Other LLM Providers
    
    /// Handle accessibility tool calls for other LLM providers (Claude, Ollama, etc.)
    func handleAccessibilityToolForLLM(_ name: String, input: sending [String: Any], toolId: String) async -> (output: String, commandsRun: [String]) {
        var commandsRun: [String] = []
        var output = ""
        
        if name == "ax_check_permission" {
            appendLog("🔒 Check Accessibility permission")
            output = AccessibilityService.hasAccessibilityPermission() ? "Accessibility permission granted" : "Accessibility permission not granted"
            appendLog(output)
        }
        
        else if name == "ax_request_permission" {
            appendLog("🔓 Request Accessibility permission")
            let granted = AccessibilityService.requestAccessibilityPermission()
            output = granted ? "Accessibility permission dialog shown" : "Accessibility permission already requested this session — opening System Settings"
            appendLog(output)
        }
        
        else if name == "ax_list_windows" {
            let limit = input["limit"] as? Int ?? 50
            appendLog("🪟 List windows (limit: \(limit))")
            output = AccessibilityService.shared.listWindows(limit: limit)
            appendLog(output)
        }
        
        else if name == "ax_inspect_element" {
            let x = input["x"] as? Double ?? 0
            let y = input["y"] as? Double ?? 0
            let depth = input["depth"] as? Int ?? 3
            appendLog("🔍 Inspect element at (\(x), \(y)) depth \(depth)")
            output = AccessibilityService.shared.inspectElement(x: x, y: y, depth: depth)
            appendLog(output)
        }
        
        else if name == "ax_get_properties" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let x = input["x"] as? Double
            let y = input["y"] as? Double
            let appBundleId = input["appBundleId"] as? String
            appendLog("📋 Get accessibility properties")
            output = AccessibilityService.shared.getProperties(role: role, title: title, value: value, x: x, y: y, appBundleId: appBundleId)
            appendLog(output)
        }
        
        else if name == "ax_perform_action" {
            let action = input["action"] as? String ?? ""
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let x = input["x"] as? Double
            let y = input["y"] as? Double
            let appBundleId = input["appBundleId"] as? String
            appendLog("⚡ Perform action: \(action)")
            output = AccessibilityService.shared.performAction(action: action, role: role, title: title, value: value, x: x, y: y, appBundleId: appBundleId)
            appendLog(output)
        }
        
        else if name == "ax_type_text" {
            let text = input["text"] as? String ?? ""
            let x = input["x"] as? Double
            let y = input["y"] as? Double
            appendLog("⌨️ Type text: \(text.prefix(50))...")
            output = AccessibilityService.shared.typeText(text: text, x: x, y: y)
            appendLog(output)
        }
        
        else if name == "ax_click" {
            let x = input["x"] as? Double ?? 0
            let y = input["y"] as? Double ?? 0
            let button = input["button"] as? String ?? "left"
            let clicks = input["clicks"] as? Int ?? 1
            appendLog("🖱️ Click at (\(x), \(y)) button: \(button) clicks: \(clicks)")
            output = AccessibilityService.shared.click(x: x, y: y, button: button, clicks: clicks)
            appendLog(output)
        }
        
        else if name == "ax_scroll" {
            let x = input["x"] as? Double ?? 0
            let y = input["y"] as? Double ?? 0
            let deltaX = input["deltaX"] as? Int ?? 0
            let deltaY = input["deltaY"] as? Int ?? 0
            appendLog("🖱️ Scroll at (\(x), \(y)) deltaX: \(deltaX) deltaY: \(deltaY)")
            output = AccessibilityService.shared.scroll(x: x, y: y, deltaX: deltaX, deltaY: deltaY)
            appendLog(output)
        }
        
        else if name == "ax_press_key" {
            let keyCode = input["keyCode"] as? Int ?? 0
            let modifiers = input["modifiers"] as? [String] ?? []
            appendLog("⌨️ Press key: \(keyCode) modifiers: \(modifiers)")
            output = AccessibilityService.shared.pressKey(keyCode: keyCode, modifiers: modifiers)
            appendLog(output)
        }
        
        else if name == "ax_screenshot" {
            let x = input["x"] as? Double
            let y = input["y"] as? Double
            let width = input["width"] as? Double
            let height = input["height"] as? Double
            let windowId = input["windowId"] as? Int
            appendLog("📸 Take screenshot")
            output = AccessibilityService.shared.screenshot(x: x, y: y, width: width, height: height, windowId: windowId)
            appendLog(output)
        }
        
        else if name == "ax_get_audit_log" {
            let limit = input["limit"] as? Int ?? 50
            appendLog("📋 Get audit log (limit: \(limit))")
            output = AccessibilityService.shared.getAuditLog(limit: limit)
            appendLog(output)
        }
        
        else if name == "ax_set_properties" {
            guard let properties = input["properties"] as? [String: Any] else {
                return ("Error: properties required", commandsRun)
            }
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let x = input["x"] as? Double
            let y = input["y"] as? Double
            let appBundleId = input["appBundleId"] as? String
            appendLog("✏️ Set accessibility properties")
            output = AccessibilityService.shared.setProperties(properties: properties, role: role, title: title, value: value, x: x, y: y, appBundleId: appBundleId)
            appendLog(output)
        }
        
        else if name == "ax_find_element" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let timeout = input["timeout"] as? Double ?? 5.0
            let appBundleId = input["appBundleId"] as? String
            appendLog("🔍 Find element timeout: \(timeout)s")
            output = AccessibilityService.shared.findElement(role: role, title: title, value: value, timeout: timeout, appBundleId: appBundleId)
            appendLog(output)
        }
        
        else if name == "ax_get_focused_element" {
            let appBundleId = input["appBundleId"] as? String
            appendLog("🎯 Get focused element")
            output = AccessibilityService.shared.getFocusedElement(appBundleId: appBundleId)
            appendLog(output)
        }
        
        else if name == "ax_get_children" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let x = input["x"] as? Double
            let y = input["y"] as? Double
            let depth = input["depth"] as? Int ?? 3
            let appBundleId = input["appBundleId"] as? String
            appendLog("👶 Get children depth: \(depth)")
            output = AccessibilityService.shared.getChildren(role: role, title: title, value: value, x: x, y: y, depth: depth, appBundleId: appBundleId)
            appendLog(output)
        }
        
        else if name == "ax_drag" {
            let fromX = input["fromX"] as? Double ?? 0
            let fromY = input["fromY"] as? Double ?? 0
            let toX = input["toX"] as? Double ?? 0
            let toY = input["toY"] as? Double ?? 0
            let button = input["button"] as? String ?? "left"
            appendLog("🖱️ Drag from (\(fromX), \(fromY)) to (\(toX), \(toY)) button: \(button)")
            output = AccessibilityService.shared.drag(fromX: fromX, fromY: fromY, toX: toX, toY: toY, button: button)
            appendLog(output)
        }
        
        else if name == "ax_wait_for_element" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let timeout = input["timeout"] as? Double ?? 10.0
            let pollInterval = input["pollInterval"] as? Double ?? 0.5
            let appBundleId = input["appBundleId"] as? String
            appendLog("⏳ Wait for element timeout: \(timeout)s poll: \(pollInterval)s")
            output = AccessibilityService.shared.waitForElement(role: role, title: title, value: value, timeout: timeout, pollInterval: pollInterval, appBundleId: appBundleId)
            appendLog(output)
        }
        
        else if name == "ax_click_element" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let timeout = input["timeout"] as? Double ?? 5.0
            let verify = input["verify"] as? Bool ?? false
            let appBundleId = input["appBundleId"] as? String
            appendLog("🖱️ Click element timeout: \(timeout)s")
            output = AccessibilityService.shared.clickElement(role: role, title: title, value: value, timeout: timeout, verify: verify, appBundleId: appBundleId)
            appendLog(output)
        }
        
        else if name == "ax_wait_adaptive" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let timeout = input["timeout"] as? Double ?? 10.0
            let initialDelay = input["initialDelay"] as? Double ?? 0.1
            let maxDelay = input["maxDelay"] as? Double ?? 1.0
            let appBundleId = input["appBundleId"] as? String
            appendLog("⏳ Wait adaptive timeout: \(timeout)s initial: \(initialDelay)s max: \(maxDelay)s")
            output = AccessibilityService.shared.waitAdaptive(role: role, title: title, value: value, timeout: timeout, initialDelay: initialDelay, maxDelay: maxDelay, appBundleId: appBundleId)
            appendLog(output)
        }
        
        else if name == "ax_type_into_element" {
            let text = input["text"] as? String ?? ""
            let role = input["role"] as? String
            let title = input["title"] as? String
            let verify = input["verify"] as? Bool ?? true
            let appBundleId = input["appBundleId"] as? String
            appendLog("⌨️ Type into element: \(text.prefix(50))...")
            output = AccessibilityService.shared.typeIntoElement(text: text, role: role, title: title, verify: verify, appBundleId: appBundleId)
            appendLog(output)
        }
        
        else if name == "ax_highlight_element" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let x = input["x"] as? Double
            let y = input["y"] as? Double
            let color = input["color"] as? String ?? "green"
            let duration = input["duration"] as? Double ?? 2.0
            let appBundleId = input["appBundleId"] as? String
            appendLog("🟢 Highlight element color: \(color) duration: \(duration)s")
            output = AccessibilityService.shared.highlightElement(role: role, title: title, value: value, x: x, y: y, color: color, duration: duration, appBundleId: appBundleId)
            appendLog(output)
        }
        
        else if name == "ax_get_window_frame" {
            let windowId = input["windowId"] as? Int ?? 0
            appendLog("🪟 Get window frame: \(windowId)")
            output = AccessibilityService.shared.getWindowFrame(windowId: windowId)
            appendLog(output)
        }
        
        else if name == "ax_show_menu" {
            let role = input["role"] as? String
            let title = input["title"] as? String
            let value = input["value"] as? String
            let x = input["x"] as? Double
            let y = input["y"] as? Double
            let appBundleId = input["appBundleId"] as? String
            appendLog("📋 Show menu")
            output = AccessibilityService.shared.showMenu(role: role, title: title, value: value, x: x, y: y, appBundleId: appBundleId)
            appendLog(output)
        }
        
        return (output, commandsRun)
    }
}