import Foundation

/// Tool name constants - single source of truth for all tool names.
extension AgentTools {
    enum Name {
        // File Tools
        static let readFile = "read_file"
        static let writeFile = "write_file"
        static let editFile = "edit_file"
        static let createDiff = "create_diff"
        static let applyDiff = "apply_diff"
        static let listFiles = "list_files"
        static let searchFiles = "search_files"
        
        // Git Tools
        static let gitStatus = "git_status"
        static let gitDiff = "git_diff"
        static let gitLog = "git_log"
        static let gitCommit = "git_commit"
        static let gitDiffPatch = "git_diff_patch"
        static let gitBranch = "git_branch"
        
        // Core Scripting
        static let appleEventQuery = "apple_event_query"
        static let runApplescript = "run_applescript"
        static let runOsascript = "run_osascript"
        static let executeJavascript = "execute_javascript"
        
        // Shell Execution
        static let executeAgentCommand = "execute_agent_command"
        static let executeDaemonCommand = "execute_daemon_command"
        
        // Task
        static let taskComplete = "task_complete"
        
        // Conversation Tools
        static let writeText = "write_text"
        static let transformText = "transform_text"
        static let sendMessage = "send_message"
        static let aboutSelf = "about_self"
        static let fixText = "fix_text"
        
        // Accessibility
        static let axListWindows = "ax_list_windows"
        static let axInspectElement = "ax_inspect_element"
        static let axGetProperties = "ax_get_properties"
        static let axPerformAction = "ax_perform_action"
        static let axCheckPermission = "ax_check_permission"
        static let axRequestPermission = "ax_request_permission"
        static let axTypeText = "ax_type_text"
        static let axClick = "ax_click"
        static let axScroll = "ax_scroll"
        static let axPressKey = "ax_press_key"
        static let axScreenshot = "ax_screenshot"
        static let axGetAuditLog = "ax_get_audit_log"
        static let axSetProperties = "ax_set_properties"
        static let axFindElement = "ax_find_element"
        static let axGetFocusedElement = "ax_get_focused_element"
        static let axGetChildren = "ax_get_children"
        static let axDrag = "ax_drag"
        static let axWaitForElement = "ax_wait_for_element"
        static let axShowMenu = "ax_show_menu"
        static let axClickElement = "ax_click_element"
        static let axWaitAdaptive = "ax_wait_adaptive"
        static let axTypeIntoElement = "ax_type_into_element"
        static let axHighlightElement = "ax_highlight_element"
        static let axGetWindowFrame = "ax_get_window_frame"
        
        // Agent Script Management
        static let listAgentScripts = "list_agent_scripts"
        static let readAgentScript = "read_agent_script"
        static let createAgentScript = "create_agent_script"
        static let updateAgentScript = "update_agent_script"
        static let runAgentScript = "run_agent_script"
        static let deleteAgentScript = "delete_agent_script"
        
        // SDEF
        static let lookupSdef = "lookup_sdef"
        
        // Xcode
        static let xcodeBuild = "xcode_build"
        static let xcodeRun = "xcode_run"
        static let xcodeListProjects = "xcode_list_projects"
        static let xcodeSelectProject = "xcode_select_project"
        static let xcodeGrantPermission = "xcode_grant_permission"
        
        // AppleScript Management
        static let listAppleScripts = "list_apple_scripts"
        static let runAppleScript = "run_apple_script"
        static let saveAppleScript = "save_apple_script"
        static let deleteAppleScript = "delete_apple_script"
        
        // JavaScript Management
        static let listJavascript = "list_javascript"
        static let runJavascript = "run_javascript"
        static let saveJavascript = "save_javascript"
        static let deleteJavascript = "delete_javascript"
        
        // Tool Discovery
        static let listNativeTools = "list_native_tools"
        static let listMcpTools = "list_mcp_tools"
        
        // Web Automation
        static let webOpen = "web_open"
        static let webFind = "web_find"
        static let webClick = "web_click"
        static let webType = "web_type"
        static let webExecuteJs = "web_execute_js"
        static let webGetUrl = "web_get_url"
        static let webGetTitle = "web_get_title"
        
        // Selenium
        static let seleniumStart = "selenium_start"
        static let seleniumStop = "selenium_stop"
        static let seleniumNavigate = "selenium_navigate"
        static let seleniumFind = "selenium_find"
        static let seleniumClick = "selenium_click"
        static let seleniumType = "selenium_type"
        static let seleniumExecute = "selenium_execute"
        static let seleniumScreenshot = "selenium_screenshot"
        static let seleniumWait = "selenium_wait"
        
        // Web Search (Ollama-only)
        static let webSearch = "web_search"
    }
}