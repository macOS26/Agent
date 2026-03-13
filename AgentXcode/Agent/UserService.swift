import AppKit
import ServiceManagement

final class UserOutputHandler: NSObject, UserProgressProtocol, @unchecked Sendable {
    private let handler: @Sendable (String) -> Void

    init(handler: @escaping @Sendable (String) -> Void) {
        self.handler = handler
    }

    func progressUpdate(_ line: String) {
        handler(line)
    }
}

@MainActor @Observable
final class UserService {
    nonisolated static let userID = "Agent.app.toddbruss.user"
    nonisolated let instanceID = UUID().uuidString

    var onOutput: (@MainActor @Sendable (String) -> Void)?

    nonisolated init() {}

    var userReady: Bool {
        SMAppService.agent(plistName: "Agent.app.toddbruss.user.plist").status == .enabled
    }

    @discardableResult
    func registerUser() -> String {
        let service = SMAppService.agent(plistName: "Agent.app.toddbruss.user.plist")
        let status = service.status

        let statusName: String
        switch status {
        case .notRegistered: statusName = "notRegistered"
        case .enabled: statusName = "enabled"
        case .requiresApproval: statusName = "requiresApproval"
        case .notFound: statusName = "notFound"
        @unknown default: statusName = "unknown"
        }

        do {
            try service.register()
            return "User agent registered. (was: \(statusName))"
        } catch {
            let afterStatus = service.status
            if afterStatus == .enabled {
                return "User agent is active."
            }
            if afterStatus == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
                return "Please approve Agent in System Settings > Login Items. (was: \(statusName))"
            }
            if status == .enabled {
                try? service.unregister()
                do {
                    try service.register()
                    return "User agent updated."
                } catch {
                    return "Update failed: \(error.localizedDescription) (status: \(statusName))"
                }
            }
            return "Registration failed: \(error.localizedDescription) (status: \(statusName))"
        }
    }

    func execute(command: String) async -> (status: Int32, output: String) {
        if !userReady {
            registerUser()
        }

        let handler = UserOutputHandler { [weak self] chunk in
            Task { @MainActor in
                self?.onOutput?(chunk)
            }
        }

        return await executeViaXPC(script: command, outputHandler: handler)
    }

    func cancel() {
        Self.cancelProcess(instanceID: instanceID)
    }

    nonisolated static func cancelProcess(instanceID: String) {
        Task.detached {
            await cancelViaXPC(instanceID: instanceID)
        }
    }

    // MARK: - XPC

    nonisolated private func makeConnection(outputHandler: UserOutputHandler) -> NSXPCConnection {
        // No .privileged option — runs as current user
        let connection = NSXPCConnection(machServiceName: UserService.userID, options: [])
        connection.remoteObjectInterface = NSXPCInterface(with: UserToolProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: UserProgressProtocol.self)
        connection.exportedObject = outputHandler
        connection.resume()
        return connection
    }

    nonisolated private func executeViaXPC(script: String, outputHandler: UserOutputHandler) async -> (status: Int32, output: String) {
        await withCheckedContinuation { continuation in
            let connection = makeConnection(outputHandler: outputHandler)
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(returning: (-1, "XPC error: \(error.localizedDescription)"))
            } as! UserToolProtocol

            proxy.execute(script: script, instanceID: self.instanceID) { status, output in
                connection.invalidate()
                continuation.resume(returning: (status, output))
            }
        }
    }

    nonisolated private static func cancelViaXPC(instanceID: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let connection = NSXPCConnection(machServiceName: userID, options: [])
            connection.remoteObjectInterface = NSXPCInterface(with: UserToolProtocol.self)
            connection.resume()
            let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
                continuation.resume()
            } as! UserToolProtocol
            proxy.cancelOperation(instanceID: instanceID) {
                connection.invalidate()
                continuation.resume()
            }
        }
    }
}
