# AgentColorSyntax

A Swift package for syntax highlighting code blocks, terminal output, diffs, and activity logs on macOS. Theme-aware with automatic dark/light mode support.

## Requirements

- macOS 26+
- Swift 6.2+
- No external dependencies (AppKit only)

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../AgentColorSyntax")
]
```

## Usage

```swift
import AgentColorSyntax

// Highlight a code block
let highlighted = CodeBlockHighlighter.highlight(
    code: "let x = 42",
    language: "swift",
    font: .monospacedSystemFont(ofSize: 12, weight: .regular)
)

// Auto-detect language
let lang = CodeBlockHighlighter.guessLanguage(from: code)

// Highlight activity log output (diffs, shell output, git stats)
if CodeBlockHighlighter.looksLikeActivityLogLine(line) {
    let styled = CodeBlockHighlighter.highlightActivityLogLine(line: line, font: font)
}
```

## Supported Languages

Swift, Python, JavaScript, TypeScript, C, C++, Go, Rust, Ruby, Java, Kotlin, Objective-C, JSON, YAML, SQL, HTML, XML, CSS, Bash/Shell.

Language aliases are supported (e.g., "js" resolves to "javascript").

## Specialized Output Highlighting

Beyond standard code, the package highlights:

- **Terminal output** -- `ls -la` listings with colored permissions, directories, sizes, and dates
- **Diffs** -- Added lines (green), removed lines (red), line numbers (dim)
- **Git output** -- Files changed (yellow), insertions (green), deletions (red), commit refs (cyan)
- **Hex dumps** -- Address (dim), hex bytes (yellow), ASCII (cyan)
- **Activity logs** -- Timestamps, section headers, labels, file paths, shell commands, flags, errors

## Public API

### CodeBlockHighlighter

| Method | Description |
|---|---|
| `highlight(code:language:font:)` | Syntax highlight a code string |
| `highlightActivityLogLine(line:font:)` | Highlight a single activity log line |
| `looksLikeActivityLogLine(_:)` | Detect if a line is terminal/log output |
| `guessLanguage(from:)` | Auto-detect language from code content |
| `langDef(for:)` | Get language definition by name or alias |

### CodeBlockTheme

Theme-aware colors for keywords, strings, numbers, comments, types, function calls, paths, and more. Automatically adapts to system dark/light mode.

### LangDef

Language definition struct with keywords, declaration keywords, types, self keywords, system functions, comment delimiters, and string patterns.

## License

MIT
