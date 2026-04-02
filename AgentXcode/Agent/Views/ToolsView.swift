import SwiftUI
import AgentTools

struct ToolsView: View {
    @Binding var selectedProvider: APIProvider
    var viewModel: AgentViewModel?
    @Bindable var prefs = ToolPreferencesService.shared
    @State private var collapsedGroups: Set<String> = []
    
    // Group definitions matching ToolPreferencesService — use exact name sets to avoid overlap
    static let groups: [String: (filter: (AgentTools.ToolDef) -> Bool, icon: String)] = [
        "Coding": ({ ["read_file", "write_file", "edit_file", "create_diff", "apply_diff", "diff_and_apply", "undo_edit", "list_files", "search_files", "read_dir", "file_manager", "xcode", "project_folder", "mode"].contains($0.name) }, "chevron.left.forwardslash.chevron.right"),
        "Automation": ({ ["applescript_tool", "accessibility", "javascript_tool", "lookup_sdef"].contains($0.name) }, "gearshape.2"),
        "Experimental": ({ ["ax_screenshot", "selenium"].contains($0.name) }, "flask"),
        "Core": ({ ["task_complete", "list_tools", "web_search"].contains($0.name) }, "checkmark.circle"),
        "Conversation": ({ $0.name == "conversation" }, "text.bubble"),
        "Workflow": ({ ["agent", "plan_mode", "git", "send_message", "batch_commands", "batch_tools"].contains($0.name) }, "flowchart"),
        "User Agent": ({ $0.name == "execute_agent_command" }, "person"),
        "Launch Daemon": ({ $0.name == "execute_daemon_command" }, "lock.shield"),
        "Web": ({ $0.name == "web" }, "globe"),
    ]

    static let groupOrder: [String] = ["Core", "Conversation", "Workflow", "Coding", "Automation", "User Agent", "Launch Daemon", "Web", "Experimental"]

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
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            if enabled {
                                                collapsedGroups.remove(groupName)
                                            } else {
                                                collapsedGroups.insert(groupName)
                                            }
                                        }
                                        // Sync service group toggles with launch agent/daemon
                                        if let vm = viewModel {
                                            if groupName == "User Agent" {
                                                vm.userEnabled = enabled
                                            } else if groupName == "Launch Daemon" {
                                                vm.rootEnabled = enabled
                                            }
                                        }
                                    },
                                    onToolToggled: (groupName == "User Agent" || groupName == "Launch Daemon") ? { toolName, enabled in
                                        guard let vm = viewModel else { return }
                                        if toolName == "execute_agent_command" {
                                            vm.userEnabled = enabled
                                        } else if toolName == "execute_daemon_command" {
                                            vm.rootEnabled = enabled
                                        }
                                    } : nil
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
        .frame(maxHeight: 660)
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
    var onToolToggled: ((String, Bool) -> Void)? = nil

    var body: some View {
        let groupEnabled = prefs.isGroupEnabled(groupName)
        let isServiceGroup: Bool = groupName == "User Agent" || groupName == "Launch Daemon"
        let offColor: Color = isServiceGroup ? .yellow : .red

        VStack(alignment: .leading, spacing: 4) {
            // Group header with collapse toggle and group toggle
            HStack(spacing: 6) {
                // Collapse arrow
                Image(systemName: (isCollapsed || !groupEnabled) ? "chevron.right" : "chevron.down")
                    .font(.caption2)
                    .foregroundColor(groupEnabled ? .secondary : offColor.opacity(0.5))

                // Group icon and name
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(groupEnabled ? (isServiceGroup ? .green : .primary) : offColor.opacity(0.6))
                Text(groupName)
                    .font(.caption).bold()
                    .foregroundColor(groupEnabled ? .secondary : offColor.opacity(0.6))

                // Tool count
                Text("\(groupTools.count)")
                    .font(.caption2)
                    .foregroundColor(groupEnabled ? .gray : offColor.opacity(0.4))

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
                            let nowEnabled = prefs.isEnabled(provider, tool.name)
                            onToolToggled?(tool.name, nowEnabled)
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