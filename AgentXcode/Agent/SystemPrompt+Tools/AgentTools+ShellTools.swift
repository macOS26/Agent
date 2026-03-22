import Foundation

// MARK: - Shell Execution Tool Definitions

extension AgentTools {
    
    /// Shell execution tools: execute_agent_command, execute_daemon_command, task_complete
    nonisolated(unsafe) static let shellTools: [ToolDef] = [
        ToolDef(
            name: Name.executeAgentCommand,
            description: "Execute a shell command as the current user (no root). NO TCC permissions. Use for git, builds, file ops, homebrew, etc.",
            properties: [
                "command": ["type": "string", "description": "The bash command to execute as the current user"],
            ],
            required: ["command"]
        ),
        ToolDef(
            name: Name.executeDaemonCommand,
            description: "Execute a shell command with ROOT privileges via the privileged daemon. NO TCC. Only use when root is required: system packages, /System or /Library modifications, disk operations.",
            properties: [
                "command": ["type": "string", "description": "The bash command to execute as root"],
            ],
            required: ["command"]
        ),
        ToolDef(
            name: Name.taskComplete,
            description: "Signal that the task has been completed. Always call this when done.",
            properties: [
                "summary": ["type": "string", "description": "Brief summary of what was accomplished"],
            ],
            required: ["summary"]
        ),
    ]
}