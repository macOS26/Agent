import SwiftUI

struct ToolsView: View {
    let initialProvider: APIProvider
    @State private var selectedProvider: APIProvider
    private let prefs = ToolPreferencesService.shared

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
                TagCloudView(
                    tools: AgentTools.tools(for: selectedProvider),
                    provider: selectedProvider,
                    prefs: prefs
                )
                .padding()
            }

            Divider()

            // Footer
            HStack {
                let all = AgentTools.tools(for: selectedProvider)
                let enabledCount = all.filter { prefs.isEnabled(selectedProvider, $0.name) }.count
                Text("\(enabledCount) of \(all.count) enabled for \(selectedProvider.displayName)")
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
        .frame(width: 460, height: 480)
    }
}

// MARK: - Tag Cloud

private struct TagCloudView: View {
    let tools: [AgentTools.ToolDef]
    let provider: APIProvider
    let prefs: ToolPreferencesService

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tools, id: \.name) { tool in
                ToolTagView(tool: tool, provider: provider, prefs: prefs)
            }
        }
    }
}

// MARK: - Tool Tag

private struct ToolTagView: View {
    let tool: AgentTools.ToolDef
    let provider: APIProvider
    let prefs: ToolPreferencesService

    private var isEnabled: Bool { prefs.isEnabled(provider, tool.name) }

    var body: some View {
        Text(tool.name)
            .font(.system(.caption, design: .monospaced))
            .fontWeight(isEnabled ? .semibold : .regular)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEnabled ? Color.accentColor.opacity(0.85) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled ? Color.clear : Color.secondary.opacity(0.4), lineWidth: 1)
            )
            .foregroundStyle(isEnabled ? .white : .secondary)
            .help(tool.description.components(separatedBy: ". ").first ?? tool.description)
            .onTapGesture { prefs.toggle(provider, tool.name) }
            .animation(.easeInOut(duration: 0.15), value: isEnabled)
    }
}

// MARK: - Flow Layout

/// Wrapping horizontal layout — places items left-to-right, wrapping to the next line.
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
