import Foundation
import AgentTools

/// Bridge extension that provides convenience methods using app-specific services
/// (ToolPreferencesService, MCPService) that the AgentTools package doesn't know about.
extension AgentTools {

    /// Claude format with ToolPreferencesService and MCPService integration.
    @MainActor static func claudeFormat(activeGroups: Set<String>? = nil, compact: Bool = false) -> [[String: Any]] {
        let prefs = ToolPreferencesService.shared
        let mcpService = MCPService.shared
        let mcpTools: [MCPToolInfo] = mcpService.discoveredTools
            .filter { mcpService.isToolEnabled(serverName: $0.serverName, toolName: $0.name) }
            .map { MCPToolInfo(serverName: $0.serverName, name: $0.name, description: $0.description, inputSchemaJSON: $0.inputSchemaJSON) }
        return claudeFormat(
            isEnabled: { prefs.isEnabled(.claude, $0, activeGroups: activeGroups) },
            mcpTools: mcpTools,
            compact: compact
        )
    }

    /// Ollama format with ToolPreferencesService and MCPService integration.
    @MainActor static func ollamaTools(for provider: APIProvider, activeGroups: Set<String>? = nil, compact: Bool = false) -> [[String: Any]] {
        let prefs = ToolPreferencesService.shared
        let mcpService = MCPService.shared
        let mcpTools: [MCPToolInfo] = mcpService.discoveredTools
            .filter { mcpService.isToolEnabled(serverName: $0.serverName, toolName: $0.name) }
            .map { MCPToolInfo(serverName: $0.serverName, name: $0.name, description: $0.description, inputSchemaJSON: $0.inputSchemaJSON) }
        return ollamaTools(
            isEnabled: { prefs.isEnabled(provider, $0, activeGroups: activeGroups) },
            mcpTools: mcpTools,
            compact: compact
        )
    }

    /// Backward-compat alias.
    @MainActor static var ollamaFormat: [[String: Any]] { ollamaTools(for: .ollama) }
}
