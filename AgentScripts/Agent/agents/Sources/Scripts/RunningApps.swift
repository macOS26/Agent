import Foundation
import SystemEventsBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    runningApps()
    return 0
}

func runningApps() {
    // Parse arguments from AGENT_SCRIPT_ARGS or JSON input
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/RunningApps_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/RunningApps_output.json"
    
    // Default options
    var showHidden = false
    var showSystem = false
    var outputJSON = false
    
    // Parse AGENT_SCRIPT_ARGS
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "hidden": showHidden = value.lowercased() == "true"
                case "system": showSystem = value.lowercased() == "true"
                case "json": outputJSON = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let h = json["hidden"] as? Bool { showHidden = h }
        if let s = json["system"] as? Bool { showSystem = s }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    guard let sysEvents: SystemEventsApplication = SBApplication(bundleIdentifier: "com.apple.systemevents") else {
        print("Could not connect to System Events")
        writeRunningAppsOutput(outputPath, success: false, error: "Could not connect to System Events", outputJSON: outputJSON)
        return
    }

    print("Running Applications")
    print("====================")

    guard let procs = sysEvents.processes?() else {
        print("Could not list processes")
        writeRunningAppsOutput(outputPath, success: false, error: "Could not list processes", outputJSON: outputJSON)
        return
    }

    var apps: [[String: Any]] = []

    for i in 0..<procs.count {
        guard let proc = procs.object(at: i) as? SystemEventsProcess,
              let name = proc.name else { continue }

        let frontmost = proc.frontmost ?? false
        let visible = proc.visible ?? false
        
        // Filter based on options
        if !showHidden && !visible { continue }
        
        // Filter system apps
        if !showSystem {
            let systemApps = ["Finder", "Dock", "SystemUIServer", "WindowServer", "loginwindow", 
                              "System Events", "SecurityAgent", "KernelEventAgent", "launchd", 
                              "launchd", "coreauthd", "trustd", "boardd", "cfprefsd"]
            if systemApps.contains(name) { continue }
        }
        
        apps.append([
            "name": name,
            "frontmost": frontmost,
            "visible": visible
        ])
    }

    // Sort alphabetically
    apps.sort { ($0["name"] as? String)?.lowercased() ?? "" < ($1["name"] as? String)?.lowercased() ?? "" }

    for app in apps {
        let name = app["name"] as? String ?? ""
        let frontmost = app["frontmost"] as? Bool ?? false
        let visible = app["visible"] as? Bool ?? true
        let marker = frontmost ? " *" : ""
        let hidden = visible ? "" : " (hidden)"
        print("  \(name)\(marker)\(hidden)")
    }

    print("\nTotal: \(apps.count) processes")
    print("(* = frontmost)")
    
    // Write JSON output if requested
    if outputJSON {
        writeRunningAppsOutput(outputPath, success: true, apps: apps, outputJSON: true)
    }
}

func writeRunningAppsOutput(_ path: String, success: Bool, error: String? = nil, apps: [[String: Any]]? = nil, outputJSON: Bool) {
    guard outputJSON else { return }
    
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    
    if !success, let error = error {
        result["error"] = error
    }
    
    if success {
        if let apps = apps { result["apps"] = apps }
        if let apps = apps { result["count"] = apps.count }
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}