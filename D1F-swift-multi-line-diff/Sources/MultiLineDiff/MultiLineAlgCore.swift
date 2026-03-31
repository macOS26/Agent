//
//  MultiLineAlgCore.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//

/// Shared components for both Brus and Todd algorithms
public enum DiffAlgorithmCore {
    
    /// Enhanced common regions detection using Swift 6.1 features
    struct EnhancedCommonRegions {
        let prefixLength: Int
        let suffixLength: Int
        let sourceMiddleRange: Range<Int>
        let destMiddleRange: Range<Int>
        
        @_optimize(speed)
        init(source: String, destination: String) {
            // Use Swift 6.1 enhanced string comparison
            let prefixLen = source.commonPrefix(with: destination)
            
            // Calculate suffix avoiding prefix overlap
            let remainingSourceCount = source.count - prefixLen
            let remainingDestCount = destination.count - prefixLen
            let maxSuffixLen = Swift.min(remainingSourceCount, remainingDestCount)
            
            let suffixLen: Int
            if maxSuffixLen > 0 {
                let sourceSuffix = String(source.suffix(maxSuffixLen))
                let destSuffix = String(destination.suffix(maxSuffixLen))
                suffixLen = sourceSuffix.commonSuffix(with: destSuffix)
            } else {
                suffixLen = 0
            }
            
            self.prefixLength = prefixLen
            self.suffixLength = suffixLen
            self.sourceMiddleRange = prefixLen..<(source.count - suffixLen)
            self.destMiddleRange = prefixLen..<(destination.count - suffixLen)
        }
        
        /// Extract middle content from source
        @_optimize(speed)
        func sourceMiddle(from source: String) -> String {
            guard !sourceMiddleRange.isEmpty else { return "" }
            return source.substring(from: sourceMiddleRange.lowerBound,
                                  length: sourceMiddleRange.count)
        }
        
        /// Extract middle content from destination
        @_optimize(speed)
        func destMiddle(from destination: String) -> String {
            guard !destMiddleRange.isEmpty else { return "" }
            return destination.substring(from: destMiddleRange.lowerBound,
                                       length: destMiddleRange.count)
        }
    }
    
    /// Optimized operation builder using Swift 6.1 features
    struct OperationBuilder {
        public var operations: [DiffOperation] = []
        
        // Accumulated operation state
        public var pendingRetainCount = 0
        public var pendingDeleteCount = 0
        public var pendingInsertText = ""
        
        @_optimize(speed)
        mutating func addRetain(count: Int) {
            guard count > 0 else { return }
            
            // Flush non-retain operations before adding retain
            if pendingDeleteCount > 0 || !pendingInsertText.isEmpty {
                flushPendingOperations()
            }
            
            pendingRetainCount += count
        }
        
        @_optimize(speed)
        mutating func addDelete(count: Int) {
            guard count > 0 else { return }
            
            // Flush non-delete operations before adding delete
            if pendingRetainCount > 0 || !pendingInsertText.isEmpty {
                flushPendingOperations()
            }
            
            pendingDeleteCount += count
        }
        
        @_optimize(speed)
        mutating func addInsert(text: String) {
            guard !text.isEmpty else { return }
            
            // Flush non-insert operations before adding insert
            if pendingRetainCount > 0 || pendingDeleteCount > 0 {
                flushPendingOperations()
            }
            
            pendingInsertText += text
        }
        
        @_optimize(speed)
        mutating func flushPendingOperations() {
            if pendingRetainCount > 0 {
                operations.append(.retain(pendingRetainCount))
                pendingRetainCount = 0
            }
            if pendingDeleteCount > 0 {
                operations.append(.delete(pendingDeleteCount))
                pendingDeleteCount = 0
            }
            if !pendingInsertText.isEmpty {
                operations.append(.insert(pendingInsertText))
                pendingInsertText = ""
            }
        }
        
        @_optimize(speed)
        mutating func build() -> [DiffOperation] {
            flushPendingOperations()
            return operations
        }
    }
    
        
       
}
