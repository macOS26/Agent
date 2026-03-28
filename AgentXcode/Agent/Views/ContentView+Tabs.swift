import SwiftUI

// MARK: - Tab Management

extension ContentView {
    
    // MARK: - Tab Creation
    
    func createNewTab() {
        withAnimation {
            let newTab = ScriptTab()
            viewModel.scriptTabs.append(newTab)
            viewModel.selectedTabId = newTab.id
        }
    }
    
    func createNewTab(withScript script: Script) {
        withAnimation {
            let newTab = ScriptTab()
            newTab.scriptName = script.name
            newTab.scriptPath = script.path
            viewModel.scriptTabs.append(newTab)
            viewModel.selectedTabId = newTab.id
        }
    }
    
    func createNewTab(withPrompt prompt: String) {
        withAnimation {
            let newTab = ScriptTab()
            newTab.currentPrompt = prompt
            viewModel.scriptTabs.append(newTab)
            viewModel.selectedTabId = newTab.id
        }
    }
    
    // MARK: - Tab Selection
    
    func selectTab(number: Int) {
        guard number >= 1 && number <= viewModel.scriptTabs.count else { return }
        viewModel.selectedTabId = viewModel.scriptTabs[number - 1].id
    }
    
    func selectTab(id: UUID) {
        viewModel.selectedTabId = id
    }
    
    // MARK: - Tab Navigation
    
    func nextTab() {
        guard let currentId = viewModel.selectedTabId,
              let currentIndex = viewModel.scriptTabs.firstIndex(where: { $0.id == currentId }) else { return }
        
        let nextIndex = (currentIndex + 1) % viewModel.scriptTabs.count
        viewModel.selectedTabId = viewModel.scriptTabs[nextIndex].id
    }
    
    func previousTab() {
        guard let currentId = viewModel.selectedTabId,
              let currentIndex = viewModel.scriptTabs.firstIndex(where: { $0.id == currentId }) else { return }
        
        let previousIndex = (currentIndex - 1 + viewModel.scriptTabs.count) % viewModel.scriptTabs.count
        viewModel.selectedTabId = viewModel.scriptTabs[previousIndex].id
    }
    
    // MARK: - Tab Closure
    
    func closeTab(id: UUID) {
        guard let index = viewModel.scriptTabs.firstIndex(where: { $0.id == id }) else { return }
        
        // Stop any running task in this tab
        if let tab = viewModel.scriptTabs.first(where: { $0.id == id }) {
            if tab.isLLMRunning {
                viewModel.stopTabTask(tab: tab)
            }
        }
        
        withAnimation {
            viewModel.scriptTabs.remove(at: index)
            
            // Adjust selection
            if viewModel.selectedTabId == id {
                if viewModel.scriptTabs.isEmpty {
                    viewModel.selectedTabId = nil
                } else {
                    // Select the previous tab, or the first if we closed the first
                    let newIndex = min(index, viewModel.scriptTabs.count - 1)
                    viewModel.selectedTabId = viewModel.scriptTabs[newIndex].id
                }
            }
        }
    }
    
    func closeAllTabs() {
        // Stop all running tasks
        for tab in viewModel.scriptTabs where tab.isLLMRunning {
            viewModel.stopTabTask(tab: tab)
        }
        
        withAnimation {
            viewModel.scriptTabs.removeAll()
            viewModel.selectedTabId = nil
        }
    }
    
    // MARK: - Tab Status
    
    func isTabRunning(id: UUID) -> Bool {
        guard let tab = viewModel.scriptTabs.first(where: { $0.id == id }) else { return false }
        return tab.isBusy
    }
    
    func getTabStatus(id: UUID) -> TabStatus {
        guard let tab = viewModel.scriptTabs.first(where: { $0.id == id }) else {
            return .idle
        }
        
        if tab.isLLMRunning {
            return .llmThinking
        } else if tab.isRunning {
            return .runningScript
        } else {
            return .idle
        }
    }
    
    // MARK: - Tab Color
    
    static let tabColors: [Color] = [
        .orange, .purple, .pink, .cyan, .mint, .indigo, .teal, .yellow
    ]
    
    static func tabColor(for tabId: UUID, in tabs: [ScriptTab]) -> Color {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return .orange }
        return tabColors[idx % tabColors.count]
    }
}

// MARK: - Tab Status Enum

enum TabStatus {
    case idle
    case llmThinking
    case runningScript
}