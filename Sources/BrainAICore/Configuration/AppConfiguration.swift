import Foundation
import Observation

// MARK: - App Language

/// Supported application languages
public enum AppLanguage: String, Codable, Sendable, Hashable, CaseIterable {
    case system
    case en
    case ru
    case uk
    case de
    case fr
    case it
    case es
    case pl
    /// Simplified Chinese (matches `zh-Hans.lproj`).
    case zhHans = "zh-Hans"
    case ja
}

// MARK: - App Theme

/// Supported application themes
public enum AppTheme: String, Codable, Sendable, Hashable, CaseIterable {
    case system
    case light
    case dark
}

// MARK: - App Configuration

/// Main application configuration
///
/// This class manages all application-level settings including workspace configuration,
/// provider endpoints, and UI preferences. Settings are persisted to UserDefaults.
@Observable
public final class AppConfiguration: @unchecked Sendable {
    // MARK: - Workspace Settings

    /// Directory where workspaces are stored
    public var workspacesDirectory: URL {
        didSet {
            saveToUserDefaults()
        }
    }

    /// ID of the default workspace to open on startup
    public var defaultWorkspaceID: String {
        didSet {
            saveToUserDefaults()
        }
    }

    /// Policy for starting the workspace on app launch
    public var workspaceStartPolicy: WorkspaceStartPolicy {
        didSet {
            saveToUserDefaults()
        }
    }

    /// Time in seconds before an idle workspace is unloaded
    public var workspaceIdleTimeout: TimeInterval {
        didSet {
            saveToUserDefaults()
        }
    }

    // MARK: - Provider Roles

    /// Configuration for embedding role
    public var embeddingRole: RoleConfig {
        didSet {
            saveToUserDefaults()
        }
    }

    /// Configuration for extraction role
    public var extractionRole: RoleConfig {
        didSet {
            saveToUserDefaults()
        }
    }

    /// Configuration for reranking role (optional)
    public var rerankerRole: RoleConfig? {
        didSet {
            saveToUserDefaults()
        }
    }

    /// Configuration for text generation role
    public var generationRole: RoleConfig {
        didSet {
            saveToUserDefaults()
        }
    }

    // MARK: - Ollama Settings

    /// Port for local Ollama server
    public var ollamaPort: Int {
        didSet {
            saveToUserDefaults()
        }
    }

    /// Keep-alive duration for Ollama API
    public var ollamaKeepAlive: KeepAliveDuration {
        didSet {
            saveToUserDefaults()
        }
    }

    /// URL for remote Ollama instance (if using remote)
    public var remoteOllamaURL: URL? {
        didSet {
            saveToUserDefaults()
        }
    }

    // MARK: - Cloud Provider Settings

    /// Base URL for OpenAI API
    public var openAIBaseURL: URL? {
        didSet {
            saveToUserDefaults()
        }
    }

    /// Base URL for Anthropic API
    public var anthropicBaseURL: URL? {
        didSet {
            saveToUserDefaults()
        }
    }

    /// Base URL for DeepSeek API
    public var deepSeekBaseURL: URL? {
        didSet {
            saveToUserDefaults()
        }
    }

    // MARK: - UI Settings

    /// Application language
    public var language: AppLanguage {
        didSet {
            saveToUserDefaults()
        }
    }

    /// Application theme
    public var theme: AppTheme {
        didSet {
            saveToUserDefaults()
        }
    }

    // MARK: - Knowledge Graph Settings

    /// Chunk size for document processing
    public var chunkSize: Int {
        didSet {
            saveToUserDefaults()
        }
    }

    /// Overlap between chunks for context preservation
    public var chunkOverlap: Int {
        didSet {
            saveToUserDefaults()
        }
    }

    // MARK: - Private Properties

    /// Recursive: `loadFromUserDefaults()` holds the lock while assigning properties; each `didSet`
    /// calls `saveToUserDefaults()`, which must re-enter the same lock on the main thread (non-recursive `NSLock` deadlocks).
    private let lock = NSRecursiveLock()

    // MARK: - Initialization

    private init() {
        let defaultWorkspacesDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrainAI/Workspaces", isDirectory: true)

        self.workspacesDirectory = defaultWorkspacesDir
        self.defaultWorkspaceID = ""
        self.workspaceStartPolicy = .onDemand
        self.workspaceIdleTimeout = 3600 // 1 hour

        self.embeddingRole = RoleConfig(
            providerID: "ollama",
            modelID: LightRAGLocalePreset.defaultEmbeddingModelIDForSystemLocale(),
            endpoint: .local
        )
        self.extractionRole = RoleConfig(
            providerID: "ollama",
            modelID: LightRAGLocalePreset.defaultOllamaChatModelID,
            endpoint: .local
        )
        self.rerankerRole = nil
        self.generationRole = RoleConfig(
            providerID: "ollama",
            modelID: LightRAGLocalePreset.defaultOllamaChatModelID,
            endpoint: .local
        )

        self.ollamaPort = 11434
        self.ollamaKeepAlive = .forever
        self.remoteOllamaURL = nil

        self.openAIBaseURL = nil
        self.anthropicBaseURL = nil
        self.deepSeekBaseURL = nil

        self.language = .system
        self.theme = .system

        self.chunkSize = LightRAGLocalePreset.defaultChunkSize
        self.chunkOverlap = LightRAGLocalePreset.defaultChunkOverlap

        loadFromUserDefaults()
    }

    // MARK: - Singleton Access

    /// Shared singleton instance
    public static let shared = AppConfiguration()

    // MARK: - Persistence

    private func saveToUserDefaults() {
        lock.lock()
        defer { lock.unlock() }

        let encoder = JSONEncoder()
        let defaults = UserDefaults.standard

        do {
            defaults.set(workspacesDirectory.absoluteString, forKey: Key.workspacesDirectory.rawValue)
            defaults.set(defaultWorkspaceID, forKey: Key.defaultWorkspaceID.rawValue)
            defaults.set(workspaceStartPolicy.rawValue, forKey: Key.workspaceStartPolicy.rawValue)
            defaults.set(workspaceIdleTimeout, forKey: Key.workspaceIdleTimeout.rawValue)

            let embeddingData = try encoder.encode(embeddingRole)
            defaults.set(embeddingData, forKey: Key.embeddingRole.rawValue)

            let extractionData = try encoder.encode(extractionRole)
            defaults.set(extractionData, forKey: Key.extractionRole.rawValue)

            if let rerankerRole {
                let rerankerData = try encoder.encode(rerankerRole)
                defaults.set(rerankerData, forKey: Key.rerankerRole.rawValue)
            } else {
                defaults.removeObject(forKey: Key.rerankerRole.rawValue)
            }

            let generationData = try encoder.encode(generationRole)
            defaults.set(generationData, forKey: Key.generationRole.rawValue)

            defaults.set(ollamaPort, forKey: Key.ollamaPort.rawValue)
            defaults.set(ollamaKeepAlive.rawValue, forKey: Key.ollamaKeepAlive.rawValue)

            if let remoteOllamaURL {
                defaults.set(remoteOllamaURL.absoluteString, forKey: Key.remoteOllamaURL.rawValue)
            } else {
                defaults.removeObject(forKey: Key.remoteOllamaURL.rawValue)
            }

            if let openAIBaseURL {
                defaults.set(openAIBaseURL.absoluteString, forKey: Key.openAIBaseURL.rawValue)
            } else {
                defaults.removeObject(forKey: Key.openAIBaseURL.rawValue)
            }

            if let anthropicBaseURL {
                defaults.set(anthropicBaseURL.absoluteString, forKey: Key.anthropicBaseURL.rawValue)
            } else {
                defaults.removeObject(forKey: Key.anthropicBaseURL.rawValue)
            }

            if let deepSeekBaseURL {
                defaults.set(deepSeekBaseURL.absoluteString, forKey: Key.deepSeekBaseURL.rawValue)
            } else {
                defaults.removeObject(forKey: Key.deepSeekBaseURL.rawValue)
            }

            defaults.set(language.rawValue, forKey: Key.language.rawValue)
            defaults.set(theme.rawValue, forKey: Key.theme.rawValue)

            defaults.set(chunkSize, forKey: Key.chunkSize.rawValue)
            defaults.set(chunkOverlap, forKey: Key.chunkOverlap.rawValue)
        } catch {
            print("Failed to save AppConfiguration to UserDefaults: \(error)")
        }
    }

    private func loadFromUserDefaults() {
        lock.lock()
        defer { lock.unlock() }

        let decoder = JSONDecoder()
        let defaults = UserDefaults.standard

        // Workspace settings
        if let urlString = defaults.string(forKey: Key.workspacesDirectory.rawValue) {
            workspacesDirectory = URL(string: urlString) ?? workspacesDirectory
        }

        defaultWorkspaceID = defaults.string(forKey: Key.defaultWorkspaceID.rawValue) ?? ""

        if let policyString = defaults.string(forKey: Key.workspaceStartPolicy.rawValue) {
            workspaceStartPolicy = WorkspaceStartPolicy(rawValue: policyString) ?? .onDemand
        }

        workspaceIdleTimeout = defaults.double(forKey: Key.workspaceIdleTimeout.rawValue)
        if workspaceIdleTimeout == 0 {
            workspaceIdleTimeout = 3600
        }

        // Provider roles
        if let embeddingData = defaults.data(forKey: Key.embeddingRole.rawValue) {
            if let role = try? decoder.decode(RoleConfig.self, from: embeddingData) {
                embeddingRole = role
            }
        }

        if let extractionData = defaults.data(forKey: Key.extractionRole.rawValue) {
            if let role = try? decoder.decode(RoleConfig.self, from: extractionData) {
                extractionRole = role
            }
        }

        if let rerankerData = defaults.data(forKey: Key.rerankerRole.rawValue) {
            if let role = try? decoder.decode(RoleConfig.self, from: rerankerData) {
                rerankerRole = role
            }
        }

        if let generationData = defaults.data(forKey: Key.generationRole.rawValue) {
            if let role = try? decoder.decode(RoleConfig.self, from: generationData) {
                generationRole = role
            }
        }

        // Ollama settings
        ollamaPort = defaults.integer(forKey: Key.ollamaPort.rawValue)
        if ollamaPort == 0 {
            ollamaPort = 11434
        }

        if let keepAliveStr = defaults.string(forKey: Key.ollamaKeepAlive.rawValue) {
            // rawValue is a string like "5m", "30s", "-1" — wrap in JSON string for decoder
            let jsonStr = "\"\(keepAliveStr)\""
            if let data = jsonStr.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(KeepAliveDuration.self, from: data) {
                ollamaKeepAlive = decoded
            }
        }

        if let urlString = defaults.string(forKey: Key.remoteOllamaURL.rawValue) {
            remoteOllamaURL = URL(string: urlString)
        }

        // Cloud provider settings
        if let urlString = defaults.string(forKey: Key.openAIBaseURL.rawValue) {
            openAIBaseURL = URL(string: urlString)
        }

        if let urlString = defaults.string(forKey: Key.anthropicBaseURL.rawValue) {
            anthropicBaseURL = URL(string: urlString)
        }

        if let urlString = defaults.string(forKey: Key.deepSeekBaseURL.rawValue) {
            deepSeekBaseURL = URL(string: urlString)
        }

        // UI settings
        if let languageStr = defaults.string(forKey: Key.language.rawValue) {
            language = AppLanguage(rawValue: languageStr) ?? .system
        }

        if let themeStr = defaults.string(forKey: Key.theme.rawValue) {
            theme = AppTheme(rawValue: themeStr) ?? .system
        }

        // Knowledge graph settings
        chunkSize = defaults.integer(forKey: Key.chunkSize.rawValue)
        if chunkSize == 0 {
            chunkSize = LightRAGLocalePreset.defaultChunkSize
        }

        chunkOverlap = defaults.integer(forKey: Key.chunkOverlap.rawValue)
        if chunkOverlap == 0 {
            chunkOverlap = LightRAGLocalePreset.defaultChunkOverlap
        }
    }

    // MARK: - Manual Save

    /// Manually save configuration to UserDefaults
    public func save() {
        saveToUserDefaults()
    }

    // MARK: - LightRAG server (env presets)

    /// Value for LightRAG `SUMMARY_LANGUAGE`, derived from app language (see `LightRAGLocalePreset`).
    public var lightRAGSummaryLanguage: String {
        LightRAGLocalePreset.summaryLanguage(for: language)
    }

    /// Environment variables merged into the LightRAG server process (with later overrides winning).
    /// Universal: `SUMMARY_LANGUAGE` (from UI locale), chunking, graph cap, listen address.
    /// Ollama-specific keys are added only when **both** generation and embedding roles use the `ollama` provider.
    public func lightRAGServerEnvironment(port: UInt16) -> [String: String] {
        var env: [String: String] = [
            "HOST": "0.0.0.0",
            "PORT": "\(port)",
            "LIGHTRAG_PORT": "\(port)",
            "SUMMARY_LANGUAGE": lightRAGSummaryLanguage,
            "CHUNK_SIZE": "\(chunkSize)",
            "CHUNK_OVERLAP": "\(chunkOverlap)",
            "MAX_GRAPH_NODES": "5000",
        ]

        if generationRole.providerID == ProviderType.ollama.rawValue {
            env["OLLAMA_KEEP_ALIVE"] = ollamaKeepAlive.rawValue
        }

        let ollamaLLM = generationRole.providerID == ProviderType.ollama.rawValue
        let ollamaEmb = embeddingRole.providerID == ProviderType.ollama.rawValue
        if ollamaLLM, ollamaEmb {
            let ollamaHost: String
            if let remote = remoteOllamaURL {
                var s = remote.absoluteString
                while s.hasSuffix("/") { s.removeLast() }
                ollamaHost = s
            } else {
                ollamaHost = "http://127.0.0.1:\(ollamaPort)"
            }
            env["LLM_BINDING"] = "ollama"
            env["LLM_BINDING_HOST"] = ollamaHost
            env["EMBEDDING_BINDING"] = "ollama"
            env["EMBEDDING_BINDING_HOST"] = ollamaHost
            env["LLM_MODEL"] = generationRole.modelID
            env["EMBEDDING_MODEL"] = embeddingRole.modelID
            env["MAX_ASYNC"] = "4"
            env["MAX_PARALLEL_INSERT"] = "2"
            env["LLM_TIMEOUT"] = "300"
            env["EMBEDDING_TIMEOUT"] = "300"
            env["OLLAMA_LLM_NUM_CTX"] = "32768"
            env["OLLAMA_EMBEDDING_NUM_CTX"] = "8192"

            let mid = embeddingRole.modelID.lowercased()
            if mid.contains("bge-m3") || mid.contains("bge_m3") {
                env["EMBEDDING_DIM"] = "1024"
            } else if mid.contains("nomic") {
                env["EMBEDDING_DIM"] = "768"
            }
        }

        return env
    }

    // MARK: - UserDefaults Keys

    private enum Key: String {
        case workspacesDirectory
        case defaultWorkspaceID
        case workspaceStartPolicy
        case workspaceIdleTimeout

        case embeddingRole
        case extractionRole
        case rerankerRole
        case generationRole

        case ollamaPort
        case ollamaKeepAlive
        case remoteOllamaURL

        case openAIBaseURL
        case anthropicBaseURL
        case deepSeekBaseURL

        case language
        case theme

        case chunkSize
        case chunkOverlap
    }
}
