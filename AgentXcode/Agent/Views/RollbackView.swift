import SwiftUI

/// Shows file backups for the current tab with restore/delete options.
struct RollbackView: View {
    @Bindable var viewModel: AgentViewModel
    @State private var backups: [(original: String, backup: String, date: Date)] = []
    @State private var restoreResult: String?

    private var tabID: UUID {
        viewModel.selectedTabId ?? AgentViewModel.mainTabBackupID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("File Backups")
                    .font(.headline)
                Spacer()
                Text("\(backups.count) file\(backups.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if backups.isEmpty {
                Text("No backups yet. Files are backed up automatically before edits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(backups, id: \.backup) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.original)
                                        .font(.caption.monospaced())
                                        .lineLimit(1)
                                    Text(formatDate(item.date))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Restore") {
                                    restore(item)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            if let result = restoreResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.hasPrefix("Error") ? .red : .green)
            }

            HStack {
                Button("Clear All") {
                    FileBackupService.shared.clearBackups(tabID: tabID)
                    loadBackups()
                    restoreResult = "All backups cleared"
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Refresh") {
                    loadBackups()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 400)
        .onAppear { loadBackups() }
    }

    private func loadBackups() {
        backups = FileBackupService.shared.listBackups(tabID: tabID)
        restoreResult = nil
    }

    private func restore(_ item: (original: String, backup: String, date: Date)) {
        // The backup filename contains the original filename
        // We need the original full path — prompt user or use project folder
        let projectFolder = viewModel.projectFolder
        let originalPath = projectFolder.isEmpty
            ? item.original
            : (projectFolder as NSString).appendingPathComponent(item.original)

        // Try to find the original file in project
        let candidates = [
            originalPath,
            item.original,  // might be an absolute path stored as filename
        ]

        for path in candidates {
            if FileBackupService.shared.restore(backupPath: item.backup, to: path) {
                restoreResult = "Restored \(item.original)"
                viewModel.appendLog("🔄 Restored \(item.original) from backup")
                viewModel.flushLog()
                return
            }
        }
        restoreResult = "Error: could not find original path for \(item.original)"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
