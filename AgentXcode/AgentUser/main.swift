import Foundation

private final class OutputContext: @unchecked Sendable {
    var output = ""
    let outputLock = NSLock()
    let proxy: UserProgressProtocol?

    init(proxy: UserProgressProtocol?) {
        self.proxy = proxy
    }
}

final class UserCommandHandler: NSObject, UserToolProtocol, @unchecked Sendable {
    nonisolated(unsafe) private static var runningProcesses: [String: Process] = [:]
    private static let lock = NSLock()
    weak var connection: NSXPCConnection?

    func execute(script: String, instanceID: String, withReply reply: @escaping (Int32, String) -> Void) {
        execute(script: script, instanceID: instanceID, workingDirectory: "", withReply: reply)
    }

    func execute(script: String, instanceID: String, workingDirectory: String, withReply reply: @escaping (Int32, String) -> Void) {
        let lock = UserCommandHandler.lock

        lock.lock()
        if let old = UserCommandHandler.runningProcesses[instanceID], old.isRunning {
            old.terminate()
            old.waitUntilExit()
        }
        UserCommandHandler.runningProcesses[instanceID] = nil
        lock.unlock()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", script]

        // Set working directory on the process — shell starts in this dir
        if !workingDirectory.isEmpty {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        // Force color output, set PWD to match working directory
        var env = ProcessInfo.processInfo.environment
        env["CLICOLOR_FORCE"] = "1"
        env["TERM"] = env["TERM"] ?? "xterm-256color"
        if !workingDirectory.isEmpty {
            env["PWD"] = workingDirectory
        }
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        lock.lock()
        UserCommandHandler.runningProcesses[instanceID] = process
        lock.unlock()

        let ctx = OutputContext(proxy: connection?.remoteObjectProxy as? UserProgressProtocol)

        pipe.fileHandleForReading.readabilityHandler = { [ctx] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            ctx.outputLock.lock()
            ctx.output += chunk
            ctx.outputLock.unlock()
            ctx.proxy?.progressUpdate(chunk)
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            reply(-1, error.localizedDescription)
            return
        }

        pipe.fileHandleForReading.readabilityHandler = nil

        // Read any remaining data in the pipe
        let remainingData = pipe.fileHandleForReading.readDataToEndOfFile()
        if !remainingData.isEmpty, let chunk = String(data: remainingData, encoding: .utf8) {
            ctx.outputLock.lock()
            ctx.output += chunk
            ctx.outputLock.unlock()
            ctx.proxy?.progressUpdate(chunk)
        }

        ctx.outputLock.lock()
        let output = ctx.output
        ctx.outputLock.unlock()

        reply(process.terminationStatus, output)

        lock.lock()
        UserCommandHandler.runningProcesses.removeValue(forKey: instanceID)
        lock.unlock()
    }

    func cancelOperation(instanceID: String, withReply reply: @escaping () -> Void) {
        let lock = UserCommandHandler.lock
        lock.lock()
        if let process = UserCommandHandler.runningProcesses[instanceID], process.isRunning {
            process.terminate()
        }
        UserCommandHandler.runningProcesses.removeValue(forKey: instanceID)
        lock.unlock()
        reply()
    }
}

final class UserDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let handler = UserCommandHandler()
        handler.connection = connection
        connection.exportedInterface = NSXPCInterface(with: UserToolProtocol.self)
        connection.remoteObjectInterface = NSXPCInterface(with: UserProgressProtocol.self)
        connection.exportedObject = handler
        connection.resume()
        return true
    }
}

// MARK: - Package.swift auto-sync

/// Replace the contents of a named array in Package.swift with the given set of names.
/// Returns the updated content, or the original if unchanged.
func syncArray(named marker: String, with diskNames: Set<String>, in content: String) -> String {
    guard let arrayStart = content.range(of: marker) else { return content }
    guard let arrayEnd = content[arrayStart.upperBound...].range(of: "]") else { return content }

    let arrayContent = content[arrayStart.upperBound..<arrayEnd.lowerBound]
    let registered = Set(arrayContent.components(separatedBy: "\n")
        .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\",")) }
        .filter { !$0.isEmpty })

    guard diskNames != registered else { return content }

    let sorted = diskNames.sorted()
    let newArray = sorted.map { "    \"\($0)\"," }.joined(separator: "\n")
    return String(content[..<arrayStart.upperBound]) + "\n" + newArray + "\n" + String(content[arrayEnd.lowerBound...])
}

/// Sync scriptNames in Package.swift with actual .swift files on disk.
/// Bridge names come from AppleEventBridges package (single source of truth).
func syncPackage() {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser
    let agentsDir = home.appendingPathComponent("Documents/AgentScript/agents")
    let scriptsDir = agentsDir.appendingPathComponent("Sources/Scripts")
    let packageURL = agentsDir.appendingPathComponent("Package.swift")

    guard fm.fileExists(atPath: packageURL.path) else { return }
    guard var content = try? String(contentsOf: packageURL, encoding: .utf8) else { return }

    let original = content

    // Sync scripts
    if fm.fileExists(atPath: scriptsDir.path),
       let files = try? fm.contentsOfDirectory(atPath: scriptsDir.path) {
        let diskScripts = Set(files.filter { $0.hasSuffix(".swift") }
            .map { $0.replacingOccurrences(of: ".swift", with: "") })
        content = syncArray(named: "let scriptNames = [", with: diskScripts, in: content)
    }

    // Only write if something changed
    guard content != original else { return }
    try? content.write(to: packageURL, atomically: true, encoding: .utf8)
}

// Run sync on startup
syncPackage()

// Schedule sync every 20 seconds
let syncTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
syncTimer.schedule(deadline: .now() + 20, repeating: 20)
syncTimer.setEventHandler { syncPackage() }
syncTimer.resume()

let delegate = UserDelegate()
let listener = NSXPCListener(machServiceName: "Agent.app.toddbruss.user")
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
