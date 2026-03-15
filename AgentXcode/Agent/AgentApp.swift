import SwiftUI
import SwiftData

@main
struct AgentApp: App {
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
