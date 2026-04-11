import Foundation

// MARK: - LightRAG Client Protocol

/// Protocol for interacting with LightRAG knowledge graph API
public protocol LightRAGClientProtocol: Sendable {
    /// Query the knowledge graph
    func query(
        _ question: String,
        mode: SearchMode,
        topK: Int,
        onlyNeedContext: Bool
    ) async throws -> QueryResponse

    /// Insert text into the knowledge base
    func insertText(
        _ text: String,
        description: String
    ) async throws -> InsertTextResponse

    /// Create an entity in the knowledge graph
    func createEntity(_ request: EntityCreateRequest) async throws

    /// Create a relation in the knowledge graph
    func createRelation(_ request: RelationCreateRequest) async throws

    /// Delete an entity from the knowledge graph
    func deleteEntity(_ name: String) async throws

    /// List documents in the knowledge base
    func listDocuments(
        page: Int,
        pageSize: Int,
        status: String?
    ) async throws -> DocumentListResponse

    /// Check health of LightRAG service
    func healthCheck() async throws -> HealthResponse
}

// MARK: - Local LightRAG Client

/// LightRAG client for connecting to local instance
public final class LocalLightRAGClient: LightRAGClientProtocol {
    private let httpClient: HTTPClient

    /// Initializes a client for local LightRAG instance
    /// - Parameters:
    ///   - host: Hostname (default: "localhost")
    ///   - port: Port number (default: 9621)
    public init(host: String = "localhost", port: UInt16 = 9621) {
        let baseURL = "http://\(host):\(port)"
        self.httpClient = HTTPClient(baseURL: baseURL)
    }

    // MARK: - LightRAGClientProtocol Conformance

    public func query(
        _ question: String,
        mode: SearchMode,
        topK: Int,
        onlyNeedContext: Bool
    ) async throws -> QueryResponse {
        let request = QueryRequest(
            question: question,
            mode: mode,
            topK: topK,
            onlyNeedContext: onlyNeedContext
        )
        return try await httpClient.post("/api/query", body: request)
    }

    public func insertText(
        _ text: String,
        description: String
    ) async throws -> InsertTextResponse {
        let request = InsertTextRequest(text: text, description: description)
        return try await httpClient.post("/api/documents/text", body: request)
    }

    public func createEntity(_ request: EntityCreateRequest) async throws {
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await httpClient.post("/api/graph/entity/create", body: request)
    }

    public func createRelation(_ request: RelationCreateRequest) async throws {
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await httpClient.post("/api/graph/relation/create", body: request)
    }

    public func deleteEntity(_ name: String) async throws {
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await httpClient.delete(
            "/api/graph/entity",
            queryParameters: ["name": name]
        )
    }

    public func listDocuments(
        page: Int,
        pageSize: Int,
        status: String?
    ) async throws -> DocumentListResponse {
        var queryParams: [String: String] = [
            "page": String(page),
            "page_size": String(pageSize)
        ]
        if let status = status, !status.isEmpty {
            queryParams["status"] = status
        }
        return try await httpClient.get("/api/documents/paginated", queryParameters: queryParams)
    }

    public func healthCheck() async throws -> HealthResponse {
        return try await httpClient.get("/health")
    }
}

// MARK: - Remote LightRAG Client

/// LightRAG client for connecting to remote instance with authentication
public final class RemoteLightRAGClient: LightRAGClientProtocol {
    private let httpClient: HTTPClient

    /// Initializes a client for remote LightRAG instance
    /// - Parameters:
    ///   - baseURL: Full base URL of the remote service
    ///   - authToken: Optional Bearer token for authentication
    public init(baseURL: String, authToken: String? = nil) {
        self.httpClient = HTTPClient(baseURL: baseURL, authToken: authToken)
    }

    // MARK: - LightRAGClientProtocol Conformance

    public func query(
        _ question: String,
        mode: SearchMode,
        topK: Int,
        onlyNeedContext: Bool
    ) async throws -> QueryResponse {
        let request = QueryRequest(
            question: question,
            mode: mode,
            topK: topK,
            onlyNeedContext: onlyNeedContext
        )
        return try await httpClient.post("/api/query", body: request)
    }

    public func insertText(
        _ text: String,
        description: String
    ) async throws -> InsertTextResponse {
        let request = InsertTextRequest(text: text, description: description)
        return try await httpClient.post("/api/documents/text", body: request)
    }

    public func createEntity(_ request: EntityCreateRequest) async throws {
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await httpClient.post("/api/graph/entity/create", body: request)
    }

    public func createRelation(_ request: RelationCreateRequest) async throws {
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await httpClient.post("/api/graph/relation/create", body: request)
    }

    public func deleteEntity(_ name: String) async throws {
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await httpClient.delete(
            "/api/graph/entity",
            queryParameters: ["name": name]
        )
    }

    public func listDocuments(
        page: Int,
        pageSize: Int,
        status: String?
    ) async throws -> DocumentListResponse {
        var queryParams: [String: String] = [
            "page": String(page),
            "page_size": String(pageSize)
        ]
        if let status = status, !status.isEmpty {
            queryParams["status"] = status
        }
        return try await httpClient.get("/api/documents/paginated", queryParameters: queryParams)
    }

    public func healthCheck() async throws -> HealthResponse {
        return try await httpClient.get("/health")
    }
}
