import Foundation

// MARK: - WorkspaceQueryResult

/// Result of querying across a workspace
public struct WorkspaceQueryResult: Sendable {
    /// The workspace that was queried
    public let workspace: Workspace

    /// Query response from LightRAG
    public let result: QueryResponse

    /// Relevance score of the result
    public let relevanceScore: Float

    public init(workspace: Workspace, result: QueryResponse, relevanceScore: Float) {
        self.workspace = workspace
        self.result = result
        self.relevanceScore = relevanceScore
    }
}

// MARK: - WorkspaceManager

/// Manages workspace lifecycle and queries
@Observable
public final class WorkspaceManager: @unchecked Sendable {
    public private(set) var workspaces: [Workspace]
    public var activeWorkspace: Workspace?

    private let workspacesDirectory: URL
    private let lock = NSLock()

    /// Initialize workspace manager
    /// - Parameter workspacesDirectory: Directory to store workspace data
    public init(workspacesDirectory: URL = URL.brainAIWorkspaces) {
        self.workspacesDirectory = workspacesDirectory
        self.workspaces = []
        self.activeWorkspace = nil

        Task {
            await loadWorkspaces()
        }
    }

    /// Create a new workspace
    /// - Parameters:
    ///   - name: Display name
    ///   - slug: URL-safe slug
    ///   - template: Optional template name
    /// - Returns: The created workspace
    public func create(name: String, slug: String, template: String? = nil) async throws -> Workspace {
        lock.lock()
        defer { lock.unlock() }

        // Ensure slug is unique
        if workspaces.contains(where: { $0.slug == slug }) {
            throw BrainAIError.workspaceError("Workspace with slug '\(slug)' already exists")
        }

        // Find available port
        let usedPorts = workspaces.map { $0.port }
        var port: UInt16 = 8001
        while usedPorts.contains(port) {
            port += 1
        }

        // Create data directory
        let dataPath = workspacesDirectory.appendingPathComponent(slug)
        try FileManager.default.createDirectory(at: dataPath, withIntermediateDirectories: true)

        let workspace = Workspace(
            name: name,
            slug: slug,
            port: port,
            dataPath: dataPath
        )

        workspaces.append(workspace)
        try await saveWorkspaces()

        return workspace
    }

    /// Delete a workspace
    /// - Parameter id: Workspace identifier
    public func delete(id: UUID) async throws {
        lock.lock()
        defer { lock.unlock() }

        guard let index = workspaces.firstIndex(where: { $0.id == id }) else {
            throw BrainAIError.workspaceError("Workspace not found: \(id)")
        }

        let workspace = workspaces[index]

        // Remove data directory
        try FileManager.default.removeItem(at: workspace.dataPath)

        workspaces.remove(at: index)

        if activeWorkspace?.id == id {
            activeWorkspace = nil
        }

        try await saveWorkspaces()
    }

    /// Start a workspace's services
    /// - Parameter id: Workspace identifier
    public func start(id: UUID) async throws {
        guard workspaces.contains(where: { $0.id == id }) else {
            throw BrainAIError.workspaceError("Workspace not found: \(id)")
        }

        // Note: Actual service starting would be handled by ServiceOrchestrator
        // This method is a placeholder for workspace-level start logic
    }

    /// Stop a workspace's services
    /// - Parameter id: Workspace identifier
    public func stop(id: UUID) async throws {
        guard workspaces.contains(where: { $0.id == id }) else {
            throw BrainAIError.workspaceError("Workspace not found: \(id)")
        }

        // Note: Actual service stopping would be handled by ServiceOrchestrator
        // This method is a placeholder for workspace-level stop logic
    }

    /// Query all workspaces
    /// - Parameters:
    ///   - question: The question to ask
    ///   - mode: Search mode to use
    /// - Returns: Array of results from each workspace
    public func queryAll(question: String, mode: SearchMode = .hybrid) async throws -> [WorkspaceQueryResult] {
        var results: [WorkspaceQueryResult] = []

        lock.lock()
        let workspacesCopy = workspaces
        lock.unlock()

        for workspace in workspacesCopy {
            do {
                // Placeholder: In a real implementation, this would query LightRAG
                let response = QueryResponse(
                    response: "Response from \(workspace.name)",
                    references: []
                )
                let result = WorkspaceQueryResult(
                    workspace: workspace,
                    result: response,
                    relevanceScore: 0.5
                )
                results.append(result)
            } catch {
                // Continue with next workspace on error
                continue
            }
        }

        return results
    }

    /// Load workspaces from disk
    private func loadWorkspaces() async {
        lock.lock()
        defer { lock.unlock() }

        let configPath = workspacesDirectory.appendingPathComponent("workspaces.json")

        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: configPath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            workspaces = try decoder.decode([Workspace].self, from: data)
        } catch {
            // Log error, start with empty workspaces
            workspaces = []
        }
    }

    /// Save workspaces to disk
    private func saveWorkspaces() async throws {
        lock.lock()
        let workspacesCopy = workspaces
        lock.unlock()

        try workspacesDirectory.ensureDirectoryExists()

        let configPath = workspacesDirectory.appendingPathComponent("workspaces.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(workspacesCopy)
        try data.write(to: configPath)
    }
}
