import XCTest
@testable import xcf_swift

final class SwiftCodeCheckerTests: XCTestCase {
    
    func testSyntaxCheck() throws {
        // Create a temporary file with syntax errors
        let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("syntax_test.swift")
        let testCode = """
        func brokenFunc( {
            let x = 5
            if x > 3 {  // Missing closing brace
            print("Hello")
        }
        """
        try testCode.write(to: tempFileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFileURL) }
        
        print("\n--- Syntax Test Source ---")
        print(testCode)
        print("---------------------------")
        
        // Test the syntax checker
        let checker = SwiftCodeChecker()
        let issues = try checker.checkSwiftSyntax(at: tempFileURL.path)
        
        // Debug output
        print("Found \(issues.count) syntax issues:")
        for issue in issues {
            print("  Line \(issue.line), Col \(issue.column): \(issue.description)")
        }
        
        // Verify issues were found
        XCTAssertTrue(!issues.isEmpty, "Should find syntax issues")
        XCTAssertTrue(issues.contains(where: { $0.severity == "error" }), "Should find syntax errors")
    }
    
    func testUnusedVariables() throws {
        // Create a temporary file with unused variables
        let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("unused_vars_test.swift")
        let testCode = """
        func unusedVarsFunc() {
            let unused = 10  // This variable is never used
            var used = 20
            print(used)
        }
        """
        try testCode.write(to: tempFileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFileURL) }
        
        // Test the unused variables checker
        let checker = SwiftCodeChecker()
        let issues = try checker.checkUnusedVariables(at: tempFileURL.path)
        
        // Verify issues were found
        XCTAssertTrue(!issues.isEmpty, "Should find unused variables")
        XCTAssertEqual(issues.count, 1, "Should find exactly one unused variable")
        XCTAssertTrue(issues[0].description.contains("unused"), "Issue should be about the 'unused' variable")
    }
    
    func testImmutableAssignment() throws {
        // Create a temporary file with immutable assignment
        let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("immutable_test.swift")
        let testCode = """
        func immutableFunc() {
            let constant = 10
            constant = 20  // Error: assignment to let constant
            
            var variable = 30
            variable = 40  // This is fine
        }
        """
        
        try testCode.write(to: tempFileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFileURL) }
        
        print("\n--- Immutable Test Source ---")
        print(testCode)
        print("---------------------------")
        
        // Test the immutable assignment checker
        let checker = SwiftCodeChecker()
        let issues = try checker.checkImmutableAssignments(at: tempFileURL.path)
        
        // Debug output
        print("Found \(issues.count) immutable assignment issues:")
        for issue in issues {
            print("  Line \(issue.line), Col \(issue.column): \(issue.description)")
        }
        
        // Verify issues were found
        XCTAssertTrue(!issues.isEmpty, "Should find immutable assignment issues")
        XCTAssertEqual(issues.count, 1, "Should find exactly one immutable assignment")
        if !issues.isEmpty {
            XCTAssertTrue(issues[0].description.contains("constant"), "Issue should be about the 'constant' variable")
        }
    }
    
    func testUnreachableCode() throws {
        // Create a temporary file with unreachable code
        let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("unreachable_test.swift")
        let testCode = """
        func unreachableFunc() {
            let x = 10
            return
            let y = 20  // Unreachable code
            print(y)    // Also unreachable
        }
        """
        try testCode.write(to: tempFileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFileURL) }
        
        // Test the unreachable code checker
        let checker = SwiftCodeChecker()
        let issues = try checker.checkUnreachableCode(at: tempFileURL.path)
        
        // Verify issues were found
        XCTAssertTrue(!issues.isEmpty, "Should find unreachable code issues")
        XCTAssertTrue(issues[0].description.contains("Unreachable"), "Issue should be about unreachable code")
    }
    
    func testRunAllChecks() throws {
        // Create a temporary file with multiple issues
        let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("all_issues_test.swift")
        let testCode = """
        func multiIssueFunc() {
            let unused = 5   // Unused variable
            let constant = 10
            constant = 20    // Assignment to immutable
            return
            print("unreachable") // Unreachable code
        }
        """
        try testCode.write(to: tempFileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFileURL) }
        
        // Test running all checks
        let checker = SwiftCodeChecker()
        let issues = try checker.runAllChecks(at: tempFileURL.path)
        
        // Verify multiple issues were found
        XCTAssertTrue(issues.count >= 3, "Should find at least 3 issues")
        
        // Verify each type of issue is present
        XCTAssertTrue(issues.contains(where: { $0.description.contains("unused") }), "Should find unused variable")
        XCTAssertTrue(issues.contains(where: { $0.description.contains("constant") }), "Should find immutable assignment")
        XCTAssertTrue(issues.contains(where: { $0.description.contains("Unreachable") }), "Should find unreachable code")
    }
} 