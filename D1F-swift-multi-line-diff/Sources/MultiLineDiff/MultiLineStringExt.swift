//
//  MultiLineStringExt.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//

/// Swift 6.1 Enhanced String Processing Utilities
public extension String {
    func truncated(to length: Int) -> String {
        count > length ? prefix(length) + "..." : self
    }
    
    /// Optimized common prefix detection using Swift 6.1 string enhancements
    @_optimize(speed)
    func commonPrefix(with other: String) -> Int {
        // Use Swift 6.1's enhanced string comparison
        guard !isEmpty && !other.isEmpty else { return 0 }
        
        return zip(self, other)
            .prefix(while: ==)
            .count
    }
    
    /// Optimized common suffix detection using Swift 6.1 string enhancements
    @_optimize(speed)
    func commonSuffix(with other: String) -> Int {
        // Use Swift 6.1's enhanced string comparison with reversed iteration
        guard !isEmpty && !other.isEmpty else { return 0 }
        
        return zip(self.reversed(), other.reversed())
            .prefix(while: ==)
            .count
    }
    
    /// Swift 6.1 enhanced Unicode-aware line splitting that preserves newlines
    @_optimize(speed)
    var efficientLines: [Substring] {
        // Use components(separatedBy:) to preserve the original character structure
        // This ensures that newlines are accounted for correctly in character counting
        guard !isEmpty else { return [] }
        
        var lines: [Substring] = []
        var currentIndex = startIndex
        
        while currentIndex < endIndex {
            if let newlineIndex = self[currentIndex...].firstIndex(of: "\n") {
                // Include the newline character in the line
                let lineEndIndex = index(after: newlineIndex)
                lines.append(self[currentIndex..<lineEndIndex])
                currentIndex = lineEndIndex
            } else {
                // Last line without newline
                lines.append(self[currentIndex...])
                break
            }
        }
        
        return lines
    }
    
    /// Memory-efficient character access using Swift 6.1 features
    @_optimize(speed)
    func characterAt(offset: Int) -> Character? {
        // SAFETY: Comprehensive bounds checking to prevent crashes
        guard offset >= 0 && offset < count else { return nil }
        
        // SAFETY: Additional safety check for index calculation
        guard let targetIndex = index(startIndex, offsetBy: offset, limitedBy: endIndex) else {
            return nil
        }
        
        return self[targetIndex]
    }
    
    /// Swift 6.1 enhanced substring extraction
    @_optimize(speed)
    func substring(from: Int, length: Int) -> String {
        // SAFETY: Comprehensive bounds checking to prevent crashes
        guard from >= 0 && length >= 0 && from < count else { 
            return "" 
        }
        
        // SAFETY: Calculate safe indices with bounds checking
        let safeFrom = Swift.max(0, from)
        let safeTo = Swift.min(count, safeFrom + length)
        let safeLength = Swift.max(0, safeTo - safeFrom)
        
        guard let startIdx = index(startIndex, offsetBy: safeFrom, limitedBy: endIndex) else {
            return ""
        }
        
        guard let endIdx = index(startIdx, offsetBy: safeLength, limitedBy: endIndex) else {
            // If we can't get the exact length, return from start to end
            return String(self[startIdx...])
        }
        
        return String(self[startIdx..<endIdx])
    }
}
