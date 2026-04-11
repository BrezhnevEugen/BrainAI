import Foundation
import Observation

// MARK: - ProviderRegistry

/// Registry for managing providers and active configurations
@Observable
public final class ProviderRegistry: @unchecked Sendable {
    public var embeddingProviders: [any EmbeddingProvider]
    public var llmProviders: [any LLMProvider]
    public var rerankerProviders: [any RerankerProvider]

    public var embeddingConfig: RoleConfig?
    public var extractionConfig: RoleConfig?
    public var rerankerConfig: RoleConfig?
    public var generationConfig: RoleConfig?

    private let lock = NSLock()

    /// Initialize a provider registry
    public init(
        embeddingProviders: [any EmbeddingProvider] = [],
        llmProviders: [any LLMProvider] = [],
        rerankerProviders: [any RerankerProvider] = [],
        embeddingConfig: RoleConfig? = nil,
        extractionConfig: RoleConfig? = nil,
        rerankerConfig: RoleConfig? = nil,
        generationConfig: RoleConfig? = nil
    ) {
        self.embeddingProviders = embeddingProviders
        self.llmProviders = llmProviders
        self.rerankerProviders = rerankerProviders
        self.embeddingConfig = embeddingConfig
        self.extractionConfig = extractionConfig
        self.rerankerConfig = rerankerConfig
        self.generationConfig = generationConfig
    }

    /// Register an embedding provider
    /// - Parameter provider: The embedding provider to register
    public func register(embedding provider: any EmbeddingProvider) {
        lock.lock()
        defer { lock.unlock() }

        embeddingProviders.removeAll { $0.id == provider.id }
        embeddingProviders.append(provider)
    }

    /// Register an LLM provider
    /// - Parameter provider: The LLM provider to register
    public func register(llm provider: any LLMProvider) {
        lock.lock()
        defer { lock.unlock() }

        llmProviders.removeAll { $0.id == provider.id }
        llmProviders.append(provider)
    }

    /// Register a reranker provider
    /// - Parameter provider: The reranker provider to register
    public func register(reranker provider: any RerankerProvider) {
        lock.lock()
        defer { lock.unlock() }

        rerankerProviders.removeAll { $0.id == provider.id }
        rerankerProviders.append(provider)
    }

    /// Get the active embedding provider
    /// - Returns: The active embedding provider
    /// - Throws: BrainAIError if no embedding provider is configured
    public func activeEmbeddingProvider() throws -> any EmbeddingProvider {
        guard let config = embeddingConfig else {
            throw BrainAIError.noActiveProvider("embedding")
        }

        guard let provider = embeddingProviders.first(where: { $0.id == config.providerID }) else {
            throw BrainAIError.providerNotFound(config.providerID)
        }

        return provider
    }

    /// Get the active extraction LLM provider
    /// - Returns: The active extraction LLM provider
    /// - Throws: BrainAIError if no extraction provider is configured
    public func activeExtractionLLM() throws -> any LLMProvider {
        guard let config = extractionConfig else {
            throw BrainAIError.noActiveProvider("extraction")
        }

        guard let provider = llmProviders.first(where: { $0.id == config.providerID }) else {
            throw BrainAIError.providerNotFound(config.providerID)
        }

        return provider
    }

    /// Get the active reranker provider if available
    /// - Returns: The active reranker provider or nil if not configured
    public func activeReranker() -> (any RerankerProvider)? {
        guard let config = rerankerConfig else {
            return nil
        }

        return rerankerProviders.first { $0.id == config.providerID }
    }

    /// Get the active generation LLM provider
    /// - Returns: The active generation LLM provider
    /// - Throws: BrainAIError if no generation provider is configured
    public func activeGenerationLLM() throws -> any LLMProvider {
        guard let config = generationConfig else {
            throw BrainAIError.noActiveProvider("generation")
        }

        guard let provider = llmProviders.first(where: { $0.id == config.providerID }) else {
            throw BrainAIError.providerNotFound(config.providerID)
        }

        return provider
    }
}

// MARK: - BrainAI Errors

/// Errors specific to BrainAI operations
public enum BrainAIError: LocalizedError {
    case noActiveProvider(String)
    case providerNotFound(String)
    case configurationError(String)
    case processError(String)
    case workspaceError(String)
    case keychainError(String)

    public var errorDescription: String? {
        switch self {
        case .noActiveProvider(let role):
            return "No active provider configured for role: \(role)"
        case .providerNotFound(let id):
            return "Provider not found: \(id)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .processError(let message):
            return "Process error: \(message)"
        case .workspaceError(let message):
            return "Workspace error: \(message)"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        }
    }
}
