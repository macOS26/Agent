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
                .pickerStyle(.menu)
            }
            .padding()

            Divider()

            // Tag cloud — native tools only, sorted alphabetically
            ScrollView {
                FlowLayout(spacing: 4) {
                    // Group tools by category
                    let tools = AgentTools.tools(for: selectedProvider)
                    let categories: [String: [AgentTools.ToolDef]] = [
                        "Coding": tools.filter { ($0.name.hasPrefix("read_") || $0.name.hasPrefix("write_") || $0.name.hasPrefix("edit_") || $0.name.hasPrefix("list_") || $0.name.hasPrefix("search_")) && !$0.name.contains("agent_") && $0.name != "list_mcp_tools" && $0.name != "list_native_tools" },
                        "Git": tools.filter { $0.name.hasPrefix("git_") },
                        "Automation": tools.filter { $0.name.hasPrefix("apple_event_") || $0.name.hasPrefix("run_") || $0.name == "execute_javascript" },
                        "Shell": tools.filter { $0.name.hasPrefix("execute_") && !$0.name.hasPrefix("execute_javascript") },
                        "Accessibility": tools.filter { $0.name.hasPrefix("ax_") },
                        "Scripts": tools.filter { $0.name.contains("agent_script") },
                        "SDEF": tools.filter { $0.name == "lookup_sdef" },
                        "Xcode": tools.filter { $0.name.hasPrefix("xcode_") },
                        "AppleScript": tools.filter { $0.name.hasPrefix("list_apple_") || $0.name.hasPrefix("run_apple_") || $0.name.hasPrefix("save_apple_") || $0.name.hasPrefix("delete_apple_") },
                        "JavaScript": tools.filter { $0.name.hasPrefix("list_javascript") || $0.name.hasPrefix("run_javascript") || $0.name.hasPrefix("save_javascript") || $0.name.hasPrefix("delete_javascript") },
                        "Core": tools.filter { $0.name == "task_complete" || $0.name == "list_native_tools" || $0.name == "list_mcp_tools" }
                    ]
                    
                    ForEach(Array(categories.keys).sorted(), id: \.self) { category in
                        if let categoryTools = categories[category], !categoryTools.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category)
                                    .font(.caption).bold()
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                                    .padding(.top, 8)
                                
                                FlowLayout(spacing: 4) {
                                    ForEach(categoryTools.sorted(by: { $0.name < $1.name }), id: \.name) { tool in
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
                            }
                        }
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
                    for tool in all {
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
