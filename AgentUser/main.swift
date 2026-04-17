import Foundation

final class UserCommandHandler: NSObject, UserToolProtocol, @unchecked Sendable {
    weak var connection: NSXPCConnection?

    func execute(script: String, instanceID: String, withReply reply: @escaping (Int32, String) -> Void) {
        execute(script: script, instanceID: instanceID, workingDirectory: "", withReply: reply)
    }

    func execute(script: String, instanceID: String, workingDirectory: String, withReply reply: @escaping (Int32, String) -> Void) {
        let proxy = connection?.remoteObjectProxy as? UserProgressProtocol
        DaemonCore.execute(
            script: script,
            instanceID: instanceID,
            workingDirectory: workingDirectory,
            progressHandler: { proxy?.progressUpdate($0) },
            reply: reply
        )
    }

    func cancelOperation(instanceID: String, withReply reply: @escaping () -> Void) {
        DaemonCore.cancel(instanceID: instanceID)
        reply()
    }
}

final class UserDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // SECURITY: the user agent holds the console user's TCC grants
        // (Accessibility, Automation, Full Disk Access, etc.). Treat this as
        // sensitive as root — any peer must prove it is Agent.app.
        guard XPCPeerValidator.accept(connection) else {
            NSLog("AgentUser: rejected XPC connection — peer failed code-signing validation")
            return false
        }

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
XPCPeerValidator.install(on: listener)
listener.resume()
RunLoop.current.run()
