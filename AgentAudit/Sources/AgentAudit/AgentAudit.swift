import os
import Foundation

/// Lightweight audit logger for Agent! — writes to os.log (visible in Console.app).
/// Categories map to security-relevant subsystems. All methods are nonisolated and thread-safe.
public enum AuditLog {

    // MARK: - Categories

    public enum Category: String {
        case launchAgent    = "LaunchAgent"
        case launchDaemon   = "LaunchDaemon"
        case accessibility  = "Accessibility"
        case appleScript    = "AppleScript"
        case agentScript    = "AgentScript"
        case permission     = "Permission"
        case web            = "Web"
        case mcp            = "MCP"
        case xcode          = "Xcode"
        case shell          = "Shell"
    }

    // MARK: - Loggers (one per category for efficient filtering)

    private static let subsystem = "Agent.app.toddbruss.audit"

    nonisolated(unsafe) private static let loggers: [Category: Logger] = {
        var map: [Category: Logger] = [:]
        for cat in [Category.launchAgent, .launchDaemon, .accessibility,
                    .appleScript, .agentScript, .permission, .web, .mcp, .xcode, .shell] {
            map[cat] = Logger(subsystem: subsystem, category: cat.rawValue)
        }
        return map
    }()

    // MARK: - In-Memory Ring Buffer (for ax_get_audit_log tool)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var ringBuffer: [String] = []
    private static let maxEntries = 1000

    // MARK: - Public API

    /// Log an audit event. Writes to os.log and in-memory ring buffer.
    public nonisolated static func log(_ category: Category, _ message: String) {
        let logger = loggers[category]!
        logger.info("\(message, privacy: .public)")

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] [\(category.rawValue)] \(message)"
        lock.lock()
        ringBuffer.append(entry)
        if ringBuffer.count > maxEntries {
            ringBuffer.removeFirst(100)
        }
        lock.unlock()
    }

    /// Log a permission request and its outcome.
    public nonisolated static func permission(_ what: String, granted: Bool) {
        let status = granted ? "GRANTED" : "DENIED"
        log(.permission, "\(what): \(status)")
    }

    /// Log a denied/failed operation.
    public nonisolated static func denied(_ category: Category, _ message: String) {
        let logger = loggers[category]!
        logger.warning("\(message, privacy: .public)")

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] [\(category.rawValue)] DENIED: \(message)"
        lock.lock()
        ringBuffer.append(entry)
        if ringBuffer.count > maxEntries {
            ringBuffer.removeFirst(100)
        }
        lock.unlock()
    }

    /// Retrieve recent audit entries (for the ax_get_audit_log tool).
    public nonisolated static func recentEntries(limit: Int = 50) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(ringBuffer.suffix(limit))
    }
}
