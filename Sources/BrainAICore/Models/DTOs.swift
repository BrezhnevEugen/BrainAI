import Foundation

// MARK: - Query DTOs

/// Request to query the knowledge graph
public struct QueryRequest: Codable, Sendable {
    public let question: String
    public let mode: SearchMode
    public let topK: Int
    public let onlyNeedContext: Bool
    public let includeReferences: Bool

    public init(
        question: String,
        mode: SearchMode = .hybrid,
        topK: Int = 40,
        onlyNeedContext: Bool = false,
        includeReferences: Bool = true
    ) {
        self.question = question
        self.mode = mode
        self.topK = topK
        self.onlyNeedContext = onlyNeedContext
        self.includeReferences = includeReferences
    }

    enum CodingKeys: String, CodingKey {
        case question
        case mode
        case topK = "top_k"
        case onlyNeedContext = "only_need_context"
        case includeReferences = "include_references"
    }
}

/// Response from knowledge graph query
public struct QueryResponse: Codable, Sendable {
    public let response: String
    public let references: [String]?

    public init(response: String, references: [String]? = nil) {
        self.response = response
        self.references = references
    }
}

// MARK: - Text Insertion DTOs

/// Request to insert text into the knowledge base
public struct InsertTextRequest: Codable, Sendable {
    public let text: String
    public let description: String

    public init(text: String, description: String = "") {
        self.text = text
        self.description = description
    }
}

/// Response from text insertion
public struct InsertTextResponse: Codable, Sendable {
    public let status: String
    public let message: String
    public let trackId: String

    public init(status: String, message: String, trackId: String) {
        self.status = status
        self.message = message
        self.trackId = trackId
    }

    enum CodingKeys: String, CodingKey {
        case status
        case message
        case trackId = "track_id"
    }
}

// MARK: - Entity DTOs

/// Request to create an entity
public struct EntityCreateRequest: Codable, Sendable {
    public let entityName: String
    public let entityType: String
    public let description: String
    public let sourceId: String

    public init(
        entityName: String,
        entityType: String,
        description: String = "",
        sourceId: String = "mcp-manual"
    ) {
        self.entityName = entityName
        self.entityType = entityType
        self.description = description
        self.sourceId = sourceId
    }

    enum CodingKeys: String, CodingKey {
        case entityName = "entity_name"
        case entityType = "entity_type"
        case description
        case sourceId = "source_id"
    }
}

/// Entity data from knowledge base
public struct EntityResponse: Codable, Sendable {
    public let id: String?
    public let name: String
    public let type: String
    public let description: String?
    public let metadata: [String: AnyCodable]?

    public init(
        id: String? = nil,
        name: String,
        type: String,
        description: String? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.metadata = metadata
    }
}

// MARK: - Relation DTOs

/// Request to create a relation
public struct RelationCreateRequest: Codable, Sendable {
    public let srcEntity: String
    public let tgtEntity: String
    public let description: String
    public let keywords: String
    public let sourceId: String

    public init(
        srcEntity: String,
        tgtEntity: String,
        description: String,
        keywords: String = "",
        sourceId: String = "mcp-manual"
    ) {
        self.srcEntity = srcEntity
        self.tgtEntity = tgtEntity
        self.description = description
        self.keywords = keywords
        self.sourceId = sourceId
    }

    enum CodingKeys: String, CodingKey {
        case srcEntity = "src_entity"
        case tgtEntity = "tgt_entity"
        case description
        case keywords
        case sourceId = "source_id"
    }
}

/// Relation data from knowledge base
public struct RelationResponse: Codable, Sendable {
    public let id: String?
    public let sourceId: String
    public let targetId: String
    public let description: String
    public let keywords: [String]?

    public init(
        id: String? = nil,
        sourceId: String,
        targetId: String,
        description: String,
        keywords: [String]? = nil
    ) {
        self.id = id
        self.sourceId = sourceId
        self.targetId = targetId
        self.description = description
        self.keywords = keywords
    }
}

// MARK: - Document DTOs

/// Request to list documents
public struct DocumentListRequest: Codable, Sendable {
    public let page: Int
    public let pageSize: Int
    public let status: String

    public init(page: Int = 1, pageSize: Int = 20, status: String = "") {
        self.page = page
        self.pageSize = pageSize
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case page
        case pageSize = "page_size"
        case status
    }
}

/// Response containing list of documents
public struct DocumentListResponse: Codable, Sendable {
    public let documents: [DocumentInfo]
    public let total: Int
    public let page: Int
    public let pageSize: Int
    public let hasMore: Bool

    public init(
        documents: [DocumentInfo],
        total: Int,
        page: Int,
        pageSize: Int,
        hasMore: Bool
    ) {
        self.documents = documents
        self.total = total
        self.page = page
        self.pageSize = pageSize
        self.hasMore = hasMore
    }

    enum CodingKeys: String, CodingKey {
        case documents
        case total
        case page
        case pageSize = "page_size"
        case hasMore = "has_more"
    }
}

/// Information about a single document
public struct DocumentInfo: Codable, Sendable {
    public let id: String
    public let status: DocumentStatus
    public let createdAt: Date?
    public let updatedAt: Date?
    public let metadata: [String: AnyCodable]?

    public init(
        id: String,
        status: DocumentStatus,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case metadata
    }
}

// MARK: - Health DTOs

/// Health check response
public struct HealthResponse: Codable, Sendable {
    public let status: String
    public let llmModel: String?
    public let embeddingModel: String?
    public let embeddingDim: Int?
    public let workingDir: String?
    public let queryEngineType: String?

    public init(
        status: String,
        llmModel: String? = nil,
        embeddingModel: String? = nil,
        embeddingDim: Int? = nil,
        workingDir: String? = nil,
        queryEngineType: String? = nil
    ) {
        self.status = status
        self.llmModel = llmModel
        self.embeddingModel = embeddingModel
        self.embeddingDim = embeddingDim
        self.workingDir = workingDir
        self.queryEngineType = queryEngineType
    }

    enum CodingKeys: String, CodingKey {
        case status
        case llmModel = "llm_model"
        case embeddingModel = "embedding_model"
        case embeddingDim = "embedding_dim"
        case workingDir = "working_dir"
        case queryEngineType = "query_engine_type"
    }
}

// MARK: - System Stats DTOs

/// System statistics response
public struct SystemStatsResponse: Codable, Sendable {
    public let ram: MemoryStats
    public let cpu: CPUStats
    public let swap: MemoryStats

    public init(ram: MemoryStats, cpu: CPUStats, swap: MemoryStats) {
        self.ram = ram
        self.cpu = cpu
        self.swap = swap
    }
}

/// Memory statistics
public struct MemoryStats: Codable, Sendable {
    public let total: UInt64
    public let used: UInt64
    public let available: UInt64

    public init(total: UInt64, used: UInt64, available: UInt64) {
        self.total = total
        self.used = used
        self.available = available
    }
}

/// CPU statistics
public struct CPUStats: Codable, Sendable {
    public let count: Int
    public let usagePercent: Double

    public init(count: Int, usagePercent: Double) {
        self.count = count
        self.usagePercent = usagePercent
    }

    enum CodingKeys: String, CodingKey {
        case count
        case usagePercent = "usage_percent"
    }
}

// MARK: - Helper Types

// MARK: - Ollama DTOs

/// Information about an Ollama model
public struct OllamaModelInfo: Codable, Sendable {
    public let name: String
    public let size: Int?
    public let digest: String?
    public let modifiedAt: String?
    public let details: OllamaModelDetails?

    public init(
        name: String,
        size: Int? = nil,
        digest: String? = nil,
        modifiedAt: String? = nil,
        details: OllamaModelDetails? = nil
    ) {
        self.name = name
        self.size = size
        self.digest = digest
        self.modifiedAt = modifiedAt
        self.details = details
    }

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case digest
        case modifiedAt = "modified_at"
        case details
    }
}

/// Details about an Ollama model
public struct OllamaModelDetails: Codable, Sendable {
    public let family: String?
    public let parameterSize: String?
    public let quantizationLevel: String?

    public init(
        family: String? = nil,
        parameterSize: String? = nil,
        quantizationLevel: String? = nil
    ) {
        self.family = family
        self.parameterSize = parameterSize
        self.quantizationLevel = quantizationLevel
    }

    enum CodingKeys: String, CodingKey {
        case family
        case parameterSize = "parameter_size"
        case quantizationLevel = "quantization_level"
    }
}

/// Options for Ollama generate and embed operations
public struct OllamaOptions: Codable, Sendable {
    public var temperature: Float?
    public var topP: Float?
    public var topK: Int?
    public var numCtx: Int?
    public var numPredict: Int?
    public var seed: Int?

    public init(
        temperature: Float? = nil,
        topP: Float? = nil,
        topK: Int? = nil,
        numCtx: Int? = nil,
        numPredict: Int? = nil,
        seed: Int? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.numCtx = numCtx
        self.numPredict = numPredict
        self.seed = seed
    }

    enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case numCtx = "num_ctx"
        case numPredict = "num_predict"
        case seed
    }
}

/// Response from Ollama generate operation
public struct OllamaGenerateResponse: Codable, Sendable {
    public let model: String
    public let response: String
    public let done: Bool
    public let totalDuration: Int?
    public let loadDuration: Int?
    public let evalCount: Int?

    public init(
        model: String,
        response: String,
        done: Bool,
        totalDuration: Int? = nil,
        loadDuration: Int? = nil,
        evalCount: Int? = nil
    ) {
        self.model = model
        self.response = response
        self.done = done
        self.totalDuration = totalDuration
        self.loadDuration = loadDuration
        self.evalCount = evalCount
    }

    enum CodingKeys: String, CodingKey {
        case model
        case response
        case done
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case evalCount = "eval_count"
    }
}

/// Progress update for Ollama model pull operation
public struct OllamaPullProgress: Codable, Sendable {
    public let status: String
    public let digest: String?
    public let total: Int?
    public let completed: Int?

    public init(
        status: String,
        digest: String? = nil,
        total: Int? = nil,
        completed: Int? = nil
    ) {
        self.status = status
        self.digest = digest
        self.total = total
        self.completed = completed
    }

    enum CodingKeys: String, CodingKey {
        case status
        case digest
        case total
        case completed
    }
}

/// Details about an Ollama model
public struct OllamaModelDetail: Codable, Sendable {
    public let modelfile: String?
    public let parameters: String?
    public let template: String?
    public let details: OllamaModelDetails?

    public init(
        modelfile: String? = nil,
        parameters: String? = nil,
        template: String? = nil,
        details: OllamaModelDetails? = nil
    ) {
        self.modelfile = modelfile
        self.parameters = parameters
        self.template = template
        self.details = details
    }

    enum CodingKeys: String, CodingKey {
        case modelfile
        case parameters
        case template
        case details
    }
}

/// Request for embedding with Ollama
public struct OllamaEmbedRequest: Codable, Sendable {
    public let model: String
    public let input: String
    public let options: OllamaOptions?
    public let keepAlive: String?

    public init(
        model: String,
        input: String,
        options: OllamaOptions? = nil,
        keepAlive: String? = nil
    ) {
        self.model = model
        self.input = input
        self.options = options
        self.keepAlive = keepAlive
    }

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case options
        case keepAlive = "keep_alive"
    }
}

/// Response from Ollama embed operation
public struct OllamaEmbedResponse: Codable, Sendable {
    public let embedding: [Float]

    public init(embedding: [Float]) {
        self.embedding = embedding
    }

    enum CodingKeys: String, CodingKey {
        case embedding
    }
}

/// Request for generate with streaming in Ollama
public struct OllamaGenerateRequest: Codable, Sendable {
    public let model: String
    public let prompt: String
    public let stream: Bool
    public let options: OllamaOptions?
    public let keepAlive: String?

    public init(
        model: String,
        prompt: String,
        stream: Bool = false,
        options: OllamaOptions? = nil,
        keepAlive: String? = nil
    ) {
        self.model = model
        self.prompt = prompt
        self.stream = stream
        self.options = options
        self.keepAlive = keepAlive
    }

    enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case stream
        case options
        case keepAlive = "keep_alive"
    }
}

/// Request for model pull with streaming in Ollama
public struct OllamaPullRequest: Codable, Sendable {
    public let name: String
    public let stream: Bool

    public init(name: String, stream: Bool = true) {
        self.name = name
        self.stream = stream
    }

    enum CodingKeys: String, CodingKey {
        case name
        case stream
    }
}

/// Request for model deletion in Ollama
public struct OllamaDeleteRequest: Codable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case name
    }
}

/// Response for listing models in Ollama
public struct OllamaModelsResponse: Codable, Sendable {
    public let models: [OllamaModelInfo]

    public init(models: [OllamaModelInfo]) {
        self.models = models
    }

    enum CodingKeys: String, CodingKey {
        case models
    }
}

// MARK: - Helper Types

/// Type-erased wrapper for any Codable value
public enum AnyCodable: Codable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case object([String: AnyCodable])

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: AnyCodable].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }
}
