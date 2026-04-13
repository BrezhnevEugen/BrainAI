# BrainAI

**Your knowledge, your device, your rules.**

Native macOS application that turns scattered knowledge into a persistent, AI-powered personal knowledge base. Built with Swift and LightRAG.

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS_14+-black.svg)]()
[![Swift](https://img.shields.io/badge/Swift-5.10+-orange.svg)]()

---

## What It Does

BrainAI is a **second brain** that actually thinks. It combines a knowledge graph (entities, relations, semantic connections) with AI-powered retrieval to give you instant access to everything you've ever learned and decided.

- **Persistent memory** across sessions, tools, and agents
- **Cross-agent** knowledge base for Cursor, Claude Cowork, MCP clients, REST API
- **Privacy-first** with data always stored locally on your device
- **Native macOS** experience built with Swift/SwiftUI, not Electron
- **Flexible AI compute** from fully offline (Ollama) to cloud APIs (OpenAI, Anthropic, DeepSeek)

## Architecture

```
BrainAI Tray         Menu bar agent. Service status, RAM monitoring, quick actions.
BrainAI Settings     Provider configuration, workspace management, server controls.
BrainAI UI           Knowledge graph viewer, AI chat with RAG, semantic search, notes.
BrainAI Installer    Setup wizard. Downloads Ollama, LightRAG, models automatically.
BrainAI Core         Shared Swift Package. Networking, providers, models, MCP bridge.
```

### Multi-Workspace

Isolated knowledge bases, each with its own LightRAG instance, storage, and provider configuration:

```
Work         :9621   OpenAI gpt-4o          Architecture decisions, meeting notes
Personal     :9622   Ollama qwen2.5:14b     Private notes, preferences
ESP32 Hobby  :9623   Ollama qwen2.5:14b     Pinouts, sensor data, wiring
Automotive   :9624   DeepSeek API           ECU programming, OBD protocols
```

Work data never leaks into personal context. Cross-workspace search when you need it.

### 4 Provider Roles

Each stage of the LightRAG pipeline uses its own provider and model:

| Role | Purpose | Can be |
|------|---------|--------|
| **Embedding** | Text vectorization | Ollama local, Remote Ollama, OpenAI API |
| **Extraction** | Entity/relation extraction | Ollama local, Remote Ollama, OpenAI, DeepSeek |
| **Reranker** | Improve retrieval accuracy (optional) | Jina API, Cohere API |
| **Generation** | Answer from context | Ollama local, Remote Ollama, Any cloud API |

Storage is always local. Compute is your choice.

## Requirements

| | Minimum | Recommended |
|---|---------|-------------|
| macOS | 14.0 Sonoma | 15.0+ |
| CPU | Apple Silicon M1 | M3 Pro+ |
| RAM | 8 GB | 16-36 GB |
| Disk | 5 GB (no models) | 30+ GB (with models) |

## Quick Start

### Installer (recommended)

Download the DMG from [Releases](https://github.com/BrezhnevEugen/BrainAI/releases). The installer detects existing components, downloads only what's missing, and configures everything.

### Manual

```bash
git clone https://github.com/BrezhnevEugen/BrainAI.git
cd BrainAI

# Prerequisites
brew install ollama
ollama pull bge-m3
ollama pull qwen2.5:14b
pip install lightrag-hku[api] --break-system-packages

# Build and run
swift build
swift run BrainAIApp
```

## Documentation

| Document | Description |
|----------|-------------|
| [TECHNICAL_SPEC.md](TECHNICAL_SPEC.md) | Full technical specification: architecture, API contracts, data models, development phases |
| [docs/WHY.md](docs/WHY.md) | Design decisions and reasoning: why Swift, why LightRAG, why Workspaces, why offline-first |
| [docs/architecture-diagrams.html](docs/architecture-diagrams.html) | Interactive architecture diagrams (open in browser) |
| [docs/ARCHITECTURE.mermaid](docs/ARCHITECTURE.mermaid) | Ecosystem diagram source |
| [docs/PIPELINE.mermaid](docs/PIPELINE.mermaid) | LightRAG processing pipeline with 4 provider roles |
| [docs/DEPLOYMENT.mermaid](docs/DEPLOYMENT.mermaid) | 5 deployment variants |

## Roadmap

**Phase 1** -- Foundation. Core package, Tray agent, Settings, LightRAG client, Ollama provider.

**Phase 2** -- Main UI. Dashboard, AI Chat with RAG, Semantic Search, Notes Editor.

**Phase 3** -- Graph and Installer. Knowledge graph visualization, setup wizard, auto-update.

**Phase 4** -- Remote and MCP. Remote LightRAG connection, MCP bridge, Bearer auth.

**Phase 5** -- Release. Localization (en, ru, uk), accessibility, performance tuning, v1.0.

**Beyond v1.0** -- iOS companion, iCloud sync, plugin system, Spotlight integration, watchOS, visionOS.

## Contributing

BrainAI is open source under the Apache License 2.0. Contributions are welcome. Read [TECHNICAL_SPEC.md](TECHNICAL_SPEC.md) before submitting a PR.

## License

[Apache License 2.0](LICENSE)

---

Built by [Eugen Brezhnev](https://github.com/BrezhnevEugen).
