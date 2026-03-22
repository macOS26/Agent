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
        .openAI: "openai.txt",
        .deepSeek: "deepseek.txt",
        .huggingFace: "hugging_face.txt",
        .ollama: "ollama.txt",
        .localOllama: "local_ollama.txt",
        .foundationModel: "foundation_model.txt",
    ]

    /// Version header prefix embedded in each prompt file.
    private static let versionPrefix = "// Agent! v"
    /// Custom header prefix for user-edited prompts (never auto-overwritten).
    private static let customPrefix = "// Agent! custom v"

    /// Current app version from the bundle.
    private static let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }()

    private init() {}

    /// Ensure the system/ directory exists and default prompts are written.
    /// Replaces all prompts when the app version changes.
    func ensureDefaults() {
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.systemDir, withIntermediateDirectories: true)

        for (provider, fileName) in Self.fileNames {
            let url = Self.systemDir.appendingPathComponent(fileName)
            let needsWrite: Bool
            if !fm.fileExists(atPath: url.path) {
                needsWrite = true
            } else if let existing = try? String(contentsOf: url, encoding: .utf8),
                      let firstLine = existing.components(separatedBy: "\n").first {
                if firstLine.hasPrefix(Self.customPrefix) {
                    // User-edited prompt — never overwrite automatically
                    needsWrite = false
                } else if firstLine.hasPrefix(Self.versionPrefix) {
                    // Default prompt — replace if version changed
                    let fileVersion = String(firstLine.dropFirst(Self.versionPrefix.count))
                    needsWrite = fileVersion != Self.appVersion
                } else {
                    // No version stamp — replace with versioned prompt
                    needsWrite = true
                }
            } else {
                // Unreadable or empty — replace with default
                needsWrite = true
            }

            if needsWrite {
                let defaultPrompt = Self.versionPrefix + Self.appVersion + "\n" + Self.defaultPrompt(for: provider)
                try? defaultPrompt.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    /// Read the on-disk prompt for a provider, substituting {userName}, {userHome}, and {projectFolder}.
    /// Strips the version comment line before returning.
    func prompt(for provider: APIProvider, userName: String, userHome: String, projectFolder: String = "") -> String {
        ensureDefaults()
        guard let fileName = Self.fileNames[provider] else { return "" }
        let url = Self.systemDir.appendingPathComponent(fileName)
        guard let template = try? String(contentsOf: url, encoding: .utf8) else {
            return Self.defaultPrompt(for: provider)
        }
        // Strip version header before use
        let content = Self.stripVersionLine(template)
        let folder = projectFolder.isEmpty ? userHome : projectFolder
        return content
            .replacingOccurrences(of: "{userName}", with: userName)
            .replacingOccurrences(of: "{userHome}", with: userHome)
            .replacingOccurrences(of: "{projectFolder}", with: folder)
    }

    /// Remove the version/custom comment line from prompt content.
    private static func stripVersionLine(_ text: String) -> String {
        if text.hasPrefix(customPrefix) || text.hasPrefix(versionPrefix) {
            let lines = text.components(separatedBy: "\n")
            return lines.dropFirst().joined(separator: "\n")
        }
        return text
    }

    /// Read the raw template (with placeholders) for editing. Strips version line.
    func rawTemplate(for provider: APIProvider) -> String {
        ensureDefaults()
        guard let fileName = Self.fileNames[provider] else { return "" }
        let url = Self.systemDir.appendingPathComponent(fileName)
        let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? Self.defaultPrompt(for: provider)
        return Self.stripVersionLine(raw)
    }

    /// Save an edited template back to disk (prepends custom header to prevent auto-overwrite).
    func saveTemplate(_ content: String, for provider: APIProvider) {
        guard let fileName = Self.fileNames[provider] else { return }
        let url = Self.systemDir.appendingPathComponent(fileName)
        let stripped = Self.stripVersionLine(content)
        let versioned = Self.customPrefix + Self.appVersion + "\n" + stripped
        try? versioned.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Reset a provider's prompt to the built-in default.
    func resetToDefault(for provider: APIProvider) {
        guard let fileName = Self.fileNames[provider] else { return }
        let url = Self.systemDir.appendingPathComponent(fileName)
        let defaultPrompt = Self.versionPrefix + Self.appVersion + "\n" + Self.defaultPrompt(for: provider)
        try? defaultPrompt.write(to: url, atomically: true, encoding: .utf8)
    }

    /// The built-in default prompt template for each provider.
    /// Uses {userName}, {userHome}, and {projectFolder} as placeholders.
    private static func defaultPrompt(for provider: APIProvider) -> String {
        return AgentTools.systemPrompt(userName: "{userName}", userHome: "{userHome}", projectFolder: "{projectFolder}")
    }
}