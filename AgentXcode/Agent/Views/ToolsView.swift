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

            // Tool list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(AgentTools.tools(for: selectedProvider), id: \.name) { tool in
                        ToolRowView(tool: tool, provider: selectedProvider, prefs: prefs)
                        Divider()
                            .padding(.leading, 16)
                    }
                }
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
                Button("Enable All") {
                    prefs.enableAll(for: selectedProvider)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
        }
        .frame(width: 420, height: 520)
    }
}

// MARK: - Tool Row

private struct ToolRowView: View {
    let tool: AgentTools.ToolDef
    let provider: APIProvider
    let prefs: ToolPreferencesService

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { prefs.isEnabled(provider, tool.name) },
                set: { _ in prefs.toggle(provider, tool.name) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Text(tool.description.components(separatedBy: ". ").first ?? tool.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { prefs.toggle(provider, tool.name) }
    }
}
