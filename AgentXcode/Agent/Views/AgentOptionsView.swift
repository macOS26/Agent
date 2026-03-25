import SwiftUI

struct AgentOptionsView: View {
    @Bindable var viewModel: AgentViewModel

    private var temperatureBinding: Binding<Double> {
        switch viewModel.selectedProvider {
        case .claude: return $viewModel.claudeTemperature
        case .ollama: return $viewModel.ollamaTemperature
        case .openAI: return $viewModel.openAITemperature
        case .deepSeek: return $viewModel.deepSeekTemperature
        case .huggingFace: return $viewModel.huggingFaceTemperature
        case .localOllama: return $viewModel.localOllamaTemperature
        case .vLLM: return $viewModel.vLLMTemperature
        case .lmStudio: return $viewModel.lmStudioTemperature
        case .foundationModel: return $viewModel.claudeTemperature // unused
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("Options")
                    .font(.headline)
                
                Text("Configure agent behavior and limits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
            
            row {
                Text("Iterations").font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
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

            row {
                Text("Output").font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
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

            row {
                Text("Read File").font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Preview lines").font(.caption).foregroundStyle(.secondary)
                    Stepper("\(viewModel.readFilePreviewLines)",
                        onIncrement: {
                            let opts = AgentViewModel.readPreviewOptions
                            if let i = opts.firstIndex(of: viewModel.readFilePreviewLines), i > 0 {
                                viewModel.readFilePreviewLines = opts[i - 1]
                            }
                        },
                        onDecrement: {
                            let opts = AgentViewModel.readPreviewOptions
                            if let i = opts.firstIndex(of: viewModel.readFilePreviewLines), i + 1 < opts.count {
                                viewModel.readFilePreviewLines = opts[i + 1]
                            }
                        })
                }
            }


            row {
                Text("Temperature").font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(viewModel.selectedProvider.displayName)").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Slider(value: temperatureBinding, in: 0...2, step: 0.1)
                            .frame(width: 120)
                        Text(String(format: "%.1f", temperatureBinding.wrappedValue))
                            .font(.caption.monospacedDigit())
                            .frame(width: 28)
                    }
                }
            }

            row {
                Text("AgentScript").font(.subheadline)
                Spacer()
                Toggle("Capture stderr", isOn: $viewModel.scriptCaptureStderr)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            row {
                Text("History").font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Summarize after").font(.caption).foregroundStyle(.secondary)
                    Stepper("\(viewModel.maxHistoryBeforeSummary) tasks",
                        onIncrement: { if viewModel.maxHistoryBeforeSummary > 5 { viewModel.maxHistoryBeforeSummary -= 5 } },
                        onDecrement: { if viewModel.maxHistoryBeforeSummary < 50 { viewModel.maxHistoryBeforeSummary += 5 } })
                }
                Spacer().frame(width: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Visible in chat").font(.caption).foregroundStyle(.secondary)
                    Stepper("\(viewModel.visibleTaskCount)",
                        onIncrement: { if viewModel.visibleTaskCount > 1 { viewModel.visibleTaskCount -= 1 } },
                        onDecrement: { if viewModel.visibleTaskCount < 5 { viewModel.visibleTaskCount += 1 } })
                }
            }

            row {
                Text("Shell").font(.subheadline)
                Spacer()
                Picker("", selection: Binding(
                    get: { AppConstants.shellPath },
                    set: { UserDefaults.standard.set($0, forKey: "agentShellPath") }
                )) {
                    Text("zsh").tag("/bin/zsh")
                    Text("bash").tag("/bin/bash")
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
        .padding(16)
        .padding(.bottom, 15)
        .frame(width: 360)
    }

    @ViewBuilder
    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack { content() }
                .padding(.vertical, 10)
        }
    }
}
