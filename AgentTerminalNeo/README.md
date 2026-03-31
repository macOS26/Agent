# AgentTerminalNeo

A Swift package that renders markdown as styled text with a retro green terminal aesthetic. Includes a drop-in SwiftUI view for displaying rendered output on macOS.

## Requirements

- macOS 26+
- Swift 6.2+
- No external dependencies (AppKit + SwiftUI only)

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../AgentTerminalNeo")
]
```

## Usage

### SwiftUI View

```swift
import AgentTerminalNeo

struct ContentView: View {
    var body: some View {
        TerminalNeoTextView(text: "# Hello\n\nThis is **bold** and *italic*.")
    }
}
```

With height tracking:

```swift
TerminalNeoTextView(text: markdownString, onContentHeight: { height in
    print("Content height: \(height)")
})
```

### Direct Rendering

```swift
import AgentTerminalNeo

let attributed = TerminalNeoRenderer.render("# Heading\n\nSome **bold** text.")
```

### Theme Colors

```swift
let textColor = TerminalNeoTheme.text      // Green terminal text
let dimColor = TerminalNeoTheme.dim        // Dimmed green
let brightColor = TerminalNeoTheme.bright  // Bright green for headers
```

## Markdown Support

| Feature | Syntax |
|---|---|
| Headers | `# H1` through `###### H6` |
| Bold | `**text**` |
| Italic | `*text*` |
| Bold + Italic | `***text***` |
| Inline code | `` `code` `` |
| Code blocks | ` ``` ` fenced blocks |
| Tables | Pipe-delimited markdown tables (rendered with NSTextTable) |
| Bullet lists | `- item` or `* item` |
| Numbered lists | `1. item` |
| Horizontal rules | `---` |

## Public API

### TerminalNeoTextView

SwiftUI `NSViewRepresentable` wrapper around NSTextView.

```swift
public struct TerminalNeoTextView: NSViewRepresentable {
    public init(text: String, onContentHeight: ((CGFloat) -> Void)? = nil)
}
```

- Non-editable, scrollable text display
- Automatic link detection
- Transparent background (inherits parent styling)

### TerminalNeoRenderer

Converts markdown strings to styled `NSAttributedString`.

| Method / Property | Description |
|---|---|
| `render(_:)` | Convert markdown to attributed string |
| `font` | 11pt monospaced system font |
| `boldFont` | 11pt bold monospaced system font |
| `isTableSeparator(_:)` | Check if a line is a table separator |
| `parseTableRow(_:)` | Extract cells from a table row |

### TerminalNeoTheme

Retro green terminal color palette. All colors adapt to system dark/light mode.

| Color | Dark Mode | Light Mode |
|---|---|---|
| `text` | Green on dark | Dark green on light |
| `bright` | Bright green | Bold dark green |
| `dim` | Muted green | Soft green |
| `border` | Dark green border | Light green border |
| `headerBg` | Dark green fill | Light green fill |
| `codeBg` | Near-black | Light gray-green |

## License

MIT
