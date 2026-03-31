// Swift Code Checker Demo
// Demonstrates using the SwiftCodeChecker with SwiftSyntax

import Foundation
import SwiftSyntax
import SwiftParser

// Create a simple demo file to analyze
func createDemoFile() throws -> String {
    let demoCode = """
    // Demo Swift file with various issues to detect

    import Foundation

    // Unused variable example
    func unusedVarExample() {
        let unusedVar = 42    // This variable is never used
        print("Hello, world!")
    }

    // Force unwrap example
    func forceUnwrapExample() {
        let optionalValue: String? = "test"
        let forcedValue = optionalValue!   // Force unwrap
        print(forcedValue)
        
        let dict: [String: Any] = ["key": "value"]
        let forced = dict["missing"] as! String  // Forced cast
    }

    // Unreachable code example
    func unreachableCodeExample() -> Int {
        return 42
        print("This will never be executed")  // Unreachable code
    }

    // Magic number example
    func magicNumberExample() {
        let result = 100 * 1.5  // Magic numbers
        
        // Wait for 3600 seconds (1 hour)
        let waitTime = 3600
    }

    // Naming convention example
    struct invalidTypeName {  // Type names should be UpperCamelCase
        let ValidProperty = true  // Property names should be lowerCamelCase
    }

    // Long method example
    func reallyLongMethodExample() {
        print("Line 1")
        print("Line 2")
        // ... imagine 50+ more lines ...
    }

    // High cyclomatic complexity example
    func complexFunction(a: Int, b: Int, c: Int) -> Bool {
        if a > 0 {
            if b > 0 {
                if c > 0 {
                    return true
                } else if c < -10 {
                    return true
                } else {
                    return false
                }
            } else if b < -10 {
                if c == 0 {
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        } else if a < -10 {
            if b == 0 {
                return true
            } else {
                return false
            }
        }
        return false
    }

    // Guard usage example
    func ifLetExample(value: String?) {
        if let unwrapped = value {  // Could use guard instead
            print(unwrapped)
            return
        }
    }

    // Immutable assignment example
    func immutableAssignmentExample() {
        let constant = 10
        // constant = 20  // Uncommenting this would be an error - assignment to let constant
    }

    // Empty catch block example
    func emptyCatchBlockExample() {
        do {
            try FileManager.default.removeItem(atPath: "/nonexistent/path")
        } catch {
            // Empty catch block
        }
    }

    // Retain cycle example (memory leak)
    class RetainCycleExample {
        var handler: (() -> Void)?
        
        func setupHandler() {
            handler = {
                self.doSomething()  // Captures self strongly
            }
        }
        
        func doSomething() {
            print("Doing something")
        }
    }

    // Empty collection check example
    func emptyCollectionCheckExample() {
        let array = [Int]()
        if array.count == 0 {  // Should use isEmpty
            print("Array is empty")
        }
    }

    // Optional chaining depth example
    class DeepOptionalChaining {
        var level1: Level1?
        
        class Level1 {
            var level2: Level2?
        }
        
        class Level2 {
            var level3: Level3?
        }
        
        class Level3 {
            var level4: Level4?
        }
        
        class Level4 {
            var value: String?
        }
        
        func accessDeepValue() {
            let value = level1?.level2?.level3?.level4?.value  // Deep optional chaining
        }
    }

    // String literal hardcoding
    func stringLiteralExample() {
        let message = "This is a hardcoded string that should be localized"
        print(message)
    }

    // Deprecated API usage
    func deprecatedAPIExample() {
        let pi = M_PI  // Deprecated, should use Double.pi
    }
    """
    
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("demo_swift_file.swift")
    try demoCode.write(to: tempURL, atomically: true, encoding: .utf8)
    return tempURL.path
}

func runDemo() {
    do {
        print("Swift Code Checker Demo")
        print("=======================\n")
        
        // Create a temp file with demo code
        let demoFilePath = try createDemoFile()
        print("Created demo file at: \(demoFilePath)\n")
        
        // Run the analysis
        print("Running Swift Code Checker analysis...\n")
        let checker = SwiftCodeChecker()
        let issues = try checker.runAllChecks(at: demoFilePath)
        
        // Group issues by type for display
        var issuesByType: [String: [SourceKitIssue]] = [:]
        for issue in issues {
            if issuesByType[issue.severity] == nil {
                issuesByType[issue.severity] = []
            }
            issuesByType[issue.severity]?.append(issue)
        }
        
        // Display issues by type
        print("Analysis Results:")
        print("================\n")
        
        let totalIssues = issues.count
        print("Found \(totalIssues) issues in total\n")
        
        // Display errors first
        if let errors = issuesByType["error"] {
            print("ERRORS (\(errors.count)):")
            for (index, error) in errors.enumerated() {
                print("  \(index + 1). Line \(error.line): \(error.description)")
            }
            print()
        }
        
        // Then display warnings
        if let warnings = issuesByType["warning"] {
            print("WARNINGS (\(warnings.count)):")
            for (index, warning) in warnings.enumerated() {
                print("  \(index + 1). Line \(warning.line): \(warning.description)")
            }
            print()
        }
        
        // Clean up the temp file
        try FileManager.default.removeItem(atPath: demoFilePath)
        print("Demo completed. Temporary file removed.")
        
    } catch {
        print("Error running demo: \(error)")
    }
}

// Run the demo
runDemo() 