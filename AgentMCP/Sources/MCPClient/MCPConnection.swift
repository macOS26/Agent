import Foundation

// MARK: - Connection Protocol

/// Protocol for MCP transport connections (stdio or HTTP)
protocol MCPConnection: AnyObject, Sendable {
    func sendRequest(method: String, params: [String: Any]?) async throws -> [String: Any]
    func sendNotification(method: String, params: [String: Any]?) throws
    func disconnect()
    var isAlive: Bool { get }
}
