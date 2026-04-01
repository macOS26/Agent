import AgentAudit
import Foundation
import AppKit
@preconcurrency import ApplicationServices

// MARK: - Security Extension for AccessibilityService

extension AccessibilityService {
    
    // MARK: - Cached Permission State
    
    /// Cached permission — once granted, skip repeated AXIsProcessTrusted() calls.
    /// Rebuilds in Xcode change the binary signature, causing macOS TCC to revoke trust.
    /// Caching prevents the LLM from re-triggering the dialog on every tool call within a session.
    private nonisolated(unsafe) static var _permissionGranted = false
    private nonisolated(unsafe) static var _promptShown = false

    // MARK: - Permission Methods
    
    /// Check if the app has Accessibility permissions (cached once granted)
    public static func hasAccessibilityPermission() -> Bool {
        if _permissionGranted { return true }
        let granted = AXIsProcessTrusted()
        if granted { _permissionGranted = true }
        return granted
    }

    /// Request Accessibility permissions — opens System Settings directly.
    /// Only shows the system dialog once per session to avoid repeated prompts.
    /// Starts polling — if the user grants permission, the app restarts automatically.
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
            // Start polling for permission grant → auto-relaunch
            startPermissionPolling()
            return false
        }
        // Already showed dialog this session — just open System Settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        // Start polling in case user toggles it on
        startPermissionPolling()
        return false
    }

    /// Polls AXIsProcessTrusted every 2 seconds. When permission is granted, relaunches the app.
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

    /// Relaunch the app by spawning a new instance and terminating the current one.
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
    
    /// Check whether an ID is restricted. Reads UserDefaults directly (thread-safe).
    /// Only IDs in the known enabled list can be restricted. Unknown IDs are allowed.
    public static func isRestricted(_ id: String) -> Bool {
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
}