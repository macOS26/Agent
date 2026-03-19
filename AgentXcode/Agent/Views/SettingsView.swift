import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: AgentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Provider toggle
            VStack(alignment: .leading, spacing: 6) {
                Text("LLM Provider")
                    .font(.headline)
                Picker("AI", selection: $viewModel.selectedProvider) {
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
                Text("Ollama Pro is preferred")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.selectedProvider == .claude {
                // Claude settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Claude API")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key").font(.caption).foregroundStyle(.secondary)
                        LockedSecureField(text: $viewModel.apiKey, placeholder: "sk-ant-...", lockKey: "lock.claudeAPIKey")
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
            } else if viewModel.selectedProvider == .openAI {
                // OpenAI settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("OpenAI API")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key").font(.caption).foregroundStyle(.secondary)
                        LockedSecureField(text: $viewModel.openAIAPIKey, placeholder: "sk-...", lockKey: "lock.openAIAPIKey")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            if viewModel.openAIModels.isEmpty {
                                TextField("Model name", text: $viewModel.openAIModel)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Picker("Model", selection: $viewModel.openAIModel) {
                                    ForEach(viewModel.openAIModels) { model in
                                        Text(model.name).tag(model.id)
                                    }
                                }
                                .labelsHidden()
                            }

                            Button {
                                viewModel.fetchOpenAIModels()
                            } label: {
                                if viewModel.isFetchingOpenAIModels {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.isFetchingOpenAIModels)
                            .help("Fetch available models")
                        }
                    }
                }
            } else if viewModel.selectedProvider == .deepSeek {
                // DeepSeek settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("DeepSeek API")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key").font(.caption).foregroundStyle(.secondary)
                        LockedSecureField(text: $viewModel.deepSeekAPIKey, placeholder: "sk-...", lockKey: "lock.deepSeekAPIKey")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            if viewModel.deepSeekModels.isEmpty {
                                TextField("Model name", text: $viewModel.deepSeekModel)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Picker("Model", selection: $viewModel.deepSeekModel) {
                                    ForEach(viewModel.deepSeekModels) { model in
                                        Text(model.name).tag(model.id)
                                    }
                                }
                                .labelsHidden()
                            }

                            Button {
                                viewModel.fetchDeepSeekModels()
                            } label: {
                                if viewModel.isFetchingDeepSeekModels {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.isFetchingDeepSeekModels)
                            .help("Fetch available models")
                        }
                    }
                }
            } else if viewModel.selectedProvider == .huggingFace {
                // Hugging Face settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hugging Face Inference")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key").font(.caption).foregroundStyle(.secondary)
                        LockedSecureField(text: $viewModel.huggingFaceAPIKey, placeholder: "hf_...", lockKey: "lock.huggingFaceAPIKey")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            if viewModel.huggingFaceModels.isEmpty {
                                TextField("Model name", text: $viewModel.huggingFaceModel)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Picker("Model", selection: $viewModel.huggingFaceModel) {
                                    ForEach(viewModel.huggingFaceModels) { model in
                                        Text(model.name).tag(model.id)
                                    }
                                }
                                .labelsHidden()
                            }

                            Button {
                                viewModel.fetchHuggingFaceModels()
                            } label: {
                                if viewModel.isFetchingHuggingFaceModels {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.isFetchingHuggingFaceModels)
                            .help("Fetch available models")
                        }
                    }
                }
            } else if viewModel.selectedProvider == .ollama {
                // Cloud Ollama settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ollama Cloud")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key").font(.caption).foregroundStyle(.secondary)
                        LockedSecureField(text: $viewModel.ollamaAPIKey, placeholder: "Required for cloud", lockKey: "lock.ollamaAPIKey")
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
            } else if viewModel.selectedProvider == .foundationModel {
                // Apple Foundation Models (on-device) + LoRA
                VStack(alignment: .leading, spacing: 10) {
                    Text("Apple Intelligence (On-Device)")
                        .font(.headline)
                    HStack(spacing: 6) {
                        Image(systemName: FoundationModelService.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(FoundationModelService.isAvailable ? .green : .red)
                        Text(FoundationModelService.isAvailable ? "Available" : "Not available")
                            .font(.subheadline)
                    }
                    if !FoundationModelService.isAvailable {
                        Text(FoundationModelService.unavailabilityReason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("Apple Intelligence is not fully compatible with Agent! It is here for training purposes only. Apple AI does not have enough context.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        // LoRA adapter status
                        HStack(spacing: 6) {
                            Circle()
                                .fill(LoRAAdapterManager.shared.isLoaded ? .green : .gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                            Text(LoRAAdapterManager.shared.isLoaded ? "LoRA: \(LoRAAdapterManager.shared.adapterName)" : "No LoRA adapter")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        // LoRA Training Section (inline)
                        LoRASettingsView()
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

            // Web Search (Tavily) — for Ollama providers only
            if viewModel.selectedProvider == .ollama || viewModel.selectedProvider == .localOllama {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Web Search")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tavily API Key").font(.caption).foregroundStyle(.secondary)
                        LockedSecureField(text: $viewModel.tavilyAPIKey, placeholder: "tvly-...", lockKey: "lock.tavilyAPIKey")
                    }
                }
            }

            // System Prompts Editor
            Button("Edit System Prompts...") {
                SystemPromptWindow.shared.show()
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}

// MARK: - Locked Secure Field

/// A SecureField with a lock/unlock button. When locked, the field is disabled.
/// Lock state persists in UserDefaults via the lockKey.
struct LockedSecureField: View {
    @Binding var text: String
    let placeholder: String
    let lockKey: String
    @State private var isLocked: Bool

    init(text: Binding<String>, placeholder: String, lockKey: String) {
        self._text = text
        self.placeholder = placeholder
        self.lockKey = lockKey
        _isLocked = State(initialValue: UserDefaults.standard.bool(forKey: lockKey))
    }

    var body: some View {
        HStack(spacing: 4) {
            SecureField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .disabled(isLocked)
                .opacity(isLocked ? 0.6 : 1)

            Button {
                isLocked.toggle()
                UserDefaults.standard.set(isLocked, forKey: lockKey)
            } label: {
                Image(systemName: isLocked ? "lock.fill" : "lock.open")
                    .foregroundStyle(isLocked ? .orange : .secondary)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(isLocked ? "Unlock to edit" : "Lock to protect")
        }
    }
}
