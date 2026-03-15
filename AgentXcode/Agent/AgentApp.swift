import SwiftUI

@main
struct AgentApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await MCPService.shared.startAutoStartServers()
                }
        }
        .windowResizability(.contentMinSize)
    }
}
