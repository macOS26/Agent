// SwiftCodeChecker Demo
// This file demonstrates the use of the SwiftCodeChecker to detect issues in Swift code

import Foundation
import xcf_swift

print("Swift Code Checker Demo")
print("=======================\n")

// Parse command line arguments
var filePath: String?
var generateReport = false
var reportPath: String?
var shouldCleanup = false

// Simple argument parsing
for (index, arg) in CommandLine.arguments.enumerated() {
    if index == 0 { continue } // Skip program name
    
    if arg == "--report" || arg == "-r" {
        generateReport = true
        // Check if next arg is a path
        if CommandLine.arguments.count > index + 1 && !CommandLine.arguments[index + 1].hasPrefix("-") {
            reportPath = CommandLine.arguments[index + 1]
        }
    } else if arg == "--help" || arg == "-h" {
        printUsage()
        exit(0)
    } else if !arg.hasPrefix("-") {
        // Could be a file path or report path
        if generateReport && reportPath == nil && filePath != nil {
            // If we have already seen a file path and --report flag, this is the report path
            reportPath = arg
        } else if filePath == nil {
            // First non-flag argument is the file path
            filePath = arg
        }
    }
}

func printUsage() {
    print("""
    Usage: swift run swift-checker-demo [OPTIONS] [FILE_PATH]
    
    Options:
      -r, --report [PATH]     Generate a detailed Markdown report (optional path)
      -h, --help              Display this help message
    
    If no file path is provided, a demo file will be created for testing.
    """)
}

// Determine which file to check
let testFilePath: String

if let path = filePath {
    // Use provided file path
    testFilePath = path
    print("Checking file: \(testFilePath)")
    
    // Verify file exists
    guard FileManager.default.fileExists(atPath: testFilePath) else {
        print("Error: File not found at path: \(testFilePath)")
        exit(1)
    }
} else {
    // Create a demo test file if no path provided
    testFilePath = NSTemporaryDirectory() + "SwiftCodeCheckerTest.swift"
    shouldCleanup = true
    let testCode = """
import Foundation

// Example file with various code issues

@available
class MyClass {
    // Incorrectly named constant
    let x = 42
    
    // Unused variable
    var unusedVar = "I'm never used"
    
    // Force unwrap - potential runtime crash
    func processValue(value: String?) {
        print(value!)
    }
    
    // Long method with complex logic
    func calculateSomething(a: Int, b: Int, c: Int, d: Int, e: Int) -> Int {
        let result = a + b * (c - d) / e  // Operator precedence issue
        
        if result > 10 {
            print("Result exceeds 10")
            return result
            print("Unreachable code")  // Unreachable code
        }
        
        return result
    }
    
    // Try to modify an immutable value
    func updateValue() {
        let immutableValue = 5
        immutableValue = 10  // Error: Cannot assign to immutable value
    }
    
    // Duplicate method implementation
    func processData(data: [Int]) -> Int {
        var sum = 0
        for item in data {
            sum += item
        }
        return sum
    }
    
    // Nearly identical method
    func calculateTotal(values: [Int]) -> Int {
        var total = 0
        for value in values {
            total += value
        }
        return total
    }
    
    // Empty catch block
    func riskyOperation() {
        do {
            try performOperation()
        } catch {
            // Empty catch block
        }
    }
    
    func performOperation() throws {
        // Do something that might throw
    }
    
    // Macro usage
    func conditionalCode() {
        #if DEBUG
        print("Debug mode")
        #endif
    }
}
"""

    // Write the test file
    do {
        try testCode.write(toFile: testFilePath, atomically: true, encoding: .utf8)
        print("Created demo test file at: \(testFilePath)")
    } catch {
        print("Error creating test file: \(error)")
        exit(1)
    }
}

// Create the checker
let checker = SwiftCodeChecker()

// Run all checks
do {
    print("\n=== Running All Checks ===")
    let allIssues = try checker.runAllChecks(at: testFilePath)
    
    // Group issues by severity
    let errors = allIssues.filter { $0.severity == "error" }
    let warnings = allIssues.filter { $0.severity == "warning" }
    let infos = allIssues.filter { $0.severity == "info" }
    
    // Summary
    print("\nSummary of all checks:")
    print("- Found \(allIssues.count) issues total")
    print("- \(errors.count) errors")
    print("- \(warnings.count) warnings")
    print("- \(infos.count) informational messages\n")
    
    // Print errors first
    if !errors.isEmpty {
        print("ERRORS:")
        printIssues(errors)
        print("")
    }
    
    // Print warnings (limit to 5 if there are many)
    if !warnings.isEmpty {
        if warnings.count > 5 {
            print("WARNINGS (showing first 5 of \(warnings.count)):")
            printIssues(Array(warnings.prefix(5)))
            print("... and \(warnings.count - 5) more warnings\n")
        } else {
            print("WARNINGS:")
            printIssues(warnings)
            print("")
        }
    }
    
    // Print informational messages (limit to 3)
    if !infos.isEmpty {
        if infos.count > 3 {
            print("INFO (showing first 3 of \(infos.count)):")
            printIssues(Array(infos.prefix(3)))
            print("... and \(infos.count - 3) more informational messages\n")
        } else {
            print("INFO:")
            printIssues(infos)
            print("")
        }
    }
    
    // Generate report if requested
    if generateReport {
        let reporter = AnalysisReporter(issues: allIssues, filePath: testFilePath)
        let outputPath = reportPath ?? "\(testFilePath.components(separatedBy: "/").last ?? "analysis")-report.md"
        
        do {
            try reporter.saveReportToFile(outputPath: outputPath)
            print("Report saved to: \(outputPath)")
        } catch {
            print("Error saving report: \(error)")
        }
    }
} catch {
    print("Error checking code: \(error)")
    exit(1)
}

// Helper function to print issues
func printIssues(_ issues: [SourceKitIssue]) {
    if issues.isEmpty {
        print("No issues found.")
        return
    }
    
    for (index, issue) in issues.enumerated() {
        let severityIndicator = issue.severity == "error" ? "🔴" : 
                                issue.severity == "warning" ? "🟠" : "🔵"
        print("\(index + 1). \(severityIndicator) Line \(issue.line):\(issue.column) - \(issue.description)")
    }
}

// Clean up if we created a temporary file
if shouldCleanup {
    do {
        try FileManager.default.removeItem(atPath: testFilePath)
        print("\nRemoved test file")
    } catch {
        print("Error removing test file: \(error)")
    }
} 