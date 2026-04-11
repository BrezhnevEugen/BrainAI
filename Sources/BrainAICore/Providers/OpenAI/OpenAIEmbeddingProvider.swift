import Foundation

// MARK: - OpenAI Embedding API DTOs

/// Request structure for OpenAI embedding API
private struct OpenAIEmbedRequest: Encodable {
    let model: String
    let input: [String]
}

/// Response structure from OpenAI embedding API
private struct OpenAIEmbedResponse: Decodable {
    let data: [OpenAIEmbedData]
}

/// Embedding data structure in OpenAI response
private struct OpenAIEmbedData: Decodable {
    let index: Int
    let embedding: [Float]
}

/// Response structure for models list API
private struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModelInfo]
}

/// Model information structure
private struct OpenAIModelInfo: Decodable {
    let id: String
}

// MARK: - OpenAIEmbeddingProvider

/// Embedding provider implementation for OpenAI-compatible APIs
public actor OpenAIEmbeddingProvider: EmbeddingProvider {
    public let id: String
    public let displayName: String
    public let providerType: ProviderType
    public let outputDimension: Int

    private let httpClient: HTTPClient

    /// Initialize an OpenAI embedding provider
    /// - Parameters:
    ///   - id: Provider identifier
    ///   - displayName: Human-readable name
    ///   - providerType: Type of provider (default .openai)
    ///   - baseURL: Base URL for API requests (default: OpenAI API)
    ///   - apiKey: API key for authentication
    ///   - outputDimension: Dimension of embedding vectors (default: 1536 for text-embedding-3-small)
    public init(
        id: String = "openai-embedding",
        displayName: String = "OpenAI Embeddings",
        providerType: ProviderType = .openai,
        baseURL: String = "https://api.openai.com/v1",
        apiKey: String,
        outputDimension: Int = 1536
    ) {
        self.id = id
        self.displayName = displayName
        self.providerType = providerType
        self.outputDimension = outputDimension
        self.httpClient = HTTPClient(baseURL: baseURL, authToken: apiKey)
    }

    public var isAvailable: Bool {
        get async {
            do {
                let _: OpenAIModelsResponse = try await httpClient.get("/models")
                return true
            } catch {
                return false
            }
        }
    }

    public func embed(text: String, model: String) async throws -> [Float] {
        let embeddings = try await embedBatch(texts: [text], model: model)
        guard !embeddings.isEmpty else {
            throw HTTPClientError.decodingFailed("No embeddings returned from OpenAI")
        }
        return embeddings[0]
    }

    public func embedBatch(texts: [String], model: String) async throws -> [[Float]] {
        let request = OpenAIEmbedRequest(model: model, input: texts)
        let response: OpenAIEmbedResponse = try await httpClient.post("/embeddings", body: request)

        // Sort by index to ensure correct ordering
        let sorted = response.data.sorted { $0.index < $1.index }
        return sorted.map { $0.embedding }
    }

    public func availableModels() async throws -> [EmbeddingModel] {
        let embeddingModels = [
            EmbeddingModel(
                id: "text-embedding-3-small",
                name: "Text Embedding 3 Small",
                dimension: 512,
                maxTokens: 8191,
                multilingual: true
            ),
            EmbeddingModel(
                id: "text-embedding-3-large",
                name: "Text Embedding 3 Large",
                dimension: 3072,
                maxTokens: 8191,
                multilingual: true
            ),
            EmbeddingModel(
                id: "text-embedding-ada-002",
                name: "Text Embedding Ada 002",
                dimension: 1536,
                maxTokens: 8191,
                multilingual: true
            ),
        ]
        return embeddingModels
    }
}
