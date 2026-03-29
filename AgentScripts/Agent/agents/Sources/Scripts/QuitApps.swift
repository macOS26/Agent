import Foundation
import AppKit

// ============================================================================
// QuitApps - Quit applications with configurable exclusion list
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "excluded=App1,App2,App3" or "excluded=App1|App2|App3"
//     Example: "excluded=Xcode,Agent,Terminal"
//     Special: "excluded=essential" for default essential apps (Xcode,Agent,Terminal)
//
//   Option 2: JSON input file at ~/Documents/AgentScript/json/QuitApps_input.json
//     {
//       "excluded": ["Xcode", "Agent", "Terminal"],
//       "systemApps": false,
//       "dryRun": false
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/QuitApps_output.json
//   {
//     "success": true,
//     "quitApps": ["Safari", "Mail", ...],
//     "keptApps": ["Xcode", "Agent", "Terminal"],
//     "count": 5
//   }
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    quitApps()
    return 0
}

func quitApps() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/QuitApps_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/QuitApps_output.json"
    
    // Default essential apps
    let essentialApps = ["Xcode", "Agent", "Terminal"]
    
    // Default options
    var excludedApps: [String] = []
    var excludeSystemApps = true
    var dryRun = false
    var useEssential = false
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    if !argsString.isEmpty {
        // Parse key=value pairs
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                
                if key == "excluded" {
                    if value == "essential" {
                        useEssential = true
                    } else {
                        // Support both comma and pipe separators
                        excludedApps = value.contains("|") 
                            ? value.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                            : value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    }
                } else if key == "systemApps" {
                    excludeSystemApps = value.lowercased() != "true"
                } else if key == "dryRun" {
                    dryRun = value.lowercased() == "true"
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let excluded = json["excluded"] as? [String] {
            excludedApps = excluded
        }
        if let sysApps = json["systemApps"] as? Bool {
            excludeSystemApps = !sysApps
        }
        if let dry = json["dryRun"] as? Bool {
            dryRun = dry
        }
        if let essential = json["useEssential"] as? Bool, essential {
            useEssential = true
        }
    }
    
    // Use essential apps if requested
    if useEssential || excludedApps.isEmpty {
        excludedApps = essentialApps
    }
    
    // System apps to never quit
    let systemApps = [
        "Finder", "Dock", "SystemUIServer", "WindowServer", "loginwindow",
        "System Events", "SecurityAgent", "KernelEventAgent", "launchd",
        "coreauthd", "trustd", "boardd", "cfprefsd", "Agent"
    ]
    
    let allExcluded = excludeSystemApps 
        ? excludedApps + systemApps 
        : excludedApps
    
    print("🚪 QuitApps")
    print("═════════════════════════════════════")
    print("Excluded apps: \(allExcluded.joined(separator: ", "))")
    print("Dry run: \(dryRun ? "Yes" : "No")")
    print("")
    
    let workspace = NSWorkspace.shared
    let runningApps = workspace.runningApplications
    
    var quitApps: [String] = []
    var keptApps: [String] = []
    
    for app in runningApps {
        guard let appName = app.localizedName else { continue }
        
        // Skip excluded apps
        if allExcluded.contains(where: { $0.lowercased() == appName.lowercased() }) {
            keptApps.append(appName)
            continue
        }
        
        // Only quit regular apps (not background-only)
        guard app.activationPolicy == .regular else { continue }
        
        if dryRun {
            print("  Would quit: \(appName)")
            quitApps.append(appName)
        } else {
            print("  Quitting: \(appName)")
            app.terminate()
            quitApps.append(appName)
        }
    }
    
    print("")
    print("═════════════════════════════════════")
    print("Summary:")
    print("  Quit: \(quitApps.count) apps")
    print("  Kept: \(keptApps.count) apps")
    
    if dryRun {
        print("\n⚠️ Dry run - no apps were actually quit")
    }
    
    // Write JSON output
    let result: [String: Any] = [
        "success": true,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "dryRun": dryRun,
        "quitApps": quitApps,
        "keptApps": keptApps,
        "quitCount": quitApps.count,
        "keptCount": keptApps.count
    ]
    
    try? FileManager.default.createDirectory(atPath: "\(home)/Documents/AgentScript/json", withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: outputPath))
        print("\n📄 JSON saved to: \(outputPath)")
    }
}