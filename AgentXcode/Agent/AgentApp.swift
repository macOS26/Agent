import SwiftUI
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Drain the script compilation queue before exit to prevent a deadlock
        // where C++ static destructors (DoIOSInit) try to fflush(stdout) while
        // the compilation queue holds the flockfile(stdout) lock.
        DispatchQueue.global().async {
            ScriptService.drainCompilationQueue()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@main
struct AgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Initialize SwiftData chat history store
                    ChatHistoryStore.shared.migrateFromUserDefaults()
                    
                    await MCPService.shared.startAutoStartServers()
                    // Sync registry enabled flags with actual connection state
                    let registry = MCPServerRegistry.shared
                    for server in registry.servers {
                        let connected = MCPService.shared.connectedServerIds.contains(server.id)
                        if server.enabled != connected {
                            registry.setEnabled(server.id, connected)
                        }
                    }
                }
        }
        .windowResizability(.contentMinSize)
    }
}
