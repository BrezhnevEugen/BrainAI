import Foundation

// MARK: - Graph label list JSON (array vs legacy object)

private enum GraphLabelsAPIPayload: Decodable {
    case list([String])
    case legacy(GraphLabelsResponse)

    init(from decoder: Decoder) throws {
        if let c = try? decoder.singleValueContainer(), let arr = try? c.decode([String].self) {
            self = .list(arr)
            return
        }
        self = .legacy(try GraphLabelsResponse(from: decoder))
    }

    var normalized: GraphLabelsResponse {
        switch self {
        case .list(let arr):
            return GraphLabelsResponse(entityLabels: arr, relationLabels: [])
        case .legacy(let response):
            return response
        }
    }
}

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

    /// Search entity/label names matching a query (`GET /graph/label/search`).
    func searchGraphLabels(query: String, limit: Int) async throws -> [String]

    /// Load a subgraph for a starting label (`GET /graphs`). `searchText` is ignored; filter with `searchGraphLabels` first.
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
    ///   - requestTimeout: Per-request timeout in seconds (default: 30)
    public init(host: String = "localhost", port: UInt16 = 9621, requestTimeout: TimeInterval = 30) {
        let baseURL = "http://\(host):\(port)"
        self.httpClient = HTTPClient(baseURL: baseURL, timeout: requestTimeout)
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
        return try await httpClient.post("/query", body: request)
    }

    public func insertText(
        _ text: String,
        description: String
    ) async throws -> InsertTextResponse {
        let request = InsertTextRequest(text: text, description: description)
        return try await httpClient.post("/documents/text", body: request)
    }

    public func createEntity(_ request: EntityCreateRequest) async throws {
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await httpClient.post("/graph/entity/create", body: request)
    }

    public func createRelation(_ request: RelationCreateRequest) async throws {
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await httpClient.post("/graph/relation/create", body: request)
    }

    public func deleteEntity(_ name: String) async throws {
        struct DeleteEntityBody: Encodable {
            let entityName: String
            enum CodingKeys: String, CodingKey {
                case entityName = "entity_name"
            }
        }
        struct DeletionResultWire: Decodable {
            let status: String?
        }
        let body = DeleteEntityBody(entityName: name)
        let _: DeletionResultWire = try await httpClient.post("/documents/delete_entity", body: body)
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
        return try await httpClient.get("/documents/paginated", queryParameters: queryParams)
    }

    public func healthCheck() async throws -> HealthResponse {
        return try await httpClient.get("/health")
    }

    public func getGraphLabels() async throws -> GraphLabelsResponse {
        let payload: GraphLabelsAPIPayload = try await httpClient.get("/graph/label/list")
        return payload.normalized
    }

    public func searchGraphLabels(query: String, limit: Int) async throws -> [String] {
        try await httpClient.get(
            "/graph/label/search",
            queryParameters: [
                "q": query,
                "limit": String(limit)
            ]
        )
    }

    public func searchGraph(label: String, searchText _: String, maxItems: Int) async throws -> GraphSearchResponse {
        let params: [String: String] = [
            "label": label,
            "max_depth": "3",
            "max_nodes": String(maxItems)
        ]
        let dto: LightRAGKnowledgeGraphDTO = try await httpClient.get("/graphs", queryParameters: params)
        return dto.toGraphSearchResponse()
    }

    public func getEntity(_ name: String) async throws -> GraphNodeData {
        let subgraph = try await searchGraph(label: name, searchText: "", maxItems: 1)
        guard let first = subgraph.nodes.first else {
            throw HTTPClientError.decodingFailed("Entity not found: \(name)")
        }
        return first
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
        return try await httpClient.post("/query/data", body: request)
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
        return try await httpClient.post("/query", body: request)
    }

    public func insertText(
        _ text: String,
        description: String
    ) async throws -> InsertTextResponse {
        let request = InsertTextRequest(text: text, description: description)
        return try await httpClient.post("/documents/text", body: request)
    }

    public func createEntity(_ request: EntityCreateRequest) async throws {
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await httpClient.post("/graph/entity/create", body: request)
    }

    public func createRelation(_ request: RelationCreateRequest) async throws {
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await httpClient.post("/graph/relation/create", body: request)
    }

    public func deleteEntity(_ name: String) async throws {
        struct DeleteEntityBody: Encodable {
            let entityName: String
            enum CodingKeys: String, CodingKey {
                case entityName = "entity_name"
            }
        }
        struct DeletionResultWire: Decodable {
            let status: String?
        }
        let body = DeleteEntityBody(entityName: name)
        let _: DeletionResultWire = try await httpClient.post("/documents/delete_entity", body: body)
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
        return try await httpClient.get("/documents/paginated", queryParameters: queryParams)
    }

    public func healthCheck() async throws -> HealthResponse {
        return try await httpClient.get("/health")
    }

    public func getGraphLabels() async throws -> GraphLabelsResponse {
        let payload: GraphLabelsAPIPayload = try await httpClient.get("/graph/label/list")
        return payload.normalized
    }

    public func searchGraphLabels(query: String, limit: Int) async throws -> [String] {
        try await httpClient.get(
            "/graph/label/search",
            queryParameters: [
                "q": query,
                "limit": String(limit)
            ]
        )
    }

    public func searchGraph(label: String, searchText _: String, maxItems: Int) async throws -> GraphSearchResponse {
        let params: [String: String] = [
            "label": label,
            "max_depth": "3",
            "max_nodes": String(maxItems)
        ]
        let dto: LightRAGKnowledgeGraphDTO = try await httpClient.get("/graphs", queryParameters: params)
        return dto.toGraphSearchResponse()
    }

    public func getEntity(_ name: String) async throws -> GraphNodeData {
        let subgraph = try await searchGraph(label: name, searchText: "", maxItems: 1)
        guard let first = subgraph.nodes.first else {
            throw HTTPClientError.decodingFailed("Entity not found: \(name)")
        }
        return first
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
        return try await httpClient.post("/query/data", body: request)
    }
}
