//
//  EnhancedLineOperation.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//

import Foundation
import CommonCrypto

#if canImport(CryptoKit)
import CryptoKit
#endif

extension MultiLineDiff {
    
    /// Enhanced algorithm execution with intelligent selection and verification
//    internal static func executeEnhancedAlgorithm(
//        algorithm: DiffAlgorithm,
//        source: String,
//        destination: String
//    ) -> (DiffResult, DiffAlgorithm) {
//        switch algorithm {
//        case .zoom:
//            return (createEnhancedBrusDiff(source: source, destination: destination), .zoom)
//        case .megatron:
//            return executeEnhancedToddWithFallback(source: source, destination: destination)
//        }
//    }
    
    /// Enhanced Todd algorithm with intelligent fallback
//    internal static func executeEnhancedToddWithFallback(
//        source: String,
//        destination: String
//    ) -> (DiffResult, DiffAlgorithm) {
//        // Try enhanced Todd algorithm
//        let toddResult = createEnhancedToddDiff(source: source, destination: destination)
//        
//        // Verify the Todd result by applying it
//        do {
//            let appliedResult = try applyDiff(to: source, diff: toddResult)
//            if appliedResult == destination {
//                return (toddResult, .megatron)
//            } else {
//                print("Todd similarity: \(DiffAlgorithmCore.AlgorithmSelector.calculateSimilarity(source: appliedResult, destination: destination)) < 0.98, falling back to Brus")
//                // Fallback to enhanced Brus
//                return (createEnhancedBrusDiff(source: source, destination: destination), .zoom)
//            }
//        } catch {
//            print("Todd algorithm failed with error: \(error), falling back to Brus")
//            // Fallback to enhanced Brus
//            return (createEnhancedBrusDiff(source: source, destination: destination), .zoom)
//        }
//    }
    
    /// Enhanced Brus algorithm using Swift 6.1 features
    @_optimize(speed)
    internal static func createEnhancedBrusDiff(source: String, destination: String) -> DiffResult {
        // Handle empty string scenarios first
        if let emptyResult = handleEmptyStrings(source: source, destination: destination) {
            return emptyResult
        }
        
        // Use enhanced common regions detection
        let regions = DiffAlgorithmCore.EnhancedCommonRegions(source: source, destination: destination)
        var builder = DiffAlgorithmCore.OperationBuilder()
        
        // Build operations using enhanced operation builder
        if regions.prefixLength > 0 {
            builder.addRetain(count: regions.prefixLength)
        }
        
        if !regions.sourceMiddleRange.isEmpty {
            builder.addDelete(count: regions.sourceMiddleRange.count)
        }
        
        if !regions.destMiddleRange.isEmpty {
            let destMiddleText = regions.destMiddle(from: destination)
            builder.addInsert(text: destMiddleText)
        }
        
        if regions.suffixLength > 0 {
            builder.addRetain(count: regions.suffixLength)
        }
        
        return DiffResult(operations: builder.build())
    }
    
    /// Enhanced Todd algorithm using Swift 6.1 LCS and line processing with performance optimizations
    @_optimize(speed)
    internal static func createEnhancedToddDiff(source: String, destination: String) -> DiffResult {
        // Handle empty strings
        if let emptyResult = handleEmptyStrings(source: source, destination: destination) {
            return emptyResult
        }
        
        // Use Swift 6.1 enhanced line processing
        let sourceLines = source.efficientLines
        let destLines = destination.efficientLines
        
        // Detect if original strings end with newlines - this is crucial for proper character counting
        let sourceEndsWithNewline = source.hasSuffix("\n")
        let destEndsWithNewline = destination.hasSuffix("\n")
        
        // Only use simple diff for very tiny content (1-2 lines each)
        if sourceLines.count <= 1 && destLines.count <= 1 {
            return createSimpleLineDiff(sourceLines: sourceLines, destLines: destLines, sourceEndsWithNewline: sourceEndsWithNewline, destEndsWithNewline: destEndsWithNewline)
        }
        
        // Use optimized LCS for semantic line-by-line processing
        let lcsOperations = ToddsDiffAlg(sourceLines: sourceLines, destLines: destLines)
        
        // OPTIMIZATION: Work directly with lines, no character conversion!
        return createDiffFromLineOperations(
            lcsOperations: lcsOperations,
            sourceLines: sourceLines,
            destLines: destLines,
            sourceEndsWithNewline: sourceEndsWithNewline,
            destEndsWithNewline: destEndsWithNewline
        )
    }
    
    /// Create diff directly from line operations (preserves line-by-line granularity)
    @_optimize(speed)
    internal static func createDiffFromLineOperations(
        lcsOperations: [EnhancedLineOperation],
        sourceLines: [Substring],
        destLines: [Substring],
        sourceEndsWithNewline: Bool,
        destEndsWithNewline: Bool
    ) -> DiffResult {
        var builder = DiffAlgorithmCore.OperationBuilder()
        
        // Convert each line operation individually (preserving granularity)
        for operation in lcsOperations {
            switch operation {
            case .retain(let i):
                // SAFETY: Bounds checking to prevent crashes
                guard i >= 0 && i < sourceLines.count else {
                    // Skip invalid retain operations instead of crashing
                    continue
                }
                // Lines now include newlines, so use the exact character count
                let line = sourceLines[i]
                builder.addRetain(count: line.count)
                
            case .delete(let i):
                // SAFETY: Bounds checking to prevent crashes
                guard i >= 0 && i < sourceLines.count else {
                    // Skip invalid delete operations instead of crashing
                    continue
                }
                // Lines now include newlines, so use the exact character count
                let line = sourceLines[i]
                builder.addDelete(count: line.count)
                
            case .insert(let i):
                // SAFETY: Bounds checking to prevent crashes
                guard i >= 0 && i < destLines.count else {
                    // Skip invalid insert operations instead of crashing
                    continue
                }
                // Lines now include newlines, so use the exact text
                let line = destLines[i]
                builder.addInsert(text: String(line))
            }
        }
        
        return DiffResult(operations: builder.build())
    }
    
    /// Fast path for small line diffs (preserves line-by-line granularity)
    @_optimize(speed)
    internal static func createSimpleLineDiff(sourceLines: [Substring], destLines: [Substring], sourceEndsWithNewline: Bool, destEndsWithNewline: Bool) -> DiffResult {
        var builder = DiffAlgorithmCore.OperationBuilder()
        var srcIdx = 0, dstIdx = 0
        
        while srcIdx < sourceLines.count || dstIdx < destLines.count {
            if srcIdx < sourceLines.count && dstIdx < destLines.count && sourceLines[srcIdx] == destLines[dstIdx] {
                // Lines match - retain (lines now include newlines)
                let line = sourceLines[srcIdx]
                builder.addRetain(count: line.count)
                srcIdx += 1
                dstIdx += 1
            } else if srcIdx < sourceLines.count && (dstIdx >= destLines.count || sourceLines[srcIdx] != destLines[dstIdx]) {
                // Delete source line (lines now include newlines)
                let line = sourceLines[srcIdx]
                builder.addDelete(count: line.count)
                srcIdx += 1
            } else if dstIdx < destLines.count {
                // Insert destination line (lines now include newlines)
                let line = destLines[dstIdx]
                builder.addInsert(text: String(line))
                dstIdx += 1
            }
        }
        
        return DiffResult(operations: builder.build())
    }
    
    /// Swift built-in difference algorithm
    @_optimize(speed)
    internal static func ToddsDiffAlg(sourceLines: [Substring], destLines: [Substring]) -> [EnhancedLineOperation] {
        let S = sourceLines.count
        let D = destLines.count
        
        // Handle edge cases
        if S == 0 || D == 0 {
            return handleEmptyCases(srcCount: S, dstCount: D)
        }
        
        
        // Use Swift's built-in optimized difference algorithm
        let difference = destLines.difference(from: sourceLines)
        
        // Pre-allocate operations array for better performance
        var operations: [EnhancedLineOperation] = []
        operations.reserveCapacity(S + D)
        
        // Create removal and insertion tracking arrays (faster than Set for small collections)
        var isRemoved = Array(repeating: false, count: S)
        var isInserted = Array(repeating: false, count: D)
        
        // Mark removals and insertions in O(changes) time with bounds checking
        for change in difference {
            switch change {
            case .remove(let offset, _, _):
                // SAFETY: Bounds checking to prevent crashes
                if offset >= 0 && offset < S { 
                    isRemoved[offset] = true 
                }
            case .insert(let offset, _, _):
                // SAFETY: Bounds checking to prevent crashes
                if offset >= 0 && offset < D { 
                    isInserted[offset] = true 
                }
            }
        }
        
        // Single optimized pass with bounds checking
        var sourceIndex = 0
        var destIndex = 0
        
        while sourceIndex < S || destIndex < D {
            // SAFETY: Additional bounds checking for all array accesses
            if sourceIndex < S && sourceIndex < isRemoved.count && isRemoved[sourceIndex] {
                operations.append(.delete(sourceIndex))
                sourceIndex += 1
            } else if destIndex < D && destIndex < isInserted.count && isInserted[destIndex] {
                operations.append(.insert(destIndex))
                destIndex += 1
            } else if sourceIndex < S && destIndex < D {
                operations.append(.retain(sourceIndex))
                sourceIndex += 1
                destIndex += 1
            } else if sourceIndex < S {
                operations.append(.delete(sourceIndex))
                sourceIndex += 1
            } else if destIndex < D {
                operations.append(.insert(destIndex))
                destIndex += 1
            } else {
                // SAFETY: Break if we somehow get into an invalid state
                break
            }
        }
        
        return operations
    }
    
    /// Handle empty cases without any loops
    internal static func handleEmptyCases(srcCount: Int, dstCount: Int) -> [EnhancedLineOperation] {
        if srcCount == 0 && dstCount == 0 {
            return []
        } else if srcCount == 0 {
            return (0..<dstCount).map { .insert($0) }
        } else {
            return (0..<srcCount).map { .delete($0) }
        }
    }
    
    /// Enhanced line operation for internal processing
    internal enum EnhancedLineOperation {
        case retain(Int)  // Line index in source
        case delete(Int)  // Line index in source
        case insert(Int)  // Line index in destination
    }
    
    /// Generate enhanced metadata using Swift 6.1 features
    @_optimize(speed)
    internal static func generateEnhancedMetadata(
        result: DiffResult,
        source: String,
        destination: String,
        actualAlgorithm: DiffAlgorithm,
        sourceStartLine: Int?,
        destStartLine: Int?
    ) -> DiffResult {
        let sourceLines = source.efficientLines
        
        // Enhanced context generation
        let contextLength = 30
        let precedingContext = source.prefix(Swift.min(contextLength, source.count)).description
        let followingContext = source.suffix(Swift.min(contextLength, source.count)).description
        
        // Store both source and destination content for verification and undo operations
        let sourceContent = source
        let destinationContent = destination
        
        // Auto-detect application type based on metadata characteristics
        let applicationType = DiffMetadata.autoDetectApplicationType(
            sourceStartLine: sourceStartLine,
            precedingContext: precedingContext,
            followingContext: followingContext,
            sourceContent: sourceContent
        )
        
        // Create temporary metadata without hash
        let tempMetadata = DiffMetadata(
            sourceStartLine: sourceStartLine,
            sourceTotalLines: sourceLines.count,
            precedingContext: precedingContext,
            followingContext: followingContext,
            sourceContent: sourceContent,
            destinationContent: destinationContent,
            algorithmUsed: actualAlgorithm,
            diffHash: nil,
            applicationType: applicationType,
            diffGenerationTime: nil
        )
        
        let tempResult = DiffResult(operations: result.operations, metadata: tempMetadata)
        
        // Generate SHA256 hash of the base64 diff
        let diffHash = generateDiffHash(for: tempResult)
        
        // Create final metadata with hash
        let finalMetadata = DiffMetadata(
            sourceStartLine: sourceStartLine,
            sourceTotalLines: sourceLines.count,
            precedingContext: precedingContext,
            followingContext: followingContext,
            sourceContent: sourceContent,
            destinationContent: destinationContent,
            algorithmUsed: actualAlgorithm,
            diffHash: diffHash,
            applicationType: applicationType,
            diffGenerationTime: nil
        )
        
        return DiffResult(operations: result.operations, metadata: finalMetadata)
    }
    
    /// Generate SHA256 hash of the base64 encoded diff for integrity verification
    @_optimize(speed)
    internal static func generateDiffHash(for diff: DiffResult) -> String {
        do {
            // Get base64 representation of the diff
            let base64Diff = try diffToBase64(diff)
            
            // Calculate SHA256 hash of the base64 string
            let data = Data(base64Diff.utf8)
            
            // Use CryptoKit
            let hash = SHA256.hash(data: data)
            return hash.compactMap { String(format: "%02x", $0) }.joined()

        } catch {
            // Fallback to deterministic hash based on content if base64 fails
            return generateFallbackHash(for: diff)
        }
    }
    
    /// Cross-platform SHA256 implementation using CommonCrypto
    @_optimize(speed)
    internal static func sha256HashUsingCommonCrypto(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Generate a fallback hash based on diff operations for extreme edge cases
    @_optimize(speed)
    internal static func generateFallbackHash(for diff: DiffResult) -> String {
        var hashComponents: [String] = []
        
        // Include operation signatures
        for operation in diff.operations {
            switch operation {
            case .retain(let count):
                hashComponents.append("r\(count)")
            case .insert(let text):
                hashComponents.append("i\(text.count):\(text.hashValue)")
            case .delete(let count):
                hashComponents.append("d\(count)")
            }
        }
        
        // Create deterministic hash from operation signatures
        let signature = hashComponents.joined(separator: "|")
        let data = Data(signature.utf8)
        return sha256HashUsingCommonCrypto(data: data)
    }
}
