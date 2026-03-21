// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import CommonCrypto

#if canImport(CryptoKit)
import CryptoKit
#endif

// MultiLineDiff - A library for creating and applying diffs to multi-line text
// Supports Unicode/UTF-8 strings and handles multi-line content properly

/// Represents a single diff operation with three core transformation types
/// 
/// DiffOperation is the fundamental building block for describing text transformations.
/// It supports three primary operations: retain, insert, and delete.
///
/// - `retain`: Keeps existing characters from the source text
/// - `insert`: Adds new content not present in the source
/// - `delete`: Removes characters from the source text
///
/// # Performance Characteristics
/// - Constant-time operation creation O(1)
/// - Memory-efficient value type
/// - Supports Unicode and multi-line text
///
/// # Example
/// ```swift
/// let diff: [DiffOperation] = [
///     .retain(5),        // Keep first 5 characters
///     .delete(3),        // Remove next 3 characters
///     .insert("Swift")   // Insert "Swift"
/// ]
/// ```

/// The main entry point for the MultiLineDiff library
@frozen public enum MultiLineDiff {
    /// Creates a diff between two strings using advanced diffing algorithms
    ///
    /// This method provides a flexible and powerful way to generate diff operations
    /// that transform one text into another. It supports two primary algorithms:
    /// Brus (fast, O(n)) and Todd (semantic, O(n log n)).
    ///
    /// # Algorithms
    /// - `.zoom`: Optimized for simple, character-level changes
    ///   - Fastest performance
    ///   - Best for minimal text modifications
    ///   - O(n) time complexity
    ///
    /// - `.megatron`: Semantic diff with deeper analysis
    ///   - More intelligent change detection
    ///   - Preserves structural context
    ///   - O(n log n) time complexity
    ///
    /// # Features
    /// - Unicode/UTF-8 support
    /// - Metadata generation with source verification
    /// - Flexible line number tracking
    /// - Automatic truncated source detection
    ///
    /// # Example
    /// ```swift
    /// let source = "Hello, world!"
    /// let destination = "Hello, Swift!"
    ///
            /// // Default Megatron algorithm with source verification
    /// let diff = MultiLineDiff.createDiff(
    ///     source: source,
    ///     destination: destination
    /// )
    ///
    /// // Apply diff (automatically detects full vs truncated source)
    /// let result = try MultiLineDiff.applyDiff(to: someSource, diff: diff)
    /// ```
    ///
    /// - Parameters:
    ///   - source: The original text to transform from
    ///   - destination: The target text to transform to
    ///   - algorithm: Diff generation strategy (defaults to semantic Megatron algorithm)
    ///   - includeMetadata: Whether to generate additional context information
    ///   - sourceStartLine: Optional starting line number for precise tracking
    ///   - destStartLine: Optional destination starting line number
    ///
    /// - Returns: A `DiffResult` containing transformation operations with source verification metadata
    public static func createDiff(
        source: String,
        destination: String,
        algorithm: DiffAlgorithm = .megatron,
        includeMetadata: Bool = true,
        sourceStartLine: Int? = nil,
        destStartLine: Int? = nil
    ) -> DiffResult {
        
        let result : DiffResult
        
        switch algorithm {
        case .megatron:
            result = createEnhancedToddDiff(source: source, destination: destination)
        case .zoom:
            result = createEnhancedBrusDiff(source: source, destination: destination)
        case .flash:
            result = createDiffUsingSwiftNativeMethods(source: source, destination: destination)
        case .starscream:
            result = createDiffUsingSwiftNativeLinesMethods(source: source, destination: destination)
        case .optimus:
            result = createDiffUsingSwiftNativeLinesWithDifferenceMethods(source: source, destination: destination)
        case .aigenerated:
            result = createEnhancedToddDiff(source: source, destination: destination) // Use megatron as base
        }

        // If metadata isn't needed, return the result as is
        guard includeMetadata else {
            return result
        }
        
        // Generate enhanced metadata for the diff (includes source content for verification)
        return generateEnhancedMetadata(
            result: result,
            source: source,
            destination: destination,
            actualAlgorithm: algorithm,
            sourceStartLine: sourceStartLine,
            destStartLine: destStartLine
        )
    }
    
    // MARK: - Base64 and Encoding Methods
    
    /// Creates a base64 encoded diff between two strings
    /// - Parameters:
    ///   - source: The original string
    ///   - destination: The modified string
    ///   - algorithm: The diff algorithm to use (default: Megatron)
    ///   - includeMetadata: Whether to include metadata in the diff result
    ///   - sourceStartLine: The line number where the source string starts (0-indexed)
    ///   - destStartLine: The line number where the destination string starts (0-indexed)
    /// - Returns: A base64 encoded string representing the diff operations
    /// - Throws: An error if encoding fails
    public static func createBase64Diff(
        source: String,
        destination: String,
        algorithm: DiffAlgorithm = .megatron,
        includeMetadata: Bool = true,
        sourceStartLine: Int? = nil,
        destStartLine: Int? = nil
    ) throws -> String {
        // Create diff with the explicitly requested algorithm
        let diff = createDiff(
            source: source,
            destination: destination,
            algorithm: algorithm,
            includeMetadata: includeMetadata,
            sourceStartLine: sourceStartLine,
            destStartLine: destStartLine
        )
        return try diffToBase64(diff)
    }
        
    /// Enhanced diff application using Swift 6.1 features
    /// - Parameters:
    ///   - source: The original string
    ///   - diff: The diff to apply
    ///   - allowTruncatedSource: Whether to allow applying diff to truncated source string
    /// - Returns: The resulting string after applying the diff
    /// - Throws: An error if the diff cannot be applied correctly
    public static func applyDiff(
        to source: String,
        diff: DiffResult
    ) throws -> String {
        // Handle empty operations case explicitly
        if diff.operations.isEmpty {
            return source
        }
    
        let allowTruncated = shouldAllowTruncatedSource(for: source, diff: diff)

        // Use enhanced string processing for diff application
        let result = try applyDiffWithEnhancedProcessing(
            source: source,
            operations: diff.operations,
            metadata: diff.metadata,
            allowTruncatedSource: allowTruncated
        )
        
        try performSmartVerification(source: source, result: result, diff: diff)
        return result
    }
    
    /// Applies a base64 encoded diff to a source string
    /// - Parameters:
    ///   - source: The original string
    ///   - base64Diff: The base64 encoded diff to apply
    ///   - allowTruncatedSource: Whether to allow applying diff to truncated source string
    /// - Returns: The resulting string after applying the diff
    /// - Throws: An error if decoding or applying the diff fails
    public static func applyBase64Diff(
        to source: String,
        base64Diff: String,
        allowTruncatedSource: Bool = false
    ) throws -> String {
        let diff = try diffFromBase64(base64Diff)
        return try applyDiff(to: source, diff: diff)
    }
    
    /// Creates a diff in the specified encoding
    /// - Parameters:
    ///   - source: The original text
    ///   - destination: The modified text
    ///   - algorithm: Diff generation strategy (defaults to semantic Megatron algorithm)
    ///   - encoding: The desired encoding format for the diff
    ///   - includeMetadata: Whether to generate additional context information
    ///   - sourceStartLine: Optional starting line number for precise tracking
    ///   - destStartLine: Optional destination starting line number
    /// - Returns: The diff in the specified encoding
    /// - Throws: An error if encoding fails
    public static func createEncodedDiff(
        source: String,
        destination: String,
        algorithm: DiffAlgorithm = .megatron,
        encoding: DiffEncoding = .base64,
        includeMetadata: Bool = true,
        sourceStartLine: Int? = nil,
        destStartLine: Int? = nil
    ) throws -> Any {
        // Create the base diff result
        let diff = createDiff(
            source: source,
            destination: destination,
            algorithm: algorithm,
            includeMetadata: includeMetadata,
            sourceStartLine: sourceStartLine,
            destStartLine: destStartLine
        )
        
        // Encode based on the specified format
        switch encoding {
        case .base64:
            return try diffToBase64(diff)
        case .jsonString:
            return try encodeDiffToJSONString(diff)
        case .jsonData:
            let jsonString = try encodeDiffToJSONString(diff)
            return jsonString.data(using: .utf8) ?? Data()
        }
    }
    
    /// Enhanced diff application with Swift 6.1 optimizations
    @_optimize(speed)
    private static func applyDiffWithEnhancedProcessing(
        source: String,
        operations: [DiffOperation],
        metadata: DiffMetadata?,
        allowTruncatedSource: Bool
    ) throws -> String {
        // Check if this is a section diff that needs special handling using explicit metadata
        if allowTruncatedSource, 
           let metadata = metadata,
           metadata.applicationType == .requiresTruncatedSource {
            
            // Try to find and apply the diff to a specific section
            if let sectionResult = try applySectionDiff(
                fullSource: source,
                operations: operations,
                metadata: metadata
            ) {
                return sectionResult
            }
        }
        
        // Apply operations to source string
        return try processOperationsOnSource(
            source: source,
            operations: operations,
            allowTruncatedSource: allowTruncatedSource
        )
    }
    
    /// Apply a section diff to a full document by finding the appropriate section using both preceding and following context
    private static func applySectionDiff(
        fullSource: String,
        operations: [DiffOperation],
        metadata: DiffMetadata
    ) throws -> String? {
        guard let precedingContext = metadata.precedingContext,
              !precedingContext.isEmpty else {
            return nil
        }
        
        let fullLines = fullSource.efficientLines
        let sourceLineCount = metadata.sourceTotalLines ?? 3
        
        // Find the best matching section
        guard let sectionRange = findBestMatchingSection(
            fullLines: fullLines,
            metadata: metadata,
            sourceLineCount: sourceLineCount
        ) else {
            return nil
        }
        
        // Apply diff to the matched section and reconstruct document
        return try reconstructDocumentWithModifiedSection(
            fullLines: fullLines,
            sectionRange: sectionRange,
            operations: operations
        )
    }
    
    /// Applies an encoded diff to a source string
    /// - Parameters:
    ///   - source: The original string
    ///   - encodedDiff: The encoded diff to apply
    ///   - encoding: The encoding type of the diff
    ///   - allowTruncatedSource: Whether to allow applying diff to truncated source string
    /// - Returns: The resulting string after applying the diff
    /// - Throws: An error if decoding or applying the diff fails
    public static func applyEncodedDiff(
        to source: String,
        encodedDiff: Any,
        encoding: DiffEncoding,
        allowTruncatedSource: Bool = false
    ) throws -> String {
        let diff = try decodeEncodedDiff(encodedDiff: encodedDiff, encoding: encoding)
        return try applyDiff(to: source, diff: diff)
    }
    
    // MARK: - Display and Formatting Methods
    
    /// Display format options for diff output
    public enum DiffDisplayFormat {
        case terminal    // Colored terminal output with ANSI codes
        case ai          // Plain ASCII output suitable for AI models
    }
    
    /// Displays a diff result in the specified format
    /// 
    /// This method provides a convenient way to format diff results for different
    /// output contexts. Terminal format includes ANSI color codes for visual
    /// distinction, while AI format provides clean ASCII output suitable for
    /// sending to AI models or plain text environments.
    ///
    /// # Format Examples
    /// 
         /// **Terminal Format:**
     /// ```swift
     /// 📎 class UserManager {
     /// ❌     private var users: [String: User] = [:]
     /// ✅     private var users: [String: User] = [:]
     /// ✅     private var userCount: Int = 0
     /// ```
    /// 
         /// **AI Format:**
     /// ```swift
     /// 📎 class UserManager {
     /// ❌     private var users: [String: User] = [:]
     /// ✅     private var users: [String: User] = [:]
     /// ✅     private var userCount: Int = 0
     /// ```
    ///
    /// - Parameters:
    ///   - diff: The diff result to display
    ///   - source: The original source string
    ///   - format: The display format (.terminal or .ai)
    /// - Returns: A formatted string representation of the diff
    public static func displayDiff(
        diff: DiffResult,
        source: String,
        format: DiffDisplayFormat
    ) -> String {
        switch format {
        case .terminal:
            return TerminalDiffFormatter.generateColoredTerminalDiff(from: diff, sourceText: source)
        case .ai:
            return TerminalDiffFormatter.generateASCIIDiff(from: diff, sourceText: source)
        }
    }
    
    /// Creates and displays a diff between two strings in one convenient call
    /// 
    /// This is a convenience method that combines `createDiff` and `displayDiff`
    /// into a single operation. Perfect for quick diff generation and display.
    ///
    /// # Usage Examples
    /// 
    /// **For AI models:**
    /// ```swift
    /// let diffOutput = MultiLineDiff.createAndDisplayDiff(
    ///     source: oldCode,
    ///     destination: newCode,
    ///     format: .ai
    /// )
    /// // Send diffOutput to AI model
    /// ```
    /// 
    /// **For terminal display:**
    /// ```swift
    /// let coloredDiff = MultiLineDiff.createAndDisplayDiff(
    ///     source: oldCode,
    ///     destination: newCode,
    ///     format: .terminal
    /// )
    /// print(coloredDiff)
    /// ```
    ///
    /// - Parameters:
    ///   - source: The original text to transform from
    ///   - destination: The target text to transform to
    ///   - format: The display format (.terminal or .ai)
    ///   - algorithm: Diff generation strategy (defaults to semantic Megatron algorithm)
    /// - Returns: A formatted string representation of the diff
    public static func createAndDisplayDiff(
        source: String,
        destination: String,
        format: DiffDisplayFormat,
        algorithm: DiffAlgorithm = .megatron
    ) -> String {
        let diff = createDiff(
            source: source,
            destination: destination,
            algorithm: algorithm,
            includeMetadata: false  // Display doesn't need metadata
        )
        
        return displayDiff(
            diff: diff,
            source: source,
            format: format
        )
    }
    
    // MARK: - ASCII Diff Parsing Methods
    
    /// Parses ASCII diff text back into a DiffResult
    /// 
    /// This method allows AI models and users to submit diffs in a readable ASCII format
    /// using emoji diff prefixes:
    /// - `\(DiffSymbols.retain)` for retained content (unchanged lines)
    /// - `\(DiffSymbols.delete)` for deleted content (removed from source)
    /// - `\(DiffSymbols.insert)` for inserted content (added to destination)
    ///
    /// # Format Examples
    /// 
    /// **Input ASCII Diff:**
    /// ```swift
    /// 📎 class UserManager {
    /// 📎     private var users: [String: User] = [:]
    /// ✅     private var userCount: Int = 0
    /// 📎     
    /// ❌     func addUser(name: String, email: String) -> Bool {
    /// ✅     func addUser(name: String, email: String, age: Int = 0) -> Result<User, UserError> {
    /// 📎         guard !name.isEmpty && !email.isEmpty else {
    /// ❌             return false
    /// ✅             return .failure(.invalidInput)
    /// 📎         }
    /// 📎 }
    /// ```
    ///
    /// **Output:** A `DiffResult` with operations that can be applied to recreate the changes
    ///
    /// # Usage Examples
    /// 
    /// **Parse AI-submitted diff:**
    /// ```swift
    /// let aiDiffText = """
    /// 📎 func greet() {
    /// ❌     print("Hello")
    /// ✅     print("Hello, World!")
    /// 📎 }
    /// """
    /// 
    /// let diffResult = try MultiLineDiff.parseDiffFromASCII(aiDiffText)
    /// let result = try MultiLineDiff.applyDiff(to: sourceCode, diff: diffResult)
    /// ```
    ///
    /// - Parameter asciiDiff: The ASCII diff text with 📎, ❌, ✅ prefixes
    /// - Returns: A `DiffResult` containing the parsed diff operations
    /// - Throws: `DiffParsingError` if the ASCII diff format is invalid
    public static func parseDiffFromASCII(_ asciiDiff: String) throws -> DiffResult {
        var operations: [DiffOperation] = []
        
        var retainLines: [String] = []
        var deleteLines: [String] = []
        var insertLines: [String] = []
        
        // Flush accumulated lines into operations
        func flushOperations() {
            if !retainLines.isEmpty {
                let text = retainLines.joined(separator: "\n") + "\n"
                operations.append(.retain(text.count))
                retainLines = []
            }
            if !deleteLines.isEmpty {
                let text = deleteLines.joined(separator: "\n") + "\n"
                operations.append(.delete(text.count))
                deleteLines = []
            }
            if !insertLines.isEmpty {
                let text = insertLines.joined(separator: "\n") + "\n"
                operations.append(.insert(text))
                insertLines = []
            }
        }
        
        // Parse each line using split instead of enumerateLines to allow throwing
        let lines = asciiDiff.components(separatedBy: .newlines)
        
        for (lineNumber, line) in lines.enumerated() {
            guard !line.isEmpty else { continue }
            guard line.count >= 2 else { 
                throw DiffParsingError.invalidFormat(line: lineNumber + 1, content: line)
            }
            
            let prefix = String(line.prefix(2)) // Get "📎 ", "❌ ", or "✅ "
            let content = String(line.dropFirst(2)) // Remove prefix
            
            switch prefix {
            case "\(DiffSymbols.retain) ":
                // Flush deletes/inserts, then add to retain
                if !deleteLines.isEmpty || !insertLines.isEmpty {
                    flushOperations()
                }
                retainLines.append(content)
                
            case "\(DiffSymbols.delete) ":
                // Flush retains/inserts, then add to delete
                if !retainLines.isEmpty || !insertLines.isEmpty {
                    flushOperations()
                }
                deleteLines.append(content)
                
            case "\(DiffSymbols.insert) ":
                // Flush retains only (keep deletes for delete+insert pairs)
                if !retainLines.isEmpty {
                    let text = retainLines.joined(separator: "\n") + "\n"
                    operations.append(.retain(text.count))
                    retainLines = []
                }
                insertLines.append(content)
                
            default:
                throw DiffParsingError.invalidPrefix(line: lineNumber + 1, prefix: prefix)
            }
        }
        
        // Flush remaining operations
        flushOperations()
        
        // Adjust final operation to remove trailing newline
        if !operations.isEmpty {
            let lastIndex = operations.count - 1
            switch operations[lastIndex] {
            case .retain(let count):
                operations[lastIndex] = .retain(max(0, count - 1))
            case .delete(let count):
                operations[lastIndex] = .delete(max(0, count - 1))
            case .insert(let text):
                operations[lastIndex] = .insert(text.hasSuffix("\n") ? String(text.dropLast()) : text)
            }
        }
        
        // Reconstruct source and modified strings from the parsed lines
        var sourceLines: [String] = []
        var modifiedLines: [String] = []
        var sourceStartLine: Int? = nil
        var currentLineNumber = 0
        
        // Re-parse the ASCII diff to capture the strings and find first insert
        let diffLines = asciiDiff.components(separatedBy: .newlines)
        for line in diffLines {
            guard !line.isEmpty, line.count >= 2 else { continue }
            
            let prefix = String(line.prefix(2))
            let content = String(line.dropFirst(2))
            
            switch prefix {
            case "\(DiffSymbols.retain) ":
                sourceLines.append(content)
                modifiedLines.append(content)
                currentLineNumber += 1
            case "\(DiffSymbols.delete) ":
                // First delete or insert marks where modifications start
                if sourceStartLine == nil {
                    sourceStartLine = currentLineNumber
                }
                sourceLines.append(content)
                currentLineNumber += 1
            case "\(DiffSymbols.insert) ":
                // First delete or insert marks where modifications start
                if sourceStartLine == nil {
                    sourceStartLine = currentLineNumber
                }
                modifiedLines.append(content)
            default:
                continue
            }
        }
        
        let sourceString = sourceLines.joined(separator: "\n")
        let modifiedString = modifiedLines.joined(separator: "\n")
        
        // Extract preceding and following context (first and last lines)
        let precedingContext = sourceLines.first
        let followingContext = sourceLines.last
        
        return DiffResult(
            operations: operations,
            metadata: DiffMetadata(
                sourceStartLine: sourceStartLine,
                sourceTotalLines: sourceLines.count,
                precedingContext: precedingContext,
                followingContext: followingContext,
                sourceContent: sourceString,
                destinationContent: modifiedString,
                algorithmUsed: .megatron,
                applicationType: .requiresFullSource
            )
        )
    }
    
    /// Convenience method that parses ASCII diff and applies it to source text in one call
    /// 
    /// This method combines `parseDiffFromASCII` and `applyDiff` for easy AI integration.
    ///
    /// # Usage Examples
    /// 
    /// **AI workflow:**
    /// ```swift
    /// let aiSubmittedDiff = """
    /// 📎 func calculate() -> Int {
    /// ❌     return 42
    /// ✅     return 100
    /// 📎 }
    /// """
    /// 
    /// let result = try MultiLineDiff.applyASCIIDiff(
    ///     to: sourceCode,
    ///     asciiDiff: aiSubmittedDiff
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - source: The original source text to apply the diff to
    ///   - asciiDiff: The ASCII diff text with 📎, ❌, ✅ prefixes
    /// - Returns: The resulting text after applying the parsed diff
    /// - Throws: `DiffParsingError` or `DiffApplicationError` if parsing or application fails
    public static func applyASCIIDiff(
        to source: String,
        asciiDiff: String
    ) throws -> String {
        let diffResult = try parseDiffFromASCII(asciiDiff)
        return try applyDiff(to: source, diff: diffResult)
    }
    
    // MARK: - ASCII Diff Workflow Demonstration
    
    /// Demonstrates the complete ASCII diff workflow: create → display → parse → apply
    /// 
    /// This method shows the full round-trip process that proves ASCII diff parsing works:
    /// 1. Creates a diff between source and destination
    /// 2. Displays the diff in ASCII format
    /// 3. Parses the ASCII diff back into operations
    /// 4. Applies the parsed diff to the original source
    /// 5. Verifies the result matches the destination
    ///
    /// # Usage Example
    /// ```swift
    /// let source = "func greet() {\n    print(\"Hello\")\n}"
    /// let destination = "func greet() {\n    print(\"Hello, World!\")\n}"
    /// 
    /// let demo = try MultiLineDiff.demonstrateASCIIWorkflow(
    ///     source: source,
    ///     destination: destination
    /// )
    /// 
    /// print("ASCII Diff:")
    /// print(demo.asciiDiff)
    /// print("Result matches destination: \(demo.success)")
    /// ```
    ///
    /// - Parameters:
    ///   - source: The original text
    ///   - destination: The target text
    ///   - algorithm: The diff algorithm to use (default: .megatron)
    /// - Returns: A demonstration result showing all steps
    /// - Throws: An error if any step fails
    public static func demonstrateASCIIWorkflow(
        source: String,
        destination: String,
        algorithm: DiffAlgorithm = .megatron
    ) throws -> ASCIIWorkflowDemo {
        print("🚀 ASCII Diff Workflow Demonstration")
        print(String(repeating: "=", count: 50))
        
        // Step 1: Create original diff
        print("📝 Step 1: Creating diff...")
        let originalDiff = createDiff(
            source: source,
            destination: destination,
            algorithm: algorithm,
            includeMetadata: false
        )
        print("   ✅ Created \(originalDiff.operations.count) operations")
        
        // Step 2: Display as ASCII
        print("📄 Step 2: Converting to ASCII format...")
        let asciiDiff = displayDiff(
            diff: originalDiff,
            source: source,
            format: .ai
        )
        print("   ✅ Generated ASCII diff (\(asciiDiff.count) characters)")
        
        // Step 3: Parse ASCII back to diff
        print("🔍 Step 3: Parsing ASCII diff...")
        let parsedDiff = try parseDiffFromASCII(asciiDiff)
        print("   ✅ Parsed \(parsedDiff.operations.count) operations")
        
        // Step 4: Apply parsed diff
        print("⚡ Step 4: Applying parsed diff...")
        let result = try applyDiff(to: source, diff: parsedDiff)
        print("   ✅ Applied diff successfully")
        
        // Step 5: Verify result
        print("🎯 Step 5: Verifying result...")
        let success = result == destination
        print("   \(success ? "✅" : "❌") Result matches destination: \(success)")
        
        if success {
            print("🎉 ASCII diff workflow completed successfully!")
        } else {
            print("❌ Workflow failed - result doesn't match destination")
            print("Expected: '\(destination)'")
            print("Got: '\(result)'")
        }
        
        return ASCIIWorkflowDemo(
            originalOperations: originalDiff.operations,
            asciiDiff: asciiDiff,
            parsedOperations: parsedDiff.operations,
            finalResult: result,
            success: success,
            algorithm: algorithm
        )
    }
    
    // MARK: - AI-Generated Diff Methods
    
    /// Creates a diff from AI-submitted ASCII diff with comprehensive metadata
    /// 
    /// This method is specifically designed for AI workflows where the AI submits
    /// an ASCII diff and we need to capture detailed metadata about where and how
    /// the patch should be applied in the larger codebase.
    ///
    /// # Metadata Captured
    /// - **Source location**: Start/end line numbers in the original file
    /// - **Context**: Preceding and following lines for patch location
    /// - **Patch details**: Number of lines affected, change summary
    /// - **AI attribution**: Uses .aigenerated algorithm type
    ///
    /// # Usage Examples
    /// 
    /// **AI submits a diff:**
    /// ```swift
    /// let aiDiff = """
    /// 📎 func calculate() -> Int {
    /// ❌     return 42
    /// ✅     return 100
    /// 📎 }
    /// """
    /// 
    /// let result = try MultiLineDiff.createAIGeneratedDiff(
    ///     originalSource: fullSourceCode,
    ///     aiSubmittedDiff: aiDiff,
    ///     contextLines: 3
    /// )
    /// 
    /// // Access rich metadata
    /// print("Patch starts at line: \(result.metadata?.sourceStartLine ?? 0)")
    /// print("Preceding context: \(result.metadata?.precedingContext ?? "")")
    /// ```
    ///
    /// - Parameters:
    ///   - originalSource: The complete original source code
    ///   - aiSubmittedDiff: The ASCII diff submitted by the AI
    ///   - contextLines: Number of context lines to capture before/after the patch
    /// - Returns: A `DiffResult` with comprehensive AI metadata
    /// - Throws: `DiffParsingError` if the AI diff format is invalid
    public static func createAIGeneratedDiff(
        originalSource: String,
        aiSubmittedDiff: String,
        contextLines: Int = 5
    ) throws -> DiffResult {
        // Parse the AI's ASCII diff
        let parsedDiff = try parseDiffFromASCII(aiSubmittedDiff)
        
        // Analyze the original source to find patch location
        let sourceLines = originalSource.efficientLines.map(String.init)
        let patchAnalysis = try analyzePatchLocation(
            sourceLines: sourceLines,
            aiDiff: aiSubmittedDiff,
            contextLines: contextLines
        )
        
        // Create enhanced metadata using existing structure
        let aiMetadata = DiffMetadata(
            sourceStartLine: patchAnalysis.startLine,
            sourceTotalLines: sourceLines.count,
            precedingContext: patchAnalysis.precedingContext,
            followingContext: patchAnalysis.followingContext,
            sourceContent: originalSource,
            destinationContent: nil, // Will be filled when diff is applied
            algorithmUsed: .aigenerated,
            diffHash: nil, // Will be generated
            applicationType: .requiresFullSource,
            diffGenerationTime: nil
        )
        
        return DiffResult(
            operations: parsedDiff.operations,
            metadata: aiMetadata
        )
    }
    
    /// Analyzes where an AI-submitted patch should be applied in the source code
    private static func analyzePatchLocation(
        sourceLines: [String],
        aiDiff: String,
        contextLines: Int
    ) throws -> PatchAnalysis {
        let diffLines = aiDiff.components(separatedBy: .newlines)
        
        // Extract the first few retain lines to find the patch location
        var retainLines: [String] = []
        var patchLineCount = 0
        var insertCount = 0
        var deleteCount = 0
        
        for line in diffLines {
            guard !line.isEmpty else { continue }
            guard line.count >= 2 else { continue }
            
            let prefix = String(line.prefix(2))
            let content = String(line.dropFirst(2))
            
            switch prefix {
            case "\(DiffSymbols.retain) ":
                retainLines.append(content)
                patchLineCount += 1
            case "\(DiffSymbols.delete) ":
                deleteCount += 1
                patchLineCount += 1
            case "\(DiffSymbols.insert) ":
                insertCount += 1
                patchLineCount += 1
            default:
                continue
            }
            
            // Stop after collecting enough retain lines to find location
            if retainLines.count >= 3 {
                break
            }
        }
        
        // Find the patch location in the source
        let startLine = findPatchStartLine(sourceLines: sourceLines, retainLines: retainLines)
        let endLine = startLine + patchLineCount - 1
        
        // Extract context
        let precedingStart = max(0, startLine - contextLines)
        let precedingEnd = max(0, startLine - 1)
        let followingStart = min(sourceLines.count, endLine + 1)
        let followingEnd = min(sourceLines.count, endLine + contextLines)
        
        let precedingContext = precedingStart <= precedingEnd ? 
            Array(sourceLines[precedingStart...precedingEnd]).joined(separator: "\n") : ""
        let followingContext = followingStart < followingEnd ? 
            Array(sourceLines[followingStart..<followingEnd]).joined(separator: "\n") : ""
        
        // Generate changes summary
        let changesSummary = generateChangesSummary(
            insertCount: insertCount,
            deleteCount: deleteCount,
            retainCount: retainLines.count
        )
        
        return PatchAnalysis(
            startLine: startLine,
            endLine: endLine,
            patchLineCount: patchLineCount,
            precedingContext: precedingContext,
            followingContext: followingContext,
            changesSummary: changesSummary
        )
    }
    
    /// Finds the starting line number where the patch should be applied
    private static func findPatchStartLine(sourceLines: [String], retainLines: [String]) -> Int {
        guard !retainLines.isEmpty else { return 0 }
        
        // Look for the sequence of retain lines in the source
        for i in 0...(sourceLines.count - retainLines.count) {
            var matches = true
            for j in 0..<retainLines.count {
                if sourceLines[i + j].trimmingCharacters(in: .whitespaces) != 
                   retainLines[j].trimmingCharacters(in: .whitespaces) {
                    matches = false
                    break
                }
            }
            if matches {
                return i
            }
        }
        
        return 0 // Default to beginning if not found
    }
    
    /// Generates a human-readable summary of the changes
    private static func generateChangesSummary(insertCount: Int, deleteCount: Int, retainCount: Int) -> String {
        var summary: [String] = []
        
        if insertCount > 0 {
            summary.append("\(insertCount) insertion\(insertCount == 1 ? "" : "s")")
        }
        if deleteCount > 0 {
            summary.append("\(deleteCount) deletion\(deleteCount == 1 ? "" : "s")")
        }
        if retainCount > 0 {
            summary.append("\(retainCount) line\(retainCount == 1 ? "" : "s") retained")
        }
        
        return summary.isEmpty ? "No changes" : summary.joined(separator: ", ")
    }
    
    /// Applies an AI-generated diff with enhanced reporting
    /// 
    /// This method provides additional reporting when applying AI-generated diffs.
    ///
    /// - Parameters:
    ///   - source: The original source code
    ///   - aiDiffResult: The AI-generated diff result with metadata
    /// - Returns: The resulting code after applying the AI diff
    /// - Throws: Standard diff application errors
    public static func applyAIGeneratedDiff(
        to source: String,
        aiDiffResult: DiffResult
    ) throws -> String {
        // Validate this is an AI-generated diff
        if let metadata = aiDiffResult.metadata,
           metadata.algorithmUsed != .aigenerated {
            print("⚠️ Warning: Diff was not marked as AI-generated")
        }
        
        // Apply the diff
        let result = try applyDiff(to: source, diff: aiDiffResult)
        
        // Log successful application if metadata is available
        if let diffMetadata = aiDiffResult.metadata {
            print("✅ AI diff applied successfully")
            if let startLine = diffMetadata.sourceStartLine {
                print("📍 Applied at line: \(startLine)")
            }
            if let totalLines = diffMetadata.sourceTotalLines {
                print("📊 Affected \(totalLines) lines")
            }
        }
        
        return result
    }
}

/// Errors that can occur during ASCII diff parsing
public enum DiffParsingError: Error, LocalizedError {
    case invalidFormat(line: Int, content: String)
    case invalidPrefix(line: Int, prefix: String)
    case emptyDiff
    
    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let line, let content):
            return "Invalid diff format at line \(line): '\(content)'"
        case .invalidPrefix(let line, let prefix):
            return "Invalid diff prefix '\(prefix)' at line \(line). Expected '📎', '❌', or '✅'"
        case .emptyDiff:
            return "Empty diff provided"
        }
    }
}

/// Analysis result for AI patch location and context
internal struct PatchAnalysis {
    let startLine: Int
    let endLine: Int
    let patchLineCount: Int
    let precedingContext: String
    let followingContext: String
    let changesSummary: String
}

/// Result of the ASCII workflow demonstration
public struct ASCIIWorkflowDemo {
    /// The original diff operations
    public let originalOperations: [DiffOperation]
    
    /// The ASCII representation of the diff
    public let asciiDiff: String
    
    /// The operations parsed back from ASCII
    public let parsedOperations: [DiffOperation]
    
    /// The final result after applying the parsed diff
    public let finalResult: String
    
    /// Whether the workflow was successful (result matches destination)
    public let success: Bool
    
    /// The algorithm used for the demonstration
    public let algorithm: DiffAlgorithm
    
    /// Summary of the demonstration
    public var summary: String {
        return """
        ASCII Diff Workflow Summary:
        - Algorithm: \(algorithm)
        - Original operations: \(originalOperations.count)
        - ASCII diff length: \(asciiDiff.count) characters
        - Parsed operations: \(parsedOperations.count)
        - Success: \(success ? "✅" : "❌")
        """
    }
}
