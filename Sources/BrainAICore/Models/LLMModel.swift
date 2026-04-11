import Foundation

// MARK: - LLM Model

/// Descriptor for a large language model
public struct LLMModel: Identifiable, Codable, Sendable, Hashable {
    /// Unique identifier for the model
    public let id: String

    /// Human-readable name of the model
    public let name: String

    /// Parameter size (e.g., "7B", "13B", "70B")
    public let parameterSize: String

    /// Estimated RAM requirement in bytes
    public let ramEstimate: UInt64?

    /// Set of capabilities this model has
    public let capabilities: Set<ModelCapability>

    /// Context window size in tokens
    public let contextWindow: Int

    public init(
        id: String,
        name: String,
        parameterSize: String,
        ramEstimate: UInt64? = nil,
        capabilities: Set<ModelCapability> = [],
        contextWindow: Int = 2048
    ) {
        self.id = id
        self.name = name
        self.parameterSize = parameterSize
        self.ramEstimate = ramEstimate
        self.capabilities = capabilities
        self.contextWindow = contextWindow
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case parameterSize = "parameter_size"
        case ramEstimate = "ram_estimate"
        case capabilities
        case contextWindow = "context_window"
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: LLMModel, rhs: LLMModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Embedding Model

/// Descriptor for an embedding model
public struct EmbeddingModel: Identifiable, Codable, Sendable, Hashable {
    /// Unique identifier for the model
    public let id: String

    /// Human-readable name of the model
    public let name: String

    /// Dimension of the embedding vectors
    public let dimension: Int

    /// Maximum number of tokens the model accepts
    public let maxTokens: Int

    /// Whether the model supports multiple languages
    public let multilingual: Bool

    /// Size of the model on disk in bytes
    public let sizeOnDisk: UInt64?

    public init(
        id: String,
        name: String,
        dimension: Int,
        maxTokens: Int = 512,
        multilingual: Bool = false,
        sizeOnDisk: UInt64? = nil
    ) {
        self.id = id
        self.name = name
        self.dimension = dimension
        self.maxTokens = maxTokens
        self.multilingual = multilingual
        self.sizeOnDisk = sizeOnDisk
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case dimension
        case maxTokens = "max_tokens"
        case multilingual
        case sizeOnDisk = "size_on_disk"
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: EmbeddingModel, rhs: EmbeddingModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Ranked Document

/// A document ranked by relevance score in search results
public struct RankedDocument: Identifiable, Codable, Sendable, Hashable {
    /// Index in the ranked results
    public let index: Int

    /// Relevance score (typically 0.0 to 1.0)
    public let score: Double

    /// The document text content
    public let text: String

    public var id: Int { index }

    public init(index: Int, score: Double, text: String) {
        self.index = index
        self.score = score
        self.text = text
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(index)
    }

    public static func == (lhs: RankedDocument, rhs: RankedDocument) -> Bool {
        lhs.index == rhs.index
    }
}
