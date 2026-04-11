import Foundation

// MARK: - Generate Options

/// Options for LLM generation
public struct GenerateOptions: Sendable {
    /// Temperature for sampling (0.0 to 2.0)
    public var temperature: Float?

    /// Nucleus sampling parameter
    public var topP: Float?

    /// Top-K sampling parameter
    public var topK: Int?

    /// Maximum number of tokens to generate
    public var maxTokens: Int?

    /// Context window size in tokens
    public var contextWindow: Int?

    public init(
        temperature: Float? = nil,
        topP: Float? = nil,
        topK: Int? = nil,
        maxTokens: Int? = nil,
        contextWindow: Int? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxTokens = maxTokens
        self.contextWindow = contextWindow
    }
}

// MARK: - LLMProvider Protocol

/// Protocol for large language model providers
public protocol LLMProvider: Sendable {
    /// Unique identifier for the provider
    var id: String { get }

    /// Human-readable display name
    var displayName: String { get }

    /// Type of provider
    var providerType: ProviderType { get }

    /// Whether the provider is currently available
    var isAvailable: Bool { get async }

    /// Generate text from a prompt
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - model: The model ID to use
    ///   - options: Generation options
    /// - Returns: Generated text
    func generate(prompt: String, model: String, options: GenerateOptions) async throws -> String

    /// Generate text with streaming output
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - model: The model ID to use
    ///   - options: Generation options
    /// - Returns: AsyncStream of text chunks
    func generateStream(prompt: String, model: String, options: GenerateOptions) async throws -> AsyncStream<String>

    /// Get list of available models
    /// - Returns: Array of available LLMModel descriptors
    func availableModels() async throws -> [LLMModel]
}
