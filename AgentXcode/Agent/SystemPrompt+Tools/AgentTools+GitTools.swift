import Foundation

// MARK: - Git Tool Definitions

extension AgentTools {
    
    /// Git tools: git_status, git_diff, git_log, git_commit, git_diff_patch, git_branch
    nonisolated(unsafe) static let gitTools: [ToolDef] = [
        ToolDef(
            name: Name.gitStatus,
            description: "Show current branch, staged/unstaged changes, and untracked files.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.gitDiff,
            description: "Show file changes as a unified diff. Can show staged changes, unstaged changes, or diff against a branch/commit.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "staged": ["type": "boolean", "description": "Show staged changes only (default false)"],
                "target": ["type": "string", "description": "Branch, commit, or ref to diff against (e.g. \"main\", \"HEAD~3\")"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.gitLog,
            description: "Show recent commit history as one-line summaries.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "count": ["type": "integer", "description": "Number of commits to show (default 20, max 100)"],
            ],
            required: []
        ),
        ToolDef(
            name: Name.gitCommit,
            description: "Stage files and create a commit. If no files specified, stages all changes.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "message": ["type": "string", "description": "Commit message"],
                "files": ["type": "array", "items": ["type": "string"] as [String: Any], "description": "Specific files to stage (default: all changes)"] as [String: Any],
            ],
            required: ["message"]
        ),
        ToolDef(
            name: Name.gitDiffPatch,
            description: "Apply a unified diff patch to files in the repository. Use for complex multi-line edits that are easier to express as a patch.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "patch": ["type": "string", "description": "Unified diff patch content"],
            ],
            required: ["patch"]
        ),
        ToolDef(
            name: Name.gitBranch,
            description: "Create a new git branch, optionally switching to it.",
            properties: [
                "path": ["type": "string", "description": "Repository path (REQUIRED for git operations — provide the project directory)"],
                "name": ["type": "string", "description": "Branch name to create"],
                "checkout": ["type": "boolean", "description": "Switch to the new branch (default true)"],
            ],
            required: ["name"]
        ),
    ]
}