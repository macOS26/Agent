import SwiftUI

struct ToolsView: View {
    @Binding var selectedProvider: APIProvider
    @Bindable var prefs = ToolPreferencesService.shared
    @State private var collapsedGroups: Set<String> = []
    
    // Group definitions matching ToolPreferencesService
    static let groups: [String: (filter: (AgentTools.ToolDef) -> Bool, icon: String)] = [
        "Coding": ({ ($0.name.hasPrefix("read_") || $0.name.hasPrefix("write_") || $0.name.hasPrefix("edit_") || $0.name.hasPrefix("list_") || $0.name.hasPrefix("search_")) && !$0.name.contains("agent_") && $0.name != "list_mcp_tools" && $0.name != "list_native_tools" }, "doc.text"),
        "Git": ({ $0.name.hasPrefix("git_") }, "branch"),
        "Automation": ({ $0.name.hasPrefix("apple_event_") || $0.name.hasPrefix("run_") || $0.name == "execute_javascript" }, "gearshape.2"),
        "Shell": ({ $0.name.hasPrefix("execute_") && !$0.name.hasPrefix("execute_javascript") }, "terminal"),
        "Accessibility": ({ $0.name.hasPrefix("ax_") }, "accessibility"),
        "Scripts": ({ $0.name.contains("agent_script") }, "scroll"),
        "SDEF": ({ $0.name == "lookup_sdef" }, "book"),
        "Xcode": ({ $0.name.hasPrefix("xcode_") }, "xcode"),
        "AppleScript": ({ $0.name.hasPrefix("list_apple_") || $0.name.hasPrefix("run_apple_") || $0.name.hasPrefix("save_apple_") || $0.name.hasPrefix("delete_apple_") }, "applescript"),
        "JavaScript": ({ $0.name.hasPrefix("list_javascript") || $0.name.hasPrefix("run_javascript") || $0.name.hasPrefix("save_javascript") || $0.name.hasPrefix("delete_javascript") }, "curlybraces"),
        "Core": ({ $0.name == "task_complete" || $0.name == "list_native_tools" || $0.name == "list_mcp_tools" }, "checkmark.circle"),
        "Web": ({ $0.name.hasPrefix("web_") && !$0.name.hasPrefix("web_search") }, "globe"),
        "Selenium": ({ $0.name.hasPrefix("selenium_") }, "network"),
        "Web Search": ({ $0.name == "web_search" }, "magnifyingglass"),
        "Conversation": ({ ["write_text", "transform_text", "send_message", "about_self", "fix_text"].contains($0.name) }, "bubble.left.and.bubble.right")
    ]
    
    static let groupOrder: [String] = ["Core", "Coding", "Git", "Shell", "Xcode", "Scripts", "SDEF", "Automation", "AppleScript", "JavaScript", "Accessibility", "Web", "Selenium", "Web Search", "Conversation"]

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
                                    toggleCollapse: { toggleGroup(groupName) }
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

    var body: some View {
        let groupEnabled = prefs.isGroupEnabled(groupName)

        VStack(alignment: .leading, spacing: 4) {
            // Group header with collapse toggle and group toggle
            HStack(spacing: 6) {
                // Collapse arrow
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Group icon and name
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(groupEnabled ? .primary : .tertiary)
                Text(groupName)
                    .font(.caption).bold()
                    .foregroundStyle(groupEnabled ? .secondary : .tertiary)

                // Tool count
                Text("\(groupTools.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                // Group toggle switch
                Toggle("", isOn: Binding(
                    get: { groupEnabled },
                    set: { _ in prefs.toggleGroup(groupName) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
            .padding(.leading, 4)
            .padding(.top, 8)
            .contentShape(Rectangle())
            .onTapGesture { toggleCollapse() }

            // Tool buttons (collapsible)
            if !isCollapsed {
                FlowLayout(spacing: 4) {
                    ForEach(groupTools, id: \.name) { tool in
                        let enabled = groupEnabled && prefs.isEnabled(provider, tool.name)
                        Button {
                            guard groupEnabled else { return }
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
                        .disabled(!groupEnabled)
                        .help(groupEnabled
                            ? (tool.description.components(separatedBy: ". ").first ?? tool.description)
                            : "Enable \(groupName) group first")
                    }
                }
                .opacity(groupEnabled ? 1.0 : 0.4)
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