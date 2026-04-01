# AgentLLM

LLM provider framework for Agent! — protocols and types for adding any LLM provider.

## Architecture

```
LLMProviderKind     — How it's hosted (cloudAPI, localServer, embedded, etc.)
LLMEndpoint         — Connection details (URL, auth, paths, headers, timeout)
LLMCapability       — What it supports (streaming, tools, vision, caching, etc.)
LLMModelInfo        — Model metadata (id, name, context window, capabilities)
LLMProviderConfig   — Full config for a provider instance
LLMProvider         — Protocol that provider implementations conform to
LLMResponse         — Standardized response from any provider
LLMRegistry         — Central registry for all available providers
```

## Adding a New Provider

1. Create an `LLMProviderConfig` with endpoint, kind, and capabilities
2. Implement the `LLMProvider` protocol for API calls
3. Register with `LLMRegistry.shared.register(config)`

```swift
import AgentLLM

// 1. Configure
let config = LLMProviderConfig(
    id: "mistral",
    displayName: "Mistral AI",
    kind: .cloudAPI,
    endpoint: LLMEndpoint(
        baseURL: "https://api.mistral.ai",
        chatPath: "/v1/chat/completions",
        modelsPath: "/v1/models"
    ),
    apiKey: "your-key",
    model: "mistral-large-latest",
    capabilities: [.streaming, .tools, .systemPrompt]
)

// 2. Register
LLMRegistry.shared.register(config)

// 3. Implement LLMProvider protocol in your service class
```

## Provider Kinds

| Kind | Example | Auth | URL |
|---|---|---|---|
| `.cloudAPI` | Claude, OpenAI, DeepSeek | API key | Remote HTTPS |
| `.localServer` | Ollama, LM Studio | None | localhost |
| `.remoteServer` | vLLM, Ollama Cloud | Optional | Remote HTTP(S) |
| `.embedded` | Apple Intelligence | None | On-device |
| `.custom` | Hybrid setups | Varies | Varies |

## Endpoint Presets

Built-in presets for common providers:

```swift
LLMEndpoint.claude      // api.anthropic.com
LLMEndpoint.openAI      // api.openai.com
LLMEndpoint.ollama      // localhost:11434
LLMEndpoint.lmStudio    // localhost:1234
LLMEndpoint.deepSeek    // api.deepseek.com
LLMEndpoint.huggingFace // router.huggingface.co
```

## Requirements

- macOS 26+
- Swift 6.2+
