import Foundation

// MARK: - Anthropic API DTOs

/// Request structure for Anthropic Messages API
/// Note: encoder uses .convertToSnakeCase, so maxTokens -> max_tokens, topP -> top_p, topK -> top_k
private struct AnthropicMessagesRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [AnthropicMessage]
    let temperature: Float?
    let topP: Float?
    let topK: Int?
}

/// Message structure for Anthropic API
private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

/// Response structure from Anthropic Messages API
/// Note: decoder uses .convertFromSnakeCase, so stop_reason -> stopReason
private struct AnthropicMessagesResponse: Decodable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicContentBlock]
    let stopReason: String?
    let usage: AnthropicUsage?
}

/// Content block structure in Anthropic response
private struct AnthropicContentBlock: Decodable {
    let type: String
    let text: String?
}

/// Usage statistics from Anthropic response
/// Note: decoder uses .convertFromSnakeCase, so input_tokens -> inputTokens
private struct AnthropicUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
}

// MARK: - AnthropicLLMProvider

/// LLM provider implementation for Anthropic's Messages API
public actor AnthropicLLMProvider: LLMProvider {
    public let id: String
    public let displayName: String
    public let providerType: ProviderType = .anthropic

    private let baseURL: String
    private let apiKey: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Initialize an Anthropic LLM provider
    /// - Parameters:
    ///   - id: Provider identifier
    ///   - displayName: Human-readable name
    ///   - baseURL: Base URL for API requests (default: Anthropic API)
    ///   - apiKey: API key for authentication
    public init(
        id: String = "anthropic-llm",
        displayName: String = "Anthropic",
        baseURL: String = "https://api.anthropic.com",
        apiKey: String
    ) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.apiKey = apiKey

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    public var isAvailable: Bool {
        get async {
            do {
                let request = AnthropicMessagesRequest(
                    model: "claude-sonnet-4-20250514",
                    maxTokens: 1,
                    messages: [AnthropicMessage(role: "user", content: "hi")],
                    temperature: nil,
                    topP: nil,
                    topK: nil
                )

                let urlString = "\(baseURL)/v1/messages"
                guard let url = URL(string: urlString) else {
                    return false
                }

                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")

                let requestData = try encoder.encode(request)
                urlRequest.httpBody = requestData

                let (_, response) = try await URLSession.shared.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    return false
                }

                return httpResponse.statusCode == 200 || httpResponse.statusCode == 401
            } catch {
                return false
            }
        }
    }

    public func generate(prompt: String, model: String, options: GenerateOptions) async throws -> String {
        let request = AnthropicMessagesRequest(
            model: model,
            maxTokens: options.maxTokens ?? 2048,
            messages: [AnthropicMessage(role: "user", content: prompt)],
            temperature: options.temperature,
            topP: options.topP,
            topK: options.topK
        )

        let urlString = "\(baseURL)/v1/messages"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AnthropicLLMProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")

        let requestData = try encoder.encode(request)
        urlRequest.httpBody = requestData

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AnthropicLLMProvider", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AnthropicLLMProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        let anthropicResponse = try decoder.decode(AnthropicMessagesResponse.self, from: data)

        guard let textBlock = anthropicResponse.content.first(where: { $0.type == "text" }),
              let text = textBlock.text else {
            throw NSError(domain: "AnthropicLLMProvider", code: -3, userInfo: [NSLocalizedDescriptionKey: "No text content in response"])
        }

        return text
    }

    public func generateStream(prompt: String, model: String, options: GenerateOptions) async throws -> AsyncStream<String> {
        // For now, implement streaming by wrapping the generate function
        // Proper streaming with SSE can be implemented later
        let result = try await generate(prompt: prompt, model: model, options: options)
        return AsyncStream { continuation in
            continuation.yield(result)
            continuation.finish()
        }
    }

    public func availableModels() async throws -> [LLMModel] {
        return [
            LLMModel(
                id: "claude-sonnet-4-20250514",
                name: "Claude Sonnet 4",
                parameterSize: "unknown",
                ramEstimate: nil,
                capabilities: [.chat],
                contextWindow: 200000
            ),
            LLMModel(
                id: "claude-haiku-3-5-20241022",
                name: "Claude 3.5 Haiku",
                parameterSize: "unknown",
                ramEstimate: nil,
                capabilities: [.chat],
                contextWindow: 200000
            ),
            LLMModel(
                id: "claude-opus-4-20250514",
                name: "Claude Opus 4",
                parameterSize: "unknown",
                ramEstimate: nil,
                capabilities: [.chat],
                contextWindow: 200000
            ),
        ]
    }
}
