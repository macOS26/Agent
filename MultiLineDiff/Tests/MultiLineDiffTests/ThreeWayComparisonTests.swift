//
//  ThreeWayComparisonTests.swift
//  MultiLineDiffTests
//
//  Created by Todd Bruss on 5/24/25.
//

import Testing
import Foundation
@testable import MultiLineDiff

struct ThreeWayComparisonTests {
    
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
        print("Source lines: \(source.split(separator: "\n").count)")
        print("Destination lines: \(destination.split(separator: "\n").count)")
        print()
        
        // Test all five algorithms
        let brusResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
        print("🟦 Brus Algorithm (Character-based, O(n)):")
        print("   Operations count: \(brusResult.operations.count)")
        print("   Algorithm used: \(brusResult.metadata?.algorithmUsed ?? .zoom)")
        print("   Operations:")
        for (i, op) in brusResult.operations.enumerated() {
            print("     \(i): \(op.description)")
        }
        
        let toddResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
        print("\n🟩 Todd Algorithm (Line-based, O(n log n)):")
        print("   Operations count: \(toddResult.operations.count)")
        print("   Algorithm used: \(toddResult.metadata?.algorithmUsed ?? .megatron)")
        print("   Operations:")
        for (i, op) in toddResult.operations.enumerated() {
            print("     \(i): \(op.description)")
        }
        
        let sodaResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .flash)
        print("\n🥤 Soda Algorithm (Swift Prefix-based):")
        print("   Operations count: \(sodaResult.operations.count)")
        print("   Algorithm used: \(sodaResult.metadata?.algorithmUsed ?? .flash)")
        print("   Operations:")
        for (i, op) in sodaResult.operations.enumerated() {
            print("     \(i): \(op.description)")
        }
        
        let lineResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .starscream)
        print("\n📏 Line Algorithm (Swift Lines-based):")
        print("   Operations count: \(lineResult.operations.count)")
        print("   Algorithm used: \(lineResult.metadata?.algorithmUsed ?? .starscream)")
        print("   Operations:")
        for (i, op) in lineResult.operations.enumerated() {
            print("     \(i): \(op.description)")
        }
        
        let drewResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .optimus)
        print("\n🎨 Drew Algorithm (Swift Lines+Diff):")
        print("   Operations count: \(drewResult.operations.count)")
        print("   Algorithm used: \(drewResult.metadata?.algorithmUsed ?? .optimus)")
        print("   Operations:")
        for (i, op) in drewResult.operations.enumerated() {
            print("     \(i): \(op.description)")
        }
        
        // Verify all produce correct results
        let appliedBrus = try MultiLineDiff.applyDiff(to: source, diff: brusResult)
        let appliedTodd = try MultiLineDiff.applyDiff(to: source, diff: toddResult)
        let appliedSoda = try MultiLineDiff.applyDiff(to: source, diff: sodaResult)
        let appliedLine = try MultiLineDiff.applyDiff(to: source, diff: lineResult)
        let appliedDrew = try MultiLineDiff.applyDiff(to: source, diff: drewResult)
        
        #expect(appliedBrus == destination, "Brus should produce correct result")
        #expect(appliedTodd == destination, "Todd should produce correct result")
        #expect(appliedSoda == destination, "Soda should produce correct result")
        #expect(appliedLine == destination, "Line should produce correct result")
        #expect(appliedDrew == destination, "Drew should produce correct result")
        
        print("\n✅ All algorithms produce correct results!")
        
        // Performance comparison
        let iterations = 100
        
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
        
        print("\n🏁 Performance Comparison (\(iterations) iterations):")
        print("   Brus: \(String(format: "%.2f", brusTime * 1000))ms total (\(String(format: "%.3f", (brusTime * 1000) / Double(iterations)))ms per op)")
        print("   Todd: \(String(format: "%.2f", toddTime * 1000))ms total (\(String(format: "%.3f", (toddTime * 1000) / Double(iterations)))ms per op)")
        print("   Soda: \(String(format: "%.2f", sodaTime * 1000))ms total (\(String(format: "%.3f", (sodaTime * 1000) / Double(iterations)))ms per op)")
        print("   Line: \(String(format: "%.2f", lineTime * 1000))ms total (\(String(format: "%.3f", (lineTime * 1000) / Double(iterations)))ms per op)")
        print("   Drew: \(String(format: "%.2f", drewTime * 1000))ms total (\(String(format: "%.3f", (drewTime * 1000) / Double(iterations)))ms per op)")
        
        // Calculate relative speeds
        let fastest = min(brusTime, toddTime, sodaTime, lineTime, drewTime)
        print("\n📊 Relative Speed (1.0 = fastest):")
        print("   Brus: \(String(format: "%.2f", brusTime / fastest))x")
        print("   Todd: \(String(format: "%.2f", toddTime / fastest))x")
        print("   Soda: \(String(format: "%.2f", sodaTime / fastest))x")
        print("   Line: \(String(format: "%.2f", lineTime / fastest))x")
        print("   Drew: \(String(format: "%.2f", drewTime / fastest))x")
        
        print("\n📈 Operation Count Comparison:")
        print("   Brus: \(brusResult.operations.count) operations")
        print("   Todd: \(toddResult.operations.count) operations")
        print("   Soda: \(sodaResult.operations.count) operations")
        print("   Line: \(lineResult.operations.count) operations")
        print("   Drew: \(drewResult.operations.count) operations")
    }
    
    @Test("Small string comparison")
    func compareSmallStrings() throws {
        let source = "Hello World"
        let destination = "Hello Swift World"
        
        print("🔬 Small String Comparison")
        print("Source: '\(source)'")
        print("Destination: '\(destination)'")
        print()
        
        let brusResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
        let toddResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
        
        print("🟦 Brus: \(formatOperations(brusResult))")
        print("🟩 Todd: \(formatOperations(toddResult))")
        
        // Verify correctness
        let appliedBrus = try MultiLineDiff.applyDiff(to: source, diff: brusResult)
        let appliedTodd = try MultiLineDiff.applyDiff(to: source, diff: toddResult)
        
        #expect(appliedBrus == destination, "Brus should work on small strings")
        #expect(appliedTodd == destination, "Todd should work on small strings")
        
        print("✅ All correct!")
    }
    
    @Test("Large string performance test")
    func compareLargeStrings() throws {
        // Generate larger test content
        let baseCode = """
        import Foundation
        
        class DataProcessor {
            private var cache: [String: Any] = [:]
            private let queue = DispatchQueue(label: "processor")
            
            func processData(_ input: String) -> String {
                return queue.sync {
                    if let cached = cache[input] as? String {
                        return cached
                    }
                    
                    let processed = input.uppercased()
                        .replacingOccurrences(of: " ", with: "_")
                        .replacingOccurrences(of: "\\n", with: "\\\\n")
                    
                    cache[input] = processed
                    return processed
                }
            }
            
            func clearCache() {
                cache.removeAll()
            }
        }
        """
        
        let source = String(repeating: baseCode, count: 5)
        let destination = source
            .replacingOccurrences(of: "DataProcessor", with: "FastProcessor")
            .replacingOccurrences(of: "processData", with: "fastProcess")
            .replacingOccurrences(of: "uppercased", with: "lowercased")
            .replacingOccurrences(of: "clearCache", with: "resetCache")
        
        print("🔬 Large String Performance Test")
        print("Source length: \(source.count) characters")
        print("Destination length: \(destination.count) characters")
        print("Source lines: \(source.split(separator: "\n").count)")
        print()
        
        let iterations = 10
        
        // Performance test
        let brusStart = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
        }
        let brusTime = Date().timeIntervalSince(brusStart)
        
        let toddStart = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
        }
        let toddTime = Date().timeIntervalSince(toddStart)
        
        print("🏁 Large String Performance (\(iterations) iterations):")
        print("   Brus:  \(String(format: "%.1f", brusTime * 1000))ms (\(String(format: "%.1f", (brusTime * 1000) / Double(iterations)))ms per op)")
        print("   Todd:  \(String(format: "%.1f", toddTime * 1000))ms (\(String(format: "%.1f", (toddTime * 1000) / Double(iterations)))ms per op)")
        
        // Test one result for correctness
        let testResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
        let applied = try MultiLineDiff.applyDiff(to: source, diff: testResult)
        #expect(applied == destination, "Large string diff should be correct")
        
        print("✅ Large string test passed!")
    }
} 