@preconcurrency import Foundation
import AppKit
import SwiftUI

// MARK: - Model Fetching Extension
extension AgentViewModel {

    func fetchClaudeModels() async {
        guard !apiKey.isEmpty else {
            await MainActor.run {
                self.availableClaudeModels = Self.defaultClaudeModels
            }
            return
        }

        do {
            let models = try await Self.fetchClaudeModelsFromAPI(apiKey: apiKey)
            await MainActor.run {
                self.availableClaudeModels = models.isEmpty ? Self.defaultClaudeModels : models
            }
        } catch {
            print("Error fetching Claude models: \(error)")
            await MainActor.run {
                self.availableClaudeModels = Self.defaultClaudeModels
            }
        }
    }

    private static func fetchClaudeModelsFromAPI(apiKey: String) async throws -> [ClaudeModelInfo] {
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AgentError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "API error")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsData = json["data"] as? [[String: Any]] else {
            return defaultClaudeModels
        }

        let models = modelsData.compactMap { modelData -> ClaudeModelInfo? in
            guard let id = modelData["id"] as? String else { return nil }
            let displayName = modelData["display_name"] as? String ?? id
            let createdAt = modelData["created_at"] as? String
            let description = modelData["description"] as? String

            return ClaudeModelInfo(
                id: id,
                name: displayName,
                displayName: displayName,
                createdAt: createdAt,
                description: description
            )
        }

        return models.isEmpty ? defaultClaudeModels : models
    }

    func fetchOllamaModels() {
        let endpoint = ollamaEndpoint
        let apiKey = ollamaAPIKey
        isFetchingModels = true
        Task {
            defer { isFetchingModels = false }
            do {
                let models = try await Self.fetchModels(endpoint: endpoint, apiKey: apiKey)
                ollamaModels = models.isEmpty ? Self.defaultOllamaModels : models
                // Auto-select first model if current selection is empty or not in list
                let names = ollamaModels.map(\.name)
                if ollamaModel.isEmpty || (!names.isEmpty && !names.contains(ollamaModel)) {
                    ollamaModel = names.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch models: \(error.localizedDescription)")
                ollamaModels = Self.defaultOllamaModels
            }
        }
    }

    func fetchLocalOllamaModels() {
        let endpoint = localOllamaEndpoint
        isFetchingLocalModels = true
        Task {
            defer { isFetchingLocalModels = false }
            do {
                let models = try await Self.fetchModels(endpoint: endpoint, apiKey: "")
                localOllamaModels = models.isEmpty ? Self.defaultOllamaModels : models
                let names = localOllamaModels.map(\.name)
                if localOllamaModel.isEmpty || (!names.isEmpty && !names.contains(localOllamaModel)) {
                    localOllamaModel = names.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch local models: \(error.localizedDescription)")
                localOllamaModels = Self.defaultOllamaModels
            }
        }
    }

    // MARK: - OpenAI Model Fetching

    func fetchOpenAIModels() {
        guard !openAIAPIKey.isEmpty else {
            openAIModels = Self.defaultOpenAIModels
            return
        }
        isFetchingOpenAIModels = true
        Task {
            defer { isFetchingOpenAIModels = false }
            do {
                let models = try await Self.fetchOpenAIModelsFromAPI(apiKey: openAIAPIKey)
                openAIModels = models.isEmpty ? Self.defaultOpenAIModels : models
                let ids = openAIModels.map(\.id)
                if openAIModel.isEmpty || (!ids.isEmpty && !ids.contains(openAIModel)) {
                    openAIModel = ids.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch OpenAI models: \(error.localizedDescription)")
                openAIModels = Self.defaultOpenAIModels
            }
        }
    }

    func fetchDeepSeekModels() {
        guard !deepSeekAPIKey.isEmpty else {
            deepSeekModels = Self.defaultDeepSeekModels
            return
        }
        isFetchingDeepSeekModels = true
        Task {
            defer { isFetchingDeepSeekModels = false }
            do {
                let models = try await Self.fetchOpenAICompatibleModels(
                    baseURL: "https://api.deepseek.com/v1",
                    apiKey: deepSeekAPIKey
                )
                deepSeekModels = models.isEmpty ? Self.defaultDeepSeekModels : models
                let ids = deepSeekModels.map(\.id)
                if deepSeekModel.isEmpty || (!ids.isEmpty && !ids.contains(deepSeekModel)) {
                    deepSeekModel = ids.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch DeepSeek models: \(error.localizedDescription)")
                deepSeekModels = Self.defaultDeepSeekModels
            }
        }
    }

    func fetchHuggingFaceModels() {
        guard !huggingFaceAPIKey.isEmpty else {
            huggingFaceModels = Self.defaultHuggingFaceModels
            return
        }
        isFetchingHuggingFaceModels = true
        Task {
            defer { isFetchingHuggingFaceModels = false }
            do {
                let models = try await Self.fetchHuggingFaceModelsFromAPI(apiKey: huggingFaceAPIKey)
                huggingFaceModels = models.isEmpty ? Self.defaultHuggingFaceModels : models
                let ids = huggingFaceModels.map(\.id)
                if huggingFaceModel.isEmpty || (!ids.isEmpty && !ids.contains(huggingFaceModel)) {
                    huggingFaceModel = ids.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch HuggingFace models: \(error.localizedDescription)")
                huggingFaceModels = Self.defaultHuggingFaceModels
            }
        }
    }

    // MARK: - Static API Fetch Helpers

    private nonisolated static func fetchOpenAIModelsFromAPI(apiKey: String) async throws -> [OpenAIModelInfo] {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw AgentError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AgentError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "OpenAI API error")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["data"] as? [[String: Any]] else {
            return defaultOpenAIModels
        }

        let filtered = modelsArray
            .filter { model in
                let id = model["id"] as? String ?? ""
                return id.hasPrefix("gpt-") || id.hasPrefix("chatgpt-") || id.hasPrefix("o1-") || id.hasPrefix("o3-") || id.hasPrefix("o4-")
            }
            .compactMap { model -> OpenAIModelInfo? in
                guard let id = model["id"] as? String else { return nil }
                return OpenAIModelInfo(id: id, name: id)
            }
            .sorted { $0.name < $1.name }

        return filtered.isEmpty ? defaultOpenAIModels : filtered
    }

    private nonisolated static func fetchOpenAICompatibleModels(baseURL: String, apiKey: String) async throws -> [OpenAIModelInfo] {
        let endpoint = baseURL.hasSuffix("/models") ? baseURL : baseURL + "/models"
        guard let url = URL(string: endpoint) else { throw AgentError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AgentError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "API error")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["data"] as? [[String: Any]] else {
            return defaultDeepSeekModels
        }

        let models = modelsArray.compactMap { model -> OpenAIModelInfo? in
            guard let id = model["id"] as? String else { return nil }
            return OpenAIModelInfo(id: id, name: id)
        }.sorted { $0.name < $1.name }

        return models.isEmpty ? defaultDeepSeekModels : models
    }

    private nonisolated static func fetchHuggingFaceModelsFromAPI(apiKey: String) async throws -> [OpenAIModelInfo] {
        guard let url = URL(string: "https://api-inference.huggingface.co/models") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AgentError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "HuggingFace API error")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return defaultHuggingFaceModels
        }

        let models = json.compactMap { model -> OpenAIModelInfo? in
            guard let id = model["id"] as? String else { return nil }
            return OpenAIModelInfo(id: id, name: id)
        }.sorted { $0.name < $1.name }

        return models
    }

    private nonisolated static func fetchModels(endpoint: String, apiKey: String) async throws -> [OllamaModelInfo] {
        let effectiveEndpoint = endpoint.isEmpty ? "http://localhost:11434/api/chat" : endpoint
        guard let chatURL = URL(string: effectiveEndpoint) else { throw AgentError.invalidResponse }
        let baseDir = chatURL.deletingLastPathComponent().absoluteString

        guard let tagsURL = URL(string: baseDir + "tags") else { throw AgentError.invalidResponse }
        guard let showURL = URL(string: baseDir + "show") else { throw AgentError.invalidResponse }

        // 1. Fetch model list
        var tagsRequest = URLRequest(url: tagsURL)
        tagsRequest.httpMethod = "GET"
        tagsRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        if !apiKey.isEmpty {
            tagsRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        tagsRequest.timeoutInterval = llmAPITimeout

        let (data, response) = try await URLSession.shared.data(for: tagsRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AgentError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            throw AgentError.invalidResponse
        }

        let names = models.compactMap { $0["name"] as? String }.sorted()

        // 2. Check capabilities for each model via /api/show (in parallel)
        return await withTaskGroup(of: OllamaModelInfo?.self) { group in
            for name in names {
                group.addTask {
                    let hasVision = await Self.checkVision(model: name, showURL: showURL, apiKey: apiKey)
                    return OllamaModelInfo(id: name, name: name, supportsVision: hasVision)
                }
            }
            var results: [OllamaModelInfo] = []
            for await info in group {
                if let info { results.append(info) }
            }
            return results.sorted { $0.name < $1.name }
        }
    }

    /// Check if a model has "vision" in its capabilities via /api/show
    private nonisolated static func checkVision(model: String, showURL: URL, apiKey: String) async -> Bool {
        do {
            let body = try JSONSerialization.data(withJSONObject: ["model": model])
            var request = URLRequest(url: showURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = body
            request.timeoutInterval = llmAPITimeout

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let capabilities = json["capabilities"] as? [String] else {
                return false
            }
            return capabilities.contains("vision")
        } catch {
            return false
        }
    }

    // MARK: - Z.ai Models

    func fetchZAIModels() {
        isFetchingZAIModels = true
        let key = zAIAPIKey
        Task {
            defer { isFetchingZAIModels = false }
            guard !key.isEmpty else {
                zAIModels = Self.defaultZAIModels
                return
            }
            do {
                let models = try await Self.fetchZAIModelsFromAPI(apiKey: key)
                zAIModels = models.isEmpty ? Self.defaultZAIModels : models
                if zAIModel.isEmpty || !zAIModels.contains(where: { $0.id == zAIModel }) {
                    zAIModel = zAIModels.first?.id ?? "glm-4-plus"
                }
            } catch {
                appendLog("Failed to fetch Z.ai models: \(error.localizedDescription)")
                zAIModels = Self.defaultZAIModels
            }
        }
    }

    private nonisolated static func fetchZAIModelsFromAPI(apiKey: String) async throws -> [OpenAIModelInfo] {
        guard let url = URL(string: "https://api.z.ai/api/coding/paas/v4/models") else {
            throw AgentError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = llmAPITimeout
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let modelsData: [[String: Any]]
        if let data = json["data"] as? [[String: Any]] { modelsData = data }
        else if let models = json["models"] as? [[String: Any]] { modelsData = models }
        else { return [] }
        return modelsData.compactMap { model -> OpenAIModelInfo? in
            guard let id = model["id"] as? String else { return nil }
            return OpenAIModelInfo(id: id, name: id)
        }.sorted { $0.name < $1.name }
    }

    // MARK: - vLLM Models

    func fetchVLLMModels() {
        isFetchingVLLMModels = true
        let endpoint = vLLMEndpoint
        let key = vLLMAPIKey
        Task {
            defer { isFetchingVLLMModels = false }
            do {
                let models = try await Self.fetchVLLMModelsFromAPI(endpoint: endpoint, apiKey: key)
                vLLMModels = models
                let ids = models.map(\.id)
                if vLLMModel.isEmpty || (!ids.isEmpty && !ids.contains(vLLMModel)) {
                    vLLMModel = ids.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch vLLM models: \(error.localizedDescription)")
            }
        }
    }

    private nonisolated static func fetchVLLMModelsFromAPI(endpoint: String, apiKey: String) async throws -> [OpenAIModelInfo] {
        let modelsURL: URL
        if let range = endpoint.range(of: "/v1/") {
            let base = String(endpoint[endpoint.startIndex..<range.upperBound])
            guard let url = URL(string: base + "models") else { throw AgentError.invalidURL }
            modelsURL = url
        } else {
            guard let url = URL(string: endpoint) else { throw AgentError.invalidURL }
            modelsURL = url.deletingLastPathComponent().appendingPathComponent("models")
        }
        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.timeoutInterval = llmAPITimeout
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsData = json["data"] as? [[String: Any]] else { return [] }
        return modelsData.compactMap { model -> OpenAIModelInfo? in
            guard let id = model["id"] as? String else { return nil }
            return OpenAIModelInfo(id: id, name: id)
        }.sorted { $0.name < $1.name }
    }

    // MARK: - LM Studio Models

    func fetchLMStudioModels() {
        isFetchingLMStudioModels = true
        let proto = lmStudioProtocol
        let modelsEndpoint: String
        switch proto {
        case .lmStudio: modelsEndpoint = "http://localhost:1234/api/v1/models"
        default: modelsEndpoint = "http://localhost:1234/v1/models"
        }
        Task {
            defer { isFetchingLMStudioModels = false }
            do {
                let models = try await Self.fetchLMStudioModelsFromAPI(modelsURL: modelsEndpoint)
                lmStudioModels = models
                let ids = models.map(\.id)
                if lmStudioModel.isEmpty || (!ids.isEmpty && !ids.contains(lmStudioModel)) {
                    lmStudioModel = ids.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch LM Studio models: \(error.localizedDescription)")
            }
        }
    }

    private nonisolated static func fetchLMStudioModelsFromAPI(modelsURL: String) async throws -> [OpenAIModelInfo] {
        guard let url = URL(string: modelsURL) else { throw AgentError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = llmAPITimeout
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsData = json["data"] as? [[String: Any]] else { return [] }
        return modelsData.compactMap { model -> OpenAIModelInfo? in
            guard let id = model["id"] as? String else { return nil }
            return OpenAIModelInfo(id: id, name: id)
        }.sorted { $0.name < $1.name }
    }
}
