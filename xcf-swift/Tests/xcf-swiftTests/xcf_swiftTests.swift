import XCTest
import SwiftParser
@testable import xcf_swift

final class xcf_swiftTests: XCTestCase {
    func testAnalyzeFileWithSyntaxErrors() throws {
        // Create a temporary file with syntax errors
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.swift")
        
        // Write a Swift file with intentional syntax errors
        let sourceCode = """
        func testFunction) {
            let x = 5
            if x > 3 {  // Missing closing brace
            print("Hello")
            }
        
        """
        
        try sourceCode.write(to: testFile, atomically: true, encoding: .utf8)
        print("\n--- Source file ---\n\(sourceCode)\n------------------\n")
        
        // Parse and print the syntax tree
        let sourceText = try String(contentsOf: testFile, encoding: .utf8)
        let parsed = SwiftParser.Parser.parse(source: sourceText)
        print("\n--- Syntax tree ---\n\(parsed)\n------------------\n")
        
        // Create analyzer and analyze the file
        let checker = SwiftCodeChecker()
        let issues = try checker.checkSwiftSyntax(at: testFile.path)
        
        // Print the issues for debugging
        if issues.isEmpty {
            print("No issues found by analyzer.")
        } else {
            print("Issues found:")
            for issue in issues {
                print("Issue at line \(issue.line), column \(issue.column): \(issue.description)")
            }
        }
        
        // Verify we found syntax errors
        XCTAssertFalse(issues.isEmpty, "Should find syntax errors in the test file")
        
        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }
    
    func testAnalyzeValidFile() throws {
        // Create a temporary file with valid Swift code
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("valid.swift")
        
        // Write a valid Swift file
        let sourceCode = """
        func testFunction() {
            let x = 5
            if x > 3 {
                print("Hello")
            }
        }
        """
        
        try sourceCode.write(to: testFile, atomically: true, encoding: .utf8)
        
        // Create analyzer and analyze the file
        let checker = SwiftCodeChecker()
        let issues = try checker.checkSwiftSyntax(at: testFile.path)
        
        // Verify we found no syntax errors
        XCTAssertTrue(issues.isEmpty, "Should not find any syntax errors in a valid file")
        
        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }
} 