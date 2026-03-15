import SwiftUI

struct MCPServersView: View {
    @Bindable var registry = MCPServerRegistry.shared
    @Bindable var mcpService = MCPService.shared
    @State private var showingAddServer = false
    @State private var editingServer: MCPServerConfig?
    @State private var showingImport = false
    @State private var importText = ""
    @State private var connectingIds: Set<UUID> = []
    @State private var renderKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("MCP Servers")
                    .font(.headline)
                Spacer()
                Button {
                    showingImport = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Import server configuration")

                Button {
                    showingAddServer = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Add MCP server")
            }

            Divider()

            if registry.servers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No MCP servers configured")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Add servers to expose tools to Agent!")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(registry.servers) { server in
                            serverRow(server)
                        }
                    }
                }
                .id(renderKey)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("MCP (Model Context Protocol) servers provide tools to Agent!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Toggle servers on/off to connect/disconnect.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(width: 420)
        .frame(maxHeight: 500)
        .sheet(isPresented: $showingAddServer) {
            MCPServerEditView(server: nil) { newServer in
                registry.add(newServer)
                showingAddServer = false
            }
        }
        .sheet(item: $editingServer) { server in
            MCPServerEditView(server: server) { updatedServer in
                registry.update(updatedServer)
                editingServer = nil
            }
        }
        .alert("Import Configuration", isPresented: $showingImport) {
            TextField("Paste JSON configuration", text: $importText, axis: .vertical)
                .font(.system(.caption, design: .monospaced))
            Button("Cancel", role: .cancel) {
                importText = ""
            }
            Button("Import") {
                if registry.importFrom(importText) {
                    importText = ""
                }
            }
        } message: {
            Text("Paste MCP server JSON configuration")
        }
        .onAppear {
            // Force toggles to re-render with correct thumb after popover appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                renderKey.toggle()
            }
        }
    }

    // MARK: - Status (single source of truth: MCPService)

    private func statusFor(_ id: UUID) -> ServerStatus {
        if connectingIds.contains(id) { return .connecting }
        if mcpService.connectedServerIds.contains(id) { return .connected }
        if let err = mcpService.connectionErrors[id] { return .error(err) }
        return .disconnected
    }

    enum ServerStatus {
        case disconnected, connecting, connected, error(String)
    }

    // MARK: - Actions

    /// Connect or disconnect based on the NEW enabled state (already set by the toggle binding).
    private func connectOrDisconnect(_ serverId: UUID, enable: Bool) async {
        if enable {
            guard let server = registry.servers.first(where: { $0.id == serverId }) else { return }
            connectingIds.insert(serverId)
            do {
                try await mcpService.connect(to: server)
            } catch {
                mcpService.connectionErrors[serverId] = error.localizedDescription
            }
            connectingIds.remove(serverId)
        } else {
            connectingIds.remove(serverId)
            await mcpService.disconnect(serverId: serverId)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func serverRow(_ server: MCPServerConfig) -> some View {
        let status = statusFor(server.id)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Toggle("", isOn: Binding(
                    get: { registry.servers.first(where: { $0.id == server.id })?.enabled ?? false },
                    set: { newValue in
                        registry.setEnabled(server.id, newValue)
                        Task { await connectOrDisconnect(server.id, enable: newValue) }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)

                HStack(spacing: 3) {
                    switch status {
                    case .connected:
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("Connected").font(.caption2).foregroundStyle(.green)
                    case .connecting:
                        ProgressView().controlSize(.mini)
                        Text("Connecting...").font(.caption2).foregroundStyle(.secondary)
                    case .disconnected:
                        Circle().fill(.secondary).frame(width: 6, height: 6)
                        Text("Disconnected").font(.caption2).foregroundStyle(.secondary)
                    case .error(let message):
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text(message).font(.caption2).foregroundStyle(.red).lineLimit(1)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(server.name).font(.subheadline).fontWeight(.medium)
                    if server.autoStart {
                        Text("auto").font(.caption2).foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.blue).clipShape(Capsule())
                    }
                }
                Text(server.command).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }

            Spacer()

            HStack(spacing: 4) {
                Button { editingServer = server } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered).controlSize(.mini)

                Button(role: .destructive) {
                    Task { await mcpService.disconnect(serverId: server.id) }
                    registry.remove(at: server.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered).controlSize(.mini)
            }
        }
        .padding(8)
        .background(.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Edit View

struct MCPServerEditView: View {
    let server: MCPServerConfig?
    let onSave: (MCPServerConfig) -> Void

    @State private var name: String
    @State private var command: String
    @State private var argumentsText: String
    @State private var environmentText: String
    @State private var enabled: Bool
    @State private var autoStart: Bool
    @State private var jsonText: String
    @State private var jsonError: String?
    @State private var updatingFromJSON = false

    @Environment(\.dismiss) private var dismiss

    init(server: MCPServerConfig?, onSave: @escaping (MCPServerConfig) -> Void) {
        self.server = server
        self.onSave = onSave
        _name = State(initialValue: server?.name ?? "")
        _command = State(initialValue: server?.command ?? "")
        _argumentsText = State(initialValue: server?.arguments.joined(separator: "\n") ?? "")
        _environmentText = State(initialValue: server?.environment.map { "\($0.key)=\($0.value)" }.joined(separator: "\n") ?? "")
        _enabled = State(initialValue: server?.enabled ?? true)
        _autoStart = State(initialValue: server?.autoStart ?? true)
        let initial = MCPServerConfig(
            id: server?.id ?? UUID(),
            name: server?.name ?? "",
            command: server?.command ?? "",
            arguments: server?.arguments ?? [],
            environment: server?.environment ?? [:],
            enabled: server?.enabled ?? true,
            autoStart: server?.autoStart ?? true
        )
        _jsonText = State(initialValue: initial.toJSON())
        _jsonError = State(initialValue: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(server == nil ? "Add MCP Server" : "Edit MCP Server")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered).controlSize(.small)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name").font(.caption).foregroundStyle(.secondary)
                    TextField("My MCP Server", text: $name).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Command").font(.caption).foregroundStyle(.secondary)
                    TextField("/usr/local/bin/my-mcp-server", text: $command).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arguments (one per line)").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $argumentsText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 60)
                        .scrollContentBackground(.hidden)
                        .background(.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Environment Variables (KEY=value, one per line)").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $environmentText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 60)
                        .scrollContentBackground(.hidden)
                        .background(.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                HStack(spacing: 20) {
                    Toggle("Enabled", isOn: $enabled).toggleStyle(.switch).controlSize(.mini)
                    Toggle("Auto-start", isOn: $autoStart).toggleStyle(.switch).controlSize(.mini)
                }
                .onChange(of: name) { if !updatingFromJSON { jsonText = previewJSON } }
                .onChange(of: command) { if !updatingFromJSON { jsonText = previewJSON } }
                .onChange(of: argumentsText) { if !updatingFromJSON { jsonText = previewJSON } }
                .onChange(of: environmentText) { if !updatingFromJSON { jsonText = previewJSON } }
                .onChange(of: enabled) { if !updatingFromJSON { jsonText = previewJSON } }
                .onChange(of: autoStart) { if !updatingFromJSON { jsonText = previewJSON } }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("JSON").font(.caption).foregroundStyle(.secondary)
                PlainTextEditor(text: $jsonText)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onChange(of: jsonText) {
                        applyJSON(jsonText)
                    }
                if let jsonError {
                    Text(jsonError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Button("Revert") {
                    jsonText = previewJSON
                    jsonError = nil
                }
                .buttonStyle(.bordered).controlSize(.small)
                Spacer()
                Button("Save") {
                    let config = MCPServerConfig(
                        id: server?.id ?? UUID(),
                        name: name,
                        command: command,
                        arguments: argumentsText.split(separator: "\n").map(String.init),
                        environment: parseEnvironment(environmentText),
                        enabled: enabled,
                        autoStart: autoStart
                    )
                    onSave(config)
                    dismiss()
                }
                .buttonStyle(.borderedProminent).controlSize(.small)
                .disabled(name.isEmpty || command.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 400)
    }

    private var previewJSON: String {
        MCPServerConfig(
            id: server?.id ?? UUID(),
            name: name,
            command: command,
            arguments: argumentsText.split(separator: "\n").map(String.init),
            environment: parseEnvironment(environmentText),
            enabled: enabled,
            autoStart: autoStart
        ).toJSON()
    }

    /// Parse edited JSON back into the form fields.
    private func applyJSON(_ json: String) {
        guard let data = json.data(using: .utf8),
              let config = try? JSONDecoder().decode(MCPServerConfig.self, from: data) else {
            jsonError = "Invalid JSON"
            return
        }
        jsonError = nil
        updatingFromJSON = true
        name = config.name
        command = config.command
        argumentsText = config.arguments.joined(separator: "\n")
        environmentText = config.environment.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        enabled = config.enabled
        autoStart = config.autoStart
        updatingFromJSON = false
    }

    /// Sync JSON text when form fields change.
    private func updateJSONFromFields() {
        jsonText = previewJSON
    }

    private func parseEnvironment(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                result[String(parts[0])] = String(parts[1])
            }
        }
        return result
    }
}

// MARK: - Plain Text Editor (no smart quotes)

private struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isRichText = false
        textView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.05)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.delegate = context.coordinator
        textView.string = text
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text.wrappedValue = tv.string
        }
    }
}

#Preview {
    MCPServersView()
}
