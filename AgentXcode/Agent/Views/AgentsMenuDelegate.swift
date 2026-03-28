import AppKit

private struct UncheckedSendable<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

/// NSMenu delegate that builds the 🦾 Agents menu dynamically from RecentAgentsService.
@MainActor
final class AgentsMenuDelegate: NSObject, NSMenuDelegate {
    static let shared = AgentsMenuDelegate()

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        let m = UncheckedSendable(menu)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                Self.shared.buildMenu(m.value)
            }
        }
    }

    private func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let entries = RecentAgentsService.shared.entries

        if entries.isEmpty {
            let item = NSMenuItem(title: "No recent agents", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }

        // Group by agent name
        var seen: [String: [RecentAgentsService.AgentEntry]] = [:]
        var order: [String] = []
        for entry in entries {
            if seen[entry.agentName] == nil {
                order.append(entry.agentName)
                seen[entry.agentName] = []
            }
            seen[entry.agentName]?.append(entry)
        }

        for name in order {
            guard let group = seen[name] else { continue }

            let agentSubmenu = NSMenu(title: name)
            let agentItem = NSMenuItem(title: name, action: nil, keyEquivalent: "")
            agentItem.submenu = agentSubmenu

            // ▶ Run submenu
            let runMenu = NSMenu(title: "▶ Run")
            let runItem = NSMenuItem(title: "▶ Run", action: nil, keyEquivalent: "")
            runItem.submenu = runMenu
            for entry in group {
                let label = entry.arguments.isEmpty ? entry.agentName : entry.arguments
                let item = NSMenuItem(title: label, action: #selector(playAgent(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = entry.populatedPrompt
                runMenu.addItem(item)
            }
            agentSubmenu.addItem(runItem)

            // ⏸ Edit submenu
            let editMenu = NSMenu(title: "⏸ Edit")
            let editItem = NSMenuItem(title: "⏸ Edit", action: nil, keyEquivalent: "")
            editItem.submenu = editMenu
            for entry in group {
                let label = entry.arguments.isEmpty ? entry.agentName : entry.arguments
                let item = NSMenuItem(title: label, action: #selector(editAgent(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = entry.populatedPrompt
                editMenu.addItem(item)
            }
            agentSubmenu.addItem(editItem)

            menu.addItem(agentItem)
        }

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: "Clear Recent Agents", action: #selector(clearAgents), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
    }

    private func addAgentItems(to menu: NSMenu, entry: RecentAgentsService.AgentEntry) {
        let playItem = NSMenuItem(title: "▶ \(entry.menuLabel)", action: #selector(playAgent(_:)), keyEquivalent: "")
        playItem.target = self
        playItem.representedObject = entry.populatedPrompt
        menu.addItem(playItem)

        let editItem = NSMenuItem(title: "✏️ \(entry.menuLabel)", action: #selector(editAgent(_:)), keyEquivalent: "")
        editItem.target = self
        editItem.representedObject = entry.populatedPrompt
        menu.addItem(editItem)
    }

    @objc private func playAgent(_ sender: NSMenuItem) {
        guard let prompt = sender.representedObject as? String else { return }
        // Run agent directly — skip the LLM, just compile and execute
        NotificationCenter.default.post(name: .runAgentDirect, object: nil, userInfo: ["prompt": prompt])
    }

    @objc private func editAgent(_ sender: NSMenuItem) {
        guard let prompt = sender.representedObject as? String else { return }
        NotificationCenter.default.post(name: .populateTaskInput, object: nil, userInfo: ["prompt": prompt])
    }

    @objc private func clearAgents() {
        RecentAgentsService.shared.clearAll()
    }
}
