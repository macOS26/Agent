import Foundation

/// Manages which internal tools are enabled per LLM provider.
/// Claude/Ollama: all tools on by default.
/// Apple AI: only core tools on by default (context window is too small for 40+).
@MainActor @Observable
final class ToolPreferencesService {
    static let shared = ToolPreferencesService()

    private var disabledTools: Set<String> = [] {
        didSet { persist() }
    }

    private static let udKey = "agent.disabledTools"
    private static let appleAISeededKey = "agent.appleAISeeded.v2"

    /// Tools enabled by default for Apple Intelligence (small context window).
    static let appleAIDefaults: Set<String> = [
        "task_complete", "list_agent_scripts", "run_agent_script",
        "list_native_tools", "apple_event_query",
        "run_applescript", "run_osascript"
    ]

    private init() {
        let arr = UserDefaults.standard.stringArray(forKey: Self.udKey) ?? []
        disabledTools = Set(arr)
        seedAppleAIDefaults()
    }

    /// On first launch, disable all Apple AI tools not in the core default set.
    private func seedAppleAIDefaults() {
        guard !UserDefaults.standard.bool(forKey: Self.appleAISeededKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.appleAISeededKey)
        let all = AgentTools.tools(for: .foundationModel).map { $0.name }
        var updated = disabledTools
        for name in all where !Self.appleAIDefaults.contains(name) {
            updated.insert(toolKey(.foundationModel, name))
        }
        disabledTools = updated  // single persist
    }

    private func persist() {
        UserDefaults.standard.set(Array(disabledTools), forKey: Self.udKey)
    }

    private func toolKey(_ provider: APIProvider, _ name: String) -> String {
        "\(provider.rawValue).\(name)"
    }

    func isEnabled(_ provider: APIProvider, _ toolName: String) -> Bool {
        !disabledTools.contains(toolKey(provider, toolName))
    }

    func toggle(_ provider: APIProvider, _ toolName: String) {
        let k = toolKey(provider, toolName)
        if disabledTools.contains(k) { disabledTools.remove(k) }
        else { disabledTools.insert(k) }
    }

    func enableAll(for provider: APIProvider) {
        disabledTools = disabledTools.filter { !$0.hasPrefix("\(provider.rawValue).") }
    }
}
