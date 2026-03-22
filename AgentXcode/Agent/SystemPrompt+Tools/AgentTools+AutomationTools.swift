import Foundation

// MARK: - Automation Tool Definitions

extension AgentTools {
    
    /// Agent script management tools
    nonisolated(unsafe) static let agentScriptTools: [ToolDef] = [
        ToolDef(
            name: Name.listAgentScripts,
            description: "List all Swift automation scripts in ~/Documents/AgentScript/agents/",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: Name.readAgentScript,
            description: "Read the source code of a Swift automation script.",
            properties: [
                "name": ["type": "string", "description": "Script name (with or without .swift)"],
            ],
            required: ["name"]
        ),
        ToolDef(
            name: Name.createAgentScript,
            description: "Create a new Swift automation script in ~/Documents/AgentScript/agents/",
            properties: [
                "name": ["type": "string", "description": "Script filename (with or without .swift)"],
                "content": ["type": "string", "description": "Swift source code"],
            ],
            required: ["name", "content"]
        ),
        ToolDef(
            name: Name.updateAgentScript,
            description: "Update an existing Swift automation script.",
            properties: [
                "name": ["type": "string", "description": "Script filename"],
                "content": ["type": "string", "description": "New Swift source code"],
            ],
            required: ["name", "content"]
        ),
        ToolDef(
            name: Name.runAgentScript,
            description: "PRIORITY 1 for app automation. Compile and run a Swift dylib with full TCC. Use existing scripts first (list_agent_scripts), create new ones with ScriptingBridge protocols. Use lookup_sdef and read_agent_script to check app dictionaries and bridge Swift files. NSAppleScript fallback if ScriptingBridge has issues. Output streams live — do NOT repeat stdout.",
            properties: [
                "name": ["type": "string", "description": "Script filename (without .swift)"],
                "arguments": ["type": "string", "description": "Simple string passed via AGENT_SCRIPT_ARGS env var. For complex data, use JSON files instead."],
            ],
            required: ["name"]
        ),
        ToolDef(
            name: Name.deleteAgentScript,
            description: "Delete a Swift automation script.",
            properties: [
                "name": ["type": "string", "description": "Script filename"],
            ],
            required: ["name"]
        ),
    ]
    
    /// AppleScript and osascript tools
    nonisolated(unsafe) static let appleScriptTools: [ToolDef] = [
        ToolDef(
            name: Name.runApplescript,
            description: "Execute AppleScript code in-process via NSAppleScript with full TCC. Use lookup_sdef first to get correct terminology. For quick automation that doesn't need a compiled AgentScript.",
            properties: [
                "source": ["type": "string", "description": "AppleScript source code to execute"],
            ],
            required: ["source"]
        ),
        ToolDef(
            name: Name.runOsascript,
            description: "Run AppleScript source code via osascript in-process with full TCC. Use for app automation via AppleScript. Prefer run_applescript or run_agent_script when available.",
            properties: [
                "script": ["type": "string", "description": "AppleScript source code to execute"],
            ],
            required: ["script"]
        ),
        ToolDef(
            name: Name.executeJavascript,
            description: "Run JavaScript for Automation (JXA) code via osascript. Use for app automation with JavaScript syntax. Example: var app = Application('Finder'); app.selection()",
            properties: [
                "source": ["type": "string", "description": "JXA source code to execute"],
            ],
            required: ["source"]
        ),
    ]
    
    /// Saved AppleScripts
    nonisolated(unsafe) static let savedAppleScriptTools: [ToolDef] = [
        ToolDef(
            name: Name.listAppleScripts,
            description: "List all saved AppleScript files in ~/Documents/AgentScript/applescript/.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: Name.runAppleScript,
            description: "Run a saved AppleScript by name. List first with list_apple_scripts.",
            properties: [
                "name": ["type": "string", "description": "Name of the saved AppleScript (without .applescript extension)"],
            ],
            required: ["name"]
        ),
        ToolDef(
            name: Name.saveAppleScript,
            description: "Save an AppleScript to ~/Documents/AgentScript/applescript/ for reuse.",
            properties: [
                "name": ["type": "string", "description": "Name for the script (without .applescript extension)"],
                "source": ["type": "string", "description": "AppleScript source code"],
            ],
            required: ["name", "source"]
        ),
        ToolDef(
            name: Name.deleteAppleScript,
            description: "Delete a saved AppleScript file.",
            properties: [
                "name": ["type": "string", "description": "Name of the saved AppleScript to delete"],
            ],
            required: ["name"]
        ),
    ]
    
    /// Saved JavaScript/JXA
    nonisolated(unsafe) static let savedJavascriptTools: [ToolDef] = [
        ToolDef(
            name: Name.listJavascript,
            description: "List all saved JavaScript (JXA) files in ~/Documents/AgentScript/javascript/.",
            properties: [:],
            required: []
        ),
        ToolDef(
            name: Name.runJavascript,
            description: "Run a saved JavaScript (JXA) script by name. List first with list_javascript.",
            properties: [
                "name": ["type": "string", "description": "Name of the saved script (without .js extension)"],
            ],
            required: ["name"]
        ),
        ToolDef(
            name: Name.saveJavascript,
            description: "Save a JXA script to ~/Documents/AgentScript/javascript/ for reuse.",
            properties: [
                "name": ["type": "string", "description": "Name for the script (without .js extension)"],
                "source": ["type": "string", "description": "JavaScript for Automation source code"],
            ],
            required: ["name", "source"]
        ),
        ToolDef(
            name: Name.deleteJavascript,
            description: "Delete a saved JavaScript (JXA) file.",
            properties: [
                "name": ["type": "string", "description": "Name of the saved script to delete"],
            ],
            required: ["name"]
        ),
    ]
    
    /// Apple Event query
    nonisolated(unsafe) static let appleEventTools: [ToolDef] = [
        ToolDef(
            name: Name.appleEventQuery,
            description: "Query a scriptable Mac app via ObjC dispatch. Flat keys, one operation per call. Use lookup_sdef first.",
            properties: [
                "bundle_id": ["type": "string", "description": "App bundle identifier (e.g. com.apple.Music)"],
                "action": ["type": "string", "description": "One of: get, iterate, index, call, filter"],
                "key": ["type": "string", "description": "Property key for 'get' action"],
                "properties": ["type": "string", "description": "Comma-separated property names for 'iterate' (e.g. \"name,artist,album\")"],
                "limit": ["type": "integer", "description": "Max items for 'iterate' (default 50)"],
                "index": ["type": "integer", "description": "Array index for 'index' action"],
                "method": ["type": "string", "description": "Method name for 'call' action"],
                "arg": ["type": "string", "description": "Argument for 'call' action"],
                "predicate": ["type": "string", "description": "NSPredicate format string for 'filter' action"],
            ],
            required: ["bundle_id", "action"]
        ),
        ToolDef(
            name: Name.lookupSdef,
            description: "Read an app's SDEF scripting dictionary. ALWAYS use this to read SDEFs — never use shell commands to find .sdef files. Returns commands, classes, properties, elements, and enums. Use before writing osascript, NSAppleScript, apple_event_query, or ScriptingBridge code.",
            properties: [
                "bundle_id": ["type": "string", "description": "App bundle identifier (e.g. com.apple.Music). Use 'list' to see all available SDEFs."],
                "class_name": ["type": "string", "description": "Optional: get details for a specific class (e.g. 'track', 'application')"],
            ],
            required: ["bundle_id"]
        ),
    ]
}