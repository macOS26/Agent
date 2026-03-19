import SwiftUI
import UniformTypeIdentifiers

struct LoRASettingsView: View {
    @State private var adapterManager = LoRAAdapterManager.shared
    @State private var showAdapterPicker = false
    @State private var showImportJSONLPicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var pythonAvailable = false
    @State private var pythonVersion = "Checking..."
    @State private var pythonChecked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Adapter Section
            adapterSection

            Divider()

            // Training Data Section
            dataSection

            Divider()

            // Python Environment Section
            pythonSection
        }
        .alert("LoRA", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .task {
            let status = await LoRAAdapterManager.pythonStatus()
            pythonAvailable = status.available
            pythonVersion = status.version
            pythonChecked = true
        }
        .fileImporter(
            isPresented: $showAdapterPicker,
            allowedContentTypes: [.folder, .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                let _ = adapterManager.installAdapter(from: url)
            }
        }
        .fileImporter(
            isPresented: $showImportJSONLPicker,
            allowedContentTypes: [UTType(filenameExtension: "jsonl") ?? .json, .json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                let count = adapterManager.importJSONL(from: url)
                alertMessage = count > 0 ? "Imported \(count) training samples from \(url.lastPathComponent)" : "No valid samples found in file."
                showAlert = true
            }
        }
    }

    // MARK: - Adapter Section

    private var adapterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LoRA Adapter")
                .font(.headline)

            HStack(spacing: 6) {
                Circle()
                    .fill(adapterManager.isLoaded ? .green : .red.opacity(0.6))
                    .frame(width: 8, height: 8)
                Text(adapterManager.statusMessage)
                    .font(.caption)
                    .foregroundStyle(adapterManager.isLoaded ? .green : .secondary)
            }

            if !adapterManager.installedAdapters.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Installed:").font(.caption2).foregroundStyle(.secondary)
                    ForEach(adapterManager.installedAdapters, id: \.absoluteString) { url in
                        HStack(spacing: 6) {
                            let name = url.deletingPathExtension().lastPathComponent
                            let isActive = adapterManager.adapterURL == url
                            Circle()
                                .fill(isActive ? .green : .gray.opacity(0.4))
                                .frame(width: 6, height: 6)
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(isActive ? .green : .primary)
                            Spacer()
                            if !isActive {
                                Button("Load") { adapterManager.loadAdapter(from: url) }
                                    .font(.caption2)
                                    .buttonStyle(.borderless)
                            }
                            Button("Remove") { adapterManager.uninstallAdapter(at: url) }
                                .font(.caption2)
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(6)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            HStack(spacing: 8) {
                Button("Install .fmadapter") { showAdapterPicker = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                if adapterManager.isLoaded {
                    Button("Unload") { adapterManager.unloadAdapter() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                }
            }

            Text("Train with Apple's Python toolkit, then install the .fmadapter here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Training Data Section

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Training Data")
                .font(.headline)

            let files = adapterManager.savedFiles()

            if !files.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved JSONL files:").font(.caption2).foregroundStyle(.secondary)
                    ForEach(files, id: \.absoluteString) { url in
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(url.lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Button("Delete") { adapterManager.deleteJSONLFile(at: url) }
                                .font(.caption2)
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(6)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text("No JSONL files saved yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Export Task History") {
                    if let url = adapterManager.exportTaskHistoryAsJSONL() {
                        alertMessage = "Saved to:\n\(url.path)"
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                    } else {
                        alertMessage = "No task history to export."
                    }
                    showAlert = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Import JSONL") {
                    showImportJSONLPicker = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Open Folder") {
                    LoRAAdapterManager.revealInFinder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Export task history or import existing JSONL for LoRA training.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Python Environment

    private var pythonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Training Environment")
                .font(.headline)

            HStack(spacing: 6) {
                Circle()
                    .fill(pythonAvailable ? .green : (pythonChecked ? .orange : .gray))
                    .frame(width: 8, height: 8)
                Text("Python: \(pythonVersion)")
                    .font(.caption)
                    .foregroundStyle(pythonAvailable ? .green : (pythonChecked ? .orange : .secondary))
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(LoRAAdapterManager.venvExists() ? .green : .red.opacity(0.6))
                    .frame(width: 8, height: 8)
                Text(LoRAAdapterManager.venvExists() ? "Virtual env ready" : "No virtual env")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Setup (Direct)") {
                    if let url = LoRAAdapterManager.generateSetupScript(homebrew: false) {
                        alertMessage = "Setup script saved.\nRun in Terminal:\n\(url.path)"
                        showAlert = true
                        LoRAAdapterManager.revealInFinder()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Setup (Homebrew)") {
                    if let url = LoRAAdapterManager.generateSetupScript(homebrew: true) {
                        alertMessage = "Homebrew setup script saved.\nRun in Terminal:\n\(url.path)"
                        showAlert = true
                        LoRAAdapterManager.revealInFinder()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                Button("Open Terminal") { LoRAAdapterManager.openTerminal() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button("Open Folder") { LoRAAdapterManager.revealInFinder() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            Text("1. Run a setup script in Terminal\n2. Download toolkit from developer.apple.com\n3. Export JSONL, train, install .fmadapter")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
