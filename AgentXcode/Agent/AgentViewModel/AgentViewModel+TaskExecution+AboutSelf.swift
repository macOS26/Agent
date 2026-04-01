//
//  AgentViewModel+TaskExecution+AboutSelf.swift
//  Agent
//
//  AboutSelf tool implementation - provides information about Agent's capabilities
//

import Foundation

// MARK: - AboutSelf Tool

extension AgentViewModel {
    
    /// Handles the about_self tool - returns information about Agent's capabilities
    func handleAboutSelfTool(name: String, input: [String: Any]) async -> String? {
        guard name == "about_self" else { return nil }
        
        let topic = input["topic"] as? String ?? "all"
        let detail = input["detail"] as? String ?? "standard"
        
        let detailPrefix = detail == "brief" ? "Brief" : detail == "detailed" ? "Detailed" : ""
        
        let aboutText: String
        
        switch topic.lowercased() {
        case "tools":
            aboutText = """
            \(detailPrefix) Agent! Tools Overview

            Agent! uses consolidated action-based tools for macOS automation:

            FILE & CODING (action-based):
            - file_manager (action: read, write, edit, list, search, create, apply, undo, diff_apply): All file operations
            - git (action: status, diff, log, commit, diff_patch, branch): Git version control

            XCODE (action-based):
            - xcode (action: build, run, list_projects, select_project, add_file, remove_file, analyze, snippet): Xcode project management

            AUTOMATION (action-based):
            - applescript_tool (action: execute, lookup_sdef, list, run, save, delete): AppleScript with full TCC
            - javascript_tool (action: execute, list, run, save, delete): JavaScript for Automation (JXA)
            - agent (action: list, read, create, update, run, delete, combine): Swift AgentScripts
            - accessibility (action: list_windows, click, type_text, press_key, find_element, etc.): UI automation

            WEB (action-based):
            - web (action: search, open, find, click, type, read_content, navigate, etc.): Browser automation

            DIRECT TOOLS (no action parameter):
            - execute_agent_command: Run shell commands as current user
            - execute_daemon_command: Run shell commands as root (troubleshooting, diagnostics)
            - batch_commands: Run multiple shell commands in one call
            - batch_tools: Run multiple tool calls in one batch
            - plan_mode (action: create, update, read, list, delete): Task planning

            CONVERSATION (action-based):
            - conversation (action: write, transform, fix, about): Text generation, formatting, corrections, self-description
            - send_message: Send content via iMessage, email, or SMS

            Use list_tools to see all available tools.
            """
            
        case "features":
            aboutText = """
            \(detailPrefix) Agent! Features
            
            CORE FEATURES:
            - Multi-provider LLM support (Claude, OpenAI, Ollama, Apple Intelligence)
            - Streaming output with real-time display
            - Task history with AI-powered summarization
            - Chat history management with persistence
            - Screenshot and image attachment support
            
            AUTOMATION FEATURES:
            - Full TCC permissions (Accessibility, Automation, Screen Recording)
            - ScriptingBridge integration for app control
            - MCP (Model Context Protocol) server support
            - Reusable AgentScripts for complex automation
            
            DEVELOPER FEATURES:
            - Xcode project building and running
            - Git integration for version control
            - Code editing with diff visualization
            - Swift script compilation and execution
            
            UI FEATURES:
            - Native macOS design with split-pane interface
            - Conversation history with task tracking
            - Tab-based workflow for multiple tasks
            - Keyboard shortcuts for efficiency
            
            PRIVACY:
            - All automation runs locally on your Mac
            - API keys stored securely in Keychain
            - No data collection or telemetry
            """
            
        case "scripting":
            aboutText = """
            \(detailPrefix) Agent! Scripting Guide
            
            SWIFT AGENTSCRIPTS:
            Agent! can compile and run Swift scripts with full TCC permissions.
            Scripts are stored in ~/Documents/AgentScript/agents/
            
            Script template:
            ```swift
            import Foundation
            
            @_cdecl("script_main")
            public func scriptMain() -> Int32 {
                // Your automation code here
                print("Hello from AgentScript!")
                return 0
            }
            ```
            
            Rules:
            - Use @_cdecl("script_main") and return Int32
            - No exit() calls or top-level code
            - Access arguments via AGENT_SCRIPT_ARGS environment variable
            - Or use JSON files: ~/Documents/AgentScript/json/{Name}_input.json
            
            APPLESCRIPT:
            - applescript_tool (action: execute): Run AppleScript directly
            - applescript_tool (action: save, run, list, delete): Manage saved scripts
            - applescript_tool (action: lookup_sdef): Read app scripting dictionaries

            JXA (JAVASCRIPT FOR AUTOMATION):
            - javascript_tool (action: execute): Run JavaScript directly
            - javascript_tool (action: save, run, list, delete): Manage saved scripts

            SCRIPTINGBRIDGE:
            - applescript_tool (action: lookup_sdef): Read app dictionaries
            """
            
        case "automation":
            aboutText = """
            \(detailPrefix) Agent! Automation Capabilities
            
            APP CONTROL:
            Agent! can control macOS apps using:
            - applescript_tool (action: execute): AppleScript with full TCC
            - javascript_tool (action: execute): JavaScript for Automation
            - agent (action: run): Swift AgentScripts with ScriptingBridge
            - accessibility (action: click, type_text, find_element, etc.): UI automation

            ACCESSIBILITY AUTOMATION:
            Use accessibility tool with actions:
            - find_element, get_children: Find UI elements by role, title, or value
            - click, type_text, press_key: Simulate user input
            - scroll_to_element, drag: Navigate and interact
            - highlight_element: Visual verification

            WEB AUTOMATION:
            Use web tool with actions:
            - open, navigate: Open URLs and navigate
            - find, click, type: Interact with web elements
            - read_content: Extract page content
            - execute_js: Run JavaScript in browser

            SYSTEM TROUBLESHOOTING:
            - execute_agent_command: Shell commands as current user
            - execute_daemon_command: Root-level diagnostics (system logs, disk health, network, launchd services)

            SECURITY:
            All automation inherits Agent!'s TCC permissions
            No additional permission prompts needed
            """
            
        case "coding":
            aboutText = """
            \(detailPrefix) Agent! Coding Assistance
            
            CODE OPERATIONS:
            - Read any text file with line numbers
            - Write new files or edit existing ones
            - Search files by content or pattern
            - Apply diffs for precise changes
            
            GIT WORKFLOW:
            - View status, diffs, and history
            - Stage and commit changes
            - Create and switch branches
            - Apply patches
            
            XCODE INTEGRATION:
            - xcode (action: build): Build projects
            - xcode (action: run): Run apps
            - xcode (action: list_projects, select_project): Manage open projects
            - xcode (action: analyze, snippet): Code review and inspection

            BEST PRACTICES:
            Agent! prefers native tools over shell commands
            Use file_manager for file operations, git for version control
            Build Xcode projects with xcode (action: build)
            """
            
        default: // "all"
            aboutText = """
            \(detailPrefix) About Agent!
            
            Agent! is a native macOS automation assistant that helps you automate tasks, write code, control apps, and manage your Mac.
            
            WHAT I CAN DO:
            - Control apps using AppleScript, JavaScript, or Accessibility
            - Read, write, and edit files in any project
            - Build and run Xcode projects
            - Automate web browsers (Safari, Chrome, Firefox)
            - Execute shell commands with user or root privileges
            - Manage git repositories and commits
            - Generate, transform, and fix text
            - Send messages via iMessage, email, or SMS
            
            HOW TO USE ME:
            Simply describe what you want to accomplish in natural language.
            I will choose the appropriate tools and execute them.
            
            EXAMPLES:
            - "Read the main.swift file and explain it"
            - "Build the Xcode project and fix any errors"
            - "Write a paragraph about machine learning"
            - "Turn this text into a grocery list"
            - "Fix spelling and grammar in this paragraph, no emojis"
            - "Send this summary to me via iMessage"
            - "Automate Safari to fill out this form"
            
            CURRENT CONTEXT:
            - Working directory: \(projectFolder)
            - User: \(NSFullUserName())
            - System: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
            
            Type naturally and I will help you get things done.
            """
        }
        
        return aboutText
    }
}