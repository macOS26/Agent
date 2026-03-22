import Foundation
import AppKit
@preconcurrency import ApplicationServices

/// Accessibility automation service - Core permissions and window listing
extension AccessibilityService {
    
    // MARK: - Security
    
    /// Cached permission — once granted, skip repeated AXIsProcessTrusted() calls.
    /// Rebuilds in Xcode change the binary signature, causing macOS TCC to revoke trust.
    /// Caching prevents the LLM from re-triggering the dialog on every tool call within a session.
    private static nonisolated(unsafe) var _permissionGranted = false
    
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
    /// Only IDs in the known enabled list can be restricted. Unknown IDs are allowed.
    static func isRestricted(_ id: String) -> Bool {
        // IDs not in the known enabled list are always allowed
        guard AccessibilityEnabledIDs.allAxIds.contains(id) else {
            return false
        }
        // Use the shared enabled key constant for consistency
        guard let enabled = UserDefaults.standard.stringArray(forKey: axEnabledKey) else {
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
    
    // MARK: - Get Window Frame
    
    /// Get the exact position and frame of a window by its ID.
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
    
    // MARK: - Frontmost Window
    
    /// Get the CGWindowID of the frontmost window for targeted screenshots.
    static func frontmostWindowID() -> UInt32? {
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
    
    // MARK: - Helpers
    
    func getProcessName(pid: pid_t) -> String? {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        return app.localizedName ?? app.bundleIdentifier
    }
}