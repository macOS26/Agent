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
    ]

    /// Focus operation
    static let axFocusActions: [(id: String, label: String)] = [
        ("AXFocus", "AXFocus"),
    ]

    /// All AX actions combined (for backward compatibility)
    static var axActions: [(id: String, label: String)] {
        axCoreActions + axValueActions + axDisclosureActions + axWindowActions + axTextActions + axScrollActions + axFocusActions
    }

    static let axRoles: [(id: String, label: String)] = [
        ("AXSecureTextField", "AXSecureTextField"),
        ("AXPasswordField", "AXPasswordField"),
        ("AXSecureText", "AXSecureText"),
    ]

    /// All Accessibility IDs (actions + roles)
    static let allAxIds: Set<String> = {
        Set(axActions.map(\.id) + axRoles.map(\.id))
    }()
}

// MARK: - Known Apple Events Enabled IDs

/// All known Apple Events write selector IDs
enum AppleEventsEnabledIDs {
    static let writeSelectors: [(id: String, label: String)] = [
        ("delete", "delete"),
        ("close", "close"),
        ("remove", "remove"),
        ("quit", "quit"),
        ("move", "move"),
        ("moveTo", "moveTo"),
        ("duplicate", "duplicate"),
        ("save", "save"),
        ("set", "set"),
        ("sendMessage", "sendMessage"),
    ]

    static let allAeIds: Set<String> = {
        Set(writeSelectors.map(\.id))
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
    static var aeWriteSelectors: [(id: String, label: String)] { AppleEventsEnabledIDs.writeSelectors }
    static var allAxIds: Set<String> { AccessibilityEnabledIDs.allAxIds }
    static var allAeIds: Set<String> { AppleEventsEnabledIDs.allAeIds }

    // MARK: - State

    /// Accessibility actions/roles that are ENABLED. Defaults to ALL.
    var axEnabled: Set<String> {
        didSet { UserDefaults.standard.set(Array(axEnabled), forKey: axEnabledKey) }
    }

    /// Apple Events selectors that are ENABLED. Defaults to ALL.
    var aeEnabled: Set<String> {
        didSet { UserDefaults.standard.set(Array(aeEnabled), forKey: aeEnabledKey) }
    }

    private init() {
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

    /// Returns true if the AX action/role is BLOCKED (user disabled it).
    func isAxRestricted(_ id: String) -> Bool {
        !axEnabled.contains(id)
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

    /// Returns true if the ID is enabled (checks both AX and AE).
    /// Used for backward compatibility during transition.
    func isEnabled(_ id: String) -> Bool {
        axEnabled.contains(id) || aeEnabled.contains(id)
    }

    /// Returns true if the ID is restricted (checks both AX and AE).
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Accessibility Actions")
                    .font(.headline)

                Text("Enabled actions are allowed. Click to disable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                axSection(title: "AX Core Actions", items: AccessibilityEnabledIDs.axCoreActions)
                axSection(title: "AX Value Actions", items: AccessibilityEnabledIDs.axValueActions)
                axSection(title: "AX Disclosure Actions", items: AccessibilityEnabledIDs.axDisclosureActions)
                axSection(title: "AX Window Actions", items: AccessibilityEnabledIDs.axWindowActions)
                axSection(title: "AX Text Actions", items: AccessibilityEnabledIDs.axTextActions)
                axSection(title: "AX Scroll Actions", items: AccessibilityEnabledIDs.axScrollActions)
                axSection(title: "AX Focus Actions", items: AccessibilityEnabledIDs.axFocusActions)

                Divider()

                axSection(title: "AX Protected Roles", items: AccessibilityEnabledIDs.axRoles)

                Divider()

                Text("Apple Events Write Selectors")
                    .font(.headline)

                Text("Enabled selectors are allowed. Click to disable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                aeSection(title: "Apple Event Write Selectors", items: AppleEventsEnabledIDs.writeSelectors)
            }
            .padding(16)
        }
        .frame(width: 400)
        .frame(maxHeight: 500)
    }

    @ViewBuilder
    private func axSection(title: String, items: [(id: String, label: String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            FlowLayout(spacing: 4) {
                ForEach(items, id: \.id) { item in
                    let enabled = settings.isAxEnabled(item.id)
                    Button {
                        settings.toggleAx(item.id)
                    } label: {
                        Text(item.label)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(enabled ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                            .foregroundStyle(enabled ? .primary : .tertiary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(enabled ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help(enabled ? "\(item.label): enabled (click to disable)" : "\(item.label): disabled (click to enable)")
                }
            }
        }
    }

    @ViewBuilder
    private func aeSection(title: String, items: [(id: String, label: String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            FlowLayout(spacing: 4) {
                ForEach(items, id: \.id) { item in
                    let enabled = settings.isAeEnabled(item.id)
                    Button {
                        settings.toggleAe(item.id)
                    } label: {
                        Text(item.label)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(enabled ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                            .foregroundStyle(enabled ? .primary : .tertiary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(enabled ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help(enabled ? "\(item.label): enabled (click to disable)" : "\(item.label): disabled (click to enable)")
                }
            }
        }
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight + (i > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var x: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(subview)
            x += size.width + spacing
        }
        return rows
    }
}
