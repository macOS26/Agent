# AgentLLM

Generic LLM provider framework for macOS apps. Defines protocols and types — you bring the provider configs and API implementations.

## Architecture

```
LLMProvider         — Protocol: implement sendStreaming + fetchModels
LLMProviderConfig   — Full config: endpoint, auth, model, capabilities
LLMEndpoint         — Connection: chat URL, models URL, auth, headers, port
LLMProviderKind     — Hosting: cloudAPI, localServer, remoteServer, embedded, custom
LLMAPIProtocol      — Format: anthropic, openAI, ollama, foundationModel, custom
LLMCapability       — Features: streaming, tools, vision, caching, thinking, webSearch
LLMModelInfo        — Model: id, name, context window, capabilities
LLMResponse         — Result: content blocks, stop reason, token counts
LLMRegistry         — Registry: O(1) lookup, register/update/remove
```

## Usage

### 1. Configure a provider (in your app)

```swift
import AgentLLM

let myProvider = LLMProviderConfig(
    id: "my-llm",
    displayName: "My LLM",
    kind: .cloudAPI,
    apiProtocol: .openAI,
    endpoint: LLMEndpoint(
        chatURL: "https://api.example.com/v1/chat/completions",
        modelsURL: "https://api.example.com/v1/models"
    ),
    apiKey: "sk-...",
    model: "my-model-v1",
    capabilities: [.streaming, .tools, .systemPrompt]
)
```

### 2. Register it

```swift
LLMRegistry.shared.register(myProvider)
```

### 3. Implement the protocol (in your app)

```swift
class MyLLMService: LLMProvider {
    var config: LLMProviderConfig
    var systemPrompt: String = ""
    var overrideSystemPrompt: String?
    var temperature: Double = 0.2
    var compactTools: Bool = false

    func sendStreaming(
        messages: [[String: Any]],
        activeGroups: Set<String>?,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> LLMResponse {
        // Your API call here
    }
}
```

## Provider Kinds

| Kind | Auth | Example |
|---|---|---|
| `.cloudAPI` | API key required | Claude, OpenAI, DeepSeek |
| `.localServer` | Usually none | Ollama local, LM Studio |
| `.remoteServer` | Optional | vLLM, Ollama cloud |
| `.embedded` | None | Apple Intelligence |
| `.custom` | Varies | Hybrid setups |

## API Protocols

| Protocol | Format | Used By |
|---|---|---|
| `.anthropic` | Messages API | Claude, LM Studio (Anthropic mode) |
| `.openAI` | Chat Completions | OpenAI, DeepSeek, HuggingFace, Z.ai, vLLM, LM Studio |
| `.ollama` | Ollama native | Ollama local + cloud |
| `.foundationModel` | Apple on-device | Apple Intelligence |
| `.custom` | App-defined | LM Studio Native, future providers |

## Well-Known Ports

```swift
LLMEndpoint.ollamaPort    // 11434
LLMEndpoint.lmStudioPort  // 1234
LLMEndpoint.vLLMPort      // 8000
```

## Multi-Protocol Providers

Some providers support multiple API formats (e.g. LM Studio):

```swift
let lmStudio = LLMProviderConfig(
    id: "lmStudio",
    displayName: "LM Studio",
    kind: .localServer,
    apiProtocol: .openAI,  // default
    endpoint: LLMEndpoint(
        chatURL: "http://localhost:1234/v1/chat/completions",
        modelsURL: "http://localhost:1234/v1/models",
        authHeader: "", authPrefix: "",
        defaultPort: LLMEndpoint.lmStudioPort
    ),
    supportedProtocols: [.openAI, .anthropic, .custom]
)
```

Switch protocols by changing `apiProtocol` and `endpoint.chatURL`.

## Design Principles

- **Zero hardcoded providers** — the package has no provider-specific code
- **App owns the config** — URLs, keys, models, capabilities defined in your app
- **Protocol-based** — implement `LLMProvider` to add any LLM
- **Modular** — each type is independent, compose as needed
- **Future-proof** — add new providers without touching the package

## Requirements

- macOS 26+
- Swift 6.2+
