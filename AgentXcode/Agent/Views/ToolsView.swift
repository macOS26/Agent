import SwiftUI

struct ToolsView: View {
    @Binding var selectedProvider: APIProvider
    @Bindable var prefs = ToolPreferencesService.shared
    @State private var collapsedGroups: Set<String> = []
    
    // Group definitions matching ToolPreferencesService — use exact name sets to avoid overlap
    static let groups: [String: (filter: (AgentTools.ToolDef) -> Bool, icon: String)] = [
        "Coding": ({ ["read_file", "write_file", "edit_file", "create_diff", "apply_diff", "list_files", "search_files"].contains($0.name) || $0.name.hasPrefix("git_") || $0.name.hasPrefix("xcode_") }, "doc.text"),
        "Automation": ({ ["run_applescript", "run_osascript", "execute_javascript", "lookup_sdef"].contains($0.name) || ["list_apple_scripts", "run_apple_script", "save_apple_script", "delete_apple_script"].contains($0.name) || ["list_javascript", "run_javascript", "save_javascript", "delete_javascript"].contains($0.name) }, "gearshape.2"),
        "Experimental": ({ $0.name == "apple_event_query" }, "flask"),
        "Accessibility": ({ $0.name.hasPrefix("ax_") }, "accessibility"),
        "Core": ({ ["task_complete", "list_tools", "list_mcp_tools", "load_groups", "unload_groups", "web_search", "write_text", "transform_text", "send_message", "about_self", "fix_text", "execute_agent_command", "execute_daemon_command"].contains($0.name) || $0.name.contains("agent_script") }, "checkmark.circle"),
        "Web": ({ ($0.name.hasPrefix("web_") && $0.name != "web_search") || $0.name.hasPrefix("selenium_") }, "globe"),
    ]
    
    static let groupOrder: [String] = ["Core", "Coding", "Automation", "Accessibility", "Web", "Experimental"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("Tools")
                    .font(.headline)
                
                Text("Toggle tool availability per LLM provider.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(APIProvider.selectableProviders, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding()
            .padding(.bottom, 4)

            Divider()

            // Tag cloud — native tools only, sorted alphabetically
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let tools = AgentTools.tools(for: selectedProvider)
                    
                    ForEach(Self.groupOrder, id: \.self) { groupName in
                        if let groupInfo = Self.groups[groupName] {
                            let groupTools = tools.filter { groupInfo.filter($0) }.sorted(by: { $0.name < $1.name })
                            
                            if !groupTools.isEmpty {
                                GroupRowView(
                                    groupName: groupName,
                                    icon: groupInfo.icon,
                                    groupTools: groupTools,
                                    provider: selectedProvider,
                                    prefs: prefs,
                                    isCollapsed: collapsedGroups.contains(groupName),
                                    toggleCollapse: { toggleGroup(groupName) },
                                    onGroupToggled: { enabled in
                                        if !enabled {
                                            _ = withAnimation(.easeInOut(duration: 0.15)) {
                                                collapsedGroups.insert(groupName)
                                            }
                                        }
                                    }
                                )
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
                Button("Enable All") {
                    prefs.enableAllGroups()
                    prefs.enableAll(for: selectedProvider)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Disable All") {
                    prefs.disableAllGroups()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .padding(.bottom, 15)
        }
        .frame(width: 460)
    }
    
    private func toggleGroup(_ groupName: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if collapsedGroups.contains(groupName) {
                collapsedGroups.remove(groupName)
            } else {
                collapsedGroups.insert(groupName)
            }
        }
    }
}

// MARK: - Group Row View

struct GroupRowView: View {
    let groupName: String
    let icon: String
    let groupTools: [AgentTools.ToolDef]
    let provider: APIProvider
    let prefs: ToolPreferencesService
    let isCollapsed: Bool
    let toggleCollapse: () -> Void
    let onGroupToggled: (Bool) -> Void

    var body: some View {
        let groupEnabled = prefs.isGroupEnabled(groupName)

        VStack(alignment: .leading, spacing: 4) {
            // Group header with collapse toggle and group toggle
            HStack(spacing: 6) {
                // Collapse arrow
                Image(systemName: (isCollapsed || !groupEnabled) ? "chevron.right" : "chevron.down")
                    .font(.caption2)
                    .foregroundColor(groupEnabled ? .secondary : .red.opacity(0.5))

                // Group icon and name
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(groupEnabled ? .primary : .red.opacity(0.6))
                Text(groupName)
                    .font(.caption).bold()
                    .foregroundColor(groupEnabled ? .secondary : .red.opacity(0.6))

                // Tool count
                Text("\(groupTools.count)")
                    .font(.caption2)
                    .foregroundColor(groupEnabled ? .gray : .red.opacity(0.4))

                Spacer()

                // Group toggle switch
                Toggle("", isOn: Binding(
                    get: { groupEnabled },
                    set: { newValue in
                        prefs.toggleGroup(groupName)
                        onGroupToggled(newValue)
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
            .padding(.leading, 4)
            .padding(.top, 8)
            .contentShape(Rectangle())
            .onTapGesture { if groupEnabled { toggleCollapse() } }

            // Tool buttons — auto-collapse when group is disabled
            if !isCollapsed && groupEnabled {
                FlowLayout(spacing: 4) {
                    ForEach(groupTools, id: \.name) { tool in
                        let enabled = prefs.isEnabled(provider, tool.name)
                        Button {
                            prefs.toggle(provider, tool.name)
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