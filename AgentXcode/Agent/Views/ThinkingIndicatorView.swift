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
    private var showStreamText: Bool {
        get { viewModel.thinkingOutputExpanded }
        nonmutating set { viewModel.thinkingOutputExpanded = newValue }
    }
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

/// Resizable LLM output box — neo-retro terminal look, adapts to dark/light mode.
private struct LLMOutputBox: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    @Binding var height: CGFloat

    private var termBg: Color {
        colorScheme == .dark
            ? Color(red: 0.05, green: 0.08, blue: 0.05)
            : Color(red: 0.93, green: 0.97, blue: 0.93)
    }
    private var termText: Color {
        colorScheme == .dark
            ? Color(red: 0.2, green: 0.9, blue: 0.3)
            : Color(red: 0.05, green: 0.35, blue: 0.1)
    }
    private var termDim: Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.4, blue: 0.2)
            : Color(red: 0.3, green: 0.6, blue: 0.35)
    }
    private var termBorder: Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.4, blue: 0.2).opacity(0.5)
            : Color(red: 0.3, green: 0.6, blue: 0.35).opacity(0.4)
    }
    private var handleBg: Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.2, blue: 0.15)
            : Color(red: 0.85, green: 0.92, blue: 0.85)
    }

    var body: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(spacing: 0) {
            if !trimmed.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(trimmed)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(termText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(10)
                }
                .frame(height: height)
                .scrollIndicators(.visible)
            } else {
                HStack(spacing: 0) {
                    Text("> ")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(termText)
                    Text("awaiting output...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(termDim)
                    Spacer()
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: height)
            }

            // Drag handle
            Rectangle()
                .fill(handleBg)
                .frame(height: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(termDim)
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
        .background(termBg)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(termBorder, lineWidth: 1))
    }
}
