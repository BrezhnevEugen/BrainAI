# BrainAI Architecture

## Overview

BrainAI is a multi-process macOS application built with Swift 5.10+ and SwiftUI. It follows a modular architecture with a shared core library and multiple executable targets communicating via XPC.

## System Diagram

```
                    +------------------+
                    |   BrainAI Tray   |  (Menu Bar Agent)
                    |  NSStatusItem    |
                    +--------+---------+
                             |
                             | XPC
                             v
+------------------+   +-----------+   +------------------+
|  BrainAI Main UI |<->| BrainAI   |<->| BrainAI Settings |
| NavigationSplit  |   |   Core    |   |  SwiftUI Tabs    |
|                  |   | (Library) |   |                  |
+------------------+   +-----+-----+   +------------------+
                             |
              +--------------+--------------+
              |              |              |
        +-----+-----+ +-----+-----+ +-----+-----+
        |  Ollama    | | LightRAG  | | Cloud API |
        | (Local LLM)| | (KG+RAG)  | | (OpenAI/  |
        | Port 11434 | | Port 9621 | | Anthropic)|
        +-----------+ +-----------+ +-----------+
```

## Core Library (BrainAICore)

The shared library contains all business logic, networking, and data models.

### Models

- **Enums.swift** - Core enumerations: ProviderType, SearchMode, ProcessStatus, ConnectionMode, MessageRole, ModelCapability
- **LLMModel.swift** - LLM model representation with capabilities and parameters
- **RoleConfig.swift** - Provider role configuration (embedding, extraction, reranker, generation)
- **DTOs.swift** - Data transfer objects for all API communication (LightRAG, Ollama, Graph)

### Providers

Four provider roles support different AI capabilities:

1. **Embedding Provider** - Converts text to vector embeddings (Ollama, OpenAI)
2. **Extraction LLM** - Extracts entities/relations for knowledge graph (Ollama, OpenAI, Anthropic)
3. **Reranker** (optional) - Re-ranks search results
4. **Generation LLM** - Generates chat responses (Ollama, OpenAI, Anthropic)

Provider implementations use the actor model for thread safety:
- `OllamaLLMProvider` / `OllamaEmbeddingProvider`
- `OpenAILLMProvider` / `OpenAIEmbeddingProvider`
- `AnthropicLLMProvider`

### Networking

- **HTTPClient** - Generic actor-based HTTP client with JSON encoding/decoding, snake_case key strategy
- **LightRAGClient** - Protocol and implementations (Local/Remote) for LightRAG API
- **OllamaAPI** - Client for Ollama REST API

### Process Management

- **ManagedProcess** - Protocol for managing long-running background processes
- **OllamaProcessManager** - Manages Ollama server lifecycle
- **LightRAGProcessManager** - Manages LightRAG Python server lifecycle
- **ServiceOrchestrator** - Coordinates startup/shutdown of all services

### XPC Communication

- **BrainAIXPCProtocol** - @objc protocol defining IPC interface
- **BrainAIXPCService** - Server-side implementation
- **BrainAIXPCConnectionManager** - Manages listener (server) and connection (client) modes

### Updates

- **SparkleUpdateManager** - Sparkle framework integration for auto-updates

## Main UI Application (BrainAIApp)

SwiftUI application with NavigationSplitView sidebar navigation:

### Views

| Section | Description | Key Features |
|---------|-------------|-------------|
| **Dashboard** | Overview with stats and status | Service status, workspace info, quick actions |
| **Knowledge Graph** | Interactive graph visualization | SpriteKit force-directed layout, filtering, path search |
| **Chat** | AI conversation with RAG | Context retrieval, model selection, streaming |
| **Search** | Semantic search interface | Multiple search modes, result cards, top-K control |
| **Notes** | Markdown notes editor | CRUD, tags, KB sync, JSON persistence |
| **Documents** | Document management | Import, status tracking, pagination |

### Knowledge Graph Viewer

Built with SpriteKit for hardware-accelerated rendering:
- Force-directed layout algorithm (repulsion + attraction + centering + damping)
- Interactive node selection with connection highlighting
- Entity type filtering with color-coded legend
- BFS-based path finding between nodes
- Mouse-based zoom, pan, and node drag
- Automatic stabilization detection

## Installer (BrainAIInstaller)

Step-by-step wizard for initial setup:

1. Welcome - System info display
2. Components - Select what to install (LightRAG, Ollama, sample data)
3. Provider - Choose AI provider (local/cloud)
4. Models - Select LLM model based on available RAM
5. Download - Progress tracking for each component
6. Complete - Health checks and launch options

## Data Flow

### Query Pipeline

```
User Query
    |
    v
LightRAG Client (query with search mode)
    |
    v
LightRAG Server (vector search + graph traversal)
    |
    v
Retrieved Context (entities, relations, chunks)
    |
    v
LLM Provider (generate response with context)
    |
    v
Chat Response (with RAG context disclosure)
```

### Document Ingestion Pipeline

```
Document Upload
    |
    v
LightRAG Client (insertText)
    |
    v
LightRAG Server:
  1. Text chunking
  2. Embedding generation (via Ollama/OpenAI)
  3. Entity extraction (via LLM)
  4. Relation extraction (via LLM)
  5. Graph + vector store update
    |
    v
Knowledge Base Updated
```

## Key Design Decisions

### @Observable + @unchecked Sendable

ViewModels use the `@Observable` macro with `@unchecked Sendable` and `NSLock` for thread-safe property mutations from async contexts.

### Actor-Based Providers

All LLM and embedding providers are implemented as Swift actors, ensuring thread-safe API access without manual locking.

### HTTPClient Snake Case Strategy

The HTTPClient uses `.convertToSnakeCase` / `.convertFromSnakeCase` key strategies. DTOs with explicit CodingKeys must account for this (the strategy is applied after CodingKey resolution on encode, and before on decode).

### XPC for IPC

NSXPCListener with anonymous connections enables inter-process communication between the tray agent, main UI, and settings app without requiring a registered Mach service.

### SpriteKit for Graph Rendering

Chosen over SceneKit/Metal for simpler 2D graph rendering with built-in mouse event handling, scene graph management, and AppKit integration via SpriteView.
