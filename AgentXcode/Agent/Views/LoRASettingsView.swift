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
            adapterSection

            Divider().background(Color.gray.opacity(0.3))

            dataSection

            Divider().background(Color.gray.opacity(0.3))

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
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            HStack(spacing: 6) {
                Circle()
                    .fill(adapterManager.isLoaded ? Color.green : Color.red.opacity(0.6))
                    .frame(width: 8, height: 8)
                Text(adapterManager.statusMessage)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(adapterManager.isLoaded ? .green : .gray)
            }

            if !adapterManager.installedAdapters.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Installed:")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    ForEach(adapterManager.installedAdapters, id: \.absoluteString) { url in
                        HStack(spacing: 6) {
                            let name = url.deletingPathExtension().lastPathComponent
                            let isActive = adapterManager.adapterURL == url
                            Circle()
                                .fill(isActive ? Color.green : Color.gray.opacity(0.4))
                                .frame(width: 6, height: 6)
                            Text(name)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(isActive ? .green : .white)
                            Spacer()
                            if !isActive {
                                Button("Load") { adapterManager.loadAdapter(from: url) }
                                    .font(.system(size: 10))
                                    .buttonStyle(.borderless)
                                    .foregroundColor(.cyan)
                            }
                            Button("Remove") { adapterManager.uninstallAdapter(at: url) }
                                .font(.system(size: 10))
                                .buttonStyle(.borderless)
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                }
                .padding(6)
                .background(Color.black.opacity(0.3))
                .cornerRadius(4)
            }

            HStack(spacing: 8) {
                Button("Install .fmadapter") { showAdapterPicker = true }
                    .buttonStyle(.bordered)

                if adapterManager.isLoaded {
                    Button("Unload") { adapterManager.unloadAdapter() }
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            }

            Text("Train with Apple's Python toolkit, then install the .fmadapter here. It persists across launches.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray.opacity(0.7))
                .lineLimit(2)
        }
    }

    // MARK: - Training Data Section

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Training Data")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            let files = adapterManager.savedFiles()

            if !files.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved JSONL files:")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    ForEach(files, id: \.absoluteString) { url in
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            Text(url.lastPathComponent)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                            Button("Delete") { adapterManager.deleteJSONLFile(at: url) }
                                .font(.system(size: 10))
                                .buttonStyle(.borderless)
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                }
                .padding(6)
                .background(Color.black.opacity(0.3))
                .cornerRadius(4)
            } else {
                Text("No JSONL files saved yet.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
            }

            HStack(spacing: 8) {
                Button("Export JSONL") {
                    if let url = adapterManager.exportTaskHistoryAsJSONL() {
                        alertMessage = "Saved to:\n\(url.path)"
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                    } else {
                        alertMessage = "No task history to export."
                    }
                    showAlert = true
                }
                .buttonStyle(.bordered)

                Button("Import JSONL") {
                    showImportJSONLPicker = true
                }
                .buttonStyle(.bordered)

                Button("Open Folder") {
                    LoRAAdapterManager.revealInFinder()
                }
                .buttonStyle(.bordered)
            }

            Text("Export task history, then train with Apple's Python adapter toolkit.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray.opacity(0.7))
                .lineLimit(2)
        }
    }

    // MARK: - Python / Training Environment

    private var pythonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Training Environment")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            HStack(spacing: 6) {
                Circle()
                    .fill(pythonAvailable ? Color.green : (pythonChecked ? Color.orange : Color.gray))
                    .frame(width: 8, height: 8)
                Text("Python: \(pythonVersion)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(pythonAvailable ? .green : (pythonChecked ? .orange : .gray))
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(LoRAAdapterManager.venvExists() ? Color.green : Color.red.opacity(0.6))
                    .frame(width: 8, height: 8)
                Text(LoRAAdapterManager.venvExists() ? "Virtual env ready" : "No virtual env")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
            }

            HStack(spacing: 8) {
                Button("Setup (Direct)") {
                    if let url = LoRAAdapterManager.generateSetupScript(homebrew: false) {
                        alertMessage = "Direct setup script saved.\nRun in Terminal:\n\(url.path)"
                        showAlert = true
                        LoRAAdapterManager.revealInFinder()
                    }
                }
                .buttonStyle(.bordered)

                Button("Setup (Homebrew)") {
                    if let url = LoRAAdapterManager.generateSetupScript(homebrew: true) {
                        alertMessage = "Homebrew setup script saved.\nRun in Terminal:\n\(url.path)"
                        showAlert = true
                        LoRAAdapterManager.revealInFinder()
                    }
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                Button("Open Terminal") { LoRAAdapterManager.openTerminal() }
                    .buttonStyle(.bordered)

                Button("Open Folder") { LoRAAdapterManager.revealInFinder() }
                    .buttonStyle(.bordered)
            }

            Text("1. Click a Setup script \u{2192} run it in Terminal\n2. Download toolkit from developer.apple.com\n3. Export JSONL \u{2192} train \u{2192} install .fmadapter")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray.opacity(0.7))
                .lineLimit(4)
        }
    }
}
