//
//  MultiLineDiff+Find.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//


extension MultiLineDiff {
    /// Process diff operations on a source string
    @_optimize(speed)
    internal static func processOperationsOnSource(
        source: String,
        operations: [DiffOperation],
        allowTruncatedSource: Bool
    ) throws -> String {
        var result = String()
        var currentIndex = source.startIndex
        
        // Enhanced operation processing
        for operation in operations {
            switch operation {
            case .retain(let count):
                try handleRetainOperation(
                    source: source,
                    currentIndex: &currentIndex,
                    count: count,
                    result: &result,
                    allowTruncated: allowTruncatedSource
                )
                
            case .insert(let text):
                // Simply append inserted text
                result.append(text)
                
            case .delete(let count):
                try handleDeleteOperation(
                    source: source,
                    currentIndex: &currentIndex,
                    count: count,
                    allowTruncated: allowTruncatedSource
                )
            }
        }
        
        // Check for remaining content
        if currentIndex < source.endIndex && !allowTruncatedSource {
            throw DiffError.incompleteApplication(
                unconsumedLength: source.distance(from: currentIndex, to: source.endIndex)
            )
        }
        
        return result
    }
}
