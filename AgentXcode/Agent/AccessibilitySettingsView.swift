import SwiftUI

/// Manages which accessibility / Apple Event safety restrictions are active.
/// Restrictions default to ON (enforced). User can opt out per-item.
@MainActor @Observable
final class AccessibilityRestrictions {
    static let shared = AccessibilityRestrictions()

    // MARK: - AX Actions (blocked unless user disables the restriction)

    /// All discoverable AX action restrictions
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

    /// All discoverable AX role restrictions
    static let axRoles: [(id: String, label: String)] = [
        ("AXSecureTextField", "AXSecureTextField"),
        ("AXPasswordField", "AXPasswordField"),
        ("AXSecureText", "AXSecureText"),
    ]

    /// All discoverable Apple Event write selector restrictions
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

    // MARK: - State

    private static let key = "ax.disabledRestrictions"

    /// Items the user has opted OUT of (restriction removed).
    var disabledRestrictions: Set<String> = [] {
        didSet { UserDefaults.standard.set(Array(disabledRestrictions), forKey: Self.key) }
    }

    private init() {
        let arr = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
        disabledRestrictions = Set(arr)
    }

    // MARK: - Queries (used by services)

    /// Returns true if the restriction is active (i.e. the item is blocked).
    func isRestricted(_ id: String) -> Bool {
        !disabledRestrictions.contains(id)
    }

    func toggle(_ id: String) {
        if disabledRestrictions.contains(id) {
            disabledRestrictions.remove(id)
        } else {
            disabledRestrictions.insert(id)
        }
    }
}

// MARK: - View

struct AccessibilitySettingsView: View {
    @Bindable var restrictions = AccessibilityRestrictions.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accessibility Restrictions")
                .font(.headline)

            Text("Restrictions are ON by default. Click to opt out.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            section(title: "AX Actions (require allowWrites)", items: AccessibilityRestrictions.axActions)

            Divider()

            section(title: "AX Blocked Roles", items: AccessibilityRestrictions.axRoles)

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
                    let restricted = restrictions.isRestricted(item.id)
                    Button {
                        restrictions.toggle(item.id)
                    } label: {
                        Text(item.label)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(restricted ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.1))
                            .foregroundStyle(restricted ? .primary : .tertiary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(restricted ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help(restricted ? "\(item.label): restricted (click to allow)" : "\(item.label): allowed (click to restrict)")
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
