//
//  MultiLineDiff+SwiftNativeLineConverter.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//

extension MultiLineDiff {
    
    /// Line-based Swift Native converter using commonPrefix/commonSuffix on lines
    @_optimize(speed)
    internal static func createDiffUsingSwiftNativeLines(
        source: String,
        destination: String
    ) -> DiffResult {
        
        // Fast paths
        if source == destination {
            return source.isEmpty ? DiffResult(operations: []) : DiffResult(operations: [.retain(source.count)])
        }
        
        if source.isEmpty {
            return DiffResult(operations: destination.isEmpty ? [] : [.insert(destination)])
        }
        
        if destination.isEmpty {
            return DiffResult(operations: [.delete(source.count)])
        }
        
        // Split into lines (preserving line endings) - optimized for speed
        let sourceLines = source.efficientLines
        let destLines = destination.efficientLines
        
        // Use CollectionDifference directly like Todd for same operation count
        let difference = destLines.difference(from: sourceLines)
        
        if difference.isEmpty {
            let totalChars = sourceLines.reduce(0) { $0 + $1.count }
            return DiffResult(operations: [.retain(totalChars)])
        }
        
        // Convert to operations using the same approach as Todd but optimized
        return convertLineDifferenceToOperationsOptimized(difference, sourceLines: Array(sourceLines), destLines: Array(destLines))
    }
    

    
    /// Fast and detailed line-based approach with fine-grained operations
    @_optimize(speed)
    internal static func createDiffUsingSwiftNativeLinesWithDifference(
        source: String,
        destination: String
    ) -> DiffResult {
        
        // Fast paths
        if source == destination {
            return source.isEmpty ? DiffResult(operations: []) : DiffResult(operations: [.retain(source.count)])
        }
        
        if source.isEmpty {
            return DiffResult(operations: destination.isEmpty ? [] : [.insert(destination)])
        }
        
        if destination.isEmpty {
            return DiffResult(operations: [.delete(source.count)])
        }
        
        // Split into lines (preserving line endings) - optimized for speed
        let sourceLines = source.efficientLines
        let destLines = destination.efficientLines
        
        // Use CollectionDifference directly like Todd for same operation count
        let difference = destLines.difference(from: sourceLines)
        
        if difference.isEmpty {
            let totalChars = sourceLines.reduce(0) { $0 + $1.count }
            return DiffResult(operations: [.retain(totalChars)])
        }
        
        // Convert to operations using the same approach as Todd but optimized
        return convertLineDifferenceToOperationsOptimized(difference, sourceLines: Array(sourceLines), destLines: Array(destLines))
    }
    

    
    /// Convert line-based CollectionDifference to character-based DiffOperations (optimized)
    @_optimize(speed)
    private static func convertLineDifferenceToOperationsOptimized(
        _ difference: CollectionDifference<Substring>,
        sourceLines: [Substring],
        destLines: [Substring]
    ) -> DiffResult {
        
        if difference.isEmpty {
            let totalChars = sourceLines.reduce(0) { $0 + $1.count }
            return DiffResult(operations: [.retain(totalChars)])
        }
        
        // Pre-allocate arrays for better performance
        var removedLines = Array(repeating: false, count: sourceLines.count)
        var insertedLines = Array(repeating: false, count: destLines.count)
        
        // Mark removed and inserted lines in one pass
        for change in difference {
            switch change {
            case .remove(let offset, _, _):
                if offset < removedLines.count {
                    removedLines[offset] = true
                }
            case .insert(let offset, _, _):
                if offset < insertedLines.count {
                    insertedLines[offset] = true
                }
            }
        }
        
        // Process lines efficiently with pre-allocated operations array
        var operations: [DiffOperation] = []
        operations.reserveCapacity(sourceLines.count + destLines.count) // Pre-allocate
        
        var sourceIndex = 0
        var destIndex = 0
        
        while sourceIndex < sourceLines.count || destIndex < destLines.count {
            if sourceIndex < sourceLines.count && removedLines[sourceIndex] {
                // Delete this source line
                operations.append(.delete(sourceLines[sourceIndex].count))
                sourceIndex += 1
            } else if destIndex < destLines.count && insertedLines[destIndex] {
                // Insert this destination line
                operations.append(.insert(String(destLines[destIndex])))
                destIndex += 1
            } else if sourceIndex < sourceLines.count && destIndex < destLines.count {
                // Retain this line (it's common)
                operations.append(.retain(sourceLines[sourceIndex].count))
                sourceIndex += 1
                destIndex += 1
            } else if sourceIndex < sourceLines.count {
                // Delete remaining source lines
                operations.append(.delete(sourceLines[sourceIndex].count))
                sourceIndex += 1
            } else if destIndex < destLines.count {
                // Insert remaining destination lines
                operations.append(.insert(String(destLines[destIndex])))
                destIndex += 1
            }
        }
        
        // Consolidate consecutive operations
        return DiffResult(operations: consolidateLineOperations(operations))
    }
    

    
    /// Consolidate consecutive operations for line-based processing
    @_optimize(speed)
    private static func consolidateLineOperations(_ operations: [DiffOperation]) -> [DiffOperation] {
        guard !operations.isEmpty else { return [] }
        
        var consolidated: [DiffOperation] = []
        var current = operations[0]
        
        for i in 1..<operations.count {
            let next = operations[i]
            
            switch (current, next) {
            case (.retain(let count1), .retain(let count2)):
                current = .retain(count1 + count2)
            case (.delete(let count1), .delete(let count2)):
                current = .delete(count1 + count2)
            case (.insert(let text1), .insert(let text2)):
                current = .insert(text1 + text2)
            default:
                consolidated.append(current)
                current = next
            }
        }
        
        consolidated.append(current)
        return consolidated
    }
    
    /// Public method for line-based Swift native approach (prefix/suffix)
    @_optimize(speed)
    public static func createDiffUsingSwiftNativeLinesMethods(
        source: String,
        destination: String
    ) -> DiffResult {
        return createDiffUsingSwiftNativeLines(source: source, destination: destination)
    }
    
    /// Public method for line-based Swift native approach (difference)
    @_optimize(speed)
    public static func createDiffUsingSwiftNativeLinesWithDifferenceMethods(
        source: String,
        destination: String
    ) -> DiffResult {
        return createDiffUsingSwiftNativeLinesWithDifference(source: source, destination: destination)
    }
} 
