// AgentLLM — LLM provider framework for Agent!
//
// This package defines the protocols and types for adding LLM providers.
// The app implements the actual provider services conforming to LLMProvider.
//
// Quick start — register a provider:
//
//   let config = LLMProviderConfig(
//       id: "my-provider",
//       displayName: "My LLM",
//       kind: .cloudAPI,
//       endpoint: LLMEndpoint(baseURL: "https://api.example.com"),
//       apiKey: "sk-...",
//       model: "my-model-v1"
//   )
//   LLMRegistry.shared.register(config)
//
// Then implement LLMProvider protocol for the actual API calls.

@_exported import Foundation
