import Foundation

// MARK: - OllamaLLMProvider

/// LLM provider implementation for Ollama
public actor OllamaLLMProvider: LLMProvider {
    public let id: String
    public let displayName: String
    public let providerType: ProviderType = .ollama

    private let ollamaAPI: OllamaAPIClient

    /// Initialize an Ollama LLM provider
    /// - Parameters:
    ///   - id: Provider identifier
    ///   - displayName: Human-readable name
    ///   - ollamaAPI: API client for Ollama
    public init(
        id: String = "ollama-llm",
        displayName: String = "Ollama",
        ollamaAPI: OllamaAPIClient
    ) {
        self.id = id
        self.displayName = displayName
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

    public func generate(prompt: String, model: String, options: GenerateOptions) async throws -> String {
        let ollamaOptions = OllamaOptions(
            temperature: options.temperature,
            topP: options.topP,
            topK: options.topK,
            numPredict: options.maxTokens
        )

        let response = try await ollamaAPI.generate(
            model: model,
            prompt: prompt,
            stream: false,
            options: ollamaOptions
        )
        return response.response
    }

    public func generateStream(prompt: String, model: String, options: GenerateOptions) async throws -> AsyncStream<String> {
        let ollamaOptions = OllamaOptions(
            temperature: options.temperature,
            topP: options.topP,
            topK: options.topK,
            numPredict: options.maxTokens
        )

        return try await ollamaAPI.generateStream(
            model: model,
            prompt: prompt,
            options: ollamaOptions
        )
    }

    public func availableModels() async throws -> [LLMModel] {
        let models = try await ollamaAPI.listModels()
        return models.map { model in
            LLMModel(
                id: model.name,
                name: model.name,
                parameterSize: model.details?.parameterSize ?? "unknown",
                ramEstimate: model.size.map { UInt64($0) },
                capabilities: [.chat],
                contextWindow: 4096
            )
        }
    }
}
