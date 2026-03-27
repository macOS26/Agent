import SwiftUI

/// Collapsible thinking indicator shown in the activity log area while the LLM is processing.
struct ThinkingIndicatorView: View {
    @State private var isExpanded = false
    @State private var dots = ""
    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

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
                    Label("Waiting for LLM response", systemImage: "brain")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("Model is generating tool calls or text", systemImage: "ellipsis.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
