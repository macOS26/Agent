import AgentAudit
import Foundation
import AppKit
@preconcurrency import ApplicationServices

/// Accessibility automation service for interacting with UI elements via the Accessibility API.
/// Provides tools for window listing, element inspection, and UI interaction.
public final class AccessibilityService: @unchecked Sendable {
    public static let shared = AccessibilityService()

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
    public static func isBrowser(_ bundleId: String?) -> Bool {
        guard let bid = bundleId else { return false }
        return browserBundleIDs.contains(bid)
    }

    /// Check if the frontmost app is a web browser.
    public static func frontmostAppIsBrowser() -> Bool {
        guard let bid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return browserBundleIDs.contains(bid)
    }

    /// When accessibility targets Safari, redirect to the web tool.
    public static func safariPageInfo() -> String {
        return "Error: Safari/browser detected. Do not use accessibility for web pages. Use the web tool: web(action: \"scan\") to find inputs/buttons, web(action: \"open\", url: \"...\"), web(action: \"type\", selector: \"...\", text: \"...\"), web(action: \"click\", selector: \"...\"), web(action: \"read_content\")."
    }

    // MARK: - Window Listing

    /// List all visible windows from all applications
    public func listWindows(limit: Int = 50) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "listWindows(limit: \(limit))")

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

        let response: [String: Any] = ["windows": results, "count": results.count]
        return successJSON(response)
    }

    // MARK: - Helpers

    public func getProcessName(pid: pid_t) -> String? {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        return app.localizedName ?? app.bundleIdentifier
    }

    public func successJSON(_ data: Any) -> String {
        if let d = try? JSONSerialization.data(withJSONObject: ["success": true, "data": data], options: .prettyPrinted),
           let s = String(data: d, encoding: .utf8) { return s }
        return "{\"success\": true}"
    }

    public func errorJSON(_ msg: String) -> String {
        return "{\"success\": false, \"error\": \"\(msg.replacingOccurrences(of: "\"", with: "\\\""))\"}"
    }
}
