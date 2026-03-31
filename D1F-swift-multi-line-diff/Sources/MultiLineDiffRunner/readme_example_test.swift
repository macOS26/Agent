import MultiLineDiff

/// Test README Example 3 to verify the algorithm differences are accurate
public func demonstrateReadmeExample3() {
    print("\n🔍 README Example 3 Verification")
    print("=================================")
    
    let source = """
func processUser() {
    let user = getCurrentUser()
    print("Processing user")
    validateUser(user)
    return user
}
"""

    let destination = """
func processUser() -> User {
    let user = getCurrentUser()
    print("Processing user data")
    let validated = validateUser(user)
    saveUserData(validated)
    return validated
}
"""

    print("📝 Source (\(source.count) chars):")
    print(source)
    print("\n📝 Destination (\(destination.count) chars):")
    print(destination)
    print()

    // Test Zoom Algorithm
    let brusDiff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
    let brusResult = try! MultiLineDiff.applyDiff(to: source, diff: brusDiff)

    print("🔥 \(AlgorithmNames.zoom) Algorithm - Bulk Operations:")
    print("Total Operations: \(brusDiff.operations.count)")
    for (i, op) in brusDiff.operations.enumerated() {
        switch op {
        case .retain(let count):
            print("  \(i+1). RETAIN(\(count) chars)")
        case .delete(let count):
            print("  \(i+1). DELETE(\(count) chars)")
        case .insert(let text):
            print("  \(i+1). INSERT(\(text.count) chars): \"\(text.prefix(30))\(text.count > 30 ? "..." : "")\"")
        }
    }
    print("✅ Result matches destination: \(brusResult == destination)")
    print()

    // Test Todd Algorithm
    let toddDiff = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
    let toddResult = try! MultiLineDiff.applyDiff(to: source, diff: toddDiff)

    print("🧠 \(AlgorithmNames.megatron) Algorithm - Line-Aware Operations:")
    print("Total Operations: \(toddDiff.operations.count)")
    for (i, op) in toddDiff.operations.enumerated() {
        switch op {
        case .retain(let count):
            print("  \(i+1). RETAIN(\(count) chars)")
        case .delete(let count):
            print("  \(i+1). DELETE(\(count) chars)")
        case .insert(let text):
            print("  \(i+1). INSERT(\(text.count) chars): \"\(text.prefix(30))\(text.count > 30 ? "..." : "")\"")
        }
    }
    print("✅ Result matches destination: \(toddResult == destination)")
    print()

    print("📊 Algorithm Comparison:")
    print("• Both produce identical final results: \(brusResult == toddResult)")
    print("• \(AlgorithmNames.zoom) operations: \(brusDiff.operations.count) (bulk approach)")
    print("• \(AlgorithmNames.megatron) operations: \(toddDiff.operations.count) (line-aware approach)")
    print("• Operation difference: \(toddDiff.operations.count - brusDiff.operations.count) more operations in \(AlgorithmNames.megatron)")
    
    // Count operation types
    let brusRetains = brusDiff.operations.filter { if case .retain = $0 { return true }; return false }.count
    let brusDeletes = brusDiff.operations.filter { if case .delete = $0 { return true }; return false }.count 
    let brusInserts = brusDiff.operations.filter { if case .insert = $0 { return true }; return false }.count
    
    let toddRetains = toddDiff.operations.filter { if case .retain = $0 { return true }; return false }.count
    let toddDeletes = toddDiff.operations.filter { if case .delete = $0 { return true }; return false }.count
    let toddInserts = toddDiff.operations.filter { if case .insert = $0 { return true }; return false }.count
    
    print("\n📈 Operation Breakdown:")
    print("• \(AlgorithmNames.zoom): \(brusRetains) retains, \(brusDeletes) deletes, \(brusInserts) inserts")
    print("• \(AlgorithmNames.megatron): \(toddRetains) retains, \(toddDeletes) deletes, \(toddInserts) inserts")
    print("\n✅ README Example 3 verification complete!")
}

/// Demonstrate SmartDiff Base64 Methods
public func demonstrateSmartDiffBase64Methods() {
    let source = "Hello, world!"
    let destination = "Hello, Swift world!"
    
    // Test new createBase64SmartDiff method
    let base64SmartDiff = try! MultiLineDiff.createBase64Diff(source: source, destination: destination)
    
    // Test new applyBase64SmartDiffWithVerify method  
    let result = try! MultiLineDiff.applyBase64Diff(to: source, base64Diff: base64SmartDiff)
    
    // Also test with applyBase64SmartDiff (existing method)
    let result2 = try! MultiLineDiff.applyBase64Diff(to: source, base64Diff: base64SmartDiff)
    
    print("Base64 diff created and applied successfully")
    print("Result 1 matches: \(result == destination)")
    print("Result 2 matches: \(result2 == destination)")
} 