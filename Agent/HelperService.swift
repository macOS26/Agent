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
    nonisolated static let helperID = "com.agent.helper"
    nonisolated let instanceID = UUID().uuidString

    var onOutput: (@Sendable (String) -> Void)?

    nonisolated init() {}

    var helperReady: Bool {
        SMAppService.daemon(plistName: "com.agent.helper.plist").status == .enabled
    }

    @discardableResult
    func registerHelper() -> String {
        let service = SMAppService.daemon(plistName: "com.agent.helper.plist")
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

    func execute(command: String) async -> (status: Int32, output: String) {
        if !helperReady {
            registerHelper()
        }

        let handler = OutputHandler { [weak self] chunk in
            Task { @MainActor in
                self?.onOutput?(chunk)
            }
        }

        return await executeViaXPC(script: command, outputHandler: handler)
    }

    func cancel() {
        Task.detached {
            await self.cancelViaXPC()
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
            let connection = makeConnection(outputHandler: outputHandler)
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(returning: (-1, "XPC error: \(error.localizedDescription)"))
            } as! HelperToolProtocol

            proxy.execute(script: script, instanceID: self.instanceID) { status, output in
                connection.invalidate()
                continuation.resume(returning: (status, output))
            }
        }
    }

    nonisolated private func cancelViaXPC() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let connection = NSXPCConnection(machServiceName: HelperService.helperID, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)
            connection.resume()
            let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
                continuation.resume()
            } as! HelperToolProtocol
            proxy.cancelOperation(instanceID: self.instanceID) {
                connection.invalidate()
                continuation.resume()
            }
        }
    }
}
