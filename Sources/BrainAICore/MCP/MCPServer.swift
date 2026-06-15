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
            } catch {
                if isRunning {
                    // Log error but continue serving
                    continue
                }
                break
            }
        }
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
                MCPContent(text: "{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"BrainAI\",\"version\":\"\(BrainAIMetadata.marketingVersion)\"}}")
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

        let store = try wikiStore(for: stringArgument("workspace", from: args))
        let pages = try await store.listPages()
        let matches = pages
            .filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                    $0.path.localizedCaseInsensitiveContains(query) ||
                    $0.markdown.localizedCaseInsensitiveContains(query)
            }
            .prefix(20)
            .map { page in
                [
                    "title": AnyCodable.string(page.title),
                    "path": AnyCodable.string(page.path),
                    "kind": AnyCodable.string(page.kind.rawValue),
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
