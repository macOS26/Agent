import Testing
import Foundation
@testable import MultiLineDiff

// MARK: - Large File Performance Tests

@Test func testLargeFilePerformanceComparison() throws {
    print("\n🚀 Large File Performance Test - 5000 Lines, 100 Iterations")
    print("=" * 70)
    
    // Generate large Swift file content
    let testFiles = try TestFileManager(testName: "LargeFilePerformance")
    let (originalContent, modifiedContent) = generateLargeSwiftFiles()
    
    // Write files to disk for verification
    _ = try testFiles.createFile(named: "original_large.swift", content: originalContent)
    _ = try testFiles.createFile(named: "modified_large.swift", content: modifiedContent)
    
    print("📊 Generated Files:")
    print("  • Original: \(originalContent.count) characters, \(originalContent.components(separatedBy: "\n").count) lines")
    print("  • Modified: \(modifiedContent.count) characters, \(modifiedContent.components(separatedBy: "\n").count) lines")
    
    let iterations = 10
    
    // Test Brus Algorithm Performance
    print("\n🔥 Testing Brus Algorithm (100 iterations)...")
    let brusResults = try testAlgorithmPerformance(
        source: originalContent,
        destination: modifiedContent,
        algorithm: .zoom,
        iterations: iterations,
        testFiles: testFiles
    )
    
    // Test Todd Algorithm Performance  
    print("\n🧠 Testing Todd Algorithm (100 iterations)...")
    let toddResults = try testAlgorithmPerformance(
        source: originalContent,
        destination: modifiedContent,
        algorithm: .megatron,
        iterations: iterations,
        testFiles: testFiles
    )
    
    // Print comprehensive results
    printPerformanceResults(brusResults: brusResults, toddResults: toddResults, iterations: iterations)
    
    // Verify both algorithms produce correct results
    #expect(brusResults.finalResult == modifiedContent, "Brus algorithm should produce correct result")
    #expect(toddResults.finalResult == modifiedContent, "Todd algorithm should produce correct result")
    
    // Save performance report to file
    try savePerformanceReport(
        brusResults: brusResults,
        toddResults: toddResults,
        iterations: iterations,
        testFiles: testFiles
    )
}

// MARK: - Large Swift File Generation

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

struct AlgorithmPerformanceResults {
    let algorithm: DiffAlgorithm
    let createTimes: [TimeInterval]
    let applyTimes: [TimeInterval]
    let totalTimes: [TimeInterval]
    let operationCounts: [Int]
    let finalResult: String
    let averageCreateTime: TimeInterval
    let averageApplyTime: TimeInterval
    let averageTotalTime: TimeInterval
    let averageOperationCount: Double
    let averageTimePerTest: TimeInterval
    
    init(algorithm: DiffAlgorithm, createTimes: [TimeInterval], applyTimes: [TimeInterval], operationCounts: [Int], finalResult: String, averageTimePerTest: TimeInterval) {
        self.algorithm = algorithm
        self.createTimes = createTimes
        self.applyTimes = applyTimes
        self.totalTimes = zip(createTimes, applyTimes).map { $0 + $1 }
        self.operationCounts = operationCounts
        self.finalResult = finalResult
        self.averageCreateTime = createTimes.reduce(0, +) / Double(createTimes.count)
        self.averageApplyTime = applyTimes.reduce(0, +) / Double(applyTimes.count)
        self.averageTotalTime = totalTimes.reduce(0, +) / Double(totalTimes.count)
        self.averageOperationCount = Double(operationCounts.reduce(0, +)) / Double(operationCounts.count)
        self.averageTimePerTest = averageTimePerTest
    }
}

private func testAlgorithmPerformance(
    source: String,
    destination: String,
    algorithm: DiffAlgorithm,
    iterations: Int,
    testFiles: TestFileManager
) throws -> AlgorithmPerformanceResults {
    var createTimes: [TimeInterval] = []
    var applyTimes: [TimeInterval] = []
    var operationCounts: [Int] = []
    var finalResult = ""
    
    let algorithmName = algorithm == .zoom ? "Brus" : "Todd"
    
    // Warm up run
    let warmupDiff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: algorithm)
    _ = try MultiLineDiff.applyDiff(to: source, diff: warmupDiff)
    
    // Total test start time
    let totalTestStartTime = Date()
    
    // Run performance tests
    for iteration in 1...iterations {
        if iteration % 10 == 0 {
            print("  ⏱️  \(algorithmName) iteration \(iteration)/\(iterations)")
        }
        
        // Measure diff creation time
        let createStartTime = Date()
        let diff = MultiLineDiff.createDiff(
            source: source,
            destination: destination,
            algorithm: algorithm,
            includeMetadata: true
        )
        let createTime = Date().timeIntervalSince(createStartTime)
        createTimes.append(createTime)
        operationCounts.append(diff.operations.count)
        
        // Measure diff application time
        let applyStartTime = Date()
        let result = try MultiLineDiff.applyDiff(to: source, diff: diff)
        let applyTime = Date().timeIntervalSince(applyStartTime)
        applyTimes.append(applyTime)
        
        // Store final result for verification (from last iteration)
        if iteration == iterations {
            finalResult = result
            
            // Save diff to file for analysis
            let diffFileURL = try testFiles.createFile(
                named: "\(algorithmName.lowercased())_diff.json",
                content: try MultiLineDiff.encodeDiffToJSONString(diff)
            )
            print("  💾 Saved \(algorithmName) diff to: \(diffFileURL.lastPathComponent)")
        }
    }
    
    // Calculate total test time and average time per test
    let totalTestTime = Date().timeIntervalSince(totalTestStartTime)
    let averageTimePerTest = totalTestTime / Double(iterations)
    
    print(String(format: "  🕒 Total Test Time: %.3f seconds", totalTestTime))
    print(String(format: "  🕒 Average Time per Test: %.3f seconds", averageTimePerTest))
    
    return AlgorithmPerformanceResults(
        algorithm: algorithm,
        createTimes: createTimes,
        applyTimes: applyTimes,
        operationCounts: operationCounts,
        finalResult: finalResult,
        averageTimePerTest: averageTimePerTest
    )
}

private func printPerformanceResults(brusResults: AlgorithmPerformanceResults, toddResults: AlgorithmPerformanceResults, iterations: Int) {
    print("\n📊 PERFORMANCE RESULTS (\(iterations) iterations)")
    print("=" * 70)
    
    // Helper function to safely format numbers
    func safeFormat(_ value: Double, decimals: Int = 3) -> String {
        if value.isNaN || value.isInfinite {
            return "N/A"
        }
        // Use string interpolation with rounding instead of String(format:)
        let multiplier = pow(10.0, Double(decimals))
        let rounded = (value * multiplier).rounded() / multiplier
        return "\(rounded)"
    }
    
    // Helper function to safely format ratios
    func safeRatio(_ numerator: Double, _ denominator: Double) -> String {
        if denominator.isZero || !denominator.isFinite || !numerator.isFinite {
            return "N/A"
        }
        let ratio = numerator / denominator
        if !ratio.isFinite {
            return "N/A"
        }
        // Use string interpolation instead of String(format:)
        let rounded = (ratio * 100).rounded() / 100
        return "\(rounded)"
    }
    
    // Algorithm comparison table
    print("\n🏆 Algorithm Performance Comparison:")
    print("┌─────────────┬─────────────┬─────────────┬─────────────┬─────────────┬─────────────┐")
    print("│ Algorithm   │ Create (ms) │ Apply (ms)  │ Total (ms)  │ Operations  │ Test Time(s)│")
    print("├─────────────┼─────────────┼─────────────┼─────────────┼─────────────┼─────────────┤")
    
    // Brus results
    let brusCreateMs = safeFormat(brusResults.averageCreateTime * 1000)
    let brusApplyMs = safeFormat(brusResults.averageApplyTime * 1000)
    let brusTotalMs = safeFormat(brusResults.averageTotalTime * 1000)
    let brusOps = safeFormat(brusResults.averageOperationCount, decimals: 0)
    let brusTestTime = safeFormat(brusResults.averageTimePerTest)
    
    print("│ Brus        │ \(String(brusCreateMs).padding(toLength: 11, withPad: " ", startingAt: 0)) │ \(String(brusApplyMs).padding(toLength: 11, withPad: " ", startingAt: 0)) │ \(String(brusTotalMs).padding(toLength: 11, withPad: " ", startingAt: 0)) │ \(String(brusOps).padding(toLength: 11, withPad: " ", startingAt: 0)) │ \(String(brusTestTime).padding(toLength: 11, withPad: " ", startingAt: 0)) │")
    
    // Todd results
    let toddCreateMs = safeFormat(toddResults.averageCreateTime * 1000)
    let toddApplyMs = safeFormat(toddResults.averageApplyTime * 1000)
    let toddTotalMs = safeFormat(toddResults.averageTotalTime * 1000)
    let toddOps = safeFormat(toddResults.averageOperationCount, decimals: 0)
    let toddTestTime = safeFormat(toddResults.averageTimePerTest)
    
    print("│ Todd        │ \(String(toddCreateMs).padding(toLength: 11, withPad: " ", startingAt: 0)) │ \(String(toddApplyMs).padding(toLength: 11, withPad: " ", startingAt: 0)) │ \(String(toddTotalMs).padding(toLength: 11, withPad: " ", startingAt: 0)) │ \(String(toddOps).padding(toLength: 11, withPad: " ", startingAt: 0)) │ \(String(toddTestTime).padding(toLength: 11, withPad: " ", startingAt: 0)) │")
    
    print("└─────────────┴─────────────┴─────────────┴─────────────┴─────────────┴─────────────┘")
    
    // Performance ratios - using safe ratio calculations
    print("\n📈 Performance Ratios (Todd vs Brus):")
    
    let createRatio = safeRatio(toddResults.averageCreateTime, brusResults.averageCreateTime)
    if createRatio != "N/A" {
        let ratio = Double(createRatio) ?? 0
        print("  • Create Time: \(createRatio)x \(ratio > 1 ? "(Brus faster)" : "(Todd faster)")")
    } else {
        print("  • Create Time: Unable to calculate ratio")
    }
    
    let applyRatio = safeRatio(toddResults.averageApplyTime, brusResults.averageApplyTime)
    if applyRatio != "N/A" {
        let ratio = Double(applyRatio) ?? 0
        print("  • Apply Time:  \(applyRatio)x \(ratio > 1 ? "(Brus faster)" : "(Todd faster)")")
    } else {
        print("  • Apply Time: Unable to calculate ratio")
    }
    
    let totalRatio = safeRatio(toddResults.averageTotalTime, brusResults.averageTotalTime)
    if totalRatio != "N/A" {
        let ratio = Double(totalRatio) ?? 0
        print("  • Total Time:  \(totalRatio)x \(ratio > 1 ? "(Brus faster)" : "(Todd faster)")")
    } else {
        print("  • Total Time: Unable to calculate ratio")
    }
    
    let operationRatio = safeRatio(toddResults.averageOperationCount, brusResults.averageOperationCount)
    if operationRatio != "N/A" {
        let ratio = Double(operationRatio) ?? 0
        print("  • Operations:  \(operationRatio)x \(ratio > 1 ? "(Todd more detailed)" : "(Brus more detailed)")")
    } else {
        print("  • Operations: Unable to calculate ratio")
    }
    
    let timePerTestRatio = safeRatio(toddResults.averageTimePerTest, brusResults.averageTimePerTest)
    if timePerTestRatio != "N/A" {
        let ratio = Double(timePerTestRatio) ?? 0
        print("  • Test Time:   \(timePerTestRatio)x \(ratio > 1 ? "(Brus slower)" : "(Todd slower)")")
    } else {
        print("  • Test Time: Unable to calculate ratio")
    }
    
    // Statistical analysis
    print("\n📊 Statistical Analysis:")
    printStatistics(label: "Brus Create", times: brusResults.createTimes)
    printStatistics(label: "Brus Apply", times: brusResults.applyTimes)
    printStatistics(label: "Todd Create", times: toddResults.createTimes)
    printStatistics(label: "Todd Apply", times: toddResults.applyTimes)
}

private func printStatistics(label: String, times: [TimeInterval]) {
    let sortedTimes = times.sorted()
    let min = sortedTimes.first! * 1000
    let max = sortedTimes.last! * 1000
    let avg = times.reduce(0, +) / Double(times.count) * 1000
    let median = sortedTimes[sortedTimes.count / 2] * 1000
    let stdDev = sqrt(times.map { pow(($0 * 1000) - avg, 2) }.reduce(0, +) / Double(times.count))
    
    // Safe formatting function
    func safeStat(_ value: Double) -> String {
        if value.isNaN || value.isInfinite {
            return "N/A"
        }
        // Use string interpolation with rounding instead of String(format:)
        let rounded = (value * 1000).rounded() / 1000
        return "\(rounded)"
    }
    
    let minStr = safeStat(min)
    let maxStr = safeStat(max)
    let avgStr = safeStat(avg)
    let medianStr = safeStat(median)
    let stdDevStr = safeStat(stdDev)
    
    print("  \(label.padding(toLength: 12, withPad: " ", startingAt: 0)): avg=\(avgStr)ms, min=\(minStr)ms, max=\(maxStr)ms, median=\(medianStr)ms, σ=\(stdDevStr)ms")
}

private func savePerformanceReport(
    brusResults: AlgorithmPerformanceResults,
    toddResults: AlgorithmPerformanceResults,
    iterations: Int,
    testFiles: TestFileManager
) throws {
    let report = generatePerformanceReport(brusResults: brusResults, toddResults: toddResults, iterations: iterations)
    _ = try testFiles.createFile(named: "performance_report.md", content: report)
    print("\n💾 Performance report saved to: performance_report.md")
}

private func generatePerformanceReport(
    brusResults: AlgorithmPerformanceResults,
    toddResults: AlgorithmPerformanceResults,
    iterations: Int
) -> String {
    let timestamp = DateFormatter().string(from: Date())
    
    return """
    # MultiLineDiff Large File Performance Report
    
    **Generated:** \(timestamp)  
    **Test Duration:** \(iterations) iterations  
    **File Size:** ~5000 lines of Swift code
    
    ## Executive Summary
    
    | Algorithm | Avg Create (ms) | Avg Apply (ms) | Avg Total (ms) | Avg Operations |
    |-----------|-----------------|----------------|----------------|----------------|
    | **Brus**  | \(String(format: "%.3f", brusResults.averageCreateTime * 1000)) | \(String(format: "%.3f", brusResults.averageApplyTime * 1000)) | \(String(format: "%.3f", brusResults.averageTotalTime * 1000)) | \(String(format: "%.0f", brusResults.averageOperationCount)) |
    | **Todd**  | \(String(format: "%.3f", toddResults.averageCreateTime * 1000)) | \(String(format: "%.3f", toddResults.averageApplyTime * 1000)) | \(String(format: "%.3f", toddResults.averageTotalTime * 1000)) | \(String(format: "%.0f", toddResults.averageOperationCount)) |
    
    ## Performance Analysis
    
    ### Speed Comparison
    - **Create Diff:** \(brusResults.averageCreateTime < toddResults.averageCreateTime ? "Brus" : "Todd") is \(String(format: "%.2fx", abs(toddResults.averageCreateTime / brusResults.averageCreateTime))) faster
    - **Apply Diff:** \(brusResults.averageApplyTime < toddResults.averageApplyTime ? "Brus" : "Todd") is \(String(format: "%.2fx", abs(toddResults.averageApplyTime / brusResults.averageApplyTime))) faster
    - **Total Time:** \(brusResults.averageTotalTime < toddResults.averageTotalTime ? "Brus" : "Todd") is \(String(format: "%.2fx", abs(toddResults.averageTotalTime / brusResults.averageTotalTime))) faster
    
    ### Operation Granularity
    - **Brus Operations:** \(String(format: "%.0f", brusResults.averageOperationCount)) (simpler, bulk operations)
    - **Todd Operations:** \(String(format: "%.0f", toddResults.averageOperationCount)) (more detailed, semantic operations)
    - **Granularity Ratio:** Todd produces \(String(format: "%.2fx", toddResults.averageOperationCount / brusResults.averageOperationCount)) more operations
    
    ## Recommendations
    
    ### Use Brus Algorithm When:
    - Performance is critical (real-time applications)
    - Simple text transformations
    - Bulk processing scenarios
    - Character-level precision is sufficient
    
    ### Use Todd Algorithm When:
    - Semantic understanding is important
    - Code refactoring scenarios
    - Structure preservation matters
    - More detailed operation history is needed
    
    ## Test Configuration
    - **Iterations:** \(iterations)
    - **Platform:** Swift 6.1 with MultiLineDiff optimizations
    - **Content:** Generated Swift code with classes, structs, enums, protocols
    - **Modifications:** Property additions, method changes, new content
    
    ---
    *Generated by MultiLineDiff Performance Test Suite*
    """
}

// String multiplication operator for formatting
extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
} 
