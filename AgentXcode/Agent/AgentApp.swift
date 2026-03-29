import SwiftUI
import SwiftData

/// App identifiers — single source of truth for bundle ID, XPC services, plists, etc.
enum AppConstants {
    static let bundleID = "Agent.app.toddbruss"
    static let subsystem = bundleID
    static let helperID = "\(bundleID).helper"
    static let userID = "\(bundleID).user"
    static let helperPlist = "\(bundleID).helper.plist"
    static let userPlist = "\(bundleID).user.plist"

    /// Preferred shell path for in-app Process() calls.
    /// Reads from UserDefaults "agentShellPath", defaults to /bin/zsh.
    static var shellPath: String {
        UserDefaults.standard.string(forKey: "agentShellPath") ?? "/bin/zsh"
    }
}

extension Notification.Name {
    static let appWillQuit = Notification.Name("appWillQuit")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize accessibility enabled defaults on startup
        // This ensures the UserDefaults keys exist before any isRestricted() checks
        _ = AccessibilityEnabled.shared

        // Insert 🦾 Agents menu before File (position 1, after app menu)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.insertAgentsMenu()
        }
    }

    @MainActor private func insertAgentsMenu() {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }
        // Remove the SwiftUI-added "🦾 Agents" menu if it exists
        if let idx = mainMenu.items.firstIndex(where: { $0.title.contains("Agents") }) {
            mainMenu.removeItem(at: idx)
        }
        // Create NSMenu version and insert at position 1 (after app menu, before File)
        let agentsMenu = NSMenu(title: "🦾 Agents")
        let agentsItem = NSMenuItem(title: "🦾 Agents", action: nil, keyEquivalent: "")
        agentsItem.submenu = agentsMenu
        agentsMenu.delegate = AgentsMenuDelegate.shared
        let insertIdx = min(1, mainMenu.items.count)
        mainMenu.insertItem(agentsItem, at: insertIdx)
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Tell the view model to stop all running tasks, MCP servers, etc.
        NotificationCenter.default.post(name: .appWillQuit, object: nil)
        // Drain the script compilation queue before exit to prevent a deadlock
        // where C++ static destructors (DoIOSInit) try to fflush(stdout) while
        // the compilation queue holds the flockfile(stdout) lock.
        ScriptService.drainCompilationQueue()
        return .terminateNow
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
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("System Prompts") {
                    SystemPromptWindow.shared.show()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}
