import Foundation

// MARK: - DeepSeek API DTOs

/// DeepSeek exposes an OpenAI-compatible REST API, so the request/response
/// shapes mirror the OpenAI chat completion contract.
/// Note: HTTPClient encoder uses .convertToSnakeCase, so camelCase properties
/// are automatically converted (maxTokens -> max_tokens, topP -> top_p).
private struct DeepSeekChatRequest: Encodable {
    let model: String
    let messages: [DeepSeekChatMessage]
    let temperature: Float?
    let maxTokens: Int?
    let topP: Float?
}

/// Message structure for DeepSeek chat API
private struct DeepSeekChatMessage: Encodable {
    let role: String
    let content: String
}

/// Response structure from DeepSeek chat completion API
private struct DeepSeekChatResponse: Decodable {
    let id: String
    let choices: [DeepSeekChatChoice]
    let usage: DeepSeekUsage?
}

/// Choice structure in DeepSeek response
private struct DeepSeekChatChoice: Decodable {
    let index: Int
    let message: DeepSeekChatResponseMessage
}

/// Message structure in DeepSeek response
private struct DeepSeekChatResponseMessage: Decodable {
    let role: String
    let content: String?
}

/// Usage statistics from DeepSeek response
/// Note: HTTPClient decoder uses .convertFromSnakeCase, so prompt_tokens -> promptTokens
private struct DeepSeekUsage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}

/// Response structure for models list API
private struct DeepSeekModelsResponse: Decodable {
    let data: [DeepSeekModelInfo]
}

/// Model information structure
private struct DeepSeekModelInfo: Decodable {
    let id: String
    let ownedBy: String?
}

// MARK: - DeepSeekLLMProvider

/// LLM provider implementation for the DeepSeek API.
///
/// DeepSeek is OpenAI-compatible (`/chat/completions`, `/models`, Bearer auth),
/// so the wire format matches `OpenAILLMProvider`; this type differs in its
/// defaults (base URL, provider type) and in how it surfaces available models.
public actor DeepSeekLLMProvider: LLMProvider {
    public let id: String
    public let displayName: String
    public let providerType: ProviderType

    private let httpClient: HTTPClient

    /// Models DeepSeek always offers, used as a fallback when `/models` is
    /// unreachable or returns an empty list.
    private static let knownModels: [LLMModel] = [
        LLMModel(
            id: "deepseek-chat",
            name: "deepseek-chat",
            parameterSize: "unknown",
            ramEstimate: nil,
            capabilities: [.chat, .extraction],
            contextWindow: 65536
        ),
        LLMModel(
            id: "deepseek-reasoner",
            name: "deepseek-reasoner",
            parameterSize: "unknown",
            ramEstimate: nil,
            capabilities: [.chat, .extraction],
            contextWindow: 65536
        ),
    ]

    /// Initialize a DeepSeek LLM provider
    /// - Parameters:
    ///   - id: Provider identifier
    ///   - displayName: Human-readable name
    ///   - providerType: Type of provider (default .deepseek)
    ///   - baseURL: Base URL for API requests (default: DeepSeek API)
    ///   - apiKey: API key for authentication
    public init(
        id: String = "deepseek-llm",
        displayName: String = "DeepSeek",
        providerType: ProviderType = .deepseek,
        baseURL: String = "https://api.deepseek.com/v1",
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
                let _: DeepSeekModelsResponse = try await httpClient.get("/models")
                return true
            } catch {
                return false
            }
        }
    }

    public func generate(prompt: String, model: String, options: GenerateOptions) async throws -> String {
        let request = DeepSeekChatRequest(
            model: model,
            messages: [DeepSeekChatMessage(role: "user", content: prompt)],
            temperature: options.temperature,
            maxTokens: options.maxTokens,
            topP: options.topP
        )

        let response: DeepSeekChatResponse = try await httpClient.post("/chat/completions", body: request)

        guard !response.choices.isEmpty,
              let content = response.choices[0].message.content else {
            throw HTTPClientError.decodingFailed("No response content in DeepSeek response")
        }

        return content
    }

    public func generateStream(prompt: String, model: String, options: GenerateOptions) async throws -> AsyncStream<String> {
        // For now, implement streaming by wrapping the generate function.
        // Proper SSE streaming can be implemented later.
        let result = try await generate(prompt: prompt, model: model, options: options)
        return AsyncStream { continuation in
            continuation.yield(result)
            continuation.finish()
        }
    }

    public func availableModels() async throws -> [LLMModel] {
        let response: DeepSeekModelsResponse = try await httpClient.get("/models")

        let models = response.data.map { model in
            LLMModel(
                id: model.id,
                name: model.id,
                parameterSize: "unknown",
                ramEstimate: nil,
                capabilities: [.chat, .extraction],
                contextWindow: 65536
            )
        }

        return models.isEmpty ? Self.knownModels : models
    }
}
