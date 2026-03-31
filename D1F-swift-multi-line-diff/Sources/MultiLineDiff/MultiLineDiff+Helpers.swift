//
//  MultiLineDiff+Helpers.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//

import Foundation

// MARK: - Helper Functions
extension MultiLineDiff {
    /// Find the best matching section in a document using context matching
    internal static func findBestMatchingSection(
        fullLines: [Substring],
        metadata: DiffMetadata,
        sourceLineCount: Int
    ) -> Range<Int>? {
        guard let precedingContext = metadata.precedingContext else { return nil }
        let followingContext = metadata.followingContext
        
        var bestMatchIndex: Int?
        var bestMatchConfidence = 0.0
        
        // SAFETY: Ensure sourceLineCount is valid and reasonable
        let safeSourceLineCount = Swift.max(1, Swift.min(sourceLineCount, fullLines.count))
        
        // Search through the document looking for the best matching section
        for startIndex in 0..<fullLines.count {
            // SAFETY: Bounds checking for endIndex calculation
            let endIndex = Swift.min(fullLines.count, startIndex + safeSourceLineCount)
            
            // SAFETY: Ensure we have a valid range
            guard startIndex < endIndex && endIndex <= fullLines.count else {
                continue
            }
            
            // Extract potential section with bounds checking
            let sectionLines = Array(fullLines[startIndex..<endIndex])
            
            // FIXED: Handle newline-preserving lines correctly
            // Since lines now include newlines, join without adding separator
            let sectionText = sectionLines.map(String.init).joined()
            
            // Calculate confidence score based on both contexts
            let confidence = calculateSectionMatchConfidence(
                sectionText: sectionText,
                precedingContext: precedingContext,
                followingContext: followingContext,
                fullLines: fullLines,
                sectionStartIndex: startIndex,
                sectionEndIndex: endIndex
            )
            
            // Update best match if this section has higher confidence
            if confidence > bestMatchConfidence {
                bestMatchConfidence = confidence
                bestMatchIndex = startIndex
            }
            
            // If we find a very high confidence match, use it immediately
            if confidence > 0.85 {
                break
            }
        }
        
        // Require minimum confidence to proceed
        guard let startIndex = bestMatchIndex, bestMatchConfidence > 0.3 else {
            return nil // Couldn't find a sufficiently confident match
        }
        
        // SAFETY: Bounds checking for final range calculation
        let endIndex = Swift.min(fullLines.count, startIndex + safeSourceLineCount)
        
        // FIXED: Extend the range to include trailing blank lines that are part of section formatting
        var extendedEndIndex = endIndex
        // Include trailing blank lines (lines that are just "\n") up to the next content
        while extendedEndIndex < fullLines.count && 
              fullLines[extendedEndIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            extendedEndIndex += 1
        }
        
        // SAFETY: Final bounds check
        guard startIndex < extendedEndIndex && extendedEndIndex <= fullLines.count else {
            return startIndex..<endIndex // Return safe range
        }
        
        return startIndex..<extendedEndIndex
    }
    
    /// Reconstruct document with modified section
    internal static func reconstructDocumentWithModifiedSection(
        fullLines: [Substring],
        sectionRange: Range<Int>,
        operations: [DiffOperation]
    ) throws -> String {
        // SAFETY: Validate section range bounds
        guard sectionRange.lowerBound >= 0 && 
              sectionRange.upperBound <= fullLines.count &&
              sectionRange.lowerBound < sectionRange.upperBound else {
            throw DiffError.invalidDiff // Return error for invalid ranges instead of crashing
        }
        
        // Extract the section to be modified with bounds checking
        let sectionLines = Array(fullLines[sectionRange])
        
        // FIXED: Handle newline-preserving lines correctly
        // Since lines now include newlines, join without adding separator
        let sectionText = sectionLines.map(String.init).joined()
        
        // Apply the diff to the section
        let modifiedSection = try processOperationsOnSource(
            source: sectionText,
            operations: operations,
            allowTruncatedSource: true
        )
        
        // Reconstruct the full document with the modified section
        var resultLines = Array(fullLines)
        
        // FIXED: Handle modified section correctly and preserve trailing formatting
        let modifiedLines: [Substring]
        if modifiedSection.isEmpty {
            modifiedLines = []
        } else {
            // Use the same newline-preserving line splitting as the original
            var tempLines = modifiedSection.efficientLines
            
            // FIXED: Preserve trailing formatting from original section
            // If the original section ended with whitespace/newlines, preserve that pattern
            let originalSectionLines = Array(fullLines[sectionRange])
            if !originalSectionLines.isEmpty {
                let lastOriginalLine = originalSectionLines.last!
                
                // If the last original line was just whitespace (blank line), 
                // and the modified section doesn't end with a newline, add one
                if lastOriginalLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // This was a trailing blank line - preserve it
                    if !tempLines.isEmpty && !tempLines.last!.hasSuffix("\n") {
                        // Modified section doesn't end with newline, add one
                        let lastLine = tempLines.removeLast()
                        tempLines.append(Substring(String(lastLine) + "\n"))
                    }
                    // Add the blank line
                    tempLines.append(Substring("\n"))
                } else if lastOriginalLine.hasSuffix("\n") && !tempLines.isEmpty && !tempLines.last!.hasSuffix("\n") {
                    // Original ended with newline, but modified doesn't - add it
                    let lastLine = tempLines.removeLast()
                    tempLines.append(Substring(String(lastLine) + "\n"))
                }
            }
            
            modifiedLines = tempLines
        }
        
        // SAFETY: Replace the original section lines with modified lines using safe bounds
        guard sectionRange.lowerBound < resultLines.count else {
            throw DiffError.invalidDiff // Prevent crash if range is invalid
        }
        
        // Ensure we don't go beyond array bounds
        let safeUpperBound = Swift.min(sectionRange.upperBound, resultLines.count)
        let safeRange = sectionRange.lowerBound..<safeUpperBound
        
        resultLines.replaceSubrange(safeRange, with: modifiedLines)
        
        // FIXED: Join without separator since lines already include newlines
        return resultLines.map(String.init).joined()
    }
    
    /// Perform smart verification of diff application result
    internal static func performSmartVerification(
        source: String,
        result: String,
        diff: DiffResult
    ) throws {
        // Smart verification: only verify if we're applying to the same type of source
        if let metadata = diff.metadata,
           let expectedDestination = metadata.destinationContent,
           let storedSource = metadata.sourceContent {
            
            // Only verify if we're applying to the same source that created the diff
            // or if we're applying to a truncated source that matches the stored source
            let shouldVerify = (source == storedSource) ||
            (storedSource.contains(source) && storedSource != source)
            
            if shouldVerify && result != expectedDestination {
                throw DiffError.verificationFailed(
                    expected: expectedDestination,
                    actual: result
                )
            }
        }
    }
    
    /// Decode an encoded diff based on the specified encoding format
    internal static func decodeEncodedDiff(
        encodedDiff: Any,
        encoding: DiffEncoding
    ) throws -> DiffResult {
        switch encoding {
        case .base64:
            guard let base64String = encodedDiff as? String else {
                throw DiffError.decodingFailed
            }
            return try diffFromBase64(base64String)
        case .jsonString:
            guard let jsonString = encodedDiff as? String else {
                throw DiffError.decodingFailed
            }
            return try decodeDiffFromJSONString(jsonString)
        case .jsonData:
            guard let jsonData = encodedDiff as? Data else {
                throw DiffError.decodingFailed
            }
            return try decodeDiffFromJSON(jsonData)
        }
    }
    
    /// Determine whether to allow truncated source handling based on metadata and source verification
    internal static func shouldAllowTruncatedSource(for source: String, diff: DiffResult) -> Bool {
        // First, check if we can verify with stored source content
        if let storedSource = diff.metadata?.sourceContent {
            return DiffMetadata.requiresTruncatedHandling(
                providedSource: source,
                storedSource: storedSource
            )
        } else if let applicationType = diff.metadata?.applicationType {
            // Fall back to explicit application type
            return (applicationType == .requiresTruncatedSource)
        } else {
            // Fall back to legacy heuristics if no explicit type or stored source
            return (diff.metadata?.sourceStartLine ?? 0) > 0 ||
            diff.metadata?.precedingContext != nil
        }
    }
    
}

