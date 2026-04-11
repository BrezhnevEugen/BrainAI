import XCTest
@testable import BrainAICore

// MARK: - AppConfigurationTests

final class AppConfigurationTests: XCTestCase {
    func testDefaultEnumValues() {
        // Test enum defaults without touching AppConfiguration.shared singleton
        XCTAssertEqual(AppTheme.system.rawValue, "system")
        XCTAssertEqual(AppTheme.light.rawValue, "light")
        XCTAssertEqual(AppTheme.dark.rawValue, "dark")
        XCTAssertEqual(AppLanguage.system.rawValue, "system")
        XCTAssertEqual(AppLanguage.en.rawValue, "en")
        XCTAssertEqual(AppLanguage.ru.rawValue, "ru")
    }

    func testKeepAliveDuration() {
        let minutes5 = KeepAliveDuration.minutes(5)
        XCTAssertEqual(minutes5.rawValue, "5m")

        let seconds30 = KeepAliveDuration.seconds(30)
        XCTAssertEqual(seconds30.rawValue, "30s")

        let forever = KeepAliveDuration.forever
        XCTAssertEqual(forever.rawValue, "-1")
    }

    func testSearchModeAllCases() {
        let cases = SearchMode.allCases
        XCTAssertEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(.local))
        XCTAssertTrue(cases.contains(.global))
        XCTAssertTrue(cases.contains(.hybrid))
        XCTAssertTrue(cases.contains(.naive))
        XCTAssertTrue(cases.contains(.mix))
    }

    func testDocumentStatusValues() {
        // DocumentStatus has 4 known cases
        let pending = DocumentStatus.pending
        let processing = DocumentStatus.processing
        let processed = DocumentStatus.processed
        let failed = DocumentStatus.failed

        XCTAssertEqual(pending.rawValue, "pending")
        XCTAssertEqual(processing.rawValue, "processing")
        XCTAssertEqual(processed.rawValue, "processed")
        XCTAssertEqual(failed.rawValue, "failed")
    }
}

// MARK: - DTOTests

final class DTOTests: XCTestCase {
    func testQueryResponseEncoding() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let original = QueryResponse(response: "test", references: ["ref1", "ref2"])
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(QueryResponse.self, from: data)

        XCTAssertEqual(original.response, decoded.response)
        XCTAssertEqual(original.references, decoded.references)
    }

    func testInsertTextRequestEncoding() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let original = InsertTextRequest(text: "Sample text", description: "A sample")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(InsertTextRequest.self, from: data)

        XCTAssertEqual(original.text, decoded.text)
        XCTAssertEqual(original.description, decoded.description)
    }

    func testEntityCreateRequestEncoding() throws {
        // EntityCreateRequest has explicit CodingKeys — use plain encoder/decoder
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = EntityCreateRequest(
            entityName: "TestEntity",
            entityType: "Person",
            description: "A test person",
            sourceId: "test-source"
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(EntityCreateRequest.self, from: data)

        XCTAssertEqual(original.entityName, decoded.entityName)
        XCTAssertEqual(original.entityType, decoded.entityType)
        XCTAssertEqual(original.description, decoded.description)
        XCTAssertEqual(original.sourceId, decoded.sourceId)
    }

    func testOllamaOptionsEncoding() throws {
        // OllamaOptions has explicit CodingKeys — use plain encoder/decoder
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = OllamaOptions(temperature: 0.7, topP: 0.9)
        let data = try encoder.encode(original)

        // Verify JSON contains snake_case keys from CodingKeys
        if let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertNotNil(jsonDict["temperature"])
            XCTAssertNotNil(jsonDict["top_p"])
        }

        let decoded = try decoder.decode(OllamaOptions.self, from: data)
        XCTAssertEqual(original.temperature, decoded.temperature)
        XCTAssertEqual(original.topP, decoded.topP)
    }
}

// MARK: - ModelTests

final class ModelTests: XCTestCase {
    func testLLMModelEquality() {
        let model1 = LLMModel(
            id: "llama2",
            name: "Llama 2",
            parameterSize: "7B"
        )
        let model2 = LLMModel(
            id: "llama2",
            name: "Llama 2 Chat",
            parameterSize: "13B"
        )

        // Same id means equal
        XCTAssertEqual(model1, model2)
    }

    func testEmbeddingModelEquality() {
        let model1 = EmbeddingModel(
            id: "nomic-embed",
            name: "Nomic Embed",
            dimension: 768
        )
        let model2 = EmbeddingModel(
            id: "nomic-embed",
            name: "Nomic Embed Text",
            dimension: 1024
        )

        // Same id means equal
        XCTAssertEqual(model1, model2)
    }

    func testRankedDocumentSorting() {
        var documents = [
            RankedDocument(index: 0, score: 0.5, text: "First doc"),
            RankedDocument(index: 1, score: 0.9, text: "Second doc"),
            RankedDocument(index: 2, score: 0.7, text: "Third doc")
        ]

        documents.sort { $0.score > $1.score }

        XCTAssertEqual(documents[0].score, 0.9)
        XCTAssertEqual(documents[1].score, 0.7)
        XCTAssertEqual(documents[2].score, 0.5)
    }

    func testWorkspaceCreation() {
        let dataPath = URL.brainAIWorkspaces.appendingPathComponent("test")
        let workspace = Workspace(
            id: UUID(),
            name: "Test Workspace",
            slug: "test-workspace",
            icon: "folder.fill",
            color: "#FF5733",
            description: "A test workspace",
            port: 8001,
            dataPath: dataPath,
            startPolicy: .always,
            isEncrypted: true,
            isShared: false,
            entityCount: 100,
            relationCount: 50,
            documentCount: 10
        )

        XCTAssertEqual(workspace.name, "Test Workspace")
        XCTAssertEqual(workspace.slug, "test-workspace")
        XCTAssertEqual(workspace.icon, "folder.fill")
        XCTAssertEqual(workspace.color, "#FF5733")
        XCTAssertEqual(workspace.description, "A test workspace")
        XCTAssertEqual(workspace.port, 8001)
        XCTAssertEqual(workspace.startPolicy, .always)
        XCTAssertTrue(workspace.isEncrypted)
        XCTAssertFalse(workspace.isShared)
        XCTAssertEqual(workspace.entityCount, 100)
        XCTAssertEqual(workspace.relationCount, 50)
        XCTAssertEqual(workspace.documentCount, 10)
    }
}

// MARK: - RoleConfigTests

final class RoleConfigTests: XCTestCase {
    func testProviderEndpointLocal() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let endpoint = ProviderEndpoint.local
        let data = try encoder.encode(endpoint)
        let decoded = try decoder.decode(ProviderEndpoint.self, from: data)

        XCTAssertEqual(endpoint, decoded)
    }

    func testProviderEndpointRemote() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let endpoint = ProviderEndpoint.remoteOllama(url: "http://host:11434")
        let data = try encoder.encode(endpoint)
        let decoded = try decoder.decode(ProviderEndpoint.self, from: data)

        if case .remoteOllama(let url) = decoded {
            XCTAssertEqual(url, "http://host:11434")
        } else {
            XCTFail("Expected remoteOllama endpoint")
        }
    }

    func testProviderEndpointCloud() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let endpoint = ProviderEndpoint.cloudAPI(baseURL: "https://api.openai.com")
        let data = try encoder.encode(endpoint)
        let decoded = try decoder.decode(ProviderEndpoint.self, from: data)

        if case .cloudAPI(let baseURL) = decoded {
            XCTAssertEqual(baseURL, "https://api.openai.com")
        } else {
            XCTFail("Expected cloudAPI endpoint")
        }
    }

    func testRoleConfigEquality() {
        let config1 = RoleConfig(
            providerID: "ollama",
            modelID: "mistral",
            endpoint: .local
        )
        let config2 = RoleConfig(
            providerID: "ollama",
            modelID: "mistral",
            endpoint: .local
        )

        XCTAssertEqual(config1, config2)
    }
}

// MARK: - ProviderTests

final class ProviderTests: XCTestCase {
    func testOllamaLLMProviderInit() async throws {
        let mockAPI = OllamaAPIClient(baseURL: "http://localhost:11434")
        let provider = OllamaLLMProvider(
            id: "test-ollama-llm",
            displayName: "Test Ollama",
            ollamaAPI: mockAPI
        )

        let id = await provider.id
        let displayName = await provider.displayName
        let providerType = await provider.providerType

        XCTAssertEqual(id, "test-ollama-llm")
        XCTAssertEqual(displayName, "Test Ollama")
        XCTAssertEqual(providerType, .ollama)
    }

    func testOpenAILLMProviderInit() async throws {
        let provider = OpenAILLMProvider(
            id: "test-openai-llm",
            displayName: "Test OpenAI",
            apiKey: "test-key"
        )

        let id = await provider.id
        let displayName = await provider.displayName
        let providerType = await provider.providerType

        XCTAssertEqual(id, "test-openai-llm")
        XCTAssertEqual(displayName, "Test OpenAI")
        XCTAssertEqual(providerType, .openai)
    }

    func testAnthropicLLMProviderInit() async throws {
        let provider = AnthropicLLMProvider(
            id: "test-anthropic-llm",
            displayName: "Test Anthropic",
            apiKey: "test-key"
        )

        let id = await provider.id
        let displayName = await provider.displayName
        let providerType = await provider.providerType

        XCTAssertEqual(id, "test-anthropic-llm")
        XCTAssertEqual(displayName, "Test Anthropic")
        XCTAssertEqual(providerType, .anthropic)
    }

    func testOllamaEmbeddingProviderInit() async throws {
        let mockAPI = OllamaAPIClient(baseURL: "http://localhost:11434")
        let provider = OllamaEmbeddingProvider(
            id: "test-ollama-embed",
            displayName: "Test Ollama Embed",
            outputDimension: 384,
            ollamaAPI: mockAPI
        )

        let id = await provider.id
        let displayName = await provider.displayName
        let outputDimension = await provider.outputDimension

        XCTAssertEqual(id, "test-ollama-embed")
        XCTAssertEqual(displayName, "Test Ollama Embed")
        XCTAssertEqual(outputDimension, 384)
    }

    func testOpenAIEmbeddingProviderInit() async throws {
        let provider = OpenAIEmbeddingProvider(
            id: "test-openai-embed",
            displayName: "Test OpenAI Embed",
            apiKey: "test-key",
            outputDimension: 1536
        )

        let id = await provider.id
        let displayName = await provider.displayName
        let outputDimension = await provider.outputDimension

        XCTAssertEqual(id, "test-openai-embed")
        XCTAssertEqual(displayName, "Test OpenAI Embed")
        XCTAssertEqual(outputDimension, 1536)
    }
}

// MARK: - ProcessStatusTests

final class ProcessStatusTests: XCTestCase {
    func testProcessStatusEncoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test stopped
        let stopped = ProcessStatus.stopped
        let stoppedData = try encoder.encode(stopped)
        let stoppedDecoded = try decoder.decode(ProcessStatus.self, from: stoppedData)
        XCTAssertEqual(stopped, stoppedDecoded)

        // Test starting
        let starting = ProcessStatus.starting
        let startingData = try encoder.encode(starting)
        let startingDecoded = try decoder.decode(ProcessStatus.self, from: startingData)
        XCTAssertEqual(starting, startingDecoded)

        // Test running
        let running = ProcessStatus.running
        let runningData = try encoder.encode(running)
        let runningDecoded = try decoder.decode(ProcessStatus.self, from: runningData)
        XCTAssertEqual(running, runningDecoded)

        // Test error
        let error = ProcessStatus.error("Test error message")
        let errorData = try encoder.encode(error)
        let errorDecoded = try decoder.decode(ProcessStatus.self, from: errorData)

        if case .error(let msg) = errorDecoded {
            XCTAssertEqual(msg, "Test error message")
        } else {
            XCTFail("Expected error case")
        }
    }

    func testWorkspaceStartPolicyAllCases() {
        let cases = WorkspaceStartPolicy.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.always))
        XCTAssertTrue(cases.contains(.onDemand))
        XCTAssertTrue(cases.contains(.manual))
    }
}

// MARK: - KeychainManagerTests

final class KeychainManagerTests: XCTestCase {
    func testKeychainManagerInit() {
        let manager = KeychainManager.shared
        XCTAssertNotNil(manager)
    }
}

// MARK: - GenerateOptionsTests

final class GenerateOptionsTests: XCTestCase {
    func testDefaultOptions() {
        let options = GenerateOptions()

        XCTAssertNil(options.temperature)
        XCTAssertNil(options.topP)
        XCTAssertNil(options.topK)
        XCTAssertNil(options.maxTokens)
        XCTAssertNil(options.contextWindow)
    }

    func testCustomOptions() {
        let options = GenerateOptions(
            temperature: 0.5,
            topP: 0.8,
            topK: 50,
            maxTokens: 1024,
            contextWindow: 2048
        )

        XCTAssertEqual(options.temperature, 0.5)
        XCTAssertEqual(options.topP, 0.8)
        XCTAssertEqual(options.topK, 50)
        XCTAssertEqual(options.maxTokens, 1024)
        XCTAssertEqual(options.contextWindow, 2048)
    }
}

// MARK: - Previous Integration Tests

final class BrainAICoreTests: XCTestCase {
    // MARK: - RoleConfig Tests

    func testRoleConfigCodable() throws {
        let config = RoleConfig(
            providerID: "ollama-llm",
            modelID: "llama2",
            endpoint: .local
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RoleConfig.self, from: data)

        XCTAssertEqual(config, decoded)
    }

    func testRoleConfigWithRemoteOllama() throws {
        let config = RoleConfig(
            providerID: "remote-ollama",
            modelID: "mistral",
            endpoint: .remoteOllama(url: "http://192.168.1.100:11434")
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RoleConfig.self, from: data)

        XCTAssertEqual(config.providerID, decoded.providerID)
        XCTAssertEqual(config.modelID, decoded.modelID)

        if case .remoteOllama(let url) = decoded.endpoint {
            XCTAssertEqual(url, "http://192.168.1.100:11434")
        } else {
            XCTFail("Expected remoteOllama endpoint")
        }
    }

    func testRoleConfigWithCloudAPI() throws {
        let config = RoleConfig(
            providerID: "openai",
            modelID: "gpt-4",
            endpoint: .cloudAPI(baseURL: "https://api.openai.com/v1")
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RoleConfig.self, from: data)

        if case .cloudAPI(let baseURL) = decoded.endpoint {
            XCTAssertEqual(baseURL, "https://api.openai.com/v1")
        } else {
            XCTFail("Expected cloudAPI endpoint")
        }
    }

    // MARK: - KeepAliveDuration Tests

    func testKeepAliveDurationSeconds() {
        let duration = KeepAliveDuration.seconds(30)
        XCTAssertEqual(duration.rawValue, "30s")
    }

    func testKeepAliveDurationMinutes() {
        let duration = KeepAliveDuration.minutes(5)
        XCTAssertEqual(duration.rawValue, "5m")
    }

    func testKeepAliveDurationForever() {
        let duration = KeepAliveDuration.forever
        XCTAssertEqual(duration.rawValue, "-1")
    }

    func testKeepAliveDurationCodable() throws {
        let durations: [KeepAliveDuration] = [
            .seconds(30),
            .minutes(5),
            .forever,
        ]

        for duration in durations {
            let encoder = JSONEncoder()
            let data = try encoder.encode(duration)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(KeepAliveDuration.self, from: data)

            XCTAssertEqual(duration.rawValue, decoded.rawValue)
        }
    }

    // MARK: - URL Extension Tests

    func testBrainAIApplicationSupportURL() {
        let url = URL.brainAIApplicationSupport
        XCTAssertTrue(url.path.contains("Application Support"))
        XCTAssertTrue(url.path.contains("BrainAI"))
    }

    func testBrainAIWorkspacesURL() {
        let url = URL.brainAIWorkspaces
        XCTAssertTrue(url.path.contains("Application Support"))
        XCTAssertTrue(url.path.contains("BrainAI"))
        XCTAssertTrue(url.path.contains("workspaces"))
    }

    func testURLEnsureDirectoryExists() throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("brainai_test_\(UUID().uuidString)")

        // Ensure directory doesn't exist
        try? fileManager.removeItem(at: testDir)
        XCTAssertFalse(fileManager.fileExists(atPath: testDir.path))

        // Create directory
        try testDir.ensureDirectoryExists()
        XCTAssertTrue(fileManager.fileExists(atPath: testDir.path))

        // Cleanup
        try? fileManager.removeItem(at: testDir)
    }

    // MARK: - Workspace Tests

    func testWorkspaceInitialization() {
        let dataPath = URL.brainAIWorkspaces.appendingPathComponent("test")
        let workspace = Workspace(
            name: "Test Workspace",
            slug: "test-workspace",
            port: 8001,
            dataPath: dataPath
        )

        XCTAssertEqual(workspace.name, "Test Workspace")
        XCTAssertEqual(workspace.slug, "test-workspace")
        XCTAssertEqual(workspace.port, 8001)
        XCTAssertEqual(workspace.startPolicy, .onDemand)
        XCTAssertFalse(workspace.isEncrypted)
        XCTAssertFalse(workspace.isShared)
    }

    func testWorkspaceCodable() throws {
        let dataPath = URL.brainAIWorkspaces.appendingPathComponent("test")
        let workspace = Workspace(
            id: UUID(),
            name: "Test Workspace",
            slug: "test-workspace",
            icon: "folder.fill",
            color: "#FF5733",
            description: "A test workspace",
            port: 8001,
            dataPath: dataPath,
            startPolicy: .always,
            isEncrypted: true,
            isShared: false,
            entityCount: 100,
            relationCount: 50,
            documentCount: 10
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(workspace)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Workspace.self, from: data)

        XCTAssertEqual(workspace.id, decoded.id)
        XCTAssertEqual(workspace.name, decoded.name)
        XCTAssertEqual(workspace.slug, decoded.slug)
        XCTAssertEqual(workspace.port, decoded.port)
        XCTAssertEqual(workspace.isEncrypted, decoded.isEncrypted)
        XCTAssertEqual(workspace.entityCount, decoded.entityCount)
    }

    // MARK: - GenerateOptions Tests

    func testGenerateOptionsWithDefaults() {
        let options = GenerateOptions()

        XCTAssertNil(options.temperature)
        XCTAssertNil(options.topP)
        XCTAssertNil(options.topK)
        XCTAssertNil(options.maxTokens)
        XCTAssertNil(options.contextWindow)
    }

    func testGenerateOptionsWithValues() {
        let options = GenerateOptions(
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            maxTokens: 2048,
            contextWindow: 4096
        )

        XCTAssertEqual(options.temperature, 0.7)
        XCTAssertEqual(options.topP, 0.9)
        XCTAssertEqual(options.topK, 40)
        XCTAssertEqual(options.maxTokens, 2048)
        XCTAssertEqual(options.contextWindow, 4096)
    }
}

// MARK: - Graph DTO Tests

final class GraphDTOTests: XCTestCase {
    func testGraphLabelsResponseEncoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = GraphLabelsResponse(
            entityLabels: ["Person", "Organization", "Concept"],
            relationLabels: ["works_at", "knows", "related_to"]
        )

        let data = try encoder.encode(original)

        // Verify JSON has snake_case keys from explicit CodingKeys
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertNotNil(json["entity_labels"])
            XCTAssertNotNil(json["relation_labels"])
        }

        let decoded = try decoder.decode(GraphLabelsResponse.self, from: data)
        XCTAssertEqual(original.entityLabels, decoded.entityLabels)
        XCTAssertEqual(original.relationLabels, decoded.relationLabels)
    }

    func testGraphNodeDataEncoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = GraphNodeData(name: "Machine Learning", type: "Concept",
                                     description: "A subset of AI", degree: 5)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GraphNodeData.self, from: data)

        XCTAssertEqual(original.name, decoded.name)
        XCTAssertEqual(original.type, decoded.type)
        XCTAssertEqual(original.description, decoded.description)
        XCTAssertEqual(original.degree, decoded.degree)
    }

    func testGraphEdgeDataEncoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = GraphEdgeData(source: "NodeA", target: "NodeB",
                                     description: "related to", keywords: "relation,test")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GraphEdgeData.self, from: data)

        XCTAssertEqual(original.source, decoded.source)
        XCTAssertEqual(original.target, decoded.target)
        XCTAssertEqual(original.description, decoded.description)
        XCTAssertEqual(original.keywords, decoded.keywords)
    }

    func testGraphSearchResponseEncoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = GraphSearchResponse(
            nodes: [
                GraphNodeData(name: "AI", type: "Concept"),
                GraphNodeData(name: "ML", type: "Concept")
            ],
            edges: [
                GraphEdgeData(source: "AI", target: "ML", description: "includes")
            ]
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GraphSearchResponse.self, from: data)

        XCTAssertEqual(decoded.nodes.count, 2)
        XCTAssertEqual(decoded.edges.count, 1)
        XCTAssertEqual(decoded.nodes[0].name, "AI")
        XCTAssertEqual(decoded.edges[0].source, "AI")
    }

    func testQueryDataResponseEncoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = QueryDataResponse(
            entities: [GraphNodeData(name: "Entity1", type: "Type1")],
            relations: [GraphEdgeData(source: "Entity1", target: "Entity2", description: "linked")],
            chunks: [ChunkData(content: "Some text chunk", sourceId: "doc-1")]
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(QueryDataResponse.self, from: data)

        XCTAssertEqual(decoded.entities?.count, 1)
        XCTAssertEqual(decoded.relations?.count, 1)
        XCTAssertEqual(decoded.chunks?.count, 1)
        XCTAssertEqual(decoded.chunks?[0].content, "Some text chunk")
        XCTAssertEqual(decoded.chunks?[0].sourceId, "doc-1")
    }

    func testChunkDataEncoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = ChunkData(content: "Test content", sourceId: "src-123")
        let data = try encoder.encode(original)

        // Verify snake_case from CodingKeys
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertNotNil(json["source_id"])
        }

        let decoded = try decoder.decode(ChunkData.self, from: data)
        XCTAssertEqual(original.content, decoded.content)
        XCTAssertEqual(original.sourceId, decoded.sourceId)
    }
}
