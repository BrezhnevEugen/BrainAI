import Foundation

// MARK: - OpenAI-Compatible SSE Streaming

/// Shared Server-Sent-Events streaming for OpenAI-compatible chat APIs
/// (OpenAI, DeepSeek, and other `/chat/completions` providers).
///
/// `HTTPClient` only decodes whole responses, so streaming providers talk to
/// `URLSession.bytes(for:)` directly through this helper. Connection setup is
/// `async throws`; once the response is flowing, deltas are delivered through a
/// non-throwing `AsyncStream` (mid-stream failures simply end the stream),
/// matching the `LLMProvider.generateStream` contract.
enum OpenAICompatibleStreaming {

    private struct ChatMessage: Encodable {
        let role: String
        let content: String
    }

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Float?
        let maxTokens: Int?
        let topP: Float?
        let stream: Bool

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature, stream
            case maxTokens = "max_tokens"
            case topP = "top_p"
        }
    }

    private struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { let content: String? }
            let delta: Delta
        }
        let choices: [Choice]
    }

    /// Open a streaming chat completion and return a stream of content deltas.
    /// - Throws: on connection setup or a non-2xx HTTP status.
    static func chatStream(
        baseURL: String,
        apiKey: String,
        model: String,
        prompt: String,
        options: GenerateOptions
    ) async throws -> AsyncStream<String> {
        guard let url = URL(string: baseURL.hasSuffix("/") ? "\(baseURL)chat/completions" : "\(baseURL)/chat/completions") else {
            throw HTTPClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(
                model: model,
                messages: [ChatMessage(role: "user", content: prompt)],
                temperature: options.temperature,
                maxTokens: options.maxTokens,
                topP: options.topP,
                stream: true
            )
        )

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if http.statusCode == 401 { throw HTTPClientError.unauthorized }
            throw HTTPClientError.requestFailed(statusCode: http.statusCode, data: nil)
        }

        return AsyncStream { continuation in
            let task = Task {
                let decoder = JSONDecoder()
                do {
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload.isEmpty { continue }
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let chunk = try? decoder.decode(StreamChunk.self, from: data),
                              let delta = chunk.choices.first?.delta.content,
                              !delta.isEmpty else { continue }
                        continuation.yield(delta)
                    }
                } catch {
                    // Network/stream error mid-flight: end the stream gracefully.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
