//
//  ComprehensiveLargeFilePerformanceTests.swift
//  MultiLineDiffTests
//
//  Created by Todd Bruss on 5/24/25.
//

import Testing
import Foundation
@testable import MultiLineDiff

@Test func testComprehensiveLargeFilePerformanceComparison() throws {
    print("\n🚀 Comprehensive Large File Performance Test - All 5 Algorithms")
    print("=" * 80)
    
    // Generate large Swift file content (same as original test)
    let (originalContent, modifiedContent) = generateLargeSwiftFiles()
    
    print("📊 Generated Files:")
    print("  • Original: \(originalContent.count) characters, \(originalContent.components(separatedBy: "\n").count) lines")
    print("  • Modified: \(modifiedContent.count) characters, \(modifiedContent.components(separatedBy: "\n").count) lines")
    
    let iterations = 10  // Same as original test
    
    // Test all six algorithms
    print("\n🔥 Testing \(AlgorithmNames.zoom) Algorithm (\(iterations) iterations)...")
    let brusResults = testComprehensiveAlgorithmPerformance(
        source: originalContent,
        destination: modifiedContent,
        algorithmName: AlgorithmNames.zoom,
        testFunction: { source, dest in
            MultiLineDiff.createDiff(source: source, destination: dest, algorithm: .zoom)
        },
        iterations: iterations
    )
    
    print("\n🧠 Testing \(AlgorithmNames.megatron) Algorithm (\(iterations) iterations)...")
    let toddResults = testComprehensiveAlgorithmPerformance(
        source: originalContent,
        destination: modifiedContent,
        algorithmName: AlgorithmNames.megatron,
        testFunction: { source, dest in
            MultiLineDiff.createDiff(source: source, destination: dest, algorithm: .megatron)
        },
        iterations: iterations
    )
    

    
    print("\n🟪 Testing \(AlgorithmNames.flash) Algorithm (\(iterations) iterations)...")
    let sodaResults = testComprehensiveAlgorithmPerformance(
        source: originalContent,
        destination: modifiedContent,
        algorithmName: AlgorithmNames.flash,
        testFunction: { source, dest in
            MultiLineDiff.createDiff(source: source, destination: dest, algorithm: .flash)
        },
        iterations: iterations
    )
    
    print("\n🟦 Testing \(AlgorithmNames.starscream) Algorithm (\(iterations) iterations)...")
    let lineResults = testComprehensiveAlgorithmPerformance(
        source: originalContent,
        destination: modifiedContent,
        algorithmName: AlgorithmNames.starscream,
        testFunction: { source, dest in
            MultiLineDiff.createDiff(source: source, destination: dest, algorithm: .starscream)
        },
        iterations: iterations
    )
    
    print("\n🟩 Testing \(AlgorithmNames.optimus) Algorithm (\(iterations) iterations)...")
    let drewResults = testComprehensiveAlgorithmPerformance(
        source: originalContent,
        destination: modifiedContent,
        algorithmName: AlgorithmNames.optimus,
        testFunction: { source, dest in
            MultiLineDiff.createDiff(source: source, destination: dest, algorithm: .optimus)
        },
        iterations: iterations
    )
    
    // Print comprehensive results
    printComprehensiveResults(
        brusResults: brusResults,
        toddResults: toddResults,
        sodaResults: sodaResults,
        lineResults: lineResults,
        drewResults: drewResults,
        iterations: iterations
    )
    
    // Verify all algorithms produce correct results
    #expect(brusResults.finalResult == modifiedContent, "Brus algorithm should produce correct result")
    #expect(toddResults.finalResult == modifiedContent, "Todd algorithm should produce correct result")
    #expect(sodaResults.finalResult == modifiedContent, "Soda algorithm should produce correct result")
    #expect(lineResults.finalResult == modifiedContent, "Line algorithm should produce correct result")
    #expect(drewResults.finalResult == modifiedContent, "Drew algorithm should produce correct result")
    
    print("\n✅ All algorithms produce correct results!")
}

// MARK: - Large Swift File Generation (copied from original test)

private func generateLargeSwiftFiles() -> (original: String, modified: String) {
    let original = generateLargeSwiftFile()
    let modified = createModifiedVersion(of: original)
    return (original, modified)
}

private func generateLargeSwiftFile() -> String {
    var lines: [String] = []
    
    // File header
    lines.append("//")
    lines.append("//  LargeSwiftFile.swift")
    lines.append("//  PerformanceTest")
    lines.append("//")
    lines.append("//  Created by MultiLineDiff Performance Test")
    lines.append("//")
    lines.append("")
    lines.append("import Foundation")
    lines.append("import UIKit")
    lines.append("import SwiftUI")
    lines.append("")
    
    // Generate multiple classes, structs, enums, and protocols
    for classIndex in 1...50 {
        lines.append(contentsOf: generateSwiftClass(index: classIndex))
        lines.append("")
    }
    
    for structIndex in 1...30 {
        lines.append(contentsOf: generateSwiftStruct(index: structIndex))
        lines.append("")
    }
    
    for enumIndex in 1...20 {
        lines.append(contentsOf: generateSwiftEnum(index: enumIndex))
        lines.append("")
    }
    
    for protocolIndex in 1...15 {
        lines.append(contentsOf: generateSwiftProtocol(index: protocolIndex))
        lines.append("")
    }
    
    // Add extension methods
    for extIndex in 1...25 {
        lines.append(contentsOf: generateSwiftExtension(index: extIndex))
        lines.append("")
    }
    
    // Pad to reach approximately 5000 lines
    while lines.count < 5000 {
        lines.append("// Additional line \(lines.count + 1) for padding")
        lines.append("// More content to reach 5000 lines")
        lines.append("")
    }
    
    return lines.joined(separator: "\n")
}

private func generateSwiftClass(index: Int) -> [String] {
    return [
        "/// Class \(index) for performance testing",
        "/// Provides various methods and properties for comprehensive testing",
        "class PerformanceTestClass\(index): NSObject {",
        "    // MARK: - Properties",
        "    ",
        "    /// Primary identifier for the class instance",
        "    var identifier: String = \"class_\(index)\"",
        "    ",
        "    /// Numeric value for calculations",
        "    var numericValue: Int = \(index * 10)",
        "    ",
        "    /// Optional string value",
        "    var optionalValue: String?",
        "    ",
        "    /// Array of test data",
        "    var testData: [String] = []",
        "    ",
        "    /// Dictionary for key-value storage",
        "    var dataStore: [String: Any] = [:]",
        "    ",
        "    // MARK: - Initialization",
        "    ",
        "    /// Designated initializer",
        "    /// - Parameters:",
        "    ///   - identifier: Unique identifier for the instance",
        "    ///   - numericValue: Initial numeric value",
        "    override init() {",
        "        super.init()",
        "        setupInitialData()",
        "    }",
        "    ",
        "    /// Convenience initializer with custom values",
        "    /// - Parameters:",
        "    ///   - identifier: Custom identifier",
        "    ///   - value: Custom numeric value",
        "    convenience init(identifier: String, value: Int) {",
        "        self.init()",
        "        self.identifier = identifier",
        "        self.numericValue = value",
        "    }",
        "    ",
        "    // MARK: - Public Methods",
        "    ",
        "    /// Performs calculation on the numeric value",
        "    /// - Parameter multiplier: Value to multiply by",
        "    /// - Returns: Calculated result",
        "    func calculateValue(multiplier: Int) -> Int {",
        "        return numericValue * multiplier",
        "    }",
        "    ",
        "    /// Processes string data",
        "    /// - Parameter input: Input string to process",
        "    /// - Returns: Processed string result",
        "    func processString(_ input: String) -> String {",
        "        return \"Processed: \\(input) for \\(identifier)\"",
        "    }",
        "    ",
        "    /// Validates the current state",
        "    /// - Returns: True if valid, false otherwise",
        "    func validateState() -> Bool {",
        "        return !identifier.isEmpty && numericValue >= 0",
        "    }",
        "    ",
        "    // MARK: - Private Methods",
        "    ",
        "    /// Sets up initial data for the instance",
        "    private func setupInitialData() {",
        "        testData = [\"item1_\\(index)\", \"item2_\\(index)\", \"item3_\\(index)\"]",
        "        dataStore[\"created\"] = Date()",
        "        dataStore[\"version\"] = \"1.0\"",
        "    }",
        "    ",
        "    /// Internal calculation helper",
        "    /// - Parameter value: Input value",
        "    /// - Returns: Processed result",
        "    private func internalCalculation(_ value: Int) -> Int {",
        "        return value * 2 + index",
        "    }",
        "}"
    ]
}

private func generateSwiftStruct(index: Int) -> [String] {
    return [
        "/// Struct \(index) for performance testing",
        "struct PerformanceTestStruct\(index): Codable, Hashable {",
        "    // MARK: - Properties",
        "    ",
        "    let id: UUID",
        "    var name: String",
        "    var value: Double",
        "    var isActive: Bool",
        "    var metadata: [String: String]",
        "    ",
        "    // MARK: - Computed Properties",
        "    ",
        "    /// Formatted display name",
        "    var displayName: String {",
        "        return \"Struct \\(index): \\(name)\"",
        "    }",
        "    ",
        "    /// String representation of value",
        "    var formattedValue: String {",
        "        return String(format: \"%.2f\", value)",
        "    }",
        "    ",
        "    // MARK: - Initialization",
        "    ",
        "    /// Default initializer",
        "    init() {",
        "        self.id = UUID()",
        "        self.name = \"TestStruct\\(index)\"",
        "        self.value = Double(index) * 1.5",
        "        self.isActive = true",
        "        self.metadata = [\"type\": \"struct\", \"index\": \"\\(index)\"]",
        "    }",
        "    ",
        "    /// Custom initializer",
        "    /// - Parameters:",
        "    ///   - name: Custom name",
        "    ///   - value: Custom value",
        "    ///   - isActive: Active status",
        "    init(name: String, value: Double, isActive: Bool = true) {",
        "        self.id = UUID()",
        "        self.name = name",
        "        self.value = value",
        "        self.isActive = isActive",
        "        self.metadata = [\"type\": \"custom\", \"name\": name]",
        "    }",
        "    ",
        "    // MARK: - Methods",
        "    ",
        "    /// Updates the value with a modifier",
        "    /// - Parameter modifier: Value to add",
        "    mutating func updateValue(modifier: Double) {",
        "        value += modifier",
        "    }",
        "    ",
        "    /// Toggles the active state",
        "    mutating func toggleActive() {",
        "        isActive.toggle()",
        "    }",
        "    ",
        "    /// Adds metadata entry",
        "    /// - Parameters:",
        "    ///   - key: Metadata key",
        "    ///   - value: Metadata value",
        "    mutating func addMetadata(key: String, value: String) {",
        "        metadata[key] = value",
        "    }",
        "}"
    ]
}

private func generateSwiftEnum(index: Int) -> [String] {
    return [
        "/// Enum \(index) for performance testing",
        "enum PerformanceTestEnum\(index): String, CaseIterable, Codable {",
        "    case option1 = \"option1_\\(index)\"",
        "    case option2 = \"option2_\\(index)\"",
        "    case option3 = \"option3_\\(index)\"",
        "    case option4 = \"option4_\\(index)\"",
        "    case option5 = \"option5_\\(index)\"",
        "    ",
        "    // MARK: - Computed Properties",
        "    ",
        "    /// Display name for the enum case",
        "    var displayName: String {",
        "        switch self {",
        "        case .option1: return \"First Option \\(index)\"",
        "        case .option2: return \"Second Option \\(index)\"",
        "        case .option3: return \"Third Option \\(index)\"",
        "        case .option4: return \"Fourth Option \\(index)\"",
        "        case .option5: return \"Fifth Option \\(index)\"",
        "        }",
        "    }",
        "    ",
        "    /// Numeric value associated with the enum",
        "    var numericValue: Int {",
        "        switch self {",
        "        case .option1: return index * 1",
        "        case .option2: return index * 2",
        "        case .option3: return index * 3",
        "        case .option4: return index * 4",
        "        case .option5: return index * 5",
        "        }",
        "    }",
        "    ",
        "    // MARK: - Methods",
        "    ",
        "    /// Processes the enum value",
        "    /// - Returns: Processed string",
        "    func processValue() -> String {",
        "        return \"Processing \\(displayName) with value \\(numericValue)\"",
        "    }",
        "    ",
        "    /// Validates the enum state",
        "    /// - Returns: True if valid",
        "    func isValid() -> Bool {",
        "        return numericValue > 0",
        "    }",
        "}"
    ]
}

private func generateSwiftProtocol(index: Int) -> [String] {
    return [
        "/// Protocol \(index) for performance testing",
        "protocol PerformanceTestProtocol\(index) {",
        "    // MARK: - Required Properties",
        "    ",
        "    var identifier: String { get set }",
        "    var isEnabled: Bool { get }",
        "    ",
        "    // MARK: - Required Methods",
        "    ",
        "    /// Initializes the protocol implementation",
        "    func initialize()",
        "    ",
        "    /// Performs the main operation",
        "    /// - Parameter input: Input data",
        "    /// - Returns: Operation result",
        "    func performOperation(input: Any) -> String",
        "    ",
        "    /// Validates the current state",
        "    /// - Returns: Validation result",
        "    func validate() -> Bool",
        "}",
        "",
        "/// Default implementation for Protocol \(index)",
        "extension PerformanceTestProtocol\(index) {",
        "    /// Default validation implementation",
        "    func validate() -> Bool {",
        "        return !identifier.isEmpty && isEnabled",
        "    }",
        "    ",
        "    /// Helper method for processing",
        "    /// - Parameter data: Data to process",
        "    /// - Returns: Processed result",
        "    func processData(_ data: String) -> String {",
        "        return \"Protocol\\(index): \\(data)\"",
        "    }",
        "}"
    ]
}

private func generateSwiftExtension(index: Int) -> [String] {
    return [
        "/// Extension \(index) for performance testing",
        "extension String {",
        "    /// Custom method \(index) for string processing",
        "    /// - Returns: Processed string",
        "    func performanceMethod\(index)() -> String {",
        "        return \"Extension\\(index): \\(self)\"",
        "    }",
        "    ",
        "    /// Validation method \(index)",
        "    /// - Returns: True if valid according to criteria \(index)",
        "    func isValidForCriteria\(index)() -> Bool {",
        "        return count > index && contains(\"\\(index)\")",
        "    }",
        "}",
        "",
        "extension Int {",
        "    /// Mathematical operation \(index)",
        "    /// - Returns: Calculated result",
        "    func calculate\(index)() -> Int {",
        "        return self * index + \(index * 10)",
        "    }",
        "}"
    ]
}

private func createModifiedVersion(of original: String) -> String {
    var lines = original.components(separatedBy: "\n")
    let originalCount = lines.count
    
    print("📝 Creating modifications to \(originalCount) lines...")
    
    // Modification 1: Change every 10th line (add "MODIFIED" to comments)
    for i in stride(from: 9, to: lines.count, by: 10) {
        if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("///") {
            lines[i] = lines[i] + " MODIFIED"
        }
    }
    
    // Modification 2: Replace some method implementations
    for i in 0..<lines.count {
        if lines[i].contains("func calculateValue(multiplier: Int) -> Int {") {
            lines[i+1] = "        return numericValue * multiplier * 2 // Enhanced calculation"
        }
        if lines[i].contains("func processString(_ input: String) -> String {") {
            lines[i+1] = "        return \"ENHANCED: \\(input) processed by \\(identifier) with timestamp \\(Date())\""
        }
    }
    
    // Modification 3: Add new properties to classes (insert after existing properties)
    var insertionOffset = 0
    for i in 0..<lines.count {
        let adjustedIndex = i + insertionOffset
        if adjustedIndex < lines.count && lines[adjustedIndex].contains("var dataStore: [String: Any] = [:]") {
            let newLines = [
                "    ",
                "    /// New enhanced property for performance testing",
                "    var enhancedProperty: String = \"enhanced_value\"",
                "    ",
                "    /// Additional numeric property",
                "    var additionalNumber: Int = 42"
            ]
            lines.insert(contentsOf: newLines, at: adjustedIndex + 1)
            insertionOffset += newLines.count
        }
    }
    
    // Modification 4: Change enum cases
    for i in 0..<lines.count {
        if lines[i].contains("case option1 = \"option1_") {
            lines[i] = lines[i].replacingOccurrences(of: "option1_", with: "enhanced_option1_")
        }
        if lines[i].contains("case option3 = \"option3_") {
            lines[i] = lines[i].replacingOccurrences(of: "option3_", with: "modified_option3_")
        }
    }
    
    // Modification 5: Add new methods to structs
    insertionOffset = 0
    for i in 0..<lines.count {
        let adjustedIndex = i + insertionOffset
        if adjustedIndex < lines.count && lines[adjustedIndex].contains("metadata[key] = value") && 
           adjustedIndex + 1 < lines.count && lines[adjustedIndex + 1].contains("    }") &&
           adjustedIndex + 2 < lines.count && lines[adjustedIndex + 2] == "}" {
            let newLines = [
                "    ",
                "    /// New enhanced method for performance testing",
                "    func enhancedOperation() -> String {",
                "        return \"Enhanced operation on \\(name) with value \\(value)\"",
                "    }",
                "    ",
                "    /// Additional validation method",
                "    func isValidEnhanced() -> Bool {",
                "        return isActive && value > 0 && !name.isEmpty",
                "    }"
            ]
            lines.insert(contentsOf: newLines, at: adjustedIndex + 1)
            insertionOffset += newLines.count
        }
    }
    
    // Modification 6: Update imports
    for i in 0..<lines.count {
        if lines[i] == "import SwiftUI" {
            lines[i] = "import SwiftUI\nimport Combine\nimport CoreData"
            break
        }
    }
    
    // Modification 7: Add completely new content at the end
    lines.append("")
    lines.append("// MARK: - Enhanced Performance Testing Extensions")
    lines.append("")
    lines.append("/// Enhanced performance testing functionality")
    lines.append("extension PerformanceTestClass1 {")
    lines.append("    /// Advanced calculation method")
    lines.append("    func advancedCalculation(input: [Int]) -> Int {")
    lines.append("        return input.reduce(0, +) * numericValue")
    lines.append("    }")
    lines.append("}")
    lines.append("")
    lines.append("/// Global performance testing functions")
    lines.append("func globalPerformanceFunction(data: String) -> String {")
    lines.append("    return \"Global processing: \\(data)\"")
    lines.append("}")
    
    let modifiedContent = lines.joined(separator: "\n")
    let modifiedCount = modifiedContent.components(separatedBy: "\n").count
    
    print("✅ Modifications complete:")
    print("  • Original lines: \(originalCount)")
    print("  • Modified lines: \(modifiedCount)")
    print("  • Added lines: \(modifiedCount - originalCount)")
    
    return modifiedContent
}

// MARK: - Performance Testing Infrastructure

struct ComprehensiveAlgorithmResults {
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

private func testComprehensiveAlgorithmPerformance(
    source: String,
    destination: String,
    algorithmName: String,
    testFunction: (String, String) -> DiffResult,
    iterations: Int
) -> ComprehensiveAlgorithmResults {
    var createTimes: [TimeInterval] = []
    var applyTimes: [TimeInterval] = []
    var operationCounts: [Int] = []
    var finalResult = ""
    
    // Warm up run
    let warmupDiff = testFunction(source, destination)
    _ = try! MultiLineDiff.applyDiff(to: source, diff: warmupDiff)
    
    // Run performance tests
    for iteration in 1...iterations {
        print("  ⏱️  \(algorithmName) iteration \(iteration)/\(iterations)")
        
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
    
    return ComprehensiveAlgorithmResults(
        algorithmName: algorithmName,
        createTimes: createTimes,
        applyTimes: applyTimes,
        operationCounts: operationCounts,
        finalResult: finalResult
    )
}

private func printComprehensiveResults(
    brusResults: ComprehensiveAlgorithmResults,
    toddResults: ComprehensiveAlgorithmResults,
    sodaResults: ComprehensiveAlgorithmResults,
    lineResults: ComprehensiveAlgorithmResults,
    drewResults: ComprehensiveAlgorithmResults,
    iterations: Int
) {
    print("\n📊 COMPREHENSIVE PERFORMANCE RESULTS - ALL 5 ALGORITHMS (\(iterations) iterations)")
    print("=" * 90)
    
    // Algorithm comparison table
    print("\n🏆 Algorithm Performance Comparison:")
    print("┌─────────────────┬─────────────┬─────────────┬─────────────┬─────────────┐")
    print("│ Algorithm       │ Create (ms) │ Apply (ms)  │ Total (ms)  │ Operations  │")
    print("├─────────────────┼─────────────┼─────────────┼─────────────┼─────────────┤")
    
    let algorithms = [brusResults, toddResults, sodaResults, lineResults, drewResults]
    
    for result in algorithms {
        let createMs = String(format: "%.1f", result.averageCreateTime * 1000)
        let applyMs = String(format: "%.1f", result.averageApplyTime * 1000)
        let totalMs = String(format: "%.1f", result.averageTotalTime * 1000)
        let ops = String(format: "%.0f", result.averageOperationCount)
        
        let name = result.algorithmName.padding(toLength: 15, withPad: " ", startingAt: 0)
        let createPad = createMs.padding(toLength: 11, withPad: " ", startingAt: 0)
        let applyPad = applyMs.padding(toLength: 11, withPad: " ", startingAt: 0)
        let totalPad = totalMs.padding(toLength: 11, withPad: " ", startingAt: 0)
        let opsPad = ops.padding(toLength: 11, withPad: " ", startingAt: 0)
        
        print("│ \(name) │ \(createPad) │ \(applyPad) │ \(totalPad) │ \(opsPad) │")
    }
    
    print("└─────────────────┴─────────────┴─────────────┴─────────────┴─────────────┘")
    
    // Find the fastest algorithm for each metric
    let fastestCreate = algorithms.min(by: { $0.averageCreateTime < $1.averageCreateTime })!
    let fastestApply = algorithms.min(by: { $0.averageApplyTime < $1.averageApplyTime })!
    let fastestTotal = algorithms.min(by: { $0.averageTotalTime < $1.averageTotalTime })!
    let fewestOps = algorithms.min(by: { $0.averageOperationCount < $1.averageOperationCount })!
    
    print("\n🏅 Winners:")
    print("  • Fastest Create: \(fastestCreate.algorithmName) (\(String(format: "%.1f", fastestCreate.averageCreateTime * 1000))ms)")
    print("  • Fastest Apply:  \(fastestApply.algorithmName) (\(String(format: "%.1f", fastestApply.averageApplyTime * 1000))ms)")
    print("  • Fastest Total:  \(fastestTotal.algorithmName) (\(String(format: "%.1f", fastestTotal.averageTotalTime * 1000))ms)")
    print("  • Fewest Ops:     \(fewestOps.algorithmName) (\(String(format: "%.0f", fewestOps.averageOperationCount)) operations)")
    
    // Speed ratios compared to fastest
    print("\n📈 Speed Ratios (relative to fastest):")
    
    for result in algorithms {
        let createRatio = result.averageCreateTime / fastestCreate.averageCreateTime
        let applyRatio = result.averageApplyTime / fastestApply.averageApplyTime
        let totalRatio = result.averageTotalTime / fastestTotal.averageTotalTime
        
        print("  \(result.algorithmName):")
        print("    Create: \(String(format: "%.1f", createRatio))x")
        print("    Apply:  \(String(format: "%.1f", applyRatio))x")
        print("    Total:  \(String(format: "%.1f", totalRatio))x")
    }
    
    // Operation count comparison
    print("\n📊 Operation Count Analysis:")
    for result in algorithms {
        let ratio = result.averageOperationCount / fewestOps.averageOperationCount
        print("  \(result.algorithmName): \(String(format: "%.0f", result.averageOperationCount)) operations (\(String(format: "%.1f", ratio))x)")
    }
} 