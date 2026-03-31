//
//  MultiLineDiffMetadata.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//

/// Represents metadata about the diff source and destination
public struct DiffMetadata: Equatable, Codable {
    // Essential location information
    public let sourceStartLine: Int?
    public let sourceTotalLines: Int?
    
    // Context for section matching
    public let precedingContext: String?
    public let followingContext: String?
    
    // Content for verification and undo operations
    public let sourceContent: String?
    public let destinationContent: String?
    
    // Algorithm and tracking
    public let algorithmUsed: DiffAlgorithm?
    public let diffHash: String?
    
    // Application type for automatic handling
    public let applicationType: DiffApplicationType?
    
    // Performance tracking (optional)
    public let diffGenerationTime: Double?
    
    // Compact 3-character keys for maximum JSON size reduction while keeping variable names unchanged
    public enum CodingKeys: String, CodingKey {
        case sourceStartLine = "str"      // Start line number
        case sourceTotalLines = "cnt"     // Total line count
        case precedingContext = "pre"     // Context before section
        case followingContext = "fol"     // Context after section
        case sourceContent = "src"        // Original source content
        case destinationContent = "dst"   // Target destination content
        case algorithmUsed = "alg"        // Algorithm used (brus/todd)
        case diffHash = "hsh"             // SHA256 integrity hash
        case applicationType = "app"      // Application type (full/truncated)
        case diffGenerationTime = "tim"   // Performance timing (optional)
    }
    
    public init(
        sourceStartLine: Int? = nil,
        sourceTotalLines: Int? = nil,
        precedingContext: String? = nil,
        followingContext: String? = nil,
        sourceContent: String? = nil,
        destinationContent: String? = nil,
        algorithmUsed: DiffAlgorithm? = nil,
        diffHash: String? = nil,
        applicationType: DiffApplicationType? = nil,
        diffGenerationTime: Double? = nil
    ) {
        self.sourceStartLine = sourceStartLine
        self.sourceTotalLines = sourceTotalLines
        self.precedingContext = precedingContext
        self.followingContext = followingContext
        self.sourceContent = sourceContent
        self.destinationContent = destinationContent
        self.algorithmUsed = algorithmUsed
        self.diffHash = diffHash
        self.applicationType = applicationType
        self.diffGenerationTime = diffGenerationTime
    }
    
    // Computed properties for derived information
    public var sourceEndLine: Int? {
        guard let start = sourceStartLine, let total = sourceTotalLines else { return nil }
        return start + total - 1
    }
    
    // Calculate operation statistics from diff operations
    public func operationStats(from operations: [DiffOperation]) -> (inserts: Int, deletes: Int, retains: Int, changePercentage: Double) {
        var insertCount = 0, deleteCount = 0, retainCount = 0
        var changedChars = 0, totalChars = 0
        
        for op in operations {
            switch op {
            case .insert(let text):
                insertCount += 1
                changedChars += text.count
            case .delete(let count):
                deleteCount += 1
                changedChars += count
                totalChars += count
            case .retain(let count):
                retainCount += 1
                totalChars += count
            }
        }
        
        let changePercentage = totalChars > 0 ? Double(changedChars) / Double(totalChars) * 100 : 0
        return (insertCount, deleteCount, retainCount, changePercentage)
    }
    
    // Convenience factory methods
    public static func forSection(startLine: Int, lineCount: Int, context: String? = nil, sourceContent: String? = nil, destinationContent: String? = nil, algorithm: DiffAlgorithm = .megatron) -> DiffMetadata {
        return DiffMetadata(
            sourceStartLine: startLine,
            sourceTotalLines: lineCount,
            precedingContext: context,
            sourceContent: sourceContent,
            destinationContent: destinationContent,
            algorithmUsed: algorithm,
            diffHash: nil, // Will be generated after diff creation
            applicationType: .requiresTruncatedSource // Explicit for section diffs
        )
    }
    
    public static func basic(sourceContent: String? = nil, destinationContent: String? = nil, algorithm: DiffAlgorithm = .megatron) -> DiffMetadata {
        return DiffMetadata(
            sourceContent: sourceContent,
            destinationContent: destinationContent,
            algorithmUsed: algorithm,
            diffHash: nil, // Will be generated after diff creation
            applicationType: .requiresFullSource // Default for basic diffs
        )
    }
    
    /// Auto-detects the application type based on metadata characteristics
    public static func autoDetectApplicationType(
        sourceStartLine: Int?,
        precedingContext: String?,
        followingContext: String?,
        sourceContent: String?
    ) -> DiffApplicationType {
        // If we have context or a non-zero start line, it's likely truncated
        if let startLine = sourceStartLine, startLine > 0 {
            return .requiresTruncatedSource
        }
        
        if precedingContext != nil || followingContext != nil {
            return .requiresTruncatedSource
        }
        
        // If we stored the source content, we can verify during application
        if sourceContent != nil {
            return .requiresTruncatedSource // Will be verified by string comparison
        }
        
        // Default to full source for simple cases
        return .requiresFullSource
    }
    
    /// Determines if the provided source requires truncated diff handling
    /// Returns true if the diff should be applied with allowTruncatedSource=true
    public static func requiresTruncatedHandling(
        providedSource: String,
        storedSource: String?
    ) -> Bool {
        guard let stored = storedSource else {
            // No stored source to compare against
            return false
        }
        
        // If provided source contains the stored source, we need truncated handling
        // (applying truncated diff to full document)
        if providedSource.contains(stored) && providedSource != stored {
            return true
        }
        
        // If they're exactly the same, no truncated handling needed
        if stored == providedSource {
            return false
        }
        
        // If stored source contains provided source, it's the opposite case
        // (applying to exactly the truncated section) - no special handling needed
        if stored.contains(providedSource) && stored != providedSource {
            return false
        }
        
        // If they're different but don't contain each other, likely need truncated handling
        if stored != providedSource {
            return true
        }
        
        // Exact match - no truncated handling needed
        return false
    }
    
    /// Verifies that applying the diff to the stored source produces the expected destination
    /// Returns true if the checksum matches, false otherwise
    public static func verifyDiffChecksum(
        diff: DiffResult,
        storedSource: String?,
        storedDestination: String?
    ) -> Bool {
        guard let source = storedSource,
              let expectedDestination = storedDestination else {
            return false // Cannot verify without stored content
        }
        
        do {
            let actualResult = try MultiLineDiff.applyDiff(to: source, diff: diff)
            return actualResult == expectedDestination
        } catch {
            return false // Diff application failed
        }
    }
    
    /// Creates an undo diff that reverses the original transformation
    /// Returns a new DiffResult that transforms destination back to source
    public static func createUndoDiff(from originalDiff: DiffResult) -> DiffResult? {
        guard let metadata = originalDiff.metadata,
              let source = metadata.sourceContent,
              let destination = metadata.destinationContent else {
            return nil // Cannot create undo without stored content
        }
        
        // Create reverse diff (destination -> source)
        let undoResult = MultiLineDiff.createDiff(
            source: destination,
            destination: source,
            algorithm: metadata.algorithmUsed ?? .megatron,
            includeMetadata: true
        )
        
        // The undo diff will get its hash generated automatically during creation
        return undoResult
    }
}

