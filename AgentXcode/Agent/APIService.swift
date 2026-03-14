import Foundation

enum APIProvider: String, CaseIterable {
    case claude = "claude"
    case ollama = "ollama"
    case localOllama = "localOllama"

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .ollama: "Ollama"
        case .localOllama: "Local Ollama"
        }
    }
}

@MainActor @Observable
final class APIService {
    var selectedProvider: APIProvider = APIProvider(rawValue: UserDefaults.standard.string(forKey: "agentProvider") ?? "claude") ?? .claude
    var claudeModels: [ClaudeModelInfo] = []
    var ollamaModels: [OllamaModelInfo] = []
    var selectedClaudeModel: String = UserDefaults.standard.string(forKey: "selectedClaudeModel") ?? "claude-sonnet-4-20250514"
    var selectedOllamaModel: String = UserDefaults.standard.string(forKey: "selectedOllamaModel") ?? "qwen3.5:397b"
    
    init() {
        fetchClaudeModels()
        fetchOllamaModels()
    }
    
    func fetchClaudeModels() {
        Task {
            do {
                let models = try await fetchClaudeModelsFromAPI()
                await MainActor.run {
                    self.claudeModels = models
                }
            } catch {
                print("Failed to fetch Claude models: \(error)")
                // Fall back to default models
                self.claudeModels = defaultClaudeModels
            }
        }
    }
    
    func fetchOllamaModels() {
        Task {
            do {
                let models = try await fetchOllamaModelsFromAPI()
                await MainActor.run {
                    self.ollamaModels = models
                }
            } catch {
                print("Failed to fetch Ollama models: \(error)")
                // Fall back to default models
                self.ollamaModels = defaultOllamaModels
            }
        }
    }
    
    private static let defaultClaudeModels: [ClaudeModelInfo] = [
        ClaudeModelInfo(id: "claude-sonnet-4-6", name: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6", createdAt: "2026-02-17", description: nil),
        ClaudeModelInfo(id: "claude-opus-4-6", name: "claude-opus-4-6", displayName: "Claude Opus 4.6", createdAt: "2026-02-04", description: nil),
        ClaudeModelInfo(id: "claude-haiku-4-5", name: "claude-haiku-4-5", displayName: "Claude Haiku 4.5", createdAt: "2025-10-15", description: nil),
        ClaudeModelInfo(id: "claude-opus-4-5", name: "claude-opus-4-5", displayName: "Claude Opus 4.5", createdAt: "2025-11-24", description: nil),
        ClaudeModelInfo(id: "claude-sonnet-4-5", name: "claude-sonnet-4-5", displayName: "Claude Sonnet 4.5", createdAt: "2025-09-29", description: nil),
        ClaudeModelInfo(id: "claude-opus-4-1", name: "claude-opus-4-1", displayName: "Claude Opus 4.1", createdAt: "2025-08-05", description: nil),
        ClaudeModelInfo(id: "claude-opus-4", name: "claude-opus-4", displayName: "Claude Opus 4", createdAt: "2025-05-22", description: nil),
        ClaudeModelInfo(id: "claude-sonnet-4", name: "claude-sonnet-4", displayName: "Claude Sonnet 4", createdAt: "2025-05-22", description: nil),
        ClaudeModelInfo(id: "claude-3-5-haiku-20241022", name: "claude-3-5-haiku-20241022", displayName: "Claude 3.5 Haiku", createdAt: "2024-10-22", description: nil)
    ]
    
    private static let defaultOllamaModels: [OllamaModelInfo] = [
        OllamaModelInfo(name: "nemotron-3-super", displayName: "Nemotron 3 Super", size: "Unknown", modified: "2026-03-11", supportsVision: false),
        OllamaModelInfo(name: "qwen3.5:397b", displayName: "Qwen3.5 397B", size: "210 GB", modified: "2026-02-16", supportsVision: false),
        OllamaModelInfo(name: "minimax-m2.5", displayName: "Minimax M2.5", size: "Unknown", modified: "2026-02-12", supportsVision: false),
        OllamaModelInfo(name: "glm-5", displayName: "GLM 5", size: "Unknown", modified: "2026-02-11", supportsVision: false),
        OllamaModelInfo(name: "kimi-k2.5", displayName: "Kimi K2.5", size: "Unknown", modified: "2026-01-26", supportsVision: true),
        OllamaModelInfo(name: "gemini-3-flash-preview", displayName: "Gemini 3 Flash Preview", size: "Unknown", modified: "2026-01-22", supportsVision: true),
        OllamaModelInfo(name: "glm-4.7", displayName: "GLM 4.7", size: "Unknown", modified: "2025-12-22", supportsVision: false),
        OllamaModelInfo(name: "gemma3:27b", displayName: "Gemma 3 27B", size: "16 GB", modified: "2025-12-17", supportsVision: true),
        OllamaModelInfo(name: "gemma3:12b", displayName: "Gemma 3 12B", size: "8 GB", modified: "2025-12-17", supportsVision: true),
        OllamaModelInfo(name: "gemma3:4b", displayName: "Gemma 3 4B", size: "3 GB", modified: "2025-12-17", supportsVision: true),
        OllamaModelInfo(name: "qwen3.5:72b", displayName: "Qwen3.5 72B", size: "40 GB", modified: "2025-12-16", supportsVision: false),
        OllamaModelInfo(name: "qwen3.5:32b", displayName: "Qwen3.5 32B", size: "18 GB", modified: "2025-12-16", supportsVision: false),
        OllamaModelInfo(name: "qwen3.5:14b", displayName: "Qwen3.5 14B", size: "8 GB", modified: "2025-12-16", supportsVision: false),
        OllamaModelInfo(name: "qwen3.5:7b", displayName: "Qwen3.5 7B", size: "4 GB", modified: "2025-12-16", supportsVision: false),
        OllamaModelInfo(name: "qwen3.5:4b", displayName: "Qwen3.5 4B", size: "2.5 GB", modified: "2025-12-16", supportsVision: false),
        OllamaModelInfo(name: "qwen3.5:1.5b", displayName: "Qwen3.5 1.5B", size: "1 GB", modified: "2025-12-16", supportsVision: false),
        OllamaModelInfo(name: "qwen3.5:0.5b", displayName: "Qwen3.5 0.5B", size: "300 MB", modified: "2025-12-16", supportsVision: false),
        OllamaModelInfo(name: "qwen3-vl:235b-instruct", displayName: "Qwen3 VL 235B Instruct", size: "130 GB", modified: "2025-09-22", supportsVision: true),
        OllamaModelInfo(name: "qwen3-vl:235b", displayName: "Qwen3 VL 235B", size: "130 GB", modified: "2025-09-22", supportsVision: true)
    ]
    
    private func fetchClaudeModelsFromAPI() async throws -> [ClaudeModelInfo] {
        guard let apiKey = KeychainService.shared.getClaudeAPIKey(), !apiKey.isEmpty else {
            print("Claude API key not found")
            return defaultClaudeModels
        }
        
        let url = URL(string: "https://api.anthropic.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("Failed to fetch Claude models: \(response)")
            return defaultClaudeModels
        }
        
        struct APIResponse: Codable {
            let data: [ModelData]
            
            struct ModelData: Codable {
                let id: String
                let display_name: String
                let created_at: String
            }
        }
        
        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        
        return apiResponse.data.map { model in
            ClaudeModelInfo(
                id: model.id,
                name: model.id,
                displayName: model.display_name,
                createdAt: model.created_at,
                description: nil
            )
        }
    }
    
    private func fetchOllamaModelsFromAPI() async throws -> [OllamaModelInfo] {
        let url = URL(string: "https://ollama.com/api/tags")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("Failed to fetch Ollama models: \(response)")
            return defaultOllamaModels
        }
        
        struct APIResponse: Codable {
            let models: [ModelData]
            
            struct ModelData: Codable {
                let name: String
                let modified_at: String
                let size: Int
                let digest: String
            }
        }
        
        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        
        return apiResponse.models.map { model in
            let displayName = model.name
                .replacingOccurrences(of: ":", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
            
            let sizeString: String
            if model.size > 1_000_000_000 {
                sizeString = String(format: "%.1f GB", Double(model.size) / 1_000_000_000)
            } else if model.size > 1_000_000 {
                sizeString = String(format: "%.1f MB", Double(model.size) / 1_000_000)
            } else {
                sizeString = String(format: "%d KB", model.size / 1000)
            }
            
            // Determine vision support based on model name
            let supportsVision = model.name.contains("-vl") || model.name.contains("vision") || 
                               model.name.contains("kimi") || model.name.contains("gemini") ||
                               model.name.contains("gemma3")
            
            return OllamaModelInfo(
                name: model.name,
                displayName: displayName,
                size: sizeString,
                modified: model.modified_at,
                supportsVision: supportsVision
            )
        }
    }
}
