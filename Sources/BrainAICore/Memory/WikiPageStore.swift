import CryptoKit
import Foundation

// MARK: - Wiki Store Error

public enum WikiPageStoreError: LocalizedError {
    case invalidPath(String)
    case pageNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            "Invalid wiki page path: \(path)"
        case .pageNotFound(let path):
            "Wiki page not found: \(path)"
        }
    }
}

// MARK: - Wiki Page Store

public actor WikiPageStore {
    public let workspaceURL: URL
    public let rawURL: URL
    public let wikiURL: URL
    public let schemaURL: URL
    public let metadataURL: URL

    private let fileManager: FileManager
    private let metadataEncoder: JSONEncoder
    private let metadataDecoder: JSONDecoder

    public init(workspaceURL: URL, fileManager: FileManager = .default) {
        self.workspaceURL = workspaceURL
        self.rawURL = workspaceURL.appendingPathComponent("raw", isDirectory: true)
        self.wikiURL = workspaceURL.appendingPathComponent("wiki", isDirectory: true)
        self.schemaURL = workspaceURL.appendingPathComponent("schema", isDirectory: true)
        self.metadataURL = workspaceURL.appendingPathComponent("metadata", isDirectory: true)
        self.fileManager = fileManager
        self.metadataEncoder = Self.makeMetadataEncoder()
        self.metadataDecoder = Self.makeMetadataDecoder()
    }

    public init(workspaceSlug: String, fileManager: FileManager = .default) {
        let workspaceURL = URL.brainAIWorkspaces.appendingPathComponent(workspaceSlug, isDirectory: true)
        self.workspaceURL = workspaceURL
        self.rawURL = workspaceURL.appendingPathComponent("raw", isDirectory: true)
        self.wikiURL = workspaceURL.appendingPathComponent("wiki", isDirectory: true)
        self.schemaURL = workspaceURL.appendingPathComponent("schema", isDirectory: true)
        self.metadataURL = workspaceURL.appendingPathComponent("metadata", isDirectory: true)
        self.fileManager = fileManager
        self.metadataEncoder = Self.makeMetadataEncoder()
        self.metadataDecoder = Self.makeMetadataDecoder()
    }

    public func ensureScaffold() throws {
        try workspaceURL.ensureDirectoryExists()
        try rawURL.ensureDirectoryExists()
        try wikiURL.ensureDirectoryExists()
        try schemaURL.ensureDirectoryExists()
        try metadataURL.ensureDirectoryExists()
        for folder in Self.defaultRawFolders {
            try rawURL.appendingPathComponent(folder, isDirectory: true).ensureDirectoryExists()
        }
        for folder in Self.defaultFolders {
            try wikiURL.appendingPathComponent(folder, isDirectory: true).ensureDirectoryExists()
        }

        let indexURL = wikiURL.appendingPathComponent("index.md")
        if !fileManager.fileExists(atPath: indexURL.path) {
            try Self.defaultIndexMarkdown.write(to: indexURL, atomically: true, encoding: .utf8)
        }

        let logURL = wikiURL.appendingPathComponent("log.md")
        if !fileManager.fileExists(atPath: logURL.path) {
            try Self.defaultLogMarkdown.write(to: logURL, atomically: true, encoding: .utf8)
        }

        let schemaFileURL = schemaURL.appendingPathComponent("MEMORY_SCHEMA.md")
        if !fileManager.fileExists(atPath: schemaFileURL.path) {
            try Self.defaultMemorySchemaMarkdown.write(to: schemaFileURL, atomically: true, encoding: .utf8)
        }
    }

    public func listPages() throws -> [WikiPage] {
        try ensureScaffold()

        guard let enumerator = fileManager.enumerator(
            at: wikiURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var pages: [WikiPage] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }
            pages.append(try readPage(at: relativePath(for: fileURL)))
        }

        return pages.sorted {
            if $0.kind == $1.kind { return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
        }
    }

    public func listSourceManifestEntries() throws -> [RawSourceManifestEntry] {
        try ensureScaffold()
        let url = metadataURL.appendingPathComponent("source_manifest.json")
        return try readJSONFile(at: url, default: [RawSourceManifestEntry]())
    }

    public func listReviewItems() throws -> [WikiReviewItem] {
        try ensureScaffold()
        let url = metadataURL.appendingPathComponent("review_queue.json")
        return try readJSONFile(at: url, default: [WikiReviewItem]())
    }

    public func listWikiSyncState() throws -> [WikiSyncStateEntry] {
        try ensureScaffold()
        let url = metadataURL.appendingPathComponent("wiki_sync_state.json")
        return try readJSONFile(at: url, default: [WikiSyncStateEntry]())
    }

    public func syncState(for page: WikiPage) throws -> WikiSyncStateEntry? {
        try listWikiSyncState().first { $0.pagePath == page.path }
    }

    public func needsLightRAGSync(_ page: WikiPage) throws -> Bool {
        guard let state = try syncState(for: page) else { return true }
        return state.checksum != Self.sha256Hex(for: page.markdown)
    }

    public func recordLightRAGSync(page: WikiPage, trackId: String) throws {
        try ensureScaffold()
        let url = metadataURL.appendingPathComponent("wiki_sync_state.json")
        var entries: [WikiSyncStateEntry] = try readJSONFile(at: url, default: [])
        entries.removeAll { $0.pagePath == page.path }
        entries.append(
            WikiSyncStateEntry(
                pagePath: page.path,
                checksum: Self.sha256Hex(for: page.markdown),
                lightRAGTrackID: trackId
            )
        )
        try writeJSONFile(entries.sorted { $0.pagePath < $1.pagePath }, to: url)
        try appendLog("Synced accepted wiki page [[\(page.path)]] to LightRAG track \(trackId)")
    }

    public func updateReviewItemStatus(id: UUID, status: WikiReviewStatus) throws {
        try ensureScaffold()
        let url = metadataURL.appendingPathComponent("review_queue.json")
        var items: [WikiReviewItem] = try readJSONFile(at: url, default: [])
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw WikiPageStoreError.pageNotFound("review item \(id)")
        }

        items[index].status = status
        try writeJSONFile(items.sorted { $0.createdAt < $1.createdAt }, to: url)
        try updatePageStatus(at: items[index].pagePath, status: status)
        try appendLog("\(status.rawValue) review item for [[\(items[index].pagePath)]]")
    }

    /// Read the workspace memory schema document (`schema/MEMORY_SCHEMA.md`).
    public func readMemorySchema() throws -> String {
        try ensureScaffold()
        let url = schemaURL.appendingPathComponent("MEMORY_SCHEMA.md")
        guard fileManager.fileExists(atPath: url.path) else {
            return Self.defaultMemorySchemaMarkdown
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func readPage(at path: String) throws -> WikiPage {
        try ensureScaffold()
        let pageURL = try urlForPage(path)
        guard fileManager.fileExists(atPath: pageURL.path) else {
            throw WikiPageStoreError.pageNotFound(path)
        }

        let raw = try String(contentsOf: pageURL, encoding: .utf8)
        let modifiedAt = try pageURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date()
        return parsePage(raw, path: relativePath(for: pageURL), updatedAt: modifiedAt)
    }

    public func writePage(_ page: WikiPage) throws {
        try ensureScaffold()
        let pageURL = try urlForPage(page.path)
        try pageURL.deletingLastPathComponent().ensureDirectoryExists()
        try page.markdown.write(to: pageURL, atomically: true, encoding: .utf8)
    }

    @discardableResult
    public func createSourcePage(
        title: String,
        content: String,
        sourceType: String,
        trackId: String?,
        originalPath: String? = nil
    ) throws -> WikiPage {
        try ensureScaffold()

        let slug = uniqueSlug(for: title, in: "sources")
        let sourceID = "src_\(UUID().uuidString.lowercased())"
        let now = ISO8601DateFormatter().string(from: Date())
        let excerpt = Self.excerpt(from: content)
        let pagePath = "sources/\(slug).md"
        let rawRecord = try writeRawSource(
            id: sourceID,
            title: title,
            content: content,
            sourceType: sourceType
        )

        var frontmatter = """
        ---
        type: source
        source_id: \(sourceID)
        source_type: \(sourceType)
        raw_path: \(rawRecord.path)
        checksum: \(rawRecord.checksum)
        status: needs_review
        created_at: \(now)
        updated_at: \(now)
        confidence: medium
        """

        if let trackId, !trackId.isEmpty {
            frontmatter += "\nlight_rag_track_id: \(trackId)"
        }

        if let originalPath, !originalPath.isEmpty {
            frontmatter += "\noriginal_path: \"\(Self.escapeYAML(originalPath))\""
        }

        frontmatter += "\n---"

        let markdown = """
        \(frontmatter)
        # \(title)

        ## TLDR

        Pending synthesis.

        ## Key Claims

        - Pending extraction.

        ## Entities

        - Pending extraction.

        ## Relations

        - Pending extraction.

        ## Open Questions

        - What should be promoted from this source into entity, concept, or decision pages?

        ## Source Excerpt

        \(excerpt)
        """

        let page = WikiPage(
            path: pagePath,
            slug: slug,
            title: title,
            kind: .source,
            markdown: markdown,
            sourceIDs: [sourceID]
        )
        try writePage(page)
        try appendSourceManifestEntry(
            RawSourceManifestEntry(
                id: sourceID,
                title: title,
                sourceType: sourceType,
                rawPath: rawRecord.path,
                checksum: rawRecord.checksum,
                byteCount: rawRecord.byteCount,
                wikiPath: pagePath,
                lightRAGTrackID: trackId,
                originalPath: originalPath
            )
        )
        try appendReviewItem(
            WikiReviewItem(
                title: "Review \(title)",
                pagePath: pagePath,
                reason: "New source page generated during ingest."
            )
        )
        try appendLog("Created source page [[\(pagePath)]] for \(title)")
        return page
    }

    public func readRawSource(for entry: RawSourceManifestEntry) throws -> String? {
        try ensureScaffold()
        guard let rawPath = entry.rawPath else { return nil }
        let url = try urlForRawSource(rawPath)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    @discardableResult
    public func createSynthesisPage(
        title: String,
        question: String,
        answer: String,
        ragContext: String?,
        model: String?,
        searchMode: SearchMode
    ) throws -> WikiPage {
        try ensureScaffold()

        let slug = uniqueSlug(for: title, in: "syntheses")
        let now = ISO8601DateFormatter().string(from: Date())
        let pagePath = "syntheses/\(slug).md"
        let contextSection = ragContext.flatMap { context -> String? in
            let trimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return """

            ## Retrieved Context

            \(Self.excerpt(from: trimmed, maxLength: 2400))
            """
        } ?? ""

        var frontmatter = """
        ---
        type: synthesis
        status: needs_review
        created_at: \(now)
        updated_at: \(now)
        search_mode: \(searchMode.rawValue)
        confidence: medium
        """

        if let model, !model.isEmpty {
            frontmatter += "\nmodel: \"\(Self.escapeYAML(model))\""
        }

        frontmatter += "\n---"

        let markdown = """
        \(frontmatter)
        # \(title)

        ## Question

        \(question)

        ## Answer

        \(answer)

        ## Review Checklist

        - Confirm that the answer is supported by the retrieved context or known workspace memory.
        - Promote stable decisions into `decisions/` and durable concepts into `concepts/`.
        - Add contradictions or open questions if the answer conflicts with existing memory.
        \(contextSection)
        """

        let page = WikiPage(
            path: pagePath,
            slug: slug,
            title: title,
            kind: .synthesis,
            markdown: markdown
        )
        try writePage(page)
        try appendReviewItem(
            WikiReviewItem(
                title: "Review synthesis: \(title)",
                pagePath: pagePath,
                reason: "AI chat answer saved as compiled memory."
            )
        )
        try appendLog("Created synthesis page [[\(pagePath)]] from chat answer")
        return page
    }

    /// Append a single timestamped entry to the workspace memory log.
    /// Low-friction memory for agents ("remember that …").
    public func appendLogEntry(_ message: String) throws {
        try ensureScaffold()
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw WikiPageStoreError.invalidPath("empty log message")
        }
        try appendLog(trimmed)
    }

    /// Create an agent-authored memory page of the given kind and queue it for review.
    /// - Parameters:
    ///   - kind: Target page kind (concept, decision, entity, question, contradiction, user, synthesis, inbox).
    ///   - title: Human-readable page title.
    ///   - body: Markdown body (without the H1 title or frontmatter).
    ///   - confidence: Confidence label stored in frontmatter.
    ///   - tags: Optional tags recorded in frontmatter.
    ///   - sourceLinks: Optional wiki paths to cite as sources (rendered as backlinks).
    ///   - reason: Human-readable reason recorded in the review queue.
    ///   - autoAccept: When true, the page is stored as `auto_accepted` instead of `needs_review`.
    /// - Returns: The created page.
    @discardableResult
    public func createMemoryPage(
        kind: WikiPageKind,
        title: String,
        body: String,
        domain: String? = nil,
        confidence: String = "medium",
        tags: [String] = [],
        sourceLinks: [String] = [],
        reason: String = "Created by an agent via MCP.",
        autoAccept: Bool = false
    ) throws -> WikiPage {
        try ensureScaffold()

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            throw WikiPageStoreError.invalidPath("empty page title")
        }

        let folder = Self.defaultFolder(for: kind)
        let slug = uniqueSlug(for: cleanTitle, in: folder)
        let pagePath = "\(folder)/\(slug).md"
        let now = ISO8601DateFormatter().string(from: Date())
        let status: WikiReviewStatus = autoAccept ? .autoAccepted : .needsReview

        var frontmatter = """
        ---
        type: \(kind.rawValue)
        status: \(status.rawValue)
        created_at: \(now)
        updated_at: \(now)
        confidence: \(confidence)
        """

        if let domain = domain?.trimmingCharacters(in: .whitespacesAndNewlines), !domain.isEmpty {
            frontmatter += "\ndomain: \(domain)"
        }

        if !tags.isEmpty {
            let list = tags.map { "\"\(Self.escapeYAML($0))\"" }.joined(separator: ", ")
            frontmatter += "\ntags: [\(list)]"
        }

        frontmatter += "\n---"

        var markdown = """
        \(frontmatter)
        # \(cleanTitle)

        \(body.trimmingCharacters(in: .whitespacesAndNewlines))
        """

        let cleanedLinks = sourceLinks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !cleanedLinks.isEmpty {
            markdown += "\n\n## Sources\n\n"
            for link in cleanedLinks {
                markdown += "- [[\(link)]]\n"
            }
        }

        let page = WikiPage(
            path: pagePath,
            slug: slug,
            title: cleanTitle,
            kind: kind,
            markdown: markdown
        )
        try writePage(page)
        try appendReviewItem(
            WikiReviewItem(
                title: "Review \(kind.displayName): \(cleanTitle)",
                pagePath: pagePath,
                status: status,
                reason: reason
            )
        )
        try appendLog("Created \(kind.rawValue) page [[\(pagePath)]] — \(cleanTitle)")
        return page
    }

    public func regenerateIndex() throws {
        let pages = try listPages().filter { $0.path != "index.md" && $0.path != "log.md" }
        let grouped = Dictionary(grouping: pages, by: \.kind)
        var markdown = """
        ---
        type: index
        status: accepted
        ---
        # Wiki Index

        """

        for kind in WikiPageKind.allCases where kind != .unknown {
            guard let items = grouped[kind], !items.isEmpty else { continue }
            markdown += "\n## \(kind.displayName)\n\n"
            for page in items.sorted(by: { $0.title < $1.title }) {
                markdown += "- [[\(page.path)]] \(page.title)\n"
            }
        }

        let index = WikiPage(path: "index.md", slug: "index", title: "Wiki Index", kind: .index, markdown: markdown)
        try writePage(index)
    }

    private func appendLog(_ message: String) throws {
        let logURL = try urlForPage("log.md")
        let now = ISO8601DateFormatter().string(from: Date())
        let entry = "- \(now) \(message)\n"

        if fileManager.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            if let data = entry.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
        } else {
            try (Self.defaultLogMarkdown + "\n" + entry).write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

    private func appendSourceManifestEntry(_ entry: RawSourceManifestEntry) throws {
        let url = metadataURL.appendingPathComponent("source_manifest.json")
        var entries: [RawSourceManifestEntry] = try readJSONFile(at: url, default: [])
        entries.removeAll { $0.id == entry.id || $0.wikiPath == entry.wikiPath }
        entries.append(entry)
        try writeJSONFile(entries.sorted { $0.importedAt < $1.importedAt }, to: url)
    }

    private func writeRawSource(
        id: String,
        title: String,
        content: String,
        sourceType: String
    ) throws -> (path: String, checksum: String, byteCount: Int) {
        let folder = Self.rawFolder(for: sourceType)
        let filename = "\(id)-\(Self.slugify(title)).txt"
        let relativePath = "\(folder)/\(filename)"
        let url = try urlForRawSource(relativePath)
        try url.deletingLastPathComponent().ensureDirectoryExists()

        let data = Data(content.utf8)
        try data.write(to: url, options: .atomic)
        let digest = Self.sha256Hex(for: data)
        return (relativePath, digest, data.count)
    }

    private func urlForRawSource(_ path: String) throws -> URL {
        guard !path.contains(".."), !path.hasPrefix("/") else {
            throw WikiPageStoreError.invalidPath(path)
        }
        return rawURL.appendingPathComponent(path)
    }

    private func appendReviewItem(_ item: WikiReviewItem) throws {
        let url = metadataURL.appendingPathComponent("review_queue.json")
        var items: [WikiReviewItem] = try readJSONFile(at: url, default: [])
        items.removeAll { $0.pagePath == item.pagePath && $0.status == .needsReview }
        items.append(item)
        try writeJSONFile(items.sorted { $0.createdAt < $1.createdAt }, to: url)
    }

    private func updatePageStatus(at path: String, status: WikiReviewStatus) throws {
        let page = try readPage(at: path)
        let updated = Self.replacingFrontmatterValue(
            in: page.markdown,
            key: "status",
            value: status.rawValue
        )
        try updated.write(to: try urlForPage(path), atomically: true, encoding: .utf8)
    }

    private func readJSONFile<T: Decodable>(at url: URL, default defaultValue: T) throws -> T {
        guard fileManager.fileExists(atPath: url.path) else { return defaultValue }
        let data = try Data(contentsOf: url)
        return try metadataDecoder.decode(T.self, from: data)
    }

    private func writeJSONFile<T: Encodable>(_ value: T, to url: URL) throws {
        try url.deletingLastPathComponent().ensureDirectoryExists()
        let data = try metadataEncoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func parsePage(_ raw: String, path: String, updatedAt: Date) -> WikiPage {
        let parsed = Self.splitFrontmatter(raw)
        let title = Self.extractTitle(from: parsed.body) ?? Self.titleFromPath(path)
        let kind = Self.kind(for: path, frontmatter: parsed.frontmatter)
        let slug = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let sourceIDs = parsed.frontmatter.values["source_id"].map { [$0] } ?? []

        return WikiPage(
            path: path,
            slug: slug,
            title: title,
            kind: kind,
            frontmatter: parsed.frontmatter,
            markdown: raw,
            sourceIDs: sourceIDs,
            updatedAt: updatedAt
        )
    }

    private func urlForPage(_ path: String) throws -> URL {
        guard !path.contains(".."), !path.hasPrefix("/") else {
            throw WikiPageStoreError.invalidPath(path)
        }
        let normalized = path.hasSuffix(".md") ? path : "\(path).md"
        return wikiURL.appendingPathComponent(normalized)
    }

    private func relativePath(for url: URL) -> String {
        let base = wikiURL.standardizedFileURL.path
        let full = url.standardizedFileURL.path
        guard full.hasPrefix(base) else { return url.lastPathComponent }
        return String(full.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func uniqueSlug(for title: String, in folder: String) -> String {
        let base = Self.slugify(title)
        var candidate = base
        var counter = 2

        while fileManager.fileExists(atPath: wikiURL.appendingPathComponent(folder).appendingPathComponent("\(candidate).md").path) {
            candidate = "\(base)-\(counter)"
            counter += 1
        }

        return candidate
    }
}

private extension WikiPageStore {
    static func makeMetadataEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func makeMetadataDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static let defaultFolders = [
        "inbox",
        "entities",
        "concepts",
        "sources",
        "syntheses",
        "decisions",
        "contradictions",
        "questions",
        "user"
    ]

    static func defaultFolder(for kind: WikiPageKind) -> String {
        switch kind {
        case .entity: "entities"
        case .concept: "concepts"
        case .source: "sources"
        case .synthesis: "syntheses"
        case .decision: "decisions"
        case .contradiction: "contradictions"
        case .question: "questions"
        case .user: "user"
        case .inbox, .index, .log, .unknown: "inbox"
        }
    }

    static let defaultRawFolders = [
        "documents",
        "notes",
        "chats",
        "clips",
        "assets"
    ]

    static let defaultIndexMarkdown = """
    ---
    type: index
    status: accepted
    ---
    # Wiki Index

    This workspace wiki is ready for compiled memory pages.
    """

    static let defaultLogMarkdown = """
    ---
    type: log
    status: accepted
    ---
    # Wiki Log

    """

    static let defaultMemorySchemaMarkdown = """
    # BrainAI Memory Schema

    Persistent personal memory that spans sessions, agents (Cursor, Claude, Cowork), and
    life domains. Sessions are ephemeral; this memory is not. Query it at the start of a
    task and save durable facts as they appear.

    This workspace uses a two-layer memory model:

    - `raw/` stores immutable source text exactly as it was imported.
    - `wiki/` stores compiled, reviewable Markdown memory.
    - `metadata/review_queue.json` stores proposed wiki changes that need a human decision.

    ## Ingest Rules

    1. Preserve every imported source in `raw/` before synthesis.
    2. Create or update a `wiki/sources/` page with source metadata, a short excerpt, and open questions.
    3. Mark new generated pages as `needs_review` until accepted by the user.
    4. Promote stable facts into entity, concept, decision, synthesis, contradiction, or question pages only with source links.

    ## Page Status

    - `draft`: generated but not yet queued.
    - `needs_review`: waiting for user review.
    - `accepted`: approved as workspace memory.
    - `rejected`: kept for audit, ignored for answers.
    - `superseded`: replaced by a newer page or claim.
    - `auto_accepted`: trusted by workspace automation rules.

    ## Taxonomy

    Use one consistent taxonomy across every agent so retrieval stays reliable.

    ### Entity types

    | Type | Purpose |
    |------|---------|
    | `Project` | Any project or product |
    | `Technology` | Languages, frameworks, tools, hardware |
    | `Component` | Modules, services, files, circuits |
    | `Decision` | Architecture and design choices (with reasoning) |
    | `Bug` | Bugs with symptoms, root cause, and solution |
    | `Convention` | Rules and standards |
    | `Person` | People (colleagues, contacts) |
    | `Preference` | User preferences and habits |
    | `Environment` | Hardware, OS, configs |
    | `Snippet` | Reusable code patterns |
    | `Resource` | Useful links, docs, references |

    ### Relation patterns

    `Project → uses → Technology`, `Component → belongs_to → Project`,
    `Decision → affects → Component`, `Bug → found_in → Component`,
    `Person → prefers → Preference`, `Person → works_on → Project`,
    `Technology → compatible_with → Technology`, `Snippet → applies_to → Technology`,
    `Project → depends_on → Technology`.

    ### Description / tag format

    Tag durable facts as `domain/category-topic`.

    - Domains: `work`, `personal-project`, `hobby-*` (e.g. `hobby-esp32`), `personal`.
    - Categories: `architecture-*`, `bug-fix-*`, `config-*`, `convention-*`, `preference-*`,
      `setup-*`, `api-*`, `meeting-*`, `research-*`, `snippet-*`, `hardware-*`, `protocol-*`.

    Example: `personal-project/architecture-brainai-llm-model`.

    ## Writing Guidance

    - Capture facts that a fresh session in any agent would benefit from — not trivia.
    - Always include the **why** (reasoning), concrete numbers, and versions.
    - Prefer a few high-quality entries over many shallow ones.
    - Start longer notes with a `[YYYY-MM-DD]` date and write in English for consistent retrieval.
    - Do not save trivial fixes, temporary debugging state, or facts already documented in code.
    """

    static func splitFrontmatter(_ raw: String) -> (frontmatter: WikiFrontmatter, body: String) {
        guard raw.hasPrefix("---\n") else {
            return (WikiFrontmatter(), raw)
        }

        let lines = raw.components(separatedBy: .newlines)
        guard let endIndex = lines.dropFirst().firstIndex(of: "---") else {
            return (WikiFrontmatter(), raw)
        }

        var values: [String: String] = [:]
        for line in lines[1..<endIndex] {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }

        let body = lines.dropFirst(endIndex + 1).joined(separator: "\n")
        return (WikiFrontmatter(values: values), body)
    }

    static func replacingFrontmatterValue(in raw: String, key: String, value: String) -> String {
        guard raw.hasPrefix("---\n") else {
            return """
            ---
            \(key): \(value)
            ---
            \(raw)
            """
        }

        var lines = raw.components(separatedBy: .newlines)
        guard let endIndex = lines.dropFirst().firstIndex(of: "---") else {
            return raw
        }

        var replaced = false
        for index in 1..<endIndex {
            if lines[index].hasPrefix("\(key):") {
                lines[index] = "\(key): \(value)"
                replaced = true
                break
            }
        }

        if !replaced {
            lines.insert("\(key): \(value)", at: endIndex)
        }

        return lines.joined(separator: "\n")
    }

    static func extractTitle(from markdown: String) -> String? {
        markdown
            .components(separatedBy: .newlines)
            .first { $0.hasPrefix("# ") }?
            .dropFirst(2)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func titleFromPath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    static func slugify(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let lowercased = value.lowercased()
        var slug = ""
        var previousWasDash = false

        for scalar in lowercased.unicodeScalars {
            if allowed.contains(scalar) {
                slug.unicodeScalars.append(scalar)
                previousWasDash = false
            } else if !previousWasDash {
                slug.append("-")
                previousWasDash = true
            }
        }

        let trimmed = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return trimmed.isEmpty ? "source" : trimmed
    }

    static func excerpt(from content: String, maxLength: Int = 1200) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(trimmed.prefix(maxLength))
        let suffix = trimmed.count > maxLength ? "\n\n..." : ""
        return "```text\n\(prefix)\(suffix)\n```"
    }

    static func sha256Hex(for value: String) -> String {
        sha256Hex(for: Data(value.utf8))
    }

    static func sha256Hex(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func escapeYAML(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func rawFolder(for sourceType: String) -> String {
        switch sourceType.lowercased() {
        case "note", "notes":
            "notes"
        case "chat", "conversation", "conversations":
            "chats"
        case "clip", "web", "url":
            "clips"
        case "asset", "image", "pdf":
            "assets"
        default:
            "documents"
        }
    }

    static func kind(for path: String, frontmatter: WikiFrontmatter) -> WikiPageKind {
        if let type = frontmatter.values["type"], let kind = WikiPageKind(rawValue: type) {
            return kind
        }

        if path == "index.md" { return .index }
        if path == "log.md" { return .log }

        let folder = path.split(separator: "/").first.map(String.init)
        switch folder {
        case "sources": return .source
        case "entities": return .entity
        case "concepts": return .concept
        case "syntheses": return .synthesis
        case "decisions": return .decision
        case "contradictions": return .contradiction
        case "questions": return .question
        case "user": return .user
        case "inbox": return .inbox
        default: return .unknown
        }
    }
}
