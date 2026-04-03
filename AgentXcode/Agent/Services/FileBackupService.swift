import Foundation

/// Backs up files before editing, organized by tab UUID.
/// Structure: ~/Documents/AgentScript/backups/<tabUUID>/<timestamp>_<filename>
/// TTL: 1 week — old backups auto-cleaned on launch.
@MainActor
final class FileBackupService {
    static let shared = FileBackupService()

    private let backupsDir: URL
    private let ttl: TimeInterval = 7 * 24 * 60 * 60  // 1 week

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        backupsDir = home.appendingPathComponent("Documents/AgentScript/backups")
        try? FileManager.default.createDirectory(at: backupsDir, withIntermediateDirectories: true)
        cleanExpired()
    }

    // MARK: - Backup

    /// Back up a file before editing. Returns the backup path on success.
    @discardableResult
    func backup(filePath: String, tabID: UUID) -> String? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: filePath) else { return nil }

        let tabDir = backupsDir.appendingPathComponent(tabID.uuidString)
        try? fm.createDirectory(at: tabDir, withIntermediateDirectories: true)

        let fileName = (filePath as NSString).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupName = "\(timestamp)_\(fileName)"
        let backupURL = tabDir.appendingPathComponent(backupName)

        do {
            try fm.copyItem(atPath: filePath, toPath: backupURL.path)
            return backupURL.path
        } catch {
            return nil
        }
    }

    // MARK: - Restore

    /// List all backups for a tab, newest first.
    func listBackups(tabID: UUID) -> [(original: String, backup: String, date: Date)] {
        let tabDir = backupsDir.appendingPathComponent(tabID.uuidString)
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: tabDir.path) else { return [] }

        let formatter = ISO8601DateFormatter()
        return files.compactMap { name -> (String, String, Date)? in
            // Parse timestamp_filename format
            guard let underscoreRange = name.range(of: "_", range: name.index(name.startIndex, offsetBy: 15)..<name.endIndex) else { return nil }
            let timestampStr = String(name[..<underscoreRange.lowerBound])
                .replacingOccurrences(of: "-", with: ":")
            // Restore the colons for hours/minutes/seconds (positions 13,16)
            guard let date = formatter.date(from: timestampStr) else { return nil }
            let fileName = String(name[underscoreRange.upperBound...])
            let backupPath = tabDir.appendingPathComponent(name).path
            return (fileName, backupPath, date)
        }.sorted { $0.2 > $1.2 }
    }

    /// Restore the most recent backup of a specific file for a tab.
    func restore(fileName: String, tabID: UUID) -> Bool {
        let backups = listBackups(tabID: tabID).filter { $0.original == fileName }
        guard let latest = backups.first else { return false }

        // Find the original path by searching common locations
        // The backup only stores the filename, not the full path
        // This is a limitation — caller should provide the full path
        let fm = FileManager.default
        do {
            try fm.copyItem(atPath: latest.backup, toPath: fileName)
            return true
        } catch {
            return false
        }
    }

    /// Restore a specific backup by its full backup path to a target path.
    func restore(backupPath: String, to targetPath: String) -> Bool {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: targetPath) {
                try fm.removeItem(atPath: targetPath)
            }
            try fm.copyItem(atPath: backupPath, toPath: targetPath)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Cleanup

    /// Remove backups older than TTL (1 week).
    func cleanExpired() {
        let fm = FileManager.default
        guard let tabDirs = try? fm.contentsOfDirectory(atPath: backupsDir.path) else { return }

        let cutoff = Date().addingTimeInterval(-ttl)

        for tabDir in tabDirs {
            let tabPath = backupsDir.appendingPathComponent(tabDir)
            guard let files = try? fm.contentsOfDirectory(atPath: tabPath.path) else { continue }

            for file in files {
                let filePath = tabPath.appendingPathComponent(file)
                if let attrs = try? fm.attributesOfItem(atPath: filePath.path),
                   let modified = attrs[.modificationDate] as? Date,
                   modified < cutoff {
                    try? fm.removeItem(at: filePath)
                }
            }

            // Remove empty tab dirs
            if let remaining = try? fm.contentsOfDirectory(atPath: tabPath.path), remaining.isEmpty {
                try? fm.removeItem(at: tabPath)
            }
        }
    }

    /// Remove all backups for a specific tab.
    func clearBackups(tabID: UUID) {
        let tabDir = backupsDir.appendingPathComponent(tabID.uuidString)
        try? FileManager.default.removeItem(at: tabDir)
    }

    /// Count backups for a tab.
    func backupCount(tabID: UUID) -> Int {
        let tabDir = backupsDir.appendingPathComponent(tabID.uuidString)
        return (try? FileManager.default.contentsOfDirectory(atPath: tabDir.path))?.count ?? 0
    }

    /// List ALL backups across all tabs, newest first.
    func allBackups() -> [(original: String, backup: String, date: Date)] {
        let fm = FileManager.default
        guard let tabDirs = try? fm.contentsOfDirectory(atPath: backupsDir.path) else { return [] }
        var all: [(String, String, Date)] = []
        for dir in tabDirs {
            guard let uuid = UUID(uuidString: dir) else { continue }
            all.append(contentsOf: listBackups(tabID: uuid))
        }
        return all.sorted { $0.2 > $1.2 }
    }

    /// Count ALL backups across all tabs.
    func totalBackupCount() -> Int {
        let fm = FileManager.default
        guard let tabDirs = try? fm.contentsOfDirectory(atPath: backupsDir.path) else { return 0 }
        var count = 0
        for dir in tabDirs {
            let tabPath = backupsDir.appendingPathComponent(dir)
            count += (try? fm.contentsOfDirectory(atPath: tabPath.path))?.count ?? 0
        }
        return count
    }
}
