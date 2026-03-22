import SwiftUI

struct HistoryView: View {
    let prompts: [String]
    let tabName: String
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(tabName) History")
                .font(.headline)
            
            Text("Browse and manage previous prompts.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Divider()
            
            HStack {
                Text("\(prompts.count) prompts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear All") { onClear() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(prompts.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

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
        .padding(.bottom, 15)
        .frame(width: 500)
        .frame(maxHeight: 400)
    }
}
