import Foundation

// MARK: - File Operation Tool Definitions

extension AgentTools {
    
    /// File tools: read_file, write_file, edit_file, create_diff, apply_diff, list_files, search_files
    nonisolated(unsafe) static let fileTools: [ToolDef] = [
        ToolDef(
            name: Name.readFile,
            description: "Read file contents with line numbers. Use instead of `cat`. Returns numbered lines for easy reference in edit_file.",
            properties: [
                "file_path": ["type": "string", "description": "Absolute path to the file to read"],
                "offset": ["type": "integer", "description": "1-based line number to start from (default 1)"],
                "limit": ["type": "integer", "description": "Max lines to return (default 2000)"],
            ],
            required: ["file_path"]
        ),
        ToolDef(
            name: Name.writeFile,
            description: "Create or overwrite a file. Creates parent dirs automatically. Returns line count only — call read_file after to verify content.",
            properties: [
                "file_path": ["type": "string", "description": "Absolute path to the file to write"],
                "content": ["type": "string", "description": "The full file content to write"],
            ],
            required: ["file_path", "content"]
        ),
        ToolDef(
            name: Name.editFile,
            description: "Replace exact text in a file. Use instead of sed/awk. You MUST read_file first. The old_string must be unique unless replace_all is true.",
            properties: [
                "file_path": ["type": "string", "description": "Absolute path to the file to edit"],
                "old_string": ["type": "string", "description": "The exact text to find and replace"],
                "new_string": ["type": "string", "description": "The replacement text"],
                "replace_all": ["type": "boolean", "description": "Replace all occurrences (default false)"],
            ],
            required: ["file_path", "old_string", "new_string"]
        ),
        ToolDef(
            name: Name.createDiff,
            description: "Compare two text strings and return a pretty D1F diff showing retained, deleted, and inserted lines with emoji markers.",
            properties: [
                "source": ["type": "string", "description": "The original text"],
                "destination": ["type": "string", "description": "The modified text"],
            ],
            required: ["source", "destination"]
        ),
        ToolDef(
            name: Name.applyDiff,
            description: "Apply a D1F ASCII diff (📎 retain, ❌ delete, ✅ insert) to a file. The diff must use emoji line prefixes. Returns the patched file content.",
            properties: [
                "file_path": ["type": "string", "description": "Absolute path to the file to patch"],
                "diff": ["type": "string", "description": "D1F ASCII diff text with 📎/❌/✅ line prefixes"],
            ],
            required: ["file_path", "diff"]
        ),
        ToolDef(
            name: Name.listFiles,
            description: "Find files matching a glob pattern. Use instead of `find`. Excludes hidden files and .build directories.",
            properties: [
                "pattern": ["type": "string", "description": "Glob pattern (e.g. \"*.swift\", \"Package.swift\")"],
                "path": ["type": "string", "description": "Directory to search in (default: user home). Always provide a project path for best results."],
            ],
            required: ["pattern"]
        ),
        ToolDef(
            name: Name.searchFiles,
            description: "Search file contents by regex pattern. Use instead of `grep`. Returns matching lines with file paths and line numbers.",
            properties: [
                "pattern": ["type": "string", "description": "Regex pattern to search for"],
                "path": ["type": "string", "description": "Directory to search in (default: user home). Always provide a project path for best results."],
                "include": ["type": "string", "description": "File glob filter (e.g. \"*.swift\", \"*.py\")"],
            ],
            required: ["pattern"]
        ),
    ]
}