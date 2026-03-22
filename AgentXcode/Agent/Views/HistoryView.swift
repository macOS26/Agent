import SwiftUI

struct HistoryView: View {
    let prompts: [String]
    let tabName: String
    let onClear: () -> Void
    var onRerun: ((String) -> Void)? = nil
    
    @State private var showTaskSummaries = false
    @State private var selectedTaskType: TaskViewType = .prompts

    enum TaskViewType: String, CaseIterable {
        case prompts = "Prompts"
        case errors = "Error History"
        case summaries = "Task Summaries"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(tabName) History")
                .font(.headline)
            
            Picker("View", selection: $selectedTaskType) {
                ForEach(TaskViewType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            Divider()
            
            HStack {
                Text("\(prompts.count) entries")
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
                Text("No history yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(Array(prompts.reversed().enumerated()), id: \.offset) { index, prompt in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(prompt)
                                .font(.system(.body))
                                .lineLimit(selectedTaskType == .prompts ? 2 : 4)
                                .textSelection(.enabled)
                            
                            Spacer()
                            
                            if let onRerun = onRerun {
                                Button(action: {
                                    onRerun(prompt)
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                                .help("Rerun this prompt in current tab")
                            }
                        }
                        
                        if selectedTaskType == .errors {
                            // Error indicator - would show actual error history
                            if prompt.lowercased().contains("error") || prompt.lowercased().contains("fail") {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("Contains error indicators")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.top, 2)
                            }
                        }
                        
                        if selectedTaskType == .summaries {
                            // Summary display - would show actual summaries
                            Text("Summary: Task executed successfully")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.bottom, 15)
        .frame(width: 550)
        .frame(maxHeight: 500)
    }
}
