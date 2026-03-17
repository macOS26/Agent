import Foundation
import SafariBridge

// ============================================================================
// SafariSearch - Perform web search in Safari
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "query=search+terms" or just the search terms directly
//     Example: "query=swift+programming" or "swift programming"
//
//   Option 2: JSON input file at ~/Documents/Agent/json/SafariSearch_input.json
//     {
//       "query": "swift programming",
//       "engine": "google",
//       "newTab": true
//     }
//
// OUTPUT: ~/Documents/Agent/json/SafariSearch_output.json
//   {
//     "success": true,
//     "query": "swift programming",
//     "url": "https://www.google.com/search?q=swift+programming"
//   }
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    safariSearch()
    return 0
}

func safariSearch() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/Agent/json/SafariSearch_input.json"
    let outputPath = "\(home)/Documents/Agent/json/SafariSearch_output.json"
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var query = ""
    var engine = "google"
    var newTab = true
    var outputJSON = false
    
    if !argsString.isEmpty {
        // Check if it's key=value format
        if argsString.contains("=") {
            let pairs = argsString.components(separatedBy: ",")
            for pair in pairs {
                let parts = pair.components(separatedBy: "=")
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    switch key {
                    case "query": query = value
                    case "engine": engine = value.lowercased()
                    case "newTab": newTab = value.lowercased() == "true"
                    case "json": outputJSON = value.lowercased() == "true"
                    default: break
                    }
                }
            }
        } else {
            // Treat entire string as query
            query = argsString
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let q = json["query"] as? String { query = q }
        if let e = json["engine"] as? String { engine = e.lowercased() }
        if let n = json["newTab"] as? Bool { newTab = n }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    guard !query.isEmpty else {
        print("No search query provided")
        print("Usage: SafariSearch query=search+terms")
        print("   or: SafariSearch search terms directly")
        writeOutput(outputPath, success: false, error: "No search query provided", query: query, outputJSON: outputJSON)
        return
    }
    
    // Build search URL based on engine
    let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    let searchURL: String
    
    switch engine {
    case "google":
        searchURL = "https://www.google.com/search?q=\(encodedQuery)"
    case "bing":
        searchURL = "https://www.bing.com/search?q=\(encodedQuery)"
    case "duckduckgo", "ddg":
        searchURL = "https://duckduckgo.com/?q=\(encodedQuery)"
    case "yahoo":
        searchURL = "https://search.yahoo.com/search?p=\(encodedQuery)"
    default:
        searchURL = "https://www.google.com/search?q=\(encodedQuery)"
    }
    
    print("🔍 Safari Search")
    print("═════════════════════════════════════")
    print("Query: \(query)")
    print("Engine: \(engine)")
    print("URL: \(searchURL)")
    
    guard let safari: SafariApplication = SBApplication(bundleIdentifier: "com.apple.Safari") else {
        print("❌ Could not connect to Safari")
        writeOutput(outputPath, success: false, error: "Could not connect to Safari", query: query, outputJSON: outputJSON)
        return
    }
    
    // Ensure Safari is running
    if !safari.isRunning {
        print("Starting Safari...")
        safari.activate()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))
    }
    
    // Get or create window
    var window: SafariWindow? = nil
    if let windows = safari.windows?(), windows.count > 0 {
        window = windows.object(at: 0) as? SafariWindow
    }
    
    if window == nil {
        // Create new window
        _ = safari.doJavaScript?("window.open('\(searchURL)', '_blank')", in: nil)
        print("✅ Opened new window with search")
        writeOutput(outputPath, success: true, query: query, url: searchURL, outputJSON: outputJSON)
        return
    }
    
    guard let win = window else {
        print("❌ Could not access Safari window")
        writeOutput(outputPath, success: false, error: "Could not access Safari window", query: query, outputJSON: outputJSON)
        return
    }
    
    if newTab {
        // Open in new tab
        let newTabScript = """
        var tab = safari.application.activeBrowserWindow.openTab();
        tab.url = '\(searchURL)';
        """
        _ = safari.doJavaScript?(newTabScript, in: nil)
        print("✅ Opened new tab with search")
    } else {
        // Use current tab
        if let tab = win.currentTab {
            _ = safari.doJavaScript?("window.location.href = '\(searchURL)'", in: tab)
            print("✅ Navigated current tab to search")
        }
    }
    
    // Bring Safari to foreground
    safari.activate()
    
    writeOutput(outputPath, success: true, query: query, url: searchURL, outputJSON: outputJSON)
}

func writeOutput(_ path: String, success: Bool, error: String? = nil, query: String, url: String? = nil, outputJSON: Bool) {
    guard outputJSON else { return }
    
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "query": query
    ]
    
    if let error = error {
        result["error"] = error
    }
    
    if let url = url {
        result["url"] = url
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}