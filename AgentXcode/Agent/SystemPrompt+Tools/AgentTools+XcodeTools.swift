import Foundation

// MARK: - Xcode Tool Definitions

extension AgentTools {
    
    /// Xcode build/run tools via ScriptingBridge
    nonisolated(unsafe) static let xcodeTools: [ToolDef] = [
        ToolDef(
            name: Name.xcodeBuild,
            description: "Build an Xcode project or workspace via ScriptingBridge. Blocks until build completes. Returns errors/warnings in file:line:col format with code snippets for context.",
            properties: [
                "project_path": ["type": "string", "description": "Path to .xcodeproj or .xcworkspace"],
            ],
            required: ["project_path"]
        ),
        ToolDef(
            name: Name.xcodeRun,
            description: "Build then run an Xcode project via ScriptingBridge. Builds first — only runs if clean. Returns errors if build fails.",
            properties: [
                "project_path": ["type": "string", "description": "Path to .xcodeproj or .xcworkspace"],
            ],
            required: ["project_path"]
        ),
        ToolDef(
            name: Name.xcodeListProjects,
            description: "List all open Xcode projects and workspaces with numbered indices. Use the number with xcode_select_project to choose one.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: Name.xcodeSelectProject,
            description: "Select an open Xcode project by its number from xcode_list_projects. Returns the project path for use with xcode_build/xcode_run.",
            properties: [
                "number": ["type": "integer", "description": "Project number from the list (1-based)"],
            ],
            required: ["number"]
        ),
        ToolDef(
            name: Name.xcodeGrantPermission,
            description: "Grant macOS Automation permission so the agent can control Xcode via ScriptingBridge. Run this once before using xcode_build or xcode_run.",
            properties: [:],
            required: []
        ),
    ]
}