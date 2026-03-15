// Test file for backticks and fenced code blocks

// Example of inline backticks: `print("Hello, world!")`

/*
Example of a fenced code block:
```swift
struct Test {
    var value: String
    
    func printValue() {
        print(value)
    }
}
```
*/

// Another example of inline backticks: `let x = 42`

// Example of a shell command in a fenced block:
```bash
ls -la
```

// Example of a numbered output (should not trigger copy button):
1 | let y = 10
2 | print(y)

// Example of a fenced code block with no language:
```
This is a test.
```