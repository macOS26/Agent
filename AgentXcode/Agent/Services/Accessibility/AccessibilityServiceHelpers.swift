import Foundation
import AppKit
@preconcurrency import ApplicationServices

/// Shared helper utilities for Accessibility services.
/// Provides JSON formatting, audit logging, and process lookup.
enum AccessibilityServiceHelpers {
    
    // MARK: - JSON Helpers
    
    /// Create a success JSON response
    static func successJSON(_ data: Any) -> String {
        let wrapper: [String: Any] = ["success": true, "data": data]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: wrapper, options: .prettyPrinted),
              let jsonStr = String(data: jsonData, encoding: .utf8) else {
            return "{\"success\": true}"
        }
        return jsonStr
    }
    
    /// Create an error JSON response
    static func errorJSON(_ msg: String) -> String {
        let wrapper: [String: Any] = ["success": false, "error": msg]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: wrapper, options: .prettyPrinted),
              let jsonStr = String(data: jsonData, encoding: .utf8) else {
            return "{\"success\": false, \"error\": \"\(msg)\"}"
        }
        return jsonStr
    }
    
    // MARK: - Process Lookup
    
    /// Get process name from PID
    static func getProcessName(pid: pid_t) -> String? {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        return app.localizedName ?? app.bundleIdentifier
    }
    
    // MARK: - Audit Logging
    
    /// Log an accessibility action for audit purposes
    static func logAudit(_ message: String) {
        // Use a simple file-based audit log
        let logDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/AgentScript")
        let logPath = logDir.appendingPathComponent("accessibility_audit.log")
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"
        
        do {
            try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: logPath.path) {
                let fileHandle = try FileHandle(forWritingTo: logPath)
                fileHandle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                try fileHandle.close()
            } else {
                try logEntry.write(to: logPath, atomically: true, encoding: .utf8)
            }
        } catch {
            // Silent fail - audit logging is not critical
        }
    }
    
    /// Get recent audit log entries
    static func getAuditLog(limit: Int = 50) -> String {
        let logPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/AgentScript/accessibility_audit.log")
        
        guard FileManager.default.fileExists(atPath: logPath.path),
              let content = try? String(contentsOf: logPath, encoding: .utf8) else {
            return AccessibilityServiceHelpers.successJSON(["entries": []])
        }
        
        let lines = content.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .suffix(limit)
        
        let entries = lines.map { line -> [String: String] in
            // Parse log entry format: [timestamp] message
            if line.hasPrefix("["), let closeBracket = line.firstIndex(of: "]") {
                let timestamp = String(line[line.index(after: line.startIndex)..<closeBracket])
                let message = String(line[line.index(after: closeBracket)...].trimmingCharacters(in: .whitespaces))
                return ["timestamp": timestamp, "message": message]
            }
            return ["timestamp": "", "message": line]
        }
        
        return AccessibilityServiceHelpers.successJSON(["entries": Array(entries.reversed()), "count": entries.count])
    }
}