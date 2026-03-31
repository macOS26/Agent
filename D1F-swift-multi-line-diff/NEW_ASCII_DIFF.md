# MultiLineDiff: ASCII Diff I/O and Terminal Output Documentation

## 🔤 ASCII Diff Symbols and Formatting

### Symbol Rules

**IMPORTANT:** ASCII diff symbols are actually two characters:
- `📎 ` (Paperclip + space): Retained/unchanged lines
- `❌ ` (Red X + space): Lines to be removed
- `✅ ` (Green checkmark + space): Lines to be added

### Color Coding and Visual Meaning

| Symbol | Operation | Visual Meaning | Description |
|--------|-----------|----------------|-------------|
| `📎 `  | Retain    | 📎 Paperclip | Unchanged lines - "keeps code together" |
| `❌ `  | Delete    | ❌ Red X | Lines to be removed - "delete this" |
| `✅ `  | Insert    | ✅ Green checkmark | New lines to be added - "add this" |
| `❓ `  | Unknown   | ❓ Question mark | Unknown operations - "unclear" |

## 🌈 Terminal Diff Output

### How Terminal Users See Diffs

When using `.terminal` format, users see colorful emoji symbols that make diffs instantly readable:

```swift
📎 class UserManager {
📎     private var users: [String: User] = [:]
✅     private var userCount: Int = 0
📎     
❌     func addUser(name: String, email: String) -> Bool {
✅     func addUser(name: String, email: String, age: Int = 0) -> Result<User, UserError> {
📎         guard !name.isEmpty && !email.isEmpty else {
❌             return false
✅             return .failure(.invalidInput)
📎         }
📎         
❌         let user = User(name: name, email: email)
✅         let user = User(id: UUID(), name: name, email: email, age: age)
📎         users[email] = user
❌         return true
✅         userCount += 1
✅         return .success(user)
📎     }
📎 }
```

### Terminal Output Features

1. **ANSI Color Support**: Symbols appear in their natural colors in supporting terminals
2. **Instant Recognition**: Visual symbols make scanning diffs effortless
3. **Professional Appearance**: Clean, business-like presentation
4. **Universal Symbols**: Paperclip, X, and checkmark are universally understood

### Generating Terminal Output

```swift
// Generate colored terminal diff
let terminalDiff = MultiLineDiff.createAndDisplayDiff(
    source: oldCode,
    destination: newCode,
    format: .terminal
)
print(terminalDiff)

// Or using the display method
let diff = MultiLineDiff.createDiff(source: oldCode, destination: newCode)
let terminalOutput = MultiLineDiff.displayDiff(
    diff: diff,
    source: oldCode,
    format: .terminal
)
```

## 🤖 AI-Friendly ASCII Diff Output

### How AI Models See Diffs

When using `.ai` format, AI models receive clean ASCII output perfect for processing:

```swift
📎 class UserManager {
📎     private var users: [String: User] = [:]
✅     private var userCount: Int = 0
📎     
❌     func addUser(name: String, email: String) -> Bool {
✅     func addUser(name: String, email: String, age: Int = 0) -> Result<User, UserError> {
📎         guard !name.isEmpty && !email.isEmpty else {
❌             return false
✅             return .failure(.invalidInput)
📎         }
📎         
❌         let user = User(name: name, email: email)
✅         let user = User(id: UUID(), name: name, email: email, age: age)
📎         users[email] = user
❌         return true
✅         userCount += 1
✅         return .success(user)
📎     }
📎 }
```

### AI Output Features

1. **Clean ASCII**: No ANSI color codes, pure text
2. **Semantic Symbols**: Emoji symbols provide clear semantic meaning
3. **Parseable Format**: AI can easily understand and generate these diffs
4. **Consistent Structure**: Every line follows the same `symbol + space + content` pattern

### Generating AI-Friendly Output

```swift
// Generate AI-friendly ASCII diff
let aiDiff = MultiLineDiff.createAndDisplayDiff(
    source: oldCode,
    destination: newCode,
    format: .ai
)

// Send to AI model
sendToAI(aiDiff)

// Or using the display method
let diff = MultiLineDiff.createDiff(source: oldCode, destination: newCode)
let aiOutput = MultiLineDiff.displayDiff(
    diff: diff,
    source: oldCode,
    format: .ai
)
```

## 🔄 AI Workflow Integration

### AI Submitting Diffs

AI models can submit diffs using the same emoji format:

```swift
let aiSubmittedDiff = """
📎 func calculate() -> Int {
❌     return 42
✅     return 100
📎 }
"""

// Parse and apply AI's diff
let result = try MultiLineDiff.applyASCIIDiff(
    to: sourceCode,
    asciiDiff: aiSubmittedDiff
)
```

### Round-Trip Workflow

1. **Generate diff** → Display as ASCII
2. **Send to AI** → AI processes the diff
3. **AI responds** → With modified ASCII diff
4. **Parse AI diff** → Back to operations
5. **Apply to code** → Get final result

```swift
// Step 1: Generate and display
let originalDiff = MultiLineDiff.createAndDisplayDiff(
    source: source, destination: destination, format: .ai)

// Step 2: Send to AI (AI processes and modifies)
let aiModifiedDiff = sendToAI(originalDiff)

// Step 3: Apply AI's changes
let finalResult = try MultiLineDiff.applyASCIIDiff(
    to: source, asciiDiff: aiModifiedDiff)
```

## 📊 Diff Operation Counts Breakdown

### Simple Text Transformation Example

#### Original Text
```
"Hello, world!"
```

#### Modified Text
```
"Hello, Swift!"
```

#### Detailed Diff Analysis

```swift
// Diff Representation
let diffOperations = [
    .retain(7),   // "Hello, "
    .delete(5),   // "world"
    .insert("Swift"),  // "Swift"
    .retain(1)    // "!"
]

// Diff Counts Breakdown
struct DiffCounts {
    let retain: Int   // Unchanged characters
    let delete: Int   // Removed characters
    let insert: Int   // Added characters
}

let counts = DiffCounts(
    retain: 8,   // "Hello, " and "!"
    delete: 5,   // "world"
    insert: 5    // "Swift"
)

// Visualization
print("Diff Counts:")
print("📎 Retained: \(counts.retain) characters")
print("❌ Deleted:  \(counts.delete) characters")
print("✅ Inserted: \(counts.insert) characters")
```

#### ASCII Diff Output
```
📎 Hello, 
❌ world
✅ Swift
📎 !
```

## 🎯 Real-World Examples

### Example 1: Function Signature Change

**Before:**
```swift
func addUser(name: String, email: String) -> Bool
```

**After:**
```swift
func addUser(name: String, email: String, age: Int = 0) -> Result<User, UserError>
```

**ASCII Diff:**
```swift
❌ func addUser(name: String, email: String) -> Bool
✅ func addUser(name: String, email: String, age: Int = 0) -> Result<User, UserError>
```

### Example 2: Adding Properties

**Before:**
```swift
struct User {
    let name: String
    let email: String
}
```

**After:**
```swift
struct User {
    let id: UUID
    let name: String
    let email: String
    let age: Int
}
```

**ASCII Diff:**
```swift
📎 struct User {
✅     let id: UUID
📎     let name: String
📎     let email: String
✅     let age: Int
📎 }
```

### Example 3: Error Handling Improvement

**Before:**
```swift
guard !name.isEmpty && !email.isEmpty else {
    return false
}
```

**After:**
```swift
guard !name.isEmpty && !email.isEmpty else {
    return .failure(.invalidInput)
}
```

**ASCII Diff:**
```swift
📎 guard !name.isEmpty && !email.isEmpty else {
❌     return false
✅     return .failure(.invalidInput)
📎 }
```

## 🚀 Advanced Usage Patterns

### Batch Processing Multiple Files

```swift
let fileDiffs = files.map { file in
    MultiLineDiff.createAndDisplayDiff(
        source: file.original,
        destination: file.modified,
        format: .ai
    )
}

// Send all diffs to AI for review
let aiReviews = sendBatchToAI(fileDiffs)
```

### Interactive Code Review

```swift
// Generate terminal diff for human review
let humanDiff = MultiLineDiff.createAndDisplayDiff(
    source: oldCode, destination: newCode, format: .terminal)
print("👀 Human Review:")
print(humanDiff)

// Generate AI diff for automated analysis
let aiDiff = MultiLineDiff.createAndDisplayDiff(
    source: oldCode, destination: newCode, format: .ai)
let analysis = analyzeWithAI(aiDiff)
```

### Diff Validation and Testing

```swift
// Test round-trip accuracy
let originalDiff = MultiLineDiff.createDiff(source: source, destination: destination)
let asciiDiff = MultiLineDiff.displayDiff(diff: originalDiff, source: source, format: .ai)
let parsedDiff = try MultiLineDiff.parseDiffFromASCII(asciiDiff)
let result = try MultiLineDiff.applyDiff(to: source, diff: parsedDiff)

assert(result == destination, "Round-trip failed!")
```

## 🎨 Visual Comparison: Terminal vs AI Output

### Terminal Output (with ANSI colors)
```
📎 class UserManager {    // Blue paperclip
❌     func oldMethod()   // Red X with red background
✅     func newMethod()   // Green checkmark with green background
📎 }                     // Blue paperclip
```

### AI Output (plain ASCII)
```
📎 class UserManager {
❌     func oldMethod()
✅     func newMethod()
📎 }
```

Both formats use the same emoji symbols but terminal output includes ANSI color codes for enhanced visual presentation.

## 🔧 Configuration and Customization

### Algorithm Selection

```swift
// Different algorithms produce different diff granularity
let detailedDiff = MultiLineDiff.createAndDisplayDiff(
    source: source, destination: destination, 
    format: .ai, algorithm: .megatron  // More detailed
)

let simpleDiff = MultiLineDiff.createAndDisplayDiff(
    source: source, destination: destination,
    format: .ai, algorithm: .zoom      // Simpler, faster
)
```

### Metadata Inclusion

```swift
// Include metadata for debugging
let diffWithMetadata = MultiLineDiff.createDiff(
    source: source, destination: destination,
    includeMetadata: true
)

// Check algorithm used
print("Algorithm: \(diffWithMetadata.metadata?.algorithmUsed)")
```

## 🎯 Best Practices

### For AI Integration
1. **Use `.ai` format** for sending diffs to AI models
2. **Validate AI responses** before applying diffs
3. **Include context** when sending partial diffs
4. **Test round-trips** to ensure accuracy

### For Terminal Display
1. **Use `.terminal` format** for human review
2. **Combine with syntax highlighting** for better readability
3. **Limit diff size** for terminal display (use pagination)
4. **Provide legend** for new users

### For Production Use
1. **Cache diff results** for large files
2. **Use appropriate algorithms** based on content type
3. **Handle Unicode properly** in all contexts
4. **Monitor performance** with large diffs

## �� Summary

The MultiLineDiff ASCII system provides:

- **📎 Paperclip**: Intuitive symbol for retained/unchanged lines
- **❌ Red X**: Clear indication of lines to delete
- **✅ Green checkmark**: Obvious symbol for lines to add
- **🌈 Terminal support**: Beautiful colored output for humans
- **🤖 AI integration**: Clean ASCII format for AI models
- **🔄 Round-trip capability**: Parse AI diffs back to operations
- **⚡ High performance**: Optimized for large codebases

This creates a perfect bridge between human-readable diffs and AI-processable formats, making code review and automated refactoring seamless and intuitive. 