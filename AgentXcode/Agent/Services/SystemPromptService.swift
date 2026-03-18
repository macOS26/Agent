import Foundation

/// Manages editable system prompt files stored at ~/Documents/AgentScript/system/.
/// On first access, copies the default prompts from AgentTools to disk.
/// At runtime, services read the on-disk prompts (with {userName}/{userHome} substitution).
@MainActor
final class SystemPromptService {
    static let shared = SystemPromptService()

    private static let systemDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/AgentScript/system")
    }()

    /// File names for each provider's system prompt.
    static let fileNames: [APIProvider: String] = [
        .claude: "claude.txt",
        .ollama: "ollama.txt",
        .localOllama: "local_ollama.txt",
        .foundationModel: "apple_ai.txt",
    ]

    private init() {}

    /// Ensure the system/ directory exists and default prompts are written.
    func ensureDefaults() {
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.systemDir, withIntermediateDirectories: true)

        for (provider, fileName) in Self.fileNames {
            let url = Self.systemDir.appendingPathComponent(fileName)
            if !fm.fileExists(atPath: url.path) {
                let defaultPrompt = Self.defaultPrompt(for: provider)
                try? defaultPrompt.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    /// Read the on-disk prompt for a provider, substituting {userName} and {userHome}.
    func prompt(for provider: APIProvider, userName: String, userHome: String) -> String {
        ensureDefaults()
        guard let fileName = Self.fileNames[provider] else { return "" }
        let url = Self.systemDir.appendingPathComponent(fileName)
        guard let template = try? String(contentsOf: url, encoding: .utf8) else {
            return Self.defaultPrompt(for: provider)
        }
        return template
            .replacingOccurrences(of: "{userName}", with: userName)
            .replacingOccurrences(of: "{userHome}", with: userHome)
    }

    /// Read the raw template (with placeholders) for editing.
    func rawTemplate(for provider: APIProvider) -> String {
        ensureDefaults()
        guard let fileName = Self.fileNames[provider] else { return "" }
        let url = Self.systemDir.appendingPathComponent(fileName)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? Self.defaultPrompt(for: provider)
    }

    /// Save an edited template back to disk.
    func saveTemplate(_ content: String, for provider: APIProvider) {
        guard let fileName = Self.fileNames[provider] else { return }
        let url = Self.systemDir.appendingPathComponent(fileName)
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Reset a provider's prompt to the built-in default.
    func resetToDefault(for provider: APIProvider) {
        guard let fileName = Self.fileNames[provider] else { return }
        let url = Self.systemDir.appendingPathComponent(fileName)
        let defaultPrompt = Self.defaultPrompt(for: provider)
        try? defaultPrompt.write(to: url, atomically: true, encoding: .utf8)
    }

    /// The built-in default prompt template for each provider.
    /// Uses {userName} and {userHome} as placeholders.
    private static func defaultPrompt(for provider: APIProvider) -> String {
        switch provider {
        case .claude, .ollama, .localOllama:
            return AgentTools.systemPrompt(userName: "{userName}", userHome: "{userHome}")
        case .foundationModel:
            return AgentTools.compactSystemPrompt(userName: "{userName}", userHome: "{userHome}")
        }
    }
}
