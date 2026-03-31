import Foundation
import xcf_swift

// Path to our test file
let currentDirectory = FileManager.default.currentDirectoryPath
let testFilePath = "\(currentDirectory)/test.swift"

print("SwiftCodeChecker Custom Test")
print("===========================\n")
print("Analyzing file: \(testFilePath)\n")

// Create checker instance
let checker = SwiftCodeChecker()

func runTest(name: String, testFunc: () throws -> [SourceKitIssue]) {
    print("=== \(name) ===")
    do {
        let issues = try testFunc()
        if issues.isEmpty {
            print("No issues found.\n")
        } else {
            printIssues(issues)
            print("")
        }
    } catch {
        print("Error: \(error)\n")
    }
}

// Run individual tests
runTest(name: "Syntax Check", testFunc: { try checker.checkSwiftSyntax(at: testFilePath) })
runTest(name: "Unused Variables", testFunc: { try checker.checkUnusedVariables(at: testFilePath) })
runTest(name: "Immutable Assignments", testFunc: { try checker.checkImmutableAssignments(at: testFilePath) })
runTest(name: "Unreachable Code", testFunc: { try checker.checkUnreachableCode(at: testFilePath) })
runTest(name: "Force Unwraps", testFunc: { try checker.checkForceUnwraps(at: testFilePath) })
runTest(name: "Operator Precedence", testFunc: { try checker.checkOperatorPrecedence(at: testFilePath) })
runTest(name: "Refactoring Opportunities", testFunc: { try checker.checkRefactoringOpportunities(at: testFilePath) })
runTest(name: "Memory Leaks", testFunc: { try checker.checkMemoryLeaks(at: testFilePath) })
runTest(name: "Empty Catch Blocks", testFunc: { try checker.checkEmptyCatchBlocks(at: testFilePath) })
runTest(name: "Magic Numbers", testFunc: { try checker.checkMagicNumbers(at: testFilePath) })
runTest(name: "Optional Chaining Depth", testFunc: { try checker.checkOptionalChainingDepth(at: testFilePath) })

// Run all checks
print("=== Complete Analysis ===")
do {
    let allIssues = try checker.runAllChecks(at: testFilePath)
    
    // Group issues by severity
    let errors = allIssues.filter { $0.severity == "error" }
    let warnings = allIssues.filter { $0.severity == "warning" }
    let infos = allIssues.filter { $0.severity == "info" }
    
    // Summary
    print("Found \(allIssues.count) total issues:")
    print("- \(errors.count) errors")
    print("- \(warnings.count) warnings")
    print("- \(infos.count) informational messages\n")
    
    // Print errors first
    if !errors.isEmpty {
        print("ERRORS:")
        printIssues(errors)
        print("")
    }
    
    // Print top 5 warnings only to avoid cluttering output
    if !warnings.isEmpty {
        print("TOP 5 WARNINGS:")
        printIssues(Array(warnings.prefix(5)))
        if warnings.count > 5 {
            print("... and \(warnings.count - 5) more warnings\n")
        } else {
            print("")
        }
    }
} catch {
    print("Error running complete analysis: \(error)")
}

// Helper function to print issues
func printIssues(_ issues: [SourceKitIssue]) {
    for (index, issue) in issues.enumerated() {
        let severityIcon = issue.severity == "error" ? "❌" : 
                          issue.severity == "warning" ? "⚠️" : "ℹ️"
        print("\(index + 1). \(severityIcon) Line \(issue.line):\(issue.column) - \(issue.description)")
    }
} 