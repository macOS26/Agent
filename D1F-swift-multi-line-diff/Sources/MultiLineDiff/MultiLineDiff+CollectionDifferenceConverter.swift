//
//  MultiLineDiff+CollectionDifferenceConverter.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//

extension MultiLineDiff {
    
    /// Convert Swift's CollectionDifference to DiffOperation array
    @_optimize(speed)
    internal static func convertCollectionDifference<T: Collection>(
        _ difference: CollectionDifference<T.Element>,
        source: T,
        destination: T
    ) -> [DiffOperation] where T.Element: Equatable {
        
        var operations: [DiffOperation] = []
        
        // Sort changes by offset to process in order
        let sortedChanges = difference.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case (.remove(let lOffset, _, _), .remove(let rOffset, _, _)):
                return lOffset < rOffset
            case (.insert(let lOffset, _, _), .insert(let rOffset, _, _)):
                return lOffset < rOffset
            case (.remove(let lOffset, _, _), .insert(let rOffset, _, _)):
                return lOffset <= rOffset
            case (.insert(let lOffset, _, _), .remove(let rOffset, _, _)):
                return lOffset < rOffset
            }
        }
        
        var processedSourceOffset = 0
        var processedDestOffset = 0
        
        for change in sortedChanges {
            switch change {
            case .remove(let offset, _, _):
                // Add retains for unchanged elements before this removal
                let retainCount = offset - processedSourceOffset
                if retainCount > 0 {
                    operations.append(.retain(retainCount))
                }
                
                // Add delete operation
                operations.append(.delete(1)) // Assuming single character/element
                processedSourceOffset = offset + 1
                
            case .insert(let offset, let element, _):
                // Add retains for unchanged elements before this insertion
                let retainCount = offset - processedDestOffset
                if retainCount > 0 {
                    operations.append(.retain(retainCount))
                    processedSourceOffset += retainCount
                }
                
                // Add insert operation
                let insertText = String(describing: element)
                operations.append(.insert(insertText))
                processedDestOffset = offset + 1
            }
        }
        
        // Add final retains for any remaining unchanged elements
        let remainingSourceCount = source.count - processedSourceOffset
        if remainingSourceCount > 0 {
            operations.append(.retain(remainingSourceCount))
        }
        
        return operations
    }
    
    /// Convert String CollectionDifference to DiffOperation array (optimized for strings)
    @_optimize(speed)
    internal static func convertStringDifference(
        _ difference: CollectionDifference<Character>,
        source: String,
        destination: String
    ) -> [DiffOperation] {
        
        // Fast path for identical strings
        if source == destination {
            return source.isEmpty ? [] : [.retain(source.count)]
        }
        
        // Fast path for empty strings
        if source.isEmpty {
            return destination.isEmpty ? [] : [.insert(destination)]
        }
        if destination.isEmpty {
            return [.delete(source.count)]
        }
        
        // Convert strings to arrays once for O(1) access
        let sourceChars = Array(source)
        let destChars = Array(destination)
        
        // Use Sets for O(1) lookup instead of arrays with contains()
        var removalSet = Set<Int>()
        var insertionMap: [Int: Character] = [:]
        
        for change in difference {
            switch change {
            case .remove(let offset, _, _):
                removalSet.insert(offset)
            case .insert(let offset, let char, _):
                insertionMap[offset] = char
            }
        }
        
        // Pre-allocate operations array with estimated capacity
        var operations: [DiffOperation] = []
        operations.reserveCapacity(difference.count + 1)
        
        var sourceIndex = 0
        var destIndex = 0
        
        // Track consecutive operations for inline consolidation
        var retainCount = 0
        var deleteCount = 0
        var insertBuffer = ""
        
        @inline(__always)
        func flushOperations() {
            if retainCount > 0 {
                operations.append(.retain(retainCount))
                retainCount = 0
            }
            if deleteCount > 0 {
                operations.append(.delete(deleteCount))
                deleteCount = 0
            }
            if !insertBuffer.isEmpty {
                operations.append(.insert(insertBuffer))
                insertBuffer = ""
            }
        }
        
        // Main processing loop
        while sourceIndex < sourceChars.count || destIndex < destChars.count {
            
            // Check if current source position should be deleted
            if sourceIndex < sourceChars.count && removalSet.contains(sourceIndex) {
                if retainCount > 0 || !insertBuffer.isEmpty {
                    flushOperations()
                }
                deleteCount += 1
                sourceIndex += 1
                continue
            }
            
            // Check if we need to insert at current destination position
            if let insertChar = insertionMap[destIndex] {
                if retainCount > 0 || deleteCount > 0 {
                    flushOperations()
                }
                insertBuffer.append(insertChar)
                destIndex += 1
                continue
            }
            
            // If we're at valid positions in both strings, they should match
            if sourceIndex < sourceChars.count && destIndex < destChars.count {
                if deleteCount > 0 || !insertBuffer.isEmpty {
                    flushOperations()
                }
                retainCount += 1
                sourceIndex += 1
                destIndex += 1
            } else if sourceIndex < sourceChars.count {
                // Only source characters left - delete them
                if retainCount > 0 || !insertBuffer.isEmpty {
                    flushOperations()
                }
                deleteCount += 1
                sourceIndex += 1
            } else if destIndex < destChars.count {
                // Only destination characters left - insert them
                if retainCount > 0 || deleteCount > 0 {
                    flushOperations()
                }
                insertBuffer.append(destChars[destIndex])
                destIndex += 1
            } else {
                break
            }
        }
        
        // Flush any remaining operations
        flushOperations()
        
        return operations
    }
    

    
    /// Example usage method
    @_optimize(speed)
    public static func createDiffFromCollectionDifference(
        source: String,
        destination: String
    ) -> DiffResult {
        let difference = destination.difference(from: source)
        let operations = convertStringDifference(difference, source: source, destination: destination)
        return DiffResult(operations: operations)
    }
} 
