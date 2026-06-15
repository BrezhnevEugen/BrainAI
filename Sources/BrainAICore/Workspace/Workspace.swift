import Foundation

// MARK: - Workspace

/// Represents a knowledge graph workspace
public struct Workspace: Identifiable, Codable, Sendable {
    /// Unique identifier
    public let id: UUID

    /// Display name
    public var name: String

    /// URL-safe slug
    public var slug: String

    /// SF Symbol name for display
    public var icon: String

    /// Hex color string for UI
    public var color: String

    /// Optional description
    public var description: String?

    /// Optional default memory domain (work, personal-project, hobby-*, personal)
    public var domain: String?

    /// Port the workspace's LightRAG service runs on
    public var port: UInt16

    /// File system path to workspace data
    public var dataPath: URL

    /// Role configuration for embeddings (nil = use global)
    public var embeddingRole: RoleConfig?

    /// Role configuration for extraction (nil = use global)
    public var extractionRole: RoleConfig?

    /// Role configuration for reranking (nil = use global)
    public var rerankerRole: RoleConfig?

    /// Role configuration for generation (nil = use global)
    public var generationRole: RoleConfig?

    /// Policy for starting this workspace
    public var startPolicy: WorkspaceStartPolicy

    /// Whether data is encrypted at rest
    public var isEncrypted: Bool

    /// Whether workspace data is shared
    public var isShared: Bool

    /// Share endpoint URL if shared
    public var shareEndpoint: String?

    /// Approximate number of entities
    public var entityCount: Int

    /// Approximate number of relations
    public var relationCount: Int

    /// Approximate number of documents
    public var documentCount: Int

    /// Last activity timestamp
    public var lastActivity: Date

    /// Initialize a workspace
    public init(
        id: UUID = UUID(),
        name: String,
        slug: String,
        icon: String = "circle.fill",
        color: String = "#6B7280",
        description: String? = nil,
        domain: String? = nil,
        port: UInt16,
        dataPath: URL,
        embeddingRole: RoleConfig? = nil,
        extractionRole: RoleConfig? = nil,
        rerankerRole: RoleConfig? = nil,
        generationRole: RoleConfig? = nil,
        startPolicy: WorkspaceStartPolicy = .onDemand,
        isEncrypted: Bool = false,
        isShared: Bool = false,
        shareEndpoint: String? = nil,
        entityCount: Int = 0,
        relationCount: Int = 0,
        documentCount: Int = 0,
        lastActivity: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.icon = icon
        self.color = color
        self.description = description
        self.domain = domain
        self.port = port
        self.dataPath = dataPath
        self.embeddingRole = embeddingRole
        self.extractionRole = extractionRole
        self.rerankerRole = rerankerRole
        self.generationRole = generationRole
        self.startPolicy = startPolicy
        self.isEncrypted = isEncrypted
        self.isShared = isShared
        self.shareEndpoint = shareEndpoint
        self.entityCount = entityCount
        self.relationCount = relationCount
        self.documentCount = documentCount
        self.lastActivity = lastActivity
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case slug
        case icon
        case color
        case description
        case domain
        case port
        case dataPath = "data_path"
        case embeddingRole = "embedding_role"
        case extractionRole = "extraction_role"
        case rerankerRole = "reranker_role"
        case generationRole = "generation_role"
        case startPolicy = "start_policy"
        case isEncrypted = "is_encrypted"
        case isShared = "is_shared"
        case shareEndpoint = "share_endpoint"
        case entityCount = "entity_count"
        case relationCount = "relation_count"
        case documentCount = "document_count"
        case lastActivity = "last_activity"
    }
}
