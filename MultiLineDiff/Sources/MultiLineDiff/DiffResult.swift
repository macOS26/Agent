//
//  DiffResult.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//


/// Represents the result of a diff operation
@frozen public struct DiffResult: Equatable, Codable {
    /// The sequence of operations that transform the source text into the destination text
    public let operations: [DiffOperation]
    /// Optional metadata about the diff, useful for truncated strings
    public let metadata: DiffMetadata?
    
    public init(operations: [DiffOperation], metadata: DiffMetadata? = nil) {
        self.operations = operations
        self.metadata = metadata
    }
}
