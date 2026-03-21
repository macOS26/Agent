//
//  CollectionDifferenceConverterTests.swift
//  MultiLineDiffTests
//
//  Created by Todd Bruss on 5/24/25.
//

import Testing
import Foundation
@testable import MultiLineDiff

struct CollectionDifferenceConverterTests {
    
    @Test("Basic string insertion")
    func testBasicInsertion() throws {
        let source = "Hello World"
        let destination = "Hello Todd's World"
        
        let result = MultiLineDiff.createDiffFromCollectionDifference(source: source, destination: destination)
        
        print("🧪 Test: Basic Insertion")
        print("Source: '\(source)'")
        print("Destination: '\(destination)'")
        print("Operations: \(formatOperations(result))")
        
        // Verify by applying the diff
        let applied = try MultiLineDiff.applyDiff(to: source, diff: result)
        #expect(applied == destination, "Applied diff should match destination")
        
        // Expected: [.retain(6), .insert("Todd's "), .retain(5)]
        #expect(result.operations.count >= 2, "Should have at least 2 operations")
    }
    
    @Test("Basic string deletion")
    func testBasicDeletion() throws {
        let source = "Hello Todd's World"
        let destination = "Hello World"
        
        let result = MultiLineDiff.createDiffFromCollectionDifference(source: source, destination: destination)
        
        print("\n🧪 Test: Basic Deletion")
        print("Source: '\(source)'")
        print("Destination: '\(destination)'")
        print("Operations: \(formatOperations(result))")
        
        // Verify by applying the diff
        let applied = try MultiLineDiff.applyDiff(to: source, diff: result)
        #expect(applied == destination, "Applied diff should match destination")
    }
    
    @Test("String replacement")
    func testStringReplacement() throws {
        let source = "Hello World"
        let destination = "Hello Swift"
        
        let result = MultiLineDiff.createDiffFromCollectionDifference(source: source, destination: destination)
        
        print("\n🧪 Test: String Replacement")
        print("Source: '\(source)'")
        print("Destination: '\(destination)'")
        print("Operations: \(formatOperations(result))")
        
        // Verify by applying the diff
        let applied = try MultiLineDiff.applyDiff(to: source, diff: result)
        #expect(applied == destination, "Applied diff should match destination")
    }
    
    @Test("Empty string cases")
    func testEmptyStringCases() throws {
        // Empty to non-empty
        let result1 = MultiLineDiff.createDiffFromCollectionDifference(source: "", destination: "Hello")
        print("\n🧪 Test: Empty to Non-empty")
        print("Operations: \(formatOperations(result1))")
        let applied1 = try MultiLineDiff.applyDiff(to: "", diff: result1)
        #expect(applied1 == "Hello", "Should insert 'Hello'")
        
        // Non-empty to empty
        let result2 = MultiLineDiff.createDiffFromCollectionDifference(source: "Hello", destination: "")
        print("\n🧪 Test: Non-empty to Empty")
        print("Operations: \(formatOperations(result2))")
        let applied2 = try MultiLineDiff.applyDiff(to: "Hello", diff: result2)
        #expect(applied2 == "", "Should delete everything")
        
        // Empty to empty
        let result3 = MultiLineDiff.createDiffFromCollectionDifference(source: "", destination: "")
        print("\n🧪 Test: Empty to Empty")
        print("Operations: \(formatOperations(result3))")
        let applied3 = try MultiLineDiff.applyDiff(to: "", diff: result3)
        #expect(applied3 == "", "Should remain empty")
    }
    
    @Test("Complex multi-operation diff")
    func testComplexDiff() throws {
        let source = "The quick brown fox"
        let destination = "The slow red fox jumps"
        
        let result = MultiLineDiff.createDiffFromCollectionDifference(source: source, destination: destination)
        
        print("\n🧪 Test: Complex Multi-operation")
        print("Source: '\(source)'")
        print("Destination: '\(destination)'")
        print("Operations: \(formatOperations(result))")
        
        // Verify by applying the diff
        let applied = try MultiLineDiff.applyDiff(to: source, diff: result)
        #expect(applied == destination, "Applied diff should match destination")
        
        // Print detailed breakdown
        print("Detailed operations:")
        for (i, op) in result.operations.enumerated() {
            print("  \(i): \(op.description)")
        }
    }
    
    @Test("Single character changes")
    func testSingleCharacterChanges() throws {
        let source = "cat"
        let destination = "bat"
        
        let result = MultiLineDiff.createDiffFromCollectionDifference(source: source, destination: destination)
        
        print("\n🧪 Test: Single Character Change")
        print("Source: '\(source)'")
        print("Destination: '\(destination)'")
        print("Operations: \(formatOperations(result))")
        
        // Verify by applying the diff
        let applied = try MultiLineDiff.applyDiff(to: source, diff: result)
        #expect(applied == destination, "Applied diff should match destination")
    }
    
    @Test("Identical strings")
    func testIdenticalStrings() throws {
        let source = "Hello World"
        let destination = "Hello World"
        
        let result = MultiLineDiff.createDiffFromCollectionDifference(source: source, destination: destination)
        
        print("\n🧪 Test: Identical Strings")
        print("Source: '\(source)'")
        print("Destination: '\(destination)'")
        print("Operations: \(formatOperations(result))")
        
        // Should only have retain operations
        let applied = try MultiLineDiff.applyDiff(to: source, diff: result)
        #expect(applied == destination, "Applied diff should match destination")
        
        // Check that we only have retain operations
        let hasOnlyRetains = result.operations.allSatisfy { operation in
            if case .retain = operation { return true }
            return false
        }
        #expect(hasOnlyRetains, "Identical strings should only have retain operations")
    }
    
    @Test("Performance comparison with existing Todd algorithm")
    func testPerformanceComparison() throws {
        let source = """
        func hello() {
            print("Hello World")
            let x = 42
            return x
        }
        """
        
        let destination = """
        func hello() {
            print("Hello Swift World")
            let y = 42
            let z = y * 2
            return z
        }
        """
        
        // Test our new converter
        let start1 = Date()
        let result1 = MultiLineDiff.createDiffFromCollectionDifference(source: source, destination: destination)
        let time1 = Date().timeIntervalSince(start1)
        
        // Test existing Todd algorithm
        let start2 = Date()
        let result2 = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
        let time2 = Date().timeIntervalSince(start2)
        
        print("\n🧪 Test: Performance Comparison")
        print("CollectionDifference converter time: \(time1 * 1000)ms")
        print("Todd algorithm time: \(time2 * 1000)ms")
        print("CollectionDifference operations: \(result1.operations.count)")
        print("Todd algorithm operations: \(result2.operations.count)")
        
        // Both should produce valid results
        let applied1 = try MultiLineDiff.applyDiff(to: source, diff: result1)
        let applied2 = try MultiLineDiff.applyDiff(to: source, diff: result2)
        
        #expect(applied1 == destination, "CollectionDifference result should be correct")
        #expect(applied2 == destination, "Todd algorithm result should be correct")
        
        print("Both algorithms produce correct results: ✅")
    }
} 