@preconcurrency import Foundation


// MARK: - Vision Verification
extension AgentViewModel {
    /// Capture a screenshot of the frontmost window and return base64-encoded PNG data.
    /// Used by the vision loop to auto-verify UI actions.
    nonisolated static func captureVerificationScreenshot() async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let tempPath = NSTemporaryDirectory() + "agent_vision_\(UUID().uuidString).png"
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                process.arguments = ["-x", "-t", "png", tempPath]
                do {
                    try process.run()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0,
                          let data = try? Data(contentsOf: URL(fileURLWithPath: tempPath)) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    // Resize to max 1024px wide to save tokens
                    let base64 = data.base64EncodedString()
                    try? FileManager.default.removeItem(atPath: tempPath)
                    continuation.resume(returning: base64)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - Shell Execution Tools
extension AgentViewModel {

    /// Execute a command via UserService XPC with streaming output.
    /// Used by TabTask and TaskExecution for Ollama restart commands.
    func executeViaUserAgent(command: String, workingDirectory: String = "", silent: Bool = false) async -> (status: Int32, output: String) {
        resetStreamCounters()
        userServiceActive = true
        userWasActive = true
        if !silent {
            userService.onOutput = { [weak self] chunk in
                self?.appendRawOutput(chunk)
            }
        }
        let result = await userService.execute(command: command, workingDirectory: workingDirectory)
        userService.onOutput = nil
        userServiceActive = false

        // Only show exit code on real errors (not cancellation, not success)
        if result.status > 0 {
            appendLog("exit code: \(result.status)")
        }
        flushLog()
        return result
    }

    /// Runs a command in the Agent app process to inherit TCC permissions
    /// (Automation, Accessibility, ScreenRecording).
    nonisolated static func executeTCC(command: String, workingDirectory: String = "") async -> (status: Int32, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: AppConstants.shellPath)
                process.arguments = ["-c", command]

                if !workingDirectory.isEmpty {
                    process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
                }

                var env = ProcessInfo.processInfo.environment
                env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
                let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "")
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
    nonisolated static func executeTCCStreaming(command: String, workingDirectory: String = "", onOutput: @escaping @Sendable (String) -> Void) async -> (status: Int32, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: AppConstants.shellPath)
                process.arguments = ["-c", command]

                if !workingDirectory.isEmpty {
                    process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
                }

                var env = ProcessInfo.processInfo.environment
                env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
                // Ensure common tool paths are in PATH
                let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "")
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