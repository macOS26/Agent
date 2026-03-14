import Foundation

@MainActor @Observable
final class XPCService {
    var userServiceActive = false
    var rootServiceActive = false
    var userWasActive = false
    var rootWasActive = false
    var rootEnabled: Bool = UserDefaults.standard.object(forKey: "agentRootEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(rootEnabled, forKey: "agentRootEnabled") }
    }
    
    func checkXPCStatus() {
        Task {
            do {
                let userStatus = try await checkXPCServiceStatus(serviceName: "com.agent.user-service")
                let rootStatus = try await checkXPCServiceStatus(serviceName: "com.agent.root-service")
                
                await MainActor.run {
                    userWasActive = userServiceActive
                    rootWasActive = rootServiceActive
                    userServiceActive = userStatus
                    rootServiceActive = rootStatus
                }
            } catch {
                print("Failed to check XPC status: \(error)")
            }
        }
    }
    
    func toggleRootService() {
        rootEnabled.toggle()
        if rootEnabled {
            startRootService()
        } else {
            stopRootService()
        }
    }
    
    private func startRootService() {
        Task {
            do {
                try await executeCommand(command: "launchctl load -w /Library/LaunchDaemons/com.agent.root-service.plist")
                try await Task.sleep(for: .seconds(1))
                await checkXPCStatus()
            } catch {
                print("Failed to start root service: \(error)")
            }
        }
    }
    
    private func stopRootService() {
        Task {
            do {
                try await executeCommand(command: "launchctl unload -w /Library/LaunchDaemons/com.agent.root-service.plist")
                try await Task.sleep(for: .seconds(1))
                await checkXPCStatus()
            } catch {
                print("Failed to stop root service: \(error)")
            }
        }
    }
    
    private func checkXPCServiceStatus(serviceName: String) async throws -> Bool {
        let result = try await executeCommand(command: "launchctl list | grep \(serviceName)")
        return !result.isEmpty
    }
    
    private func executeCommand(command: String) async throws -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
