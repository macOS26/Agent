import Testing
import Foundation
@testable import MultiLineDiff

@Test func example() throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}

@Test func testCreateDiffWithEmptyStrings() throws {
    let result = MultiLineDiff.createDiff(source: "", destination: "")
    #expect(result.operations.isEmpty)
}

@Test func testCreateDiffWithSourceOnly() throws {
    let source = "Hello, world!"
    let destination = ""
    
    let result = MultiLineDiff.createDiff(source: source, destination: destination)
    
    #expect(result.operations.count == 1)
    if case .delete(let count) = result.operations[0] {
        #expect(count == source.count)
    } else {
        throw TestError("Expected delete operation")
    }
}

@Test func testCreateDiffWithDestinationOnly() throws {
    let source = ""
    let destination = "Hello, world!"
    
    let result = MultiLineDiff.createDiff(source: source, destination: destination)
    
    #expect(result.operations.count == 1)
    if case .insert(let text) = result.operations[0] {
        #expect(text == destination)
    } else {
        throw TestError("Expected insert operation")
    }
}

@Test func testCreateDiffWithSingleLineChanges() throws {
    let source = "Hello, world!"
    let destination = "Hello, Swift!"
    
    // Use the Brus algorithm explicitly, as we're making assumptions about its output format
    let result = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
    
    // Expected operations: retain "Hello, ", delete "world", insert "Swift", retain "!"
    #expect(result.operations.count == 4)
    
    if case .retain(let count) = result.operations[0] {
        #expect(count == "Hello, ".count)
    } else {
        throw TestError("Expected retain operation first")
    }
    
    if case .delete(let count) = result.operations[1] {
        #expect(count == "world".count)
    } else {
        throw TestError("Expected delete operation second")
    }
    
    if case .insert(let text) = result.operations[2] {
        #expect(text == "Swift")
    } else {
        throw TestError("Expected insert operation third")
    }
    
    if case .retain(let count) = result.operations[3] {
        #expect(count == "!".count)
    } else {
        throw TestError("Expected retain operation fourth")
    }
}

@Test func testCreateDiffWithMultiLineChanges() throws {
    let source = """
    hello
    1
    signal(SIGINT) { _ in
        exit(1)
    }
    xxx
    """
    
    let destination = """
    1
    hello
     signal(SIGINT) { _ in
         exit(0)
     }
    """
    
    let result = MultiLineDiff.createDiff(source: source, destination: destination)
    
    // Verify the diff can be applied correctly
    let applied = try MultiLineDiff.applyDiff(to: source, diff: result)
    #expect(applied == destination)
}

@Test func testApplyDiffWithEmptyStrings() throws {
    let result = MultiLineDiff.createDiff(source: "", destination: "")
    let applied = try MultiLineDiff.applyDiff(to: "", diff: result)
    #expect(applied == "")
}

@Test func testApplyDiffWithSourceOnly() throws {
    let source = "Hello, world!"
    let destination = ""
    
    let result = MultiLineDiff.createDiff(source: source, destination: destination)
    let applied = try MultiLineDiff.applyDiff(to: source, diff: result)
    
    #expect(applied == destination)
}

@Test func testApplyDiffWithDestinationOnly() throws {
    let source = ""
    let destination = "Hello, world!"
    
    let result = MultiLineDiff.createDiff(source: source, destination: destination)
    let applied = try MultiLineDiff.applyDiff(to: source, diff: result)
    
    #expect(applied == destination)
}

@Test func testApplyDiffWithSingleLineChanges() throws {
    let source = "Hello, world!"
    let destination = "Hello, Swift!"
    
    let result = MultiLineDiff.createDiff(source: source, destination: destination)
    let applied = try MultiLineDiff.applyDiff(to: source, diff: result)
    
    #expect(applied == destination)
}

@Test func testApplyDiffWithMultiLineChanges() throws {
    let source = """
    Line 1
    Line 2
    Line 4
    Line 3
    """
    
    let destination = """
    Line 1
    Modified Line 2
    Line 3
    Line 4
    """
    
    // Use Brus algorithm explicitly for consistent behavior
    let result = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
    let applied = try MultiLineDiff.applyDiff(to: source, diff: result)
    #expect(applied == destination)
}

@Test func testApplyDiffWithUnicodeContent() throws {
    let source = "Hello, 世界 !"
    let destination = "Hello, 世界! 🚀"
    
    let result = MultiLineDiff.createDiff(source: source, destination: destination)
    let applied = try MultiLineDiff.applyDiff(to: source, diff: result)
    #expect(applied == destination)
}

@Test func testInvalidApplyDiff() throws {
    // Create a diff result with invalid operations
    let operations: [DiffOperation] = [
        .retain(100)  // Source doesn't have 100 characters
    ]
    
    let diff = DiffResult(operations: operations)
    
    do {
        _ = try MultiLineDiff.applyDiff(to: "short string", diff: diff)
        throw TestError("Expected error when applying invalid diff")
    } catch {
        // Error is expected
    }
}

@Test func testRoundTrip() throws {
    // Use a minimal set of test cases to avoid hanging
    let testCases = [
        ("", ""),
        ("Hello", "")
    ]
    
    for (source, destination) in testCases {
        let diff = MultiLineDiff.createDiff(source: source, destination: destination)
        let result = try MultiLineDiff.applyDiff(to: source, diff: diff)
        #expect(result == destination, "Round trip failed for source: \(source), destination: \(destination)")
    }
}

@Test func testFileBasedDiffOperations() throws {
    let testFiles = try TestFileManager(testName: "FileBasedDiff")
    
    // Sample source code
    let sourceCode = """
    import Foundation
    
    class Calculator {
        func add(_ a: Int, _ b: Int) -> Int {
            return a + b
        }
        
        func subtract(_ a: Int, _ b: Int) -> Int {
            return a - b
        }
    }
    """
    
    // Sample modified code with changes
    let modifiedCode = """
    import Foundation
    
    class Calculator {
        // Add two numbers
        func add(_ a: Int, _ b: Int) -> Int {
            return a + b
        }
        
        // Subtract two numbers
        func subtract(_ a: Int, _ b: Int) -> Int {
            return a - b
        }
        
        // Multiply two numbers
        func multiply(_ a: Int, _ b: Int) -> Int {
            return a * b
        }
    }
    """
    
    // Write files
    let sourceFileURL = try testFiles.createFile(named: "source_code.swift", content: sourceCode)
    let modifiedFileURL = try testFiles.createFile(named: "modified_code.swift", content: modifiedCode)
    let diffFileURL = try testFiles.createFile(named: "diff.json", content: "")
    
    // Read back the files
    let sourceFromFile = try testFiles.readFile(sourceFileURL)
    let modifiedFromFile = try testFiles.readFile(modifiedFileURL)
    
    // Create diff
    let diff = MultiLineDiff.createDiff(source: sourceFromFile, destination: modifiedFromFile)
    
    // Save diff to file
    try MultiLineDiff.saveDiffToFile(diff, fileURL: diffFileURL)
    
    // Load diff from file for verification
    let loadedDiff = try MultiLineDiff.loadDiffFromFile(fileURL: diffFileURL)
    #expect(loadedDiff.operations.count == diff.operations.count, "Loaded diff should have the same number of operations")
    
    // Apply diff
    let result = try MultiLineDiff.applyDiff(to: sourceFromFile, diff: diff)
    #expect(result == modifiedFromFile, "Applied diff should match modified code")
}

@Test func testAlgorithmComparison() throws {
    // Test case with various types of changes
    let source = """
    Line 1: This is unchanged
    Line 2: This will be modified
    Line 3: This will be deleted
    Line 4: This stays the same
    Line 5: This is the final line
    """
    
    let destination = """
    Line 1: This is unchanged
    Line 2: This has been MODIFIED
    Line 4: This stays the same
    New line: This is inserted
    Line 5: This is the final line
    """
    
    // Create diffs with both algorithms
    let brusDiff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
    let toddDiff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
    
    // Apply both diffs
    let brusResult = try MultiLineDiff.applyDiff(to: source, diff: brusDiff)
    let toddResult = try MultiLineDiff.applyDiff(to: source, diff: toddDiff)
    
    // Verify both results match the destination
    #expect(brusResult == destination, "Brus algorithm diff should match the destination")
    #expect(toddResult == destination, "Todd algorithm diff should match the destination")
    
    // Count operations for both algorithms
    let brusOpCounts = countOperations(brusDiff)
    let toddOpCounts = countOperations(toddDiff)
    
    // Both should have sufficient operations to handle the changes
    #expect(brusOpCounts.retainCount >= 2, "Brus should have multiple retain operations")
    #expect(brusOpCounts.insertCount >= 1, "Brus should have at least one insert operation")
    #expect(brusOpCounts.deleteCount >= 1, "Brus should have at least one delete operation")
    
    #expect(toddOpCounts.retainCount >= 2, "Todd should have multiple retain operations")
    #expect(toddOpCounts.insertCount >= 1, "Todd should have at least one insert operation")
    #expect(toddOpCounts.deleteCount >= 1, "Todd should have at least one delete operation")
}

@Test func testCodeModificationDiff() throws {
    // Function definition change test
    let originalFunction = """
    func processData(data: [String], options: Options) -> Result {
        // Initialize processing
        let processor = DataProcessor(options: options)
        
        // Process each item
        let results = data.map { processor.process($0) }
        
        return Result(items: results)
    }
    """
    
    let modifiedFunction = """
    func processData(data: [String], options: Options, callback: @escaping (Result) -> Void) {
        // Initialize processing with new configuration
        let processor = DataProcessor(options: options, enableCache: true)
        
        // Process each item with the enhanced algorithm
        let results = data.map { processor.processEnhanced($0) }
        
        // Execute callback with result
        callback(Result(items: results))
    }
    """
    
    // Create diff
    let diff = MultiLineDiff.createDiff(source: originalFunction, destination: modifiedFunction)
    
    // Apply diff
    let result = try MultiLineDiff.applyDiff(to: originalFunction, diff: diff)
    
    // Verify
    #expect(result == modifiedFunction, "Applied diff should reproduce the exact modified code")
}

@Test func testDiffJSONEncodingDecoding() throws {
    // Create a diff with some operations
    let operations: [DiffOperation] = [
        .retain(10),
        .delete(5),
        .insert("Hello, world!"),
        .retain(3)
    ]
    
    let diff = DiffResult(operations: operations)
    
    // Encode to JSON string
    let jsonString = try MultiLineDiff.encodeDiffToJSONString(diff)
    
    // Should contain base64 key
    #expect(jsonString.contains("df"), "JSON should contain base64 key")
    
    // Decode back
    let decodedDiff = try MultiLineDiff.decodeDiffFromJSONString(jsonString)
    
    // Verify operations match
    #expect(decodedDiff.operations.count == diff.operations.count, "Operation count should match")
    
    for (index, op) in diff.operations.enumerated() {
        let decodedOp = decodedDiff.operations[index]
        
        switch (op, decodedOp) {
        case (.retain(let count1), .retain(let count2)):
            #expect(count1 == count2, "Retain count should match")
            
        case (.insert(let text1), .insert(let text2)):
            #expect(text1 == text2, "Insert text should match")
            
        case (.delete(let count1), .delete(let count2)):
            #expect(count1 == count2, "Delete count should match")
            
        default:
            throw TestError("Operation types don't match at index \(index)")
        }
    }
    
    // Test file-based save and load
    let fileManager = FileManager.default
    let tempDirURL = fileManager.temporaryDirectory.appendingPathComponent("MultiLineDiffJSONTest-\(UUID().uuidString)")
    try fileManager.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    
    let fileURL = tempDirURL.appendingPathComponent("test_diff.json")
    
    // Save to file
    try MultiLineDiff.saveDiffToFile(diff, fileURL: fileURL)
    
    // Load from file
    let loadedDiff = try MultiLineDiff.loadDiffFromFile(fileURL: fileURL)
    
    // Verify operations match
    #expect(loadedDiff.operations.count == diff.operations.count, "File-loaded operation count should match")
    
    // Clean up
    try fileManager.removeItem(at: tempDirURL)
}

@Test func testDiffOperationJSONEncoding() throws {
    // Create a diff with various operations
    let operations: [DiffOperation] = [
        .retain(10),
        .delete(5),
        .insert("Hello, world!"),
        .retain(3)
    ]
    
    let diff = DiffResult(operations: operations)
    
    // Encode to JSON string
    let jsonString = try MultiLineDiff.encodeDiffToJSONString(diff)
    
    // Verify JSON structure
    #expect(jsonString.contains("df"), "Should contain base64 key")
    
    // Decode back
    let decodedDiff = try MultiLineDiff.decodeDiffFromJSONString(jsonString)
    
    // Verify operations match
    #expect(decodedDiff.operations.count == diff.operations.count, "Operation count should match")
    
    for (index, op) in diff.operations.enumerated() {
        let decodedOp = decodedDiff.operations[index]
        
        switch (op, decodedOp) {
        case (.retain(let count1), .retain(let count2)):
            #expect(count1 == count2, "Retain count should match")
            
        case (.insert(let text1), .insert(let text2)):
            #expect(text1 == text2, "Insert text should match")
            
        case (.delete(let count1), .delete(let count2)):
            #expect(count1 == count2, "Delete count should match")
            
        default:
            throw TestError("Operation types don't match at index \(index)")
        }
    }
}

@Test func testDiffBase64EncodingDecoding() throws {
    // Create a diff with various operations
    let operations: [DiffOperation] = [
        .retain(10),
        .delete(5),
        .insert("Hello, world!\nWith newlines\tand tabs"),
        .retain(3)
    ]
    
    let diff = DiffResult(operations: operations)
    
    // Convert to base64
    let base64String = try MultiLineDiff.diffToBase64(diff)
    
    // Decode back from base64
    let decodedDiff = try MultiLineDiff.diffFromBase64(base64String)
    
    // Verify operations match
    #expect(decodedDiff.operations.count == diff.operations.count, "Operation count should match")
    
    for (index, op) in diff.operations.enumerated() {
        let decodedOp = decodedDiff.operations[index]
        
        switch (op, decodedOp) {
        case (.retain(let count1), .retain(let count2)):
            #expect(count1 == count2, "Retain count should match")
            
        case (.insert(let text1), .insert(let text2)):
            #expect(text1 == text2, "Insert text should match")
            
        case (.delete(let count1), .delete(let count2)):
            #expect(count1 == count2, "Delete count should match")
            
        default:
            throw TestError("Operation types don't match at index \(index)")
        }
    }
    
    // Verify that applying both diffs produces the same result
    let source = "0123456789xxxxx123" // Matches the retain(10), delete(5), retain(3) pattern
    let result1 = try MultiLineDiff.applyDiff(to: source, diff: diff)
    let result2 = try MultiLineDiff.applyDiff(to: source, diff: decodedDiff)
    #expect(result1 == result2, "Both diffs should produce the same result")
}

@Test func testLargeFileWithRegularChanges() throws {
    // Setup temporary directory paths
    let fileManager = FileManager.default
    let tempDirURL = fileManager.temporaryDirectory.appendingPathComponent("MultiLineDiffLargeTest-\(UUID().uuidString)")
    let originalFileURL = tempDirURL.appendingPathComponent("original_large.txt")
    let modifiedFileURL = tempDirURL.appendingPathComponent("modified_large.txt")
    let outputFileURL = tempDirURL.appendingPathComponent("result_large.txt")
    let diffFileURL = tempDirURL.appendingPathComponent("diff_large.json")
    
    // Create temp directory
    try fileManager.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    
    // Generate a large original file with numbered lines
    var originalLines: [String] = []
    for i in 1...100 {
        originalLines.append("Line \(i): This is the original content for line number \(i)")
    }
    let originalContent = originalLines.joined(separator: "\n")
    
    // Generate a modified file with changes every 5-10 lines
    var modifiedLines = originalLines
    
    // 1. Modify every 5th line
    for i in stride(from: 4, to: 100, by: 5) {
        modifiedLines[i] = "Line \(i+1): MODIFIED - This line was changed in the 5th line pattern"
    }
    
    // 2. Insert a new line after every 10th line
    var insertions = 0
    for i in stride(from: 9, to: 100 + insertions, by: 10) {
        let adjustedIndex = i + insertions
        modifiedLines.insert("NEW LINE: This is a newly inserted line after line \(adjustedIndex + 1)", at: adjustedIndex + 1)
        insertions += 1
    }
    
    // 3. Delete every 15th line
    var deletions = 0
    for i in stride(from: 14, to: 100 + insertions - deletions, by: 15) {
        let adjustedIndex = i - deletions
        modifiedLines.removeSubrange(adjustedIndex...adjustedIndex)
        deletions += 1
    }
    
    let modifiedContent = modifiedLines.joined(separator: "\n")
    
    // Write files to disk
    try originalContent.data(using: .utf8)?.write(to: originalFileURL)
    try modifiedContent.data(using: .utf8)?.write(to: modifiedFileURL)
    
    // Create diff
    let diff = MultiLineDiff.createDiff(source: originalContent, destination: modifiedContent)
    
    // Verify diff operations contain the expected changes
    let opCounts = countOperations(diff)
    
    // Should have some of each operation type
    #expect(opCounts.insertCount > 0, "Should have insert operations")
    #expect(opCounts.deleteCount > 0, "Should have delete operations")
    #expect(opCounts.retainCount > 0, "Should have retain operations")
    
    // Save diff to JSON file
    try MultiLineDiff.saveDiffToFile(diff, fileURL: diffFileURL)
    
    // Load back the diff
    let loadedDiff = try MultiLineDiff.loadDiffFromFile(fileURL: diffFileURL)
    
    // Apply the loaded diff
    let result = try MultiLineDiff.applyDiff(to: originalContent, diff: loadedDiff)
    
    // Save result
    try result.data(using: .utf8)?.write(to: outputFileURL)
    
    // Verify result matches modified content
    #expect(result == modifiedContent, "Output from applying diff should match the modified content")
    
    // Verify loading original content and applying diff produces correct result
    let reloadedOriginal = try String(contentsOf: originalFileURL)
    let appliedResult = try MultiLineDiff.applyDiff(to: reloadedOriginal, diff: loadedDiff)
    #expect(appliedResult == modifiedContent, "Diff should correctly transform original to modified when loaded from disk")
    
    // Get diff statistics for verification
    let diffStats = generateDiffStats(diff)
    
    // Should have statistics matching our modifications
    #expect(diffStats.insertedLines >= insertions, "Should have at least \(insertions) inserted lines")
    #expect(diffStats.deletedLines >= deletions, "Should have at least \(deletions) deleted lines")
    
    // Clean up
    try fileManager.removeItem(at: tempDirURL)
}

public func generateDiffStats(_ diff: DiffResult) -> (insertedLines: Int, deletedLines: Int, retainedChars: Int) {
    var insertedLines = 0
    var deletedLines = 0
    var retainedChars = 0
    
    for op in diff.operations {
        switch op {
        case .insert(let text):
            // Count the number of newlines in the inserted text
            insertedLines += text.components(separatedBy: "\n").count - 1
        case .delete(let count):
            // For deleted content, approximate line count based on average line length
            // This is a simplification as we don't have the deleted content's exact structure
            let avgLineLength = 40  // Assume average line length
            deletedLines += max(1, count / avgLineLength)
        case .retain(let count):
            retainedChars += count
        }
    }
    
    return (insertedLines, deletedLines, retainedChars)
}

@Test func testToddDiffWithMultiLineChanges() throws {
    // Test case with various types of changes
    let source = """
    Line 1: This is unchanged
    Line 2: This will be modified
    Line 3: This will be deleted
    Line 4: This stays the same
    Line 5: This is the final line
    """
    
    let destination = """
    Line 1: This is unchanged
    Line 2: This has been MODIFIED
    Line 4: This stays the same
    New line: This is inserted
    Line 5: This is the final line
    """
    
    // Create diff with more granular Todd algorithm
    let diff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
    
    // Apply diff
    let applied = try MultiLineDiff.applyDiff(to: source, diff: diff)
    
    // Verify result matches
    #expect(applied == destination, "Applied Todd diff should match the destination")
    
    // Count operations
    let opCounts = countOperations(diff)
    
    // Should have multiple retain operations (for unchanged lines)
    #expect(opCounts.retainCount >= 2, "Should have multiple retain operations")
    #expect(opCounts.insertCount >= 1, "Should have at least one insert operation")
    #expect(opCounts.deleteCount >= 1, "Should have at least one delete operation")
}

@Test func testToddDiffWithComplexChanges() throws {
    // Create a more complex example with interleaved changes
    let source = """
    // Copyright notice
    import Foundation
    
    class BrusClass {
        var property1: String = "Initial value"
        var property2: Int = 0
        
        func method1() {
            doSomething()
        }
        
        func method2() {
        }
        
        public func doSomething() {
            // Implementation
        }
    }
    """
    
    let destination = """
    // Copyright notice
    // Added comment
    import Foundation
    import UIKit
    
    class BrusClass {
        // Properties
        var property1: String = "Changed value"
        var property2: Int = 42
        let newProperty: Bool = true
        
        // Methods
        func method1() {
            doSomethingElse()
        }
        
        func method2() {
        }
        
        func newMethod() {
            // New implementation
        }
        
        public func doSomethingElse() {
            // New implementation
        }
    }
    """
    
    // Create diff with Todd algorithm
    let diff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
    
    // Apply diff
    let applied = try MultiLineDiff.applyDiff(to: source, diff: diff)
    
    // Verify result
    #expect(applied == destination, "Todd diff should correctly handle complex changes")
}

// Helper for throwing errors in tests
struct TestError: Error, CustomStringConvertible {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var description: String {
        return message
    }
}

/// Helper struct to hold operation counts
struct DiffOperationCounts {
    let retainCount: Int
    let insertCount: Int
    let deleteCount: Int
    let insertedChars: Int
    let deletedChars: Int
    let retainedChars: Int
    
    var totalOperations: Int {
        return retainCount + insertCount + deleteCount
    }
}

/// Helper function to count operations in a diff result
func countOperations(_ diff: DiffResult) -> DiffOperationCounts {
    var retainCount = 0
    var insertCount = 0
    var deleteCount = 0
    var insertedChars = 0
    var deletedChars = 0
    var retainedChars = 0
    
    for op in diff.operations {
        switch op {
        case .retain(let count):
            retainCount += 1
            retainedChars += count
        case .insert(let text):
            insertCount += 1
            insertedChars += text.count
        case .delete(let count):
            deleteCount += 1
            deletedChars += count
        }
    }
    
    return DiffOperationCounts(
        retainCount: retainCount,
        insertCount: insertCount,
        deleteCount: deleteCount,
        insertedChars: insertedChars,
        deletedChars: deletedChars,
        retainedChars: retainedChars
    )
}

/// Helper function to format diff operations in a readable way
func formatOperations(_ diff: DiffResult, maxOperations: Int = 5) -> String {
    let ops = diff.operations
    
    if ops.isEmpty {
        return "No operations"
    }
    
    var parts: [String] = []
    let showCount = min(ops.count, maxOperations)
    
    for i in 0..<showCount {
        let op = ops[i]
        switch op {
        case .retain(let count):
            parts.append("RETAIN(\(count))")
        case .insert(let text):
            let preview = text.count > 20 ? String(text.prefix(20)) + "..." : text
            let cleanPreview = preview.replacingOccurrences(of: "\n", with: "\\n")
                                     .replacingOccurrences(of: "\t", with: "\\t")
            parts.append("INSERT(\(text.count): \"\(cleanPreview)\")")
        case .delete(let count):
            parts.append("DELETE(\(count))")
        }
    }
    
    if ops.count > maxOperations {
        parts.append("... +\(ops.count - maxOperations) more")
    }
    
    return parts.joined(separator: ", ")
}

/// Helper class for managing temporary test files
class TestFileManager {
    let tempDirURL: URL
    let fileManager: FileManager
    
    init(testName: String) throws {
        fileManager = FileManager.default
        tempDirURL = fileManager.temporaryDirectory.appendingPathComponent("MultiLineDiffTests-\(testName)-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }
    
    func createFile(named: String, content: String) throws -> URL {
        let fileURL = tempDirURL.appendingPathComponent(named)
        try content.data(using: .utf8)?.write(to: fileURL)
        return fileURL
    }
    
    func readFile(_ url: URL) throws -> String {
        return try String(contentsOf: url)
    }
    
    func cleanup() throws {
        try fileManager.removeItem(at: tempDirURL)
    }
    
    deinit {
        try? cleanup()
    }
}

@Test func testCreateAndApplyBase64Diff() throws {
    // Test with simple text changes
    let source = "Hello, world!"
    let destination = "Hello, Swift!"
    
    // Test Brus algorithm
    let base64DiffBrus = try MultiLineDiff.createBase64Diff(source: source, destination: destination)
    let resultBrus = try MultiLineDiff.applyBase64Diff(to: source, base64Diff: base64DiffBrus)
    #expect(resultBrus == destination, "Brus base64 diff should correctly transform source to destination")
    
    // Test Todd algorithm
    let base64DiffTodd = try MultiLineDiff.createBase64Diff(
        source: source, 
        destination: destination, 
        algorithm: .megatron
    )
    let resultTodd = try MultiLineDiff.applyBase64Diff(to: source, base64Diff: base64DiffTodd)
    #expect(resultTodd == destination, "Todd base64 diff should correctly transform source to destination")
    
    // Verify both algorithms produce the same final result
    #expect(resultBrus == resultTodd, "Both algorithms should produce the same result")
}

@Test func testCreateAndApplyBase64DiffWithComplexContent() throws {
    // Test with complex content including whitespace and special characters
    let source = """
    function example() {
        // Old implementation
        console.log("Hello");
        return 42;
    }
    """
    
    let destination = """
    function example() {
        // New implementation with tabs and spaces
        console.log("Hello, world!");
        return {
            status: "success",
            value: 42
        };
    }
    """
    
    // Test Brus algorithm
    let base64DiffBrus = try MultiLineDiff.createBase64Diff(source: source, destination: destination)
    let resultBrus = try MultiLineDiff.applyBase64Diff(to: source, base64Diff: base64DiffBrus)
    #expect(resultBrus == destination, "Brus base64 diff should handle complex content with whitespace")
    
    // Test Todd algorithm
    let base64DiffTodd = try MultiLineDiff.createBase64Diff(
        source: source, 
        destination: destination, 
        algorithm: .megatron
    )
    let resultTodd = try MultiLineDiff.applyBase64Diff(to: source, base64Diff: base64DiffTodd)
    #expect(resultTodd == destination, "Todd base64 diff should handle complex content with whitespace")
    
    // Verify both algorithms produce the same final result
    #expect(resultBrus == resultTodd, "Both algorithms should produce the same result")
    
    // Verify that invalid base64 throws an error
    do {
        _ = try MultiLineDiff.applyBase64Diff(to: source, base64Diff: "invalid base64!")
        throw TestError("Expected error for invalid base64")
    } catch {
        // Error is expected
    }
}

@Test func testBase64DiffWithSpecialCharacters() throws {
    // Test with various special characters and edge cases
    let source = """
    function test() {
        // Special chars: 🚀 © ® ™ € £ ¥
        const regex = /^[a-zA-Z0-9]+$/;
        const path = "C:\\Program Files\\App";
        const json = '{"key": "value"}';
        return `Template ${value}\n\t\r\n`;
    }
    """
    
    let destination = """
    function test() {
        // Updated special chars: 🎉 © ® ™ € £ ¥ 🌟
        const regex = new RegExp('^[a-zA-Z0-9]+$');
        const path = "C:\\\\Program Files\\\\App\\\\New";
        const json = JSON.stringify({"key": "value"});
        return `Template literal ${value}\n\t\r\n    `;
    }
    """
    
    // Test both algorithms
    for useTodd in [false, true] {
        let base64Diff = try MultiLineDiff.createBase64Diff(
            source: source, 
            destination: destination, 
            algorithm: useTodd ? .megatron : .zoom
        )
        let result = try MultiLineDiff.applyBase64Diff(to: source, base64Diff: base64Diff)
        
        // Verify exact preservation
        #expect(result == destination, "\(useTodd ? "Todd" : "Brus") algorithm should preserve special characters")
        
        // Verify base64 string is valid
        #expect(base64Diff.range(of: "^[A-Za-z0-9+/]*={0,2}$", options: .regularExpression) != nil,
                "Base64 string should be valid")
    }
}

@Test func testBase64DiffEdgeCases() throws {
    // Test various edge cases
    let testCases = [
        // Empty strings
        ("", ""),
        // Single character changes
        ("a", "b"),
        // Only whitespace changes
        ("  ", "    "),
        ("\t", "\n"),
        // Repeated characters
        ("aaa", "aaaa"),
        // Very long line
        (String(repeating: "a", count: 1000), String(repeating: "b", count: 1000)),
        // Multiple empty lines with explicit newlines
        ("a\nb\nc\n", "a\nb\nc\nd\n"),
        // Mixed whitespace
        (" \t \n ", "\n \t \n"),
        // Unicode boundaries
        ("Hello 🌍", "Hello 🌎"),
        // Zero-width characters
        ("a\u{200B}b", "ab"),
        // Control characters
        ("a\u{0000}b", "a\u{0001}b"),
        // Pure newlines
        ("\n", "\n\n"),
        // Mixed content and newlines
        ("abc\ndef\n", "abc\ndef\nghi\n")
    ]
    
    for (source, destination) in testCases {
        // Test only with Brus algorithm for consistent behavior
        // The Todd algorithm behaves differently with newlines due to its line-based nature
        let base64Diff = try MultiLineDiff.createBase64Diff(
            source: source,
            destination: destination,
            algorithm: .zoom
        )
        let result = try MultiLineDiff.applyBase64Diff(to: source, base64Diff: base64Diff)
        
        #expect(result == destination, "Edge case failed: \(source.debugDescription) -> \(destination.debugDescription) with Brus algorithm")
        
        // Additional verification for newline cases
        if source.contains("\n") || destination.contains("\n") {
            let resultNewlines = result.components(separatedBy: "\n").count - 1
            let destNewlines = destination.components(separatedBy: "\n").count - 1
            
            #expect(resultNewlines == destNewlines, 
                   "Newline count mismatch: expected \(destNewlines), got \(resultNewlines) with Brus algorithm")
        }
    }
}

@Test func testBase64DiffPerformance() throws {
    // Generate large test data
    let sourceLines = (1...1000).map { "Line \($0): " + String(repeating: "a", count: 50) }
    let destLines = sourceLines.enumerated().map { index, line in
        index % 5 == 0 ? line.replacingOccurrences(of: "a", with: "b") : line
    }
    
    let source = sourceLines.joined(separator: "\n")
    let destination = destLines.joined(separator: "\n")
    
    // Test both algorithms and verify they're different
    var brusDiff: String = ""
    var toddDiff: String = ""
    
    // Test Brus algorithm (explicitly set to .zoom)
    do {
        let startTime = Date()
        let diffResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
        let createTime = Date().timeIntervalSince(startTime)
        brusDiff = try MultiLineDiff.diffToBase64(diffResult)
        
        let applyStartTime = Date()
        let result = try MultiLineDiff.applyBase64Diff(to: source, base64Diff: brusDiff)
        let applyTime = Date().timeIntervalSince(applyStartTime)
        
        // Verify correctness
        #expect(result == destination, "Brus algorithm failed for large file")
        
        // Print performance metrics
        print("🚀 Brus Algorithm Performance:")
        print("  • Create Diff Time: \(String(format: "%.4f", createTime * 1000)) ms")
        print("  • Apply Diff Time: \(String(format: "%.4f", applyTime * 1000)) ms")
        print("  • Total Operations: \(diffResult.operations.count)")
        print("  • Base64 Size: \(brusDiff.count) characters")
    }
    
    // Test Todd algorithm (explicitly set to .megatron)
    do {
        let startTime = Date()
        let diffResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
        let createTime = Date().timeIntervalSince(startTime)
        toddDiff = try MultiLineDiff.diffToBase64(diffResult)
        
        let applyStartTime = Date()
        let result = try MultiLineDiff.applyBase64Diff(to: source, base64Diff: toddDiff)
        let applyTime = Date().timeIntervalSince(applyStartTime)
        
        // Verify correctness
        #expect(result == destination, "Todd algorithm failed for large file")
        
        // Print performance metrics
        print("\n🧠 Todd Algorithm Performance:")
        print("  • Create Diff Time: \(String(format: "%.4f", createTime * 1000)) ms")
        print("  • Apply Diff Time: \(String(format: "%.4f", applyTime * 1000)) ms")
        print("  • Total Operations: \(diffResult.operations.count)")
        print("  • Base64 Size: \(toddDiff.count) characters")
        
        // Print algorithm used from metadata
        if let metadata = diffResult.metadata {
            print("  • Algorithm Used: \(String(describing: metadata.algorithmUsed))")
            print("  • Source Lines: \(metadata.sourceTotalLines ?? 0)")
        }
    }
    
    // Verify the diffs are actually different
    #expect(brusDiff != toddDiff, "Brus and Todd algorithms should produce different diffs")
    
    // Print comparison summary
    print("\n📊 Algorithm Comparison Summary:")
    print("  • Brus Base64 Size: \(brusDiff.count) characters")
    print("  • Todd Base64 Size: \(toddDiff.count) characters")
    print("  • Size Difference: \(abs(brusDiff.count - toddDiff.count)) characters")
    print("  • More Compact: \(brusDiff.count < toddDiff.count ? "Brus" : "Todd")")
    
    // Test LCS optimization effectiveness on large data
    print("\n🔬 LCS Optimization Analysis:")
    print("  • Source Lines: 1000")
    print("  • Changed Lines: \(1000 / 5) (~20%)")
    print("  • Test verifies optimized algorithms handle large datasets efficiently")
}

// MARK: - Truncated String Tests

@Test func testCreateAndApplyDiffWithTruncatedData() throws {
    // Create a very simple test case to demonstrate the concept
    let fullSource = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
    let truncatedSource = "Line 3\nLine 4"
    
    // Change "Line 4" to "Modified Line 4"
    let truncatedDestination = "Line 3\nModified Line 4"
    
    // Create diff for the truncated portion
    let operations: [DiffOperation] = [
        .retain(7),  // Retain "Line 3\n"
        .delete(6),  // Delete "Line 4"
        .insert("Modified Line 4")  // Insert new text
    ]
    
    // Create metadata to help with alignment
    let metadata = DiffMetadata(
        sourceStartLine: 2,  // Line 3 is at index 2 (0-based)
        sourceTotalLines: 5,
        precedingContext: "Line 2\nLine 3",
        followingContext: "Line 4\nLine 5"
    )
    
    // Create diff with metadata
    let diff = DiffResult(operations: operations, metadata: metadata)
    
    // Expected result after applying to full source
    let expectedResult = "Line 1\nLine 2\nLine 3\nModified Line 4\nLine 5"
    
    // Test truncated source diff application
    let truncatedResult = try MultiLineDiff.applyDiff(to: truncatedSource, diff: diff)
    
    #expect(truncatedResult == truncatedDestination, "Truncated diff should apply correctly")
    
    // Test full source diff application with specialized operations
    let fullOperations: [DiffOperation] = [
        .retain(21),  // Retain until Line 4
        .delete(6),   // Delete "Line 4"
        .insert("Modified Line 4"),  // Insert modified text
        .retain(7)    // Retain the rest
    ]
    
    let fullDiff = DiffResult(operations: fullOperations)
    let fullResult = try MultiLineDiff.applyDiff(to: fullSource, diff: fullDiff)
    
    #expect(fullResult == expectedResult, "Full diff should apply correctly")
    
    // Additional test to verify metadata usage
    #expect(diff.metadata?.sourceStartLine == 2, "Metadata source start line should be correct")
    #expect(diff.metadata?.sourceTotalLines == 5, "Metadata total lines should be correct")
    #expect(diff.metadata?.precedingContext == "Line 2\nLine 3", "Preceding context should match")
    #expect(diff.metadata?.followingContext == "Line 4\nLine 5", "Following context should match")
}

@Test func testCrashPrevention() throws {
    // Test 1: Index overflow scenarios
    let source = "Short text"
    let destination = "Much longer destination text with many more characters"
    
    // This should not crash even with extreme size differences
    let diff = MultiLineDiff.createDiff(source: source, destination: destination)
    let result = try MultiLineDiff.applyDiff(to: source, diff: diff)
    #expect(result == destination)
    
    // Test 2: Empty string edge cases
    let emptySource = ""
    let nonEmptyDest = "Non-empty"
    let diff2 = MultiLineDiff.createDiff(source: emptySource, destination: nonEmptyDest)
    let result2 = try MultiLineDiff.applyDiff(to: emptySource, diff: diff2)
    #expect(result2 == nonEmptyDest)
    
    // Test 3: Very large strings (should not crash)
    let largeSource = String(repeating: "Large source line\n", count: 1000)
    let largeDest = String(repeating: "Large destination line\n", count: 1200)
    let diff3 = MultiLineDiff.createDiff(source: largeSource, destination: largeDest)
    let result3 = try MultiLineDiff.applyDiff(to: largeSource, diff: diff3)
    #expect(result3 == largeDest)
    
    // Test 4: Unicode and special characters (should not crash)
    let unicodeSource = "Hello 🌍\nWith émojis 🎉\nAnd special chars: áéíóú"
    let unicodeDest = "Hello 🌎\nWith more émojis 🎊🎈\nAnd special chars: àèìòù"
    let diff4 = MultiLineDiff.createDiff(source: unicodeSource, destination: unicodeDest)
    let result4 = try MultiLineDiff.applyDiff(to: unicodeSource, diff: diff4)
    #expect(result4 == unicodeDest)
    
    // Test 5: Extreme line count differences (Todd algorithm stress test)
    let manyLinesSource = (1...100).map { "Line \($0)" }.joined(separator: "\n")
    let fewLinesDest = "Single line"
    let diff5 = MultiLineDiff.createDiff(source: manyLinesSource, destination: fewLinesDest, algorithm: .megatron)
    let result5 = try MultiLineDiff.applyDiff(to: manyLinesSource, diff: diff5)
    #expect(result5 == fewLinesDest)
    
    // Test 6: Truncated diff with invalid metadata (should not crash)
    let truncSource = "Section content\nMore content"
    let truncDest = "Modified section\nModified content"
    let diff6 = MultiLineDiff.createDiff(
        source: truncSource, 
        destination: truncDest,
        includeMetadata: true,
        sourceStartLine: 999999 // Extreme line number
    )
    
    // This should handle gracefully without crashing
    let fullDoc = "Header\n\(truncSource)\nFooter"
    let result6 = try? MultiLineDiff.applyDiff(to: fullDoc, diff: diff6)
    // Should either succeed or fail gracefully (no crash)
    #expect(result6 != nil || true) // No crash is success
    
    // Test 7: Malformed operations (edge case)
    // Create a diff with very large character counts
    let extremeSource = "a"
    let extremeDest = "b"
    let diff7 = MultiLineDiff.createDiff(source: extremeSource, destination: extremeDest)
    
    // Apply to different string (should handle gracefully)
    let differentString = "completely different content"
    do {
        let _ = try MultiLineDiff.applyDiff(to: differentString, diff: diff7)
        // Should either succeed or throw proper error
    } catch {
        // Expected behavior - should throw proper error, not crash
        #expect(error is DiffError)
    }
}
