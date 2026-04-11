import Foundation

// MARK: - EmbeddingProvider Protocol

/// Protocol for embedding service providers
public protocol EmbeddingProvider: Sendable {
    /// Unique identifier for the provider
    var id: String { get }

    /// Human-readable display name
    var displayName: String { get }

    /// Type of provider
    var providerType: ProviderType { get }

    /// Dimension of the embedding vectors this provider produces
    var outputDimension: Int { get }

    /// Whether the provider is currently available
    var isAvailable: Bool { get async }

    /// Embed a single text string
    /// - Parameters:
    ///   - text: The text to embed
    ///   - model: The model ID to use for embedding
    /// - Returns: Array of Float values representing the embedding
    func embed(text: String, model: String) async throws -> [Float]

    /// Embed multiple text strings in a batch
    /// - Parameters:
    ///   - texts: Array of texts to embed
    ///   - model: The model ID to use for embedding
    /// - Returns: Array of embedding arrays
    func embedBatch(texts: [String], model: String) async throws -> [[Float]]

    /// Get list of available embedding models
    /// - Returns: Array of available EmbeddingModel descriptors
    func availableModels() async throws -> [EmbeddingModel]
}
