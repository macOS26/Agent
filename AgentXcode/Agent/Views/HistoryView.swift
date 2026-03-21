import SwiftUI

struct HistoryView: View {
    let prompts: [String]
    let tabName: String
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(tabName) History")
                    .font(.headline)
                Spacer()
                Text("\(prompts.count) prompts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Clear All") { onClear() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(prompts.isEmpty)
            }
            .padding()

            Divider()

            if prompts.isEmpty {
                Text("No prompts yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(Array(prompts.reversed().enumerated()), id: \.offset) { _, prompt in
                    Text(prompt)
                        .font(.system(.body))
                        .lineLimit(2)
                        .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}
