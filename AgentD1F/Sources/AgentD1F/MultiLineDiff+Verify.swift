//
//  MultiLineDiff+Verify.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//

extension MultiLineDiff {
    
    /// Verifies a diff by applying it and checking against stored destination content
    /// Returns true if the diff produces the expected result
    public static func verifyDiff(_ diff: DiffResult) -> Bool {
        guard let metadata = diff.metadata else {
            return false // Cannot verify without metadata
        }
        
        return DiffMetadata.verifyDiffChecksum(
            diff: diff,
            storedSource: metadata.sourceContent,
            storedDestination: metadata.destinationContent
        )
    }
    
    /// Creates an undo diff that reverses the original transformation
    /// Returns nil if the diff doesn't contain the necessary metadata for undo
    public static func createUndoDiff(from diff: DiffResult) -> DiffResult? {
        return DiffMetadata.createUndoDiff(from: diff)
    }
}
