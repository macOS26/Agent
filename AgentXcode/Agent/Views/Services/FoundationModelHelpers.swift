import Foundation

// MARK: - Shell Helpers for Foundation Models

/// Run a bash command string, returning combined stdout+stderr.
func nativeShellRun(_ cmd: String) -> String {
    let p = Process()
    let pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: AppConstants.shellPath)
    p.arguments = ["-c", cmd]
    p.standardOutput = pipe
    p.standardError = pipe
    try? p.run()
    p.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return out.isEmpty ? "(no output, exit \(p.terminationStatus))" : out
}

/// Run a specific executable with arguments, returning combined stdout+stderr.
func nativeShellRun(_ exe: String, args: [String]) -> String {
    let p = Process()
    let pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: exe)
    p.arguments = args
    p.standardOutput = pipe
    p.standardError = pipe
    try? p.run()
    p.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return out.isEmpty ? "(no output, exit \(p.terminationStatus))" : out
}

// MARK: - String Extensions for Foundation Models

extension String {
    /// Single-quote shell escape: wraps the string in single quotes, escaping any embedded single quotes.
    var shellEscaped: String { "'\(replacingOccurrences(of: "'", with: "'\\''"))'" }
    
    /// Returns self if non-empty, otherwise returns the given fallback.
    func orProjectFolder(_ fallback: String) -> String { isEmpty ? fallback : self }
    
    /// Replace Unicode smart/curly quotes and apostrophes with plain ASCII equivalents.
    /// Apple Intelligence often generates these in code strings, which break NSAppleScript / osascript / bash.
    var asciiQuotes: String {
        self
            .replacingOccurrences(of: "\u{201C}", with: "\"")  // " LEFT DOUBLE QUOTATION MARK
            .replacingOccurrences(of: "\u{201D}", with: "\"")  // " RIGHT DOUBLE QUOTATION MARK
            .replacingOccurrences(of: "\u{2018}", with: "'")   // ' LEFT SINGLE QUOTATION MARK
            .replacingOccurrences(of: "\u{2019}", with: "'")    // ' RIGHT SINGLE QUOTATION MARK
            .replacingOccurrences(of: "\u{2032}", with: "'")    // ′ PRIME (sometimes used as apostrophe)
    }
    
    /// Sanitize a string for use as AppleScript source.
    /// Fixes smart quotes AND removes backslash-escaping that the model adds (\" → ").
    /// AppleScript uses raw unquoted " for string literals — backslash escapes are invalid syntax.
    var appleScriptSanitized: String {
        asciiQuotes
            .replacingOccurrences(of: "\\\"", with: "\"")  // \" → "  (model over-escapes quotes)
            .replacingOccurrences(of: "\\'", with: "'")      // \' → '
    }
}