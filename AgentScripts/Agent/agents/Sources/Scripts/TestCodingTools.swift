import Foundation

// ============================================================================
// TestCodingTools - Test and demonstrate coding tool capabilities
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "test=all" or "test=write" or "test=edit" or "test=read"
//     Example: "test=write,verbose=true"
//
//   Option 2: JSON input file at ~/Documents/Agent/json/TestCodingTools_input.json
//     {
//       "test": "all",     // "all", "write", "edit", or "read"
//       "verbose": true,
//       "cleanup": true    // Remove test files after completion
//     }
//
// OUTPUT: ~/Documents/Agent/json/TestCodingTools_output.json
//   {
//     "success": true,
//     "tests": ["write", "edit", "read"],
//     "results": { "write": true, "edit": true, "read": true },
//     "filesCreated": ["..."],
//     "filesDeleted": ["..."]
//   }
//
// PURPOSE:
//   - Validates file operations work correctly
//   - Demonstrates proper script structure
//   - Useful for debugging agent file capabilities
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    testCodingTools()
    return 0
}

func testCodingTools() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/Agent/json/TestCodingTools_input.json"
    let outputPath = "\(home)/Documents/Agent/json/TestCodingTools_output.json"
    let testDir = "\(home)/Documents/Agent/test_output"
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var testType = "all"
    var verbose = true
    var cleanup = false
    
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "test": testType = value.lowercased()
                case "verbose": verbose = value.lowercased() == "true"
                case "cleanup": cleanup = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let t = json["test"] as? String { testType = t.lowercased() }
        if let v = json["verbose"] as? Bool { verbose = v }
        if let c = json["cleanup"] as? Bool { cleanup = c }
    }
    
    print("🧪 Test Coding Tools")
    print("═══════════════════════════════════════")
    print("Test: \(testType)")
    print("Verbose: \(verbose)")
    print("Cleanup: \(cleanup)")
    print("═══════════════════════════════════════")
    
    // Ensure test directory exists
    try? FileManager.default.createDirectory(atPath: testDir, withIntermediateDirectories: true)
    
    var testsRun: [String] = []
    var results: [String: Bool] = [:]
    var filesCreated: [String] = []
    var filesDeleted: [String] = []
    
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let testFile = "\(testDir)/test_file.txt"
    let editFile = "\(testDir)/edit_test.txt"
    
    // Test 1: Write file
    if testType == "all" || testType == "write" {
        print("\n📝 Testing write_file...")
        testsRun.append("write")
        
        let content = """
        Test File Created by TestCodingTools
        =====================================
        Created: \(timestamp)
        User: \(NSFullUserName())
        Home: \(home)
        
        This file demonstrates successful file writing capability.
        """
        
        do {
            try content.write(to: URL(fileURLWithPath: testFile), atomically: true, encoding: .utf8)
            print("   ✅ Write successful: \(testFile)")
            results["write"] = true
            filesCreated.append(testFile)
        } catch {
            print("   ❌ Write failed: \(error.localizedDescription)")
            results["write"] = false
        }
    }
    
    // Test 2: Read file
    if testType == "all" || testType == "read" {
        print("\n📖 Testing read_file...")
        testsRun.append("read")
        
        do {
            let content = try String(contentsOfFile: testFile, encoding: .utf8)
            if verbose {
                print("   Content preview:")
                let lines = content.components(separatedBy: "\n").prefix(5)
                for line in lines {
                    print("      \(line)")
                }
            }
            print("   ✅ Read successful")
            results["read"] = true
        } catch {
            print("   ❌ Read failed: \(error.localizedDescription)")
            results["read"] = false
        }
    }
    
    // Test 3: Edit file
    if testType == "all" || testType == "edit" {
        print("\n✏️ Testing edit_file...")
        testsRun.append("edit")
        
        // Create file for editing
        let initialContent = "Line 1: Original content\nLine 2: More content\nLine 3: End\n"
        do {
            try initialContent.write(to: URL(fileURLWithPath: editFile), atomically: true, encoding: .utf8)
            filesCreated.append(editFile)
            
            // Simulate edit by reading, modifying, and writing
            var content = try String(contentsOfFile: editFile, encoding: .utf8)
            content = content.replacingOccurrences(of: "Original content", with: "EDITED CONTENT")
            try content.write(to: URL(fileURLWithPath: editFile), atomically: true, encoding: .utf8)
            
            print("   ✅ Edit successful: replaced 'Original content' with 'EDITED CONTENT'")
            results["edit"] = true
        } catch {
            print("   ❌ Edit failed: \(error.localizedDescription)")
            results["edit"] = false
        }
    }
    
    // Cleanup
    if cleanup {
        print("\n🧹 Cleaning up test files...")
        for file in filesCreated {
            do {
                try FileManager.default.removeItem(atPath: file)
                print("   🗑️ Deleted: \(file)")
                filesDeleted.append(file)
            } catch {
                print("   ⚠️ Could not delete: \(file)")
            }
        }
        // Remove test directory if empty
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: testDir),
           contents.isEmpty {
            try? FileManager.default.removeItem(atPath: testDir)
            print("   🗑️ Removed test directory")
        }
    }
    
    print("\n═══════════════════════════════════════")
    print("Summary:")
    print("   Tests run: \(testsRun.joined(separator: ", "))")
    let passed = results.values.filter { $0 }.count
    print("   Passed: \(passed)/\(testsRun.count)")
    print("═══════════════════════════════════════")
    
    // Write JSON output
    let resultData: [String: Any] = [
        "success": results.values.allSatisfy { $0 },
        "timestamp": timestamp,
        "tests": testsRun,
        "results": results,
        "filesCreated": filesCreated,
        "filesDeleted": filesDeleted
    ]
    
    try? FileManager.default.createDirectory(atPath: "\(home)/Documents/Agent/json", withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: resultData, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: outputPath))
        print("\n📄 JSON saved to: \(outputPath)")
    }
}