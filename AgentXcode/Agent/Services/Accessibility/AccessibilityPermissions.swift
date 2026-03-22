import Foundation
import AppKit
@preconcurrency import ApplicationServices

/// Permission and security utilities for Accessibility API.
/// Handles permission checks and manages restriction settings.
enum AccessibilityPermissions {
    
    // MARK: - Permission State
    
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
    
    // MARK: - Restrictions
    
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
}