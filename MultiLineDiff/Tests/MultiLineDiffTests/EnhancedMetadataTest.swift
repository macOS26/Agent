import Testing
@testable import MultiLineDiff

/// Test for enhanced metadata in parseDiffFromASCII
struct EnhancedMetadataTest {
    
    @Test("Verify enhanced metadata in parseDiffFromASCII")
    func testEnhancedMetadata() throws {
        print("\n🧪 Testing Enhanced Metadata in parseDiffFromASCII")
        print(String(repeating: "=", count: 60))
        
        // Create a test ASCII diff
        let asciiDiff = """
        =class Calculator {
        =    private var result: Double = 0
        -    func add(_ value: Double) {
        -        result += value
        -    }
        +    func add(_ value: Double) -> Double {
        +        result += value
        +        return result
        +    }
        =    func getResult() -> Double {
        =        return result
        =    }
        =}
        """
        
        print("📄 ASCII Diff Input:")
        print(asciiDiff)
        
        // Parse the ASCII diff
        let diffResult = try MultiLineDiff.parseDiffFromASCII(asciiDiff)
        
        // Verify we have metadata
        guard let metadata = diffResult.metadata else {
            #expect(Bool(false), "Metadata should not be nil")
            return
        }
        
        print("\n✨ ENHANCED METADATA RESULTS:")
        
        // Test source content
        let expectedSource = """
        class Calculator {
            private var result: Double = 0
            func add(_ value: Double) {
                result += value
            }
            func getResult() -> Double {
                return result
            }
        }
        """
        
        print("\n1. 📝 Source Content:")
        print("Expected: '\(expectedSource)'")
        print("Actual: '\(metadata.sourceContent ?? "nil")'")
        #expect(metadata.sourceContent == expectedSource, "Source content should match")
        
        // Test destination content
        let expectedDestination = """
        class Calculator {
            private var result: Double = 0
            func add(_ value: Double) -> Double {
                result += value
                return result
            }
            func getResult() -> Double {
                return result
            }
        }
        """
        
        print("\n2. 📝 Destination Content:")
        print("Expected: '\(expectedDestination)'")
        print("Actual: '\(metadata.destinationContent ?? "nil")'")
        #expect(metadata.destinationContent == expectedDestination, "Destination content should match")
        
        // Test preceding context (first line)
        print("\n3. 📍 Preceding Context:")
        print("Expected: 'class Calculator {'")
        print("Actual: '\(metadata.precedingContext ?? "nil")'")
        #expect(metadata.precedingContext == "class Calculator {", "Preceding context should be first line")
        
        // Test following context (last line)
        print("\n4. 📍 Following Context:")
        print("Expected: '}'")
        print("Actual: '\(metadata.followingContext ?? "nil")'")
        #expect(metadata.followingContext == "}", "Following context should be last line")
        
        // Test source start line (where modifications begin)
        print("\n5. 📍 Source Start Line (where modifications begin):")
        print("Expected: 2 (0-indexed, after 2 retain lines, first delete/insert occurs)")
        print("Actual: \(metadata.sourceStartLine ?? -1)")
        print("Display: Line \((metadata.sourceStartLine ?? -1) + 1) (1-indexed for users)")
        #expect(metadata.sourceStartLine == 2, "Should start at line 2 (0-indexed) where modifications begin")
        
        // Test source total lines
        print("\n6. 📊 Source Total Lines:")
        print("Expected: 9")
        print("Actual: \(metadata.sourceTotalLines ?? 0)")
        #expect(metadata.sourceTotalLines == 9, "Should have 9 source lines")
        
        // Test algorithm used
        print("\n7. 🔧 Algorithm Used:")
        print("Expected: .megatron")
        print("Actual: \(metadata.algorithmUsed?.displayName ?? "nil")")
        #expect(metadata.algorithmUsed == .megatron, "Should use megatron algorithm")
        
        // Test application type
        print("\n8. 🎯 Application Type:")
        print("Expected: .requiresFullSource")
        print("Actual: \(metadata.applicationType?.rawValue ?? "nil")")
        #expect(metadata.applicationType == .requiresFullSource, "Should require full source")
        
        // Test that we can verify the diff using the metadata
        print("\n9. 🔍 Diff Verification:")
        let verificationResult = DiffMetadata.verifyDiffChecksum(
            diff: diffResult,
            storedSource: metadata.sourceContent,
            storedDestination: metadata.destinationContent
        )
        print("Verification result: \(verificationResult)")
        #expect(verificationResult, "Diff should verify correctly with stored content")
        
        print("\n💡 METADATA SUMMARY:")
        print("✅ Source content: \(metadata.sourceContent?.count ?? 0) characters")
        print("✅ Destination content: \(metadata.destinationContent?.count ?? 0) characters")
        print("✅ Preceding context: '\(metadata.precedingContext ?? "nil")'")
        print("✅ Following context: '\(metadata.followingContext ?? "nil")'")
        print("✅ Source start line: \(metadata.sourceStartLine ?? -1)")
        print("✅ Source lines: \(metadata.sourceTotalLines ?? 0)")
        print("✅ Algorithm: \(metadata.algorithmUsed?.displayName ?? "nil")")
        print("✅ Application type: \(metadata.applicationType?.rawValue ?? "nil")")
        print("✅ Verification: \(verificationResult ? "✅" : "❌")")
        
        print("\n🎉 Enhanced metadata test completed successfully!")
    }
} 