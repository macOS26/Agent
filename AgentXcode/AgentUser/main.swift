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
        let lock = UserCommandHandler.lock

        lock.lock()
        if let old = UserCommandHandler.runningProcesses[instanceID], old.isRunning {
            old.terminate()
            old.waitUntilExit()
        }
        UserCommandHandler.runningProcesses[instanceID] = nil
        lock.unlock()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]

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

let delegate = UserDelegate()
let listener = NSXPCListener(machServiceName: "Agent.app.toddbruss.user")
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
