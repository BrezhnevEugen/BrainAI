import Foundation

// MARK: - MCP Server

/// BrainAI MCP Server — exposes knowledge base operations as MCP tools
public actor MCPServer {

    private let lightRAGClient: LightRAGClientProtocol
    private let workspaceManager: WorkspaceManager
    private var isRunning = false
    private var transport: MCPTransport?

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// BrainAI tools exposed via MCP
    public static let toolDefinitions: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "brainai_query",
            description: "Query the BrainAI knowledge base using natural language. Returns AI-generated answer with context from the knowledge graph.",
            inputSchema: MCPInputSchema(
                properties: [
                    "question": MCPPropertySchema(type: "string", description: "The question to ask"),
                    "mode": MCPPropertySchema(type: "string", description: "Search mode: local, global, hybrid, naive, mix", defaultValue: "hybrid"),
                    "top_k": MCPPropertySchema(type: "integer", description: "Number of results to retrieve", defaultValue: "40"),
                    "workspace": MCPPropertySchema(type: "string", description: "Workspace name (optional, defaults to current)")
                ],
                required: ["question"]
            )
        ),
        MCPToolDefinition(
            name: "brainai_insert",
            description: "Insert text content into the BrainAI knowledge base. The text will be chunked, entities extracted, and the knowledge graph updated.",
            inputSchema: MCPInputSchema(
                properties: [
                    "text": MCPPropertySchema(type: "string", description: "Text content to insert"),
                    "description": MCPPropertySchema(type: "string", description: "Optional description of the content"),
                    "workspace": MCPPropertySchema(type: "string", description: "Target workspace (optional)")
                ],
                required: ["text"]
            )
        ),
        MCPToolDefinition(
            name: "brainai_create_entity",
            description: "Create a new entity in the BrainAI knowledge graph.",
            inputSchema: MCPInputSchema(
                properties: [
                    "name": MCPPropertySchema(type: "string", description: "Entity name"),
                    "type": MCPPropertySchema(type: "string", description: "Entity type (e.g., Person, Concept, Organization)"),
                    "description": MCPPropertySchema(type: "string", description: "Entity description")
                ],
                required: ["name", "type"]
            )
        ),
        MCPToolDefinition(
            name: "brainai_create_relation",
            description: "Create a relationship between two entities in the BrainAI knowledge graph.",
            inputSchema: MCPInputSchema(
                properties: [
                    "source": MCPPropertySchema(type: "string", description: "Source entity name"),
                    "target": MCPPropertySchema(type: "string", description: "Target entity name"),
                    "description": MCPPropertySchema(type: "string", description: "Relationship description"),
                    "keywords": MCPPropertySchema(type: "string", description: "Comma-separated keywords")
                ],
                required: ["source", "target", "description"]
            )
        ),
        MCPToolDefinition(
            name: "brainai_search",
            description: "Search the BrainAI knowledge graph for entities and relations by label and text.",
            inputSchema: MCPInputSchema(
                properties: [
                    "label": MCPPropertySchema(type: "string", description: "Entity type/label to search within"),
                    "search_text": MCPPropertySchema(type: "string", description: "Text to search for"),
                    "max_items": MCPPropertySchema(type: "integer", description: "Maximum results", defaultValue: "50")
                ],
                required: ["label"]
            )
        ),
        MCPToolDefinition(
            name: "brainai_wiki_search",
            description: "Search BrainAI Markdown Wiki pages in the active or named workspace.",
            inputSchema: MCPInputSchema(
                properties: [
                    "query": MCPPropertySchema(type: "string", description: "Text to search for in wiki title, path, and markdown"),
                    "domain": MCPPropertySchema(type: "string", description: "Optional domain filter (work, personal-project, hobby-*, personal)"),
                    "workspace": MCPPropertySchema(type: "string", description: "Workspace slug or name (optional, defaults to active workspace)")
                ],
                required: ["query"]
            )
        ),
        MCPToolDefinition(
            name: "brainai_wiki_get_page",
            description: "Read a BrainAI Markdown Wiki page by path or slug.",
            inputSchema: MCPInputSchema(
                properties: [
                    "path_or_slug": MCPPropertySchema(type: "string", description: "Wiki page path, filename, or slug"),
                    "workspace": MCPPropertySchema(type: "string", description: "Workspace slug or name (optional, defaults to active workspace)")
                ],
                required: ["path_or_slug"]
            )
        ),
        MCPToolDefinition(
            name: "brainai_wiki_review_queue",
            description: "List pending BrainAI Wiki review items for the active or named workspace.",
            inputSchema: MCPInputSchema(
                properties: [
                    "workspace": MCPPropertySchema(type: "string", description: "Workspace slug or name (optional, defaults to active workspace)"),
                    "status": MCPPropertySchema(type: "string", description: "Review status filter: needs_review, accepted, rejected, superseded, auto_accepted")
                ],
                required: []
            )
        ),
        MCPToolDefinition(
            name: "brainai_wiki_append_log",
            description: "Append a timestamped entry to the BrainAI workspace memory log. Use for quick, low-friction facts an agent learned.",
            inputSchema: MCPInputSchema(
                properties: [
                    "message": MCPPropertySchema(type: "string", description: "The fact or event to record in the workspace log"),
                    "workspace": MCPPropertySchema(type: "string", description: "Workspace slug or name (optional, defaults to active workspace)")
                ],
                required: ["message"]
            )
        ),
        MCPToolDefinition(
            name: "brainai_wiki_create_note",
            description: "Create a reviewable BrainAI Wiki memory page (concept, decision, entity, question, contradiction, user, synthesis, or inbox). The page is queued for human review unless auto_accept is true.",
            inputSchema: MCPInputSchema(
                properties: [
                    "title": MCPPropertySchema(type: "string", description: "Page title"),
                    "body": MCPPropertySchema(type: "string", description: "Markdown body of the memory page (no H1 title or frontmatter)"),
                    "kind": MCPPropertySchema(type: "string", description: "Page kind: concept (default), decision, entity, question, contradiction, user, synthesis, inbox"),
                    "domain": MCPPropertySchema(type: "string", description: "Optional life domain: work, personal-project, hobby-* (e.g. hobby-esp32), personal"),
                    "tags": MCPPropertySchema(type: "array", description: "Optional list of tag strings"),
                    "source_links": MCPPropertySchema(type: "array", description: "Optional list of wiki page paths to cite as sources"),
                    "confidence": MCPPropertySchema(type: "string", description: "Confidence label: low, medium (default), high"),
                    "auto_accept": MCPPropertySchema(type: "boolean", description: "Store as auto_accepted instead of needs_review (default false)"),
                    "workspace": MCPPropertySchema(type: "string", description: "Workspace slug or name (optional, defaults to active workspace)")
                ],
                required: ["title", "body"]
            )
        ),
        MCPToolDefinition(
            name: "brainai_wiki_record_source",
            description: "Store an immutable raw source (note, chat, clip, document) in BrainAI memory and create a reviewable source page.",
            inputSchema: MCPInputSchema(
                properties: [
                    "title": MCPPropertySchema(type: "string", description: "Source title"),
                    "content": MCPPropertySchema(type: "string", description: "Full raw source text to preserve verbatim"),
                    "source_type": MCPPropertySchema(type: "string", description: "Source type: note (default), chat, clip, document, asset"),
                    "workspace": MCPPropertySchema(type: "string", description: "Workspace slug or name (optional, defaults to active workspace)")
                ],
                required: ["title", "content"]
            )
        ),
        MCPToolDefinition(
            name: "brainai_list_workspaces",
            description: "List BrainAI workspaces (projects). Each workspace has its own isolated memory.",
            inputSchema: MCPInputSchema(
                properties: [:],
                required: []
            )
        ),
    ]

    // MARK: - Initialization

    public init(lightRAGClient: LightRAGClientProtocol, workspaceManager: WorkspaceManager = .shared) {
        self.lightRAGClient = lightRAGClient
        self.workspaceManager = workspaceManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Server Lifecycle

    /// Start the MCP server with the given transport
    public func start(transport: MCPTransport) async throws {
        self.transport = transport
        isRunning = true

        while isRunning {
            do {
                let requestData = try await transport.receive()
                let request = try decoder.decode(MCPRequest.self, from: requestData)
                let response = await handleRequest(request)
                let responseData = try encoder.encode(response)
                try await transport.send(responseData)
            } catch is MCPServerTransportError {
                // Transport closed (EOF) or unrecoverable write failure — stop serving
                // rather than busy-looping on a dead connection.
                break
            } catch {
                if isRunning {
                    // Tolerate a single malformed/undecodable message and keep serving.
                    continue
                }
                break
            }
        }

        isRunning = false
    }

    /// Stop the MCP server
    public func stop() async {
        isRunning = false
        await transport?.close()
        transport = nil
    }

    // MARK: - Request Handling

    private func handleRequest(_ request: MCPRequest) async -> MCPResponse {
        switch request.method {
        case "initialize":
            return handleInitialize(request)

        case "tools/list":
            return handleToolsList(request)

        case "tools/call":
            return await handleToolCall(request)

        case "resources/list":
            return await handleResourcesList(request)

        case "resources/read":
            return await handleResourcesRead(request)

        default:
            return MCPResponse(
                id: request.id,
                error: MCPError(code: -32601, message: "Method not found: \(request.method)")
            )
        }
    }

    private func handleInitialize(_ request: MCPRequest) -> MCPResponse {
        MCPResponse(
            id: request.id,
            result: MCPResult(content: [
                MCPContent(text: "{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{},\"resources\":{}},\"serverInfo\":{\"name\":\"BrainAI\",\"version\":\"\(BrainAIMetadata.marketingVersion)\"}}")
            ])
        )
    }

    private func handleToolsList(_ request: MCPRequest) -> MCPResponse {
        MCPResponse(
            id: request.id,
            result: MCPResult(tools: Self.toolDefinitions)
        )
    }

    private func handleToolCall(_ request: MCPRequest) async -> MCPResponse {
        guard let toolName = request.params?.name else {
            return MCPResponse(
                id: request.id,
                error: MCPError(code: -32602, message: "Missing tool name")
            )
        }

        let args = request.params?.arguments ?? [:]

        do {
            let result = try await executeTool(name: toolName, arguments: args)
            return MCPResponse(
                id: request.id,
                result: MCPResult(content: [MCPContent(text: result)])
            )
        } catch {
            return MCPResponse(
                id: request.id,
                error: MCPError(code: -32000, message: error.localizedDescription)
            )
        }
    }

    // MARK: - Resources

    static let schemaResourceURI = "brainai://memory/schema"
    static let indexResourceURI = "brainai://memory/index"
    static let pageResourceURIPrefix = "brainai://memory/page/"

    private func handleResourcesList(_ request: MCPRequest) async -> MCPResponse {
        var resources = [
            MCPResourceDescriptor(
                uri: Self.schemaResourceURI,
                name: "Memory Schema",
                description: "BrainAI memory taxonomy for the active workspace: page kinds, entity types, relation patterns, and domain/category tagging conventions.",
                mimeType: "text/markdown"
            ),
            MCPResourceDescriptor(
                uri: Self.indexResourceURI,
                name: "Memory Index",
                description: "Index of all compiled wiki memory pages in the active workspace.",
                mimeType: "text/markdown"
            ),
        ]

        // Each compiled wiki page is individually addressable as a resource.
        if let store = try? wikiStore(for: nil), let pages = try? await store.listPages() {
            for page in pages where page.path != "index.md" {
                resources.append(
                    MCPResourceDescriptor(
                        uri: Self.pageResourceURIPrefix + page.path,
                        name: page.title,
                        description: "\(page.kind.displayName) page" + (page.frontmatter["domain"].map { " · \($0)" } ?? ""),
                        mimeType: "text/markdown"
                    )
                )
            }
        }

        return MCPResponse(id: request.id, result: MCPResult(resources: resources))
    }

    private func handleResourcesRead(_ request: MCPRequest) async -> MCPResponse {
        guard let uri = request.params?.uri, !uri.isEmpty else {
            return MCPResponse(id: request.id, error: MCPError(code: -32602, message: "Missing resource uri"))
        }

        do {
            let text: String
            switch uri {
            case Self.schemaResourceURI:
                text = try await wikiStore(for: nil).readMemorySchema()
            case Self.indexResourceURI:
                text = try await wikiStore(for: nil).readPage(at: "index.md").markdown
            case let uri where uri.hasPrefix(Self.pageResourceURIPrefix):
                let path = String(uri.dropFirst(Self.pageResourceURIPrefix.count))
                text = try await wikiStore(for: nil).readPage(at: path).markdown
            default:
                return MCPResponse(id: request.id, error: MCPError(code: -32602, message: "Unknown resource: \(uri)"))
            }
            return MCPResponse(
                id: request.id,
                result: MCPResult(contents: [
                    MCPResourceContents(uri: uri, mimeType: "text/markdown", text: text)
                ])
            )
        } catch {
            return MCPResponse(id: request.id, error: MCPError(code: -32000, message: error.localizedDescription))
        }
    }

    // MARK: - Tool Execution

    private func executeTool(name: String, arguments: [String: AnyCodable]) async throws -> String {
        switch name {
        case "brainai_query":
            return try await executeQuery(arguments)
        case "brainai_insert":
            return try await executeInsert(arguments)
        case "brainai_create_entity":
            return try await executeCreateEntity(arguments)
        case "brainai_create_relation":
            return try await executeCreateRelation(arguments)
        case "brainai_search":
            return try await executeSearch(arguments)
        case "brainai_wiki_search":
            return try await executeWikiSearch(arguments)
        case "brainai_wiki_get_page":
            return try await executeWikiGetPage(arguments)
        case "brainai_wiki_review_queue":
            return try await executeWikiReviewQueue(arguments)
        case "brainai_wiki_append_log":
            return try await executeWikiAppendLog(arguments)
        case "brainai_wiki_create_note":
            return try await executeWikiCreateNote(arguments)
        case "brainai_wiki_record_source":
            return try await executeWikiRecordSource(arguments)
        case "brainai_list_workspaces":
            return try executeListWorkspaces(arguments)
        default:
            throw MCPToolError.unknownTool(name)
        }
    }

    private func executeQuery(_ args: [String: AnyCodable]) async throws -> String {
        guard case .string(let question) = args["question"] else {
            throw MCPToolError.missingArgument("question")
        }

        let modeString = args["mode"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? "hybrid"
        let mode = SearchMode(rawValue: modeString) ?? .hybrid
        let topK = args["top_k"].flatMap { if case .int(let i) = $0 { return i } else { return nil } } ?? 40

        let response = try await lightRAGClient.query(question, mode: mode, topK: topK, onlyNeedContext: false)
        return response.response
    }

    private func executeInsert(_ args: [String: AnyCodable]) async throws -> String {
        guard case .string(let text) = args["text"] else {
            throw MCPToolError.missingArgument("text")
        }

        let description = args["description"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""

        let response = try await lightRAGClient.insertText(text, description: description)
        return "Inserted successfully. Status: \(response.status), Track ID: \(response.trackId)"
    }

    private func executeCreateEntity(_ args: [String: AnyCodable]) async throws -> String {
        guard case .string(let name) = args["name"] else {
            throw MCPToolError.missingArgument("name")
        }
        guard case .string(let type) = args["type"] else {
            throw MCPToolError.missingArgument("type")
        }

        let description = args["description"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""

        let request = EntityCreateRequest(entityName: name, entityType: type, description: description)
        try await lightRAGClient.createEntity(request)
        return "Entity '\(name)' of type '\(type)' created successfully."
    }

    private func executeCreateRelation(_ args: [String: AnyCodable]) async throws -> String {
        guard case .string(let source) = args["source"] else {
            throw MCPToolError.missingArgument("source")
        }
        guard case .string(let target) = args["target"] else {
            throw MCPToolError.missingArgument("target")
        }
        guard case .string(let description) = args["description"] else {
            throw MCPToolError.missingArgument("description")
        }

        let keywords = args["keywords"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""

        let request = RelationCreateRequest(srcEntity: source, tgtEntity: target, description: description, keywords: keywords)
        try await lightRAGClient.createRelation(request)
        return "Relation '\(source)' -> '\(target)' (\(description)) created successfully."
    }

    private func executeSearch(_ args: [String: AnyCodable]) async throws -> String {
        guard case .string(let label) = args["label"] else {
            throw MCPToolError.missingArgument("label")
        }

        let searchText = args["search_text"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""
        let maxItems = args["max_items"].flatMap { if case .int(let i) = $0 { return i } else { return nil } } ?? 50

        let response = try await lightRAGClient.searchGraph(label: label, searchText: searchText, maxItems: maxItems)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(response)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func executeWikiSearch(_ args: [String: AnyCodable]) async throws -> String {
        guard let query = stringArgument("query", from: args), !query.isEmpty else {
            throw MCPToolError.missingArgument("query")
        }

        let domainFilter = stringArgument("domain", from: args)?.trimmingCharacters(in: .whitespaces)
        let store = try wikiStore(for: stringArgument("workspace", from: args))
        let pages = try await store.listPages()
        let matches = pages
            .filter { page in
                if let domainFilter, !domainFilter.isEmpty,
                   page.frontmatter["domain"]?.caseInsensitiveCompare(domainFilter) != .orderedSame {
                    return false
                }
                return page.title.localizedCaseInsensitiveContains(query) ||
                    page.path.localizedCaseInsensitiveContains(query) ||
                    page.markdown.localizedCaseInsensitiveContains(query)
            }
            .prefix(20)
            .map { page in
                [
                    "title": AnyCodable.string(page.title),
                    "path": AnyCodable.string(page.path),
                    "kind": AnyCodable.string(page.kind.rawValue),
                    "domain": AnyCodable.string(page.frontmatter["domain"] ?? ""),
                    "updated_at": AnyCodable.string(ISO8601DateFormatter().string(from: page.updatedAt))
                ]
            }

        let payload: [String: AnyCodable] = [
            "query": .string(query),
            "count": .int(matches.count),
            "results": .array(matches.map { .object($0) })
        ]
        return try encodeToolPayload(payload)
    }

    private func executeWikiGetPage(_ args: [String: AnyCodable]) async throws -> String {
        guard let selector = stringArgument("path_or_slug", from: args), !selector.isEmpty else {
            throw MCPToolError.missingArgument("path_or_slug")
        }

        let store = try wikiStore(for: stringArgument("workspace", from: args))
        let pages = try await store.listPages()
        guard let page = pages.first(where: { page in
            page.path == selector ||
                page.slug == selector ||
                page.path == "\(selector).md" ||
                page.path.hasSuffix("/\(selector)") ||
                page.path.hasSuffix("/\(selector).md")
        }) else {
            throw MCPToolError.executionFailed("Wiki page not found: \(selector)")
        }

        let payload: [String: AnyCodable] = [
            "title": .string(page.title),
            "path": .string(page.path),
            "slug": .string(page.slug),
            "kind": .string(page.kind.rawValue),
            "markdown": .string(page.markdown)
        ]
        return try encodeToolPayload(payload)
    }

    private func executeWikiReviewQueue(_ args: [String: AnyCodable]) async throws -> String {
        let store = try wikiStore(for: stringArgument("workspace", from: args))
        let requestedStatus = stringArgument("status", from: args).flatMap(WikiReviewStatus.init(rawValue:))
        let items = try await store.listReviewItems()
            .filter { item in requestedStatus.map { status in item.status == status } ?? true }
            .map { item in
                [
                    "id": AnyCodable.string(item.id.uuidString),
                    "title": AnyCodable.string(item.title),
                    "page_path": AnyCodable.string(item.pagePath),
                    "status": AnyCodable.string(item.status.rawValue),
                    "reason": AnyCodable.string(item.reason),
                    "created_at": AnyCodable.string(ISO8601DateFormatter().string(from: item.createdAt))
                ]
            }

        let payload: [String: AnyCodable] = [
            "count": .int(items.count),
            "results": .array(items.map { .object($0) })
        ]
        return try encodeToolPayload(payload)
    }

    private func executeWikiAppendLog(_ args: [String: AnyCodable]) async throws -> String {
        guard let message = stringArgument("message", from: args), !message.isEmpty else {
            throw MCPToolError.missingArgument("message")
        }

        let store = try wikiStore(for: stringArgument("workspace", from: args))
        try await store.appendLogEntry(message)

        let payload: [String: AnyCodable] = [
            "ok": .bool(true),
            "message": .string(message)
        ]
        return try encodeToolPayload(payload)
    }

    private func executeWikiCreateNote(_ args: [String: AnyCodable]) async throws -> String {
        guard let title = stringArgument("title", from: args), !title.isEmpty else {
            throw MCPToolError.missingArgument("title")
        }
        guard let body = stringArgument("body", from: args), !body.isEmpty else {
            throw MCPToolError.missingArgument("body")
        }

        let kind = stringArgument("kind", from: args).flatMap(WikiPageKind.init(rawValue:)) ?? .concept
        let workspaceSelector = stringArgument("workspace", from: args)
        // Fall back to the workspace's default domain when none is provided.
        let domain = stringArgument("domain", from: args) ?? resolveWorkspace(for: workspaceSelector)?.domain
        let confidence = stringArgument("confidence", from: args) ?? "medium"
        let tags = stringArrayArgument("tags", from: args)
        let sourceLinks = stringArrayArgument("source_links", from: args)
        let autoAccept = boolArgument("auto_accept", from: args) ?? false

        let store = try wikiStore(for: workspaceSelector)
        let page = try await store.createMemoryPage(
            kind: kind,
            title: title,
            body: body,
            domain: domain,
            confidence: confidence,
            tags: tags,
            sourceLinks: sourceLinks,
            autoAccept: autoAccept
        )

        let payload: [String: AnyCodable] = [
            "ok": .bool(true),
            "path": .string(page.path),
            "kind": .string(page.kind.rawValue),
            "status": .string(autoAccept ? "auto_accepted" : "needs_review")
        ]
        return try encodeToolPayload(payload)
    }

    private func executeWikiRecordSource(_ args: [String: AnyCodable]) async throws -> String {
        guard let title = stringArgument("title", from: args), !title.isEmpty else {
            throw MCPToolError.missingArgument("title")
        }
        guard let content = stringArgument("content", from: args), !content.isEmpty else {
            throw MCPToolError.missingArgument("content")
        }

        let sourceType = stringArgument("source_type", from: args) ?? "note"
        let store = try wikiStore(for: stringArgument("workspace", from: args))
        let page = try await store.createSourcePage(
            title: title,
            content: content,
            sourceType: sourceType,
            trackId: nil
        )

        let payload: [String: AnyCodable] = [
            "ok": .bool(true),
            "path": .string(page.path),
            "source_type": .string(sourceType),
            "status": .string("needs_review")
        ]
        return try encodeToolPayload(payload)
    }

    private func executeListWorkspaces(_ args: [String: AnyCodable]) throws -> String {
        let activeID = workspaceManager.activeWorkspace?.id
        let rows = workspaceManager.workspaces.map { ws in
            [
                "slug": AnyCodable.string(ws.slug),
                "name": AnyCodable.string(ws.name),
                "active": AnyCodable.bool(ws.id == activeID)
            ]
        }

        let payload: [String: AnyCodable] = [
            "count": .int(rows.count),
            "results": .array(rows.map { .object($0) })
        ]
        return try encodeToolPayload(payload)
    }

    private func resolveWorkspace(for selector: String?) -> Workspace? {
        if let selector, !selector.isEmpty {
            return workspaceManager.workspaces.first {
                $0.slug == selector || $0.name.localizedCaseInsensitiveCompare(selector) == .orderedSame
            }
        }
        return workspaceManager.activeWorkspace
    }

    private func wikiStore(for workspaceSelector: String?) throws -> WikiPageStore {
        if let workspaceSelector, !workspaceSelector.isEmpty {
            guard let workspace = workspaceManager.workspaces.first(where: {
                $0.slug == workspaceSelector || $0.name.localizedCaseInsensitiveCompare(workspaceSelector) == .orderedSame
            }) else {
                throw MCPToolError.executionFailed("Workspace not found: \(workspaceSelector)")
            }
            return WikiPageStore(workspaceURL: workspace.dataPath)
        }

        if let workspace = workspaceManager.activeWorkspace {
            return WikiPageStore(workspaceURL: workspace.dataPath)
        }

        return WikiPageStore(workspaceSlug: "default")
    }

    private func stringArgument(_ name: String, from args: [String: AnyCodable]) -> String? {
        guard case .string(let value) = args[name] else { return nil }
        return value
    }

    private func boolArgument(_ name: String, from args: [String: AnyCodable]) -> Bool? {
        switch args[name] {
        case .bool(let value): return value
        case .string(let value): return (value as NSString).boolValue
        default: return nil
        }
    }

    private func stringArrayArgument(_ name: String, from args: [String: AnyCodable]) -> [String] {
        switch args[name] {
        case .array(let values):
            return values.compactMap { element in
                if case .string(let value) = element { return value }
                return nil
            }
        case .string(let value):
            // Accept a comma-separated string as a convenience.
            return value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        default:
            return []
        }
    }

    private func encodeToolPayload(_ payload: [String: AnyCodable]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - MCP Tool Error

public enum MCPToolError: LocalizedError {
    case unknownTool(String)
    case missingArgument(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unknownTool(let name): "Unknown tool: \(name)"
        case .missingArgument(let arg): "Missing required argument: \(arg)"
        case .executionFailed(let msg): "Tool execution failed: \(msg)"
        }
    }
}
