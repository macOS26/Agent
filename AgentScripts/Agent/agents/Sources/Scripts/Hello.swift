import Foundation

// ============================================================================
// Hello - Test script for verifying AgentScript setup
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "verbose=true" or just run with no args for basic info
//     Example: "verbose=true"
//
//   Option 2: JSON input file at ~/Documents/AgentScript/json/Hello_input.json
//     {
//       "verbose": true,
//       "json": true
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/Hello_output.json
//   {
//     "success": true,
//     "currentDirectory": "/",
//     "homeDirectory": "/Users/...",
//     "userName": "...",
//     "fullName": "...",
//     "hostName": "...",
//     "osVersion": "..."
//   }
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    hello()
    return 0
}

func hello() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/Hello_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/Hello_output.json"
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var verbose = false
    var outputJSON = false
    
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "verbose": verbose = value.lowercased() == "true"
                case "json": outputJSON = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let v = json["verbose"] as? Bool { verbose = v }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    print("Hello from Swift Script! 👋")
    print("===========================")
    
    let currentDir = FileManager.default.currentDirectoryPath
    let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
    let userName = NSUserName()
    let fullName = NSFullUserName()
    let hostName = ProcessInfo.processInfo.hostName
    let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    let date = Date()
    
    print("Current directory: \(currentDir)")  // edited
    print("Home directory: \(homeDir)")
    print("User name: \(userName)")
    print("Full name: \(fullName)")
    print("Date: \(date)")
    print("Host name: \(hostName)")
    print("OS version: \(osVersion)")
    
    if verbose {
        print("")
        print("=== Verbose Output ===")
        print("Process ID: \(ProcessInfo.processInfo.processIdentifier)")
        print("Arguments: \(CommandLine.arguments)")
        print("Environment variables:")
        let env = ProcessInfo.processInfo.environment
        for (key, value) in env.sorted(by: { $0.key < $1.key }).prefix(20) {
            print("  \(key): \(value)")
        }
        if env.count > 20 {
            print("  ... and \(env.count - 20) more")
        }
    }
    
    // Display system information summary
    print("")
    print("📊 System Information Summary")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("👤 User:        \(userName) (\(fullName))")
    print("💻 Hostname:    \(hostName)")
    print("🍎 macOS:       \(osVersion)")
    print("📅 Timestamp:   \(ISO8601DateFormatter().string(from: date))")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    // Write JSON output if requested
    if outputJSON {
        let result: [String: Any] = [
            "success": true,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "currentDirectory": currentDir,
            "homeDirectory": homeDir,
            "userName": userName,
            "fullName": fullName,
            "hostName": hostName,
            "osVersion": osVersion
        ]
        
        try? FileManager.default.createDirectory(atPath: "\(home)/Documents/AgentScript/json", withIntermediateDirectories: true)
        if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
            try? out.write(to: URL(fileURLWithPath: outputPath))
            print("\n📄 JSON saved to: \(outputPath)")
        }
    }
    
    print("\n✅ Script completed successfully!")
}