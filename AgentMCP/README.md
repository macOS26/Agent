# AgentMCP

A lightweight Swift MCP (Model Context Protocol) client for macOS. Connect to any MCP server via stdio or HTTP — no external SDK required.

## Features

- **Stdio & HTTP** transport support
- **JSON-RPC 2.0** protocol implementation
- **Tool discovery** — auto-discover tools from connected servers
- **Tool execution** — call tools with typed arguments
- **Resource reading** — read resources from MCP servers
- **Multi-server** — manage connections to multiple servers simultaneously
- **Zero dependencies** — pure Swift, no external packages
- **macOS 26+** / Swift 6.2

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/macOS26/AgentMCP.git", from: "1.0.0"),
]
```

Then add `MCPClient` to your target:

```swift
.target(name: "YourApp", dependencies: [
    .product(name: "MCPClient", package: "AgentMCP"),
]),
```

## Usage

```swift
import MCPClient

// Create client and connect to an MCP server via stdio
let client = MCPClient()
let serverId = try await client.connect(
    name: "my-server",
    command: "/path/to/mcp-server",
    arguments: []
)

// Discover available tools
let tools = try await client.listTools(serverId: serverId)

// Call a tool
let result = try await client.callTool(
    serverId: serverId,
    name: "my_tool",
    arguments: ["key": .string("value")]
)
```

## Architecture

| File | Purpose |
|------|---------|
| `MCPClient.swift` | Main client API — connect, list tools, call tools |
| `MCPConnection.swift` | Base connection protocol |
| `StdioConnection.swift` | Stdio transport (launches process) |
| `HTTPConnection.swift` | HTTP/SSE transport |
| `ServerManager.swift` | Multi-server connection manager |
| `JSONValue.swift` | Type-safe JSON encoding/decoding |
| `MCPClientError.swift` | Error types |

## License

MIT
