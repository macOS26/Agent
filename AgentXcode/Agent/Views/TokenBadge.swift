import SwiftUI

struct TokenBadge: View {
    let taskIn: Int
    let taskOut: Int
    let sessionIn: Int
    let sessionOut: Int
    var providerName: String = ""
    var modelName: String = ""

    @State private var showDetail: Bool = false

    var body: some View {
        let total: Int = taskIn + taskOut
        if total > 0 {
            Button {
                showDetail.toggle()
            } label: {
                Text(formatTokens(total))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDetail) {
                TokenDetailView(
                    taskIn: taskIn, taskOut: taskOut,
                    sessionIn: sessionIn, sessionOut: sessionOut,
                    providerName: providerName, modelName: modelName
                )
            }
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

// MARK: - Detail Popover

private struct TokenDetailView: View {
    let taskIn: Int
    let taskOut: Int
    let sessionIn: Int
    let sessionOut: Int
    let providerName: String
    let modelName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("Token Usage")
                    .font(.headline)

                Text("Current session breakdown.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .padding(.bottom, 4)

            Divider()

            // Provider & Model
            if !providerName.isEmpty {
                row {
                    Text("Provider").font(.subheadline)
                    Spacer()
                    Text(providerName)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            if !modelName.isEmpty {
                row {
                    Text("Model").font(.subheadline)
                    Spacer()
                    Text(shortModel(modelName))
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            // Task tokens
            row {
                Text("Task").font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    tokenBar(label: "In", value: taskIn, color: .blue, max: max(taskIn, taskOut))
                    tokenBar(label: "Out", value: taskOut, color: .green, max: max(taskIn, taskOut))
                }
            }

            // Session tokens
            row {
                Text("Session").font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    tokenBar(label: "In", value: sessionIn, color: .blue, max: max(sessionIn, sessionOut))
                    tokenBar(label: "Out", value: sessionOut, color: .green, max: max(sessionIn, sessionOut))
                }
            }

            // Totals
            row {
                Text("Totals").font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Task: \(fmt(taskIn + taskOut))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("Session: \(fmt(sessionIn + sessionOut))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.bottom, 15)
        .frame(width: 320)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack { content() }
                .padding(.vertical, 8)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func tokenBar(label: String, value: Int, color: Color, max: Int) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 24, alignment: .trailing)
            GeometryReader { geo in
                let fraction: CGFloat = max > 0 ? CGFloat(value) / CGFloat(max) : 0
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.5))
                    .frame(width: geo.size.width * fraction)
            }
            .frame(width: 80, height: 8)
            Text(fmt(value))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }

    private func fmt(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func shortModel(_ model: String) -> String {
        // Trim long model IDs like "claude-sonnet-4-20250514" to "claude-sonnet-4"
        let parts: [String] = model.components(separatedBy: "-")
        if parts.count > 3, let last = parts.last, last.count == 8, Int(last) != nil {
            return parts.dropLast().joined(separator: "-")
        }
        return model
    }
}
