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
            var didResume = false
            let resumeLock = NSLock()

            func safeResume(_ value: (Int32, String)) {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            let connection = makeConnection(outputHandler: outputHandler)
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                safeResume((-1, "XPC error: \(error.localizedDescription)"))
            }) as? UserToolProtocol else {
                connection.invalidate()
                safeResume((-1, "XPC proxy cast failed"))
                return
            }

            // 90-second timeout — cancel and return error if XPC doesn't reply
            let timeout = DispatchWorkItem {
                connection.invalidate()
                Self.cancelProcess(instanceID: self.instanceID)
                safeResume((-1, "Error: command timed out after 90 seconds"))
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 90, execute: timeout)

            proxy.execute(script: script, instanceID: self.instanceID) { status, output in
                timeout.cancel()
                connection.invalidate()
                safeResume((status, output))
            }
        }
    }

    nonisolated private static func cancelViaXPC(instanceID: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let connection = NSXPCConnection(machServiceName: userID, options: [])
            connection.remoteObjectInterface = NSXPCInterface(with: UserToolProtocol.self)
            connection.resume()
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
                continuation.resume()
            }) as? UserToolProtocol else {
                connection.invalidate()
                continuation.resume()
                return
            }
            proxy.cancelOperation(instanceID: instanceID) {
                connection.invalidate()
                continuation.resume()
            }
        }
    }
}
