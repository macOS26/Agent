import Foundation

/// Shared output context for streaming command output via XPC.
final class OutputContext: @unchecked Sendable {
    var output = ""
    let outputLock = NSLock()
    let progressHandler: ((String) -> Void)?

    init(progressHandler: ((String) -> Void)?) {
        self.progressHandler = progressHandler
    }
}

/// Shared command execution logic for both AgentHelper (root) and AgentUser (user) daemons.
/// The only differences are the XPC protocol types and Mach service name.
enum DaemonCore {
    nonisolated(unsafe) static var runningProcesses: [String: Process] = [:]
    static let lock = NSLock()

    static func execute(
        script: String,
        instanceID: String,
        workingDirectory: String,
        progressHandler: ((String) -> Void)?,
        reply: @escaping (Int32, String) -> Void
    ) {
        // Defense in depth: refuse a small set of catastrophic shell patterns
        // right here in the daemon, even when the app-side `ShellSafetyService`
        // has already approved. If a peer ever bypassed the listener
        // validator (for example via a future bug), this is the last wall
        // before `/bin/zsh -c` runs the payload as root.
        if let reason = DaemonShellGuard.refuse(script) {
            reply(-1, "Refused by daemon guard: \(reason)")
            return
        }

        lock.lock()
        if let old = runningProcesses[instanceID], old.isRunning {
            old.terminate()
            old.waitUntilExit()
        }
        runningProcesses[instanceID] = nil
        lock.unlock()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", script]

        if !workingDirectory.isEmpty {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        var env = ProcessInfo.processInfo.environment
        env["CLICOLOR_FORCE"] = "1"
        env["TERM"] = env["TERM"] ?? "xterm-256color"
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "")
        if !workingDirectory.isEmpty {
            env["PWD"] = workingDirectory
        }
          // Defense-in-depth: set AGENT_PROJECT_FOLDER on process.environment too.
        env["AGENT_PROJECT_FOLDER"] = workingDirectory.isEmpty
            ? FileManager.default.homeDirectoryForCurrentUser.path
            : workingDirectory
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        lock.lock()
        runningProcesses[instanceID] = process
        lock.unlock()

        let ctx = OutputContext(progressHandler: progressHandler)

        pipe.fileHandleForReading.readabilityHandler = { [ctx] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            ctx.outputLock.lock()
            ctx.output += chunk
            ctx.outputLock.unlock()
            ctx.progressHandler?(chunk)
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            reply(-1, error.localizedDescription)
            return
        }

        pipe.fileHandleForReading.readabilityHandler = nil

        let remainingData = pipe.fileHandleForReading.readDataToEndOfFile()
        if !remainingData.isEmpty, let chunk = String(data: remainingData, encoding: .utf8) {
            ctx.outputLock.lock()
            ctx.output += chunk
            ctx.outputLock.unlock()
            ctx.progressHandler?(chunk)
        }

        ctx.outputLock.lock()
        let output = ctx.output
        ctx.outputLock.unlock()

        reply(process.terminationStatus, output)

        lock.lock()
        runningProcesses.removeValue(forKey: instanceID)
        lock.unlock()
    }

    static func cancel(instanceID: String) {
        lock.lock()
        if let process = runningProcesses[instanceID], process.isRunning {
            process.terminate()
        }
        runningProcesses.removeValue(forKey: instanceID)
        lock.unlock()
    }
}

/// Small, conservative, last-mile safety check compiled into every daemon.
/// This duplicates the most dangerous-rule subset of the app's
/// `ShellSafetyService` so the daemon refuses catastrophic commands even if
/// the app wrapper is ever bypassed.
enum DaemonShellGuard {

    /// Returns a refusal reason when the command must not execute, nil when
    /// it's OK to proceed.
    static func refuse(_ command: String) -> String? {
        let normalized = command.replacingOccurrences(of: " ", with: "")
        if normalized.contains(":(){:|:&};:") {
            return "fork bomb pattern"
        }

        for segment in splitSegments(command) {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if let reason = refuseSegment(trimmed) { return reason }
        }
        return nil
    }

    private static func refuseSegment(_ segment: String) -> String? {
        let stripped = stripWrappers(segment)
        let tokens = tokenize(stripped)
        guard !tokens.isEmpty else { return nil }

        // rm -rf <dangerous>
        if tokens.contains("rm") {
            var recursive = false
            var force = false
            var positionals: [String] = []
            for t in tokens.dropFirst() where !t.isEmpty {
                if t == "--no-preserve-root" {
                    return "rm --no-preserve-root is never legitimate"
                }
                if t.hasPrefix("--recursive") { recursive = true; continue }
                if t.hasPrefix("--force") { force = true; continue }
                if t.hasPrefix("--") { continue }
                if t.hasPrefix("-") {
                    let chars = t.dropFirst()
                    if chars.contains("r") || chars.contains("R") { recursive = true }
                    if chars.contains("f") || chars.contains("F") { force = true }
                    continue
                }
                positionals.append(t)
            }
            if recursive && force {
                for target in positionals {
                    if isCatastrophicTarget(target) {
                        return "rm -rf on a system root or home-equivalent path (\(target))"
                    }
                }
            }
        }

        // dd of=/dev/disk*
        if tokens.contains("dd") {
            for t in tokens where t.hasPrefix("of=/dev/") {
                let dest = String(t.dropFirst(3))
                if isRawDisk(dest) {
                    return "dd writing to raw disk device \(dest)"
                }
            }
        }

        // mkfs*
        if let first = tokens.first, first.hasPrefix("mkfs") {
            return "\(first) formats a filesystem"
        }

        // diskutil erase*
        if tokens.first == "diskutil" && tokens.count >= 2 {
            let verb = tokens[1].lowercased()
            if verb == "erasedisk" || verb == "zerodisk" || verb == "secureerase" || verb == "erasevolume" {
                return "diskutil \(tokens[1]) erases a disk/volume"
            }
        }

        // Redirect to raw disk device
        let redirectPattern = #">+\s*/dev/(?:r?disk[0-9]|sd[a-z]|hd[a-z]|nvme[0-9])"#
        if stripped.range(of: redirectPattern, options: .regularExpression) != nil {
            return "output redirected to a raw disk device"
        }

        return nil
    }

    private static func isCatastrophicTarget(_ raw: String) -> Bool {
        var t = raw
        if (t.hasPrefix("\"") && t.hasSuffix("\"")) || (t.hasPrefix("'") && t.hasSuffix("'")) {
            t = String(t.dropFirst().dropLast())
        }
        if t == "/" || t == "/*" || t == "/." || t == "/.." || t == "/.*" { return true }
        if t == "*" || t == "." || t == ".." || t == "./" || t == "./*" || t == ".*" { return true }
        let roots: Set<String> = [
            "/etc", "/usr", "/bin", "/sbin", "/var", "/lib", "/lib64",
            "/boot", "/proc", "/sys", "/dev", "/run", "/opt",
            "/System", "/Library", "/Applications", "/private",
            "/Volumes", "/Network", "/cores", "/Users", "/home",
        ]
        for r in roots {
            if t == r || t == r + "/" || t == r + "/*" || t == r + "/.*" { return true }
        }
        let homeForms: Set<String> = [
            "~", "~/", "~/*", "~/.*",
            "$HOME", "${HOME}", "$HOME/", "${HOME}/",
            "$HOME/*", "${HOME}/*", "$HOME/.*", "${HOME}/.*",
        ]
        if homeForms.contains(t) { return true }
        let realHome = NSHomeDirectory()
        if t == realHome || t == realHome + "/" || t == realHome + "/*" { return true }
        return false
    }

    private static func isRawDisk(_ path: String) -> Bool {
        let lower = path.lowercased()
        return lower.hasPrefix("/dev/disk")
            || lower.hasPrefix("/dev/rdisk")
            || lower.hasPrefix("/dev/sd")
            || lower.hasPrefix("/dev/hd")
            || lower.hasPrefix("/dev/nvme")
    }

    private static func stripWrappers(_ command: String) -> String {
        var result = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["sudo ", "exec ", "command ", "builtin ", "eval ", "doas "]
        var changed = true
        while changed {
            changed = false
            for prefix in prefixes where result.lowercased().hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                changed = true
            }
            if let space = result.firstIndex(of: " "),
               result[..<space].contains("="),
               !result[..<space].contains("/") {
                result = String(result[result.index(after: space)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                changed = true
            }
        }
        return result
    }

    private static func tokenize(_ command: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escape = false
        for ch in command {
            if escape { current.append(ch); escape = false; continue }
            if ch == "\\" { current.append(ch); escape = true; continue }
            if ch == "'" && !inDouble { inSingle.toggle(); current.append(ch); continue }
            if ch == "\"" && !inSingle { inDouble.toggle(); current.append(ch); continue }
            if (ch == " " || ch == "\t") && !inSingle && !inDouble {
                if !current.isEmpty { tokens.append(current); current = "" }
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func splitSegments(_ command: String) -> [String] {
        var segments: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var i = command.startIndex
        while i < command.endIndex {
            let ch = command[i]
            if ch == "'" && !inDouble { inSingle.toggle(); current.append(ch); i = command.index(after: i); continue }
            if ch == "\"" && !inSingle { inDouble.toggle(); current.append(ch); i = command.index(after: i); continue }
            if !inSingle && !inDouble {
                let next = command.index(after: i)
                if next < command.endIndex {
                    let two = String(command[i...next])
                    if two == "&&" || two == "||" {
                        if !current.isEmpty { segments.append(current); current = "" }
                        i = command.index(after: next)
                        continue
                    }
                }
                if ch == ";" || ch == "|" || ch == "\n" {
                    if !current.isEmpty { segments.append(current); current = "" }
                    i = command.index(after: i)
                    continue
                }
            }
            current.append(ch)
            i = command.index(after: i)
        }
        if !current.isEmpty { segments.append(current) }
        return segments
    }
}
