/// AgentAccessibility — Accessibility helpers for AgentScripts.
/// Scripts run in-process (dlopen'd into Agent!) so they inherit TCC permissions.
/// Import this module to get clean wrappers around AXUIElement, CGEvent, etc.

import Foundation
import ApplicationServices
import CoreGraphics

// MARK: - Click

/// Simulate a left-click at the given screen coordinates.
public func axClick(x: Double, y: Double) {
    let point = CGPoint(x: x, y: y)
    let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
    let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}

/// Simulate a right-click at the given screen coordinates.
public func axRightClick(x: Double, y: Double) {
    let point = CGPoint(x: x, y: y)
    let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: point, mouseButton: .right)
    let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: point, mouseButton: .right)
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}

/// Simulate a double-click at the given screen coordinates.
public func axDoubleClick(x: Double, y: Double) {
    let point = CGPoint(x: x, y: y)
    let down1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
    down1?.setIntegerValueField(.mouseEventClickState, value: 1)
    let up1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
    up1?.setIntegerValueField(.mouseEventClickState, value: 1)
    let down2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
    down2?.setIntegerValueField(.mouseEventClickState, value: 2)
    let up2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
    up2?.setIntegerValueField(.mouseEventClickState, value: 2)
    down1?.post(tap: .cghidEventTap)
    up1?.post(tap: .cghidEventTap)
    down2?.post(tap: .cghidEventTap)
    up2?.post(tap: .cghidEventTap)
}

// MARK: - Type Text

/// Simulate typing a string at the current cursor position.
public func axType(_ text: String) {
    for scalar in text.unicodeScalars {
        if scalar == "\n" {
            axPressKey(keyCode: 0x24) // Return
            continue
        }
        if scalar == "\t" {
            axPressKey(keyCode: 0x30) // Tab
            continue
        }
        guard let source = CGEventSource(stateID: .hidSystemState) else { continue }
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        var utf16 = Array(String(scalar).utf16)
        keyDown?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        keyUp?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

// MARK: - Key Press

/// Press a virtual key with optional modifiers.
/// Common key codes: Return=0x24, Tab=0x30, Delete=0x33, Escape=0x35,
/// Left=0x7B, Right=0x7C, Down=0x7D, Up=0x7E, Space=0x31
public func axPressKey(keyCode: CGKeyCode, command: Bool = false, option: Bool = false, control: Bool = false, shift: Bool = false) {
    guard let source = CGEventSource(stateID: .hidSystemState) else { return }
    guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
          let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
    var flags: CGEventFlags = []
    if command { flags.insert(.maskCommand) }
    if option { flags.insert(.maskAlternate) }
    if control { flags.insert(.maskControl) }
    if shift { flags.insert(.maskShift) }
    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}

// MARK: - Scroll

/// Simulate a scroll wheel event at given coordinates.
public func axScroll(x: Double, y: Double, deltaY: Int32 = 0, deltaX: Int32 = 0) {
    let point = CGPoint(x: x, y: y)
    // Move mouse to position first
    if let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
        move.post(tap: .cghidEventTap)
    }
    if let scroll = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0) {
        scroll.post(tap: .cghidEventTap)
    }
}

// MARK: - AXUIElement Helpers

/// Get the AXUIElement at screen coordinates. Returns nil if nothing found.
public func axElementAt(x: Double, y: Double) -> AXUIElement? {
    let systemWide = AXUIElementCreateSystemWide()
    var element: AXUIElement?
    AXUIElementCopyElementAtPosition(systemWide, Float(x), Float(y), &element)
    return element
}

/// Get an attribute value from an AXUIElement.
public func axGetAttribute(_ element: AXUIElement, _ attribute: String) -> Any? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    return result == .success ? value : nil
}

/// Get the role of an AXUIElement (e.g. "AXButton", "AXTextField").
public func axRole(_ element: AXUIElement) -> String? {
    axGetAttribute(element, kAXRoleAttribute as String) as? String
}

/// Get the title of an AXUIElement.
public func axTitle(_ element: AXUIElement) -> String? {
    axGetAttribute(element, kAXTitleAttribute as String) as? String
}

/// Get the value of an AXUIElement.
public func axValue(_ element: AXUIElement) -> Any? {
    axGetAttribute(element, kAXValueAttribute as String)
}

/// Perform an action on an AXUIElement (e.g. "AXPress").
@discardableResult
public func axPerformAction(_ element: AXUIElement, _ action: String) -> Bool {
    AXUIElementPerformAction(element, action as CFString) == .success
}

/// Get all children of an AXUIElement.
public func axChildren(_ element: AXUIElement) -> [AXUIElement] {
    guard let children = axGetAttribute(element, kAXChildrenAttribute as String) as? [AXUIElement] else { return [] }
    return children
}

/// Check if Accessibility permission is granted.
public func axHasPermission() -> Bool {
    AXIsProcessTrusted()
}

// MARK: - Window Listing

/// List visible windows as (ownerName, windowName, windowID, bounds) tuples.
public func axListWindows() -> [(owner: String, name: String, id: Int, bounds: CGRect)] {
    guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
    var results: [(String, String, Int, CGRect)] = []
    for w in windowList {
        guard let wid = w[kCGWindowNumber as String] as? Int,
              let owner = w[kCGWindowOwnerName as String] as? String else { continue }
        let name = w[kCGWindowName as String] as? String ?? ""
        var bounds = CGRect.zero
        if let boundsDict = w[kCGWindowBounds as String] as? [String: Any] {
            bounds = CGRect(
                x: boundsDict["X"] as? CGFloat ?? 0,
                y: boundsDict["Y"] as? CGFloat ?? 0,
                width: boundsDict["Width"] as? CGFloat ?? 0,
                height: boundsDict["Height"] as? CGFloat ?? 0
            )
        }
        results.append((owner, name, wid, bounds))
    }
    return results
}
