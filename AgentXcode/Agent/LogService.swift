import Foundation

@MainActor @Observable
final class LogService {
    var activityLogPath: String { "\(NSHomeDirectory())/Documents/Agent/activity_log.txt" }
    
    var activityLog: String {
        get {
            try? String(contentsOfFile: activityLogPath, encoding: .utf8)
        }
        set {
            try? newValue.write(toFile: activityLogPath, atomically: true, encoding: .utf8)
        }
    }
    
    private var logBuffer = ""
    private var logFlushTask: Task<Void, Never>?
    private var logPersistTask: Task<Void, Never>?
    private let visibleTaskCount = 5
    
    func appendStreamDelta(_ delta: String) {
        logBuffer += delta
        scheduleLogFlush()
    }
    
    func clearLog() {
        logBuffer = ""
        logFlushTask?.cancel()
        logFlushTask = nil
        activityLog = ""
        try? FileManager.default.removeItem(atPath: activityLogPath)
        // Clean up cached image snapshots
        try? FileManager.default.removeItem(at: Self.logImageCacheDir)
        try? FileManager.default.createDirectory(at: Self.logImageCacheDir, withIntermediateDirectories: true)
    }
    
    private func scheduleLogFlush() {
        logFlushTask?.cancel()
        logFlushTask = Task {
            try? await Task.sleep(for: .seconds(0.5))
            await flushLog()
        }
    }
    
    private func flushLog() {
        logFlushTask?.cancel()
        logFlushTask = nil
        if !logBuffer.isEmpty {
            activityLog += logBuffer
            logBuffer = ""
            trimToRecentTasks()
            schedulePersist()
        }
    }
    
    private func schedulePersist() {
        guard logPersistTask == nil else { return }
        logPersistTask = Task {
            try? await Task.sleep(for: .seconds(2))
            logPersistTask = nil
        }
    }
    
    func persistLogNow() {
        logPersistTask?.cancel()
        logFlushTask?.cancel()
        logFlushTask = nil
        if !logBuffer.isEmpty {
            activityLog += logBuffer
            logBuffer = ""
        }
    }
    
    private func trimToRecentTasks() {
        let marker = "--- New Task ---"
        let parts = activityLog.components(separatedBy: marker)
        let limit = visibleTaskCount
        guard parts.count > limit + 1 else { return }
        let kept = parts.suffix(limit).joined(separator: marker)
        activityLog = marker + kept
    }
    
    static var logImageCacheDir: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/Agent/log_images")
    }
}
