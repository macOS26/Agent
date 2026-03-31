//
//  MultiLineFile.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/20/25.
//

import Foundation

extension MultiLineDiff {
    /// Saves a diff result to a file with advanced configuration
    ///
    /// This method provides a robust way to persist diff operations to disk,
    /// supporting both compact and human-readable JSON formats.
    ///
    /// # Features
    /// - Flexible file output formatting
    /// - Preserves full diff metadata
    /// - Safe file writing with atomic operations
    ///
    /// # Performance Considerations
    /// - Efficient JSON encoding
    /// - Minimal memory overhead
    /// - Supports large diff results
    ///
    /// # Example
    /// ```swift
    /// let diff = MultiLineDiff.createDiff(source: oldCode, destination: newCode)
    /// let fileURL = URL(fileURLWithPath: "/path/to/diff.json")
    ///
    /// // Save with default pretty-printed format
    /// try MultiLineDiff.saveDiffToFile(diff, fileURL: fileURL)
    ///
    /// // Save in compact format
    /// try MultiLineDiff.saveDiffToFile(diff, fileURL: fileURL, prettyPrinted: false)
    /// ```
    ///
    /// - Parameters:
    ///   - diff: The diff result to save to file
    ///   - fileURL: Destination file URL for the diff
    ///   - prettyPrinted: Whether to format JSON for human readability
    ///
    /// - Throws: File writing or encoding errors
    @_optimize(speed)
    public static func saveDiffToFile(_ diff: DiffResult, fileURL: URL, prettyPrinted: Bool = true) throws {
        // Swift 6.1 enhanced JSON encoding with optimized memory usage
        let data = try encodeDiffToJSON(diff, prettyPrinted: prettyPrinted)
        
        // Swift 6.1 optimized file writing with atomic operations
        try data.write(to: fileURL, options: [.atomic])
    }

    /// Loads a diff result from a file with robust error handling
    ///
    /// This method provides a safe and efficient way to read diff operations
    /// from a previously saved JSON file.
    ///
    /// # Features
    /// - Supports both compact and pretty-printed JSON formats
    /// - Handles legacy and current diff encodings
    /// - Comprehensive error handling
    ///
    /// # Performance
    /// - Efficient JSON decoding
    /// - Minimal memory allocation
    /// - Supports large diff files
    ///
    /// # Example
    /// ```swift
    /// let fileURL = URL(fileURLWithPath: "/path/to/saved/diff.json")
    ///
    /// // Load a previously saved diff
    /// let loadedDiff = try MultiLineDiff.loadDiffFromFile(fileURL: fileURL)
    ///
    /// // Apply the loaded diff to a source
    /// let result = try MultiLineDiff.applyDiff(to: sourceCode, diff: loadedDiff)
    /// ```
    ///
    /// - Parameters:
    ///   - fileURL: Source file URL containing the saved diff
    ///
    /// - Returns: A fully reconstructed `DiffResult`
    /// - Throws: File reading or decoding errors
    @_optimize(speed)
    public static func loadDiffFromFile(fileURL: URL) throws -> DiffResult {
        // Swift 6.1 enhanced file reading with optimized memory allocation
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        
        // Swift 6.1 optimized JSON decoding
        return try decodeDiffFromJSON(data)
    }
}
