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
            
            Agent! provides powerful automation tools for macOS:
            
            FILE & CODING TOOLS:
            - read_file, write_file, edit_file: Read, create, and modify files
            - create_diff, apply_diff: Compare and patch text with visual diffs
            - list_files, search_files: Find files by pattern or content
            - git_status, git_diff, git_log, git_commit: Git version control
            
            AUTOMATION TOOLS:
            - run_applescript, run_osascript: Execute AppleScript with full TCC permissions
            - execute_javascript: JavaScript for Automation (JXA)
            - apple_event_query: Query scriptable apps via Apple Events
            - run_agent: Compile and run Swift automation scripts
            
            ACCESSIBILITY TOOLS:
            - ax_click, ax_type_text, ax_press_key: Simulate user input
            - ax_find_element, ax_wait_for_element: Find UI elements
            - ax_screenshot: Capture screen regions or windows
            
            XCODE TOOLS:
            - xcode_build, xcode_run: Build and run Xcode projects
            - xcode_list_projects, xcode_select_project: Manage open projects
            
            WEB AUTOMATION:
            - web_open, web_find, web_click, web_type: Browser automation
            - selenium_start, selenium_navigate: Selenium WebDriver support
            
            CONVERSATION TOOLS:
            - write_text: Generate prose about any subject
            - transform_text: Convert text to lists, outlines, summaries
            - send_message: Send content via iMessage, email, SMS
            - fix_text: Correct spelling and grammar
            - about_self: Learn about Agent's capabilities
            
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
            Save reusable scripts with save_apple_script
            Run saved scripts with run_apple_script
            Or execute directly with run_applescript
            
            JXA (JAVASCRIPT FOR AUTOMATION):
            Execute JavaScript with execute_javascript
            Save reusable scripts with save_javascript
            
            SCRIPTINGBRIDGE:
            Use lookup_sdef to read app dictionaries
            Create Swift bridges with GenerateBridge script
            Query apps with apple_event_query
            """
            
        case "automation":
            aboutText = """
            \(detailPrefix) Agent! Automation Capabilities
            
            APP CONTROL:
            Agent! can control macOS apps using:
            - AppleScript (run_applescript, run_osascript)
            - JavaScript for Automation (execute_javascript)
            - ScriptingBridge (via AgentScripts)
            - Apple Events (apple_event_query)
            - Accessibility API (ax_* tools)
            
            ACCESSIBILITY AUTOMATION:
            Full UI automation via Accessibility API:
            - Find elements by role, title, or value
            - Click, type, scroll, and drag
            - Wait for elements to appear
            - Highlight elements for verification
            - Take screenshots
            
            WEB AUTOMATION:
            - Safari/Chrome/Firefox control via AppleScript
            - Selenium WebDriver support
            - Element finding by CSS, XPath, or accessibility
            - Form filling and navigation
            
            SCHEDULED TASKS:
            Create LaunchAgents/LaunchDaemons for recurring automation
            Use cron or launchd for scheduling
            
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
            - Build projects with xcode_build
            - Run apps with xcode_run
            - List and select open projects
            - View build errors with context
            
            PROJECT STRUCTURE:
            - Navigate complex codebases
            - Understand file relationships
            - Refactor with confidence
            
            BEST PRACTICES:
            Agent! prefers native tools over shell commands
            Edit files directly instead of using sed/awk
            Use git tools instead of git CLI when possible
            Build Xcode projects with xcode_build, not xcodebuild
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