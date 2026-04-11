import XCTest
@testable import BrainAICore

// MARK: - BrainAICoreTests

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
