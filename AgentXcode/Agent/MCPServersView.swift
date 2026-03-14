import SwiftUI

struct MCPServersView: View {
    @Bindable var registry = MCPServerRegistry.shared
    @State private var showingAddServer = false
    @State private var editingServer: MCPServerConfig?
    @State private var showingImport = false
    @State private var importText = ""
    
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
                    Text("Add servers to expose tools to LLM clients")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(registry.servers) { server in
                            MCPServerRowView(
                                server: server,
                                onEdit: { editingServer = server },
                                onToggle: { registry.toggleEnabled(server.id) },
                                onDelete: { registry.remove(at: server.id) }
                            )
                        }
                    }
                }
            }
            
            Divider()
            
            // Info text
            VStack(alignment: .leading, spacing: 4) {
                Text("MCP (Model Context Protocol) servers allow Agent! to expose tools to LLM clients.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Configure servers that implement the MCP protocol to make their tools available.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(width: 420, maxHeight: 500)
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
    }
}

// MARK: - Server Row View

struct MCPServerRowView: View {
    let server: MCPServerConfig
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Enable toggle
            Toggle("", isOn: Binding(
                get: { server.enabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            
            // Server info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(server.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if server.autoStart {
                        Text("auto")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.blue)
                            .clipShape(Capsule())
                    }
                }
                
                Text(server.command)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                if !server.arguments.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(server.arguments.prefix(3), id: \.self) { arg in
                            Text(arg)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        if server.arguments.count > 3 {
                            Text("+\(server.arguments.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
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
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(server == nil ? "Add MCP Server" : "Edit MCP Server")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name").font(.caption).foregroundStyle(.secondary)
                    TextField("My MCP Server", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Command
                VStack(alignment: .leading, spacing: 4) {
                    Text("Command").font(.caption).foregroundStyle(.secondary)
                    TextField("/usr/local/bin/my-mcp-server", text: $command)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Arguments
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arguments (one per line)").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $argumentsText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 60)
                        .scrollContentBackground(.hidden)
                        .background(.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                // Environment
                VStack(alignment: .leading, spacing: 4) {
                    Text("Environment Variables (KEY=value, one per line)").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $environmentText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 60)
                        .scrollContentBackground(.hidden)
                        .background(.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                // Toggles
                HStack(spacing: 20) {
                    Toggle("Enabled", isOn: $enabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    
                    Toggle("Auto-start", isOn: $autoStart)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
            }
            
            Divider()
            
            // Preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview JSON").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    Text(previewJSON)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 80)
                .padding(8)
                .background(.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            HStack {
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
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(name.isEmpty || command.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 400)
    }
    
    private var previewJSON: String {
        let config = MCPServerConfig(
            id: server?.id ?? UUID(),
            name: name,
            command: command,
            arguments: argumentsText.split(separator: "\n").map(String.init),
            environment: parseEnvironment(environmentText),
            enabled: enabled,
            autoStart: autoStart
        )
        return config.toJSON()
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

#Preview {
    MCPServersView()
}