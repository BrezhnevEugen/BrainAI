# BrainAI — Техническое задание (ТЗ)

**Версия:** 1.1
**Дата:** 2026-04-11
**Автор:** Eugen Brezhnev
**Лицензия:** Apache License 2.0
**Репозиторий:** https://github.com/BrezhnevEugen/BrainAI

---

## 1. Обзор продукта

### 1.1 Что такое BrainAI

BrainAI — нативное macOS-приложение, персональная база знаний с AI-усилением. Продукт объединяет граф знаний (LightRAG), локальные и облачные LLM-провайдеры, и нативный Swift-интерфейс в единую экосистему «второго мозга».

### 1.2 Ключевая ценность

- **Персональная память**, которая живёт между сессиями, агентами и инструментами
- **Кросс-агентность** — единая база знаний для Cursor, Cowork, MCP-клиентов, REST API
- **Privacy-first** — данные локально, облако только по выбору пользователя
- **Нативный опыт** — не Electron, не WebView, а полноценное Swift/SwiftUI приложение

### 1.3 Целевая аудитория

- Разработчики и технические специалисты
- Power-users, работающие с несколькими AI-агентами
- Пользователи, которым важен контроль над своими данными

### 1.4 Стратегия выпуска

| Фаза | Модель | Распространение |
|------|--------|----------------|
| Alpha | Open Source (Apache 2.0) | GitHub Releases + Sparkle auto-update |
| Beta | Open Source + Premium фичи | GitHub + TestFlight |
| Release | Freemium | Mac App Store + сайт |

---

## 2. Архитектура

### 2.1 Принципы

- **Модульность** — каждый компонент является отдельным Swift Package или target
- **Изоляция процессов** — tray, settings, main UI, server manager — отдельные процессы через XPC
- **Protocol-oriented** — все интеграции через протоколы, легко подменяемые реализации
- **Offline-first** — полная функциональность без интернета (с локальным Ollama)
- **Расширяемость** — архитектура готова к iOS, iPadOS, visionOS без переписывания core
- **No emoji** — в коде, UI, комментариях, документации и диаграммах не используются эмодзи. Иконки только через SF Symbols (нативные Apple-иконки)

### 2.2 Высокоуровневая схема

```
┌─────────────────────────────────────────────────────────────┐
│                     BrainAI Ecosystem                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Tray Agent   │  │  Settings    │  │   Main UI        │  │
│  │  (MenuBar)    │  │  (SwiftUI)   │  │   (SwiftUI)      │  │
│  │              │  │              │  │                  │  │
│  │ - Status      │  │ - LLM config │  │ - Knowledge      │  │
│  │ - RAM monitor │  │ - Providers  │  │   graph viewer   │  │
│  │ - Quick       │  │ - API keys   │  │ - AI chat        │  │
│  │   actions     │  │ - Server mgmt│  │ - Search         │  │
│  │ - Alerts      │  │ - Domains    │  │ - Notes editor   │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
│         │                 │                    │             │
│         └────────────┬────┴────────────────────┘             │
│                      │ XPC Services                          │
│                      ▼                                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                  BrainAICore (SPM)                     │  │
│  │                                                       │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐  │  │
│  │  │ Networking   │  │ LLMProvider  │  │ DataModels  │  │  │
│  │  │ (REST/WS)    │  │ (Protocol)   │  │ (SwiftData) │  │  │
│  │  └─────────────┘  └──────────────┘  └─────────────┘  │  │
│  │                                                       │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐  │  │
│  │  │ ProcessMgr   │  │ MCPBridge    │  │ Security    │  │  │
│  │  │ (Ollama,RAG) │  │ (MCP Proto)  │  │ (Keychain)  │  │  │
│  │  └─────────────┘  └──────────────┘  └─────────────┘  │  │
│  └───────────────────────────┬───────────────────────────┘  │
│                              │                               │
│                              ▼                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Backend Services (Managed)                │  │
│  │                                                       │  │
│  │  ┌──────────────┐  ┌──────────────┐                   │  │
│  │  │ LightRAG     │  │ Ollama       │                   │  │
│  │  │ Server       │  │ (local LLM)  │                   │  │
│  │  │ (Python)     │  │              │                   │  │
│  │  │ port 9621    │  │ port 11434   │                   │  │
│  │  └──────────────┘  └──────────────┘                   │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              External Connections                      │  │
│  │                                                       │  │
│  │  ┌──────────┐  ┌──────────┐  ┌─────────────────────┐ │  │
│  │  │ OpenAI   │  │ Anthropic│  │ Remote LightRAG     │ │  │
│  │  │ API      │  │ API      │  │ (REST/MCP bridge)   │ │  │
│  │  └──────────┘  └──────────┘  └─────────────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 2.3 Структура репозитория

```
BrainAI/
├── Package.swift                    # Root SPM workspace
├── TECHNICAL_SPEC.md
├── LICENSE
├── README.md
├── docs/
│   ├── SETUP.md
│   ├── ARCHITECTURE.md
│   └── API.md
│
├── Sources/
│   ├── BrainAICore/                 # Shared library (SPM package)
│   │   ├── Models/                  # SwiftData models, DTOs
│   │   ├── Networking/              # REST client, WebSocket
│   │   ├── Providers/               # Model provider protocols + implementations
│   │   │   ├── Protocols/
│   │   │   │   ├── EmbeddingProvider.swift   # Векторизация текста
│   │   │   │   ├── LLMProvider.swift         # Генерация текста (extraction + generation)
│   │   │   │   └── RerankerProvider.swift    # Переранжирование чанков
│   │   │   ├── Ollama/
│   │   │   │   ├── OllamaEmbeddingProvider.swift
│   │   │   │   ├── OllamaLLMProvider.swift
│   │   │   │   └── OllamaClient.swift        # Shared HTTP client
│   │   │   ├── OpenAI/
│   │   │   │   ├── OpenAIEmbeddingProvider.swift
│   │   │   │   ├── OpenAILLMProvider.swift
│   │   │   │   └── OpenAIClient.swift
│   │   │   ├── Anthropic/
│   │   │   │   ├── AnthropicLLMProvider.swift
│   │   │   │   └── AnthropicClient.swift
│   │   │   ├── DeepSeek/
│   │   │   │   ├── DeepSeekLLMProvider.swift
│   │   │   │   └── DeepSeekClient.swift
│   │   │   ├── Reranker/
│   │   │   │   ├── JinaRerankerProvider.swift
│   │   │   │   └── CohereRerankerProvider.swift
│   │   │   └── ProviderRegistry.swift        # Manages all provider instances
│   │   ├── Workspace/                # Multi-workspace management
│   │   │   ├── Workspace.swift       # Model
│   │   │   ├── WorkspaceManager.swift # Lifecycle, cross-query
│   │   │   └── WorkspaceMigrator.swift # Domain → Workspace migration
│   │   ├── ProcessManager/          # Ollama, LightRAG process lifecycle
│   │   ├── MCP/                     # MCP protocol bridge
│   │   ├── Security/                # Keychain wrapper
│   │   ├── Configuration/           # Settings, defaults, migrations
│   │   └── Extensions/
│   │
│   ├── BrainAITray/                 # Menu bar agent (AppKit + SwiftUI)
│   │   ├── App/
│   │   │   └── TrayApp.swift
│   │   ├── Views/
│   │   │   ├── StatusMenu.swift
│   │   │   ├── RAMMonitorView.swift
│   │   │   └── QuickActionsView.swift
│   │   └── Services/
│   │       └── SystemMonitor.swift
│   │
│   ├── BrainAISettings/             # Settings app (SwiftUI)
│   │   ├── App/
│   │   │   └── SettingsApp.swift
│   │   ├── Views/
│   │   │   ├── GeneralTab.swift
│   │   │   ├── ProvidersTab.swift
│   │   │   ├── ServerTab.swift
│   │   │   ├── DomainsTab.swift
│   │   │   └── AdvancedTab.swift
│   │   └── ViewModels/
│   │
│   ├── BrainAIApp/                  # Main UI app (SwiftUI)
│   │   ├── App/
│   │   │   └── BrainAIApp.swift
│   │   ├── Views/
│   │   │   ├── KnowledgeGraph/      # Граф знаний (визуализация)
│   │   │   ├── Chat/                # AI-чат с контекстом
│   │   │   ├── Search/              # Семантический поиск
│   │   │   ├── Notes/               # Редактор заметок
│   │   │   ├── Documents/           # Управление документами
│   │   │   └── Dashboard/           # Главный экран
│   │   ├── ViewModels/
│   │   └── Services/
│   │
│   ├── BrainAIInstaller/            # Installer / Setup Wizard
│   │   ├── App/
│   │   │   └── InstallerApp.swift
│   │   ├── Views/
│   │   │   ├── WelcomeStep.swift
│   │   │   ├── ComponentsStep.swift # Выбор компонентов
│   │   │   ├── ProviderStep.swift   # Настройка провайдера
│   │   │   ├── DownloadStep.swift   # Прогресс загрузки
│   │   │   └── CompleteStep.swift
│   │   └── Services/
│   │       ├── OllamaInstaller.swift
│   │       ├── PythonEnvSetup.swift
│   │       └── LightRAGSetup.swift
│   │
│   └── BrainAIXPC/                  # XPC service for IPC
│       ├── BrainAIXPCProtocol.swift
│       └── BrainAIXPCService.swift
│
├── Tests/
│   ├── BrainAICoreTests/
│   ├── BrainAITrayTests/
│   └── BrainAIAppTests/
│
├── Resources/
│   ├── Assets.xcassets
│   ├── Localizable/                 # i18n (en, ru, uk)
│   └── DefaultConfig.plist
│
├── Scripts/
│   ├── setup-dev.sh
│   ├── build-release.sh
│   └── notarize.sh
│
└── Server/                          # Bundled backend
    ├── lightrag/                    # LightRAG (Python, embedded)
    ├── requirements.txt
    ├── start_server.py
    └── config/
```

---

## 3. Модули — детальное описание

### 3.1 BrainAICore (Swift Package)

Общая библиотека, от которой зависят все приложения.

#### 3.1.1 Models (SwiftData)

```swift
// Основные модели
@Model class KnowledgeEntity {
    var id: UUID
    var name: String
    var entityType: EntityType     // Project, Technology, Bug, Decision...
    var description: String
    var domain: Domain             // work, personal-project, hobby-esp32...
    var createdAt: Date
    var updatedAt: Date
    var metadata: [String: String]
    var relations: [KnowledgeRelation]
}

@Model class KnowledgeRelation {
    var id: UUID
    var source: KnowledgeEntity
    var target: KnowledgeEntity
    var description: String
    var keywords: [String]
}

@Model class Document {
    var id: UUID
    var title: String
    var content: String
    var domain: Domain
    var status: DocumentStatus     // pending, processing, processed, failed
    var createdAt: Date
}

@Model class ChatMessage {
    var id: UUID
    var role: MessageRole          // user, assistant, system
    var content: String
    var provider: String           // ollama, openai, anthropic
    var model: String
    var timestamp: Date
    var context: [KnowledgeEntity] // связанные сущности
}

@Model class ProviderConfig {
    var id: UUID
    var providerType: ProviderType // ollama, openai, anthropic
    var apiKey: String?            // reference to Keychain
    var baseURL: String
    var defaultModel: String
    var isEnabled: Bool
    var parameters: [String: String]
}
```

#### 3.1.2 Networking

```swift
// REST-клиент к LightRAG серверу
protocol LightRAGClient {
    func query(_ text: String, mode: SearchMode, topK: Int) async throws -> QueryResult
    func insertText(_ text: String, description: String) async throws -> InsertResult
    func createEntity(_ entity: EntityCreateRequest) async throws -> EntityResponse
    func createRelation(_ relation: RelationCreateRequest) async throws -> RelationResponse
    func deleteEntity(_ name: String) async throws
    func listDocuments(page: Int, pageSize: Int, status: String?) async throws -> DocumentList
    func healthCheck() async throws -> HealthStatus
}

// Реализации
class LocalLightRAGClient: LightRAGClient { ... }   // localhost:9621
class RemoteLightRAGClient: LightRAGClient { ... }   // удалённый сервер
```

#### 3.1.3 Provider Architecture — Разделение по ролям

LightRAG использует модели для **4 независимых задач**. Каждая задача может использовать свой провайдер и свою модель:

```
┌──────────────────────────────────────────────────────────────────┐
│                   LightRAG Processing Pipeline                    │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  INDEXING (Document Insertion):                                    │
│  ┌─────────────┐    ┌──────────────────┐    ┌────────────────┐   │
│  │   Chunking   │───►│ EMBEDDING MODEL  │───►│ Vector Storage │   │
│  │   (local)    │    │ (Role 1)         │    │ (always local) │   │
│  └──────┬───────┘    └──────────────────┘    └────────────────┘   │
│         │                                                          │
│         │            ┌──────────────────┐    ┌────────────────┐   │
│         └───────────►│ LLM EXTRACTION   │───►│ Graph Storage  │   │
│                      │ (Role 2)         │    │ (always local) │   │
│                      │ entities+relations│    └────────────────┘   │
│                      └──────────────────┘                          │
│                                                                   │
│  QUERY (Retrieval + Generation):                                  │
│  ┌─────────────┐    ┌──────────────────┐    ┌────────────────┐   │
│  │  User Query  │───►│ EMBEDDING MODEL  │───►│ Vector Search  │   │
│  └──────────────┘    │ (Role 1, same)   │    └───────┬────────┘   │
│                      └──────────────────┘            │             │
│                                                      ▼             │
│                      ┌──────────────────┐    ┌────────────────┐   │
│                      │ RERANKER         │◄───│ Retrieved      │   │
│                      │ (Role 3, optional)│    │ Chunks+Entities│   │
│                      └────────┬─────────┘    └────────────────┘   │
│                               │                                    │
│                               ▼                                    │
│                      ┌──────────────────┐    ┌────────────────┐   │
│                      │ LLM GENERATION   │───►│ Final Answer   │   │
│                      │ (Role 4)         │    └────────────────┘   │
│                      └──────────────────┘                          │
└──────────────────────────────────────────────────────────────────┘
```

**4 роли моделей (каждая настраивается независимо):**

| Роль | Задача | Требования | Примеры моделей |
|------|--------|-----------|----------------|
| **Embedding** | Векторизация текста | Быстрый, многоязычный, стабильные размерности | bge-m3 (1024d), nomic-embed-text (768d), OpenAI text-embedding-3-small |
| **LLM Extraction** | Извлечение сущностей/связей при индексации | Качество > скорость, минимум 14B+, рекомендован 32B+ | qwen2.5:32b, GPT-4o, DeepSeek-V3 |
| **Reranker** | Переранжирование чанков после retrieval | Опционально, улучшает точность ответов | Jina Reranker API, Cohere Rerank, local BAAI/bge-reranker |
| **LLM Generation** | Генерация ответа из контекста | Баланс скорость/качество, может быть легче extraction | qwen2.5:14b, GPT-4o-mini, Claude Haiku, DeepSeek-V3 |

**Принцип:** Storage всегда локально. Compute — по выбору пользователя.

```swift
// === PROTOCOLS ===

/// Роль 1: Embedding — векторизация текста для поиска
protocol EmbeddingProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var providerType: ProviderType { get }
    var isAvailable: Bool { get async }
    var outputDimension: Int { get }       // 768, 1024, 1536...

    func embed(text: String, model: String) async throws -> [Float]
    func embedBatch(texts: [String], model: String) async throws -> [[Float]]
    func availableModels() async throws -> [EmbeddingModel]
}

/// Роли 2 и 4: LLM — генерация текста (extraction + generation)
protocol LLMProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var providerType: ProviderType { get }
    var isAvailable: Bool { get async }

    func generate(prompt: String, model: String, options: GenerateOptions) async throws -> String
    func generateStream(prompt: String, model: String, options: GenerateOptions) async throws -> AsyncStream<String>
    func availableModels() async throws -> [LLMModel]
}

/// Роль 3: Reranker — переранжирование результатов (опционально)
protocol RerankerProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var isAvailable: Bool { get async }

    func rerank(query: String, documents: [String], topK: Int) async throws -> [RankedDocument]
}

// === MODELS ===

struct EmbeddingModel: Identifiable, Codable {
    let id: String
    let name: String
    let dimension: Int             // 768, 1024, 1536
    let maxTokens: Int
    let multilingual: Bool
    let sizeOnDisk: UInt64?        // nil for cloud models
}

struct LLMModel: Identifiable, Codable {
    let id: String
    let name: String
    let parameterSize: String      // "7B", "14B", "32B"
    let ramEstimate: UInt64?       // bytes, nil for cloud
    let capabilities: Set<ModelCapability>  // .chat, .extraction, .vision
    let contextWindow: Int         // 4096, 8192, 32768, 128000...
}

struct RankedDocument {
    let index: Int
    let score: Float
    let text: String
}

// === PROVIDER REGISTRY — управление всеми провайдерами ===

@Observable
class ProviderRegistry {
    // Registered providers
    private(set) var embeddingProviders: [any EmbeddingProvider] = []
    private(set) var llmProviders: [any LLMProvider] = []
    private(set) var rerankerProviders: [any RerankerProvider] = []

    // Active provider+model for each ROLE (настраивается пользователем)
    var embeddingConfig: RoleConfig      // Role 1: Embedding
    var extractionConfig: RoleConfig     // Role 2: LLM for entity extraction
    var rerankerConfig: RoleConfig?      // Role 3: Reranker (optional)
    var generationConfig: RoleConfig     // Role 4: LLM for answer generation

    struct RoleConfig: Codable {
        var providerID: String           // "ollama", "openai", "deepseek"
        var modelID: String              // "bge-m3", "qwen2.5:32b", "gpt-4o-mini"
        var endpoint: Endpoint           // local, remote-ollama, cloud-api
    }

    enum Endpoint: Codable {
        case local                       // localhost (Ollama)
        case remoteOllama(url: String)   // Ollama на другом сервере
        case cloudAPI(baseURL: String)   // OpenAI, DeepSeek, Anthropic
    }

    // Convenience
    func embeddingProvider() throws -> any EmbeddingProvider { ... }
    func extractionLLM() throws -> any LLMProvider { ... }
    func reranker() -> (any RerankerProvider)? { ... }
    func generationLLM() throws -> any LLMProvider { ... }
}
```

**Типичные конфигурации пользователей:**

| Сценарий | Embedding | Extraction LLM | Reranker | Generation LLM |
|---------|-----------|---------------|----------|---------------|
| **Всё локально (8GB)** | Ollama: nomic-embed-text | Ollama: qwen2.5:7b | — | Ollama: qwen2.5:7b |
| **Всё локально (36GB)** | Ollama: bge-m3 | Ollama: qwen2.5:32b | — | Ollama: qwen2.5:14b |
| **Гибрид (экономный)** | Ollama: bge-m3 | DeepSeek: deepseek-chat | — | Ollama: qwen2.5:14b |
| **Гибрид (качество)** | OpenAI: text-embedding-3-small | OpenAI: gpt-4o | Jina Reranker | Ollama: qwen2.5:14b |
| **Полностью облако** | OpenAI: text-embedding-3-small | OpenAI: gpt-4o | Cohere Rerank | Anthropic: claude-haiku |
| **Remote Ollama** | Remote: bge-m3 @server | Remote: qwen2.5:32b @server | — | Remote: qwen2.5:14b @server |

**ВАЖНО: Смена embedding модели требует полной переиндексации** (старые векторы несовместимы с новыми размерностями). UI должен предупреждать об этом.

#### 3.1.4 Process Manager

```swift
protocol ManagedProcess {
    var processName: String { get }
    var status: ProcessStatus { get async }  // stopped, starting, running, error
    var port: UInt16 { get }

    func start() async throws
    func stop() async throws
    func restart() async throws
    func healthCheck() async throws -> Bool
}

class OllamaProcessManager: ManagedProcess { ... }
class LightRAGProcessManager: ManagedProcess { ... }

// Координатор всех процессов
@Observable
class ServiceOrchestrator {
    var ollama: OllamaProcessManager
    var lightRAG: LightRAGProcessManager
    var overallStatus: SystemStatus

    func startAll() async throws { ... }
    func stopAll() async throws { ... }
    func healthCheckAll() async throws -> [String: Bool] { ... }
}
```

#### 3.1.5 MCP Bridge

```swift
// MCP-сервер: BrainAI выставляет свои знания как MCP tools
// MCP-клиент: BrainAI подключается к удалённому LightRAG через MCP

protocol MCPServer {
    func registerTool(_ tool: MCPTool) async
    func start(transport: MCPTransport) async throws
}

protocol MCPTransport {
    // stdio, SSE, WebSocket
}

// Tools которые BrainAI выставляет:
// - brainai_query(question, mode)
// - brainai_insert(text, description)
// - brainai_create_entity(name, type, description)
// - brainai_create_relation(src, tgt, description)
// - brainai_search(label, text)
```

#### 3.1.6 Security (Keychain)

```swift
actor KeychainManager {
    func save(key: String, value: String, service: String) throws
    func load(key: String, service: String) throws -> String?
    func delete(key: String, service: String) throws

    // Convenience
    func saveAPIKey(_ key: String, for provider: ProviderType) throws
    func loadAPIKey(for provider: ProviderType) throws -> String?
}
```

#### 3.1.7 Configuration

```swift
@Observable
class AppConfiguration {
    // === Storage (всегда локально) ===
    var dataDirectory: URL               // ~/Library/Application Support/BrainAI/
    var workspacesDirectory: URL         // .../workspaces/

    // === Workspaces ===
    var defaultWorkspaceID: UUID?        // Workspace по умолчанию для MCP/API
    var workspaceStartPolicy: WorkspaceStartPolicy = .onDemand
    var workspaceIdleTimeout: TimeInterval = 300  // 5 min

    // === LightRAG Server ===
    var lightRAGMode: ConnectionMode = .local  // .local, .remote
    var lightRAGHost: String = "0.0.0.0"
    var lightRAGPort: UInt16 = 9621
    var remoteServerURL: String = ""
    var remoteAuthToken: String = ""     // → Keychain

    // === Provider Roles (каждая роль — свой провайдер + модель) ===
    var embeddingRole: RoleConfig = .init(
        providerID: "ollama", modelID: "bge-m3",
        endpoint: .local
    )
    var extractionRole: RoleConfig = .init(
        providerID: "ollama", modelID: "qwen2.5:14b",
        endpoint: .local
    )
    var rerankerRole: RoleConfig? = nil  // опционально
    var generationRole: RoleConfig = .init(
        providerID: "ollama", modelID: "qwen2.5:14b",
        endpoint: .local
    )

    // === Ollama (Local) ===
    var ollamaPort: UInt16 = 11434
    var ollamaKeepAlive: KeepAliveDuration = .minutes(5)

    // === Ollama (Remote — на другом сервере) ===
    var remoteOllamaURL: String = ""     // http://192.168.1.100:11434

    // === Cloud Providers ===
    // API keys хранятся в Keychain, здесь только конфиг
    var openAIBaseURL: String = "https://api.openai.com/v1"
    var anthropicBaseURL: String = "https://api.anthropic.com"
    var deepSeekBaseURL: String = "https://api.deepseek.com/v1"

    // === Domains ===
    var enabledDomains: [Domain] = Domain.allCases

    // === UI ===
    var language: AppLanguage = .system
    var theme: AppTheme = .system

    // === Chunking (влияет на качество индексации) ===
    var chunkSize: Int = 1200            // символов на чанк
    var chunkOverlap: Int = 100          // перекрытие между чанками

    // Persistence: UserDefaults + CloudKit (optional sync)
}
```

---

### 3.2 BrainAI Tray (Menu Bar Agent)

Лёгкий процесс, постоянно живёт в menu bar.

#### Функциональность

| Функция | Описание |
|---------|----------|
| Статус сервисов | Иконки: LightRAG (green/red), Ollama (green/red) |
| RAM мониторинг | Цветные прогресс-бары: System RAM, Swap, Ollama RAM |
| Текущая модель | Отображение активной LLM модели и embedding модели |
| Документы | Счётчик документов в базе знаний |
| Quick Actions | Быстрая вставка текста, быстрый вопрос к базе |
| Alerts | Уведомления: сервис упал, swap > 80%, модель загружена |
| Управление | Start/Stop LightRAG, Start/Stop Ollama |
| Навигация | Открыть Main UI, Открыть Settings, Открыть WebUI (browser) |

#### Технические детали

- **NSStatusItem** с custom NSMenu
- **SwiftUI views** внутри NSHostingView для сложных элементов (прогресс-бары)
- **Timer** каждые 15 секунд — poll system stats через `host_statistics64`
- **XPC connection** к BrainAICore service для данных о сервисах
- **Launch at Login** через SMAppService (macOS 13+)
- **Minimal footprint** — target < 20MB RAM

```swift
// Мониторинг системных ресурсов
struct SystemStats {
    let totalRAM: UInt64
    let usedRAM: UInt64
    let swapUsed: UInt64
    let swapTotal: UInt64
    let ollamaRAM: UInt64          // через process info
    let lightRAGRAM: UInt64
    let cpuUsage: Double
}
```

---

### 3.3 BrainAI Settings

Отдельное окно настроек, вызывается из Tray или Main UI.

#### Табы

**General**
- Язык интерфейса (System, English, Русский, Українська)
- Тема (System, Light, Dark)
- Launch at Login toggle
- Auto-start services toggle
- Check for updates

**Providers & Roles**

Два уровня настройки:

*Уровень 1: Провайдеры (источники моделей)*
- Ollama Local: port, path, status
- Ollama Remote: URL сервера, Test Connection
- OpenAI: API key (Keychain), Base URL, Test Connection
- Anthropic: API key (Keychain), Base URL, Test Connection
- DeepSeek: API key (Keychain), Base URL, Test Connection
- Jina AI: API key (для Reranker)
- Cohere: API key (для Reranker)

*Уровень 2: Роли (привязка провайдер+модель к задаче)*
- **Embedding Model**: выбор провайдера → выбор модели → dimension (auto-detect)
  - ⚠️ Предупреждение: смена модели = полная переиндексация!
- **Extraction LLM**: выбор провайдера → выбор модели → параметры (temperature, context window)
  - Подсказка: рекомендуется 32B+ для качества
- **Reranker** (опционально): Enable/Disable → выбор провайдера → top_k
- **Generation LLM**: выбор провайдера → выбор модели → параметры
  - Подсказка: может быть легче extraction (14B достаточно)

Каждая роль показывает: текущий статус (✅ online / ❌ offline), latency, стоимость (для cloud)

**Server**
- LightRAG: host, port, status, Start/Stop/Restart
- Ollama: path, port, status, Start/Stop
- Connection mode: Local / Remote
  - Remote: URL, auth token, Test Connection
- OLLAMA_KEEP_ALIVE dropdown (30s, 1m, 5m, 15m, 30m, forever)

**Models**
- Installed models (pull from Ollama API)
- RAM estimates для каждой
- Pull new model (input + download progress)
- Delete model
- Set as default LLM / default Embedding

**Workspaces**
- Список Workspace'ов: имя, иконка (SF Symbol), цвет, описание
- CRUD: создать (из шаблона или пустой), переименовать, удалить (с подтверждением)
- Для каждого Workspace:
  - Start Policy: Always / On Demand / Manual
  - Provider Roles (override глобальных или свои)
  - Port assignment (auto или manual)
  - Stats: entities, relations, documents, last activity
  - Encryption toggle
  - Export / Import кнопки
  - Status: Running / Stopped / Error
  - Start / Stop / Restart кнопки

**Advanced**
- Data directory path
- Export / Import всей базы знаний
- Reset to defaults
- Debug logging toggle
- Python environment path
- LightRAG graph storage path

---

### 3.4 BrainAI Main UI

Главное приложение — интерфейс работы с базой знаний.

#### Экраны

**Dashboard**
- Статистика: сущности, связи, документы, домены
- Недавняя активность (timeline)
- Quick search bar (Cmd+K)
- Quick insert (Cmd+N)

**Knowledge Graph Viewer**
- Интерактивная визуализация графа (SpriteKit или SceneKit)
- Фильтрация по домену, типу сущности
- Zoom, pan, select node → sidebar с деталями
- Поиск и highlight пути между сущностями
- Force-directed layout

**AI Chat**
- Чат-интерфейс с выбором провайдера/модели
- Контекст из базы знаний автоматически подтягивается (RAG)
- Режимы поиска: local, global, hybrid, naive, mix
- Сохранение ответов в базу знаний (одной кнопкой)
- История чатов

**Semantic Search**
- Полнотекстовый + семантический поиск по графу
- Фильтры: домен, тип сущности, дата, ключевые слова
- Preview результатов с highlight совпадений
- Быстрые действия: открыть, редактировать, удалить, связать

**Notes Editor**
- Markdown-редактор с превью
- Автоматическое извлечение сущностей при сохранении
- Теги, домены, связи с существующими сущностями
- Wiki-links: [[Entity Name]] автоматически связывает

**Documents Manager**
- Список всех документов с фильтрацией по статусу
- Drag & drop для добавления файлов (txt, md, pdf → извлечение текста)
- Batch operations: delete, re-process, export
- Status: pending → processing → processed → failed

#### Навигация

- **Sidebar** (NavigationSplitView): Dashboard, Graph, Chat, Search, Notes, Documents, Settings
- **Cmd+K**: Global spotlight-like search
- **Cmd+N**: Quick note / quick insert
- **Cmd+,**: Settings

---

### 3.5 BrainAI Installer

Отдельное приложение-визард для первоначальной установки.

#### Шаги

**1. Welcome**
- Описание продукта, что будет установлено
- Выбор языка

**2. Components Selection**
- Checkboxes:
  - [x] BrainAI Core (обязательно)
  - [x] LightRAG Server (Python)
  - [x] Ollama (Local LLM)
  - [ ] Sample Knowledge Base (демо-данные)
- Показ требуемого дискового пространства

**3. Provider Setup**
- Выбор основного провайдера:
  - Ollama (local) — будет скачан и установлен
  - OpenAI API — ввод API key
  - Anthropic API — ввод API key
  - Skip (настроить позже)

**4. Model Selection** (если выбран Ollama)
- Рекомендованные модели с учётом RAM:
  - 8GB RAM → qwen2.5:7b
  - 16GB RAM → qwen2.5:14b
  - 32GB+ RAM → qwen2.5:32b
- Embedding model: nomic-embed-text (обязательно)
- Показ размера скачивания

**5. Download & Install**
- Прогресс-бар для каждого компонента:
  - Python environment (если нет)
  - LightRAG + dependencies (pip install)
  - Ollama (brew или прямая загрузка)
  - LLM model (ollama pull)
  - Embedding model (ollama pull)
- Cancel / Retry для каждого шага

**6. Complete**
- Всё установлено, проверка здоровья всех компонентов
- Кнопки: Open BrainAI, Open Settings
- Checkbox: Launch at Login

#### Технические детали

- Определяет установленные компоненты (Ollama, Python, Homebrew)
- Скачивает только недостающее
- Использует `Process` для запуска brew, pip, ollama CLI
- Сохраняет пути и конфигурацию в `AppConfiguration`
- Проверяет совместимость macOS версии (минимум 14.0 Sonoma)

---

### 3.6 Разнесение процессов (Storage vs Compute)

Ключевой архитектурный принцип: **Storage всегда локально, Compute — по выбору.**

#### 3.6.1 Что всегда локально (на машине пользователя)

| Компонент | Расположение | Описание |
|-----------|-------------|----------|
| Graph Storage | `~/Library/Application Support/BrainAI/graph/` | Сущности, связи, метаданные графа |
| Vector Storage | `~/Library/Application Support/BrainAI/vectors/` | Векторные embeddings для поиска |
| Document Store | `~/Library/Application Support/BrainAI/documents/` | Исходные тексты, чанки |
| SwiftData Cache | `~/Library/Application Support/BrainAI/cache.store` | Кэш для UI, история чатов |
| Configuration | UserDefaults + Keychain | Настройки, API-ключи |

Данные никогда не покидают машину пользователя (если он сам не включит sync).

#### 3.6.2 Что может быть удалённым (compute)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Варианты размещения Compute                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Вариант A: Всё локально                                        │
│  ┌──────────────────────────────────────────────────┐           │
│  │ MacBook                                          │           │
│  │  BrainAI UI ◄──► LightRAG Server ◄──► Ollama    │           │
│  │                   (Python)         (LLM+Embed)   │           │
│  │  [Storage: graph + vectors + docs]               │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                  │
│  Вариант B: Remote Ollama (GPU сервер в LAN/VPN)                │
│  ┌──────────────────────┐    ┌──────────────────────┐           │
│  │ MacBook              │    │ GPU Server            │           │
│  │  BrainAI UI          │    │  Ollama (port 11434)  │           │
│  │  LightRAG Server ────┼───►│  qwen2.5:32b          │           │
│  │  [Storage: local]    │ API│  bge-m3               │           │
│  └──────────────────────┘    └──────────────────────┘           │
│                                                                  │
│  Вариант C: Cloud API (OpenAI / DeepSeek / Anthropic)           │
│  ┌──────────────────────┐    ┌──────────────────────┐           │
│  │ MacBook              │    │ Cloud                  │           │
│  │  BrainAI UI          │    │  OpenAI API            │           │
│  │  LightRAG Server ────┼───►│  gpt-4o (extraction)   │           │
│  │  [Storage: local]    │HTTPS│ text-embedding-3-small│           │
│  └──────────────────────┘    └──────────────────────┘           │
│                                                                  │
│  Вариант D: Гибрид (mix local + remote)                         │
│  ┌──────────────────────┐  ┌──────────┐  ┌──────────┐          │
│  │ MacBook              │  │ GPU Srv  │  │ Cloud    │          │
│  │  BrainAI UI          │  │          │  │          │          │
│  │  LightRAG Server     │  │ Ollama   │  │ OpenAI   │          │
│  │  [Storage: local]    │  │ (embed)  │  │ (extrac) │          │
│  │  Ollama (generation) │  │          │  │          │          │
│  └──────────┬───────────┘  └────┬─────┘  └────┬─────┘          │
│             │ local              │ LAN         │ HTTPS          │
│             └────────────────────┴─────────────┘                │
│                                                                  │
│  Вариант E: Remote LightRAG (всё на сервере, клиент тонкий)    │
│  ┌──────────────────────┐    ┌──────────────────────┐           │
│  │ MacBook (thin client)│    │ Server               │           │
│  │  BrainAI UI          │    │  LightRAG Server     │           │
│  │  BrainAI Tray   ─────┼───►│  Ollama              │           │
│  │  [NO local storage]  │REST│  [Storage: on server] │           │
│  │                      │/MCP│                       │           │
│  └──────────────────────┘    └──────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

#### 3.6.3 Как LightRAG работает с remote провайдерами

LightRAG (Python) поддерживает конфигурацию провайдеров через `.env` / API:

```env
# Embedding — Role 1
EMBEDDING_PROVIDER=ollama_remote       # ollama, ollama_remote, openai, deepseek
EMBEDDING_MODEL=bge-m3
EMBEDDING_DIM=1024
EMBEDDING_API_BASE=http://192.168.1.100:11434  # для remote ollama

# LLM Extraction — Role 2
EXTRACTION_PROVIDER=openai
EXTRACTION_MODEL=gpt-4o
EXTRACTION_API_KEY=sk-...              # из Keychain через Swift → env

# Reranker — Role 3 (optional)
RERANKER_ENABLED=true
RERANKER_PROVIDER=jina
RERANKER_API_KEY=jina_...

# LLM Generation — Role 4
GENERATION_PROVIDER=ollama
GENERATION_MODEL=qwen2.5:14b
# (local ollama, default port)
```

**Swift-клиент (BrainAICore)** при запуске LightRAG server:
1. Читает `ProviderRegistry` из `AppConfiguration`
2. Генерирует `.env` файл с нужными параметрами
3. Инжектит API-ключи из Keychain в environment variables процесса
4. Запускает LightRAG server как child process с этим environment

Таким образом API-ключи **никогда не хранятся в файлах** — только в Keychain и в памяти процесса.

---

### 3.7 Multi-Workspace (несколько баз знаний)

Вместо одного LightRAG instance с доменами — **несколько изолированных Workspace**, каждый со своим LightRAG, хранилищем и конфигурацией провайдеров.

#### 3.7.1 Зачем

| Проблема одного instance | Решение с Workspaces |
|-------------------------|---------------------|
| Рабочие данные смешиваются с личными | Полная изоляция данных |
| Один набор провайдеров на всё | Свои провайдеры на каждый Workspace |
| Нельзя расшарить только часть базы | Work KB расшарить команде, Personal оставить приватным |
| Один размер модели на все задачи | Work: cloud API (качество), Hobby: local (бесплатно) |
| Бэкап всё-или-ничего | Гранулярный бэкап/экспорт по Workspace |
| При повреждении теряется всё | Изоляция повреждений |

#### 3.7.2 Архитектура

```
~/Library/Application Support/BrainAI/
├── workspaces.json                      # Реестр Workspace'ов
├── global/                              # Глобальные настройки
│   └── config.plist
│
├── workspaces/
│   ├── work/                            # Workspace: Work
│   │   ├── workspace.json               # Метаданные, провайдеры, порт
│   │   ├── graph/                       # Graph Storage
│   │   ├── vectors/                     # Vector Storage
│   │   ├── documents/                   # Document Store
│   │   └── .env                         # LightRAG config (generated)
│   │
│   ├── personal/                        # Workspace: Personal
│   │   ├── workspace.json
│   │   ├── graph/
│   │   ├── vectors/
│   │   ├── documents/
│   │   └── .env
│   │
│   ├── hobby-esp32/                     # Workspace: ESP32 Hobby
│   │   └── ...
│   │
│   └── hobby-automotive/               # Workspace: Automotive
│       └── ...
```

#### 3.7.3 Workspace Model

```swift
struct Workspace: Identifiable, Codable {
    let id: UUID
    var name: String                     // "Work", "Personal", "ESP32"
    var slug: String                     // "work", "personal", "hobby-esp32"
    var icon: String                     // SF Symbol name
    var color: String                    // hex color
    var description: String

    // LightRAG instance config
    var port: UInt16                     // 9621, 9622, 9623...
    var dataPath: URL                    // ~/...BrainAI/workspaces/{slug}/

    // Provider roles (override global or set per-workspace)
    var embeddingRole: RoleConfig?       // nil = use global default
    var extractionRole: RoleConfig?
    var rerankerRole: RoleConfig?
    var generationRole: RoleConfig?

    // Access control
    var isEncrypted: Bool                // шифрование хранилища
    var isShared: Bool                   // расшарен ли для команды
    var shareEndpoint: String?           // URL для remote access

    // Stats (cached)
    var entityCount: Int
    var relationCount: Int
    var documentCount: Int
    var lastActivity: Date

    var isRunning: Bool                  // LightRAG instance status
}

// Реестр всех Workspace'ов
@Observable
class WorkspaceManager {
    var workspaces: [Workspace] = []
    var activeWorkspace: Workspace?      // текущий в UI

    // Process management — каждый Workspace = свой LightRAG process
    private var processes: [UUID: LightRAGProcessManager] = [:]

    func create(name: String, template: WorkspaceTemplate?) async throws -> Workspace
    func delete(id: UUID) async throws    // с подтверждением
    func start(id: UUID) async throws     // запуск LightRAG instance
    func stop(id: UUID) async throws
    func startAll() async throws          // при запуске приложения

    // Cross-workspace query
    func queryAll(question: String, mode: SearchMode) async throws -> [WorkspaceQueryResult]
    func queryWorkspaces(_ ids: [UUID], question: String) async throws -> [WorkspaceQueryResult]
}

struct WorkspaceQueryResult {
    let workspace: Workspace
    let result: QueryResult
    let relevanceScore: Float
}
```

#### 3.7.4 Управление процессами

Каждый Workspace запускает свой LightRAG server на отдельном порту:

```
Workspace "Work"      → LightRAG :9621  → Ollama/OpenAI (extraction: gpt-4o)
Workspace "Personal"  → LightRAG :9622  → Ollama local  (extraction: qwen2.5:14b)
Workspace "ESP32"     → LightRAG :9623  → Ollama local  (extraction: qwen2.5:14b)
Workspace "Automotive" → LightRAG :9624  → DeepSeek API  (extraction: deepseek-chat)
```

**Оптимизация RAM**: не все Workspace должны быть запущены одновременно.

```swift
enum WorkspaceStartPolicy: Codable {
    case always                  // запускать при старте приложения
    case onDemand                // запускать при обращении, останавливать через N минут
    case manual                  // только вручную
}
```

**Lazy start**: Workspace в режиме `onDemand` запускается при первом запросе и останавливается после `idleTimeout` (по умолчанию 5 минут без запросов). Это экономит RAM — одновременно работает только то, что нужно.

#### 3.7.5 Cross-Workspace Query

Поиск по нескольким базам одновременно:

```
User: "где я видел про I2C протокол?"

→ Query "work"      → 2 results (score: 0.3, 0.2)
→ Query "esp32"     → 5 results (score: 0.9, 0.8, 0.7, 0.5, 0.4)
→ Query "automotive" → 1 result  (score: 0.6)

→ Merged & ranked:
  1. [ESP32]      I2C sensor configuration     (0.9)
  2. [ESP32]      I2C bus wiring diagram        (0.8)
  3. [ESP32]      BME280 I2C address conflict   (0.7)
  4. [Automotive] OBD-II I2C adapter setup      (0.6)
  5. [ESP32]      Multi-device I2C bus          (0.5)
  ...
```

UI показывает результаты с цветной меткой Workspace (цвет и иконка).

#### 3.7.6 Workspace Templates

Предустановленные шаблоны для быстрого создания:

| Template | Провайдеры по умолчанию | Домены |
|----------|------------------------|--------|
| **Work** | Cloud API (OpenAI/Anthropic) | architecture, api, meeting, convention |
| **Personal** | Local Ollama | preference, personal |
| **Hobby (Hardware)** | Local Ollama | hardware, snippet, protocol |
| **Research** | Hybrid (local embed + cloud LLM) | research, resource |
| **Custom** | Inherit from global | user-defined |

#### 3.7.7 MCP: Multi-Workspace Tools

Для внешних агентов (Cursor, Cowork) — MCP tools с указанием Workspace:

```
brainai_query(question, workspace="work", mode="hybrid")
brainai_query(question, workspace="all", mode="hybrid")     // cross-query
brainai_insert(text, description, workspace="personal")
brainai_list_workspaces()
```

Обратная совместимость: если `workspace` не указан — используется `activeWorkspace` или `default`.

#### 3.7.8 Миграция с текущей системы доменов

Текущая BrainAI использует домены (work, personal-project, hobby-esp32...) в одном LightRAG instance. Путь миграции:

1. Installer определяет существующую базу
2. Предлагает: "Оставить как один Workspace" или "Разбить по доменам"
3. Если разбить — фильтрует документы по domain prefix в description, копирует в отдельные Workspace'ы
4. Переиндексирует каждый Workspace отдельно

---

### 3.8 Remote Monitoring Mode

Режим работы, когда LightRAG запущен на удалённом сервере.

#### Сценарий

```
┌──────────────────┐         REST API / MCP         ┌──────────────────┐
│  MacBook (Client) │ ◄──────────────────────────► │  Server (Remote)  │
│                    │                               │                    │
│  BrainAI Tray      │         Health, Stats         │  LightRAG          │
│  BrainAI UI        │         Query, Insert         │  Ollama            │
│  BrainAI Settings  │         MCP Tools             │  GPU-accelerated   │
└──────────────────┘                               └──────────────────┘
```

#### Функциональность

- **Connection mode** в Settings: Local ↔ Remote (toggle)
- **Remote config**: URL, Auth token (Bearer), TLS verification
- **Health monitoring**: ping удалённого сервера, latency display
- **MCP bridge**: BrainAI выступает MCP-клиентом к удалённому MCP-серверу
- **Fallback**: если remote недоступен — уведомление + опция переключиться на local
- **Sync** (future): двусторонняя синхронизация между local и remote базами

#### REST API Endpoints (серверная часть)

```
GET  /health                          → status, uptime, models
GET  /api/graph/entity/{name}         → entity details
POST /api/query                       → RAG query
POST /api/documents/text              → insert text
POST /api/graph/entity                → create entity
POST /api/graph/relation              → create relation
GET  /api/documents                   → list documents
GET  /api/stats                       → entities count, relations count, docs count
GET  /api/system                      → RAM, CPU, GPU, model loaded
```

#### Bearer Auth

```swift
class RemoteLightRAGClient: LightRAGClient {
    let baseURL: URL
    let authToken: String           // Stored in Keychain

    func addAuth(to request: inout URLRequest) {
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    }
}
```

---

## 4. Технологический стек

### 4.1 Swift / Apple

| Технология | Применение | Минимальная версия |
|-----------|-----------|-------------------|
| Swift 5.10+ | Язык | - |
| SwiftUI | UI для Settings, Main App, Installer | macOS 14+ |
| AppKit | Tray app (NSStatusItem, NSMenu) | macOS 14+ |
| SwiftData | Локальное хранилище, кэш, метаданные | macOS 14+ |
| Swift Concurrency | async/await, actors, structured concurrency | macOS 14+ |
| Combine | Reactive bindings где нужно | macOS 14+ |
| SpriteKit / SceneKit | Визуализация графа знаний | macOS 14+ |
| SMAppService | Launch at Login | macOS 13+ |
| Network.framework | Low-level networking, WebSocket | macOS 14+ |
| Security.framework | Keychain access | macOS 14+ |
| XPC | Inter-process communication | macOS 14+ |
| OSLog | Structured logging | macOS 14+ |
| Swift Package Manager | Dependency management | - |

### 4.2 External Dependencies (SPM)

| Package | Назначение |
|---------|-----------|
| [Sparkle](https://github.com/sparkle-project/Sparkle) | Auto-update (open source фаза) |
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | Keychain wrapper |
| [SwiftSoup](https://github.com/scinfu/SwiftSoup) | HTML parsing (для document import) |
| [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) | Markdown rendering в SwiftUI |
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) | CLI tools |

### 4.3 Backend (Bundled)

| Технология | Версия | Назначение |
|-----------|--------|-----------|
| Python | 3.11+ | Runtime для LightRAG |
| LightRAG | 1.4.14+ | Граф знаний, RAG engine |
| FastAPI | latest | REST API сервер |
| uvicorn | latest | ASGI server |
| Ollama | latest | Локальный LLM runtime |

### 4.4 Минимальные требования

| Параметр | Минимум | Рекомендуется |
|---------|---------|--------------|
| macOS | 14.0 Sonoma | 15.0+ |
| RAM | 8 GB | 16-36 GB |
| Disk | 5 GB (без моделей) | 30+ GB (с моделями) |
| CPU | Apple Silicon (M1+) | M3 Pro+ |
| Intel | Поддерживается* | Apple Silicon preferred |

*Intel: Ollama работает без GPU acceleration, медленнее.

---

## 5. Безопасность и приватность

### 5.1 Принципы

- **Все данные локально** по умолчанию
- **API ключи** только в macOS Keychain (зашифровано аппаратно)
- **Никакой телеметрии** без явного opt-in
- **Никаких облачных зависимостей** для core функциональности
- **App Sandbox** готовность (для App Store)

### 5.2 Keychain Usage

```
Service: "com.brainai.providers"
  Key: "openai-api-key"       → sk-...
  Key: "anthropic-api-key"    → sk-ant-...
  Key: "remote-auth-token"    → bearer token

Service: "com.brainai.config"
  Key: "encryption-key"       → for local DB encryption (future)
```

### 5.3 Network Policy

- Local mode: никаких исходящих соединений (кроме Ollama localhost)
- Cloud provider mode: только HTTPS к API провайдера
- Remote mode: только HTTPS к указанному серверу
- Никакого phoning home, analytics, crash reporting без opt-in

---

## 6. Фазы разработки

### 6.1 Phase 1 — Foundation (4-6 недель)

**Цель:** рабочий скелет всех модулей, базовая функциональность

- [ ] Структура репозитория, SPM packages, CI/CD (GitHub Actions)
- [ ] BrainAICore: Models, Configuration, Keychain
- [ ] BrainAICore: LightRAGClient (local REST)
- [ ] BrainAICore: OllamaProvider
- [ ] BrainAICore: ProcessManager (start/stop Ollama, LightRAG)
- [ ] BrainAI Tray: статус сервисов, RAM мониторинг, start/stop
- [ ] BrainAI Settings: General, Providers, Server табы (базовый)
- [ ] Тесты: Core networking, provider protocol

### 6.2 Phase 2 — Main UI (4-6 недель)

**Цель:** основной интерфейс работы с базой знаний

- [ ] BrainAI Main UI: Dashboard, Search, Documents Manager
- [ ] BrainAI Main UI: AI Chat с RAG-контекстом
- [ ] BrainAI Main UI: Notes editor с markdown
- [ ] BrainAICore: OpenAIProvider, AnthropicProvider
- [ ] BrainAI Settings: Models, Domains, Advanced табы
- [ ] XPC service для IPC между Tray ↔ Main UI ↔ Settings
- [ ] Тесты: UI snapshot tests, integration tests

### 6.3 Phase 3 — Graph & Installer (3-4 недели)

**Цель:** визуализация графа, инсталлятор

- [ ] BrainAI Main UI: Knowledge Graph Viewer (SpriteKit)
- [ ] BrainAI Installer: полный визард с загрузкой компонентов
- [ ] Sparkle auto-update интеграция
- [ ] Code signing, notarization pipeline
- [ ] Документация: README, SETUP, ARCHITECTURE

### 6.4 Phase 4 — Remote & MCP (3-4 недели)

**Цель:** удалённые подключения, MCP-мост

- [ ] BrainAICore: RemoteLightRAGClient
- [ ] BrainAICore: MCPBridge (server + client)
- [ ] Remote monitoring в Tray и Settings
- [ ] Bearer auth, TLS pinning
- [ ] Тесты: remote connection, MCP protocol

### 6.5 Phase 5 — Polish & Release (2-3 недели)

**Цель:** полировка для публичного релиза

- [ ] Локализация (en, ru, uk)
- [ ] Accessibility (VoiceOver, keyboard navigation)
- [ ] Performance profiling (Instruments)
- [ ] DMG installer packaging
- [ ] Landing page, documentation site
- [ ] GitHub Release v1.0.0

---

## 7. Расширения (Post-MVP)

Архитектура заложена, но реализация в будущих версиях:

| Фича | Описание | Приоритет |
|------|----------|-----------|
| iOS/iPadOS companion | Поиск и чат с базой знаний с телефона | High |
| iCloud Sync | Синхронизация конфига и метаданных между устройствами | High |
| Plugins system | Расширения для импорта (Notion, Obsidian, Telegram) | High |
| watchOS | Quick query с часов через Siri/voice | Medium |
| Shortcuts integration | macOS Shortcuts actions для автоматизаций | Medium |
| Spotlight integration | Поиск по BrainAI через системный Spotlight | Medium |
| Widget (Notification Center) | Статус сервисов, quick search widget | Medium |
| Share Extension | Share text/URL из любого приложения → BrainAI | Medium |
| Local-Remote sync | Двусторонняя синхронизация баз знаний | Medium |
| Multi-user | Shared knowledge bases (team mode) | Low |
| visionOS | Spatial knowledge graph visualization | Low |
| App Store release | Sandbox compliance, in-app purchases | Low |

---

## 8. Метрики успеха

### 8.1 Технические

- Запуск Tray app < 1 сек
- Startup Main UI < 2 сек
- Поисковый запрос < 3 сек (local), < 5 сек (remote)
- RAM footprint: Tray < 20 MB, Main UI < 100 MB (без моделей)
- 0 crashes в стабильной версии

### 8.2 Продуктовые (Alpha)

- Полная замена текущего Python tray app
- Полная замена React WebUI
- Работа с базой знаний не хуже текущего решения
- Installer устанавливает всё с нуля за < 10 минут

---

## 9. Открытые вопросы

1. **Graph visualization library** — SpriteKit vs custom Metal vs порт D3-force на Swift?
2. **Python bundling** — embedded Python runtime или системный Python с venv?
3. **App Sandbox** — ограничения для App Store vs полная функциональность для прямого распространения
4. **Database encryption** — нужен ли шифрование SwiftData store?
5. **CI/CD** — GitHub Actions или Xcode Cloud?

---

*Документ является живым и обновляется по мере развития проекта.*
