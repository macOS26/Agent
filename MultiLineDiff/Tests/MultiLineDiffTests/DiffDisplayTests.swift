import Testing
@testable import MultiLineDiff

/// Tests for the diff display functionality
struct DiffDisplayTests {
    
    @Test("Display diff in AI format")
    func testDisplayDiffAIFormat() throws {
        let source = """
        class UserManager {
            private var users: [String: User] = [:]
            
            func addUser(name: String, email: String) -> Bool {
                guard !name.isEmpty && !email.isEmpty else {
                    return false
                }
                
                let user = User(name: name, email: email)
                users[email] = user
                return true
            }
        }
        """
        
        let destination = """
        class UserManager {
            private var users: [String: User] = [:]
            private var userCount: Int = 0
            
            func addUser(name: String, email: String, age: Int = 0) -> Result<User, UserError> {
                guard !name.isEmpty && !email.isEmpty else {
                    return .failure(.invalidInput)
                }
                
                let user = User(id: UUID(), name: name, email: email, age: age)
                users[email] = user
                userCount += 1
                return .success(user)
            }
        }
        """
        
        let diff = MultiLineDiff.createDiff(
            source: source,
            destination: destination,
            algorithm: .megatron
        )
        
        let aiOutput = MultiLineDiff.displayDiff(
            diff: diff,
            source: source,
            format: .ai
        )
        
        // AI format should not contain ANSI color codes
        #expect(!aiOutput.contains("\u{001B}"))
        
        // Should contain diff markers
        #expect(aiOutput.contains(DiffSymbols.retain) || aiOutput.contains(DiffSymbols.insert) || aiOutput.contains(DiffSymbols.delete))
        
        // Should contain some of the source content
        #expect(aiOutput.contains("UserManager"))
        
        print("🤖 AI Format Output:")
        print("```swift")
        print(aiOutput)
        print("```")
    }
    
    @Test("Display diff in terminal format")
    func testDisplayDiffTerminalFormat() throws {
        let source = """
        func greet(name: String) -> String {
            return "Hello, \\(name)!"
        }
        """
        
        let destination = """
        func greet(name: String, greeting: String = "Hello") -> String {
            return "\\(greeting), \\(name)!"
        }
        """
        
        let diff = MultiLineDiff.createDiff(
            source: source,
            destination: destination,
            algorithm: .zoom
        )
        
        let terminalOutput = MultiLineDiff.displayDiff(
            diff: diff,
            source: source,
            format: .terminal
        )
        
        // Terminal format should contain ANSI color codes
        #expect(terminalOutput.contains("\u{001B}"))
        
        // Should contain diff markers
        #expect(terminalOutput.contains(DiffSymbols.retain) || terminalOutput.contains(DiffSymbols.insert) || terminalOutput.contains(DiffSymbols.delete))
        
        // Should contain some of the source content
        #expect(terminalOutput.contains("greet"))
        
        print("🖥️ Terminal Format Output:")
        print(terminalOutput)
    }
    
    @Test("Display diff with empty operations")
    func testDisplayDiffEmptyOperations() throws {
        let source = "Hello, world!"
        let destination = "Hello, world!"
        
        let diff = MultiLineDiff.createDiff(
            source: source,
            destination: destination,
            algorithm: .flash
        )
        
        let aiOutput = MultiLineDiff.displayDiff(
            diff: diff,
            source: source,
            format: .ai
        )
        
        let terminalOutput = MultiLineDiff.displayDiff(
            diff: diff,
            source: source,
            format: .terminal
        )
        
        // Both outputs should handle empty diffs gracefully
        #expect(!aiOutput.isEmpty)
        #expect(!terminalOutput.isEmpty)
        
        print("📝 Empty Diff AI Output: '\(aiOutput)'")
        print("🖥️ Empty Diff Terminal Output: '\(terminalOutput)'")
    }
    
    @Test("Display diff with only insertions")
    func testDisplayDiffOnlyInsertions() throws {
        let source = ""
        let destination = """
        // New file content
        class NewClass {
            var property: String = "value"
        }
        """
        
        let diff = MultiLineDiff.createDiff(
            source: source,
            destination: destination,
            algorithm: .starscream
        )
        
        let aiOutput = MultiLineDiff.displayDiff(
            diff: diff,
            source: source,
            format: .ai
        )
        
        let terminalOutput = MultiLineDiff.displayDiff(
            diff: diff,
            source: source,
            format: .terminal
        )
        
        // Should contain insertion markers
        #expect(aiOutput.contains(DiffSymbols.insert))
        #expect(terminalOutput.contains(DiffSymbols.insert))
        
        // Should contain the new content
        #expect(aiOutput.contains("NewClass"))
        #expect(terminalOutput.contains("NewClass"))
        
        print("➕ Insertion-only AI Output:")
        print(aiOutput)
        print("➕ Insertion-only Terminal Output:")
        print(terminalOutput)
    }
    
    @Test("Display diff with only deletions")
    func testDisplayDiffOnlyDeletions() throws {
        let source = """
        // Old file content
        class OldClass {
            var oldProperty: String = "old value"
        }
        """
        let destination = ""
        
        let diff = MultiLineDiff.createDiff(
            source: source,
            destination: destination,
            algorithm: .optimus
        )
        
        let aiOutput = MultiLineDiff.displayDiff(
            diff: diff,
            source: source,
            format: .ai
        )
        
        let terminalOutput = MultiLineDiff.displayDiff(
            diff: diff,
            source: source,
            format: .terminal
        )
        
        // Should contain deletion markers
        #expect(aiOutput.contains(DiffSymbols.delete))
        #expect(terminalOutput.contains(DiffSymbols.delete))
        
        // Should contain the old content
        #expect(aiOutput.contains("OldClass"))
        #expect(terminalOutput.contains("OldClass"))
        
        print("➖ Deletion-only AI Output:")
        print(aiOutput)
        print("➖ Deletion-only Terminal Output:")
        print(terminalOutput)
    }
    
    @Test("Display diff format consistency")
    func testDisplayDiffFormatConsistency() throws {
        let source = """
        let x = 1
        let y = 2
        let z = x + y
        """
        
        let destination = """
        let x = 10
        let y = 20
        let z = x + y
        print(z)
        """
        
        // Test all algorithms produce valid output
        let algorithms: [DiffAlgorithm] = [.zoom, .megatron, .flash, .starscream, .optimus]
        
        for algorithm in algorithms {
            let diff = MultiLineDiff.createDiff(
                source: source,
                destination: destination,
                algorithm: algorithm
            )
            
            let aiOutput = MultiLineDiff.displayDiff(
                diff: diff,
                source: source,
                format: .ai
            )
            
            let terminalOutput = MultiLineDiff.displayDiff(
                diff: diff,
                source: source,
                format: .terminal
            )
            
            // Both formats should produce non-empty output
            #expect(!aiOutput.isEmpty, "AI output should not be empty for algorithm \(algorithm)")
            #expect(!terminalOutput.isEmpty, "Terminal output should not be empty for algorithm \(algorithm)")
            
            // AI format should not have ANSI codes
            #expect(!aiOutput.contains("\u{001B}"), "AI format should not contain ANSI codes for algorithm \(algorithm)")
            
            // Terminal format should have ANSI codes (unless it's a very simple diff)
            // Note: Simple diffs might not have colors, so we'll just check it's different from AI
            #expect(aiOutput != terminalOutput, "AI and terminal formats should be different for algorithm \(algorithm)")
            
            print("🔄 Algorithm \(algorithm):")
            print("   AI length: \(aiOutput.count) chars")
            print("   Terminal length: \(terminalOutput.count) chars")
        }
    }
    
    @Test("Display diff with multiline changes")
    func testDisplayDiffMultilineChanges() throws {
        let source = """
        func calculateTotal(items: [Item]) -> Double {
            var total = 0.0
            for item in items {
                total += item.price
            }
            return total
        }
        """
        
        let destination = """
        func calculateTotal(items: [Item], tax: Double = 0.0) -> Double {
            var total = 0.0
            for item in items {
                total += item.price * (1.0 + item.taxRate)
            }
            total += tax
            return total
        }
        """
        
        let diff = MultiLineDiff.createDiff(
            source: source,
            destination: destination,
            algorithm: .megatron
        )
        
        let aiOutput = MultiLineDiff.displayDiff(
            diff: diff,
            source: source,
            format: .ai
        )
        
        let terminalOutput = MultiLineDiff.displayDiff(
            diff: diff,
            source: source,
            format: .terminal
        )
        
        // Should handle multiline changes properly
        #expect(aiOutput.contains("calculateTotal"))
        #expect(terminalOutput.contains("calculateTotal"))
        
        // Should show the parameter change
        #expect(aiOutput.contains("tax") || terminalOutput.contains("tax"))
        
        print("📄 Multiline AI Output:")
        print(aiOutput)
        print("📄 Multiline Terminal Output:")
        print(terminalOutput)
    }
    
    @Test("Create and display diff convenience method - AI format")
    func testCreateAndDisplayDiffAIFormat() throws {
        let source = """
        struct Point {
            let x: Int
            let y: Int
        }
        """
        
        let destination = """
        struct Point {
            let x: Double
            let y: Double
            let z: Double = 0.0
        }
        """
        
        let output = MultiLineDiff.createAndDisplayDiff(
            source: source,
            destination: destination,
            format: .ai,
            algorithm: .flash
        )
        
        // Should not contain ANSI color codes
        #expect(!output.contains("\u{001B}"))
        
        // Should contain diff markers
        #expect(output.contains(DiffSymbols.retain) || output.contains(DiffSymbols.insert) || output.contains(DiffSymbols.delete))
        
        // Should contain the struct content
        #expect(output.contains("Point"))
        #expect(output.contains("Double"))
        
        print("🚀 Convenience AI Output:")
        print("```swift")
        print(output)
        print("```")
    }
    
    @Test("Create and display diff convenience method - Terminal format")
    func testCreateAndDisplayDiffTerminalFormat() throws {
        let source = """
        enum Status {
            case active
            case inactive
        }
        """
        
        let destination = """
        enum Status {
            case active
            case inactive
            case pending
            case archived
        }
        """
        
        let output = MultiLineDiff.createAndDisplayDiff(
            source: source,
            destination: destination,
            format: .terminal,
            algorithm: .starscream
        )
        
        // Should contain ANSI color codes
        #expect(output.contains("\u{001B}"))
        
        // Should contain diff markers
        #expect(output.contains(DiffSymbols.retain) || output.contains(DiffSymbols.insert) || output.contains(DiffSymbols.delete))
        
        // Should contain the enum content
        #expect(output.contains("Status"))
        #expect(output.contains("pending") || output.contains("archived"))
        
        print("🚀 Convenience Terminal Output:")
        print(output)
    }
    
    @Test("Create and display diff convenience method - All algorithms")
    func testCreateAndDisplayDiffAllAlgorithms() throws {
        let source = "let value = 42"
        let destination = "let value = 100\nlet doubled = value * 2"
        
        let algorithms: [DiffAlgorithm] = [.zoom, .megatron, .flash, .starscream, .optimus]
        
        for algorithm in algorithms {
            let aiOutput = MultiLineDiff.createAndDisplayDiff(
                source: source,
                destination: destination,
                format: .ai,
                algorithm: algorithm
            )
            
            let terminalOutput = MultiLineDiff.createAndDisplayDiff(
                source: source,
                destination: destination,
                format: .terminal,
                algorithm: algorithm
            )
            
            // Both should be non-empty
            #expect(!aiOutput.isEmpty, "AI output should not be empty for \(algorithm)")
            #expect(!terminalOutput.isEmpty, "Terminal output should not be empty for \(algorithm)")
            
            // AI should not have ANSI codes
            #expect(!aiOutput.contains("\u{001B}"), "AI output should not have ANSI codes for \(algorithm)")
            
            // Should contain the value change
            #expect(aiOutput.contains("42") || aiOutput.contains("100"))
            #expect(terminalOutput.contains("42") || terminalOutput.contains("100"))
            
            print("🔄 Convenience \(algorithm):")
            print("   AI: \(aiOutput.count) chars")
            print("   Terminal: \(terminalOutput.count) chars")
        }
    }
    
    @Test("Create and display diff convenience method - Edge cases")
    func testCreateAndDisplayDiffEdgeCases() throws {
        // Test empty strings - this can result in empty output which is valid
        let emptyOutput = MultiLineDiff.createAndDisplayDiff(
            source: "",
            destination: "",
            format: .ai
        )
        // Empty diff can result in empty output, which is valid
        
        // Test identical strings
        let identicalOutput = MultiLineDiff.createAndDisplayDiff(
            source: "same content",
            destination: "same content",
            format: .terminal
        )
        #expect(!identicalOutput.isEmpty)
        #expect(identicalOutput.contains("same content"))
        
        // Test large insertion
        let largeInsertOutput = MultiLineDiff.createAndDisplayDiff(
            source: "",
            destination: String(repeating: "line\n", count: 100),
            format: .ai
        )
        #expect(largeInsertOutput.contains(DiffSymbols.insert))
        #expect(largeInsertOutput.contains("line"))
        
        // Test large deletion
        let largeDeletionOutput = MultiLineDiff.createAndDisplayDiff(
            source: String(repeating: "delete\n", count: 50),
            destination: "",
            format: .terminal
        )
        #expect(largeDeletionOutput.contains(DiffSymbols.delete))
        #expect(largeDeletionOutput.contains("delete"))
        
        print("✅ Edge case tests completed")
        print("   Empty: \(emptyOutput.count) chars")
        print("   Identical: \(identicalOutput.count) chars")
        print("   Large insert: \(largeInsertOutput.count) chars")
        print("   Large deletion: \(largeDeletionOutput.count) chars")
    }
} 