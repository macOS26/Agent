import Foundation
import AgentAccessibility

// ============================================================================
// AXDemo - Accessibility demo showing windows and element inspection
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "param1=value1,param2=value2"
//     Parameters:
//       - x=500 (X coordinate to inspect, default: center of screen)
//       - y=400 (Y coordinate to inspect, default: center of screen)
//       - windows=10 (number of windows to list, default: 10)
//       - json=true (output to JSON file)
//     Example: "x=500,y=400,windows=15,json=true"
//
//   Option 2: JSON input file at ~/Documents/Agent/json/AXDemo_input.json
//     {
//       "x": 500,
//       "y": 400,
//       "windows": 15,
//       "json": true
//     }
//
// OUTPUT: ~/Documents/Agent/json/AXDemo_output.json
//   {
//     "success": true,
//     "windows": [...],
//     "inspectedElement": { "role": "...", "title": "...", "value": "..." },
//     "timestamp": "2026-03-16T..."
//   }
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    axDemo()
    return 0
}

func axDemo() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/Agent/json/AXDemo_input.json"
    let jsonOutputPath = "\(home)/Documents/Agent/json/AXDemo_output.json"
    
    // Default values
    var inspectX: CGFloat = 500
    var inspectY: CGFloat = 400
    var windowLimit = 10
    var outputJSON = false
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "x", "inspectX":
                    inspectX = CGFloat(Double(value) ?? 500)
                case "y", "inspectY":
                    inspectY = CGFloat(Double(value) ?? 400)
                case "windows", "limit":
                    windowLimit = Int(value) ?? 10
                case "json":
                    outputJSON = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let x = json["x"] as? Double { inspectX = CGFloat(x) }
        if let y = json["y"] as? Double { inspectY = CGFloat(y) }
        if let w = json["windows"] as? Int { windowLimit = w }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    print("🔍 Accessibility Demo")
    print("═══════════════════════════════════════")
    
    // Check permission
    guard axHasPermission() else {
        print("❌ Accessibility permission not granted")
        print("   Grant permission in System Preferences > Privacy & Security > Accessibility")
        writeOutput(jsonOutputPath, success: false, error: "Accessibility permission not granted", outputJSON: outputJSON)
        return
    }
    
    print("✅ Accessibility permission granted")
    print("")
    
    // Collect data for JSON output
    var windowsData: [[String: Any]] = []
    var elementData: [String: Any]? = nil
    
    // List visible windows
    print("=== Visible Windows (top \(windowLimit)) ===")
    let windows = axListWindows()
    for (i, w) in windows.prefix(windowLimit).enumerated() {
        print("\(i + 1). [\(w.owner)] \(w.name) — id:\(w.id) at \(Int(w.bounds.origin.x)),\(Int(w.bounds.origin.y)) \(Int(w.bounds.width))x\(Int(w.bounds.height))")
        
        windowsData.append([
            "id": w.id,
            "owner": w.owner,
            "name": w.name ?? "",
            "x": Int(w.bounds.origin.x),
            "y": Int(w.bounds.origin.y),
            "width": Int(w.bounds.width),
            "height": Int(w.bounds.height)
        ])
    }
    
    // Inspect element at specified coordinates
    print("\n=== Element at (\(Int(inspectX)), \(Int(inspectY))) ===")
    if let element = axElementAt(x: inspectX, y: inspectY) {
        var roleStr = "unknown"
        var titleStr = ""
        var valueStr = ""
        
        if let role = axRole(element) {
            roleStr = role
            print("Role: \(role)")
        }
        if let title = axTitle(element) {
            titleStr = title
            print("Title: \(title)")
        }
        if let value = axValue(element) {
            if let strValue = value as? String {
                valueStr = strValue
            } else {
                valueStr = String(describing: value)
            }
            print("Value: \(value)")
        }
        
        elementData = [
            "x": Int(inspectX),
            "y": Int(inspectY),
            "role": roleStr,
            "title": titleStr,
            "value": valueStr
        ]
    } else {
        print("No element found at (\(Int(inspectX)), \(Int(inspectY)))")
    }
    
    print("\n═══════════════════════════════════════")
    print("Summary: \(min(windowLimit, windows.count)) of \(windows.count) windows listed")
    
    // Write JSON output if requested
    if outputJSON {
        var result: [String: Any] = [
            "success": true,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "totalWindows": windows.count,
            "windowsListed": min(windowLimit, windows.count),
            "windows": windowsData
        ]
        
        if let elementData = elementData {
            result["inspectedElement"] = elementData
        }
        
        try? FileManager.default.createDirectory(atPath: (jsonOutputPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
            try? out.write(to: URL(fileURLWithPath: jsonOutputPath))
            print("\n📄 JSON saved to: \(jsonOutputPath)")
        }
    }
}

func writeOutput(_ path: String, success: Bool, error: String? = nil, outputJSON: Bool) {
    guard outputJSON else { return }
    
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    
    if let error = error {
        result["error"] = error
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}