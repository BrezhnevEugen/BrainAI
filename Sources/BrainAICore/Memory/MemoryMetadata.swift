import Foundation

// MARK: - Raw Source Manifest Entry

public struct RawSourceManifestEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var sourceType: String
    public var rawPath: String?
    public var checksum: String?
    public var byteCount: Int?
    public var wikiPath: String
    public var lightRAGTrackID: String?
    public var originalPath: String?
    public var importedAt: Date

    public init(
        id: String,
        title: String,
        sourceType: String,
        rawPath: String? = nil,
        checksum: String? = nil,
        byteCount: Int? = nil,
        wikiPath: String,
        lightRAGTrackID: String?,
        originalPath: String?,
        importedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.sourceType = sourceType
        self.rawPath = rawPath
        self.checksum = checksum
        self.byteCount = byteCount
        self.wikiPath = wikiPath
        self.lightRAGTrackID = lightRAGTrackID
        self.originalPath = originalPath
        self.importedAt = importedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case sourceType = "source_type"
        case rawPath = "raw_path"
        case checksum
        case byteCount = "byte_count"
        case wikiPath = "wiki_path"
        case lightRAGTrackID = "light_rag_track_id"
        case originalPath = "original_path"
        case importedAt = "imported_at"
    }
}

// MARK: - Wiki Review Item

public enum WikiReviewStatus: String, Codable, Sendable {
    case draft
    case needsReview = "needs_review"
    case accepted
    case rejected
    case superseded
    case autoAccepted = "auto_accepted"
}

public struct WikiReviewItem: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var pagePath: String
    public var status: WikiReviewStatus
    public var reason: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        pagePath: String,
        status: WikiReviewStatus = .needsReview,
        reason: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.pagePath = pagePath
        self.status = status
        self.reason = reason
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case pagePath = "page_path"
        case status
        case reason
        case createdAt = "created_at"
    }
}

// MARK: - Wiki Sync State

public struct WikiSyncStateEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: String { pagePath }
    public var pagePath: String
    public var checksum: String
    public var lightRAGTrackID: String
    public var syncedAt: Date

    public init(
        pagePath: String,
        checksum: String,
        lightRAGTrackID: String,
        syncedAt: Date = Date()
    ) {
        self.pagePath = pagePath
        self.checksum = checksum
        self.lightRAGTrackID = lightRAGTrackID
        self.syncedAt = syncedAt
    }

    enum CodingKeys: String, CodingKey {
        case pagePath = "page_path"
        case checksum
        case lightRAGTrackID = "light_rag_track_id"
        case syncedAt = "synced_at"
    }
}
