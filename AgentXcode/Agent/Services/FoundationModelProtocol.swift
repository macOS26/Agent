import Foundation

// MARK: - Foundation Model Service Protocol

/// Protocol defining the interface for Foundation Model services.
/// Allows for dependency injection and testing.
protocol FoundationModelServiceProtocol: Sendable {
    /// History context for conversations
    var historyContext: String { get }
    /// User home directory
    var userHome: String { get }
    /// User name
    var userName: String { get }
    /// Project folder path
    var projectFolder: String { get }
    
    /// Names of tools currently enabled for Apple Intelligence
    var enabledToolNames: [String] { get }
    
    /// Check if Apple Intelligence is available on this device
    static var isAvailable: Bool { get }
    
    /// Get the reason why Apple Intelligence is unavailable
    static var unavailabilityReason: String { get }
    
    /// Reset the session (e.g., after prompt changes)
    func resetSession()
    
    /// Send messages and get a response (non-streaming)
    func send(messages: [[String: Any]]) async throws -> (content: [[String: Any]], stopReason: String)
    
    /// Send messages with streaming response
    func sendStreaming(
        messages: [[String: Any]],
        onTextDelta: @escaping @Sendable (String) -> Void
    ) async throws -> (content: [[String: Any]], stopReason: String)
}