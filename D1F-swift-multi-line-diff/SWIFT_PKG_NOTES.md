# Swift MultiLineDiff Package Usage Guide

## 📦 Package Information

**Repository**: [CodeFreezeAI/swift-multi-line-diff](https://github.com/CodeFreezeAI/swift-multi-line-diff.git)  
**License**: MIT  
**Language**: Swift 100%  
**Latest Release**: v1.3.3 (May 25, 2025)  
**Creator**: Todd Bruss © xcf.ai

---

## 🚀 Installation Methods

### Method 1: Swift Package Manager (Recommended)

#### Via Xcode
1. Open your Xcode project
2. Go to **File** → **Add Package Dependencies**
3. Enter the repository URL:
   ```
   https://github.com/CodeFreezeAI/swift-multi-line-diff.git
   ```
4. Select version `1.3.3` or **Up to Next Major Version**
5. Click **Add Package**
6. Select **MultiLineDiff** target and click **Add Package**

#### Via Package.swift
Add the dependency to your `Package.swift` file:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YourProject",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13_0),
        .watchOS(.v6_0),
        .tvOS(.v13_0)
    ],
    dependencies: [
        .package(
            url: "https://github.com/CodeFreezeAI/swift-multi-line-diff.git",
            from: "1.3.3"
        )
    ],
    targets: [
        .target(
            name: "YourTarget",
            dependencies: [
                .product(name: "MultiLineDiff", package: "swift-multi-line-diff")
            ]
        )
    ]
)
```

Then run:
```bash
swift package resolve
swift build
```

### Method 2: Local Compilation

#### Clone and Build Locally
```bash
# Clone the repository
git clone https://github.com/CodeFreezeAI/swift-multi-line-diff.git
cd swift-multi-line-diff

# Build the package
swift build

# Run tests to verify installation
swift test

# Build in release mode for production
swift build -c release
```

#### Integration into Local Project
```bash
# Add as a local dependency in your Package.swift
.package(path: "../path/to/swift-multi-line-diff")
```

---

## 📱 Platform Support

| Platform | Minimum Version |
|----------|----------------|
| **macOS** | 10.15+ |
| **iOS** | 13.0+ |
| **watchOS** | 6.0+ |
| **tvOS** | 13.0+ |
| **Linux** | Swift 5.9+ |

---

## 🔧 Basic Usage

### Import the Package
```swift
import MultiLineDiff
```

### Quick Start Examples

#### 1. Basic Diff Creation
```swift
import MultiLineDiff

let source = """
func greet() {
    print("Hello")
}
"""

let destination = """
func greet() {
    print("Hello, World!")
}
"""

// Create diff using default Megatron algorithm
let diff = MultiLineDiff.createDiff(
    source: source,
    destination: destination
)

// Apply the diff
let result = try MultiLineDiff.applyDiff(to: source, diff: diff)
print(result) // Outputs the destination text
```

#### 2. Algorithm Selection
```swift
// Ultra-fast Flash algorithm (recommended for speed)
let flashDiff = MultiLineDiff.createDiff(
    source: source,
    destination: destination,
    algorithm: .flash
)

// Detailed Optimus algorithm (recommended for precision)
let optimusDiff = MultiLineDiff.createDiff(
    source: source,
    destination: destination,
    algorithm: .optimus
)

// Semantic Megatron algorithm (recommended for complex changes)
let megatronDiff = MultiLineDiff.createDiff(
    source: source,
    destination: destination,
    algorithm: .megatron
)
```

#### 3. ASCII Diff Display
```swift
// Generate AI-friendly ASCII diff
let asciiDiff = MultiLineDiff.createAndDisplayDiff(
    source: source,
    destination: destination,
    format: .ai,
    algorithm: .flash
)

print("ASCII Diff for AI:")
print(asciiDiff)
// Output:
// 📎 func greet() {
// ❌     print("Hello")
// ✅     print("Hello, World!")
// 📎 }
```

#### 4. JSON and Base64 Encoding
```swift
// Create diff with metadata
let diff = MultiLineDiff.createDiff(
    source: source,
    destination: destination,
    includeMetadata: true
)

// Convert to Base64 for storage/transmission
let base64Diff = try MultiLineDiff.diffToBase64(diff)
print("Base64 Diff: \(base64Diff)")

// Convert to JSON for APIs
let jsonString = try MultiLineDiff.encodeDiffToJSONString(diff, prettyPrinted: true)
print("JSON Diff: \(jsonString)")

// Restore from Base64
let restoredDiff = try MultiLineDiff.diffFromBase64(base64Diff)
let finalResult = try MultiLineDiff.applyDiff(to: source, diff: restoredDiff)
```

---

## 🎯 Advanced Features

### Truncated Diff Application
```swift
// Create a section diff
let sectionSource = """
func calculateTotal() -> Int {
    return 42
}
"""

let sectionDestination = """
func calculateTotal() -> Int {
    return 100
}
"""

let sectionDiff = MultiLineDiff.createDiff(
    source: sectionSource,
    destination: sectionDestination,
    algorithm: .megatron,
    includeMetadata: true,
    sourceStartLine: 10  // Line number in larger document
)

// Apply to full document (automatic detection)
let fullDocument = """
class Calculator {
    var value: Int = 0
    
    func calculateTotal() -> Int {
        return 42
    }
    
    func reset() {
        value = 0
    }
}
"""

let updatedDocument = try MultiLineDiff.applyDiff(to: fullDocument, diff: sectionDiff)
```

### Verification and Undo
```swift
// Create diff with full metadata
let diff = MultiLineDiff.createDiff(
    source: source,
    destination: destination,
    includeMetadata: true
)

// Verify diff integrity
let isValid = MultiLineDiff.verifyDiff(diff)
print("Diff is valid: \(isValid)")

// Create automatic undo diff
if let undoDiff = MultiLineDiff.createUndoDiff(from: diff) {
    let originalText = try MultiLineDiff.applyDiff(to: destination, diff: undoDiff)
    print("Undo successful: \(originalText == source)")
}
```

### AI Integration
```swift
// Parse AI-submitted ASCII diff
let aiSubmittedDiff = """
📎 func calculate() -> Int {
❌     return 42
✅     return 100
📎 }
"""

// Apply AI diff directly
let result = try MultiLineDiff.applyASCIIDiff(
    to: source,
    asciiDiff: aiSubmittedDiff
)
```

---

## 🔧 Build Configuration

### Development Build
```bash
# Debug build with full symbols
swift build --configuration debug

# Run with verbose output
swift build --verbose
```

### Production Build
```bash
# Optimized release build
swift build --configuration release

# Build with specific target
swift build --product MultiLineDiff
```

### Testing
```bash
# Run all tests
swift test

# Run specific test
swift test --filter MultiLineDiffTests

# Generate test coverage
swift test --enable-code-coverage
```

---

## 📊 Performance Optimization

### Algorithm Selection Guide
```swift
// For maximum speed (2x faster)
let fastDiff = MultiLineDiff.createDiff(
    source: source,
    destination: destination,
    algorithm: .flash,
    includeMetadata: false
)

// For maximum detail and accuracy
let detailedDiff = MultiLineDiff.createDiff(
    source: source,
    destination: destination,
    algorithm: .optimus,
    includeMetadata: true
)

// For balanced performance
let balancedDiff = MultiLineDiff.createDiff(
    source: source,
    destination: destination,
    algorithm: .megatron,
    includeMetadata: true
)
```

### Memory Management
```swift
// For large files, use streaming approach
func processLargeFile(sourceURL: URL, destURL: URL) throws {
    let source = try String(contentsOf: sourceURL)
    let destination = try String(contentsOf: destURL)
    
    // Use Flash algorithm for large files
    let diff = MultiLineDiff.createDiff(
        source: source,
        destination: destination,
        algorithm: .flash,
        includeMetadata: false
    )
    
    // Save to disk immediately
    let diffURL = sourceURL.appendingPathExtension("diff")
    try MultiLineDiff.saveDiffToFile(diff, fileURL: diffURL)
}
```

---

## 🛠️ Troubleshooting

### Common Issues

#### 1. Import Error
```swift
// ❌ Error: No such module 'MultiLineDiff'
import MultiLineDiff

// ✅ Solution: Ensure package is properly added to dependencies
// Check Package.swift or Xcode package dependencies
```

#### 2. Platform Compatibility
```swift
// ❌ Error: Platform version too low
// ✅ Solution: Update minimum deployment target
// iOS 13.0+, macOS 10.15+, watchOS 6.0+, tvOS 13.0+
```

#### 3. Memory Issues with Large Files
```swift
// ❌ Memory pressure with large files
// ✅ Solution: Use Flash algorithm and disable metadata
let diff = MultiLineDiff.createDiff(
    source: largeSource,
    destination: largeDestination,
    algorithm: .flash,
    includeMetadata: false
)
```

### Debug Information
```swift
// Enable debug output
#if DEBUG
print("Diff operations count: \(diff.operations.count)")
if let metadata = diff.metadata {
    print("Algorithm used: \(metadata.algorithmUsed?.displayName ?? "Unknown")")
    print("Source lines: \(metadata.sourceTotalLines ?? 0)")
}
#endif
```

---

## 📚 Documentation References

### Key Files in Repository
- **README.md**: Main documentation
- **ASCIIDIFF.md**: ASCII diff format specification
- **FLASH_OPTIMUS_ALGORITHMS.md**: Algorithm performance details
- **NEW_SUMMARY_2025.md**: Complete feature overview
- **Sources/**: Core implementation
- **Tests/**: Comprehensive test suite

### API Documentation
```swift
// Core methods
MultiLineDiff.createDiff(source:destination:algorithm:includeMetadata:)
MultiLineDiff.applyDiff(to:diff:)
MultiLineDiff.displayDiff(diff:source:format:)

// Encoding methods
MultiLineDiff.diffToBase64(_:)
MultiLineDiff.encodeDiffToJSON(_:prettyPrinted:)

// Verification methods
MultiLineDiff.verifyDiff(_:)
MultiLineDiff.createUndoDiff(from:)

// AI integration
MultiLineDiff.parseDiffFromASCII(_:)
MultiLineDiff.applyASCIIDiff(to:asciiDiff:)
```

---

## 🎯 Best Practices

### 1. Algorithm Selection
- **Flash**: Use for speed-critical applications
- **Optimus**: Use for detailed line-by-line analysis
- **Megatron**: Use for semantic understanding
- **Zoom**: Use for simple character-level changes
- **Starscream**: Use for line-aware processing

### 2. Metadata Usage
```swift
// Include metadata for verification and undo
let diff = MultiLineDiff.createDiff(
    source: source,
    destination: destination,
    includeMetadata: true  // Enables verification and undo
)
```

### 3. Error Handling
```swift
do {
    let result = try MultiLineDiff.applyDiff(to: source, diff: diff)
    // Success
} catch DiffError.invalidDiff {
    // Handle invalid diff
} catch DiffError.verificationFailed(let expected, let actual) {
    // Handle verification failure
} catch {
    // Handle other errors
}
```

### 4. Performance Monitoring
```swift
let startTime = CFAbsoluteTimeGetCurrent()
let diff = MultiLineDiff.createDiff(source: source, destination: destination)
let endTime = CFAbsoluteTimeGetCurrent()
print("Diff creation took: \((endTime - startTime) * 1000)ms")
```

---

## 🚀 Getting Started Checklist

- [ ] Add package dependency to your project
- [ ] Import MultiLineDiff in your Swift files
- [ ] Choose appropriate algorithm for your use case
- [ ] Test with small examples first
- [ ] Enable metadata for production use
- [ ] Implement error handling
- [ ] Consider performance requirements
- [ ] Test with your specific data formats

---

**Ready to revolutionize your diffing workflow with the world's most advanced diffing system!**

*Created by Todd Bruss © 2025 xcf.ai* 