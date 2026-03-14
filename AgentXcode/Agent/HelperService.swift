import AppKit
import ServiceManagement

final class OutputHandler: NSObject, HelperProgressProtocol, @unchecked Sendable {
    private let handler: @Sendable (String) -> Void

    init(handler: @escaping @Sendable (String) -> Void) {
        self.handler = handler
    }

    func progressUpdate(_ line: String) {
        handler(line)
    }
}

@MainActor @Observable
final class HelperService {
    nonisolated static let helperID = "Agent.app.toddbruss.helper"
    nonisolated let instanceID = UUID().uuidString

    var onOutput: (@MainActor @Sendable (String) -> Void)?

    nonisolated init() {}

    var helperReady: Bool {
        SMAppService.daemon(plistName: "Agent.app.toddbruss.helper.plist").status == .enabled
    }

    @discardableResult
    func registerHelper() -> String {
        let service = SMAppService.daemon(plistName: "Agent.app.toddbruss.helper.plist")
        let status = service.status

        // Log current status for diagnostics
        let statusName: String
        switch status {
        case .notRegistered: statusName = "notRegistered"
        case .enabled: statusName = "enabled"
        case .requiresApproval: statusName = "requiresApproval"
        case .notFound: statusName = "notFound"
        @unknown default: statusName = "unknown"
        }

        // Always try to register regardless of status
        do {
            try service.register()
            return "Helper daemon registered. (was: \(statusName))"
        } catch {
            let afterStatus = service.status
            if afterStatus == .enabled {
                return "Helper daemon is active."
            }
            if afterStatus == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
                return "Please approve Agent in System Settings > Login Items. (was: \(statusName))"
            }
            // Try unregister + re-register if it was already registered
            if status == .enabled {
                try? service.unregister()
                do {
                    try service.register()
                    return "Helper daemon updated."
                } catch {
                    return "Update failed: \(error.localizedDescription) (status: \(statusName))"
                }
            }
            return "Registration failed: \(error.localizedDescription) (status: \(statusName))"
        }
    }

    /// Completely shut down and unregister the daemon for security.
    func shutdownDaemon() {
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        kill.arguments = ["-f", "AgentHelper"]
        try? kill.run()
        kill.waitUntilExit()

        let service = SMAppService.daemon(plistName: "Agent.app.toddbruss.helper.plist")
        try? service.unregister()
    }

    /// Kill any stale daemon processes, unregister, and re-register.
    @discardableResult
    func restartDaemon() -> String {
        // Kill any lingering processes
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        kill.arguments = ["-f", "AgentHelper"]
        try? kill.run()
        kill.waitUntilExit()

        // Unregister then re-register
        let service = SMAppService.daemon(plistName: "Agent.app.toddbruss.helper.plist")
        try? service.unregister()
        // Brief pause for launchd to clean up
        Thread.sleep(forTimeInterval: 0.5)
        return registerHelper()
    }

    func execute(command: String) async -> (status: Int32, output: String) {
        if !helperReady {
            let msg = restartDaemon()
            if !helperReady {
                return (-1, "Error: Launch Daemon is not running — \(msg). Check System Settings > Login Items.")
            }
        }

        let handler = OutputHandler { [weak self] chunk in
            Task { @MainActor in
                self?.onOutput?(chunk)
            }
        }

        return await executeViaXPC(script: command, outputHandler: handler)
    }

    /// Quick connectivity test with 5-second timeout. Returns true if XPC responds.
    func ping() async -> Bool {
        let handler = OutputHandler { _ in }
        return await withCheckedContinuation { continuation in
            var didResume = false
            let resumeLock = NSLock()
            func safeResume(_ value: Bool) {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            let connection = makeConnection(outputHandler: handler)
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
                safeResume(false)
            }) as? HelperToolProtocol else {
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

    nonisolated private func makeConnection(outputHandler: OutputHandler) -> NSXPCConnection {
        let connection = NSXPCConnection(machServiceName: HelperService.helperID, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: HelperProgressProtocol.self)
        connection.exportedObject = outputHandler
        connection.resume()
        return connection
    }

    nonisolated private func executeViaXPC(script: String, outputHandler: OutputHandler) async -> (status: Int32, output: String) {
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
            }) as? HelperToolProtocol else {
                connection.invalidate()
                safeResume((-1, "XPC proxy cast failed"))
                return
            }

            // No arbitrary timeout — commands run as long as they need.
            // Protection: early bailout if daemon not running (checked in execute()),
            // XPC error handler if connection drops, user cancel button.
            proxy.execute(script: script, instanceID: self.instanceID) { status, output in
                connection.invalidate()
                safeResume((status, output))
            }
        }
    }

    nonisolated private static func cancelViaXPC(instanceID: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let connection = NSXPCConnection(machServiceName: helperID, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)
            connection.resume()
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
                continuation.resume()
            }) as? HelperToolProtocol else {
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
