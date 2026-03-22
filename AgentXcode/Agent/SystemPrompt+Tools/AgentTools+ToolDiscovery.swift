import Foundation

// MARK: - Tool Discovery Definitions

extension AgentTools {
    
    /// Tool discovery tools
    nonisolated(unsafe) static let toolDiscoveryTools: [ToolDef] = [
        ToolDef(
            name: Name.listNativeTools,
            description: "List all enabled native tools.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: Name.listMcpTools,
            description: "List all enabled MCP (Model Context Protocol) tools.",
            properties: [:],
            required: []
        ),
    ]
}