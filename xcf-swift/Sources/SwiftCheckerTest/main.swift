import Foundation
import xcf_swift

print("SwiftCodeChecker Test Suite")
print("=========================\n")

// Create a test Swift file with various code issues to detect
let testFilePath = NSTemporaryDirectory() + "SwiftCodeCheckerTest.swift"
let testCode = """
import Foundation

// File with various code issues to test SwiftCodeChecker

class badlyNamedClass {
    // Immutable assignment issue
    func testImmutableAssignment() {
        let constant = 5
        constant = 10  // Error: Can't assign to let constant
    }
    
    // Force unwrap issue
    func testForceUnwrap(value: String?) {
        print(value!)
    }
    
    // Operator precedence issue
    func testOperatorPrecedence() {
        let result = 5 + 10 * 3 - 2 / 4 > 20 && true  // Mixed arithmetic and logical operators
    }
    
    // Unreachable code
    func testUnreachableCode() -> Int {
        return 42
        print("This will never be executed")  // Unreachable
    }
    
    // Magic number
    func calculateDiscount(price: Double) -> Double {
        return price * 0.15  // Magic number 0.15
    }
    
    // Unused variable
    func testUnusedVariable() {
        var unused = "This variable is never used"
        return
    }
    
    // Excessive optional chaining
    func testExcessiveChaining(obj: SomeClass?) {
        let value = obj?.property?.subProperty?.items?.first?.name
    }
    
    // Memory leak in closure
    func testMemoryLeak() {
        let closure = { 
            self.testUnusedVariable()  // Strong reference to self
        }
    }
    
    // Empty catch block
    func testEmptyCatch() {
        do {
            try riskyOperation()
        } catch {
            // Empty catch block
        }
    }
    
    func riskyOperation() throws {
        throw NSError(domain: "Test", code: 100, userInfo: nil)
    }
}

// Nearly identical functions (refactoring opportunity)
func calculateSum(numbers: [Int]) -> Int {
    var sum = 0
    for number in numbers {
        sum += number
    }
    return sum
}

func computeTotal(values: [Int]) -> Int {
    var total = 0
    for value in values {
        total += value
    }
    return total
}

class SomeClass {
    var property: SubProperty?
}

class SubProperty {
    var subProperty: ItemContainer?
}

class ItemContainer {
    var items: [Item]?
}

class Item {
    var name: String = ""
}
"""

// Write the test file
do {
    try testCode.write(toFile: testFilePath, atomically: true, encoding: .utf8)
    print("Created test file at: \(testFilePath)\n")
} catch {
    print("Error creating test file: \(error)")
    exit(1)
}

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

// Clean up
do {
    try FileManager.default.removeItem(atPath: testFilePath)
    print("Removed test file")
} catch {
    print("Error removing test file: \(error)")
}

// Run advanced tests focusing on the new checkers
print("\n\n")
AdvancedTests.run() 
