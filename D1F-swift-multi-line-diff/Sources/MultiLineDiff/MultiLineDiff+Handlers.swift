//
//  MultiLineDiff+Handlers.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//

extension MultiLineDiff {
    
    /// Enhanced retain operation handling
    @_optimize(speed)
    internal static func handleRetainOperation(
        source: String,
        currentIndex: inout String.Index,
        count: Int,
        result: inout String,
        allowTruncated: Bool
    ) throws {
        // SAFETY: Validate count parameter
        guard count >= 0 else {
            throw DiffError.invalidDiff
        }
        
        guard currentIndex < source.endIndex else {
            if allowTruncated {
                return // Skip retain if truncated source
            } else {
                throw DiffError.invalidRetain(count: count, remainingLength: 0)
            }
        }
        
        // Enhanced index calculation using Swift 6.1 features with extra safety
        let endIndex = source.index(currentIndex, offsetBy: count, limitedBy: source.endIndex) ?? source.endIndex
        let actualRetainLength = source.distance(from: currentIndex, to: endIndex)
        
        // SAFETY: Ensure actualRetainLength is not negative
        guard actualRetainLength >= 0 else {
            throw DiffError.invalidDiff
        }
        
        if actualRetainLength != count && !allowTruncated {
            throw DiffError.invalidRetain(
                count: count,
                remainingLength: source.distance(from: currentIndex, to: source.endIndex)
            )
        }
        
        // Efficient substring append with bounds validation
        guard currentIndex <= endIndex && endIndex <= source.endIndex else {
            throw DiffError.invalidDiff
        }
        
        result.append(contentsOf: source[currentIndex..<endIndex])
        currentIndex = endIndex
    }
    
    /// Enhanced delete operation handling
    @_optimize(speed)
    internal static func handleDeleteOperation(
        source: String,
        currentIndex: inout String.Index,
        count: Int,
        allowTruncated: Bool
    ) throws {
        // SAFETY: Validate count parameter
        guard count >= 0 else {
            throw DiffError.invalidDiff
        }
        
        guard currentIndex < source.endIndex else {
            if allowTruncated {
                return // Skip delete if truncated source
            } else {
                throw DiffError.invalidDelete(count: count, remainingLength: 0)
            }
        }
        
        // Enhanced index calculation with extra safety
        let endIndex = source.index(currentIndex, offsetBy: count, limitedBy: source.endIndex) ?? source.endIndex
        let actualDeleteLength = source.distance(from: currentIndex, to: endIndex)
        
        // SAFETY: Ensure actualDeleteLength is not negative
        guard actualDeleteLength >= 0 else {
            throw DiffError.invalidDiff
        }
        
        if actualDeleteLength != count && !allowTruncated {
            throw DiffError.invalidDelete(
                count: count,
                remainingLength: source.distance(from: currentIndex, to: source.endIndex)
            )
        }
        
        // SAFETY: Validate index bounds before assignment
        guard endIndex <= source.endIndex else {
            throw DiffError.invalidDiff
        }
        
        currentIndex = endIndex
    }
    
    
    /// Handle empty string cases for both diff algorithms
    internal static func handleEmptyStrings(source: String, destination: String) -> DiffResult? {
        switch (source.isEmpty, destination.isEmpty) {
        case (true, true):
            return .init(operations: [])
        case (true, false):
            return .init(operations: [.insert(destination)])
        case (false, true):
            return .init(operations: [.delete(source.count)])
        case (false, false):
            return nil
        }
    }
}
