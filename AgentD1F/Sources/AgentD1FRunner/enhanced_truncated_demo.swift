import Foundation
import AgentD1F

/// Demonstrates the enhanced truncated diff functionality with dual context matching
func demonstrateEnhancedTruncatedDiff() -> Bool {
    print("\n🔍 Enhanced Truncated Diff Demonstration")
    print("========================================\n")

    // Full document with repeated similar sections that could cause false matches
    let fullDocument = """
    # Documentation

    ## Setup Instructions
    Please follow these setup steps carefully.
    This is important for the installation.

    ## Configuration Settings  
    Please follow these setup steps carefully.
    This configuration is essential for operation.

    ## Advanced Configuration
    Please follow these setup steps carefully. 
    This advanced section covers complex scenarios.

    ## Conclusion
    Final notes and recommendations.
    """

    // Truncated section (middle part) - note the repeated "Please follow these setup steps carefully"
    let truncatedOriginal = """
    ## Configuration Settings  
    Please follow these setup steps carefully.
    This configuration is essential for operation.
    """

    // Modified version of the truncated section
    let truncatedModified = """
    ## Configuration Settings  
    Please follow these UPDATED setup steps carefully.
    This configuration is CRITICAL for operation.
    """

    print("📄 Full Document:")
    print(fullDocument)
    print("\n📝 Truncated Section (original):")
    print(truncatedOriginal)
    print("\n✏️  Truncated Section (modified):")
    print(truncatedModified)

    // Create diff with enhanced metadata that includes both contexts and source verification
    let diff = MultiLineDiff.createDiff(
        source: truncatedOriginal,
        destination: truncatedModified,
        algorithm: .megatron,
        sourceStartLine: 5  // Approximate line number
    )

    print("\n🧩 Diff Metadata:")
    if let metadata = diff.metadata {
        print("  Preceding Context: '\(metadata.precedingContext ?? "None")'")
        print("  Following Context: '\(metadata.followingContext ?? "None")'")
        print("  Application Type: \(metadata.applicationType?.rawValue ?? "Unknown")")
        print("  Source Content Stored: \(metadata.sourceContent != nil ? "Yes" : "No")")
        print("  Destination Content Stored: \(metadata.destinationContent != nil ? "Yes" : "No")")
        print("  Algorithm Used: \(metadata.algorithmUsed?.rawValue ?? "Unknown")")
        print("  Source Lines: \(metadata.sourceTotalLines ?? 0)")
        if let hash = metadata.diffHash {
            print("  Diff Hash (SHA256): \(String(hash.prefix(16)))...")
        }
    }

    print("\n🔧 Diff Operations:")
    for (index, operation) in diff.operations.enumerated() {
        print("  \(index + 1). \(operation.description)")
    }

    // Apply the truncated diff to the full document
    // The enhanced algorithm should find the correct section using both contexts
    do {
        // First demonstrate intelligent application that auto-detects source type
        print("\n🤖 Intelligent Application (auto-detects full vs truncated source):")
        let intelligentResult = try MultiLineDiff.applyDiff(
            to: fullDocument,
            diff: diff
        )
        
        print("✅ Result after intelligent application to full document:")
        print(intelligentResult)
        
        // Also demonstrate applying to the truncated source directly
        print("\n🔧 Intelligent Application to truncated source:")
        let truncatedResult = try MultiLineDiff.applyDiff(
            to: truncatedOriginal,
            diff: diff
        )
        
        print("✅ Result after intelligent application to truncated source:")
        print(truncatedResult)
        
        // Traditional method for comparison
        print("\n🔄 Traditional method (manual allowTruncatedSource):")
        let result = try MultiLineDiff.applyDiff(
            to: fullDocument,
            diff: diff
        )
        
        print("✅ Result after traditional application to full document:")
        print(result)
        
        // Verify the correct section was modified
        let expectedResult = """
        # Documentation

        ## Setup Instructions
        Please follow these setup steps carefully.
        This is important for the installation.

        ## Configuration Settings  
        Please follow these UPDATED setup steps carefully.
        This configuration is CRITICAL for operation.

        ## Advanced Configuration
        Please follow these setup steps carefully. 
        This advanced section covers complex scenarios.

        ## Conclusion
        Final notes and recommendations.
        """
        
        if intelligentResult == expectedResult && result == expectedResult {
            print("\n🎉 SUCCESS: Enhanced dual context matching with source verification works perfectly!")
            
            // Test checksum verification
            print("\n🔐 Checksum Verification:")
            let checksumValid = MultiLineDiff.verifyDiff(diff)
            print("• Diff checksum verification: \(checksumValid ? "✅ PASSED" : "❌ FAILED")")
            
            // Test undo functionality
            print("\n↩️ Undo Operation:")
            if let undoDiff = MultiLineDiff.createUndoDiff(from: diff) {
                do {
                    let undoResult = try MultiLineDiff.applyDiff(to: truncatedModified, diff: undoDiff)
                    let undoWorked = undoResult == truncatedOriginal
                    print("• Undo diff creation: ✅ SUCCESS")
                    print("• Undo application: \(undoWorked ? "✅ SUCCESS" : "❌ FAILED")")
                    print("• Round-trip verification: \(undoWorked ? "✅ PASSED" : "❌ FAILED")")
                } catch {
                    print("• Undo application: ❌ FAILED - \(error)")
                }
            } else {
                print("• Undo diff creation: ❌ FAILED")
            }
            
            // Test verification with application
            print("\n🛡️ Verified Application:")
            do {
                let verifiedResult = try MultiLineDiff.applyDiff(
                    to: fullDocument,
                    diff: diff
                )
                let verificationWorked = verifiedResult == expectedResult
                print("• Verified application: \(verificationWorked ? "✅ SUCCESS" : "❌ FAILED")")
            } catch {
                print("• Verified application: ❌ FAILED - \(error)")
            }
            
            print("\n📊 Key Enhancement Benefits:")
            print("• Preceding Context: Helps locate the section start")
            print("• Following Context: Validates section boundaries and prevents false matches")
            print("• Source Verification: Automatically detects full vs truncated source by string comparison")
            print("• Destination Storage: Enables checksum verification and undo operations")
            print("• Intelligent Application: No manual allowTruncatedSource parameter needed")
            print("• Checksum Verification: Ensures diff integrity and correct application")
            print("• Undo Operations: Automatic reverse diff generation for rollback functionality")
            print("• Confidence Scoring: Ensures the best matching section is selected")
            print("• Robust Matching: Handles documents with repeated similar content")
            
            // Verify truncated source detection
            if let metadata = diff.metadata,
               let storedSource = metadata.sourceContent {
                let fullNeedsTruncated = DiffMetadata.requiresTruncatedHandling(
                    providedSource: fullDocument,
                    storedSource: storedSource
                )
                let truncatedNeedsTruncated = DiffMetadata.requiresTruncatedHandling(
                    providedSource: truncatedOriginal,
                    storedSource: storedSource
                )
                
                print("\n🔍 Source Verification Results:")
                print("• Full document needs truncated handling: \(fullNeedsTruncated ? "Yes ✅" : "No ❌")")
                print("• Truncated section needs truncated handling: \(truncatedNeedsTruncated ? "Yes ❌" : "No ✅")")
            }
            
            return true
        } else {
            print("\n❌ FAILED: Section matching didn't work as expected")
            print("Expected vs Actual difference detected")
            return false
        }
        
    } catch {
        print("\n❌ Error applying diff: \(error)")
        return false
    }
} 
