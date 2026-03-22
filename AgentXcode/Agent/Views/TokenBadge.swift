import SwiftUI

struct TokenBadge: View {
    let taskIn: Int
    let taskOut: Int
    let sessionIn: Int
    let sessionOut: Int

    var body: some View {
        let total = taskIn + taskOut
        if total > 0 {
            Text(formatTokens(total))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
                .help("Task: \(formatTokens(taskIn)) in / \(formatTokens(taskOut)) out\nSession: \(formatTokens(sessionIn)) in / \(formatTokens(sessionOut)) out")
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
