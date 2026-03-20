import Foundation
import OSLog

/// Centralized logging service using OSLog for structured logging.
/// Provides unified logging across the app with privacy-aware redaction.
final class LoggingService {
    static let shared = LoggingService()
    
    // MARK: - Loggers
    
    /// Main agent logger - general app operations
    let agent = Logger(subsystem: "com.macos26.Agent", category: "agent")
    
    /// XPC communication logger
    let xpc = Logger(subsystem: "com.macos26.Agent", category: "xpc")
    
    /// Accessibility operations logger
    let accessibility = Logger(subsystem: "com.macos26.Agent", category: "accessibility")
    
    /// Script execution logger
    let script = Logger(subsystem: "com.macos26.Agent", category: "script")
    
    /// LLM provider logger
    let llm = Logger(subsystem: "com.macos26.Agent", category: "llm")
    
    /// MCP server logger
    let mcp = Logger(subsystem: "com.macos26.Agent", category: "mcp")
    
    /// Web automation logger
    let web = Logger(subsystem: "com.macos26.Agent", category: "web")
    
    /// Messages monitor logger
    let messages = Logger(subsystem: "com.macos26.Agent", category: "messages")
    
    /// Performance logger for timing operations
    let performance = Logger(subsystem: "com.macos26.Agent", category: "performance")
    
    private init() {}
    
    // MARK: - Convenience Methods
    
    /// Log an error with context
    func logError(_ message: String, category: Logger, error: Error? = nil, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        if let error = error {
            category.error("\(fileName):\(line): \(message) - \(error.localizedDescription)")
        } else {
            category.error("\(fileName):\(line): \(message)")
        }
    }
    
    /// Log a warning with context
    func logWarning(_ message: String, category: Logger, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        category.warning("\(fileName):\(line): \(message)")
    }
    
    /// Log an info message
    func logInfo(_ message: String, category: Logger, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        category.info("\(fileName):\(line): \(message)")
    }
    
    /// Log a debug message (only in debug builds)
    func logDebug(_ message: String, category: Logger, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        category.debug("\(fileName):\(line): \(message)")
    }
    
    // MARK: - Performance Timing
    
    /// Time an operation and log the result
    @discardableResult
    func timeOperation<T>(_ description: String, operation: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000 // ms
        performance.info("\(description): \(String(format: "%.2f", duration))ms")
        return result
    }
    
    /// Time an async operation and log the result
    func timeAsyncOperation<T>(_ description: String, operation: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000 // ms
        performance.info("\(description): \(String(format: "%.2f", duration))ms")
        return result
    }
}

// MARK: - Convenience Type Aliases

typealias AgentLog = LoggingService