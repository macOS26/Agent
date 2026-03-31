//
//  SixWayComparisonTests.swift
//  MultiLineDiffTests
//
//  Created by Todd Bruss on 5/24/25.
//

import Testing
import Foundation
@testable import MultiLineDiff

@Test func testFiveWayAlgorithmComparison() throws {
    print("\n🚀 Five-Way Algorithm Comparison - All Approaches")
    print("=" * 80)
    
    // Generate test content
    let (originalContent, modifiedContent) = generateTestSwiftFiles()
    
    print("📊 Generated Files:")
    print("  • Original: \(originalContent.count) characters, \(originalContent.components(separatedBy: "\n").count) lines")
    print("  • Modified: \(modifiedContent.count) characters, \(modifiedContent.components(separatedBy: "\n").count) lines")
    
    let iterations = 100
    
    // Test all six algorithms
    print("\n🔥 Testing \(AlgorithmNames.zoom) Algorithm (\(iterations) iterations)...")
    let brusResults = testSixWayAlgorithmPerformance(
        source: originalContent,
        destination: modifiedContent,
        algorithmName: AlgorithmNames.zoom,
        testFunction: { source, dest in
            MultiLineDiff.createDiff(source: source, destination: dest, algorithm: .zoom)
        },
        iterations: iterations
    )
    
    print("\n🧠 Testing \(AlgorithmNames.megatron) Algorithm (\(iterations) iterations)...")
    let toddResults = testSixWayAlgorithmPerformance(
        source: originalContent,
        destination: modifiedContent,
        algorithmName: AlgorithmNames.megatron,
        testFunction: { source, dest in
            MultiLineDiff.createDiff(source: source, destination: dest, algorithm: .megatron)
        },
        iterations: iterations
    )
    

    
    print("\n🥤 Testing \(AlgorithmNames.flash) Algorithm (\(iterations) iterations)...")
    let sodaResults = testSixWayAlgorithmPerformance(
        source: originalContent,
        destination: modifiedContent,
        algorithmName: AlgorithmNames.flash,
        testFunction: { source, dest in
            MultiLineDiff.createDiff(source: source, destination: dest, algorithm: .flash)
        },
        iterations: iterations
    )
    
    print("\n📏 Testing \(AlgorithmNames.starscream) Algorithm (\(iterations) iterations)...")
    let lineResults = testSixWayAlgorithmPerformance(
        source: originalContent,
        destination: modifiedContent,
        algorithmName: AlgorithmNames.starscream,
        testFunction: { source, dest in
            MultiLineDiff.createDiff(source: source, destination: dest, algorithm: .starscream)
        },
        iterations: iterations
    )
    
    print("\n🎨 Testing \(AlgorithmNames.optimus) Algorithm (\(iterations) iterations)...")
    let drewResults = testSixWayAlgorithmPerformance(
        source: originalContent,
        destination: modifiedContent,
        algorithmName: AlgorithmNames.optimus,
        testFunction: { source, dest in
            MultiLineDiff.createDiff(source: source, destination: dest, algorithm: .optimus)
        },
        iterations: iterations
    )
    
    // Print comprehensive results
    printFiveWayAlgorithmResults(
        brusResults: brusResults,
        toddResults: toddResults,
        sodaResults: sodaResults,
        lineResults: lineResults,
        drewResults: drewResults,
        iterations: iterations
    )
    
    // Verify all algorithms produce correct results
    #expect(brusResults.finalResult == modifiedContent, "\(AlgorithmNames.zoom) algorithm should produce correct result")
    #expect(toddResults.finalResult == modifiedContent, "\(AlgorithmNames.megatron) algorithm should produce correct result")
    #expect(sodaResults.finalResult == modifiedContent, "\(AlgorithmNames.flash) algorithm should produce correct result")
    #expect(lineResults.finalResult == modifiedContent, "\(AlgorithmNames.starscream) algorithm should produce correct result")
    #expect(drewResults.finalResult == modifiedContent, "\(AlgorithmNames.optimus) algorithm should produce correct result")
    
    print("\n✅ All algorithms produce correct results!")
}

// MARK: - Test File Generation

private func generateTestSwiftFiles() -> (original: String, modified: String) {
    let original = generateTestSwiftFile()
    let modified = createModifiedTestVersion(of: original)
    return (original, modified)
}

private func generateTestSwiftFile() -> String {
    var lines: [String] = []
    
    // File header
    lines.append("//")
    lines.append("//  TestSwiftFile.swift")
    lines.append("//  SixWayComparison")
    lines.append("//")
    lines.append("")
    lines.append("import Foundation")
    lines.append("import UIKit")
    lines.append("")
    
    // Generate test classes
    for classIndex in 1...5 {
        lines.append(contentsOf: generateTestClass(index: classIndex))
        lines.append("")
    }
    
    // Generate test structs
    for structIndex in 1...3 {
        lines.append(contentsOf: generateTestStruct(index: structIndex))
        lines.append("")
    }
    
    // Generate test enums
    for enumIndex in 1...2 {
        lines.append(contentsOf: generateTestEnum(index: enumIndex))
        lines.append("")
    }
    
    return lines.joined(separator: "\n")
}

private func generateTestClass(index: Int) -> [String] {
    return [
        "/// Test class \(index)",
        "class TestClass\(index): NSObject {",
        "    var identifier: String = \"class_\(index)\"",
        "    var value: Int = \(index * 10)",
        "    var data: [String] = []",
        "    ",
        "    override init() {",
        "        super.init()",
        "        setupData()",
        "    }",
        "    ",
        "    func calculate(multiplier: Int) -> Int {",
        "        return value * multiplier",
        "    }",
        "    ",
        "    func process(_ input: String) -> String {",
        "        return \"Processed: \\(input)\"",
        "    }",
        "    ",
        "    private func setupData() {",
        "        data = [\"item1\", \"item2\", \"item3\"]",
        "    }",
        "}"
    ]
}

private func generateTestStruct(index: Int) -> [String] {
    return [
        "/// Test struct \(index)",
        "struct TestStruct\(index): Codable {",
        "    let id: UUID",
        "    var name: String",
        "    var active: Bool",
        "    ",
        "    init() {",
        "        self.id = UUID()",
        "        self.name = \"TestStruct\\(index)\"",
        "        self.active = true",
        "    }",
        "    ",
        "    mutating func toggle() {",
        "        active.toggle()",
        "    }",
        "}"
    ]
}

private func generateTestEnum(index: Int) -> [String] {
    return [
        "/// Test enum \(index)",
        "enum TestEnum\(index): String, CaseIterable {",
        "    case option1 = \"option1_\\(index)\"",
        "    case option2 = \"option2_\\(index)\"",
        "    ",
        "    var displayName: String {",
        "        switch self {",
        "        case .option1: return \"First Option\"",
        "        case .option2: return \"Second Option\"",
        "        }",
        "    }",
        "}"
    ]
}

private func createModifiedTestVersion(of original: String) -> String {
    var lines = original.components(separatedBy: "\n")
    
    // Modification 1: Change method implementations
    for i in 0..<lines.count {
        if lines[i].contains("func calculate(multiplier: Int) -> Int {") && i + 1 < lines.count {
            lines[i+1] = "        return value * multiplier * 2 // Enhanced"
        }
        if lines[i].contains("func process(_ input: String) -> String {") && i + 1 < lines.count {
            lines[i+1] = "        return \"ENHANCED: \\(input) by \\(identifier)\""
        }
    }
    
    // Modification 2: Add new properties
    var insertionOffset = 0
    for i in 0..<lines.count {
        let adjustedIndex = i + insertionOffset
        if adjustedIndex < lines.count && lines[adjustedIndex].contains("var data: [String] = []") {
            let newLines = [
                "    var enhancedProperty: String = \"enhanced\"",
                "    var additionalValue: Int = 42"
            ]
            lines.insert(contentsOf: newLines, at: adjustedIndex + 1)
            insertionOffset += newLines.count
        }
    }
    
    // Modification 3: Change enum cases
    for i in 0..<lines.count {
        if lines[i].contains("case option1 = \"option1_") {
            lines[i] = lines[i].replacingOccurrences(of: "option1_", with: "enhanced_option1_")
        }
    }
    
    // Modification 4: Add new content
    lines.append("")
    lines.append("// MARK: - Enhanced Extensions")
    lines.append("extension TestClass1 {")
    lines.append("    func advancedCalculation() -> Int {")
    lines.append("        return value * 100")
    lines.append("    }")
    lines.append("}")
    
    return lines.joined(separator: "\n")
}

// MARK: - Performance Testing Infrastructure

struct SixWayAlgorithmResults {
    let algorithmName: String
    let createTimes: [TimeInterval]
    let applyTimes: [TimeInterval]
    let totalTimes: [TimeInterval]
    let operationCounts: [Int]
    let finalResult: String
    let averageCreateTime: TimeInterval
    let averageApplyTime: TimeInterval
    let averageTotalTime: TimeInterval
    let averageOperationCount: Double
    
    init(algorithmName: String, createTimes: [TimeInterval], applyTimes: [TimeInterval], operationCounts: [Int], finalResult: String) {
        self.algorithmName = algorithmName
        self.createTimes = createTimes
        self.applyTimes = applyTimes
        self.totalTimes = zip(createTimes, applyTimes).map { $0 + $1 }
        self.operationCounts = operationCounts
        self.finalResult = finalResult
        self.averageCreateTime = createTimes.reduce(0, +) / Double(createTimes.count)
        self.averageApplyTime = applyTimes.reduce(0, +) / Double(applyTimes.count)
        self.averageTotalTime = totalTimes.reduce(0, +) / Double(totalTimes.count)
        self.averageOperationCount = Double(operationCounts.reduce(0, +)) / Double(operationCounts.count)
    }
}

private func testSixWayAlgorithmPerformance(
    source: String,
    destination: String,
    algorithmName: String,
    testFunction: (String, String) -> DiffResult,
    iterations: Int
) -> SixWayAlgorithmResults {
    var createTimes: [TimeInterval] = []
    var applyTimes: [TimeInterval] = []
    var operationCounts: [Int] = []
    var finalResult = ""
    
    // Warm up run
    let warmupDiff = testFunction(source, destination)
    _ = try! MultiLineDiff.applyDiff(to: source, diff: warmupDiff)
    
    // Run performance tests
    for iteration in 1...iterations {
        if iteration % 25 == 0 {
            print("  ⏱️  \(algorithmName) iteration \(iteration)/\(iterations)")
        }
        
        // Measure diff creation time
        let createStartTime = Date()
        let diff = testFunction(source, destination)
        let createTime = Date().timeIntervalSince(createStartTime)
        createTimes.append(createTime)
        operationCounts.append(diff.operations.count)
        
        // Measure diff application time
        let applyStartTime = Date()
        let result = try! MultiLineDiff.applyDiff(to: source, diff: diff)
        let applyTime = Date().timeIntervalSince(applyStartTime)
        applyTimes.append(applyTime)
        
        // Store final result for verification (from last iteration)
        if iteration == iterations {
            finalResult = result
        }
    }
    
    return SixWayAlgorithmResults(
        algorithmName: algorithmName,
        createTimes: createTimes,
        applyTimes: applyTimes,
        operationCounts: operationCounts,
        finalResult: finalResult
    )
}

private func printFiveWayAlgorithmResults(
    brusResults: SixWayAlgorithmResults,
    toddResults: SixWayAlgorithmResults,
    sodaResults: SixWayAlgorithmResults,
    lineResults: SixWayAlgorithmResults,
    drewResults: SixWayAlgorithmResults,
    iterations: Int
) {
    print("\n📊 PERFORMANCE RESULTS - ALL 5 ALGORITHMS (\(iterations) iterations)")
    print("=" * 90)
    
    // Algorithm comparison table
    print("\n🏆 Algorithm Performance Comparison:")
    print("┌─────────────────────────┬─────────────┬─────────────┬─────────────┬─────────────┐")
    print("│ Algorithm               │ Create (ms) │ Apply (ms)  │ Total (ms)  │ Operations  │")
    print("├─────────────────────────┼─────────────┼─────────────┼─────────────┼─────────────┤")
    
    let algorithms = [brusResults, toddResults, sodaResults, lineResults, drewResults]
    
    for result in algorithms {
        let createMs = String(format: "%.3f", result.averageCreateTime * 1000)
        let applyMs = String(format: "%.3f", result.averageApplyTime * 1000)
        let totalMs = String(format: "%.3f", result.averageTotalTime * 1000)
        let ops = String(format: "%.0f", result.averageOperationCount)
        
        let name = result.algorithmName.padding(toLength: 23, withPad: " ", startingAt: 0)
        let createPad = createMs.padding(toLength: 11, withPad: " ", startingAt: 0)
        let applyPad = applyMs.padding(toLength: 11, withPad: " ", startingAt: 0)
        let totalPad = totalMs.padding(toLength: 11, withPad: " ", startingAt: 0)
        let opsPad = ops.padding(toLength: 11, withPad: " ", startingAt: 0)
        
        print("│ \(name) │ \(createPad) │ \(applyPad) │ \(totalPad) │ \(opsPad) │")
    }
    
    print("└─────────────────────────┴─────────────┴─────────────┴─────────────┴─────────────┘")
    
    // Find the fastest algorithm for each metric
    let fastestCreate = algorithms.min(by: { $0.averageCreateTime < $1.averageCreateTime })!
    let fastestApply = algorithms.min(by: { $0.averageApplyTime < $1.averageApplyTime })!
    let fastestTotal = algorithms.min(by: { $0.averageTotalTime < $1.averageTotalTime })!
    let fewestOps = algorithms.min(by: { $0.averageOperationCount < $1.averageOperationCount })!
    
    print("\n🏅 Winners:")
    print("  • Fastest Create: \(fastestCreate.algorithmName) (\(String(format: "%.3f", fastestCreate.averageCreateTime * 1000))ms)")
    print("  • Fastest Apply:  \(fastestApply.algorithmName) (\(String(format: "%.3f", fastestApply.averageApplyTime * 1000))ms)")
    print("  • Fastest Total:  \(fastestTotal.algorithmName) (\(String(format: "%.3f", fastestTotal.averageTotalTime * 1000))ms)")
    print("  • Fewest Ops:     \(fewestOps.algorithmName) (\(String(format: "%.0f", fewestOps.averageOperationCount)) operations)")
    
    // Speed ratios compared to fastest
    print("\n📈 Speed Ratios (relative to fastest):")
    
    for result in algorithms {
        let createRatio = result.averageCreateTime / fastestCreate.averageCreateTime
        let applyRatio = result.averageApplyTime / fastestApply.averageApplyTime
        let totalRatio = result.averageTotalTime / fastestTotal.averageTotalTime
        
        print("  \(result.algorithmName):")
        print("    Create: \(String(format: "%.2f", createRatio))x")
        print("    Apply:  \(String(format: "%.2f", applyRatio))x")
        print("    Total:  \(String(format: "%.2f", totalRatio))x")
    }
    
    // Operation count comparison
    print("\n📊 Operation Count Analysis:")
    for result in algorithms {
        let ratio = result.averageOperationCount / fewestOps.averageOperationCount
        print("  \(result.algorithmName): \(String(format: "%.0f", result.averageOperationCount)) operations (\(String(format: "%.2f", ratio))x)")
    }
    
    // Show actual operations for comparison
    print("\n🔍 Sample Operation Details:")
    let sampleSource = "Hello World\nLine 2\nLine 3"
    let sampleDest = "Hello Swift World\nLine 2 Modified\nLine 3"
    
    let sampleResults = [
        (AlgorithmNames.zoom, MultiLineDiff.createDiff(source: sampleSource, destination: sampleDest, algorithm: .zoom)),
        (AlgorithmNames.megatron, MultiLineDiff.createDiff(source: sampleSource, destination: sampleDest, algorithm: .megatron)),
        (AlgorithmNames.flash, MultiLineDiff.createDiff(source: sampleSource, destination: sampleDest, algorithm: .flash)),
        (AlgorithmNames.starscream, MultiLineDiff.createDiff(source: sampleSource, destination: sampleDest, algorithm: .starscream)),
        (AlgorithmNames.optimus, MultiLineDiff.createDiff(source: sampleSource, destination: sampleDest, algorithm: .optimus))
    ]
    
    for (name, result) in sampleResults {
        print("  \(name): \(formatOperations(result))")
    }
} 