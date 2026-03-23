import Foundation
import ScriptingBridge
import XcodeScriptingBridge

/// Xcode automation via ScriptingBridge — build, run, list/select projects, grant permission.
/// Modeled after xcf's best patterns: file:line:col error format, code snippets, build-before-run.
final class XcodeService: @unchecked Sendable {
    static let shared = XcodeService()
    private static let xcodeBundleID = "com.apple.dt.Xcode"

    // MARK: - Grant Permission

    /// Grant Automation permission by running a trivial AppleScript via osascript.
    /// This triggers the macOS permission dialog so ScriptingBridge can control Xcode.
    nonisolated func grantPermission() -> String {
        let script = """
        tell application "Xcode"
            set xcDoc to first document
            tell xcDoc
                set buildResult to build
                repeat
                    if completed of buildResult is true then
                        exit repeat
                    end if
                    delay 0.5
                end repeat
                return "Xcode Automation permission has been granted"
            end tell
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                return "Grant failed: \(errStr)"
            }

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "Permission granted"
        } catch {
            return "Grant failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Build

    /// Build a project via ScriptingBridge. Blocks until build completes.
    /// Returns errors/warnings in file:line:col [Error] message format with code snippets.
    nonisolated func buildProject(projectPath: String) -> String {
        guard isValidProjectPath(projectPath) else {
            return "Error: Invalid project path. Must be a valid .xcodeproj or .xcworkspace path."
        }

        guard let xcode: XcodeApplication = SBApplication(bundleIdentifier: Self.xcodeBundleID) else {
            return "Error: Failed to connect to Xcode"
        }

        guard let workspace = xcode.open?(projectPath as Any) as? XcodeWorkspaceDocument else {
            return "Error: Could not open workspace at \(projectPath)"
        }

        guard let buildResult = workspace.build?() else {
            return "Error: Failed to start build"
        }

        // Poll for completion with 10-minute timeout
        let deadline = Date().addingTimeInterval(600)
        while !(buildResult.completed ?? false) {
            if Date() > deadline {
                return "Error: Build timed out after 10 minutes"
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Collect all issue types (matching xcf's pattern)
        var output = ""

        if let errors = buildResult.buildErrors?() {
            collectIssues(errors, type: "Error", into: &output)
        }
        if let warnings = buildResult.buildWarnings?() {
            collectIssues(warnings, type: "Warning", into: &output)
        }
        if let analyzerIssues = buildResult.analyzerIssues?() {
            collectIssues(analyzerIssues, type: "Analyzer", into: &output)
        }
        if let testFailures = buildResult.testFailures?() {
            collectIssues(testFailures, type: "TestFailure", into: &output)
        }

        return output.isEmpty ? "Build succeeded" : output
    }

    // MARK: - Run

    /// Run a project via ScriptingBridge. Builds first — only runs if build is clean.
    nonisolated func runProject(projectPath: String) -> String {
        // Build first to check for errors (matching xcf's pattern)
        let buildOutput = buildProject(projectPath: projectPath)
        guard buildOutput == "Build succeeded" else {
            return buildOutput
        }

        guard let xcode: XcodeApplication = SBApplication(bundleIdentifier: Self.xcodeBundleID) else {
            return "Error: Failed to connect to Xcode"
        }

        guard let workspace = xcode.open?(projectPath as Any) as? XcodeWorkspaceDocument else {
            return "Error: Could not open workspace at \(projectPath)"
        }

        workspace.stop?()
        Thread.sleep(forTimeInterval: 1)
        _ = workspace.runWithCommandLineArguments?(nil, withEnvironmentVariables: nil)

        return "Run started for \(projectPath)"
    }

    // MARK: - List Projects

    /// List all open Xcode projects and workspaces.
    nonisolated func listProjects() -> String {
        guard let xcode: XcodeApplication = SBApplication(bundleIdentifier: Self.xcodeBundleID) else {
            return "Error: Failed to connect to Xcode"
        }

        guard let documents = xcode.documents?() else {
            return "No open projects"
        }

        var projects: Set<String> = []

        for case let document as XcodeDocument in documents {
            guard let name = document.name, let path = document.path else { continue }
            if name.contains(".xcodeproj") || name.contains(".xcworkspace") {
                projects.insert(path)
            }
        }

        if projects.isEmpty {
            return "No open Xcode projects or workspaces"
        }

        let sorted = projects.sorted()
        var result = ""
        for (i, path) in sorted.enumerated() {
            result += "\(i + 1). \(path)\n"
        }
        return result
    }

    /// Select a project by number from the open projects list.
    nonisolated func selectProject(number: Int) -> String {
        guard let xcode: XcodeApplication = SBApplication(bundleIdentifier: Self.xcodeBundleID) else {
            return "Error: Failed to connect to Xcode"
        }

        guard let documents = xcode.documents?() else {
            return "Error: No open documents"
        }

        var projects: Set<String> = []

        for case let document as XcodeDocument in documents {
            guard let name = document.name, let path = document.path else { continue }
            if name.contains(".xcodeproj") || name.contains(".xcworkspace") {
                projects.insert(path)
            }
        }

        let sorted = projects.sorted()
        guard (1...sorted.count).contains(number) else {
            return "Error: Project number \(number) out of range (1-\(sorted.count))"
        }

        let selected = sorted[number - 1]

        // Security: must be in user's home directory
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard selected.hasPrefix(home) else {
            return "Error: Project must be within your home directory"
        }

        return selected
    }

    // MARK: - Schemes

    /// List schemes for a project.
    nonisolated func listSchemes(projectPath: String) -> [String] {
        guard isValidProjectPath(projectPath) else { return [] }

        guard let xcode: XcodeApplication = SBApplication(bundleIdentifier: Self.xcodeBundleID) else {
            return []
        }

        guard let workspace = xcode.open?(projectPath as Any) as? XcodeWorkspaceDocument,
              let schemes = workspace.schemes?() else {
            return []
        }

        var names: [String] = []
        for case let scheme as XcodeScheme in schemes {
            if let name = scheme.name {
                names.append(name)
            }
        }
        return names
    }

    // MARK: - Issue Collection (xcf pattern)

    /// Collect issues from an SBElementArray into a formatted string.
    /// Format: file:line:col [Type] message\n```swift\n<snippet>\n```
    private nonisolated func collectIssues(_ issues: SBElementArray, type: String, into output: inout String) {
        for case let issue as XcodeBuildError in issues {
            guard let message = issue.message else { continue }

            if let filePath = issue.filePath,
               let startLine = issue.startingLineNumber,
               let col = issue.startingColumnNumber {
                let endLine = issue.endingLineNumber ?? startLine
                output += "\(filePath):\(startLine):\(col) [\(type)] \(message)\n"

                // Include code snippet for context (matching xcf)
                let snippet = codeSnippet(filePath: filePath, startLine: startLine, endLine: endLine)
                if !snippet.isEmpty {
                    output += "```swift\n\(snippet)\n```\n"
                }
            } else {
                output += "[\(type)] \(message)\n"
            }
        }
    }

    /// Extract a code snippet from a file around the error location.
    private nonisolated func codeSnippet(filePath: String, startLine: Int, endLine: Int) -> String {
        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else {
            return ""
        }

        let lines = content.components(separatedBy: "\n")
        let start = max(startLine - 1, 0)
        let end = min(endLine, lines.count)
        guard start < end else { return "" }

        return lines[start..<end].enumerated().map { (i, line) in
            let num = start + i + 1
            return "\(num)\t\(line)"
        }.joined(separator: "\n")
    }

    // MARK: - Security

    /// Validate a project path to prevent command injection.
    private nonisolated func isValidProjectPath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed.hasSuffix(".xcodeproj") || trimmed.hasSuffix(".xcworkspace") else { return false }
        guard !trimmed.contains("..") else { return false }
        guard !trimmed.contains(";") && !trimmed.contains("|") && !trimmed.contains("&") else { return false }
        guard trimmed.count < 1024 else { return false }
        return true
    }
}
