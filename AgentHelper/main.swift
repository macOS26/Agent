import Foundation

final class HelperCommandHandler: NSObject, HelperToolProtocol, @unchecked Sendable {
    weak var connection: NSXPCConnection?

    func execute(script: String, instanceID: String, withReply reply: @escaping (Int32, String) -> Void) {
        execute(script: script, instanceID: instanceID, workingDirectory: "", withReply: reply)
    }

    func execute(script: String, instanceID: String, workingDirectory: String, withReply reply: @escaping (Int32, String) -> Void) {
        let proxy = connection?.remoteObjectProxy as? HelperProgressProtocol
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

final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // SECURITY: the helper runs as root. Any process that can reach the
        // Mach service must prove it is the Agent.app we shipped alongside
        // this daemon — otherwise every local binary on the machine has a
        // path to root shell.
        guard XPCPeerValidator.accept(connection) else {
            NSLog("AgentHelper: rejected XPC connection — peer failed code-signing validation")
            return false
        }

        let handler = HelperCommandHandler()
        handler.connection = connection
        connection.exportedInterface = NSXPCInterface(with: HelperToolProtocol.self)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProgressProtocol.self)
        connection.exportedObject = handler
        connection.resume()
        return true
    }
}

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: "Agent.app.toddbruss.helper")
listener.delegate = delegate
// Primary defense: have the OS enforce the requirement before the delegate
// is even asked. `accept(...)` above is the belt-and-suspenders fallback.
XPCPeerValidator.install(on: listener)
listener.resume()
RunLoop.current.run()
