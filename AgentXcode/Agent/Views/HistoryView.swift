import SwiftUI

struct HistoryView: View {
    let prompts: [String]
    let errorHistory: [String]
    let taskSummaries: [String]
    let tabName: String
    let onClear: () -> Void
    var onRerun: ((String) -> Void)? = nil

    @State private var selectedTaskType: TaskViewType = .prompts

    enum TaskViewType: String, CaseIterable {
        case prompts = "Prompts"
        case errors = "Error History"
        case summaries = "Task Summaries"
    }

    private var currentItems: [String] {
        switch selectedTaskType {
        case .prompts: return prompts
        case .errors: return errorHistory
        case .summaries: return taskSummaries
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("\(tabName) History")
                    .font(.headline)

                Text("View past prompts, errors, and task summaries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(selection: $selectedTaskType) {
                    ForEach(TaskViewType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
            }
            .padding()
            .padding(.bottom, 4)

            Divider()

            // Content
            if currentItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: emptyIcon)
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No \(selectedTaskType.rawValue.lowercased()) yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(currentItems.reversed().enumerated()), id: \.offset) { _, item in
                            historyRow(item)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 340)
            }

            Divider()

            // Footer
            HStack {
                Text("\(currentItems.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear All") { onClear() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(currentItems.isEmpty)
            }
            .padding()
            .padding(.bottom, 15)
        }
        .frame(width: 460)
    }

    // MARK: - Row

    @ViewBuilder
    private func historyRow(_ item: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item)
                        .font(.system(.caption))
                        .lineLimit(selectedTaskType == .prompts ? 2 : 4)
                        .textSelection(.enabled)

                    if selectedTaskType == .errors {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                            Text("Error")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }

                    if selectedTaskType == .summaries {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption2)
                            Text("Completed")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                if selectedTaskType == .prompts, let onRerun {
                    Button {
                        onRerun(item)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Rerun this prompt")
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var emptyIcon: String {
        switch selectedTaskType {
        case .prompts: return "text.bubble"
        case .errors: return "exclamationmark.triangle"
        case .summaries: return "checkmark.circle"
        }
    }
}
