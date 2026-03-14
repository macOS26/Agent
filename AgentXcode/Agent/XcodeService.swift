import Foundation
import ScriptingBridge
import AgentScriptingBridge

/// Xcode automation via ScriptingBridge — build, run, and grant permission.
/// Follows the pattern from xcf's XcfSwiftScript and XcfOsaScript.
final class XcodeService: @unchecked Sendable {
    static let shared = XcodeService()
    private static let xcodeBundleID = "com.apple.dt.Xcode"

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

    /// Build a project via ScriptingBridge. Blocks until build completes.
    nonisolated func buildProject(projectPath: String) -> String {
        // SECURITY: Validate project path to prevent injection
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

        // Poll for completion
        while !(buildResult.completed ?? false) {
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Collect errors and warnings
        var output = ""
        if let errors = buildResult.buildErrors?() {
            for case let issue as XcodeBuildError in errors {
                let file = issue.filePath ?? "unknown"
                let line = issue.startingLineNumber ?? 0
                let msg = issue.message ?? "unknown error"
                output += "Error: \(file):\(line) \(msg)\n"
            }
        }
        if let warnings = buildResult.buildWarnings?() {
            for case let issue as XcodeBuildWarning in warnings {
                let file = issue.filePath ?? "unknown"
                let line = issue.startingLineNumber ?? 0
                let msg = issue.message ?? "unknown warning"
                output += "Warning: \(file):\(line) \(msg)\n"
            }
        }

        return output.isEmpty ? "Build succeeded" : output
    }

    /// Run a project via ScriptingBridge. Returns immediately after triggering run.
    nonisolated func runProject(projectPath: String) -> String {
        // SECURITY: Validate project path to prevent injection
        guard isValidProjectPath(projectPath) else {
            return "Error: Invalid project path. Must be a valid .xcodeproj or .xcworkspace path."
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

    /// List schemes for a project.
    nonisolated func listSchemes(projectPath: String) -> [String] {
        // SECURITY: Validate project path
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
    
    // MARK: - Security Helpers
    
    /// Validate a project path to prevent command injection
    private nonisolated func isValidProjectPath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed.hasSuffix(".xcodeproj") || trimmed.hasSuffix(".xcworkspace") else { return false }
        guard !trimmed.contains("..") else { return false }  // Path traversal prevention
        guard !trimmed.contains(";") && !trimmed.contains("|") && !trimmed.contains("&") else { return false }
        guard trimmed.count < 1024 else { return false }
        return true
    }
}
