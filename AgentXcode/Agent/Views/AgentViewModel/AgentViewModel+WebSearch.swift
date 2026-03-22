@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log

private let taskLog = Logger(subsystem: "Agent.app.toddbruss", category: "WebSearch")

// MARK: - Web Search Functions

extension AgentViewModel {
    
    // MARK: - Web Search (Ollama API + Tavily Backup)
    
    /// Perform web search using Ollama API for Ollama provider, Tavily as backup for other providers
    nonisolated private static func performTavilySearch(query: String, apiKey: String) async -> String {
        // Try Tavily as the default implementation
        return await performTavilySearchInternal(query: query, apiKey: apiKey)
    }
    
    /// Perform web search using the appropriate API based on provider
    nonisolated private static func performWebSearch(query: String, apiKey: String, provider: APIProvider) async -> String {
        // For Ollama provider, try Ollama web_search API first
        if provider == .ollama || provider == .localOllama {
            if let ollamaKey = KeychainService.shared.getOllamaAPIKey(), !ollamaKey.isEmpty {
                let ollamaResult = await performOllamaWebSearch(query: query, apiKey: ollamaKey)
                // If Ollama search succeeds, return it
                if !ollamaResult.hasPrefix("Error:") {
                    return ollamaResult
                }
                // Fall back to Tavily if Ollama search fails
            }
        }
        
        // Use Tavily as primary or backup
        return await performTavilySearchInternal(query: query, apiKey: apiKey)
    }
    
    /// Ollama Web Search API (cloud-only, requires API key)
    nonisolated private static func performOllamaWebSearch(query: String, apiKey: String) async -> String {
        guard !apiKey.isEmpty else {
            return "Error: Ollama API key not set. Add it in Settings."
        }
        
        guard let url = URL(string: "https://ollama.com/api/web_search") else {
            return "Error: Invalid Ollama search URL"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 90
        
        let body: [String: Any] = [
            "query": query,
            "max_results": 5
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return "Error: Invalid response from Ollama"
            }
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]] {
                    var output = "Web search results for '\(query)':\n\n"
                    for (index, result) in results.enumerated() {
                        let title = result["title"] as? String ?? "No title"
                        let url = result["url"] as? String ?? "No URL"
                        let snippet = result["snippet"] as? String ?? "No snippet"
                        output += "\(index + 1). \(title)\n   \(url)\n   \(snippet)\n\n"
                    }
                    return output
                } else {
                    return "Error: Failed to parse Ollama search results"
                }
            } else if httpResponse.statusCode == 401 {
                return "Error: Ollama API key invalid or expired"
            } else {
                return "Error: Ollama search failed with status \(httpResponse.statusCode)"
            }
        } catch {
            return "Error: Ollama search failed: \(error.localizedDescription)"
        }
    }
    
    /// Tavily Web Search API (requires API key)
    nonisolated private static func performTavilySearchInternal(query: String, apiKey: String) async -> String {
        guard !apiKey.isEmpty else {
            return "Error: Tavily API key not set. Add it in Settings."
        }
        
        guard let url = URL(string: "https://api.tavily.com/search") else {
            return "Error: Invalid Tavily URL"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.timeoutInterval = 90
        
        let body: [String: Any] = [
            "query": query,
            "max_results": 5,
            "include_answer": false,
            "include_raw_content": false,
            "search_depth": "basic"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return "Error: Invalid response from Tavily"
            }
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]] {
                    var output = "Web search results for '\(query)':\n\n"
                    for (index, result) in results.enumerated() {
                        let title = result["title"] as? String ?? "No title"
                        let url = result["url"] as? String ?? "No URL"
                        let content = result["content"] as? String ?? "No content"
                        output += "\(index + 1). \(title)\n   \(url)\n   \(content)\n\n"
                    }
                    return output
                } else {
                    return "Error: Failed to parse Tavily search results"
                }
            } else if httpResponse.statusCode == 401 {
                return "Error: Tavily API key invalid or expired"
            } else {
                return "Error: Tavily search failed with status \(httpResponse.statusCode)"
            }
        } catch {
            return "Error: Tavily search failed: \(error.localizedDescription)"
        }
    }
}