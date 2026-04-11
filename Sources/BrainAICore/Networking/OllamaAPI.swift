import Foundation

// MARK: - Ollama API Error

/// Errors that can occur during Ollama API operations
public enum OllamaAPIError: LocalizedError {
    /// Invalid model name
    case invalidModel
    /// Request failed with underlying error
    case requestFailed(String)
    /// Failed to decode response
    case decodingFailed(String)
    /// Model not found
    case modelNotFound(String)
    /// Ollama service unavailable
    case serviceUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidModel:
            return "Invalid model name"
        case .requestFailed(let message):
            return "Request failed: \(message)"
        case .decodingFailed(let message):
            return "Failed to decode response: \(message)"
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .serviceUnavailable:
            return "Ollama service is unavailable"
        }
    }
}

// MARK: - Ollama API Client

/// Client for interacting with Ollama REST API
public actor OllamaAPIClient {
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Initializes the Ollama API client
    /// - Parameters:
    ///   - baseURL: Base URL for Ollama API (default: http://localhost:11434)
    ///   - requestTimeout: Per-request timeout in seconds (default: 30)
    public init(baseURL: String = "http://localhost:11434", requestTimeout: TimeInterval = 30) {
        self.httpClient = HTTPClient(baseURL: baseURL, timeout: requestTimeout)

        // Configure decoder for snake_case
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601

        // Configure encoder for snake_case
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Health Check

    /// Checks if Ollama is running and reachable
    /// - Returns: True if Ollama responds successfully
    public func healthCheck() async throws -> Bool {
        do {
            let _: OllamaModelsResponse = try await httpClient.get("/api/tags")
            return true
        } catch {
            return false
        }
    }

    // MARK: - Model Management

    /// Lists all available models
    /// - Returns: Array of model information
    public func listModels() async throws -> [OllamaModelInfo] {
        let response: OllamaModelsResponse = try await httpClient.get("/api/tags")
        return response.models
    }

    /// Gets details about a specific model
    /// - Parameter name: Model name
    /// - Returns: Model details
    public func showModel(name: String) async throws -> OllamaModelDetail {
        return try await httpClient.post(
            "/api/show",
            body: ["name": name]
        )
    }

    /// Pulls (downloads) a model
    /// - Parameter name: Model name to pull
    /// - Returns: Async stream of pull progress updates
    public func pullModel(name: String) async throws -> AsyncStream<OllamaPullProgress> {
        return AsyncStream { continuation in
            Task {
                do {
                    let request = OllamaPullRequest(name: name, stream: true)
                    guard let url = URL(string: "http://localhost:11434/api/pull") else {
                        continuation.finish()
                        return
                    }

                    var httpRequest = URLRequest(url: url)
                    httpRequest.httpMethod = "POST"
                    httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    httpRequest.httpBody = try encoder.encode(request)

                    let (stream, response) = try await URLSession.shared.bytes(for: httpRequest)

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200..<300).contains(httpResponse.statusCode) else {
                        continuation.finish()
                        return
                    }

                    for try await line in stream.lines {
                        if let data = line.data(using: .utf8) {
                            if let progress = try? decoder.decode(OllamaPullProgress.self, from: data) {
                                continuation.yield(progress)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }

    /// Deletes a model
    /// - Parameter name: Model name to delete
    public func deleteModel(name: String) async throws {
        struct EmptyRequest: Encodable {
            let name: String
        }
        struct EmptyResponse: Decodable {}

        let _: EmptyResponse = try await httpClient.delete(
            "/api/delete",
            queryParameters: ["name": name]
        )
    }

    /// Unloads a model from memory
    /// - Parameter name: Model name to unload
    public func stopModel(name: String) async throws {
        struct StopRequest: Encodable {
            let name: String
            let keepAlive: Int

            enum CodingKeys: String, CodingKey {
                case name
                case keepAlive = "keep_alive"
            }
        }
        struct EmptyResponse: Decodable {}

        let request = StopRequest(name: name, keepAlive: 0)
        let _: EmptyResponse = try await httpClient.post("/api/generate", body: request)
    }

    // MARK: - Text Generation

    /// Generates text using a model
    /// - Parameters:
    ///   - model: Model name
    ///   - prompt: Input prompt
    ///   - stream: Whether to stream the response (default: false)
    ///   - options: Optional generation options
    /// - Returns: Generated response
    public func generate(
        model: String,
        prompt: String,
        stream: Bool = false,
        options: OllamaOptions? = nil
    ) async throws -> OllamaGenerateResponse {
        let request = OllamaGenerateRequest(
            model: model,
            prompt: prompt,
            stream: stream,
            options: options
        )
        return try await httpClient.post("/api/generate", body: request)
    }

    /// Generates text using a model with streaming
    /// - Parameters:
    ///   - model: Model name
    ///   - prompt: Input prompt
    ///   - options: Optional generation options
    /// - Returns: Async stream of text chunks
    public func generateStream(
        model: String,
        prompt: String,
        options: OllamaOptions? = nil
    ) async throws -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                do {
                    let request = OllamaGenerateRequest(
                        model: model,
                        prompt: prompt,
                        stream: true,
                        options: options
                    )

                    guard let url = URL(string: "http://localhost:11434/api/generate") else {
                        continuation.finish()
                        return
                    }

                    var httpRequest = URLRequest(url: url)
                    httpRequest.httpMethod = "POST"
                    httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    httpRequest.httpBody = try encoder.encode(request)

                    let (stream, response) = try await URLSession.shared.bytes(for: httpRequest)

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200..<300).contains(httpResponse.statusCode) else {
                        continuation.finish()
                        return
                    }

                    for try await line in stream.lines {
                        if let data = line.data(using: .utf8) {
                            if let response = try? decoder.decode(OllamaGenerateResponse.self, from: data) {
                                continuation.yield(response.response)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Embeddings

    /// Generates embeddings for text
    /// - Parameters:
    ///   - model: Model name
    ///   - input: Input text to embed
    ///   - options: Optional embedding options
    /// - Returns: Array of embedding values
    public func embed(
        model: String,
        input: String,
        options: OllamaOptions? = nil
    ) async throws -> [Float] {
        let request = OllamaEmbedRequest(model: model, input: input, options: options)
        let response: OllamaEmbedResponse = try await httpClient.post("/api/embed", body: request)
        return response.embedding
    }
}
