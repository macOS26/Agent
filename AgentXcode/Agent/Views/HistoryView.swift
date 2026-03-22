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
        case .prompts:
            return prompts
        case .errors:
            return errorHistory
        case .summaries:
            return taskSummaries
        }
    }
    
    private var canRerun: Bool {
        selectedTaskType == .prompts
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
                Text("\(currentItems.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear All") { onClear() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(currentItems.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            if currentItems.isEmpty {
                Text("No \(selectedTaskType.rawValue.lowercased()) yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(Array(currentItems.reversed().enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item)
                                .font(.system(.body))
                                .lineLimit(selectedTaskType == .prompts ? 2 : 4)
                                .textSelection(.enabled)
                            
                            Spacer()
                            
                            if canRerun, let onRerun = onRerun {
                                Button(action: {
                                    // Extract just the prompt text from history items
                                    let promptText: String
                                    if selectedTaskType == .prompts {
                                        // Prompts are stored directly
                                        promptText = item
                                    } else {
                                        // For error/summary items, extract the actual prompt if possible
                                        // This is a simple extraction - might need refinement
                                        if let promptStart = item.range(of: "] ") {
                                            let afterBracket = item[promptStart.upperBound...]
                                            promptText = String(afterBracket)
                                        } else {
                                            promptText = item
                                        }
                                    }
                                    onRerun(promptText)
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
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Error entry - check logs for details")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 2)
                        }
                        
                        if selectedTaskType == .summaries {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Task summary - completed successfully")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.bottom, 15)
        .frame(width: 600)
        .frame(maxHeight: 500)
    }
}
