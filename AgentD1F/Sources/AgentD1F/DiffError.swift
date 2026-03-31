//
//  DiffError.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//


/// Errors that can occur during diff operations
@frozen public enum DiffError: Error, CustomStringConvertible {
    case invalidRetain(count: Int, remainingLength: Int)
    case invalidDelete(count: Int, remainingLength: Int)
    case incompleteApplication(unconsumedLength: Int)
    case invalidDiff
    case encodingFailed
    case decodingFailed
    case verificationFailed(expected: String, actual: String)
    
    public var description: String {
        switch self {
        case .invalidRetain(let count, let remaining):
            "Cannot retain \(count) characters, only \(remaining) remaining"
        case .invalidDelete(let count, let remaining):
            "Cannot delete \(count) characters, only \(remaining) remaining"
        case .incompleteApplication(let unconsumed):
            "Diff application did not consume entire source string (\(unconsumed) characters remaining)"
        case .invalidDiff:
            "Invalid diff: operation contains out-of-bounds indices or malformed data"
        case .encodingFailed:
            "Failed to encode diff to JSON"
        case .decodingFailed:
            "Failed to decode diff from JSON"
        case .verificationFailed(let expected, let actual):
            "Diff verification failed: expected \(expected.count) characters, got \(actual.count) characters"
        }
    }
}
