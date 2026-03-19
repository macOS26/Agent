import SwiftUI

// MARK: - Known Restriction IDs (nonisolated for thread-safe access)

/// All known restriction IDs - computed from static lists at compile time
/// This is nonisolated so it can be accessed from any thread without MainActor
enum AccessibilityRestrictionIDs {
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

    static let aeWriteSelectors: [(id: String, label: String)] = [
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

    /// All known restriction IDs - thread-safe static constant
    static let allIds: Set<String> = {
        Set(axActions.map(\.id) + axRoles.map(\.id) + aeWriteSelectors.map(\.id))
    }()
}

/// Manages which accessibility / Apple Event safety restrictions are active.
/// All restrictions default to ENABLED (enforced). User can disable per-item.
@MainActor @Observable
final class AccessibilityRestrictions {
    static let shared = AccessibilityRestrictions()

    // Expose the static lists for UI binding
    static var axActions: [(id: String, label: String)] { AccessibilityRestrictionIDs.axActions }
    static var axRoles: [(id: String, label: String)] { AccessibilityRestrictionIDs.axRoles }
    static var aeWriteSelectors: [(id: String, label: String)] { AccessibilityRestrictionIDs.aeWriteSelectors }
    static var allIds: Set<String> { AccessibilityRestrictionIDs.allIds }

    // MARK: - State

    private static let key = "ax.enabledRestrictions"

    /// Restrictions the user has left ON (enforced). Defaults to ALL.
    var enabledRestrictions: Set<String> {
        didSet { UserDefaults.standard.set(Array(enabledRestrictions), forKey: Self.key) }
    }

    private init() {
        if let arr = UserDefaults.standard.stringArray(forKey: Self.key) {
            enabledRestrictions = Set(arr)
        } else {
            // First launch — all restrictions enabled
            enabledRestrictions = Self.allIds
        }
    }

    // MARK: - Queries

    /// Returns true if the call is blocked (user disabled it).
    func isRestricted(_ id: String) -> Bool {
        !enabledRestrictions.contains(id)
    }

    /// Returns true if the restriction is enabled (same as isRestricted, for UI clarity).
    func isEnabled(_ id: String) -> Bool {
        enabledRestrictions.contains(id)
    }

    func toggle(_ id: String) {
        if enabledRestrictions.contains(id) {
            enabledRestrictions.remove(id)
        } else {
            enabledRestrictions.insert(id)
        }
    }
}

// MARK: - View

struct AccessibilitySettingsView: View {
    @Bindable var restrictions = AccessibilityRestrictions.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Accessibility Access")
                    .font(.headline)

                Text("Enabled calls are allowed. Click to disable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                section(title: "AX Core Actions", items: AccessibilityRestrictionIDs.axCoreActions)
                section(title: "AX Value Actions", items: AccessibilityRestrictionIDs.axValueActions)
                section(title: "AX Disclosure Actions", items: AccessibilityRestrictionIDs.axDisclosureActions)
                section(title: "AX Window Actions", items: AccessibilityRestrictionIDs.axWindowActions)
                section(title: "AX Text Actions", items: AccessibilityRestrictionIDs.axTextActions)
                section(title: "AX Scroll Actions", items: AccessibilityRestrictionIDs.axScrollActions)
                section(title: "AX Focus Actions", items: AccessibilityRestrictionIDs.axFocusActions)

                Divider()

                section(title: "AX Protected Roles", items: AccessibilityRestrictions.axRoles)

                Divider()

                section(title: "Apple Event Write Selectors", items: AccessibilityRestrictions.aeWriteSelectors)
            }
            .padding(16)
        }
        .frame(width: 400)
        .frame(maxHeight: 500)
    }

    @ViewBuilder
    private func section(title: String, items: [(id: String, label: String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            FlowLayout(spacing: 4) {
                ForEach(items, id: \.id) { item in
                    let enabled = restrictions.isEnabled(item.id)
                    Button {
                        restrictions.toggle(item.id)
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
