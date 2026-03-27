import SwiftUI

/// Collapsible thinking indicator shown in the activity log area while the LLM is processing.
/// Shows real-time model info, token counts, and message stats when expanded.
struct ThinkingIndicatorView: View {
    @Bindable var viewModel: AgentViewModel
    var tab: ScriptTab?

    @State private var isExpanded = false
    @State private var dots = ""
    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

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

                    ShimmerText("Thinking\(dots)", color: .blue)

                    Text("(\(String(format: "%.0f", elapsed))s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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
