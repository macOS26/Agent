import Foundation
import SafariBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    guard let query = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] else {
        print("No search query provided")
        return 1
    }
    
    searchSafari(query: query)
    return 0
}

func searchSafari(query: String) {
    guard let safari: SafariApplication = SBApplication(bundleIdentifier: "com.apple.Safari") else {
        print("Could not connect to Safari")
        return
    }
    
    // Ensure Safari is running
    if !safari.isRunning {
        safari.activate()
    }
    
    // Create a new window if none exists
    if safari.windows?().count == 0 {
        _ = safari.doJavaScript?("", in: nil)
    }
    
    // Get the first window and first tab
    guard let window = safari.windows?().object(at: 0) as? SafariWindow,
          let tab = window.currentTab else {
        print("Could not access Safari window or tab")
        return
    }
    
    // Google search URL
    let searchURL = "https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
    
    // Set the URL using JavaScript
    _ = safari.doJavaScript?("window.location.href = '\\(searchURL)'", in: tab)
    
    // Bring Safari to foreground
    safari.activate()
    
    print("Searching for: \(query)")
    print("URL: \(searchURL)")
}