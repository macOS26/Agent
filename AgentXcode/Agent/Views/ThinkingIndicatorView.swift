import SwiftUI

/// Collapsible thinking indicator shown in the activity log area while the LLM is processing.
/// Shows real-time model info, token counts, and message stats when expanded.
struct ThinkingIndicatorView: View {
    @Bindable var viewModel: AgentViewModel
    var tab: ScriptTab?

    private var isExpanded: Bool {
        get { viewModel.thinkingExpanded }
        nonmutating set { viewModel.thinkingExpanded = newValue }
    }
    @State private var showStreamText = false
    @State private var outputHeight: CGFloat = 100
    @State private var dots = ""
    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var streamText: String {
        if let tab {
            return tab.rawLLMOutput
        }
        return viewModel.rawLLMOutput
    }

    private var modelName: String {
        if let tab, let config = tab.llmConfig {
            return "\(config.provider.displayName) / \(config.model)"
        }
        return "\(viewModel.selectedProvider.displayName) / \(viewModel.selectedModel)"
    }

    private var messageCount: Int {
        if let tab {
            return tab.llmMessages.count
        }
        return 0
    }

    static func formatElapsed(_ t: TimeInterval) -> String {
        let s = Int(t)
        if s < 60 { return "\(s)s" }
        let m = s / 60
        let sec = s % 60
        if m < 60 { return "\(m)m \(sec)s" }
        let h = m / 60
        let min = m % 60
        return "\(h)h \(min)m \(sec)s"
    }

    private var inputTokens: Int { viewModel.taskInputTokens }
    private var outputTokens: Int { viewModel.taskOutputTokens }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    ProgressView()
                        .controlSize(.mini)

                    Text("(\(Self.formatElapsed(elapsed)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ShimmerText("Thinking\(dots)", color: .blue)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Label(modelName, systemImage: "brain")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if messageCount > 0 {
                        Label("\(messageCount) messages in conversation", systemImage: "bubble.left.and.bubble.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if inputTokens > 0 || outputTokens > 0 {
                        Label("Tokens: \(inputTokens) in / \(outputTokens) out", systemImage: "number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.rootServiceActive {
                        Label("Root daemon active", systemImage: "lock.shield")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if viewModel.userServiceActive {
                        Label("User agent executing", systemImage: "terminal")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Waiting for LLM response", systemImage: "ellipsis.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Stream text disclosure
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showStreamText.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(showStreamText ? 90 : 0))
                            Label("LLM Output", systemImage: "text.bubble")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if showStreamText {
                        LLMOutputBox(text: streamText, height: $outputHeight)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
        .padding(.horizontal, 8)
        .onReceive(timer) { _ in
            elapsed += 0.5
            switch dots.count {
            case 0: dots = "."
            case 1: dots = ".."
            case 2: dots = "..."
            default: dots = ""
            }
        }
    }
}

/// Resizable LLM output box with drag handle at bottom.
private struct LLMOutputBox: View {
    let text: String
    @Binding var height: CGFloat

    var body: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(spacing: 0) {
            if !trimmed.isEmpty {
                ScrollView {
                    Text(trimmed)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                }
                .frame(height: height)
            } else {
                Text("No output yet...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: height)
            }

            // Drag handle
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 40, height: 3)
                )
                .onHover { inside in
                    if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            height = max(50, height + value.translation.height)
                        }
                )
        }
        .background(Color(nsColor: .systemGray).opacity(0.2))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }
}
