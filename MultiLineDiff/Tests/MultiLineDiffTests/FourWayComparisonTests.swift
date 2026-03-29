//
//  FourWayComparisonTests.swift
//  MultiLineDiffTests
//
//  Created by Todd Bruss on 5/24/25.
//

import Testing
import Foundation
@testable import MultiLineDiff

struct FourWayComparisonTests {
    
    @Test("All Five Algorithms - Five-Way Comparison")
    func compareAllFiveAlgorithms() throws {
        let source = """
        struct User {
            let id: Int
            let name: String
            let email: String
            
            func validate() -> Bool {
                return !name.isEmpty && email.contains("@")
            }
        }
        """
        
        let destination = """
        struct User {
            let id: UUID
            let fullName: String
            let emailAddress: String
            
            func isValid() -> Bool {
                return !fullName.isEmpty && emailAddress.contains("@")
            }
        }
        """
        
        print("🔬 Five-Way Algorithm Comparison")
        print("Source length: \(source.count) characters")
        print("Destination length: \(destination.count) characters")
        print()
        
        // Test all five algorithms
        let brusResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
        let toddResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
        let sodaResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .flash)
        let lineResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .starscream)
        let drewResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .optimus)
        
        print("🟦 \(AlgorithmNames.zoom): \(brusResult.operations.count) operations")
        print("🟩 \(AlgorithmNames.megatron): \(toddResult.operations.count) operations")
        print("🥤 \(AlgorithmNames.flash): \(sodaResult.operations.count) operations")
        print("📏 \(AlgorithmNames.starscream): \(lineResult.operations.count) operations")
        print("🎨 \(AlgorithmNames.optimus): \(drewResult.operations.count) operations")
        print()
        
        // Verify all produce correct results
        let appliedBrus = try MultiLineDiff.applyDiff(to: source, diff: brusResult)
        let appliedTodd = try MultiLineDiff.applyDiff(to: source, diff: toddResult)
        let appliedSoda = try MultiLineDiff.applyDiff(to: source, diff: sodaResult)
        let appliedLine = try MultiLineDiff.applyDiff(to: source, diff: lineResult)
        let appliedDrew = try MultiLineDiff.applyDiff(to: source, diff: drewResult)
        
        #expect(appliedBrus == destination, "\(AlgorithmNames.zoom) should produce correct result")
        #expect(appliedTodd == destination, "\(AlgorithmNames.megatron) should produce correct result")
        #expect(appliedSoda == destination, "\(AlgorithmNames.flash) should produce correct result")
        #expect(appliedLine == destination, "\(AlgorithmNames.starscream) should produce correct result")
        #expect(appliedDrew == destination, "\(AlgorithmNames.optimus) should produce correct result")
        
        print("✅ All algorithms produce correct results!")
        print()
        
        // Performance comparison
        let iterations = 1000
        
        // Brus performance
        let brusStart = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
        }
        let brusTime = Date().timeIntervalSince(brusStart)
        
        // Todd performance
        let toddStart = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
        }
        let toddTime = Date().timeIntervalSince(toddStart)
        
        // Soda performance
        let sodaStart = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .flash)
        }
        let sodaTime = Date().timeIntervalSince(sodaStart)
        
        // Line performance
        let lineStart = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .starscream)
        }
        let lineTime = Date().timeIntervalSince(lineStart)
        
        // Drew performance
        let drewStart = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .optimus)
        }
        let drewTime = Date().timeIntervalSince(drewStart)
        
        print("🏁 Performance Comparison (\(iterations) iterations):")
        print("   \(AlgorithmNames.zoom): \(String(format: "%6.2f", brusTime * 1000))ms (\(String(format: "%.4f", (brusTime * 1000) / Double(iterations)))ms per op)")
        print("   \(AlgorithmNames.megatron): \(String(format: "%6.2f", toddTime * 1000))ms (\(String(format: "%.4f", (toddTime * 1000) / Double(iterations)))ms per op)")
        print("   \(AlgorithmNames.flash): \(String(format: "%6.2f", sodaTime * 1000))ms (\(String(format: "%.4f", (sodaTime * 1000) / Double(iterations)))ms per op)")
        print("   \(AlgorithmNames.starscream): \(String(format: "%6.2f", lineTime * 1000))ms (\(String(format: "%.4f", (lineTime * 1000) / Double(iterations)))ms per op)")
        print("   \(AlgorithmNames.optimus): \(String(format: "%6.2f", drewTime * 1000))ms (\(String(format: "%.4f", (drewTime * 1000) / Double(iterations)))ms per op)")
        
        // Calculate relative speeds
        let fastest = min(brusTime, toddTime, sodaTime, lineTime, drewTime)
        print("\n📊 Relative Speed (1.0 = fastest):")
        print("   \(AlgorithmNames.zoom): \(String(format: "%.2f", brusTime / fastest))x")
        print("   \(AlgorithmNames.megatron): \(String(format: "%.2f", toddTime / fastest))x")
        print("   \(AlgorithmNames.flash): \(String(format: "%.2f", sodaTime / fastest))x")
        print("   \(AlgorithmNames.starscream): \(String(format: "%.2f", lineTime / fastest))x")
        print("   \(AlgorithmNames.optimus): \(String(format: "%.2f", drewTime / fastest))x")
        
        print("\n📈 Operation Count Comparison:")
        print("   \(AlgorithmNames.zoom): \(brusResult.operations.count) operations")
        print("   \(AlgorithmNames.megatron): \(toddResult.operations.count) operations")
        print("   \(AlgorithmNames.flash): \(sodaResult.operations.count) operations")
        print("   \(AlgorithmNames.starscream): \(lineResult.operations.count) operations")
        print("   \(AlgorithmNames.optimus): \(drewResult.operations.count) operations")
        
        // Show the actual operations for comparison
        print("\n🔍 Operation Details:")
        print("🟦 \(AlgorithmNames.zoom): \(formatOperations(brusResult))")
        print("🟩 \(AlgorithmNames.megatron): \(formatOperations(toddResult))")
        print("🥤 \(AlgorithmNames.flash): \(formatOperations(sodaResult))")
        print("📏 \(AlgorithmNames.starscream): \(formatOperations(lineResult))")
        print("🎨 \(AlgorithmNames.optimus): \(formatOperations(drewResult))")
    }
    
    @Test("Simple string test")
    func compareSimpleStrings() throws {
        let source = "Hello World"
        let destination = "Hello Swift World"
        
        print("🔬 Simple String Test")
        print("Source: '\(source)'")
        print("Destination: '\(destination)'")
        print()
        
        let brusResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
        let toddResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
        let sodaResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .flash)
        let lineResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .starscream)
        let drewResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .optimus)
        
        print("🟦 \(AlgorithmNames.zoom): \(formatOperations(brusResult))")
        print("🟩 \(AlgorithmNames.megatron): \(formatOperations(toddResult))")
        print("🥤 \(AlgorithmNames.flash): \(formatOperations(sodaResult))")
        print("📏 \(AlgorithmNames.starscream): \(formatOperations(lineResult))")
        print("🎨 \(AlgorithmNames.optimus): \(formatOperations(drewResult))")
        
        // Verify correctness
        let appliedBrus = try MultiLineDiff.applyDiff(to: source, diff: brusResult)
        let appliedTodd = try MultiLineDiff.applyDiff(to: source, diff: toddResult)
        let appliedSoda = try MultiLineDiff.applyDiff(to: source, diff: sodaResult)
        let appliedLine = try MultiLineDiff.applyDiff(to: source, diff: lineResult)
        let appliedDrew = try MultiLineDiff.applyDiff(to: source, diff: drewResult)
        
        #expect(appliedBrus == destination, "\(AlgorithmNames.zoom) should work")
        #expect(appliedTodd == destination, "\(AlgorithmNames.megatron) should work")
        #expect(appliedSoda == destination, "\(AlgorithmNames.flash) should work")
        #expect(appliedLine == destination, "\(AlgorithmNames.starscream) should work")
        #expect(appliedDrew == destination, "\(AlgorithmNames.optimus) should work")
        
        print("✅ All correct!")
    }
    
    @Test("Speed test on large strings")
    func speedTestLargeStrings() throws {
        // Generate large test strings
        let baseText = "The quick brown fox jumps over the lazy dog. "
        let source = String(repeating: baseText, count: 1000) // ~45KB
        let destination = source.replacingOccurrences(of: "quick brown", with: "slow red")
            .replacingOccurrences(of: "lazy dog", with: "active cat")
        
        print("🚀 Large String Speed Test")
        print("Source length: \(source.count) characters")
        print("Destination length: \(destination.count) characters")
        print()
        
        let iterations = 10
        
        // Test each algorithm
        let algorithms: [(name: String, test: () -> DiffResult)] = [
            (AlgorithmNames.zoom, { MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom) }),
            (AlgorithmNames.megatron, { MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron) }),
            (AlgorithmNames.flash, { MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .flash) }),
            (AlgorithmNames.starscream, { MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .starscream) }),
            (AlgorithmNames.optimus, { MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .optimus) })
        ]
        
        for (name, test) in algorithms {
            let start = Date()
            var result: DiffResult?
            for _ in 0..<iterations {
                result = test()
            }
            let time = Date().timeIntervalSince(start)
            
            // Verify correctness
            if let result = result {
                let applied = try MultiLineDiff.applyDiff(to: source, diff: result)
                let isCorrect = applied == destination
                print("   \(name): \(String(format: "%6.1f", time * 1000))ms (\(String(format: "%.1f", (time * 1000) / Double(iterations)))ms per op) - \(result.operations.count) ops - \(isCorrect ? "✅" : "❌")")
            }
        }
    }
} 