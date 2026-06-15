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
        XCTAssertEqual(AppLanguage.uk.rawValue, "uk")
        XCTAssertEqual(AppLanguage.zhHans.rawValue, "zh-Hans")
        XCTAssertEqual(AppLanguage.allCases.count, 11)
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

// MARK: - LightRAGLocalePresetTests

final class LightRAGLocalePresetTests: XCTestCase {
    func testSummaryLanguageMatchesUILocaleChoices() {
        XCTAssertEqual(LightRAGLocalePreset.summaryLanguage(for: .en), "English")
        XCTAssertEqual(LightRAGLocalePreset.summaryLanguage(for: .ru), "Russian")
        XCTAssertEqual(LightRAGLocalePreset.summaryLanguage(for: .uk), "Ukrainian")
    }

    func testDefaultChunkPresetStable() {
        XCTAssertEqual(LightRAGLocalePreset.defaultChunkSize, 800)
        XCTAssertEqual(LightRAGLocalePreset.defaultChunkOverlap, 100)
    }

    func testDefaultChatModelPreset() {
        XCTAssertEqual(LightRAGLocalePreset.defaultOllamaChatModelID, "qwen2.5:14b")
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

// MARK: - WorkspaceManagerTests

final class WorkspaceManagerTests: XCTestCase {
    private var workspaceRoot: URL!
    private var originalDefaultWorkspaceID: String!

    override func setUpWithError() throws {
        workspaceRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrainAIWorkspaceManagerTests-\(UUID().uuidString)", isDirectory: true)
        originalDefaultWorkspaceID = AppConfiguration.shared.defaultWorkspaceID
        AppConfiguration.shared.defaultWorkspaceID = ""
    }

    override func tearDownWithError() throws {
        AppConfiguration.shared.defaultWorkspaceID = originalDefaultWorkspaceID
        if let workspaceRoot, FileManager.default.fileExists(atPath: workspaceRoot.path) {
            try FileManager.default.removeItem(at: workspaceRoot)
        }
    }

    func testCreateFirstWorkspaceMakesItActiveAndKeepsSecondInactive() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)

        let first = try await manager.create(name: "First Workspace", slug: "first")
        let second = try await manager.create(name: "Second Workspace", slug: "second")

        XCTAssertEqual(manager.activeWorkspace?.id, first.id)
        XCTAssertNotEqual(manager.activeWorkspace?.id, second.id)
        XCTAssertEqual(AppConfiguration.shared.defaultWorkspaceID, first.id.uuidString)
    }

    func testSetActivePersistsDefaultWorkspaceForReload() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        _ = try await manager.create(name: "First Workspace", slug: "first")
        let second = try await manager.create(name: "Second Workspace", slug: "second")

        try await manager.setActive(id: second.id)

        XCTAssertEqual(manager.activeWorkspace?.id, second.id)
        XCTAssertEqual(AppConfiguration.shared.defaultWorkspaceID, second.id.uuidString)

        let reloaded = WorkspaceManager(workspacesDirectory: workspaceRoot)
        try await waitUntil {
            reloaded.workspaces.count == 2
        }

        XCTAssertEqual(reloaded.activeWorkspace?.id, second.id)
    }

    func testDeleteActiveWorkspaceFallsBackToRemainingWorkspace() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        let first = try await manager.create(name: "First Workspace", slug: "first")
        let second = try await manager.create(name: "Second Workspace", slug: "second")

        try await manager.setActive(id: second.id)
        try await manager.delete(id: second.id)

        XCTAssertEqual(manager.activeWorkspace?.id, first.id)
        XCTAssertEqual(AppConfiguration.shared.defaultWorkspaceID, first.id.uuidString)
        XCTAssertEqual(manager.workspaces.map(\.id), [first.id])
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), file: file, line: line)
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

// MARK: - Remote Connection Tests

final class RemoteConnectionTests: XCTestCase {

    func testRemoteConnectionStateDisplayString() {
        let disconnected = RemoteConnectionState.disconnected
        XCTAssertEqual(disconnected.displayString, "Disconnected")
        XCTAssertFalse(disconnected.isConnected)

        let connecting = RemoteConnectionState.connecting
        XCTAssertEqual(connecting.displayString, "Connecting...")
        XCTAssertFalse(connecting.isConnected)

        let connected = RemoteConnectionState.connected(latency: 0.150)
        XCTAssertEqual(connected.displayString, "Connected (150ms)")
        XCTAssertTrue(connected.isConnected)

        let error = RemoteConnectionState.error("timeout")
        XCTAssertEqual(error.displayString, "Error: timeout")
        XCTAssertFalse(error.isConnected)
    }

    func testRemoteConnectionConfigCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = RemoteConnectionConfig(
            baseURL: "https://lightrag.example.com",
            authToken: "secret-token",
            tlsPinnedHashes: ["abc123", "def456"],
            healthCheckInterval: 60,
            retryMaxAttempts: 5,
            retryBaseDelay: 2.0
        )

        let data = try encoder.encode(original)

        // Verify snake_case from CodingKeys
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertNotNil(json["base_url"])
            XCTAssertNotNil(json["auth_token"])
            XCTAssertNotNil(json["tls_pinned_hashes"])
            XCTAssertNotNil(json["health_check_interval"])
            XCTAssertNotNil(json["retry_max_attempts"])
            XCTAssertNotNil(json["retry_base_delay"])
        }

        let decoded = try decoder.decode(RemoteConnectionConfig.self, from: data)
        XCTAssertEqual(decoded.baseURL, "https://lightrag.example.com")
        XCTAssertEqual(decoded.authToken, "secret-token")
        XCTAssertEqual(decoded.tlsPinnedHashes, ["abc123", "def456"])
        XCTAssertEqual(decoded.healthCheckInterval, 60)
        XCTAssertEqual(decoded.retryMaxAttempts, 5)
        XCTAssertEqual(decoded.retryBaseDelay, 2.0)
    }

    func testRemoteConnectionConfigDefaults() {
        let config = RemoteConnectionConfig(baseURL: "http://localhost:9621")

        XCTAssertNil(config.authToken)
        XCTAssertTrue(config.tlsPinnedHashes.isEmpty)
        XCTAssertEqual(config.healthCheckInterval, 30)
        XCTAssertEqual(config.retryMaxAttempts, 3)
        XCTAssertEqual(config.retryBaseDelay, 1.0)
    }

    func testRemoteConnectionManagerInitialState() {
        let manager = RemoteConnectionManager()

        XCTAssertFalse(manager.connectionState.isConnected)
        XCTAssertNil(manager.lastHealthCheck)
        XCTAssertEqual(manager.lastLatency, 0)
        XCTAssertNil(manager.serverInfo)
        XCTAssertNil(manager.activeClient)
    }

    func testRemoteConnectionManagerDisconnect() {
        let manager = RemoteConnectionManager()
        manager.disconnect()

        XCTAssertFalse(manager.connectionState.isConnected)
        XCTAssertNil(manager.activeClient)
        XCTAssertNil(manager.serverInfo)
    }
}

// MARK: - MCP Protocol Tests

final class MCPProtocolTests: XCTestCase {

    func testMCPRequestEncoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let request = MCPRequest(
            id: 1,
            method: "tools/list"
        )

        let data = try encoder.encode(request)
        let decoded = try decoder.decode(MCPRequest.self, from: data)

        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.id, 1)
        XCTAssertEqual(decoded.method, "tools/list")
        XCTAssertNil(decoded.params)
    }

    func testMCPRequestWithParams() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let request = MCPRequest(
            id: 42,
            method: "tools/call",
            params: MCPParams(
                name: "brainai_query",
                arguments: [
                    "question": .string("What is AI?"),
                    "mode": .string("hybrid"),
                    "top_k": .int(20)
                ]
            )
        )

        let data = try encoder.encode(request)
        let decoded = try decoder.decode(MCPRequest.self, from: data)

        XCTAssertEqual(decoded.id, 42)
        XCTAssertEqual(decoded.method, "tools/call")
        XCTAssertEqual(decoded.params?.name, "brainai_query")

        if case .string(let q) = decoded.params?.arguments?["question"] {
            XCTAssertEqual(q, "What is AI?")
        } else {
            XCTFail("Expected string argument for question")
        }

        if case .int(let k) = decoded.params?.arguments?["top_k"] {
            XCTAssertEqual(k, 20)
        } else {
            XCTFail("Expected int argument for top_k")
        }
    }

    func testMCPResponseSuccess() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let response = MCPResponse(
            id: 1,
            result: MCPResult(content: [
                MCPContent(text: "Hello World")
            ])
        )

        let data = try encoder.encode(response)
        let decoded = try decoder.decode(MCPResponse.self, from: data)

        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.id, 1)
        XCTAssertNil(decoded.error)
        XCTAssertEqual(decoded.result?.content?.count, 1)
        XCTAssertEqual(decoded.result?.content?.first?.type, "text")
        XCTAssertEqual(decoded.result?.content?.first?.text, "Hello World")
    }

    func testMCPResponseError() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let response = MCPResponse(
            id: 2,
            error: MCPError(code: -32601, message: "Method not found")
        )

        let data = try encoder.encode(response)
        let decoded = try decoder.decode(MCPResponse.self, from: data)

        XCTAssertEqual(decoded.id, 2)
        XCTAssertNil(decoded.result)
        XCTAssertEqual(decoded.error?.code, -32601)
        XCTAssertEqual(decoded.error?.message, "Method not found")
    }

    func testMCPToolDefinitionEncoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let tool = MCPToolDefinition(
            name: "brainai_query",
            description: "Query the knowledge base",
            inputSchema: MCPInputSchema(
                properties: [
                    "question": MCPPropertySchema(type: "string", description: "The question"),
                    "mode": MCPPropertySchema(type: "string", description: "Search mode", defaultValue: "hybrid")
                ],
                required: ["question"]
            )
        )

        let data = try encoder.encode(tool)

        // Verify input_schema key name from CodingKeys
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertNotNil(json["input_schema"])
            XCTAssertNotNil(json["name"])
            XCTAssertNotNil(json["description"])
        }

        let decoded = try decoder.decode(MCPToolDefinition.self, from: data)
        XCTAssertEqual(decoded.name, "brainai_query")
        XCTAssertEqual(decoded.inputSchema.type, "object")
        XCTAssertEqual(decoded.inputSchema.properties?.count, 2)
        XCTAssertEqual(decoded.inputSchema.required, ["question"])
    }

    func testMCPServerToolDefinitions() {
        let tools = MCPServer.toolDefinitions

        XCTAssertEqual(tools.count, 12)

        let toolNames = tools.map(\.name)
        XCTAssertTrue(toolNames.contains("brainai_query"))
        XCTAssertTrue(toolNames.contains("brainai_insert"))
        XCTAssertTrue(toolNames.contains("brainai_create_entity"))
        XCTAssertTrue(toolNames.contains("brainai_create_relation"))
        XCTAssertTrue(toolNames.contains("brainai_search"))
        XCTAssertTrue(toolNames.contains("brainai_wiki_search"))
        XCTAssertTrue(toolNames.contains("brainai_wiki_get_page"))
        XCTAssertTrue(toolNames.contains("brainai_wiki_review_queue"))
        XCTAssertTrue(toolNames.contains("brainai_wiki_append_log"))
        XCTAssertTrue(toolNames.contains("brainai_wiki_create_note"))
        XCTAssertTrue(toolNames.contains("brainai_wiki_record_source"))
        XCTAssertTrue(toolNames.contains("brainai_list_workspaces"))

        // Verify query tool has required "question" field
        let queryTool = tools.first { $0.name == "brainai_query" }
        XCTAssertEqual(queryTool?.inputSchema.required, ["question"])
        XCTAssertNotNil(queryTool?.inputSchema.properties?["question"])
        XCTAssertNotNil(queryTool?.inputSchema.properties?["mode"])
        XCTAssertNotNil(queryTool?.inputSchema.properties?["top_k"])

        // Verify insert tool has required "text" field
        let insertTool = tools.first { $0.name == "brainai_insert" }
        XCTAssertEqual(insertTool?.inputSchema.required, ["text"])

        // Verify create_entity requires name and type
        let entityTool = tools.first { $0.name == "brainai_create_entity" }
        XCTAssertEqual(entityTool?.inputSchema.required?.sorted(), ["name", "type"])

        // Verify create_relation requires source, target, description
        let relationTool = tools.first { $0.name == "brainai_create_relation" }
        XCTAssertEqual(relationTool?.inputSchema.required?.sorted(), ["description", "source", "target"])

        // Verify search requires label
        let searchTool = tools.first { $0.name == "brainai_search" }
        XCTAssertEqual(searchTool?.inputSchema.required, ["label"])

        let wikiSearchTool = tools.first { $0.name == "brainai_wiki_search" }
        XCTAssertEqual(wikiSearchTool?.inputSchema.required, ["query"])

        let wikiGetPageTool = tools.first { $0.name == "brainai_wiki_get_page" }
        XCTAssertEqual(wikiGetPageTool?.inputSchema.required, ["path_or_slug"])

        let wikiReviewQueueTool = tools.first { $0.name == "brainai_wiki_review_queue" }
        XCTAssertEqual(wikiReviewQueueTool?.inputSchema.required, [])
    }

    func testMCPToolErrorDescriptions() {
        let unknownTool = MCPToolError.unknownTool("foo")
        XCTAssertEqual(unknownTool.errorDescription, "Unknown tool: foo")

        let missingArg = MCPToolError.missingArgument("question")
        XCTAssertEqual(missingArg.errorDescription, "Missing required argument: question")

        let execFailed = MCPToolError.executionFailed("timeout")
        XCTAssertEqual(execFailed.errorDescription, "Tool execution failed: timeout")
    }

    func testMCPPropertySchemaDefaultValue() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let schema = MCPPropertySchema(type: "string", description: "Search mode", defaultValue: "hybrid")
        let data = try encoder.encode(schema)

        // Verify "default" key from CodingKeys
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(json["default"] as? String, "hybrid")
        }

        let decoded = try decoder.decode(MCPPropertySchema.self, from: data)
        XCTAssertEqual(decoded.type, "string")
        XCTAssertEqual(decoded.description, "Search mode")
        XCTAssertEqual(decoded.defaultValue, "hybrid")
    }

    func testAnyCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let values: [String: AnyCodable] = [
            "string": .string("hello"),
            "int": .int(42),
            "double": .double(3.14),
            "bool": .bool(true),
            "null": .null,
            "array": .array([.int(1), .string("two")]),
            "object": .object(["nested": .bool(false)])
        ]

        let data = try encoder.encode(values)
        let decoded = try decoder.decode([String: AnyCodable].self, from: data)

        if case .string(let s) = decoded["string"] { XCTAssertEqual(s, "hello") }
        else { XCTFail("Expected string") }

        if case .int(let i) = decoded["int"] { XCTAssertEqual(i, 42) }
        else { XCTFail("Expected int") }

        if case .double(let d) = decoded["double"] { XCTAssertEqual(d, 3.14, accuracy: 0.001) }
        else { XCTFail("Expected double") }

        if case .bool(let b) = decoded["bool"] { XCTAssertTrue(b) }
        else { XCTFail("Expected bool") }

        if case .null = decoded["null"] { /* pass */ }
        else { XCTFail("Expected null") }

        if case .array(let arr) = decoded["array"] { XCTAssertEqual(arr.count, 2) }
        else { XCTFail("Expected array") }

        if case .object(let obj) = decoded["object"] { XCTAssertNotNil(obj["nested"]) }
        else { XCTFail("Expected object") }
    }
}

// MARK: - MCP Wiki Tool Execution Tests

final class MCPWikiToolExecutionTests: XCTestCase {
    private var workspaceRoot: URL!

    override func setUpWithError() throws {
        workspaceRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrainAIMCPWikiToolTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let workspaceRoot, FileManager.default.fileExists(atPath: workspaceRoot.path) {
            try FileManager.default.removeItem(at: workspaceRoot)
        }
    }

    func testWikiToolsReadFromNamedWorkspace() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        let alpha = try await manager.create(name: "Alpha Workspace", slug: "alpha")
        let beta = try await manager.create(name: "Beta Workspace", slug: "beta")

        _ = try await WikiPageStore(workspaceURL: alpha.dataPath).createSynthesisPage(
            title: "Alpha Memory",
            question: "Where should alpha-only memory live?",
            answer: "Only in alpha.",
            ragContext: nil,
            model: nil,
            searchMode: .hybrid
        )
        let betaPage = try await WikiPageStore(workspaceURL: beta.dataPath).createSynthesisPage(
            title: "Beta Memory",
            question: "Where should beta-only memory live?",
            answer: "Only in beta.",
            ragContext: "Beta evidence context",
            model: "test-model",
            searchMode: .local
        )

        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)
        let search = try await callTool(
            server,
            name: "brainai_wiki_search",
            arguments: [
                "query": .string("Beta Memory"),
                "workspace": .string("beta")
            ]
        )
        let searchPayload = try toolPayload(from: search)
        XCTAssertEqual(intValue(searchPayload["count"]), 1)

        let pageResponse = try await callTool(
            server,
            name: "brainai_wiki_get_page",
            arguments: [
                "path_or_slug": .string(betaPage.slug),
                "workspace": .string("Beta Workspace")
            ]
        )
        let pagePayload = try toolPayload(from: pageResponse)
        XCTAssertEqual(stringValue(pagePayload["path"]), betaPage.path)
        XCTAssertTrue(stringValue(pagePayload["markdown"])?.contains("Only in beta.") ?? false)

        let reviewResponse = try await callTool(
            server,
            name: "brainai_wiki_review_queue",
            arguments: [
                "workspace": .string("beta"),
                "status": .string(WikiReviewStatus.needsReview.rawValue)
            ]
        )
        let reviewPayload = try toolPayload(from: reviewResponse)
        XCTAssertEqual(intValue(reviewPayload["count"]), 1)
    }

    func testWikiToolReturnsErrorForUnknownNamedWorkspace() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        let active = try await manager.create(name: "Active Workspace", slug: "active")
        _ = try await WikiPageStore(workspaceURL: active.dataPath).createSynthesisPage(
            title: "Active Memory",
            question: "Should this leak through unknown workspace lookups?",
            answer: "No.",
            ragContext: nil,
            model: nil,
            searchMode: .hybrid
        )

        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)
        let response = try await callTool(
            server,
            name: "brainai_wiki_search",
            arguments: [
                "query": .string("Active Memory"),
                "workspace": .string("missing-workspace")
            ]
        )

        XCTAssertNil(response.result)
        XCTAssertEqual(response.error?.code, -32000)
        XCTAssertTrue(response.error?.message.contains("Workspace not found: missing-workspace") ?? false)
    }

    func testWikiCreateNoteToolWritesReviewablePage() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        _ = try await manager.create(name: "Notes WS", slug: "notes")
        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)

        let response = try await callTool(
            server,
            name: "brainai_wiki_create_note",
            arguments: [
                "title": .string("Use qwen2.5 for extraction"),
                "body": .string("We decided to use qwen2.5:14b for the extraction role."),
                "kind": .string("decision"),
                "tags": .array([.string("llm"), .string("config")]),
                "workspace": .string("notes")
            ]
        )
        let payload = try toolPayload(from: response)
        XCTAssertEqual(stringValue(payload["status"]), "needs_review")
        XCTAssertEqual(stringValue(payload["kind"]), "decision")
        let path = try XCTUnwrap(stringValue(payload["path"]))
        XCTAssertTrue(path.hasPrefix("decisions/"), "decision pages live under decisions/, got \(path)")

        // The new page is queued for human review.
        let review = try await callTool(
            server,
            name: "brainai_wiki_review_queue",
            arguments: ["workspace": .string("notes")]
        )
        XCTAssertEqual(intValue(try toolPayload(from: review)["count"]), 1)

        // And is readable back with its content and frontmatter.
        let page = try await callTool(
            server,
            name: "brainai_wiki_get_page",
            arguments: ["path_or_slug": .string(path), "workspace": .string("notes")]
        )
        let markdown = try XCTUnwrap(stringValue(try toolPayload(from: page)["markdown"]))
        XCTAssertTrue(markdown.contains("qwen2.5:14b"))
        XCTAssertTrue(markdown.contains("type: decision"))
    }

    func testWikiCreateNoteToolCanAutoAccept() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        _ = try await manager.create(name: "Auto WS", slug: "auto")
        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)

        let response = try await callTool(
            server,
            name: "brainai_wiki_create_note",
            arguments: [
                "title": .string("Trusted fact"),
                "body": .string("This was auto accepted."),
                "auto_accept": .bool(true),
                "workspace": .string("auto")
            ]
        )
        XCTAssertEqual(stringValue(try toolPayload(from: response)["status"]), "auto_accepted")
    }

    func testWikiAppendLogToolRecordsEntry() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        _ = try await manager.create(name: "Log WS", slug: "logws")
        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)

        let response = try await callTool(
            server,
            name: "brainai_wiki_append_log",
            arguments: [
                "message": .string("Fixed the I2C sensor timing bug"),
                "workspace": .string("logws")
            ]
        )
        XCTAssertEqual(boolValue(try toolPayload(from: response)["ok"]), true)

        let logPage = try await callTool(
            server,
            name: "brainai_wiki_get_page",
            arguments: ["path_or_slug": .string("log.md"), "workspace": .string("logws")]
        )
        let markdown = try XCTUnwrap(stringValue(try toolPayload(from: logPage)["markdown"]))
        XCTAssertTrue(markdown.contains("Fixed the I2C sensor timing bug"))
    }

    func testWikiRecordSourceToolCreatesSourcePage() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        _ = try await manager.create(name: "Src WS", slug: "srcws")
        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)

        let response = try await callTool(
            server,
            name: "brainai_wiki_record_source",
            arguments: [
                "title": .string("Meeting notes 2026-06-15"),
                "content": .string("Decided to ship the memory feature today."),
                "source_type": .string("note"),
                "workspace": .string("srcws")
            ]
        )
        let path = try XCTUnwrap(stringValue(try toolPayload(from: response)["path"]))
        XCTAssertTrue(path.hasPrefix("sources/"), "source pages live under sources/, got \(path)")

        let review = try await callTool(
            server,
            name: "brainai_wiki_review_queue",
            arguments: ["workspace": .string("srcws")]
        )
        XCTAssertEqual(intValue(try toolPayload(from: review)["count"]), 1)
    }

    func testListWorkspacesToolReportsAllWorkspaces() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        let first = try await manager.create(name: "First", slug: "first")
        _ = try await manager.create(name: "Second", slug: "second")
        try await manager.setActive(id: first.id)

        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)
        let response = try await callTool(server, name: "brainai_list_workspaces", arguments: [:])
        let payload = try toolPayload(from: response)
        XCTAssertEqual(intValue(payload["count"]), 2)

        guard case .array(let rows) = payload["results"] else {
            return XCTFail("results should be an array")
        }
        let activeSlugs: [String] = rows.compactMap { row in
            guard case .object(let obj) = row,
                  case .bool(true) = obj["active"],
                  case .string(let slug) = obj["slug"] else { return nil }
            return slug
        }
        XCTAssertEqual(activeSlugs, ["first"])
    }

    func testWikiCreateNoteToolStoresDomain() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        _ = try await manager.create(name: "Domain WS", slug: "domainws")
        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)

        let response = try await callTool(
            server,
            name: "brainai_wiki_create_note",
            arguments: [
                "title": .string("Auth service uses JWT"),
                "body": .string("The work auth service issues JWTs."),
                "kind": .string("decision"),
                "domain": .string("work"),
                "workspace": .string("domainws")
            ]
        )
        let path = try XCTUnwrap(stringValue(try toolPayload(from: response)["path"]))

        let page = try await callTool(
            server,
            name: "brainai_wiki_get_page",
            arguments: ["path_or_slug": .string(path), "workspace": .string("domainws")]
        )
        let markdown = try XCTUnwrap(stringValue(try toolPayload(from: page)["markdown"]))
        XCTAssertTrue(markdown.contains("domain: work"), "frontmatter should record the domain")
    }

    func testResourcesListAndRead() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        _ = try await manager.create(name: "Res WS", slug: "resws")
        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)

        let list = try await send(server, MCPRequest(id: 1, method: "resources/list"))
        let resources = try XCTUnwrap(list.result?.resources)
        XCTAssertGreaterThanOrEqual(resources.count, 2)
        XCTAssertTrue(resources.contains { $0.uri == MCPServer.schemaResourceURI })
        XCTAssertTrue(resources.contains { $0.uri == MCPServer.indexResourceURI })

        let read = try await send(
            server,
            MCPRequest(id: 2, method: "resources/read", params: MCPParams(uri: MCPServer.schemaResourceURI))
        )
        let contents = try XCTUnwrap(read.result?.contents)
        XCTAssertEqual(contents.first?.uri, MCPServer.schemaResourceURI)
        XCTAssertTrue(contents.first?.text?.contains("BrainAI Memory Schema") ?? false)

        let unknown = try await send(
            server,
            MCPRequest(id: 3, method: "resources/read", params: MCPParams(uri: "brainai://memory/nope"))
        )
        XCTAssertNotNil(unknown.error)
    }

    func testWikiSearchFiltersByDomain() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        _ = try await manager.create(name: "Filter WS", slug: "filterws")
        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)

        // Use a body-only keyword so the workspace log (which records titles) doesn't match.
        _ = try await callTool(server, name: "brainai_wiki_create_note", arguments: [
            "title": .string("Alpha note"), "body": .string("zzkeyword apple"),
            "domain": .string("work"), "workspace": .string("filterws")
        ])
        _ = try await callTool(server, name: "brainai_wiki_create_note", arguments: [
            "title": .string("Beta note"), "body": .string("zzkeyword banana"),
            "domain": .string("hobby-esp32"), "workspace": .string("filterws")
        ])

        let all = try await callTool(server, name: "brainai_wiki_search", arguments: [
            "query": .string("zzkeyword"), "workspace": .string("filterws")
        ])
        XCTAssertEqual(intValue(try toolPayload(from: all)["count"]), 2)

        let workOnly = try await callTool(server, name: "brainai_wiki_search", arguments: [
            "query": .string("zzkeyword"), "domain": .string("work"), "workspace": .string("filterws")
        ])
        XCTAssertEqual(intValue(try toolPayload(from: workOnly)["count"]), 1)
    }

    func testWikiCreateNoteInheritsWorkspaceDomain() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        let ws = try await manager.create(name: "Domain Default WS", slug: "ddws")
        try await manager.setDomain(id: ws.id, domain: "personal-project")
        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)

        let response = try await callTool(server, name: "brainai_wiki_create_note", arguments: [
            "title": .string("Note without domain"), "body": .string("body"),
            "workspace": .string("ddws")
        ])
        let path = try XCTUnwrap(stringValue(try toolPayload(from: response)["path"]))
        let page = try await callTool(server, name: "brainai_wiki_get_page", arguments: [
            "path_or_slug": .string(path), "workspace": .string("ddws")
        ])
        let markdown = try XCTUnwrap(stringValue(try toolPayload(from: page)["markdown"]))
        XCTAssertTrue(markdown.contains("domain: personal-project"))
    }

    func testResourcesIncludePagesAndReadByURI() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        _ = try await manager.create(name: "Page Res WS", slug: "pageresws")
        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)

        let created = try await callTool(server, name: "brainai_wiki_create_note", arguments: [
            "title": .string("Findable page"), "body": .string("unique-content-xyz"),
            "workspace": .string("pageresws")
        ])
        let path = try XCTUnwrap(stringValue(try toolPayload(from: created)["path"]))

        let list = try await send(server, MCPRequest(id: 1, method: "resources/list"))
        let resources = try XCTUnwrap(list.result?.resources)
        let pageURI = MCPServer.pageResourceURIPrefix + path
        XCTAssertTrue(resources.contains { $0.uri == pageURI }, "page should be listed as a resource")

        let read = try await send(server, MCPRequest(id: 2, method: "resources/read", params: MCPParams(uri: pageURI)))
        let contents = try XCTUnwrap(read.result?.contents)
        XCTAssertTrue(contents.first?.text?.contains("unique-content-xyz") ?? false)
    }

    func testReviewQueueFiltersByDomain() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        _ = try await manager.create(name: "RQ WS", slug: "rqws")
        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)

        _ = try await callTool(server, name: "brainai_wiki_create_note", arguments: [
            "title": .string("Work item"), "body": .string("b1"),
            "domain": .string("work"), "workspace": .string("rqws")
        ])
        _ = try await callTool(server, name: "brainai_wiki_create_note", arguments: [
            "title": .string("Personal item"), "body": .string("b2"),
            "domain": .string("personal"), "workspace": .string("rqws")
        ])

        let all = try await callTool(server, name: "brainai_wiki_review_queue", arguments: ["workspace": .string("rqws")])
        XCTAssertEqual(intValue(try toolPayload(from: all)["count"]), 2)

        let work = try await callTool(server, name: "brainai_wiki_review_queue", arguments: [
            "workspace": .string("rqws"), "domain": .string("work")
        ])
        XCTAssertEqual(intValue(try toolPayload(from: work)["count"]), 1)
    }

    func testTemplateResources() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        _ = try await manager.create(name: "Tpl WS", slug: "tplws")
        let server = MCPServer(lightRAGClient: TestLightRAGClient(), workspaceManager: manager)

        let list = try await send(server, MCPRequest(id: 1, method: "resources/list"))
        let resources = try XCTUnwrap(list.result?.resources)
        let decisionURI = MCPServer.templateResourceURIPrefix + "decision"
        XCTAssertTrue(resources.contains { $0.uri == decisionURI }, "decision template should be listed")

        let read = try await send(server, MCPRequest(id: 2, method: "resources/read", params: MCPParams(uri: decisionURI)))
        let text = try XCTUnwrap(read.result?.contents?.first?.text)
        XCTAssertTrue(text.contains("## Decision"))
        XCTAssertTrue(text.contains("## Consequences"))

        // A kind without a template returns an error.
        let bad = try await send(
            server,
            MCPRequest(id: 3, method: "resources/read", params: MCPParams(uri: MCPServer.templateResourceURIPrefix + "log"))
        )
        XCTAssertNotNil(bad.error)
    }

    private func callTool(
        _ server: MCPServer,
        name: String,
        arguments: [String: AnyCodable]
    ) async throws -> MCPResponse {
        try await send(server, MCPRequest(id: 1, method: "tools/call", params: MCPParams(name: name, arguments: arguments)))
    }

    private func send(_ server: MCPServer, _ request: MCPRequest) async throws -> MCPResponse {
        let requestData = try JSONEncoder().encode(request)
        let transport = TestMCPTransport(requests: [requestData])
        let serverTask = Task {
            try await server.start(transport: transport)
        }

        let responseData = await transport.waitForSent()
        await server.stop()
        try await serverTask.value
        return try JSONDecoder().decode(MCPResponse.self, from: responseData)
    }

    private func toolPayload(from response: MCPResponse) throws -> [String: AnyCodable] {
        XCTAssertNil(response.error)
        let text = try XCTUnwrap(response.result?.content?.first?.text)
        let data = try XCTUnwrap(text.data(using: .utf8))
        return try JSONDecoder().decode([String: AnyCodable].self, from: data)
    }

    private func stringValue(_ value: AnyCodable?) -> String? {
        guard case .string(let string) = value else { return nil }
        return string
    }

    private func intValue(_ value: AnyCodable?) -> Int? {
        guard case .int(let int) = value else { return nil }
        return int
    }

    private func boolValue(_ value: AnyCodable?) -> Bool? {
        guard case .bool(let bool) = value else { return nil }
        return bool
    }
}

// MARK: - MCP WebSocket Server Integration

final class MCPWebSocketServerTests: XCTestCase {
    private var workspaceRoot: URL!

    override func setUpWithError() throws {
        workspaceRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrainAIMCPWSTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let workspaceRoot, FileManager.default.fileExists(atPath: workspaceRoot.path) {
            try FileManager.default.removeItem(at: workspaceRoot)
        }
    }

    func testWebSocketServerServesToolsOverLoopback() async throws {
        let manager = WorkspaceManager(workspacesDirectory: workspaceRoot)
        _ = try await manager.create(name: "WS Host", slug: "wshost")

        // Pick a high port to reduce collision risk on shared CI runners.
        let port: UInt16 = 8779
        let server = MCPWebSocketServer(
            port: port,
            workspaceManager: manager,
            makeClient: { TestLightRAGClient() }
        )

        do {
            try server.start()
        } catch {
            throw XCTSkip("Could not bind MCP WebSocket server on port \(port): \(error)")
        }
        defer { server.stop() }

        let transport = WebSocketTransport(url: URL(string: "ws://127.0.0.1:\(port)")!)
        transport.connect()
        defer { Task { await transport.close() } }

        // Send tools/list and expect all 12 tools back.
        let request = MCPRequest(id: 7, method: "tools/list")
        try await transport.send(try JSONEncoder().encode(request))
        let responseData = try await transport.receive()
        let response = try JSONDecoder().decode(MCPResponse.self, from: responseData)

        XCTAssertNil(response.error)
        XCTAssertEqual(response.id, 7)
        let toolCount = response.result?.tools?.count ?? 0
        XCTAssertEqual(toolCount, 12, "WebSocket server should expose the full tool set")
    }
}

// MARK: - OpenAI-Compatible SSE Streaming

final class OpenAICompatibleStreamingTests: XCTestCase {

    func testStreamConcatenatesDeltas() async throws {
        let sse = """
        data: {"choices":[{"delta":{"content":"Hello"}}]}

        data: {"choices":[{"delta":{"content":", "}}]}

        data: {"choices":[{"delta":{"content":"world"}}]}

        data: [DONE]

        """
        MockSSEURLProtocol.responseBody = Data(sse.utf8)
        MockSSEURLProtocol.statusCode = 200

        let stream = try await OpenAICompatibleStreaming.chatStream(
            baseURL: "https://example.test/v1",
            apiKey: "test-key",
            model: "gpt-test",
            prompt: "hi",
            options: GenerateOptions(),
            session: Self.mockSession()
        )

        var result = ""
        for await delta in stream { result += delta }
        XCTAssertEqual(result, "Hello, world")
    }

    func testStreamThrowsOnUnauthorized() async {
        MockSSEURLProtocol.responseBody = Data(#"{"error":"invalid key"}"#.utf8)
        MockSSEURLProtocol.statusCode = 401

        do {
            _ = try await OpenAICompatibleStreaming.chatStream(
                baseURL: "https://example.test/v1",
                apiKey: "bad",
                model: "gpt-test",
                prompt: "hi",
                options: GenerateOptions(),
                session: Self.mockSession()
            )
            XCTFail("expected an error on HTTP 401")
        } catch {
            // expected
        }
    }

    private static func mockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockSSEURLProtocol.self]
        return URLSession(configuration: config)
    }
}

/// URLProtocol stub that returns a canned SSE body for streaming tests.
final class MockSSEURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody = Data()
    nonisolated(unsafe) static var statusCode = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.test")!,
            statusCode: Self.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private actor TestMCPTransport: MCPTransport {
    private var requests: [Data]
    private var sentResponses: [Data] = []
    private var receiveWaiters: [CheckedContinuation<Data, Error>] = []
    private var sendWaiters: [CheckedContinuation<Data, Never>] = []
    private var isClosed = false

    init(requests: [Data]) {
        self.requests = requests
    }

    func receive() async throws -> Data {
        if !requests.isEmpty {
            return requests.removeFirst()
        }

        if isClosed {
            throw CancellationError()
        }

        return try await withCheckedThrowingContinuation { continuation in
            receiveWaiters.append(continuation)
        }
    }

    func send(_ data: Data) async throws {
        if sendWaiters.isEmpty {
            sentResponses.append(data)
        } else {
            sendWaiters.removeFirst().resume(returning: data)
        }
    }

    func close() async {
        isClosed = true
        for waiter in receiveWaiters {
            waiter.resume(throwing: CancellationError())
        }
        receiveWaiters.removeAll()
    }

    func waitForSent() async -> Data {
        if !sentResponses.isEmpty {
            return sentResponses.removeFirst()
        }

        return await withCheckedContinuation { continuation in
            sendWaiters.append(continuation)
        }
    }
}

private final class TestLightRAGClient: LightRAGClientProtocol, @unchecked Sendable {
    func query(_ question: String, mode: SearchMode, topK: Int, onlyNeedContext: Bool) async throws -> QueryResponse {
        QueryResponse(response: "test response")
    }

    func insertText(_ text: String, description: String) async throws -> InsertTextResponse {
        InsertTextResponse(status: "ok", message: "inserted", trackId: "test-track")
    }

    func createEntity(_ request: EntityCreateRequest) async throws {}

    func createRelation(_ request: RelationCreateRequest) async throws {}

    func deleteEntity(_ name: String) async throws {}

    func listDocuments(page: Int, pageSize: Int, status: String?) async throws -> DocumentListResponse {
        DocumentListResponse(documents: [], total: 0, page: page, pageSize: pageSize, hasMore: false)
    }

    func healthCheck() async throws -> HealthResponse {
        HealthResponse(status: "ok")
    }

    func getGraphLabels() async throws -> GraphLabelsResponse {
        GraphLabelsResponse(entityLabels: [], relationLabels: [])
    }

    func searchGraphLabels(query: String, limit: Int) async throws -> [String] {
        []
    }

    func searchGraph(label: String, searchText: String, maxItems: Int) async throws -> GraphSearchResponse {
        GraphSearchResponse(nodes: [], edges: [])
    }

    func getEntity(_ name: String) async throws -> GraphNodeData {
        GraphNodeData(name: name)
    }

    func queryData(_ question: String, mode: SearchMode, topK: Int) async throws -> QueryDataResponse {
        QueryDataResponse()
    }
}

// MARK: - MCP Client Tests

final class MCPClientTests: XCTestCase {

    func testMCPClientErrorDescriptions() {
        let notInit = MCPClientError.notInitialized
        XCTAssertTrue(notInit.errorDescription?.contains("not initialized") ?? false)

        let initFailed = MCPClientError.initializationFailed("bad response")
        XCTAssertTrue(initFailed.errorDescription?.contains("bad response") ?? false)

        let toolFailed = MCPClientError.toolCallFailed("brainai_query", "timeout")
        XCTAssertTrue(toolFailed.errorDescription?.contains("brainai_query") ?? false)
        XCTAssertTrue(toolFailed.errorDescription?.contains("timeout") ?? false)

        let transport = MCPClientError.transportError("disconnected")
        XCTAssertTrue(transport.errorDescription?.contains("disconnected") ?? false)

        let timeout = MCPClientError.timeout
        XCTAssertTrue(timeout.errorDescription?.contains("timed out") ?? false)
    }

    func testMCPServerInfoCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let info = MCPServerInfo(
            protocolVersion: "2024-11-05",
            serverInfo: MCPServerIdentity(name: "TestServer", version: "1.0.0"),
            capabilities: MCPCapabilities(tools: [:])
        )

        let data = try encoder.encode(info)
        let decoded = try decoder.decode(MCPServerInfo.self, from: data)

        XCTAssertEqual(decoded.protocolVersion, "2024-11-05")
        XCTAssertEqual(decoded.serverInfo?.name, "TestServer")
        XCTAssertEqual(decoded.serverInfo?.version, "1.0.0")
        XCTAssertNotNil(decoded.capabilities?.tools)
    }

    func testMCPToolCallResult() {
        let result = MCPToolCallResult(
            toolName: "brainai_query",
            content: ["Line 1", "Line 2"],
            isError: false
        )

        XCTAssertEqual(result.toolName, "brainai_query")
        XCTAssertEqual(result.content.count, 2)
        XCTAssertEqual(result.text, "Line 1\nLine 2")
        XCTAssertFalse(result.isError)
    }

    func testMCPConnectionInfo() {
        let info = MCPConnectionInfo(
            id: "test-1",
            name: "Test Server",
            serverName: "Remote Server",
            serverVersion: "2.0",
            toolCount: 5,
            status: .connected
        )

        XCTAssertEqual(info.id, "test-1")
        XCTAssertEqual(info.name, "Test Server")
        XCTAssertEqual(info.serverName, "Remote Server")
        XCTAssertEqual(info.serverVersion, "2.0")
        XCTAssertEqual(info.toolCount, 5)

        if case .connected = info.status { /* pass */ }
        else { XCTFail("Expected connected status") }
    }

    func testMCPClientManagerInitialState() {
        let manager = MCPClientManager()
        XCTAssertTrue(manager.connections.isEmpty)
    }
}

// MARK: - HTTP Client Error Tests

final class HTTPClientErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertEqual(HTTPClientError.invalidURL.errorDescription, "Invalid URL format")
        XCTAssertTrue(HTTPClientError.requestFailed(statusCode: 404, data: nil).errorDescription?.contains("404") ?? false)
        XCTAssertTrue(HTTPClientError.decodingFailed("bad json").errorDescription?.contains("bad json") ?? false)
        XCTAssertTrue(HTTPClientError.networkError("no internet").errorDescription?.contains("no internet") ?? false)
        XCTAssertEqual(HTTPClientError.unauthorized.errorDescription, "Authentication failed (401 Unauthorized)")
        XCTAssertTrue(HTTPClientError.tlsPinningFailed.errorDescription?.contains("TLS") ?? false)
    }
}

// MARK: - Wiki Memory Store Tests

final class WikiMemoryStoreTests: XCTestCase {
    private var workspaceURL: URL!

    override func setUpWithError() throws {
        workspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrainAIWikiStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let workspaceURL, FileManager.default.fileExists(atPath: workspaceURL.path) {
            try FileManager.default.removeItem(at: workspaceURL)
        }
    }

    func testEnsureScaffoldCreatesRawWikiSchemaAndMetadataFolders() async throws {
        let store = WikiPageStore(workspaceURL: workspaceURL)

        try await store.ensureScaffold()

        XCTAssertTrue(FileManager.default.fileExists(atPath: workspaceURL.appendingPathComponent("raw/documents").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspaceURL.appendingPathComponent("wiki/sources").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspaceURL.appendingPathComponent("schema/MEMORY_SCHEMA.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspaceURL.appendingPathComponent("metadata").path))
    }

    func testCreateSourcePagePreservesRawSourceAndQueuesReview() async throws {
        let store = WikiPageStore(workspaceURL: workspaceURL)
        let content = "Persistent memory needs raw sources plus compiled wiki pages."

        let page = try await store.createSourcePage(
            title: "Memory Note",
            content: content,
            sourceType: "note",
            trackId: "track-1"
        )

        let manifest = try await store.listSourceManifestEntries()
        let reviews = try await store.listReviewItems()

        XCTAssertEqual(page.kind, .source)
        XCTAssertTrue(page.markdown.contains("status: needs_review"))
        XCTAssertEqual(manifest.count, 1)
        XCTAssertEqual(manifest.first?.sourceType, "note")
        XCTAssertEqual(manifest.first?.lightRAGTrackID, "track-1")
        XCTAssertNotNil(manifest.first?.rawPath)
        XCTAssertNotNil(manifest.first?.checksum)
        XCTAssertEqual(manifest.first?.byteCount, Data(content.utf8).count)
        XCTAssertEqual(reviews.count, 1)
        XCTAssertEqual(reviews.first?.status, .needsReview)

        let rawContent = try await store.readRawSource(for: try XCTUnwrap(manifest.first))
        XCTAssertEqual(rawContent, content)
    }

    func testCreateSynthesisPageQueuesReview() async throws {
        let store = WikiPageStore(workspaceURL: workspaceURL)

        let page = try await store.createSynthesisPage(
            title: "Hybrid Memory Direction",
            question: "What should BrainAI build next?",
            answer: "Build a reviewable compiled memory layer over LightRAG.",
            ragContext: "LightRAG handles retrieval. Wiki pages hold stable reviewed knowledge.",
            model: "qwen2.5:14b",
            searchMode: .hybrid
        )
        let reviews = try await store.listReviewItems()

        XCTAssertEqual(page.kind, .synthesis)
        XCTAssertEqual(page.path, "syntheses/hybrid-memory-direction.md")
        XCTAssertTrue(page.markdown.contains("type: synthesis"))
        XCTAssertTrue(page.markdown.contains("status: needs_review"))
        XCTAssertTrue(page.markdown.contains("search_mode: hybrid"))
        XCTAssertTrue(page.markdown.contains("## Retrieved Context"))
        XCTAssertEqual(reviews.count, 1)
        XCTAssertEqual(reviews.first?.pagePath, page.path)
        XCTAssertEqual(reviews.first?.status, .needsReview)
    }

    func testUpdateReviewItemStatusUpdatesQueueAndPageFrontmatter() async throws {
        let store = WikiPageStore(workspaceURL: workspaceURL)
        let page = try await store.createSynthesisPage(
            title: "Reviewable Memory",
            question: "What should review do?",
            answer: "Review should update both queue metadata and page frontmatter.",
            ragContext: nil,
            model: nil,
            searchMode: .hybrid
        )
        let reviews = try await store.listReviewItems()
        let review = try XCTUnwrap(reviews.first)

        try await store.updateReviewItemStatus(id: review.id, status: .accepted)

        let updatedReviews = try await store.listReviewItems()
        let updatedReview = try XCTUnwrap(updatedReviews.first)
        let updatedPage = try await store.readPage(at: page.path)

        XCTAssertEqual(updatedReview.status, .accepted)
        XCTAssertEqual(updatedPage.frontmatter["status"], WikiReviewStatus.accepted.rawValue)
        XCTAssertTrue(updatedPage.markdown.contains("status: accepted"))
    }

    func testRegenerateIndexIncludesCreatedPagesByKind() async throws {
        let store = WikiPageStore(workspaceURL: workspaceURL)
        let source = try await store.createSourcePage(
            title: "Indexed Source",
            content: "Index this source page.",
            sourceType: "note",
            trackId: nil
        )
        let synthesis = try await store.createSynthesisPage(
            title: "Indexed Synthesis",
            question: "Should synthesis appear in the index?",
            answer: "Yes.",
            ragContext: nil,
            model: nil,
            searchMode: .mix
        )

        try await store.regenerateIndex()

        let index = try await store.readPage(at: "index.md")
        XCTAssertTrue(index.markdown.contains("## Source"))
        XCTAssertTrue(index.markdown.contains("[[\(source.path)]] Indexed Source"))
        XCTAssertTrue(index.markdown.contains("## Synthesis"))
        XCTAssertTrue(index.markdown.contains("[[\(synthesis.path)]] Indexed Synthesis"))
    }

    func testWikiSyncStateTracksPageChecksumAndTrackID() async throws {
        let store = WikiPageStore(workspaceURL: workspaceURL)
        let page = try await store.createSynthesisPage(
            title: "Synced Memory",
            question: "What changed?",
            answer: "Accepted wiki pages are synced back into retrieval.",
            ragContext: nil,
            model: nil,
            searchMode: .local
        )

        let initiallyNeedsSync = try await store.needsLightRAGSync(page)
        XCTAssertTrue(initiallyNeedsSync)

        try await store.recordLightRAGSync(page: page, trackId: "track-sync-1")
        let optionalState = try await store.syncState(for: page)
        let state = try XCTUnwrap(optionalState)

        let needsSyncAfterRecord = try await store.needsLightRAGSync(page)
        XCTAssertFalse(needsSyncAfterRecord)
        XCTAssertEqual(state.pagePath, page.path)
        XCTAssertEqual(state.lightRAGTrackID, "track-sync-1")
        XCTAssertFalse(state.checksum.isEmpty)

        var changedPage = page
        changedPage.markdown += "\n\nNew accepted detail."
        let changedPageNeedsSync = try await store.needsLightRAGSync(changedPage)
        XCTAssertTrue(changedPageNeedsSync)
    }
}
