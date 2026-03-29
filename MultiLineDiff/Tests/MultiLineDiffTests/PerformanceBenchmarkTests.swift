//
//  PerformanceBenchmarkTests.swift
//  MultiLineDiffTests
//
//  Created by Todd Bruss on 5/24/25.
//

import Testing
import Foundation
@testable import MultiLineDiff

struct PerformanceBenchmarkTests {
    
    @Test("Performance benchmark - Small strings")
    func benchmarkSmallStrings() throws {
        let iterations = 1000
        let source = "Hello World"
        let destination = "Hello Swift World"
        
        // Warm up
        for _ in 0..<10 {
            _ = MultiLineDiff.createDiffFromCollectionDifference(source: source, destination: destination)
        }
        
        let start = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiffFromCollectionDifference(source: source, destination: destination)
        }
        let time = Date().timeIntervalSince(start)
        
        print("🚀 Small strings (\(iterations) iterations): \(time * 1000)ms total, \((time * 1000) / Double(iterations))ms per operation")
    }
    
    @Test("Performance benchmark - Medium strings")
    func benchmarkMediumStrings() throws {
        let iterations = 100
        let source = """
        func calculateSum(numbers: [Int]) -> Int {
            var total = 0
            for number in numbers {
                total += number
            }
            return total
        }
        """
        
        let destination = """
        func calculateSum(values: [Int]) -> Int {
            var sum = 0
            for value in values {
                sum += value * 2
            }
            return sum
        }
        """
        
        // Warm up
        for _ in 0..<5 {
            _ = MultiLineDiff.createDiffFromCollectionDifference(source: source, destination: destination)
        }
        
        let start = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiffFromCollectionDifference(source: source, destination: destination)
        }
        let time = Date().timeIntervalSince(start)
        
        print("🚀 Medium strings (\(iterations) iterations): \(time * 1000)ms total, \((time * 1000) / Double(iterations))ms per operation")
    }
    
    @Test("Performance benchmark - Large strings")
    func benchmarkLargeStrings() throws {
        let iterations = 10
        
        // Generate large strings
        let baseText = """
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
                        .replacingOccurrences(of: "\n", with: "\\n")
                    
                    cache[input] = processed
                    return processed
                }
            }
        }
        """
        
        let source = String(repeating: baseText, count: 10)
        let destination = source.replacingOccurrences(of: "DataProcessor", with: "FastProcessor")
            .replacingOccurrences(of: "processData", with: "fastProcess")
            .replacingOccurrences(of: "uppercased", with: "lowercased")
        
        // Warm up
        for _ in 0..<2 {
            _ = MultiLineDiff.createDiffFromCollectionDifference(source: source, destination: destination)
        }
        
        let start = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiffFromCollectionDifference(source: source, destination: destination)
        }
        let time = Date().timeIntervalSince(start)
        
        print("🚀 Large strings (\(iterations) iterations): \(time * 1000)ms total, \((time * 1000) / Double(iterations))ms per operation")
        print("   Source length: \(source.count) characters")
        print("   Destination length: \(destination.count) characters")
    }
    
    @Test("Performance comparison - All Five Algorithms")
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
        
        let iterations = 100
        
        // Test all five algorithms
        var start = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
        }
        let brusTime = Date().timeIntervalSince(start)
        
        start = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
        }
        let toddTime = Date().timeIntervalSince(start)
        
        start = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .flash)
        }
        let sodaTime = Date().timeIntervalSince(start)
        
        start = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .starscream)
        }
        let lineTime = Date().timeIntervalSince(start)
        
        start = Date()
        for _ in 0..<iterations {
            _ = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .optimus)
        }
        let drewTime = Date().timeIntervalSince(start)
        
        print("🏁 Performance Comparison (\(iterations) iterations):")
        print("   Brus: \(brusTime * 1000)ms (\((brusTime * 1000) / Double(iterations))ms per op)")
        print("   Todd: \(toddTime * 1000)ms (\((toddTime * 1000) / Double(iterations))ms per op)")
        print("   Soda: \(sodaTime * 1000)ms (\((sodaTime * 1000) / Double(iterations))ms per op)")
        print("   Line: \(lineTime * 1000)ms (\((lineTime * 1000) / Double(iterations))ms per op)")
        print("   Drew: \(drewTime * 1000)ms (\((drewTime * 1000) / Double(iterations))ms per op)")
        
        // Find fastest
        let fastest = min(brusTime, toddTime, sodaTime, lineTime, drewTime)
        print("\n📊 Relative Speed (1.0 = fastest):")
        print("   Brus: \(String(format: "%.2f", brusTime / fastest))x")
        print("   Todd: \(String(format: "%.2f", toddTime / fastest))x")
        print("   Soda: \(String(format: "%.2f", sodaTime / fastest))x")
        print("   Line: \(String(format: "%.2f", lineTime / fastest))x")
        print("   Drew: \(String(format: "%.2f", drewTime / fastest))x")
        
        // Verify all produce correct results
        let result1 = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
        let result2 = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
        let result3 = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .flash)
        let result4 = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .starscream)
        let result5 = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .optimus)
        
        let applied1 = try MultiLineDiff.applyDiff(to: source, diff: result1)
        let applied2 = try MultiLineDiff.applyDiff(to: source, diff: result2)
        let applied3 = try MultiLineDiff.applyDiff(to: source, diff: result3)
        let applied4 = try MultiLineDiff.applyDiff(to: source, diff: result4)
        let applied5 = try MultiLineDiff.applyDiff(to: source, diff: result5)
        
        #expect(applied1 == destination, "Brus should produce correct result")
        #expect(applied2 == destination, "Todd should produce correct result")
        #expect(applied3 == destination, "Soda should produce correct result")
        #expect(applied4 == destination, "Line should produce correct result")
        #expect(applied5 == destination, "Drew should produce correct result")
        
        print("\n   All algorithms produce correct results: ✅")
        
        // Show operation counts
        print("\n📈 Operation Count Comparison:")
        print("   Brus: \(result1.operations.count) operations")
        print("   Todd: \(result2.operations.count) operations")
        print("   Soda: \(result3.operations.count) operations")
        print("   Line: \(result4.operations.count) operations")
        print("   Drew: \(result5.operations.count) operations")
    }
} 