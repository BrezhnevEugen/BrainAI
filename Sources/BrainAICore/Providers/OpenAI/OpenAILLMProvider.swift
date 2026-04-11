import Foundation

// MARK: - OpenAI API DTOs

/// Request structure for OpenAI chat completion API
/// Note: HTTPClient encoder uses .convertToSnakeCase, so camelCase properties
/// are automatically converted (maxTokens -> max_tokens, topP -> top_p)
private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Float?
    let maxTokens: Int?
    let topP: Float?
}

/// Message structure for OpenAI chat API
private struct OpenAIChatMessage: Encodable {
    let role: String
    let content: String
}

/// Response structure from OpenAI chat completion API
private struct OpenAIChatResponse: Decodable {
    let id: String
    let choices: [OpenAIChatChoice]
    let usage: OpenAIUsage?
}

/// Choice structure in OpenAI response
private struct OpenAIChatChoice: Decodable {
    let index: Int
    let message: OpenAIChatResponseMessage
}

/// Message structure in OpenAI response
private struct OpenAIChatResponseMessage: Decodable {
    let role: String
    let content: String?
}

/// Usage statistics from OpenAI response
/// Note: HTTPClient decoder uses .convertFromSnakeCase, so prompt_tokens -> promptTokens
private struct OpenAIUsage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}

/// Response structure for models list API
private struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModelInfo]
}

/// Model information structure
private struct OpenAIModelInfo: Decodable {
    let id: String
    let ownedBy: String?
}

// MARK: - OpenAILLMProvider

/// LLM provider implementation for OpenAI-compatible APIs
public actor OpenAILLMProvider: LLMProvider {
    public let id: String
    public let displayName: String
    public let providerType: ProviderType

    private let httpClient: HTTPClient

    /// Initialize an OpenAI LLM provider
    /// - Parameters:
    ///   - id: Provider identifier
    ///   - displayName: Human-readable name
    ///   - providerType: Type of provider (default .openai)
    ///   - baseURL: Base URL for API requests (default: OpenAI API)
    ///   - apiKey: API key for authentication
    public init(
        id: String = "openai-llm",
        displayName: String = "OpenAI",
        providerType: ProviderType = .openai,
        baseURL: String = "https://api.openai.com/v1",
        apiKey: String
    ) {
        self.id = id
        self.displayName = displayName
        self.providerType = providerType
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

    public func generate(prompt: String, model: String, options: GenerateOptions) async throws -> String {
        let request = OpenAIChatRequest(
            model: model,
            messages: [OpenAIChatMessage(role: "user", content: prompt)],
            temperature: options.temperature,
            maxTokens: options.maxTokens,
            topP: options.topP
        )

        let response: OpenAIChatResponse = try await httpClient.post("/chat/completions", body: request)

        guard !response.choices.isEmpty,
              let content = response.choices[0].message.content else {
            throw HTTPClientError.decodingFailed("No response content in OpenAI response")
        }

        return content
    }

    public func generateStream(prompt: String, model: String, options: GenerateOptions) async throws -> AsyncStream<String> {
        // For now, implement streaming by wrapping the generate function
        // Proper streaming can be implemented later
        let result = try await generate(prompt: prompt, model: model, options: options)
        return AsyncStream { continuation in
            continuation.yield(result)
            continuation.finish()
        }
    }

    public func availableModels() async throws -> [LLMModel] {
        let response: OpenAIModelsResponse = try await httpClient.get("/models")

        return response.data
            .filter { $0.id.lowercased().contains("gpt") }
            .map { model in
                LLMModel(
                    id: model.id,
                    name: model.id,
                    parameterSize: "unknown",
                    ramEstimate: nil,
                    capabilities: [.chat],
                    contextWindow: 4096
                )
            }
    }
}
