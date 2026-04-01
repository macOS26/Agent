import AgentAccess
import SwiftUI

// MARK: - UserDefaults Keys (nonisolated for thread-safe access)

/// UserDefaults key for Accessibility enabled actions/roles - stores IDs as ["yes", "yes", ...]
let axEnabledKey = "AccessibilityEnabled"

/// UserDefaults key for Apple Events enabled selectors - stores IDs as ["yes", "yes", ...]
let aeEnabledKey = "AppleEventsEnabled"

// MARK: - Known Enabled IDs (nonisolated for thread-safe access)

/// All known Accessibility enabled IDs - computed from static lists at compile time
/// This is nonisolated so it can be accessed from any thread without MainActor
enum AccessibilityEnabledIDs {
    /// Core UI actions - buttons, menus, controls
    static let axCoreActions: [(id: String, label: String)] = [
        ("AXPress", "AXPress"),
        ("AXConfirm", "AXConfirm"),
        ("AXActivate", "AXActivate"),
        ("AXCancel", "AXCancel"),
        ("AXShowMenu", "AXShowMenu"),
        ("AXDismiss", "AXDismiss"),
    ]

    /// Value adjustment - sliders, steppers, progress
    static let axValueActions: [(id: String, label: String)] = [
        ("AXIncrement", "AXIncrement"),
        ("AXDecrement", "AXDecrement"),
    ]

    /// Disclosure - expandable content, outlines
    static let axDisclosureActions: [(id: String, label: String)] = [
        ("AXExpand", "AXExpand"),
        ("AXCollapse", "AXCollapse"),
        ("AXOpen", "AXOpen"),
    ]

    /// Window management
    static let axWindowActions: [(id: String, label: String)] = [
        ("AXRaise", "AXRaise"),
        ("AXZoom", "AXZoom"),
        ("AXMinimize", "AXMinimize"),
    ]

    /// Text/clipboard operations
    static let axTextActions: [(id: String, label: String)] = [
        ("AXCopy", "AXCopy"),
        ("AXCut", "AXCut"),
        ("AXPaste", "AXPaste"),
        ("AXSelect", "AXSelect"),
        ("AXSelectAll", "AXSelectAll"),
    ]

    /// Scroll operations
    static let axScrollActions: [(id: String, label: String)] = [
        ("AXScrollToVisible", "AXScrollToVisible"),
        ("AXScrollPageUp", "AXScrollPageUp"),
        ("AXScrollPageDown", "AXScrollPageDown"),
        ("AXScrollPageLeft", "AXScrollPageLeft"),
        ("AXScrollPageRight", "AXScrollPageRight"),
    ]

    /// Focus operation
    static let axFocusActions: [(id: String, label: String)] = [
        ("AXFocus", "AXFocus"),
    ]

    /// UI reveal actions
    static let axUIActions: [(id: String, label: String)] = [
        ("AXShowDefaultUI", "AXShowDefaultUI"),
        ("AXShowAlternateUI", "AXShowAlternateUI"),
    ]

    /// Content actions
    static let axContentActions: [(id: String, label: String)] = [
        ("AXDelete", "AXDelete"),
        ("AXPick", "AXPick"),
    ]

    /// All AX actions combined
    static var axActions: [(id: String, label: String)] {
        axCoreActions + axValueActions + axDisclosureActions + axWindowActions + axTextActions + axScrollActions + axFocusActions + axUIActions + axContentActions
    }

    static let axRoles: [(id: String, label: String)] = [
        ("AXSecureTextField", "AXSecureTextField"),
        ("AXPasswordField", "AXPasswordField"),
        ("AXSecureText", "AXSecureText"),
    ]

    /// Named group for dynamic UI rendering
    struct AXGroup {
        let title: String
        let items: [(id: String, label: String)]
    }

    /// All action groups — UI iterates this dynamically
    static let actionGroups: [AXGroup] = [
        AXGroup(title: "AX Core Actions", items: axCoreActions),
        AXGroup(title: "AX Value Actions", items: axValueActions),
        AXGroup(title: "AX Disclosure Actions", items: axDisclosureActions),
        AXGroup(title: "AX Window Actions", items: axWindowActions),
        AXGroup(title: "AX Text Actions", items: axTextActions),
        AXGroup(title: "AX Scroll Actions", items: axScrollActions),
        AXGroup(title: "AX Focus Actions", items: axFocusActions),
        AXGroup(title: "AX UI Actions", items: axUIActions),
        AXGroup(title: "AX Content Actions", items: axContentActions),
    ]

    /// Role groups
    static let roleGroups: [AXGroup] = [
        AXGroup(title: "AX Protected Roles", items: axRoles),
    ]

    /// All Accessibility IDs (actions + roles)
    static let allAxIds: Set<String> = {
        Set(axActions.map(\.id) + axRoles.map(\.id))
    }()
}


/// Manages which accessibility / Apple Event actions are enabled.
/// All actions default to ENABLED. User can disable per-item.
/// When disabled, the action is blocked (restricted).
@MainActor @Observable
final class AccessibilityEnabled {
    static let shared = AccessibilityEnabled()

    // Expose the static lists for UI binding
    static var axActions: [(id: String, label: String)] { AccessibilityEnabledIDs.axActions }
    static var axRoles: [(id: String, label: String)] { AccessibilityEnabledIDs.axRoles }
    static var allAxIds: Set<String> { AccessibilityEnabledIDs.allAxIds }
    static var allAeIds: Set<String> { [] }

    // MARK: - State

    /// Global on/off for all accessibility automation
    var accessibilityGlobalEnabled: Bool {
        didSet { UserDefaults.standard.set(accessibilityGlobalEnabled, forKey: "AccessibilityGlobalEnabled") }
    }

    /// Accessibility actions/roles that are ENABLED. Defaults to ALL.
    var axEnabled: Set<String> {
        didSet { UserDefaults.standard.set(Array(axEnabled), forKey: axEnabledKey) }
    }

    /// Apple Events selectors that are ENABLED. Defaults to ALL.
    var aeEnabled: Set<String> {
        didSet { UserDefaults.standard.set(Array(aeEnabled), forKey: aeEnabledKey) }
    }

    private init() {
        // Initialize global toggle (defaults to ON)
        self.accessibilityGlobalEnabled = UserDefaults.standard.object(forKey: "AccessibilityGlobalEnabled") as? Bool ?? true

        // Initialize Accessibility enabled set
        if let arr = UserDefaults.standard.stringArray(forKey: axEnabledKey) {
            let savedSet = Set(arr)
            let newKeys = Self.allAxIds.subtracting(savedSet)
            if newKeys.isEmpty {
                axEnabled = savedSet
            } else {
                axEnabled = savedSet.union(newKeys)
            }
        } else {
            axEnabled = Self.allAxIds
        }

        // Initialize Apple Events enabled set
        if let arr = UserDefaults.standard.stringArray(forKey: aeEnabledKey) {
            let savedSet = Set(arr)
            let newKeys = Self.allAeIds.subtracting(savedSet)
            if newKeys.isEmpty {
                aeEnabled = savedSet
            } else {
                aeEnabled = savedSet.union(newKeys)
            }
        } else {
            aeEnabled = Self.allAeIds
        }
    }

    // MARK: - Accessibility Queries

    /// Returns true if the AX action/role is BLOCKED (global toggle off, or user disabled it).
    func isAxRestricted(_ id: String) -> Bool {
        !accessibilityGlobalEnabled || !axEnabled.contains(id)
    }

    /// Returns true if the AX action/role is ENABLED.
    func isAxEnabled(_ id: String) -> Bool {
        axEnabled.contains(id)
    }

    func toggleAx(_ id: String) {
        if axEnabled.contains(id) {
            axEnabled.remove(id)
        } else {
            axEnabled.insert(id)
        }
    }

    // MARK: - Apple Events Queries

    /// Returns true if the AE selector is BLOCKED (user disabled it).
    func isAeRestricted(_ selector: String) -> Bool {
        !aeEnabled.contains(selector)
    }

    /// Returns true if the AE selector is ENABLED.
    func isAeEnabled(_ selector: String) -> Bool {
        aeEnabled.contains(selector)
    }

    func toggleAe(_ selector: String) {
        if aeEnabled.contains(selector) {
            aeEnabled.remove(selector)
        } else {
            aeEnabled.insert(selector)
        }
    }

    // MARK: - Legacy Compatibility (for migration)

    /// Returns true if the ID is enabled (checks global toggle + both AX and AE).
    func isEnabled(_ id: String) -> Bool {
        accessibilityGlobalEnabled && (axEnabled.contains(id) || aeEnabled.contains(id))
    }

    /// Returns true if the ID is restricted (global toggle off, or user disabled it).
    func isRestricted(_ id: String) -> Bool {
        !isEnabled(id)
    }

    /// Toggle by ID (determines AX vs AE automatically).
    func toggle(_ id: String) {
        if Self.allAxIds.contains(id) {
            toggleAx(id)
        } else if Self.allAeIds.contains(id) {
            toggleAe(id)
        }
    }
}

// MARK: - View

struct AccessibilitySettingsView: View {
    @Bindable var settings = AccessibilityEnabled.shared

    @State private var hasAccessibility = AccessibilityService.hasAccessibilityPermission()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Accessibility Permission
                HStack(spacing: 8) {
                    Circle()
                        .fill(hasAccessibility ? Color.green : Color.red.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text("Accessibility: \(hasAccessibility ? "Granted" : "Not Granted")")
                        .font(.caption)
                        .foregroundStyle(hasAccessibility ? .green : .red)
                    Spacer()
                    if !hasAccessibility {
                        Button("Request Access") {
                            _ = AccessibilityService.requestAccessibilityPermission()
                            // Recheck after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                hasAccessibility = AccessibilityService.hasAccessibilityPermission()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                Divider()

                Toggle(isOn: Binding(
                    get: { settings.accessibilityGlobalEnabled },
                    set: { settings.accessibilityGlobalEnabled = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility Automation")
                            .font(.headline)
                        Text(settings.accessibilityGlobalEnabled ? "Agent can interact with UI elements via AXorcist" : "All accessibility actions are blocked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                // Apple Events Permission
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text("Apple Events: Granted on first use of each application")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

            }
            .padding(16)
            .padding(.bottom, 15)
        }
        .frame(width: 500)
        .frame(maxHeight: 515)
    }

}
