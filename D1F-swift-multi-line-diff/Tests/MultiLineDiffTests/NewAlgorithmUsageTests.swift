//
//  NewAlgorithmUsageTests.swift
//  MultiLineDiffTests
//
//  Created by Todd Bruss on 5/24/25.
//

import Testing
import Foundation
@testable import MultiLineDiff

@Test func testNewAlgorithmUsage() throws {
    print("\n🚀 Testing New Algorithm Usage Through Main API")
    print("=" * 60)
    
    let source = """
    Hello, world!
    This is a test.
    Some content here.
    """
    
    let destination = """
    Hello, Swift!
    This is a test.
    Some modified content here.
    Additional line added.
    """
    
    // Test all algorithms through the main API
    print("\n🔥 Testing Brus Algorithm...")
    let brusDiff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
    let brusResult = try MultiLineDiff.applyDiff(to: source, diff: brusDiff)
    print("  Operations: \(brusDiff.operations.count)")
    #expect(brusResult == destination, "Brus should produce correct result")
    
    print("\n🧠 Testing Todd Algorithm...")
    let toddDiff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
    let toddResult = try MultiLineDiff.applyDiff(to: source, diff: toddDiff)
    print("  Operations: \(toddDiff.operations.count)")
    #expect(toddResult == destination, "Todd should produce correct result")
    
    print("\n🥤 Testing Soda Algorithm...")
    let sodaDiff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .flash)
    let sodaResult = try MultiLineDiff.applyDiff(to: source, diff: sodaDiff)
    print("  Operations: \(sodaDiff.operations.count)")
    #expect(sodaResult == destination, "Soda should produce correct result")
    
    print("\n📏 Testing Line Algorithm...")
    let lineDiff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .starscream)
    let lineResult = try MultiLineDiff.applyDiff(to: source, diff: lineDiff)
    print("  Operations: \(lineDiff.operations.count)")
    #expect(lineResult == destination, "Line should produce correct result")
    
    print("\n🎨 Testing Drew Algorithm...")
    let drewDiff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .optimus)
    let drewResult = try MultiLineDiff.applyDiff(to: source, diff: drewDiff)
    print("  Operations: \(drewDiff.operations.count)")
    #expect(drewResult == destination, "Drew should produce correct result")
    
    print("\n✅ All algorithms work correctly through main API!")
    
    // Show operation details
    print("\n📊 Algorithm Comparison:")
    print("  • Brus: \(brusDiff.operations.count) operations")
    print("  • Todd: \(toddDiff.operations.count) operations") 
    print("  • Soda: \(sodaDiff.operations.count) operations")
    print("  • Line: \(lineDiff.operations.count) operations")
    print("  • Drew: \(drewDiff.operations.count) operations")
}

@Test func testAlgorithmCharacteristics() throws {
    print("\n🔬 Testing Algorithm Characteristics")
    print("=" * 50)
    
    let source = "Line 1\nLine 2\nLine 3"
    let destination = "Line 1\nModified Line 2\nLine 3\nNew Line 4"
    
    // Test each algorithm and show their characteristics
    let algorithms: [(DiffAlgorithm, String)] = [
        (.zoom, "Brus (Fast & Simple)"),
        (.megatron, "Todd (Semantic)"),
        (.flash, "Soda (Swift Prefix)"),
        (.starscream, "Line (Swift Lines)"),
        (.optimus, "Drew (Swift Todd)")
    ]
    
    for (algorithm, name) in algorithms {
        let diff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: algorithm)
        let result = try MultiLineDiff.applyDiff(to: source, diff: diff)
        
        print("\n\(name):")
        print("  Operations: \(diff.operations.count)")
        print("  Result matches: \(result == destination ? "✅" : "❌")")
        
        // Show first few operations for insight
        let preview = diff.operations.prefix(3).map { op in
            switch op {
            case .retain(let count): return "retain(\(count))"
            case .delete(let count): return "delete(\(count))"
            case .insert(let text): return "insert(\"\(text.prefix(20))...\")"
            }
        }.joined(separator: ", ")
        print("  Preview: [\(preview)]")
        
        #expect(result == destination, "\(name) should produce correct result")
    }
} 