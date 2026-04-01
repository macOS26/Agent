import AgentAudit
import AXorcist
import Foundation
import AppKit
@preconcurrency import ApplicationServices

// MARK: - Security Extension for AccessibilityService

extension AccessibilityService {

    // MARK: - Cached Permission State

    private nonisolated(unsafe) static var _permissionGranted = false
    private nonisolated(unsafe) static var _promptShown = false

    // MARK: - Permission Methods

    /// Check if the app has Accessibility permissions (cached once granted).
    public static func hasAccessibilityPermission() -> Bool {
        if _permissionGranted { return true }
        let granted = AXIsProcessTrusted()
        if granted { _permissionGranted = true }
        return granted
    }

    /// Request Accessibility permissions — opens System Settings directly.
    public static func requestAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            _permissionGranted = true
            return true
        }
        if !_promptShown {
            _promptShown = true
            let promptKey = "AXTrustedCheckOptionPrompt" as CFString
            let options: [CFString: Bool] = [promptKey: true]
            let result = AXIsProcessTrustedWithOptions(options as CFDictionary)
            if result { _permissionGranted = true; return true }
            startPermissionPolling()
            return false
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startPermissionPolling()
        return false
    }

    private nonisolated(unsafe) static var _pollingTask: Task<Void, Never>?

    private static func startPermissionPolling() {
        guard _pollingTask == nil else { return }
        _pollingTask = Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if AXIsProcessTrusted() {
                    await MainActor.run { relaunchApp() }
                    return
                }
            }
        }
    }

    @MainActor
    private static func relaunchApp() {
        guard let bundleURL = Bundle.main.bundleURL as URL? else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    /// Check whether an ID is restricted.
    public static func isRestricted(_ id: String) -> Bool {
        guard AccessibilityEnabledIDs.allAxIds.contains(id) else { return false }
        guard let enabled = UserDefaults.standard.stringArray(forKey: axEnabledKey) else { return false }
        return !enabled.contains(id)
    }
}
