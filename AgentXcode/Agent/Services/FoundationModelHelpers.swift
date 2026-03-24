import FoundationModels
import Foundation

// MARK: - Agent Tool Output

/// Output type for native Foundation Models tools.
struct AgentToolOutput: ToolOutput {
    let result: String
    
    init(result: String) {
        self.result = result
    }
}

// MARK: - Tool Definitions for Foundation Models

/// Tool definition for native tools that wraps AgentToolDef.
struct NativeAgentTool: Tool {
    typealias Arguments = EmptyArgs
    typealias Output = AgentToolOutput
    
    let name: AgentTools.Name
    let description: String
    
    init(toolDef: AgentToolDef) {
        self.name = toolDef.name
        self.description = toolDef.description
    }
    
    func call(arguments: EmptyArgs) async throws -> AgentToolOutput {
        guard let handler = NativeToolContext.toolHandler else {
            return AgentToolOutput(result: "Error: No tool handler configured")
        }
        let output = await handler(name.rawValue, [:])
        await MainActor.run { NativeToolContext.lastToolOutput = output }
        return AgentToolOutput(result: output)
    }
}

/// Empty arguments for tools that don't need structured input.
@Generable
struct EmptyArgs {
    @Guide(description: "No arguments")
    var none: String?
}