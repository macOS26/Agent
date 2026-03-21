# MultiLineDiff

[![Swift 6.1](https://img.shields.io/badge/Swift-6.1-orange.svg)](https://swift.org)
[![Website](https://img.shields.io/badge/website-xcf.ai-blue.svg)](https://xcf.ai)
[![Version](https://img.shields.io/badge/version-2.0.0-green.svg)](https://github.com/toddbruss/swift-multi-line-diff)
[![GitHub stars](https://img.shields.io/github/stars/codefreezeai/swift-multi-line-diff.svg?style=social)](https://github.com/codefreezeai/swift-multi-line-diff/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/codefreezeai/swift-multi-line-diff.svg?style=social)](https://github.com/codefreezeai/swift-multi-line-diff/network)

I created this library because I wanted an "online" verison of create and apply diff. I tried having an AI replace strings by starting and ending line numbers with very poor accuracy. Multi Line Diff fixes that and adds lot more features not found in any create and apply diff library.

This is a Swift library for creating and applying diffs to multi-line text content. Supports Unicode/UTF-8 strings and handles multi-line content properly. Designed specifically for Vibe AI Coding integrity and safe code transformations.

## 🌟 Key Features

- Create diffs between two strings
- Apply diffs to transform source text
- Handle multi-line content properly
- Support for Unicode/UTF-8 strings
- Multiple diff formats (JSON, Base64)
- Two diff algorithms (Flash and Optimus)
- **Automatic algorithm fallback with verification** 🛡️
- **Auto-detection of truncated vs full source** 🤖
- **Intelligent application without manual parameters** 🧠
- **Checksum verification and undo operations** 🔐
- **Dual context matching for precision** 🎯
- **Source verification and confidence scoring** 📊
- Designed for AI code integrity
- **Enhanced Truncated Diff Support** 🆕

## 🖥️ Platform Compatibility

- **macOS**: 13.0+
- **Swift**: 6.1+

## 🚀 **Enhanced Core Methods - Intelligence Built-In** ⭐

**NEW 2025**: The standard `createDiff()` and `applyDiff()` methods now include all intelligent capabilities built-in. No special "Smart" methods needed!

### 🔥 Why Choose the Enhanced Core Methods?

- **🤖 Zero Configuration**: Automatically detects full vs truncated sources
- **🧠 Intelligent Application**: No manual `allowTruncatedSource` parameters needed
- **🔐 Built-in Verification**: Automatic checksum validation
- **🎯 Context-Aware**: Smart section matching with confidence scoring
- **↩️ Undo Support**: Automatic reverse diff generation
- **⚡ Performance**: Same blazing-fast speed with enhanced intelligence

### 🎯 Core API Overview

| Method | Description | Use Case |
|--------|-------------|----------|
| `createDiff()` | 🧠 Intelligent diff creation with source storage | **Standard for all diffs** |
| `createBase64Diff()` | 📦 Intelligent Base64 diff | **Standard for all diffs** |
| `applyDiff()` | 🤖 Auto-detecting diff application | **Standard for applying diffs** |
| `applyBase64Diff()` | 📦 Base64 diff application | **For encoded diffs** |
| `verifyDiff()` | 🔐 Diff integrity verification | **For validation** |
| `createUndoDiff()` | ↩️ Automatic undo generation | **For rollback** |

### 🔥 **Recommended Usage Pattern**

```swift
// ✅ STANDARD: Enhanced core methods (2025)
// Step 1: Create diff with automatic intelligence
let diff = MultiLineDiff.createDiff(
    source: originalCode,
    destination: modifiedCode
)

// Step 2: Apply intelligently - works with ANY source type automatically!
let result = try MultiLineDiff.applyDiff(to: anySource, diff: diff)
// Works perfectly with:
// - Full documents
// - Truncated sections  
// - Partial content
// - Mixed scenarios
// NO manual configuration needed! 🎉
```

### 🆚 **Enhanced vs Traditional Methods**

```swift
// ❌ OLD WAY: Manual configuration required
let diff = MultiLineDiff.createDiff(
    source: truncatedContent,
    destination: modifiedContent,
    includeMetadata: true,
    sourceStartLine: 42  // Manual parameter
)

let result = try MultiLineDiff.applyDiff(
    to: fullDocument, 
    diff: diff,
    allowTruncatedSource: true  // Manual decision
)

// ✅ NEW WAY: Automatic everything!
let diff = MultiLineDiff.createDiff(
    source: truncatedContent,
    destination: modifiedContent
)

let result = try MultiLineDiff.applyDiff(to: fullDocument, diff: diff)
// Automatically detects, matches, and applies correctly! 🚀
```

### 🔐 **Core Methods with Verification (Maximum Safety)**

```swift
// Create diff with built-in integrity verification
let diff = MultiLineDiff.createDiff(
    source: originalCode,
    destination: modifiedCode
)

// Apply with automatic verification built-in
let result = try MultiLineDiff.applyDiff(to: sourceCode, diff: diff)

// Check diff integrity (automatic)
if MultiLineDiff.verifyDiff(diff) {
    print("✅ Diff integrity verified")
}

// Create undo operation (automatic)
if let undoDiff = MultiLineDiff.createUndoDiff(from: diff) {
    let restored = try MultiLineDiff.applyDiff(to: result, diff: undoDiff)
    assert(restored == originalCode) // Perfect restoration
}
```

### 📦 **Core Methods with Base64 Encoding**

```swift
// Create Base64 diff
let base64Diff = try MultiLineDiff.createBase64Diff(
    source: sourceCode,
    destination: destinationCode
)

// Apply Base64 diff - automatically handles everything
let result = try MultiLineDiff.applyBase64Diff(
    to: anySource, 
    base64Diff: base64Diff
)
```

### 🎯 **Real-World Example**

```swift
let fullDocument = """
# Documentation
## Setup Instructions
Setup content here.
## Configuration Settings  
Please follow these setup steps carefully.
This configuration is essential for operation.
## Advanced Configuration
Advanced content here.
"""

let truncatedSection = """
## Configuration Settings  
Please follow these setup steps carefully.
This configuration is essential for operation.
"""

let modifiedSection = """
## Configuration Settings  
Please follow these UPDATED setup steps carefully.
This configuration is CRITICAL for operation.
"""

// ✅ Enhanced Core Methods: One method handles everything
let diff = MultiLineDiff.createDiff(
    source: truncatedSection,
    destination: modifiedSection
)

// Apply to BOTH full document AND truncated section - both work automatically!
let resultFromFull = try MultiLineDiff.applyDiff(to: fullDocument, diff: diff)
let resultFromTruncated = try MultiLineDiff.applyDiff(to: truncatedSection, diff: diff)

// Core methods automatically:
// ✅ Detects source type (full vs truncated)
// ✅ Finds correct section using context matching
// ✅ Applies diff with confidence scoring
// ✅ Verifies integrity with checksums
// ✅ Handles edge cases gracefully
```

### 🏆 **Core Methods Benefits Summary**

| Feature | Traditional Methods | Enhanced Core Methods |
|---------|-------------------|-------------------|
| **Configuration** | ❌ Manual parameters required | ✅ Zero configuration |
| **Source Detection** | ❌ Manual `allowTruncatedSource` | ✅ Automatic detection |
| **Context Matching** | ❌ Basic | ✅ Dual context + confidence |
| **Verification** | ❌ Manual checksum checking | ✅ Built-in verification |
| **Undo Operations** | ❌ Manual reverse diff creation | ✅ Automatic undo generation |
| **Error Handling** | ❌ Basic | ✅ Enhanced with fallbacks |
| **API Complexity** | ❌ Multiple parameters | ✅ Simple, clean API |

**Recommendation**: Use the enhanced core methods for all new code. They provide the same performance with significantly enhanced intelligence and safety. 🚀

## 🚀 Enhanced Truncated Diff Support with Auto-Detection

MultiLineDiff now features **intelligent auto-detection** and enhanced truncated diff capabilities, making it incredibly flexible for partial document transformations without manual configuration.

### 🤖 NEW Auto-Detection Features (2025)

- **Automatic Source Type Detection**: Automatically determines if source is full document or truncated section
- **Intelligent Application**: No manual `allowTruncatedSource` parameter needed
- **Dual Context Matching**: Uses preceding and following context for precise section location
- **Source Verification**: Compares input source against stored source content for accuracy
- **Checksum Verification**: Ensures diff integrity and correct application
- **Undo Operations**: Automatic reverse diff generation for rollback functionality
- **Confidence Scoring**: Ensures the best matching section is selected

### Key Truncated Diff Capabilities

- Apply diffs to full or partial documents
- Preserve context and metadata
- Intelligent section replacement
- Automatic line number interpolation
- **Auto-detection of full vs truncated sources** 🆕
- **Intelligent context-based matching** 🆕

#### Truncated Diff Usage: Line Number Handling

When working with truncated sources, follow these guidelines for `sourceStartLine`:

1. **If You Know the Exact Line Number**:
```swift
// ✅ PREFERRED: Enhanced core methods (automatically handles everything)
let diff = MultiLineDiff.createDiff(
    source: truncatedContent,
    destination: modifiedContent,
    sourceStartLine: 42  // Optional: enhances accuracy
)

// ❌ TRADITIONAL: Manual configuration
let diff = MultiLineDiff.createDiff(
    source: truncatedContent,
    destination: modifiedContent,
    includeMetadata: true,
    sourceStartLine: 42  // Manual parameter required
)
```

2. **If Line Number is Unknown**:
```swift
// ✅ PREFERRED: Core methods (auto-interpolates)
let diff = MultiLineDiff.createDiff(
    source: truncatedContent,
    destination: modifiedContent
    // No sourceStartLine needed - core methods handle it
)

// ❌ TRADITIONAL: Manual fallback
let diff = MultiLineDiff.createDiff(
    source: truncatedContent,
    destination: modifiedContent,
    includeMetadata: true,
    sourceStartLine: 1  // Manual fallback
)
```

**Enhanced Core Practices**:
- **Best Practice**: Use `createDiff()` - automatically handles line interpolation
- **Enhanced Accuracy**: Optionally specify `sourceStartLine` for better precision
- Core methods use dual context and confidence scoring for intelligent section location
- Built-in verification ensures correct application

### Line Number Interpolation

The core methods automatically:
- Analyzes preceding and following context
- Uses metadata to determine the most likely section
- Intelligently applies the diff to the correct location
- Provides confidence scoring for section matching

### Full Document Diff Application

```swift
let originalDocument = """
Chapter 1: Introduction
...
Chapter 2: Core Concepts
This section explains the fundamental principles.
More detailed explanation here.
...
"""

let truncatedSection = """
Chapter 2: Core Concepts
This section explains the fundamental principles.
More detailed explanation here.
"""

let updatedSection = """
Chapter 2: Core Concepts
This section provides a comprehensive explanation of fundamental principles.
Enhanced and more detailed insights.
"""

// ✅ PREFERRED: Enhanced core methods (fully automatic)
let diff = MultiLineDiff.createDiff(
    source: truncatedSection,
    destination: updatedSection
)

// Apply intelligently - works on both full document and truncated section
let updatedDocument = try MultiLineDiff.applyDiff(to: originalDocument, diff: diff)

// ❌ TRADITIONAL: Manual configuration required
let diff = MultiLineDiff.createDiff(
    source: truncatedSection,
    destination: updatedSection,
    includeMetadata: true,
    sourceStartLine: 2
)

let updatedDocument = try MultiLineDiff.applyDiff(
    to: originalDocument, 
    diff: diff,
    allowTruncatedSource: true  // Manual parameter
)
```

The core methods handle all the complexity automatically while providing the same powerful functionality.

### 🤖 NEW Intelligent Auto-Application (2025)

The enhanced version automatically detects source type and applies diffs intelligently:

```swift
// ✅ PREFERRED: Core methods - fully automatic
let diff = MultiLineDiff.createDiff(
    source: truncatedSection,
    destination: updatedSection
)

// Intelligent application - automatically detects if full document or truncated source
let result = try MultiLineDiff.applyDiff(to: anySource, diff: diff)
// Works with BOTH full documents AND truncated sections automatically!

// ❌ TRADITIONAL: Manual detection required
let diff = MultiLineDiff.createDiff(
    source: truncatedSection,
    destination: updatedSection,
    includeMetadata: true,
    sourceStartLine: 2  // Manual parameter
)

// Manual application with parameters
let result = try MultiLineDiff.applyDiff(to: anySource, diff: diff)
// Requires manual `allowTruncatedSource` configuration
```

### 🔐 Enhanced Verification and Undo Operations

```swift
// ✅ PREFERRED: Core methods with built-in verification
let diff = MultiLineDiff.createDiff(
    source: originalCode,
    destination: modifiedCode
)

// Automatic verification and checksum generation
if let hash = diff.metadata?.diffHash {
    print("✅ Diff integrity hash: \(hash)")
}

// Apply with automatic verification
let result = try MultiLineDiff.applyDiff(to: originalCode, diff: diff)

// Undo operation (automatic reverse diff)
let undoDiff = MultiLineDiff.createUndoDiff(from: diff)!
let restored = try MultiLineDiff.applyDiff(to: result, diff: undoDiff)
assert(restored == originalCode) // Perfect restoration

// ❌ TRADITIONAL: Manual verification steps
let diff = MultiLineDiff.createDiff(
    source: originalCode,
    destination: modifiedCode,
    includeMetadata: true
)

// Manual checksum verification
if let hash = diff.metadata?.diffHash {
    print("Diff integrity hash: \(hash)")
}

// Manual application
let result = try MultiLineDiff.applyDiff(to: originalCode, diff: diff)

// Manual undo diff creation
let undoDiff = MultiLineDiff.createUndoDiff(from: diff)
let restored = try MultiLineDiff.applyDiff(to: result, diff: undoDiff!)
assert(restored == originalCode)
```

### 🎯 Dual Context Matching Example

```swift
let fullDocument = """
# Documentation
## Setup Instructions
Setup content here.
## Configuration Settings  
Please follow these setup steps carefully.
This configuration is essential for operation.
## Advanced Configuration
Advanced content here.
"""

let truncatedSection = """
## Configuration Settings  
Please follow these setup steps carefully.
This configuration is essential for operation.
"""

let modifiedSection = """
## Configuration Settings  
Please follow these UPDATED setup steps carefully.
This configuration is CRITICAL for operation.
"""

// ✅ PREFERRED: Core methods with enhanced dual context
let diff = MultiLineDiff.createDiff(
    source: truncatedSection,
    destination: modifiedSection
)

// Automatic intelligent application - works on BOTH:
let resultFromFull = try MultiLineDiff.applyDiff(to: fullDocument, diff: diff)
let resultFromTruncated = try MultiLineDiff.applyDiff(to: truncatedSection, diff: diff)

// Both results are correctly transformed with automatic context matching!

// ❌ TRADITIONAL: Manual dual context handling
let diff = MultiLineDiff.createDiff(
    source: truncatedSection,
    destination: modifiedSection,
    includeMetadata: true
)

// Manual application with explicit parameters
let resultFromFull = try MultiLineDiff.applyDiff(to: fullDocument, diff: diff, allowTruncatedSource: true)
let resultFromTruncated = try MultiLineDiff.applyDiff(to: truncatedSection, diff: diff)
```

## 🛡️ Reliability & Automatic Verification

MultiLineDiff includes a built-in verification system that ensures diff reliability through automatic algorithm fallback.

### Automatic Algorithm Fallback

When using the Optimus algorithm (`.optimus`), the library now includes a sophisticated verification mechanism:

1. **Create Diff**: Generate diff using Optimus algorithm
2. **Verify Integrity**: Apply the diff to source and verify result matches destination
3. **Automatic Fallback**: If verification fails, automatically fallback to Flash algorithm
4. **Transparent Operation**: Users get reliable results without manual intervention

### How Verification Works

```swift
// When you request Optimus algorithm
let diff = MultiLineDiff.createDiff(
    source: sourceCode,
    destination: destinationCode,
    algorithm: .optimus  // Optimus algorithm with automatic fallback
)

// Internal process:
// 1. Generate Optimus diff
// 2. Apply Optimus diff to source
// 3. Check: result == destination?
//    ✅ Yes → Return Optimus diff (more granular)
//    ❌ No  → Automatically use Flash diff (more reliable)
```

### Verification Benefits

- **Zero False Positives**: Diffs are guaranteed to work correctly
- **Best of Both Worlds**: Get Optimus's sophistication when possible, Flash's reliability when needed
- **Transparent Fallback**: No additional code required from developers
- **Metadata Tracking**: `algorithmUsed` metadata reflects actual algorithm used

### Fallback Scenarios

The system automatically falls back to Flash algorithm when:
- Optimus diff produces incorrect transformation results
- Optimus diff operations cannot be applied to source
- Complex text structures that challenge Optimus's semantic analysis

### Example with Fallback Tracking

```swift
let diff = MultiLineDiff.createDiff(
    source: complexSource,
    destination: complexDestination,
    algorithm: .optimus,
    includeMetadata: true
)

// Check which algorithm was actually used
if let actualAlgorithm = diff.metadata?.algorithmUsed {
    switch actualAlgorithm {
    case .optimus:
        print("✅ Optimus algorithm succeeded - granular diff")
    case .flash:
        print("🔄 Fallback to Flash algorithm - reliable diff")
    }
}

// Either way, the diff is guaranteed to work correctly
let result = try MultiLineDiff.applyDiff(to: complexSource, diff: diff)
assert(result == complexDestination) // Always passes
```

### Verification Performance Impact

- **Minimal Overhead**: Verification adds ~0.1ms for typical diffs
- **Early Exit**: If Optimus succeeds (most cases), no additional processing
- **Smart Caching**: Verification results are internally optimized

## 🚀 Why Base64?

1. **Compact Representation**: Reduces diff size
2. **Safe Transmission**: Avoids escaping issues
3. **Universal Compatibility**: Works across different systems
4. **AI-Friendly**: Ideal for code transformation pipelines

## 🔍 Algorithm Complexity Analysis

*Based on actual performance measurements from MultiLineDiffRunner*

### Flash - Simple - Algorithm Big O Notation

| Metric | Complexity | Explanation | Real Performance | Visual |
|--------|------------|-------------|------------------|----------------------|
| **Time Complexity** | O(n) | Linear time complexity | **0.0960 ms create** | 🟢🟢🟢  |
| **Space Complexity** | O(1) | Constant space usage | **Minimal memory** | 🟢🟢🟢  |
| **Apply Performance** | O(n) | Direct character operations | **0.0220 ms apply** | 🟢🟢🟢  |
| **Total Operations** | Low | Simple retain/insert/delete | **4 operations** | 🟢🟢🟢  |
| **Best Case** | Ω(1) | Identical strings | **<0.01 ms** | 🟢🟢🟢  |
| **Worst Case** | O(n) | Complete string replacement | **~0.5 ms** | 🟢🟢🟢  |

#### Performance Profile
```
Creation Speed:  🟢🟢🟢 (0.0960 ms)
Application:     🟢🟢🟢 (0.0220 ms) 
Memory Usage:    🟢🟢🟢 (Minimal)
Operation Count: 🟢🟢🟢 (4 ops)
```

### Optimus - Smart - Algorithm Big O Notation

| Metric | Complexity | Explanation | Real Performance | Visual |
|--------|------------|-------------|------------------|----------------------|
| **Time Complexity** | O(n log n) | LCS-based semantic analysis | **0.3460 ms** | 🟢🟢🟡  |
| **Space Complexity** | O(n) | Linear space for LCS table | **Optimized** | 🟢🟢🟢  |
| **Apply Performance** | O(n) | Sequential operation application | **0.0180 ms** | 🟢🟢🟢  |
| **Total Operations** | High | Granular semantic operations | **22 ops** | 🟢🟢🟡  |
| **Best Case** | Ω(n) | Simple structural changes | **~0.2 ms** | 🟢🟢🟢 |
| **Worst Case** | O(n²) | Complex text transformations | **~1.0 ms** | 🟢🟢🟡  |

#### Performance Profile
```
Creation Speed:  🟢🟢🟡 (0.3460 ms) - Performance optimized!
Application:     🟢🟢🟢 (0.0180 ms) - Excellent performance
Memory Usage:    🟢🟢🟢 (Optimized LCS)
Operation Count: 🟢🟢🟡 (22 ops - 5.5x more detailed)
```

## 🚀 Performance Optimizations for Swift 6.1

### Compiler Speed Optimizations
- **`@_optimize(speed)` Annotations**: 11 performance-critical methods optimized for maximum speed
- **Compile-Time Inlining**: Utilizes Swift 6.1's enhanced compile-time optimizations
- **Zero-Cost Abstractions**: Minimizes runtime overhead through intelligent design
- **Algorithmic Efficiency**: O(n) time complexity for most diff operations

### Enhanced Memory Management
- **Pre-sized Allocations**: `reserveCapacity()` for dictionaries and arrays to avoid reallocations
- **Conditional Processing**: Smart allocation based on metadata presence
- **Value Type Semantics**: Leverages Swift's efficient value type handling
- **Minimal Heap Allocations**: Reduces memory churn and garbage collection pressure
- **Precise Memory Ownership**: Implements strict memory ownership rules to prevent unnecessary copying

### File I/O Optimizations
- **Atomic File Operations**: `options: [.atomic]` for safe concurrent access
- **Memory-Mapped Reading**: `options: [.mappedIfSafe]` for large file performance
- **Enhanced JSON Processing**: Optimized Base64 encoding/decoding with Swift 6.1 features
- **Error Handling**: Enhanced fallback mechanisms for legacy compatibility

### Swift 6.1 Feature Utilization
- **17 Total Optimizations** across 3 core modules (MultiLineDiff.swift, MultiLineJSON.swift, MultLineFile.swift)
- **Enhanced String Processing**: Optimized Unicode-aware operations
- **Improved JSON Serialization**: Swift 6.1 enhanced serialization with better memory usage
- **Optimized Base64 Operations**: Faster encoding/decoding with validation improvements

### 🔧 Detailed Swift 6.1 Implementation

#### Core Algorithm Optimizations
```swift
// Example of @_optimize(speed) usage throughout the codebase
@_optimize(speed)
public static func createDiff(source: String, destination: String) -> DiffResult {
    // Swift 6.1 optimized diff generation
}

@_optimize(speed) 
public static func encodeDiffToJSON(_ diff: DiffResult) throws -> Data {
    // Pre-sized dictionary allocation
    var wrapper: [String: Any] = [:]
    wrapper.reserveCapacity(diff.metadata != nil ? 2 : 1)
    // Enhanced JSON serialization...
}
```

#### Memory Management Enhancements
```swift
// Before: Default allocation
var wrapper: [String: Any] = ["key": value]

// After: Swift 6.1 optimized allocation  
var wrapper: [String: Any] = [:]
wrapper.reserveCapacity(expectedSize) // Prevents reallocations
wrapper["key"] = value
```

#### File I/O Improvements
```swift
// Enhanced file operations with atomic writes and memory mapping
try data.write(to: fileURL, options: [.atomic])           // Safe concurrent access
let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])  // Fast large file reading
```

## Performance Comparison

| Metric | MultiLineDiff (Swift 6.1) | Traditional Diff Libraries |
|--------|---------------------------|----------------------------|
| Speed | ⚡️ Ultra-Fast + Optimized | 🐌 Slower |
| Memory Usage | 🧠 Low + Pre-sized | 🤯 Higher |
| Scalability | 🚀 Excellent + Enhanced | 📉 Limited |
| File I/O | 🔒 Atomic + Memory-Mapped | 📄 Standard |

## 📦 Diff Representation Formats

### Diff Operation Types

```swift
enum DiffOperation {
    case retain(Int)     // Keep existing characters
    case delete(Int)     // Remove characters
    case insert(String)  // Add new characters
}
```

### Detailed Diff Visualization

```swift
let sourceCode = """
class Example {
    func oldMethod() {
        print("Hello")
    }
}
"""

let destinationCode = """
class Example {
    func newMethod() {
        print("Hello, World!")
    }
}
"""

// Create diff operations
let diffOperations = MultiLineDiff.createDiff(source: sourceCode, destination: destinationCode)

// Apply the diff operations
let result = try MultiLineDiff.applyDiff(to: sourceCode, diff: diffOperations)

// Verify the transformation
assert(result == destinationCode, "Applied diff should match destination code")
```

### Base64 Diff Decoding Example

```swift
// Decode Base64 Diff
func decodeBase64Diff(_ base64String: String) -> String {
    guard let decodedData = Data(base64Encoded: base64String),
          let jsonString = String(data: decodedData, encoding: .utf8) else {
        return "Decoding failed"
    }
    return jsonString
}

// Example of Base64 Diff Decoding
let decodedDiffOperations = decodeBase64Diff(base64Diff)
```

## 🔍 Diff Operation Insights

### Operation Symbols

| Symbol | Operation | Description |
|--------|-----------|-------------|
| `===` | Retain    | Keep text as is |
| `---` | Delete    | Remove text |
| `+++` | Insert    | Add new text |
| `▼`    | Position  | Current operation point |
| `┌─┐`  | Section   | Groups related changes |
| `└─┘`  | Border    | Section boundary |

### Basic Examples

```swift
Source:      "Hello, world!"
Destination: "Hello, Swift!"
Operation:    ====== ----- ++++++   // "Hello, " retained, "world" deleted, "Swift" inserted
             |||||| xxxxx ++++++
             Hello, world Swift
```

### Another Example

```swift
┌─ Source
│ func calculateTotal(items: [Product]) -> Double {
│     var total = 0.0
│     for item in items {
│         total += item.price
│     }
│     return total
│ }
└─────────────────

┌─ Destination
│ func calculateTotal(items: [Product]) -> Double {
│     return items.reduce(0.0) { $0 + $1.price }
│ }
└─────────────────

┌─ Operations
│ { ===    // retain signature
│ ┌─ Delete old implementation and insert new implementation
│ │ --- var total = 0.0
│ │ --- for item in items {
│ │ ---     total += item.price
│ │ --- }
│ │ --- return total
│ │ +++ return items.reduce(0.0) { $0 + $1.price }
│ └─ 
│ } ===                                     // retain closing brace
└─────────────────
```

### Real-World Algorithm Comparison: User Struct Refactoring

#### Original Source Code
```swift
import Foundation

struct User {
    let id: UUID
    var name: String
    var email: String
    var age: Int
    
    init(name: String, email: String, age: Int) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.age = age
    }
    
    func greet() -> String {
        return "Hello, my name is \(name)!"
    }
}

// Helper functions
func validateEmail(_ email: String) -> Bool {
    // Basic validation
    return email.contains("@")
}

func createUser(name: String, email: String, age: Int) -> User? {
    guard validateEmail(email) else {
        return nil
    }
    return User(name: name, email: email, age: age)
}
```

#### Refactored Destination Code
```swift
import Foundation
import UIKit

struct User {
    let id: UUID
    var name: String
    var email: String
    var age: Int
    var avatar: UIImage?
    
    init(name: String, email: String, age: Int, avatar: UIImage? = nil) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.age = age
        self.avatar = avatar
    }
    
    func greet() -> String {
        return "👋 Hello, my name is \(name)!"
    }
    
    func updateAvatar(_ newAvatar: UIImage) {
        self.avatar = newAvatar
    }
}

// Helper functions
func validateEmail(_ email: String) -> Bool {
    // Enhanced validation
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: email)
}

func createUser(name: String, email: String, age: Int, avatar: UIImage? = nil) -> User? {
    guard validateEmail(email) else {
        return nil
    }
    return User(name: name, email: email, age: age, avatar: avatar)
}
```

### Diff Operation Breakdown

### Performance Comparison

| Metric | Optimus Algorithm | Flash Algorithm |
|--------|----------------|----------------|
| **Total Operations** | 12-15 detailed operations | 4-6 simplified operations |
| **Create Diff Time** | 0.323 ms | 0.027 ms |
| **Apply Diff Time** | 0.003 ms | 0.002 ms |
| **Semantic Awareness** | 🧠 High (Preserves structure) | 🔤 Low (Character replacement) |
| **Best Used For** | Complex refactoring | Simple text changes |

### Detailed Transformation Visualization

```
┌─ Optimus Algorithm (.optimus) - Semantic Diff
│ === Preserve import statements
│ +++ Add UIKit import
│ === Retain struct declaration
│ +++ Add avatar property
│ --- Remove basic initializer
│ +++ Add enhanced initializer
│ --- Remove basic greet method
│ +++ Add emoji-enhanced greet method
│ +++ Insert updateAvatar method
│ --- Remove basic email validation
│ +++ Add comprehensive email validation
└─────────────────
// Detailed Operations: ~12-15 semantic operations
// Preserves code structure and intent
```

## 🔤 ASCII Diff I/O and Terminal Diff Output

MultiLineDiff provides powerful and flexible diff representation methods for various use cases, including AI models and terminal users.

### 📝 ASCII Diff Formats

MultiLineDiff supports two primary diff display formats:

1. **AI Format (`.ai`)**: Plain ASCII output suitable for AI models
2. **Terminal Format (`.terminal`)**: Colored terminal output with ANSI codes

#### ASCII Diff Symbols

| Symbol | Meaning | Description |
|--------|---------|-------------|
| `= `   | Retain  | Unchanged lines |
| `- `   | Delete  | Removed lines |
| `+ `   | Insert  | Added lines |

### 🤖 AI-Friendly Diff Generation

```swift
// Create an AI-friendly ASCII diff
let aiDiff = MultiLineDiff.createAndDisplayDiff(
    source: oldCode,
    destination: newCode,
    format: .ai
)
```

#### Example AI Diff

```swift
= func calculate() -> Int {
-     return 42
+     return 100
= }
```

### 🖥️ Terminal Diff Output

MultiLineDiff offers multiple terminal diff visualization options:

1. **Colored Diff**
```swift
let coloredDiff = MultiLineDiff.createAndDisplayDiff(
    source: oldCode,
    destination: newCode,
    format: .terminal
)
```

2. **Highlighted Diff**
```swift
let highlightedDiff = MultiLineDiff.generateHighlightedTerminalDiff(
    source: oldCode,
    destination: newCode
)
```

### 🔄 ASCII Diff Parsing and Application

```swift
// Parse an ASCII diff submitted by an AI
let aiSubmittedDiff = """
= func calculate() -> Int {
-     return 42
+     return 100
= }
"""

let result = try MultiLineDiff.applyASCIIDiff(
    to: sourceCode,
    asciiDiff: aiSubmittedDiff
)
```

### 🎯 Workflow Demonstration

```swift
// Full round-trip ASCII diff workflow
let demo = try MultiLineDiff.demonstrateASCIIWorkflow(
    source: originalCode,
    destination: modifiedCode
)

print(demo.asciiDiff)        // View the generated ASCII diff
print(demo.success)          // Check if workflow succeeded
print(demo.summary)          // Get a summary of the process
```

### 🌈 Terminal Output Styles

| Style | Description | Use Case |
|-------|-------------|----------|
| **Colored Diff** | ANSI color-coded changes | Quick visual diff |
| **Highlighted Diff** | Background color highlighting | Detailed change visualization |
| **ASCII Diff** | Plain text representation | AI model input |

### 🚀 Key Benefits

- **AI-Friendly**: Readable ASCII format for AI models
- **Terminal-Ready**: Colorful, informative diff displays
- **Flexible**: Multiple output formats
- **Intelligent**: Preserves code structure and intent

## 📝 License

MIT

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 

(c) 2025 Optimus Flashs

## 📦 Diff Operation Examples

### Basic Diff Operations

```swift
enum DiffOperation {
    case retain(Int)     // Keep existing characters
    case delete(Int)     // Remove characters
    case insert(String)  // Add new characters
}
```

### Retain Operation Example

```swift
Source:      "Hello, world!"
Destination: "Hello, Swift!"
Operation:    ====== ▼        // Retain "Hello, "
             ||||||  |
             Hello,  w
```

### Delete Operation Example

```swift
Source:      "Hello, world!"
Destination: "Hello!"
Operation:    ====== -----    // Delete "world"
             |||||| xxxxx
             Hello, world
```

### Insert Operation Example

```swift
Source:      "Hello!"
Destination: "Hello, world!"
Operation:    ====== ++++++   // Insert ", world"
             |||||| ------
             Hello, world
```

### Replace (Delete and Insert) Operation Example

```swift
Source:      "Hello, world!"
Destination: "Hello, Swift!"
Operation:    ====== ----- ++++++   // "Hello, " retained, "world" deleted, "Swift" inserted
             |||||| xxxxx ++++++
             Hello, world Swift
```

### Another Example

```swift
// Source
func calculateTotal(items: [Product]) -> Double {
    var total = 0.0
    for item in items {
        total += item.price
    }
    return total
}

// Destination
func calculateTotal(items: [Product]) -> Double {
    return items.reduce(0.0) { $0 + $1.price }
}

// Visual Representation:
┌─ Source
│ func oldMethod() {
│     print("Hello")
│ }
└─────────────────
   ↓ Transform ↓
┌─ Destination
│ func newMethod() {
│     print("Hello, World!")
│ }
└─────────────────
```

### Operation Symbols Legend

| Symbol | Operation | Description |
|--------|-----------|-------------|
| `====` | Retain    | Keep existing code |
| `----` | Delete    | Remove code section |
| `++++` | Insert    | Add new code section |
| `▼`    | Position  | Current transformation point |
| `┌─┐`  | Section   | Diff operation group |
| `└─┘`  | Border    | Section boundary |

### Flash Algorithm - Speed Champion 🏃‍♂️
- **Ultra-fast creation**: 12.0x faster than Optimus
- **Lightning apply**: 2.7x faster than Optimus
- **Minimal operations**: ~75% fewer operations
- **Best for**: Performance-critical applications, simple changes

#### Optimus Algorithm - Precision Master 🎯
- **Granular operations**: 5.5x more detailed
- **Semantic awareness**: Preserves code structure
- **With fallback**: Zero-risk reliability
- **Optimized performance**: Enhanced with enum consolidation
- **Best for**: Code transformations, complex changes, AI applications

### Performance Recommendations

| Use Case | Recommended | Reason |
|----------|-------------|---------|
| **Real-time editing** | Flash | 0.029ms total time |
| **Bulk processing** | Flash | ~12x speed advantage |
| **Code refactoring** | Optimus + Fallback | Precision + optimized performance |
| **AI transformations** | Optimus + Fallback | Semantic awareness + performance |
| **Complex changes** | Optimus | Worth the 0.32ms for intelligence |
| **Simple text edits** | Flash | Raw speed advantage |

### Performance Comparison Results (Updated 2025 - Latest Benchmarks)

**Test Environment**: 1000 iterations, Source Code: 664 chars, Modified Code: 1053 chars

| Metric | Flash Algorithm | Optimus Algorithm | Performance Ratio |
|--------|----------------|----------------|-------------------|
| **Total Operations** | 4 operations | 22 operations | 5.5x more granular |
| **Create Diff Time** | 0.0960 ms | 0.3460 ms | **3.6x faster** (Flash) |
| **Apply Diff Time** | 0.0220 ms | 0.0180 ms | **1.2x faster** (Optimus) |
| **Total Time** | 0.1180 ms | 0.3640 ms | **3.1x faster** (Flash) |
| **Retained Characters** | 21 chars (3.2%) | 397 chars (59.8%) | **18.9x more preservation** (Optimus) |
| **Semantic Awareness** | 🔤 Character-level | 🧠 Structure-aware | Intelligent |
| **Test Suite** | ✅ all tests pass | ✅ all tests pass | 100% reliability |

### Performance Visualization (Updated 2025)

```
Speed Comparison (Total Time - 1000 iterations averaged):
Flash: ██████████ 0.1180 ms
Optimus: ████████████████████████████████████ 0.3640 ms

Operation Breakdown:
Flash: 4 ops (2 retain, 1 insert, 1 delete)
  - Retained: 21 chars (3.2%)
  - Inserted: 1032 chars
  - Deleted: 643 chars

Optimus: 22 ops (9 retain, 8 insert, 5 delete)
  - Retained: 397 chars (59.8%)
  - Inserted: 656 chars
  - Deleted: 267 chars

Test Suite Performance:
33 Tests: ✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅ (100% pass rate)
Duration: ~0.224-0.565 seconds for complete test suite
```

### Performance Comparison (Detailed Metrics)

| Algorithm | Create Time | Apply Time | Total Time | Operations | Speed Factor |
|-----------|-------------|------------|------------|------------|--------------|
| **Flash** | 0.0960 ms | 0.0220 ms | **0.1180 ms** | 4 | **1.0x** ⚡ |
| **Optimus** | 0.3460 ms | 0.0180 ms | **0.3640 ms** | 22 | **3.1x slower** |

created by Todd (Optimus Flash) Bruss (c) 2025 XCF.ai

