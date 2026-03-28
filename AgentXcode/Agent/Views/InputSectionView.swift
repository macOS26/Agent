import SwiftUI
import UniformTypeIdentifiers

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
                    .textFieldStyle(.plain)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 7)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                    .lineLimit(2...16)
                    .onKeyPress(.upArrow) {
                        tab.navigateHistory(direction: -1)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        tab.navigateHistory(direction: 1)
                        return .handled
                    }
                    .onSubmit {
                        if !tab.taskInput.isEmpty {
                            viewModel.runTabTask(tab: tab)
                        }
                    }

                VStack(spacing: 4) {
                    Button {
                        if tab.isLLMRunning {
                            viewModel.stopTabTask(tab: tab)
                        } else if tab.isRunning {
                            viewModel.cancelScriptTab(id: tab.id)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .frame(width: 36)
                    }
                    .buttonStyle(.bordered)
                    .clipShape(Capsule())
                    .controlSize(.small)
                    .help("Cancel tab task")
                    .opacity(tab.isBusy ? 1 : 0)
                    .disabled(!tab.isBusy)

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
            .background(Color(nsColor: .windowBackgroundColor))
            .onDrop(of: [.fileURL, .text], isTargeted: nil) { providers in
                handleDrop(providers, tab: tab)
            }
        } else {
            // Main tab input
            HStack {
                inputButtons

                TextField("Enter task...", text: $viewModel.taskInput, axis: .vertical)
                    .focused($isTaskFieldFocused)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 7)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                    .lineLimit(2...16)
                    .onKeyPress(.upArrow) {
                        viewModel.navigatePromptHistory(direction: -1)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        viewModel.navigatePromptHistory(direction: 1)
                        return .handled
                    }
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
                    .clipShape(Capsule())
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
            .background(Color(nsColor: .windowBackgroundColor))
            .onDrop(of: [.fileURL, .text], isTargeted: nil) { providers in
                handleDrop(providers, tab: nil)
            }
        }
    }

    /// Handle drag-and-drop of text files into the input area.
    /// Works regardless of whether the text field has focus.
    private func handleDrop(_ providers: [NSItemProvider], tab: ScriptTab? = nil) -> Bool {
        for provider in providers {
            // File URLs — read text content
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let urlData = data as? Data,
                          let url = URL(dataRepresentation: urlData, relativeTo: nil) else { return }
                    // Read text-based files
                    guard let content = try? String(contentsOfFile: url.path, encoding: .utf8) else { return }
                    let filename = url.lastPathComponent
                    let dropped = "[\(filename)]\n\(content)"
                    DispatchQueue.main.async {
                        if let tab {
                            tab.taskInput += (tab.taskInput.isEmpty ? "" : " ") + dropped
                        } else {
                            viewModel.taskInput += (viewModel.taskInput.isEmpty ? "" : " ") + dropped
                            isTaskFieldFocused = true
                        }
                    }
                }
                return true
            }
            // Plain text
            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
                    guard let text = data as? String, !text.isEmpty else { return }
                    DispatchQueue.main.async {
                        if let tab {
                            tab.taskInput += (tab.taskInput.isEmpty ? "" : " ") + text
                        } else {
                            viewModel.taskInput += (viewModel.taskInput.isEmpty ? "" : " ") + text
                            isTaskFieldFocused = true
                        }
                    }
                }
                return true
            }
        }
        return false
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
