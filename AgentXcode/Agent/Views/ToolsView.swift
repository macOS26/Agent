import SwiftUI

struct ToolsView: View {
    let initialProvider: APIProvider
    @State private var selectedProvider: APIProvider
    @Bindable var prefs = ToolPreferencesService.shared

    init(initialProvider: APIProvider = .claude) {
        self.initialProvider = initialProvider
        _selectedProvider = State(initialValue: initialProvider)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 10) {
                Text("Tools")
                    .font(.title3).bold()
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(APIProvider.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()

            Divider()

            // Tag cloud
            ScrollView {
                FlowLayout(spacing: 4) {
                    ForEach(AgentTools.tools(for: selectedProvider), id: \.name) { tool in
                        let enabled = prefs.isEnabled(selectedProvider, tool.name)
                        Button {
                            prefs.toggle(selectedProvider, tool.name)
                        } label: {
                            Text(tool.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(enabled ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                                .foregroundStyle(enabled ? .primary : .tertiary)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(enabled ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .help(tool.description.components(separatedBy: ". ").first ?? tool.description)
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                let all = AgentTools.tools(for: selectedProvider)
                let enabledCount = all.filter { prefs.isEnabled(selectedProvider, $0.name) }.count
                Text("\(enabledCount) of \(all.count) enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Enable All") { prefs.enableAll(for: selectedProvider) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Disable All") {
                    for tool in AgentTools.tools(for: selectedProvider) {
                        if prefs.isEnabled(selectedProvider, tool.name) {
                            prefs.toggle(selectedProvider, tool.name)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
        }
        .frame(width: 460, height: 460)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
