import Foundation
import xcf_swift

/// Tests for the advanced SwiftSyntax package integrations
struct AdvancedTests {
    static func run() {
        print("SwiftCodeChecker Advanced Tests")
        print("=============================\n")
        
        // Create a test Swift file with issues for advanced checkers
        let testFilePath = NSTemporaryDirectory() + "SwiftAdvancedTest.swift"
        let testCode = """
        import Foundation
        
        // File with advanced code issues
        
        // 1. Operator precedence issues (SwiftOperators)
        func complexCalculation(a: Bool, b: Bool, c: Int, d: Int) -> Bool {
            return a && b || c > d + 5 * 10    // Complex, ambiguous operator precedence
        }
        
        // 2. Code style issues (SwiftBasicFormat)
        class   PoorlyFormatted    {
            func    badlySpacedMethod (  param1 :Int,param2:   String)   {
                if(param1>10){
                    print("Bad indentation")
                    }
                
                
                // Double empty line above
            }
        }
        
        // 3. Refactoring opportunities (SwiftRefactor)
        class LargeClass {
            func method1() { print("Method 1") }
            func method2() { print("Method 2") }
            func method3() { print("Method 3") }
            func method4() { print("Method 4") }
            func method5() { print("Method 5") }
            func method6() { print("Method 6") }
            func method7() { print("Method 7") }
            func method8() { print("Method 8") }
            func method9() { print("Method 9") }
            func method10() { print("Method 10") }
            func method11() { print("Method 11") }
            func method12() { print("Method 12") }
            // ... many more methods that should be split into multiple types
            
            // Very large function that should be broken down
            func veryLargeFunction() {
                var sum = 0
                for i in 1...100 {
                    sum += i
                }
                print("Sum: \\(sum)")
                
                var product = 1
                for i in 1...10 {
                    product *= i
                }
                print("Product: \\(product)")
                
                var fibonacci = [0, 1]
                for i in 2...20 {
                    fibonacci.append(fibonacci[i-1] + fibonacci[i-2])
                }
                print("Fibonacci: \\(fibonacci)")
                
                // ... many more unrelated operations that should be separate functions
            }
            
            // Duplicate code pattern
            func processData() {
                let data = [1, 2, 3, 4, 5]
                var result = 0
                for item in data {
                    result += item * 2
                }
                print("Result: \\(result)")
            }
            
            // Almost identical to processData
            func handleItems() {
                let items = [1, 2, 3, 4, 5]
                var output = 0
                for value in items {
                    output += value * 2
                }
                print("Output: \\(output)")
            }
        }
        
        // 4. Symbol usage issues (SwiftIDEUtils)
        class SymbolUsageIssues {
            private let message = "Hello world"  // Warning: used only once
            
            func printGreeting() {
                print(message)  // Only usage
            }
            
            func unusedMethod() {  // Warning: never called
                print("This is never called")
            }
            
            // Too short name
            func f() {  // Warning: name too short
                print("Function with too short name")
            }
            
            // Usage of a deprecated API
            func legacyOperation() {
                let url = URL(string: "https://example.com")!
                let connection = NSURLConnection.sendSynchronousRequest(
                    URLRequest(url: url),
                    returning: nil
                )
                print(connection as Any)
            }
        }
        
        // 5. Macro usage issues (SwiftSyntaxMacros)
        @available  // Missing parameters
        class MacroIssues {
            func conditionalCode() {
                #if  // Missing condition
                print("Condition")
                #endif
                
                #warning  // Missing message
                
                @objc(invalidName-with-dashes)  // Invalid naming for Objective-C
                func objcMethod() {}
            }
        }
        """
        
        // Write the test file
        do {
            try testCode.write(toFile: testFilePath, atomically: true, encoding: .utf8)
            print("Created advanced test file at: \(testFilePath)\n")
        } catch {
            print("Error creating test file: \(error)")
            return
        }
        
        // Create checker instance
        let checker = SwiftCodeChecker()
        
        // Run tests for advanced checkers
        runTest(name: "Operator Precedence Check (SwiftOperators)", 
                testFunc: { try checker.checkOperatorPrecedence(at: testFilePath) })
        
//        runTest(name: "Code Style Check (SwiftBasicFormat)", 
//                testFunc: { try checker.checkCodeStyle(at: testFilePath) })
        
        runTest(name: "Refactoring Opportunities (SwiftRefactor)", 
                testFunc: { try checker.checkRefactoringOpportunities(at: testFilePath) })
        
        runTest(name: "Symbol Usage Check (SwiftIDEUtils)", 
                testFunc: { try checker.checkSymbolUsage(at: testFilePath) })
        
        runTest(name: "Macro Usage Check (SwiftSyntaxMacros)",
                testFunc: { try checker.checkMacroUsage(at: testFilePath) })
        
        // Clean up
        do {
            try FileManager.default.removeItem(atPath: testFilePath)
            print("Removed advanced test file")
        } catch {
            print("Error removing test file: \(error)")
        }
    }
    
    private static func runTest(name: String, testFunc: () throws -> [SourceKitIssue]) {
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
    
    private static func printIssues(_ issues: [SourceKitIssue]) {
        for (index, issue) in issues.enumerated() {
            let severityIcon = issue.severity == "error" ? "❌" : 
                               issue.severity == "warning" ? "⚠️" : "ℹ️"
            print("\(index + 1). \(severityIcon) Line \(issue.line):\(issue.column) - \(issue.description)")
        }
    }
} 
