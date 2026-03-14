import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: AgentViewModel
    @State private var showMCPServers = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Provider toggle
            VStack(alignment: .leading, spacing: 6) {
                Text("Selected Provider")
                    .font(.headline)
                Picker("Provider", selection: $viewModel.selectedProvider) {
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            // MCP Servers button
            Button {
                showMCPServers = true
            } label: {
                HStack {
                    Image(systemName: "server.rack")
                    Text("MCP Servers")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .popover(isPresented: $showMCPServers) {
                MCPServersView()
            }

            Divider()

            if viewModel.selectedProvider == .claude {
                // Claude settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Claude API")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key").font(.caption).foregroundStyle(.secondary)
                        SecureField("sk-ant-...", text: $viewModel.apiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model").font(.caption).foregroundStyle(.secondary)
                        Picker("Model", selection: $viewModel.selectedModel) {
                            ForEach(viewModel.availableClaudeModels) { model in
                                Text(model.formattedDisplayName).tag(model.id)
                            }
                        }
                        .labelsHidden()
                    }
                }
            } else if viewModel.selectedProvider == .ollama {
                // Cloud Ollama settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ollama Cloud")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key").font(.caption).foregroundStyle(.secondary)
                        SecureField("Required for cloud", text: $viewModel.ollamaAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            if viewModel.ollamaModels.isEmpty {
                                TextField("Model name", text: $viewModel.ollamaModel)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Picker("Model", selection: $viewModel.ollamaModel) {
                                    ForEach(viewModel.ollamaModels) { model in
                                        HStack(spacing: 4) {
                                            Text(model.name)
                                            if model.supportsVision {
                                                Image(systemName: "eye")
                                                    .foregroundStyle(.blue)
                                                    .font(.caption2)
                                            }
                                        }
                                        .tag(model.name)
                                    }
                                }
                                .labelsHidden()
                            }

                            Button {
                                viewModel.fetchOllamaModels()
                            } label: {
                                if viewModel.isFetchingModels {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.isFetchingModels)
                            .help("Fetch available models")
                        }
                    }
                }
            } else {
                // Local Ollama settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Local Ollama")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Endpoint").font(.caption).foregroundStyle(.secondary)
                        TextField("http://localhost:11434/api/chat", text: $viewModel.localOllamaEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            if viewModel.localOllamaModels.isEmpty {
                                TextField("Model name", text: $viewModel.localOllamaModel)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Picker("Model", selection: $viewModel.localOllamaModel) {
                                    ForEach(viewModel.localOllamaModels) { model in
                                        HStack(spacing: 4) {
                                            Text(model.name)
                                            if model.supportsVision {
                                                Image(systemName: "eye")
                                                    .foregroundStyle(.blue)
                                                    .font(.caption2)
                                            }
                                        }
                                        .tag(model.name)
                                    }
                                }
                                .labelsHidden()
                            }

                            Button {
                                viewModel.fetchLocalOllamaModels()
                            } label: {
                                if viewModel.isFetchingLocalModels {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.isFetchingLocalModels)
                            .help("Fetch available local models")
                        }
                    }
                }
            }
            Divider()

            // Iterations setting
            HStack {
                Text("Iterations")
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Max per task").font(.caption).foregroundStyle(.secondary)
                    Stepper("\(viewModel.maxIterations)",
                           onIncrement: {
                               let opts = AgentViewModel.iterationOptions
                               if let i = opts.firstIndex(of: viewModel.maxIterations), i > 0 {
                                   viewModel.maxIterations = opts[i - 1]
                               }
                           },
                           onDecrement: {
                               let opts = AgentViewModel.iterationOptions
                               if let i = opts.firstIndex(of: viewModel.maxIterations), i + 1 < opts.count {
                                   viewModel.maxIterations = opts[i + 1]
                               }
                           })
                }
            }
            Divider()

            // Output lines setting
            HStack {
                Text("Output")
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Lines before truncated").font(.caption).foregroundStyle(.secondary)
                    Stepper("\(viewModel.maxOutputLines)",
                           onIncrement: {
                               let opts = AgentViewModel.outputLineOptions
                               if let i = opts.firstIndex(of: viewModel.maxOutputLines), i > 0 {
                                   viewModel.maxOutputLines = opts[i - 1]
                               }
                           },
                           onDecrement: {
                               let opts = AgentViewModel.outputLineOptions
                               if let i = opts.firstIndex(of: viewModel.maxOutputLines), i + 1 < opts.count {
                                   viewModel.maxOutputLines = opts[i + 1]
                               }
                           })
                }
            }
            Divider()

            // Read file preview lines setting
            HStack {
                Text("Read File")
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Preview lines").font(.caption).foregroundStyle(.secondary)
                    Stepper("\(viewModel.readFilePreviewLines)",
                           onIncrement: {
                               let opts = AgentViewModel.readPreviewOptions
                               if let i = opts.firstIndex(of: viewModel.readFilePreviewLines), i + 1 < opts.count {
                                   viewModel.readFilePreviewLines = opts[i + 1]
                               }
                           },
                           onDecrement: {
                               let opts = AgentViewModel.readPreviewOptions
                               if let i = opts.firstIndex(of: viewModel.readFilePreviewLines), i > 0 {
                                   viewModel.readFilePreviewLines = opts[i - 1]
                               }
                           })
                }
            }
            Divider()

            // History settings
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Summarize after").font(.caption).foregroundStyle(.secondary)
                    Stepper("\(viewModel.maxHistoryBeforeSummary) tasks",
                           onIncrement: { if viewModel.maxHistoryBeforeSummary > 5 { viewModel.maxHistoryBeforeSummary -= 5 } },
                           onDecrement: { if viewModel.maxHistoryBeforeSummary < 50 { viewModel.maxHistoryBeforeSummary += 5 } })
                }
                Spacer().frame(width: 16)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Visible tasks in chat").font(.caption).foregroundStyle(.secondary)
                    Stepper("\(viewModel.visibleTaskCount)",
                           onIncrement: { if viewModel.visibleTaskCount > 1 { viewModel.visibleTaskCount -= 1 } },
                           onDecrement: { if viewModel.visibleTaskCount < 5 { viewModel.visibleTaskCount += 1 } })
                }
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}