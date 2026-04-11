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

    /// Get all graph labels (entity types and relation types)
    func getGraphLabels() async throws -> GraphLabelsResponse

    /// Search graph nodes by label/type
    func searchGraph(label: String, searchText: String, maxItems: Int) async throws -> GraphSearchResponse

    /// Get entity details by name
    func getEntity(_ name: String) async throws -> GraphNodeData

    /// Query knowledge base returning structured data (entities, relations, chunks)
    func queryData(_ question: String, mode: SearchMode, topK: Int) async throws -> QueryDataResponse
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

    public func getGraphLabels() async throws -> GraphLabelsResponse {
        return try await httpClient.get("/api/graph/labels")
    }

    public func searchGraph(label: String, searchText: String, maxItems: Int) async throws -> GraphSearchResponse {
        var params: [String: String] = [
            "label": label,
            "max_items": String(maxItems)
        ]
        if !searchText.isEmpty {
            params["search_text"] = searchText
        }
        return try await httpClient.get("/api/graph/search", queryParameters: params)
    }

    public func getEntity(_ name: String) async throws -> GraphNodeData {
        return try await httpClient.get("/api/graph/entity", queryParameters: ["name": name])
    }

    public func queryData(_ question: String, mode: SearchMode, topK: Int) async throws -> QueryDataResponse {
        struct QueryDataRequest: Encodable {
            let question: String
            let mode: SearchMode
            let topK: Int
            enum CodingKeys: String, CodingKey {
                case question, mode
                case topK = "top_k"
            }
        }
        let request = QueryDataRequest(question: question, mode: mode, topK: topK)
        return try await httpClient.post("/api/query/data", body: request)
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

    /// Internal initializer accepting a pre-configured HTTPClient (for TLS pinning)
    internal init(httpClient: HTTPClient) {
        self.httpClient = httpClient
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

    public func getGraphLabels() async throws -> GraphLabelsResponse {
        return try await httpClient.get("/api/graph/labels")
    }

    public func searchGraph(label: String, searchText: String, maxItems: Int) async throws -> GraphSearchResponse {
        var params: [String: String] = [
            "label": label,
            "max_items": String(maxItems)
        ]
        if !searchText.isEmpty {
            params["search_text"] = searchText
        }
        return try await httpClient.get("/api/graph/search", queryParameters: params)
    }

    public func getEntity(_ name: String) async throws -> GraphNodeData {
        return try await httpClient.get("/api/graph/entity", queryParameters: ["name": name])
    }

    public func queryData(_ question: String, mode: SearchMode, topK: Int) async throws -> QueryDataResponse {
        struct QueryDataRequest: Encodable {
            let question: String
            let mode: SearchMode
            let topK: Int
            enum CodingKeys: String, CodingKey {
                case question, mode
                case topK = "top_k"
            }
        }
        let request = QueryDataRequest(question: question, mode: mode, topK: topK)
        return try await httpClient.post("/api/query/data", body: request)
    }
}
