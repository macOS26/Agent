@preconcurrency import Foundation
import os.log

private let shellLog = Logger(subsystem: AppConstants.subsystem, category: "ShellTools")

// MARK: - Shell Execution Tools
extension AgentViewModel {

    /// Execute a command via UserService XPC with streaming output.
    /// Used by TabTask and TaskExecution for Ollama restart commands.
    func executeViaUserAgent(command: String) async -> (status: Int32, output: String) {
        resetStreamCounters()
        userServiceActive = true
        userWasActive = true
        userService.onOutput = { [weak self] chunk in
            self?.appendRawOutput(chunk)
        }
        let result = await userService.execute(command: command)
        userService.onOutput = nil
        userServiceActive = false

        // Only show exit code on failure; streaming already displayed the output
        if result.status != 0 {
            appendLog("exit code: \(result.status)")
        }
        flushLog()
        return result
    }

    /// Runs a command in the Agent app process to inherit TCC permissions
    /// (Automation, Accessibility, ScreenRecording).
    nonisolated static func executeTCC(command: String) async -> (status: Int32, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: AppConstants.shellPath)
                process.arguments = ["-c", command]

                var env = ProcessInfo.processInfo.environment
                env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
                process.environment = env

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: (-1, "Failed to launch: \(error.localizedDescription)"))
                    return
                }

                // Read pipes then wait — osascript output is small, no deadlock risk
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                var output = String(data: stdoutData, encoding: .utf8) ?? ""
                let errStr = String(data: stderrData, encoding: .utf8) ?? ""
                if !errStr.isEmpty {
                    if !output.isEmpty { output += "\n" }
                    output += errStr
                }

                continuation.resume(returning: (process.terminationStatus, output))
            }
        }
    }

    /// Run a command in the Agent app process with streaming output.
    /// Inherits TCC permissions (Automation, Accessibility, ScreenRecording).
    nonisolated static func executeTCCStreaming(command: String, onOutput: @escaping @Sendable (String) -> Void) async -> (status: Int32, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: AppConstants.shellPath)
                process.arguments = ["-c", command]

                var env = ProcessInfo.processInfo.environment
                env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
                process.environment = env

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                } catch {
                    let msg = "Failed to launch: \(error.localizedDescription)"
                    onOutput(msg)
                    continuation.resume(returning: (-1, msg))
                    return
                }

                // Stream output chunks as they arrive
                var collected = ""
                let handle = pipe.fileHandleForReading
                while true {
                    let data = handle.availableData
                    if data.isEmpty { break }
                    if let chunk = String(data: data, encoding: .utf8) {
                        collected += chunk
                        onOutput(chunk)
                    }
                }
                process.waitUntilExit()

                continuation.resume(returning: (process.terminationStatus, collected))
            }
        }
    }

    /// Returns true if the command contains osascript and needs TCC.
    nonisolated static func isOsascriptCommand(_ command: String) -> Bool {
        command.contains("osascript") || command.contains("/usr/bin/osascript")
    }

    /// Returns true if the command needs TCC permissions (run in Agent process).
    /// TCC commands: automation, agentscript, applescript, osascript, appleevent, accessibility
    nonisolated static func needsTCCPermissions(_ command: String) -> Bool {
        let lower = command.lowercased()
        // TCC-requiring commands must run in Agent process to inherit permissions
        return lower.contains("osascript")
            || lower.contains("applescript")
            || lower.contains("screencapture")
            || lower.contains("accessibility")
            || lower.contains("automation")
            || lower.contains("agentscript")
            || lower.contains("appleevent")
            || lower.contains("tccutil")
            || lower.contains("automator")
            || lower.contains("/Library/Application Support/com.apple.TCC")
    }

}