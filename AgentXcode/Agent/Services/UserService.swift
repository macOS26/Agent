import AppKit
import ServiceManagement

// MARK: - SMAppService Safe Wrapper
/// Safely wraps SMAppService operations to prevent crashes from malformed/missing plists.
/// The crash happens inside Objective-C code that Swift can't catch, so we verify
/// the plist exists BEFORE calling SMAppService methods.
enum SafeSMAppService {
    /// The plist filename for user agent
    static let userAgentPlistName = "Agent.app.toddbruss.user.plist"

    /// Path to the plist inside the app bundle (where SMAppService reads from)
    static var bundlePlistURL: URL? {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchAgents")
            .appendingPathComponent(userAgentPlistName)
    }

    /// Check if the user agent plist exists and is readable inside the app bundle
    static func userAgentPlistExists() -> Bool {
        guard let plistURL = bundlePlistURL else { return false }
        let path = plistURL.path

        // Check file exists
        guard FileManager.default.fileExists(atPath: path) else { return false }

        // Check file is readable
        guard FileManager.default.isReadableFile(atPath: path) else { return false }

        // Verify file has valid content (not empty, not corrupted)
        guard let data = FileManager.default.contents(atPath: path),
              !data.isEmpty,
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              plist is [String: Any] else {
            return false
        }

        return true
    }
    
    /// Create user agent service ONLY if plist is valid
    static func createUserAgent() -> SMAppService? {
        // CRITICAL: Only create SMAppService if plist exists and is valid
        // SMAppService crashes in Objective-C code if plist is malformed
        guard userAgentPlistExists() else { return nil }
        return SMAppService.agent(plistName: userAgentPlistName)
    }
    
    /// Safely check if user agent is ready - returns false if any issue
    static func isUserAgentReady() -> Bool {
        // First verify plist exists
        guard userAgentPlistExists() else { return false }
        
        // Create service and check status (may still crash in ObjC)
        guard let service = createUserAgent() else { return false }
        
        // Accessing .status could crash if plist is malformed, but we validated above
        return service.status == .enabled
    }
    
    /// Safely register user agent with comprehensive error handling
    static func registerUserAgent() -> (success: Bool, message: String) {
        // First verify plist exists
        guard userAgentPlistExists() else {
            return (false, "User agent plist not found in app bundle. Rebuild and reinstall Agent.")
        }
        
        guard let service = createUserAgent() else {
            return (false, "User agent unavailable. Reinstall Agent.")
        }
        
        let status = service.status
        let statusName = statusNameFor(status)
        
        do {
            try service.register()
            return (true, "User agent registered. (was: \(statusName))")
        } catch {
            // Check if already enabled after attempted registration
            if service.status == .enabled {
                return (true, "User agent is active.")
            }
            if service.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
                return (false, "Please approve Agent in System Settings > Login Items.")
            }
            // Try re-registering if was enabled
            if status == .enabled {
                try? service.unregister()
                do {
                    try service.register()
                    return (true, "User agent updated.")
                } catch {
                    return (false, "Update failed: \(error.localizedDescription)")
                }
            }
            return (false, "Registration failed: \(error.localizedDescription)")
        }
    }
    
    /// Safely unregister user agent
    static func unregisterUserAgent() {
        guard userAgentPlistExists(),
              let service = createUserAgent() else { return }
        try? service.unregister()
    }
    
    /// Get status name safely
    private static func statusNameFor(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered: return "notRegistered"
        case .enabled: return "enabled"
        case .requiresApproval: return "requiresApproval"
        case .notFound: return "notFound"
        @unknown default: return "unknown"
        }
    }
}

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
        SafeSMAppService.isUserAgentReady()
    }

    @discardableResult
    func registerUser() -> String {
        let result = SafeSMAppService.registerUserAgent()
        return result.message
    }

    /// Completely shut down and unregister the user agent.
    func shutdownAgent() {
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        kill.arguments = ["-f", "AgentUser"]
        try? kill.run()
        kill.waitUntilExit()

        SafeSMAppService.unregisterUserAgent()
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

        SafeSMAppService.unregisterUserAgent()
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
