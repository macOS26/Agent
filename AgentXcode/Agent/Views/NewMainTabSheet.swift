import SwiftUI

/// Sheet for creating a new main tab with a specific LLM provider and model.
struct NewMainTabSheet: View {
    @Bindable var viewModel: AgentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var provider: APIProvider
    @State private var selectedModelId: String = ""

    init(viewModel: AgentViewModel) {
        self.viewModel = viewModel
        self._provider = State(initialValue: viewModel.selectedProvider)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New LLM Tab")
                .font(.headline)

            // Provider picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Provider").font(.caption).foregroundStyle(.secondary)
                Picker("Provider", selection: $provider) {
                    ForEach(APIProvider.selectableProviders, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .labelsHidden()
                .onChange(of: provider) { _, newProvider in
                    ensureModelsLoaded(for: newProvider)
                    selectedModelId = defaultModelId(for: newProvider)
                }
            }

            // Model picker (adapts per provider)
            VStack(alignment: .leading, spacing: 4) {
                Text("Model").font(.caption).foregroundStyle(.secondary)
                modelPicker
            }

            // Validation message
            if !canCreate {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create Tab") {
                    let displayName = viewModel.modelDisplayName(provider: provider, modelId: selectedModelId)
                    let config = LLMConfig(provider: provider, model: selectedModelId, displayName: displayName)
                    viewModel.createMainTab(config: config)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
        .onAppear {
            ensureModelsLoaded(for: provider)
            selectedModelId = defaultModelId(for: provider)
        }
    }

    // MARK: - Model Picker

    @ViewBuilder
    private var modelPicker: some View {
        switch provider {
        case .claude:
            Picker("Model", selection: $selectedModelId) {
                ForEach(viewModel.availableClaudeModels) { model in
                    Text(model.formattedDisplayName).tag(model.id)
                }
            }
            .labelsHidden()

        case .openAI:
            modelPickerWithFetch(
                models: viewModel.openAIModels,
                fallbackBinding: $selectedModelId,
                isFetching: viewModel.isFetchingOpenAIModels,
                fetch: { viewModel.fetchOpenAIModels() }
            )

        case .deepSeek:
            modelPickerWithFetch(
                models: viewModel.deepSeekModels,
                fallbackBinding: $selectedModelId,
                isFetching: viewModel.isFetchingDeepSeekModels,
                fetch: { viewModel.fetchDeepSeekModels() }
            )

        case .huggingFace:
            modelPickerWithFetch(
                models: viewModel.huggingFaceModels,
                fallbackBinding: $selectedModelId,
                isFetching: viewModel.isFetchingHuggingFaceModels,
                fetch: { viewModel.fetchHuggingFaceModels() }
            )

        case .ollama:
            ollamaModelPicker(models: viewModel.ollamaModels, fetch: { viewModel.fetchOllamaModels() })

        case .localOllama:
            ollamaModelPicker(models: viewModel.localOllamaModels, fetch: { viewModel.fetchLocalOllamaModels() })

        case .foundationModel:
            // Apple Intelligence is for LoRA training only, not direct task execution
            Text("Apple Intelligence (LoRA training only)")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func modelPickerWithFetch(
        models: [AgentViewModel.OpenAIModelInfo],
        fallbackBinding: Binding<String>,
        isFetching: Bool,
        fetch: @escaping () -> Void
    ) -> some View {
        HStack {
            if models.isEmpty {
                TextField("Model name", text: fallbackBinding)
                    .textFieldStyle(.roundedBorder)
            } else {
                Picker("Model", selection: $selectedModelId) {
                    ForEach(models) { model in
                        Text(model.name).tag(model.id)
                    }
                }
                .labelsHidden()
            }
            Button(action: fetch) {
                if isFetching {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isFetching)
        }
    }

    @ViewBuilder
    private func ollamaModelPicker(models: [AgentViewModel.OllamaModelInfo], fetch: @escaping () -> Void) -> some View {
        HStack {
            if models.isEmpty {
                TextField("Model name", text: $selectedModelId)
                    .textFieldStyle(.roundedBorder)
            } else {
                Picker("Model", selection: $selectedModelId) {
                    ForEach(models) { model in
                        HStack(spacing: 4) {
                            Text(model.name)
                            if model.supportsVision {
                                Image(systemName: "eye")
                                    .foregroundStyle(.blue)
                                    .font(.caption2)
                            }
                        }.tag(model.id)
                    }
                }
                .labelsHidden()
            }
            Button(action: fetch) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        return !selectedModelId.isEmpty
    }

    private var validationMessage: String {
        if selectedModelId.isEmpty {
            return "Select a model to continue"
        }
        return ""
    }

    private func defaultModelId(for provider: APIProvider) -> String {
        switch provider {
        case .claude: return viewModel.selectedModel
        case .openAI: return viewModel.openAIModel
        case .deepSeek: return viewModel.deepSeekModel
        case .huggingFace: return viewModel.huggingFaceModel
        case .ollama: return viewModel.ollamaModel
        case .localOllama: return viewModel.localOllamaModel
        case .foundationModel: return "apple-intelligence"
        }
    }

    private func ensureModelsLoaded(for provider: APIProvider) {
        switch provider {
        case .claude:
            if viewModel.availableClaudeModels.isEmpty {
                Task { await viewModel.fetchClaudeModels() }
            }
        case .openAI:
            if viewModel.openAIModels.isEmpty { viewModel.fetchOpenAIModels() }
        case .deepSeek:
            if viewModel.deepSeekModels.isEmpty { viewModel.fetchDeepSeekModels() }
        case .huggingFace:
            if viewModel.huggingFaceModels.isEmpty { viewModel.fetchHuggingFaceModels() }
        case .ollama:
            if viewModel.ollamaModels.isEmpty { viewModel.fetchOllamaModels() }
        case .localOllama:
            if viewModel.localOllamaModels.isEmpty { viewModel.fetchLocalOllamaModels() }
        case .foundationModel:
            break  // No models to fetch for Apple Intelligence
        }
    }
}