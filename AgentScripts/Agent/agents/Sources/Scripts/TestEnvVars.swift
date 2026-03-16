import Foundation

// Test script for AGENT_SCRIPT_ARGS environment variable and JSON I/O
// This script verifies that:
// 1. AGENT_SCRIPT_ARGS is correctly passed via run_agent_script
// 2. JSON input files can be read from ~/Documents/Agent/
// 3. JSON output files can be written to ~/Documents/Agent/

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    testEnvVars()
    return 0
}

func testEnvVars() {
    let home = NSHomeDirectory()
    let agentDir = "\(home)/Documents/Agent"
    let inputPath = "\(agentDir)/TestEnvVars_input.json"
    let outputPath = "\(agentDir)/TestEnvVars_output.json"
    
    print("=== AGENT Script Environment Variables Test ===\n")
    
    // Test 1: AGENT_SCRIPT_ARGS environment variable
    print("TEST 1: AGENT_SCRIPT_ARGS Environment Variable")
    print("------------------------------------------------")
    let scriptArgs = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"]
    if let args = scriptArgs {
        print("✓ AGENT_SCRIPT_ARGS found: \(args)")
    } else {
        print("✗ AGENT_SCRIPT_ARGS not set (or empty)")
    }
    print("")
    
    // Test 2: JSON Input File
    print("TEST 2: JSON Input File")
    print("----------------------")
    print("Expected path: \(inputPath)")
    
    var inputData: [String: Any]? = nil
    if let data = FileManager.default.contents(atPath: inputPath) {
        print("✓ Input file exists")
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("✓ Input file is valid JSON")
            inputData = json
            print("Contents: \(json)")
        } else {
            print("✗ Input file is not valid JSON")
        }
    } else {
        print("✗ Input file not found (this is OK if testing without input)")
    }
    print("")
    
    // Test 3: Other useful environment variables
    print("TEST 3: Other Environment Variables")
    print("------------------------------------")
    let envVars = [
        "HOME": ProcessInfo.processInfo.environment["HOME"],
        "USER": ProcessInfo.processInfo.environment["USER"],
        "SHELL": ProcessInfo.processInfo.environment["SHELL"],
        "PWD": ProcessInfo.processInfo.environment["PWD"],
        "LANG": ProcessInfo.processInfo.environment["LANG"],
    ]
    for (key, value) in envVars {
        if let v = value {
            print("  \(key): \(v)")
        } else {
            print("  \(key): (not set)")
        }
    }
    print("")
    
    // Test 4: Write JSON Output
    print("TEST 4: JSON Output File")
    print("------------------------")
    
    // Ensure Agent directory exists
    try? FileManager.default.createDirectory(atPath: agentDir, withIntermediateDirectories: true)
    
    let results: [String: Any] = [
        "success": true,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "tests": [
            "AGENT_SCRIPT_ARGS": scriptArgs ?? "(not set)",
            "inputFileFound": FileManager.default.fileExists(atPath: inputPath),
            "inputData": inputData ?? [:]
        ],
        "environment": envVars.compactMapValues { $0 }
    ]
    
    if let outData = try? JSONSerialization.data(withJSONObject: results, options: .prettyPrinted) {
        do {
            try outData.write(to: URL(fileURLWithPath: outputPath))
            print("✓ Output written to: \(outputPath)")
        } catch {
            print("✗ Failed to write output: \(error)")
        }
    }
    
    print("\n=== Test Complete ===")
    print("Results saved to: \(outputPath)")
}
