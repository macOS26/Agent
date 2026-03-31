//
//  MultiLineDiff+SwiftNativeConverter.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//

extension MultiLineDiff {
    
    /// Ultra-fast converter using Swift's native string methods
    @_optimize(speed)
    internal static func createDiffUsingSwiftNative(
        source: String,
        destination: String
    ) -> DiffResult {
        
        // Fast path for identical strings
        if source == destination {
            return source.isEmpty ? DiffResult(operations: []) : DiffResult(operations: [.retain(source.count)])
        }
        
        // Fast path for empty strings
        if source.isEmpty {
            return DiffResult(operations: destination.isEmpty ? [] : [.insert(destination)])
        }
        if destination.isEmpty {
            return DiffResult(operations: [.delete(source.count)])
        }
        
        // Use Swift's difference to get the changes
        let difference = destination.difference(from: source)
        
        // Verify the difference is valid by applying it
        guard let applied = source.applying(difference), applied == destination else {
            // Fallback to our previous method if applying fails
            return createDiffFromCollectionDifference(source: source, destination: destination)
        }
        
        // Convert difference to operations using a much simpler approach
        return convertDifferenceToOperations(difference, source: source, destination: destination)
    }
    
    /// Convert CollectionDifference to DiffOperations using Swift's native methods
    @_optimize(speed)
    private static func convertDifferenceToOperations(
        _ difference: CollectionDifference<Character>,
        source: String,
        destination: String
    ) -> DiffResult {
        
        // If no changes, just retain everything
        if difference.isEmpty {
            return DiffResult(operations: [.retain(source.count)])
        }
        
        var operations: [DiffOperation] = []
        var currentIndex = 0
        
        // Group changes by position for more efficient processing
        var changes: [(offset: Int, change: CollectionDifference<Character>.Change)] = []
        for change in difference {
            switch change {
            case .remove(let offset, _, _):
                changes.append((offset, change))
            case .insert(let offset, _, _):
                changes.append((offset, change))
            }
        }
        
        // Sort changes by offset
        changes.sort { $0.offset < $1.offset }
        
        // Process changes in order
        for (_, change) in changes {
            switch change {
            case .remove(let removeOffset, _, _):
                // Add retain for characters before this removal
                if removeOffset > currentIndex {
                    operations.append(.retain(removeOffset - currentIndex))
                }
                // Add delete operation
                operations.append(.delete(1))
                currentIndex = removeOffset + 1
                
            case .insert(_, let char, _):
                // For insertions, we need to handle them relative to the destination
                // Add insert operation
                operations.append(.insert(String(char)))
            }
        }
        
        // Add final retain for remaining characters
        if currentIndex < source.count {
            operations.append(.retain(source.count - currentIndex))
        }
        
        // Consolidate consecutive operations
        return DiffResult(operations: consolidateConsecutiveOperations(operations))
    }
    
    /// Even simpler approach: use string manipulation directly
    @_optimize(speed)
    internal static func createDiffUsingStringManipulation(
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
        
        // Find common prefix
        let prefixLength = source.commonPrefix(with: destination).count
        
        // Find common suffix (avoiding overlap with prefix)
        let sourceAfterPrefix = String(source.dropFirst(prefixLength))
        let destAfterPrefix = String(destination.dropFirst(prefixLength))
        
        let suffixLength = sourceAfterPrefix.commonSuffix(with: destAfterPrefix)
        
        // Calculate middle sections
        let sourceMiddle = String(sourceAfterPrefix.dropLast(suffixLength))
        let destMiddle = String(destAfterPrefix.dropLast(suffixLength))
        
        // Build operations
        var operations: [DiffOperation] = []
        
        if prefixLength > 0 {
            operations.append(.retain(prefixLength))
        }
        
        if !sourceMiddle.isEmpty {
            operations.append(.delete(sourceMiddle.count))
        }
        
        if !destMiddle.isEmpty {
            operations.append(.insert(destMiddle))
        }
        
        if suffixLength > 0 {
            operations.append(.retain(suffixLength))
        }
        
        return DiffResult(operations: operations)
    }
    
    /// Consolidate consecutive operations of the same type
    @_optimize(speed)
    private static func consolidateConsecutiveOperations(_ operations: [DiffOperation]) -> [DiffOperation] {
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
    
    /// Public method for the ultra-fast Swift native approach
    @_optimize(speed)
    public static func createDiffUsingSwiftNativeMethods(
        source: String,
        destination: String
    ) -> DiffResult {
        return createDiffUsingStringManipulation(source: source, destination: destination)
    }
} 
