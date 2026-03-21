import Testing
@testable import MultiLineDiff

/// Tests for ASCII diff parsing functionality
struct ASCIIDiffParsingTests {
    
    @Test("Parse simple ASCII diff")
    func testParseSimpleASCIIDiff() throws {
        let asciiDiff = """
        \(DiffSymbols.retain) func greet() {
        \(DiffSymbols.delete)     print("Hello")
        \(DiffSymbols.insert)     print("Hello, World!")
        \(DiffSymbols.retain) }
        """
        
        let diffResult = try MultiLineDiff.parseDiffFromASCII(asciiDiff)
        
        // Should have 4 operations: retain, delete, insert, retain
        #expect(diffResult.operations.count == 4)
        
        // Verify operations
        if case .retain(let count) = diffResult.operations[0] {
            #expect(count == 15) // "func greet() {\n"
        } else {
            #expect(Bool(false), "First operation should be retain")
        }
        
        if case .delete(let count) = diffResult.operations[1] {
            #expect(count == 19) // "    print(\"Hello\")\n"
        } else {
            #expect(Bool(false), "Second operation should be delete")
        }
        
        if case .insert(let text) = diffResult.operations[2] {
            // The parsed text should include the trailing newline to match original format
            #expect(text == "    print(\"Hello, World!\")\n")
        } else {
            #expect(Bool(false), "Third operation should be insert")
        }
        
        if case .retain(let count) = diffResult.operations[3] {
            #expect(count == 1) // "}"
        } else {
            #expect(Bool(false), "Fourth operation should be retain")
        }
        
        print("✅ Simple ASCII diff parsed successfully")
        print("   Operations: \(diffResult.operations.count)")
        for (i, op) in diffResult.operations.enumerated() {
            switch op {
            case .retain(let count):
                print("   \(i): RETAIN(\(count))")
            case .delete(let count):
                print("   \(i): DELETE(\(count))")
            case .insert(let text):
                print("   \(i): INSERT(\(text.count): \"\(text.prefix(20))...\")")
            }
        }
    }
    
    @Test("Parse ASCII diff with only additions")
    func testParseASCIIDiffOnlyAdditions() throws {
        let asciiDiff = """
        \(DiffSymbols.retain) class Example {
        \(DiffSymbols.insert)     var newProperty: String = "value"
        \(DiffSymbols.insert)     
        \(DiffSymbols.insert)     func newMethod() {
        \(DiffSymbols.insert)         print("New functionality")
        \(DiffSymbols.insert)     }
        \(DiffSymbols.retain) }
        """
        
        let diffResult = try MultiLineDiff.parseDiffFromASCII(asciiDiff)
        
        // Should have 3 operations: retain, insert, retain
        #expect(diffResult.operations.count == 3)
        
        if case .retain(let count) = diffResult.operations[0] {
            #expect(count == 16) // "class Example {\n"
        }
        
        if case .insert(let text) = diffResult.operations[1] {
            let expectedInsert = "    var newProperty: String = \"value\"\n    \n    func newMethod() {\n        print(\"New functionality\")\n    }\n"
            #expect(text == expectedInsert)
        }
        
        if case .retain(let count) = diffResult.operations[2] {
            #expect(count == 1) // "}"
        }
        
        print("✅ Addition-only ASCII diff parsed successfully")
    }
    
    @Test("Parse ASCII diff with only deletions")
    func testParseASCIIDiffOnlyDeletions() throws {
        let asciiDiff = """
        \(DiffSymbols.retain) class Example {
        \(DiffSymbols.delete)     var oldProperty: String = "old"
        \(DiffSymbols.delete)     
        \(DiffSymbols.delete)     func oldMethod() {
        \(DiffSymbols.delete)         print("Old functionality")
        \(DiffSymbols.delete)     }
        \(DiffSymbols.retain) }
        """
        
        let diffResult = try MultiLineDiff.parseDiffFromASCII(asciiDiff)
        
        // Should have 3 operations: retain, delete, retain
        #expect(diffResult.operations.count == 3)
        
        if case .retain(let count) = diffResult.operations[0] {
            #expect(count == 16) // "class Example {\n"
        }
        
        if case .delete(let count) = diffResult.operations[1] {
            // Calculate expected delete count
            let deletedContent = """
                var oldProperty: String = "old"
            
                func oldMethod() {
                    print("Old functionality")
                }
            """
            #expect(count == deletedContent.count + 5) // +5 for the 5 newlines (4 between lines + 1 final)
        }
        
        if case .retain(let count) = diffResult.operations[2] {
            #expect(count == 1) // "}"
        }
        
        print("✅ Deletion-only ASCII diff parsed successfully")
    }
    
    @Test("Parse complex ASCII diff with mixed operations")
    func testParseComplexASCIIDiff() throws {
        let asciiDiff = """
        \(DiffSymbols.retain) struct User {
        \(DiffSymbols.retain)     let id: UUID
        \(DiffSymbols.delete)     let name: String
        \(DiffSymbols.delete)     let email: String
        \(DiffSymbols.insert)     let fullName: String
        \(DiffSymbols.insert)     let emailAddress: String
        \(DiffSymbols.insert)     let age: Int
        \(DiffSymbols.retain)     
        \(DiffSymbols.retain)     init(name: String, email: String) {
        \(DiffSymbols.retain)         self.id = UUID()
        \(DiffSymbols.delete)         self.name = name
        \(DiffSymbols.delete)         self.email = email
        \(DiffSymbols.insert)         self.fullName = name
        \(DiffSymbols.insert)         self.emailAddress = email
        \(DiffSymbols.insert)         self.age = 0
        \(DiffSymbols.retain)     }
        \(DiffSymbols.retain) }
        """
        
        let diffResult = try MultiLineDiff.parseDiffFromASCII(asciiDiff)
        
        // Verify we have operations
        #expect(diffResult.operations.count > 0)
        
        print("✅ Complex ASCII diff parsed successfully")
        print("   Operations: \(diffResult.operations.count)")
        for (i, op) in diffResult.operations.enumerated() {
            switch op {
            case .retain(let count):
                print("   \(i): RETAIN(\(count))")
            case .delete(let count):
                print("   \(i): DELETE(\(count))")
            case .insert(let text):
                let preview = text.replacingOccurrences(of: "\n", with: "\\n").prefix(30)
                print("   \(i): INSERT(\(text.count): \"\(preview)...\")")
            }
        }
    }
    
    @Test("Apply ASCII diff to source code")
    func testApplyASCIIDiffToSource() throws {
        let sourceCode = """
        func greet() {
            print("Hello")
        }
        """
        
        let asciiDiff = """
        \(DiffSymbols.retain) func greet() {
        \(DiffSymbols.delete)     print("Hello")
        \(DiffSymbols.insert)     print("Hello, World!")
        \(DiffSymbols.retain) }
        """
        
        let result = try MultiLineDiff.applyASCIIDiff(
            to: sourceCode,
            asciiDiff: asciiDiff
        )
        
        let expectedResult = """
        func greet() {
            print("Hello, World!")
        }
        """
        
        #expect(result == expectedResult)
        
        print("✅ ASCII diff applied successfully")
        print("   Source: \(sourceCode.count) chars")
        print("   Result: \(result.count) chars")
        print("   Expected: \(expectedResult.count) chars")
    }
    
    @Test("Round trip: create diff, display as ASCII, parse back, apply")
    func testRoundTripASCIIDiff() throws {
        let source = """
        class Calculator {
            func add(a: Int, b: Int) -> Int {
                return a + b
            }
        }
        """
        
        let destination = """
        class Calculator {
            func add(a: Int, b: Int) -> Int {
                return a + b
            }
            
            func multiply(a: Int, b: Int) -> Int {
                return a * b
            }
        }
        """
        
        // Step 1: Create original diff
        let originalDiff = MultiLineDiff.createDiff(
            source: source,
            destination: destination,
            algorithm: .megatron
        )
        
        // Step 2: Display as ASCII
        let asciiDiff = MultiLineDiff.displayDiff(
            diff: originalDiff,
            source: source,
            format: .ai
        )
        
        // Step 3: Parse ASCII back to diff
        let parsedDiff = try MultiLineDiff.parseDiffFromASCII(asciiDiff)
        
        // Step 4: Apply parsed diff
        let result = try MultiLineDiff.applyDiff(to: source, diff: parsedDiff)
        
        // Step 5: Verify result matches destination
        #expect(result == destination)
        
        print("✅ Round trip successful")
        print("   Original operations: \(originalDiff.operations.count)")
        print("   Parsed operations: \(parsedDiff.operations.count)")
        print("   ASCII diff length: \(asciiDiff.count) chars")
        print("   Result matches destination: \(result == destination)")
    }
    
    @Test("Parse ASCII diff with empty lines")
    func testParseASCIIDiffWithEmptyLines() throws {
                let asciiDiff = """
        \(DiffSymbols.retain) func example() {
        \(DiffSymbols.retain)     let x = 1

        \(DiffSymbols.retain)     let y = 2
        \(DiffSymbols.insert)     let z = 3
        \(DiffSymbols.retain) }
        """
        
        let diffResult = try MultiLineDiff.parseDiffFromASCII(asciiDiff)
        
        // Should handle empty lines gracefully
        #expect(diffResult.operations.count > 0)
        
        print("✅ ASCII diff with empty lines parsed successfully")
    }
    
    @Test("Error handling: invalid prefix")
    func testInvalidPrefix() throws {
        let invalidDiff = """
        \(DiffSymbols.retain) func example() {
        *     invalid prefix
        \(DiffSymbols.retain) }
        """
        
        do {
            _ = try MultiLineDiff.parseDiffFromASCII(invalidDiff)
            #expect(Bool(false), "Should have thrown an error for invalid prefix")
        } catch let error as DiffParsingError {
            if case .invalidPrefix(let line, let prefix) = error {
                #expect(line == 2)
                #expect(prefix == "* ")
                print("✅ Invalid prefix error handled correctly: \(error.localizedDescription)")
            } else {
                #expect(Bool(false), "Wrong error type")
            }
        }
    }
    
    @Test("Error handling: invalid format")
    func testInvalidFormat() throws {
        let invalidDiff = """
        \(DiffSymbols.retain) func example() {
        x
        \(DiffSymbols.retain) }
        """
        
        do {
            _ = try MultiLineDiff.parseDiffFromASCII(invalidDiff)
            #expect(Bool(false), "Should have thrown an error for invalid format")
        } catch let error as DiffParsingError {
            if case .invalidFormat(let line, let content) = error {
                #expect(line == 2)
                #expect(content == "x")
                print("✅ Invalid format error handled correctly: \(error.localizedDescription)")
            } else {
                #expect(Bool(false), "Wrong error type")
            }
        }
    }
    
    @Test("Parse ASCII diff with special characters")
    func testParseASCIIDiffWithSpecialCharacters() throws {
        let asciiDiff = """
        \(DiffSymbols.retain) func greet(name: String) {
        \(DiffSymbols.delete)     print("Hello, \\(name)!")
        \(DiffSymbols.insert)     print("👋 Hello, \\(name)! 🎉")
        \(DiffSymbols.retain) }
        """
        
        let diffResult = try MultiLineDiff.parseDiffFromASCII(asciiDiff)
        
        #expect(diffResult.operations.count == 4)
        
        // Check that special characters are preserved
        if case .insert(let text) = diffResult.operations[2] {
            #expect(text.contains("👋"))
            #expect(text.contains("🎉"))
            #expect(text.contains("\\(name)"))
        }
        
        print("✅ ASCII diff with special characters parsed successfully")
    }
    
    @Test("Convenience method: applyASCIIDiff")
    func testApplyASCIIDiffConvenience() throws {
        let sourceCode = "let x = 1\nlet y = 2\n"
        
        let asciiDiff = """
        \(DiffSymbols.retain) let x = 1
        \(DiffSymbols.delete) let y = 2
        \(DiffSymbols.insert) let y = 20
        \(DiffSymbols.insert) let z = 3
        """
        
        let result = try MultiLineDiff.applyASCIIDiff(
            to: sourceCode,
            asciiDiff: asciiDiff
        )
        
        let expectedResult = "let x = 1\nlet y = 20\nlet z = 3"
        
        #expect(result == expectedResult)
        
        print("✅ Convenience method applyASCIIDiff works correctly")
        print("   Source: '\(sourceCode)'")
        print("   Result: '\(result)'")
        print("   Expected: '\(expectedResult)'")
    }
    
    @Test("AI workflow simulation")
    func testAIWorkflowSimulation() throws {
        // Simulate an AI receiving source code and submitting a diff
        let originalCode = """
        class UserManager {
            private var users: [User] = []
            
            func addUser(_ user: User) {
                users.append(user)
            }
        }
        """
        
        // AI submits this diff
        let aiSubmittedDiff = """
        \(DiffSymbols.retain) class UserManager {
        \(DiffSymbols.retain)     private var users: [User] = []
        \(DiffSymbols.insert)     private var userCount: Int = 0
        \(DiffSymbols.retain)     
        \(DiffSymbols.retain)     func addUser(_ user: User) {
        \(DiffSymbols.retain)         users.append(user)
        \(DiffSymbols.insert)         userCount += 1
        \(DiffSymbols.retain)     }
        \(DiffSymbols.retain) }
        """
        
        // Apply the AI's diff
        let modifiedCode = try MultiLineDiff.applyASCIIDiff(
            to: originalCode,
            asciiDiff: aiSubmittedDiff
        )
        
        // Verify the result
        let expectedCode = """
        class UserManager {
            private var users: [User] = []
            private var userCount: Int = 0
            
            func addUser(_ user: User) {
                users.append(user)
                userCount += 1
            }
        }
        """
        
        #expect(modifiedCode == expectedCode)
        
        print("✅ AI workflow simulation successful")
        print("   Original: \(originalCode.count) chars")
        print("   Modified: \(modifiedCode.count) chars")
        print("   Diff lines: \(aiSubmittedDiff.components(separatedBy: .newlines).count)")
        
        // Also test that we can create a diff from the result and it round-trips
        let verificationDiff = MultiLineDiff.createDiff(
            source: originalCode,
            destination: modifiedCode,
            algorithm: .megatron
        )
        
        let verificationResult = try MultiLineDiff.applyDiff(
            to: originalCode,
            diff: verificationDiff
        )
 
        #expect(verificationResult == modifiedCode)
        print("   Round-trip verification: ✅")
    }
} 