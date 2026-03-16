import SwiftUI

/// Manages which accessibility / Apple Event safety restrictions are active.
/// All restrictions default to ENABLED (enforced). User can disable per-item.
@MainActor @Observable
final class AccessibilityRestrictions {
    static let shared = AccessibilityRestrictions()

    // MARK: - Discoverable Restrictions

    static let axActions: [(id: String, label: String)] = [
        ("AXPress", "AXPress"),
        ("AXConfirm", "AXConfirm"),
        ("AXShowMenu", "AXShowMenu"),
        ("AXIncrement", "AXIncrement"),
        ("AXDecrement", "AXDecrement"),
        ("AXActivate", "AXActivate"),
        ("AXCancel", "AXCancel"),
        ("AXExpand", "AXExpand"),
        ("AXCollapse", "AXCollapse"),
    ]

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

    /// All known restriction IDs
    static let allIds: Set<String> = {
        Set(axActions.map(\.id) + axRoles.map(\.id) + aeWriteSelectors.map(\.id))
    }()

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
        VStack(alignment: .leading, spacing: 16) {
            Text("Accessibility Access")
                .font(.headline)

            Text("Enabled calls are allowed. Click to disable.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            section(title: "AX Actions (require allowWrites)", items: AccessibilityRestrictions.axActions)

            Divider()

            section(title: "AX Enabled Roles", items: AccessibilityRestrictions.axRoles)

            Divider()

            section(title: "Apple Event Write Selectors", items: AccessibilityRestrictions.aeWriteSelectors)
        }
        .padding(16)
        .frame(width: 360)
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
