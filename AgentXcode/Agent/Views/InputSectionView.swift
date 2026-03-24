import SwiftUI

struct InputSectionView: View {
    @Bindable var viewModel: AgentViewModel
    @FocusState.Binding var isTaskFieldFocused: Bool
    var selectedTab: ScriptTab?
    
    var body: some View {
        if let tab = selectedTab {
            // Tab input
            HStack {
                let tabColor = Self.tabColor(for: tab.id, in: viewModel.scriptTabs)
                Button { viewModel.stopTabTask(tab: tab) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(tabColor)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Cancel tab LLM task")
                .opacity(tab.isLLMRunning ? 1 : 0)
                .disabled(!tab.isLLMRunning)

                Button { viewModel.captureScreenshot() } label: {
                    Image(systemName: "camera")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Take a screenshot to attach")

                Button { viewModel.pasteImageFromClipboard() } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Paste image from clipboard")

                Button { viewModel.toggleDictation() } label: {
                    Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
                        .foregroundStyle(viewModel.isListening ? Color.blue : .primary)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help(viewModel.isListening ? "Stop dictation" : "Start dictation")

                Button { viewModel.toggleHotwordListening() } label: {
                    Image(systemName: viewModel.isHotwordListening ? "waveform.circle.fill" : "waveform.circle")
                        .foregroundStyle(viewModel.isHotwordListening
                            ? (viewModel.isHotwordCapturing ? Color.green : Color.orange)
                            : .primary)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help(viewModel.isHotwordListening
                    ? (viewModel.isHotwordCapturing ? "Capturing command..." : "Listening for \"Agent!\" — click to stop")
                    : "Say \"Agent!\" to send a voice command")

                TextField(tab.isMainTab ? "Enter task..." : tab.isMessagesTab ? "Messages task..." : "Ask about \(tab.scriptName)...", text: Binding(
                    get: { tab.taskInput },
                    set: { tab.taskInput = $0 }
                ), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...8)
                    .onSubmit {
                        if !tab.taskInput.isEmpty {
                            viewModel.runTabTask(tab: tab)
                        }
                    }

                Button("Run") { viewModel.runTabTask(tab: tab) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(tab.taskInput.isEmpty || {
                        let provider = tab.llmConfig?.provider ?? viewModel.selectedProvider
                        return provider == .claude && viewModel.apiKey.isEmpty
                    }())
            }
            .padding()
        } else {
            // Main tab input
            HStack {
                Button { viewModel.stop() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Cancel running task")
                .opacity(viewModel.isRunning || viewModel.isThinking ? 1 : 0)
                .disabled(!viewModel.isRunning && !viewModel.isThinking)

                Button { viewModel.captureScreenshot() } label: {
                    Image(systemName: "camera")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Take a screenshot to attach")

                Button { viewModel.pasteImageFromClipboard() } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Paste image from clipboard")

                Button { viewModel.toggleDictation() } label: {
                    Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
                        .foregroundStyle(viewModel.isListening ? Color.blue : .primary)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help(viewModel.isListening ? "Stop dictation" : "Start dictation")

                Button { viewModel.toggleHotwordListening() } label: {
                    Image(systemName: viewModel.isHotwordListening ? "waveform.circle.fill" : "waveform.circle")
                        .foregroundStyle(viewModel.isHotwordListening
                            ? (viewModel.isHotwordCapturing ? Color.green : Color.orange)
                            : .primary)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help(viewModel.isHotwordListening
                    ? (viewModel.isHotwordCapturing ? "Capturing command..." : "Listening for \"Agent!\" — click to stop")
                    : "Say \"Agent!\" to send a voice command")

                TextField("Enter task...", text: $viewModel.taskInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTaskFieldFocused)
                    .lineLimit(1...8)
                    .onSubmit {
                        if !viewModel.taskInput.isEmpty {
                            viewModel.run()
                        }
                    }

                Button("Run") { viewModel.run() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(viewModel.taskInput.isEmpty || (viewModel.selectedProvider == .claude && viewModel.apiKey.isEmpty))
            }
            .padding()
        }
    }
    
    private static let tabColors: [Color] = [
        .orange, .purple, .pink, .cyan, .mint, .indigo, .teal, .yellow
    ]
    
    static func tabColor(for tabId: UUID, in tabs: [ScriptTab]) -> Color {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return .red }
        return tabColors[index % tabColors.count]
    }
}