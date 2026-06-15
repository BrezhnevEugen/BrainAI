import Foundation

// MARK: - Wiki Page Kind

public enum WikiPageKind: String, Codable, CaseIterable, Sendable {
    case index
    case log
    case source
    case entity
    case concept
    case synthesis
    case decision
    case contradiction
    case question
    case user
    case inbox
    case unknown

    public var displayName: String {
        switch self {
        case .index: "Index"
        case .log: "Log"
        case .source: "Source"
        case .entity: "Entity"
        case .concept: "Concept"
        case .synthesis: "Synthesis"
        case .decision: "Decision"
        case .contradiction: "Contradiction"
        case .question: "Question"
        case .user: "User Memory"
        case .inbox: "Inbox"
        case .unknown: "Unknown"
        }
    }
}

// MARK: - Wiki Frontmatter

public struct WikiFrontmatter: Codable, Equatable, Sendable {
    public var values: [String: String]

    public init(values: [String: String] = [:]) {
        self.values = values
    }

    public subscript(_ key: String) -> String? {
        get { values[key] }
        set { values[key] = newValue }
    }
}

// MARK: - Wiki Backlink

public struct WikiBacklink: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var sourcePath: String
    public var title: String

    public init(id: UUID = UUID(), sourcePath: String, title: String) {
        self.id = id
        self.sourcePath = sourcePath
        self.title = title
    }
}

// MARK: - Wiki Page

public struct WikiPage: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var path: String
    public var slug: String
    public var title: String
    public var kind: WikiPageKind
    public var frontmatter: WikiFrontmatter
    public var markdown: String
    public var backlinks: [WikiBacklink]
    public var sourceIDs: [String]
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        path: String,
        slug: String,
        title: String,
        kind: WikiPageKind,
        frontmatter: WikiFrontmatter = WikiFrontmatter(),
        markdown: String,
        backlinks: [WikiBacklink] = [],
        sourceIDs: [String] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.path = path
        self.slug = slug
        self.title = title
        self.kind = kind
        self.frontmatter = frontmatter
        self.markdown = markdown
        self.backlinks = backlinks
        self.sourceIDs = sourceIDs
        self.updatedAt = updatedAt
    }
}
