import Cocoa

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    // Get the desired mode from environment variable
    let args = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    
    var targetMode: Bool?
    
    // Parse the argument
    if args == "dark" || args == "dark mode" {
        targetMode = true
    } else if args == "light" || args == "light mode" {
        targetMode = false
    }
    // If no valid argument, we'll toggle
    
    // Get current appearance state
    let getScript = """
    tell application "System Events"
        tell appearance preferences
            get dark mode
        end tell
    end tell
    """
    
    let getAppleScript = NSAppleScript(source: getScript)
    var error: NSDictionary?
    let result = getAppleScript?.executeAndReturnError(&error)
    
    if let error = error {
        if let localizedDescription = error["NSAppleScriptErrorMessage"] as? String {
            print("Error checking appearance: \(localizedDescription)")
        }
        return 1
    }
    
    // Parse current state
    let isCurrentlyDark = result?.stringValue?.lowercased() == "true"
    
    // Determine the new mode
    let newMode: Bool
    let actionDescription: String
    
    if let target = targetMode {
        // Specific mode requested
        newMode = target
        if target == isCurrentlyDark {
            print("Already in \(target ? "dark" : "light") mode - no change needed")
            return 0
        }
        actionDescription = target ? "Switching to dark mode" : "Switching to light mode"
    } else {
        // Toggle mode
        newMode = !isCurrentlyDark
        actionDescription = "Toggling from \(isCurrentlyDark ? "dark" : "light") to \(newMode ? "dark" : "light") mode"
    }
    
    print(actionDescription)
    
    // Set the new appearance
    let setScript = """
    tell application "System Events"
        tell appearance preferences
            set dark mode to \(newMode ? "true" : "false")
        end tell
    end tell
    """
    
    let setAppleScript = NSAppleScript(source: setScript)
    var setError: NSDictionary?
    setAppleScript?.executeAndReturnError(&setError)
    
    if let setError = setError {
        if let localizedDescription = setError["NSAppleScriptErrorMessage"] as? String {
            print("Error setting appearance: \(localizedDescription)")
        }
        return 1
    }
    
    print("✓ Successfully switched to \(newMode ? "dark" : "light") mode")
    return 0
}