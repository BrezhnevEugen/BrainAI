import Foundation

// MARK: - OllamaEmbeddingProvider

/// Embedding provider implementation for Ollama
public actor OllamaEmbeddingProvider: EmbeddingProvider {
    public let id: String
    public let displayName: String
    public let providerType: ProviderType = .ollama
    public let outputDimension: Int

    private let ollamaAPI: OllamaAPIClient

    /// Initialize an Ollama embedding provider
    /// - Parameters:
    ///   - id: Provider identifier
    ///   - displayName: Human-readable name
    ///   - outputDimension: Default embedding dimension
    ///   - ollamaAPI: API client for Ollama
    public init(
        id: String = "ollama-embed",
        displayName: String = "Ollama Embeddings",
        outputDimension: Int = 384,
        ollamaAPI: OllamaAPIClient
    ) {
        self.id = id
        self.displayName = displayName
        self.outputDimension = outputDimension
        self.ollamaAPI = ollamaAPI
    }

    public var isAvailable: Bool {
        get async {
            do {
                return try await ollamaAPI.healthCheck()
            } catch {
                return false
            }
        }
    }

    public func embed(text: String, model: String) async throws -> [Float] {
        return try await ollamaAPI.embed(model: model, input: text)
    }

    public func embedBatch(texts: [String], model: String) async throws -> [[Float]] {
        return try await withThrowingTaskGroup(of: (Int, [Float]).self) { group in
            for (index, text) in texts.enumerated() {
                group.addTask {
                    let embedding = try await self.embed(text: text, model: model)
                    return (index, embedding)
                }
            }

            var results: [(Int, [Float])] = []
            for try await result in group {
                results.append(result)
            }

            // Sort by index to maintain order
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    public func availableModels() async throws -> [EmbeddingModel] {
        let models = try await ollamaAPI.listModels()
        // Return all models; filtering for embedding-capable models
        // would require checking model metadata which Ollama doesn't expose directly
        return models.map { model in
            EmbeddingModel(
                id: model.name,
                name: model.name,
                dimension: outputDimension,
                maxTokens: 512,
                multilingual: false,
                sizeOnDisk: model.size.map { UInt64($0) }
            )
        }
    }
}
