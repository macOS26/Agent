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
        .vLLM: "vllm.txt",
        .lmStudio: "lm_studio.txt",
        .foundationModel: "foundation_model.txt",
    ]

    /// Compact prompt file names for each provider.
    static let compactFileNames: [APIProvider: String] = [
        .claude: "claude_compact.txt",
        .openAI: "openai_compact.txt",
        .deepSeek: "deepseek_compact.txt",
        .huggingFace: "hugging_face_compact.txt",
        .ollama: "ollama_compact.txt",
        .localOllama: "local_ollama_compact.txt",
        .vLLM: "vllm_compact.txt",
        .lmStudio: "lm_studio_compact.txt",
        .foundationModel: "foundation_model_compact.txt",
    ]

    /// Version header prefix embedded in each prompt file.
    private static let versionPrefix = "// Agent! v"
    /// Custom header prefix for user-edited prompts (never auto-overwritten).
    private static let customPrefix = "// Agent! custom v"
    /// READ ONLY header prefix for locked prompts (never auto-overwritten, even on version change).
    private static let readOnlyPrefix = "// Agent! READ ONLY v"

    /// Bump this when system prompt content changes to force re-sync of saved prompts.
    private static let promptRevision = "24"

    /// Combined version: app version + prompt revision. Change in either triggers re-sync.
    private static let appVersion: String = {
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return "\(bundleVersion).\(promptRevision)"
    }()

    private init() {}

    /// Ensure the system/ directory exists and default prompts are written.
    /// Replaces all prompts when the app version changes (unless READ ONLY).
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
                if firstLine.hasPrefix(Self.readOnlyPrefix) {
                    // READ ONLY prompt — never overwrite automatically
                    needsWrite = false
                } else if firstLine.hasPrefix(Self.customPrefix) {
                    // User-edited prompt — update on version change (preserves custom edits)
                    let fileVersion = String(firstLine.dropFirst(Self.customPrefix.count))
                    needsWrite = fileVersion != Self.appVersion
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
        
        // Also ensure compact prompts exist
        for (provider, fileName) in Self.compactFileNames {
            let url = Self.systemDir.appendingPathComponent(fileName)
            let needsWrite: Bool
            if !fm.fileExists(atPath: url.path) {
                needsWrite = true
            } else if let existing = try? String(contentsOf: url, encoding: .utf8),
                      let firstLine = existing.components(separatedBy: "\n").first {
                if firstLine.hasPrefix(Self.readOnlyPrefix) {
                    // READ ONLY prompt — never overwrite automatically
                    needsWrite = false
                } else if firstLine.hasPrefix(Self.customPrefix) {
                    // User-edited prompt — update on version change (preserves custom edits)
                    let fileVersion = String(firstLine.dropFirst(Self.customPrefix.count))
                    needsWrite = fileVersion != Self.appVersion
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
                let defaultPrompt = Self.versionPrefix + Self.appVersion + "\n" + Self.defaultCompactPrompt(for: provider)
                try? defaultPrompt.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    /// Read the on-disk prompt for a provider, substituting {userName}, {userHome}, and {projectFolder}.
    /// Strips the version comment line before returning.
    func prompt(for provider: APIProvider, userName: String, userHome: String, projectFolder: String = "", style: PromptStyle = .full) -> String {
        ensureDefaults()
        let fileName: String
        switch style {
        case .full:
            guard let fn = Self.fileNames[provider] else { return "" }
            fileName = fn
        case .compact:
            guard let fn = Self.compactFileNames[provider] else { return "" }
            fileName = fn
        }
        let url = Self.systemDir.appendingPathComponent(fileName)
        guard let template = try? String(contentsOf: url, encoding: .utf8) else {
            return style == .compact ? Self.defaultCompactPrompt(for: provider) : Self.defaultPrompt(for: provider)
        }
        // Strip version header before use
        let content = Self.stripVersionLine(template)
        let folder = projectFolder.isEmpty ? userHome : projectFolder
        return content
            .replacingOccurrences(of: "{userName}", with: userName)
            .replacingOccurrences(of: "{userHome}", with: userHome)
            .replacingOccurrences(of: "{projectFolder}", with: folder)
    }

    /// Remove the version/custom/readonly comment line from prompt content.
    private static func stripVersionLine(_ text: String) -> String {
        if text.hasPrefix(readOnlyPrefix) || text.hasPrefix(customPrefix) || text.hasPrefix(versionPrefix) {
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
        // Check if user added READ ONLY at the top
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let isReadOnly = trimmed.hasPrefix("READ ONLY") || trimmed.hasPrefix("// READ ONLY")
        let header = isReadOnly ? Self.readOnlyPrefix : Self.customPrefix
        let versioned = header + Self.appVersion + "\n" + stripped
        try? versioned.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Reset a provider's prompt to the built-in default.
    func resetToDefault(for provider: APIProvider) {
        guard let fileName = Self.fileNames[provider] else { return }
        let url = Self.systemDir.appendingPathComponent(fileName)
        let defaultPrompt = Self.versionPrefix + Self.appVersion + "\n" + Self.defaultPrompt(for: provider)
        try? defaultPrompt.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Check if a prompt is READ ONLY (user locked it to prevent auto-overwrite).
    func isReadOnly(provider: APIProvider) -> Bool {
        guard let fileName = Self.fileNames[provider] else { return false }
        let url = Self.systemDir.appendingPathComponent(fileName)
        guard let existing = try? String(contentsOf: url, encoding: .utf8),
              let firstLine = existing.components(separatedBy: "\n").first else {
            return false
        }
        return firstLine.hasPrefix(Self.readOnlyPrefix)
    }

    /// The built-in default prompt template for each provider.
    /// Uses {userName}, {userHome}, and {projectFolder} as placeholders.
    private static func defaultPrompt(for provider: APIProvider) -> String {
        return AgentTools.systemPrompt(userName: "{userName}", userHome: "{userHome}", projectFolder: "{projectFolder}")
    }
    
    /// The built-in default compact prompt template for each provider.
    /// Uses {userName}, {userHome}, and {projectFolder} as placeholders.
    private static func defaultCompactPrompt(for provider: APIProvider) -> String {
        return AgentTools.compactSystemPrompt(userName: "{userName}", userHome: "{userHome}", projectFolder: "{projectFolder}")
    }
}