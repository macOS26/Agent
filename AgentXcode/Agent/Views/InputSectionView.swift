import SwiftUI

struct InputSectionView: View {
    @Bindable var viewModel: AgentViewModel
    @FocusState.Binding var isTaskFieldFocused: Bool
    var selectedTab: ScriptTab?

    var body: some View {
        if let tab = selectedTab {
            // Tab input
            HStack {
                inputButtons

                TextField(tab.isMainTab ? "Enter task..." : tab.isMessagesTab ? "Messages task..." : "Ask about \(tab.scriptName)...", text: Binding(
                    get: { tab.taskInput },
                    set: { tab.taskInput = $0 }
                ), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...8)
                    .onSubmit {
                        if !tab.taskInput.isEmpty {
                            viewModel.runTabTask(tab: tab)
                        }
                    }

                VStack(spacing: 4) {
                    Button { viewModel.stopTabTask(tab: tab) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .frame(width: 36)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Cancel tab task")
                    .opacity(tab.isLLMRunning ? 1 : 0)
                    .disabled(!tab.isLLMRunning)

                    Button { viewModel.runTabTask(tab: tab) } label: {
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white)
                            .frame(width: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Capsule())
                    .controlSize(.small)
                    .disabled(tab.taskInput.isEmpty || {
                        let provider = tab.llmConfig?.provider ?? viewModel.selectedProvider
                        return provider == .claude && viewModel.apiKey.isEmpty
                    }())
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Color(white: 0.15))
        } else {
            // Main tab input
            HStack {
                inputButtons

                TextField("Enter task...", text: $viewModel.taskInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTaskFieldFocused)
                    .lineLimit(2...8)
                    .onSubmit {
                        if !viewModel.taskInput.isEmpty {
                            viewModel.run()
                        }
                    }

                VStack(spacing: 4) {
                    Button { viewModel.stop() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .frame(width: 36)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Cancel running task")
                    .opacity(viewModel.isRunning || viewModel.isThinking ? 1 : 0)
                    .disabled(!viewModel.isRunning && !viewModel.isThinking)

                    Button { viewModel.run() } label: {
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white)
                            .frame(width: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Capsule())
                    .controlSize(.small)
                    .disabled(viewModel.taskInput.isEmpty || (viewModel.selectedProvider == .claude && viewModel.apiKey.isEmpty))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Color(white: 0.15))
        }
    }

    private var inputButtons: some View {
        let buttonWidth: CGFloat = 36
        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                Button { viewModel.captureScreenshot() } label: {
                    Image(systemName: "camera")
                        .frame(width: buttonWidth)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
                .controlSize(.small)
                .help("Take a screenshot to attach")

                Button { viewModel.pasteImageFromClipboard() } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .frame(width: buttonWidth)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
                .controlSize(.small)
                .help("Paste image from clipboard")
            }
            HStack(spacing: 4) {
                Button { viewModel.toggleDictation() } label: {
                    Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
                        .foregroundStyle(viewModel.isListening ? Color.blue : .primary)
                        .frame(width: buttonWidth)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
                .controlSize(.small)
                .help(viewModel.isListening ? "Stop dictation" : "Start dictation")

                Button { viewModel.toggleHotwordListening() } label: {
                    Image(systemName: viewModel.isHotwordListening ? "waveform.circle.fill" : "waveform.circle")
                        .foregroundStyle(viewModel.isHotwordListening
                            ? (viewModel.isHotwordCapturing ? Color.green : Color.orange)
                            : .primary)
                        .frame(width: buttonWidth)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
                .controlSize(.small)
                .help(viewModel.isHotwordListening
                    ? (viewModel.isHotwordCapturing ? "Capturing command..." : "Listening for \"Agent!\" — click to stop")
                    : "Say \"Agent!\" to send a voice command")
            }
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
