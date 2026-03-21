//
//  JSON.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/20/25.
//

import Foundation

extension MultiLineDiff {
    /// Encodes a diff result to JSON data with advanced configuration
    ///
    /// This method transforms a `DiffResult` into a JSON representation,
    /// supporting both compact and human-readable formats.
    ///
    /// # Features
    /// - Base64 encoding of operations
    /// - Optional metadata preservation
    /// - Configurable JSON formatting
    ///
    /// # Performance
    /// - Efficient encoding using Swift's `JSONEncoder`
    /// - Minimal memory overhead
    /// - Supports large diff results
    ///
    /// # Example
    /// ```swift
    /// let diff = MultiLineDiff.createDiff(source: oldCode, destination: newCode)
    /// let jsonData = try MultiLineDiff.encodeDiffToJSON(diff)
    /// let prettyJsonData = try MultiLineDiff.encodeDiffToJSON(diff, prettyPrinted: true)
    /// ```
    ///
    /// - Parameters:
    ///   - diff: The diff result to encode
    ///   - prettyPrinted: Whether to format JSON for human readability
    ///
    /// - Returns: JSON-encoded representation of the diff
    /// - Throws: Encoding errors if JSON serialization fails
    @_optimize(speed)
    public static func encodeDiffToJSON(_ diff: DiffResult, prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.sortedKeys]
        }
        
        // Swift 6.1 optimized encoding with precise memory allocation
        let operationsData = try encoder.encode(diff.operations)
        
        // Pre-size wrapper for better memory efficiency
        var wrapper: [String: Any] = [:]
        wrapper.reserveCapacity(diff.metadata != nil ? 2 : 1)
        wrapper["df"] = operationsData.base64EncodedString()
        
        // Add metadata if available with optimized encoding
        if let metadata = diff.metadata {
            let metadataData = try encoder.encode(metadata)
            wrapper["md"] = metadataData.base64EncodedString()
        }
        
        // Swift 6.1 enhanced JSON serialization
        return try JSONSerialization.data(withJSONObject: wrapper, options: prettyPrinted ? [.sortedKeys, .prettyPrinted] : [])
    }
    
    /// Encodes a diff result to a JSON string
    /// - Parameters:
    ///   - diff: The diff result to encode
    ///   - prettyPrinted: Whether to format the JSON for human readability
    /// - Returns: The JSON string representation of the diff
    /// - Throws: An error if encoding fails
    @_optimize(speed)
    public static func encodeDiffToJSONString(_ diff: DiffResult, prettyPrinted: Bool = false) throws -> String {
        let data = try encodeDiffToJSON(diff, prettyPrinted: prettyPrinted)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw DiffError.encodingFailed
        }
        return jsonString
    }
    
    /// Decodes a diff result from JSON data
    /// - Parameter data: The JSON data to decode
    /// - Returns: The decoded diff result
    /// - Throws: An error if decoding fails
    @_optimize(speed)
    public static func decodeDiffFromJSON(_ data: Data) throws -> DiffResult {
        let decoder = JSONDecoder()
        
        // Swift 6.1 enhanced decoding with optimized error handling
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Swift 6.1 optimized Base64 extraction
                guard let base64String = json["df"] as? String,
                      let operationsData = Data(base64Encoded: base64String) else {
                    throw DiffError.decodingFailed
                }
                
                // Optimized operations decoding
                let operations = try decoder.decode([DiffOperation].self, from: operationsData)
                
                // Enhanced metadata decoding with Swift 6.1 optimizations
                var metadata: DiffMetadata? = nil
                if let metadataBase64 = json["md"] as? String,
                   let metadataData = Data(base64Encoded: metadataBase64) {
                    metadata = try? decoder.decode(DiffMetadata.self, from: metadataData)
                }
                
                return DiffResult(operations: operations, metadata: metadata)
            }
        } catch {
            // Swift 6.1 enhanced fallback handling
        }
        
        // Optimized fallback to legacy format
        do {
            let operations = try decoder.decode([DiffOperation].self, from: data)
            return DiffResult(operations: operations)
        } catch {
            throw DiffError.decodingFailed
        }
    }
    
    /// Decodes a diff result from a JSON string
    /// - Parameter jsonString: The JSON string to decode
    /// - Returns: The decoded diff result
    /// - Throws: An error if decoding fails
    @_optimize(speed)
    public static func decodeDiffFromJSONString(_ jsonString: String) throws -> DiffResult {
        guard let data = jsonString.data(using: .utf8) else {
            throw DiffError.decodingFailed
        }
        return try decodeDiffFromJSON(data)
    }
    
    /// Converts a diff result to a compact, secure Base64 encoded string
    ///
    /// Base64 encoding provides a safe, compact representation of diff operations
    /// that can be easily transmitted, stored, or shared across different systems.
    ///
    /// # Key Benefits
    /// - Compact representation
    /// - Safe transmission
    /// - Cross-platform compatibility
    /// - Preserves metadata
    ///
    /// # Encoding Strategy
    /// - Encodes operations and optional metadata
    /// - Uses standard Base64 encoding
    /// - Supports both Brus and Todd algorithms
    ///
    /// # Example
    /// ```swift
    /// let base64Diff = try MultiLineDiff.diffToBase64(diffResult)
    /// // Transmit or store the base64Diff safely
    /// ```
    ///
    /// - Parameters:
    ///   - diff: The diff result to encode
    ///
    /// - Returns: A Base64 encoded string representing the diff
    /// - Throws: Encoding errors if Base64 conversion fails
    @_optimize(speed)
    public static func diffToBase64(_ diff: DiffResult) throws -> String {
        let encoder = JSONEncoder()
        
        // Swift 6.1 optimized compound object creation
        var wrapper: [String: Any] = [:]
        wrapper.reserveCapacity(diff.metadata != nil ? 2 : 1)
        
        // Swift 6.1 enhanced operations encoding
        let operationsData = try encoder.encode(diff.operations)
        wrapper["op"] = operationsData.base64EncodedString()
        
        // Optimized metadata encoding with conditional allocation
        if let metadata = diff.metadata {
            let metadataData = try encoder.encode(metadata)
            wrapper["mt"] = metadataData.base64EncodedString()
        }
        
        // Swift 6.1 enhanced Base64 conversion with optimized memory usage
        let wrapperData = try JSONSerialization.data(withJSONObject: wrapper)
        return wrapperData.base64EncodedString()
    }
    
    /// Creates a diff result from a base64 encoded string
    /// - Parameter base64String: The base64 encoded string containing the diff operations
    /// - Returns: The decoded diff result
    /// - Throws: An error if decoding fails
    @_optimize(speed)
    public static func diffFromBase64(_ base64String: String) throws -> DiffResult {
        // Swift 6.1 enhanced Base64 decoding with optimized validation
        guard let data = Data(base64Encoded: base64String) else {
            throw DiffError.decodingFailed
        }
        
        // Swift 6.1 optimized wrapper decoding
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let decoder = JSONDecoder()
                
                // Enhanced format handling with Swift 6.1 optimizations
                if let opsBase64 = json["op"] as? String {
                    guard let opsData = Data(base64Encoded: opsBase64) else {
                        throw DiffError.decodingFailed
                    }
                    
                    // Swift 6.1 optimized operations decoding
                    let operations = try decoder.decode([DiffOperation].self, from: opsData)
                    
                    // Enhanced metadata decoding with conditional processing
                    var metadata: DiffMetadata? = nil
                    if let metaBase64 = json["mt"] as? String,
                       let metaData = Data(base64Encoded: metaBase64) {
                        metadata = try? decoder.decode(DiffMetadata.self, from: metaData)
                    }
                    
                    return DiffResult(operations: operations, metadata: metadata)
                }
            }
        } catch {
            // Swift 6.1 enhanced error handling for legacy compatibility
        }
        
        // Optimized legacy format fallback
        let decoder = JSONDecoder()
        do {
            let operations = try decoder.decode([DiffOperation].self, from: data)
            return DiffResult(operations: operations)
        } catch {
            throw DiffError.decodingFailed
        }
    }
}
