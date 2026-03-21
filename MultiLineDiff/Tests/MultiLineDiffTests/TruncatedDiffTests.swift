import Testing
import Foundation
@testable import MultiLineDiff

// Tests for truncated diff functionality
@Test func testTruncatedDiffFromFullSource() throws {
    // The simplest possible test case for truncated source handling
    let truncatedSection = "Section will be replaced"
    let expectedResult = "Section has been UPDATED"
    
    // Create a diff with a simple delete-and-insert operation
    let operations: [DiffOperation] = [
        .delete(truncatedSection.count),
        .insert(expectedResult)
    ]
    
    // Create a diff with metadata
    let truncatedDiff = DiffResult(
        operations: operations,
        metadata: DiffMetadata(
            sourceTotalLines: 1,
            precedingContext: "Context before section: ",
            followingContext: " and after section"
        )
    )
    
    // Apply the diff to the truncated section
    let result = try MultiLineDiff.applyDiff(
        to: truncatedSection,
        diff: truncatedDiff
    )
    
    // Verify the result
    #expect(result == expectedResult, "Failed to apply diff to truncated section")
    
    // Also test with base64 encoding/decoding
    let base64Diff = try MultiLineDiff.diffToBase64(truncatedDiff)
    let resultFromBase64 = try MultiLineDiff.applyBase64Diff(
        to: truncatedSection,
        base64Diff: base64Diff,
        allowTruncatedSource: true
    )
    
    #expect(resultFromBase64 == expectedResult, "Failed to apply base64-encoded diff to truncated section")
}

@Test func testTruncatedDiffToFullSource() throws {
    // Create a larger document with multiple sections
    let fullDocument = """
    # Test Document
    
    ## Section 1
    This is the content of section 1.
    It has multiple lines.
    
    ## Section 2
    This is the content of section 2.
    With some details here.
    
    ## Section 3
    This section will be modified.
    It contains important information.
    
    ## Section 4
    This is the last section.
    The end.
    """
    
    // Expected result after applying section 3 diff to full document
    let expectedFullResult = """
    # Test Document
    
    ## Section 1
    This is the content of section 1.
    It has multiple lines.
    
    ## Section 2
    This is the content of section 2.
    With some details here.
    
    ## Section 3
    This section has been UPDATED.
    It contains REVISED information.
    
    ## Section 4
    This is the last section.
    The end.
    """
    
    // Extract just section 3 (truncated source)
    let originalSection3 = """
    ## Section 3
    This section will be modified.
    It contains important information.
    """
    
    // Modified version of section 3
    let modifiedSection3 = """
    ## Section 3
    This section has been UPDATED.
    It contains REVISED information.
    """
    
    // Determine the line number of Section 3 in the full document
    var section3LineNumber = 0
    let fullDocLines = fullDocument.split(separator: "\n")
    for (i, line) in fullDocLines.enumerated() {
        if line == "## Section 3" {
            section3LineNumber = i
            break
        }
    }
    
    // Create a diff between the truncated sections with metadata
    let truncatedDiff = MultiLineDiff.createDiff(
        source: originalSection3,
        destination: modifiedSection3,
        includeMetadata: true,
        sourceStartLine: section3LineNumber
    )
    
    // Apply the truncated diff to the full document
    let result = try MultiLineDiff.applyDiff(
        to: fullDocument,
        diff: truncatedDiff
    )
    
    // Verify the result
    #expect(result == expectedFullResult, "Failed to apply truncated section diff to full document")
    
    // Also test with base64 encoding/decoding
    let base64Diff = try MultiLineDiff.diffToBase64(truncatedDiff)
    let resultFromBase64 = try MultiLineDiff.applyBase64Diff(
        to: fullDocument,
        base64Diff: base64Diff,
        allowTruncatedSource: true
    )
    
    #expect(resultFromBase64 == expectedFullResult, "Failed to apply base64-encoded truncated section diff to full document")
}

@Test func testTruncatedDiffEdgeCases() throws {
    // Test 1: Completely non-overlapping truncated source
    let truncatedSource = "Something completely different that doesn't exist in the original."
    
    let operations: [DiffOperation] = [
        .delete(truncatedSource.count),
        .insert("Replacement text for the truncated part.")
    ]
    
    let diff = DiffResult(operations: operations)
    
    do {
        _ = try MultiLineDiff.applyDiff(to: truncatedSource, diff: diff)
        // Should succeed with allowTruncatedSource = true
    } catch {
        throw TestError("Should not throw with allowTruncatedSource = true")
    }
    
    // Test 2: Truncated at beginning
    let source = "This is a long sentence that will be partially truncated."
    let truncated = "will be partially truncated."
    
    let op: [DiffOperation] = [
        .retain(source.count - 5),
        .delete(5),
        .insert("modified.")
    ]
    
    let beginningTruncatedDiff = DiffResult(
        operations: op,
        metadata: DiffMetadata(
            precedingContext: "This is a long sentence that will be partially",
            followingContext: "cated."
        )
    )
    
    let result = try MultiLineDiff.applyDiff(
        to: truncated, 
        diff: beginningTruncatedDiff
    )
    
    #expect(result.hasSuffix("modified."), "Failed to apply diff to beginning-truncated string")
    
    // Test 3: Empty operations with metadata
    let emptyDiff = DiffResult(
        operations: [],
        metadata: DiffMetadata(
            sourceStartLine: 10,
            precedingContext: "Some context",
            followingContext: "More context"
        )
    )
    
    let emptyResult = try MultiLineDiff.applyDiff(
        to: "Test string", 
        diff: emptyDiff
    )
    
    #expect(emptyResult == "Test string", "Empty operations should not modify the source")
}

// Remove the duplicate TestError struct 
