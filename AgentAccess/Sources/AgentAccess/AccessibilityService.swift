import AgentAudit
import AXorcist
import Foundation
import AppKit

/// Accessibility automation service for interacting with UI elements via AXorcist.
/// Provides tools for window listing, element inspection, and UI interaction.
public final class AccessibilityService: @unchecked Sendable {
    public static let shared = AccessibilityService()

    // MARK: - Browser Detection

    private static let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
    ]

    public static func isBrowser(_ bundleId: String?) -> Bool {
        guard let bid = bundleId else { return false }
        return browserBundleIDs.contains(bid)
    }

    @MainActor
    public static func frontmostAppIsBrowser() -> Bool {
        guard let bid = RunningApplicationHelper.frontmostApplication?.bundleIdentifier else { return false }
        return browserBundleIDs.contains(bid)
    }

    public static func safariPageInfo() -> String {
        return "Error: Safari/browser detected. Do not use accessibility for web pages. Use the web tool: web(action: \"scan\") to find inputs/buttons, web(action: \"open\", url: \"...\"), web(action: \"type\", selector: \"...\", text: \"...\"), web(action: \"click\", selector: \"...\"), web(action: \"read_content\")."
    }

    // MARK: - Window Listing

    @MainActor
    public func listWindows(limit: Int = 50) -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility permission required.")
        }
        AuditLog.log(.accessibility, "listWindows(limit: \(limit))")

        let windows = WindowInfoHelper.getVisibleWindows() ?? []

        var results: [[String: Any]] = []
        for (index, window) in windows.enumerated() {
            guard index < limit else { break }
            guard let windowID = window[CFConstants.cgWindowNumber] as? Int,
                  let ownerPID = window[CFConstants.cgWindowOwnerPID] as? Int32,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer >= 0 else { continue }

            let ownerName = window[CFConstants.cgWindowName] as? String ?? ""
            let windowName = window[CFConstants.cgWindowName] as? String ?? ""
            let appName = getProcessName(pid: ownerPID) ?? ownerName

            var windowInfo: [String: Any] = [:]
            windowInfo["windowId"] = windowID
            windowInfo["ownerPID"] = Int(ownerPID)
            windowInfo["ownerName"] = appName
            windowInfo["windowName"] = windowName
            windowInfo["layer"] = layer

            var boundsInfo: [String: CGFloat] = [:]
            if let bounds = window[CFConstants.cgWindowBounds] as? [String: CGFloat] {
                boundsInfo["x"] = bounds["X"] ?? 0
                boundsInfo["y"] = bounds["Y"] ?? 0
                boundsInfo["width"] = bounds["Width"] ?? 0
                boundsInfo["height"] = bounds["Height"] ?? 0
            }
            windowInfo["bounds"] = boundsInfo

            results.append(windowInfo)
        }

        let response: [String: Any] = ["windows": results, "count": results.count]
        return successJSON(response)
    }

    // MARK: - AXorcist Helpers

    /// Build an AXorcist Locator from role/title/value/description criteria with flexible matching.
    @MainActor
    public func buildLocator(role: String? = nil, title: String? = nil, value: String? = nil, description: String? = nil, identifier: String? = nil) -> Locator {
        var criteria: [Criterion] = []
        if let role = role {
            criteria.append(Criterion(attribute: "AXRole", value: role))
        }
        if let title = title {
            criteria.append(Criterion(attribute: "AXTitle", value: title, matchType: .contains))
        }
        if let value = value {
            criteria.append(Criterion(attribute: "AXValue", value: value, matchType: .contains))
        }
        if let description = description {
            criteria.append(Criterion(attribute: "AXDescription", value: description, matchType: .contains))
        }
        if let identifier = identifier {
            criteria.append(Criterion(attribute: "AXIdentifier", value: identifier))
        }
        return Locator(matchAll: true, criteria: criteria)
    }

    /// Find an AXorcist Element using role/title/value in a specific app or globally.
    @MainActor
    public func findAXElement(role: String?, title: String?, value: String?, appBundleId: String?) -> Element? {
        if let bundleId = appBundleId {
            guard let app = RunningApplicationHelper.applications(withBundleIdentifier: bundleId).first,
                  let appElement = Element.application(for: app) else { return nil }
            return searchInElement(appElement, role: role, title: title, value: value)
        } else if let frontApp = RunningApplicationHelper.frontmostApplication,
                  let appElement = Element.application(for: frontApp) {
            return searchInElement(appElement, role: role, title: title, value: value)
        }
        // Global search across all running apps
        for app in RunningApplicationHelper.filteredApplications(options: .init(excludeProhibitedApps: true)) {
            guard app.activationPolicy == .regular,
                  let appElement = Element.application(for: app) else { continue }
            if let found = searchInElement(appElement, role: role, title: title, value: value) {
                return found
            }
        }
        return nil
    }

    /// Search within an Element hierarchy using AXorcist's flexible matching.
    @MainActor
    private func searchInElement(_ root: Element, role: String?, title: String?, value: String?) -> Element? {
        // Use AXorcist's findElements for multi-criteria search
        let results = root.findElements(
            role: role,
            title: title,
            label: nil,
            value: value,
            identifier: nil,
            maxDepth: 100
        )
        // If title search by exact match failed, try description-based search
        if results.isEmpty, let title = title {
            // Fall back to AXorcist's string-based search which checks description, help, etc.
            var options = ElementSearchOptions()
            options.maxDepth = 100
            options.caseInsensitive = true
            if let role = role {
                options.includeRoles = [role]
            }
            return root.findElement(matching: title, options: options)
        }
        return results.first
    }

    /// Convert an AXorcist Element's properties to a dictionary for JSON output.
    @MainActor
    public func elementProperties(_ element: Element) -> [String: Any] {
        var result: [String: Any] = [:]
        if let role = element.role() { result["AXRole"] = role }
        if let title = element.title() { result["AXTitle"] = title }
        if let desc = element.descriptionText() { result["AXDescription"] = desc }
        if let roleDesc = element.roleDescription() { result["AXRoleDescription"] = roleDesc }
        if let sub = element.subrole() { result["AXSubrole"] = sub }
        if let ident = element.identifier() { result["AXIdentifier"] = ident }
        if let help = element.help() { result["AXHelp"] = help }
        if let enabled = element.isEnabled() { result["AXEnabled"] = enabled }
        if let focused = element.isFocused() { result["AXFocused"] = focused }
        if let hidden = element.isHidden() { result["AXHidden"] = hidden }
        if let pos = element.position() { result["AXPosition"] = ["x": pos.x, "y": pos.y] }
        if let sz = element.size() { result["AXSize"] = ["width": sz.width, "height": sz.height] }
        if let val = element.value() {
            if let s = val as? String { result["AXValue"] = s }
            else if let n = val as? NSNumber { result["AXValue"] = n }
            else { result["AXValue"] = String(describing: val) }
        }
        if let url = element.url() { result["AXURL"] = url.absoluteString }
        if let placeholder = element.placeholderValue() { result["AXPlaceholderValue"] = placeholder }
        return result
    }

    // MARK: - Helpers

    @MainActor
    public func getProcessName(pid: pid_t) -> String? {
        guard let app = RunningApplicationHelper.runningApplication(pid: pid) else { return nil }
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
