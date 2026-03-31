import Foundation

// MARK: - Errors

public enum MCPClientError: LocalizedError {
    case serverDisabled(String)
    case serverNotConnected(UUID)
    case toolNotFound(UUID)
    case resourceNotFound(String)
    case connectionFailed(String)
    case invalidResponse
    case bufferOverflow

    public var errorDescription: String? {
        switch self {
        case .serverDisabled(let name):
            return "MCP server '\(name)' is disabled"
        case .serverNotConnected(let id):
            return "MCP server \(id) is not connected"
        case .toolNotFound(let id):
            return "Tool \(id) not found"
        case .resourceNotFound(let uri):
            return "Resource '\(uri)' not found"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .invalidResponse:
            return "Invalid response from MCP server"
        case .bufferOverflow:
            return "MCP server exceeded maximum buffer size"
        }
    }
}
