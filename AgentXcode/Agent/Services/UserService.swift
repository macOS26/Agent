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
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
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

    /// Completely shut down and unregister the user agent.
    func shutdownAgent() {
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        kill.arguments = ["-f", "AgentUser"]
        try? kill.run()
        kill.waitUntilExit()

        let service = SMAppService.agent(plistName: "Agent.app.toddbruss.user.plist")
        try? service.unregister()
    }

    /// Kill any stale agent processes, unregister, and re-register.
    @discardableResult
    func restartAgent() -> String {
        // Kill any lingering processes
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        kill.arguments = ["-f", "AgentUser"]
        try? kill.run()
        kill.waitUntilExit()

        // Unregister then re-register
        let service = SMAppService.agent(plistName: "Agent.app.toddbruss.user.plist")
        try? service.unregister()
        // Brief pause for launchd to clean up
        Thread.sleep(forTimeInterval: 0.5)
        return registerUser()
    }

    func execute(command: String) async -> (status: Int32, output: String) {
        if !userReady {
            let msg = restartAgent()
            if !userReady {
                return (-1, "Error: User agent is not running — \(msg). Check System Settings > Login Items.")
            }
        }

        let handler = UserOutputHandler { [weak self] chunk in
            Task { @MainActor in
                self?.onOutput?(chunk)
            }
        }

        return await executeViaXPC(script: command, outputHandler: handler)
    }

    /// Quick connectivity test with 5-second timeout. Returns true if XPC responds.
    func ping() async -> Bool {
        let handler = UserOutputHandler { _ in }
        let conn = makeConnection(outputHandler: handler)
        return await Self.performPing(connection: conn)
    }

    /// Runs XPC ping off the main actor so continuation can be resumed from any thread.
    private nonisolated static func performPing(connection: NSXPCConnection) async -> Bool {
        await withCheckedContinuation { continuation in
            var didResume = false
            let resumeLock = NSLock()
            func safeResume(_ value: Bool) {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
                safeResume(false)
            }) as? UserToolProtocol else {
                connection.invalidate()
                safeResume(false)
                return
            }

            let timeout = DispatchWorkItem {
                connection.invalidate()
                safeResume(false)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: timeout)

            proxy.execute(script: "echo ping", instanceID: UUID().uuidString) { status, _ in
                timeout.cancel()
                connection.invalidate()
                safeResume(status == 0)
            }
        }
    }

    func cancel() {
        onOutput = nil  // Clear handler to prevent memory leaks
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

            // No arbitrary timeout — commands run as long as they need.
            // Protection: early bailout if agent not running (checked in execute()),
            // XPC error handler if connection drops, user cancel button.
            proxy.execute(script: script, instanceID: self.instanceID) { status, output in
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
