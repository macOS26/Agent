import FoundationModels
import Foundation

// MARK: - Shared State for Native Tools

/// Shared state for native Foundation Models tools.
enum NativeToolContext {
    @MainActor static var projectFolder: String = ""
    /// Set when task_complete is called via native tool — the task loop checks this after each iteration.
    @MainActor static var taskCompleteSummary: String?
    /// Last tool output — so task_complete can include it if the model just says "Done".
    @MainActor static var lastToolOutput: String = ""
    /// Counts tool calls per session turn to prevent infinite loops.
    @MainActor static var toolCallCount = 0
    /// Max tool calls before forcing task_complete.
    static let maxToolCalls = 5
    /// Handler that routes tool calls to real execution (set by ViewModel before task starts).
    nonisolated(unsafe) static var toolHandler: (@Sendable (String, sending [String: Any]) async -> String)?
}

// MARK: - @Generable Argument Structs

/// Arguments the model generates when calling execute_agent_command.
@Generable
struct ShellCommandArgs {
    @Guide(description: "Shell command")
    var command: String
}

@Generable
struct AppleScriptArgs {
    @Guide(description: "AppleScript code")
    var source: String
}

@Generable
struct OsaScriptArgs {
    @Guide(description: "AppleScript code")
    var script: String
}

@Generable
struct ReadFileArgs {
    @Guide(description: "File path")
    var file_path: String
    @Guide(description: "Start line")
    var offset: Int?
    @Guide(description: "Max lines")
    var limit: Int?
}

@Generable
struct WriteFileArgs {
    @Guide(description: "File path")
    var file_path: String
    @Guide(description: "File content")
    var content: String
}

@Generable
struct EditFileArgs {
    @Guide(description: "File path")
    var file_path: String
    @Guide(description: "Text to find")
    var old_string: String
    @Guide(description: "Replacement")
    var new_string: String
    @Guide(description: "Replace all")
    var replace_all: Bool?
}

@Generable
struct GlobArgs {
    @Guide(description: "Glob pattern")
    var pattern: String
    @Guide(description: "Directory")
    var path: String?
}

@Generable
struct SearchArgs {
    @Guide(description: "Regex pattern")
    var pattern: String
    @Guide(description: "Directory")
    var path: String?
    @Guide(description: "File filter")
    var include: String?
}

@Generable
struct TaskCompleteArgs {
    @Guide(description: "Summary")
    var summary: String
}

@Generable
struct GitRepoArgs {
    @Guide(description: "Repo path")
    var path: String?
}

@Generable
struct GitCommitArgs {
    @Guide(description: "Repo path")
    var path: String?
    @Guide(description: "Message")
    var message: String
}

@Generable
struct GitLogArgs {
    @Guide(description: "Repo path")
    var path: String?
    @Guide(description: "Count")
    var count: Int?
}

@Generable
struct GitDiffArgs {
    @Guide(description: "Repo path")
    var path: String?
    @Guide(description: "Staged only")
    var staged: Bool?
    @Guide(description: "Target branch")
    var target: String?
}

@Generable
struct JXAArgs {
    @Guide(description: "JavaScript for Automation source code")
    var source: String
}

@Generable
struct NoArgs: Generable {
    init() {}
}

@Generable
struct AppleScriptNameArgs {
    @Guide(description: "Script name")
    var name: String
}

@Generable
struct SaveAppleScriptArgs {
    @Guide(description: "Script name")
    var name: String
    @Guide(description: "AppleScript source")
    var source: String
}

// MARK: - Shell Helpers

/// Run a bash command string, returning combined stdout+stderr.
func nativeShellRun(_ cmd: String) -> String {
    let p = Process()
    let pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: "/bin/bash")
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

// MARK: - String Extensions

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
            .replacingOccurrences(of: "\u{2019}", with: "'")   // ' RIGHT SINGLE QUOTATION MARK
            .replacingOccurrences(of: "\u{2032}", with: "'")   // ′ PRIME (sometimes used as apostrophe)
    }

    /// Sanitize a string for use as AppleScript source.
    /// Fixes smart quotes AND removes backslash-escaping that the model adds (\" → ").
    /// AppleScript uses raw unquoted " for string literals — backslash escapes are invalid syntax.
    var appleScriptSanitized: String {
        asciiQuotes
            .replacingOccurrences(of: "\\\"", with: "\"")  // \" → "  (model over-escapes quotes)
            .replacingOccurrences(of: "\\'", with: "'")     // \' → '
    }
}