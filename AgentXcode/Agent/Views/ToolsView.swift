import SwiftUI

struct ToolsView: View {
    let initialProvider: APIProvider
    @State private var selectedProvider: APIProvider
    @Bindable var prefs = ToolPreferencesService.shared

    init(initialProvider: APIProvider = .claude) {
        self.initialProvider = initialProvider
        _selectedProvider = State(initialValue: initialProvider)
    }

    /// Unified item representing either a native tool or an MCP tool.
    private struct ToolItem: Identifiable {
        let id: String  // unique key for display
        let displayName: String
        let helpText: String
        let isMCP: Bool
        let serverName: String?  // non-nil for MCP tools
    }

    /// All tools (native + MCP) sorted alphabetically.
    private var allTools: [ToolItem] {
        let nativeTools = AgentTools.tools(for: selectedProvider)
        let mcpTools = MCPService.shared.discoveredTools
        var items: [ToolItem] = nativeTools.map { tool in
            ToolItem(id: tool.name, displayName: tool.name,
                     helpText: tool.description.components(separatedBy: ". ").first ?? tool.description,
                     isMCP: false, serverName: nil)
        }
        for mcp in mcpTools {
            let key = "mcp_\(mcp.serverName)_\(mcp.name)"
            items.append(ToolItem(id: key, displayName: mcp.name,
                                  helpText: "\(mcp.description) (server: \(mcp.serverName))",
                                  isMCP: true, serverName: mcp.serverName))
        }
        return items.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
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
                    ForEach(allTools) { item in
                        let enabled = item.isMCP
                            ? MCPService.shared.isToolEnabled(serverName: item.serverName ?? "", toolName: item.displayName)
                            : prefs.isEnabled(selectedProvider, item.id)
                        Button {
                            if item.isMCP, let server = item.serverName {
                                MCPService.shared.toggleTool(serverName: server, toolName: item.displayName)
                            } else {
                                prefs.toggle(selectedProvider, item.id)
                            }
                        } label: {
                            HStack(spacing: 2) {
                                if item.isMCP {
                                    Image(systemName: "server.rack")
                                        .font(.system(size: 7))
                                }
                                Text(item.isMCP ? item.id : item.displayName)
                            }
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(enabled ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                            .foregroundStyle(enabled ? .primary : .tertiary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(enabled ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .help(item.helpText)
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                let items = allTools
                let nativeItems = items.filter { !$0.isMCP }
                let mcpItems = items.filter { $0.isMCP }
                let nativeEnabled = nativeItems.filter { prefs.isEnabled(selectedProvider, $0.id) }.count
                let mcpEnabled = mcpItems.filter { MCPService.shared.isToolEnabled(serverName: $0.serverName ?? "", toolName: $0.displayName) }.count
                Text("\(nativeEnabled + mcpEnabled) of \(items.count) enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Enable All") {
                    prefs.enableAll(for: selectedProvider)
                    for item in mcpItems {
                        if let server = item.serverName,
                           !MCPService.shared.isToolEnabled(serverName: server, toolName: item.displayName) {
                            MCPService.shared.toggleTool(serverName: server, toolName: item.displayName)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Disable All") {
                    for item in nativeItems {
                        if prefs.isEnabled(selectedProvider, item.id) {
                            prefs.toggle(selectedProvider, item.id)
                        }
                    }
                    for item in mcpItems {
                        if let server = item.serverName,
                           MCPService.shared.isToolEnabled(serverName: server, toolName: item.displayName) {
                            MCPService.shared.toggleTool(serverName: server, toolName: item.displayName)
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
