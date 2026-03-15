# Agent Documentation

Welcome to the Agent project!

## Overview

Agent is a powerful macOS automation framework that enables intelligent control of applications, files, and system operations.

## Features

- **File Management**: Read, write, and edit files with ease
- **Git Integration**: Full version control support
- **Xcode Building**: Build and run Xcode projects
- **App Automation**: Control macOS apps via ScriptingBridge
- **Accessibility API**: Interact with any app's UI elements
- **Agent Scripts**: Create and run Swift dylib automation scripts

## Quick Start

1. Check the status of your repository
2. Make changes to files as needed
3. Build and test your work
4. Commit your changes

## Directory Structure

```
~/Documents/Agent/
├── agents/           # Swift automation scripts
│   ├── Package.swift
│   └── Sources/
│       ├── Scripts/
│       └── XCFScriptingBridges/
└── output/           # Generated files and logs
```

## Available Tools

| Tool Category | Purpose |
|---------------|---------|
| File Editing | Read, write, edit project files |
| Git | Version control operations |
| Xcode | Build and run projects |
| App Control | Automate macOS applications |
| Accessibility | UI interaction and screenshots |

## Tips

- Use `apple_event_query` for quick app data queries
- Use `run_agent_script` for complex automation tasks
- Always check TCC permissions for accessibility operations
- Prefer `edit_file` over shell commands for file changes

---

*Last updated: March 2025*