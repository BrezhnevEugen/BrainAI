import Foundation
import Observation

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
    public static let shared = WorkspaceManager()

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

    // MARK: - Thread-safe accessors (sync only)

    private func lockedWorkspaces() -> [Workspace] {
        lock.lock()
        defer { lock.unlock() }
        return workspaces
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    // MARK: - CRUD

    /// Create a new workspace
    /// - Parameters:
    ///   - name: Display name
    ///   - slug: URL-safe slug
    ///   - template: Optional template name
    /// - Returns: The created workspace
    public func create(name: String, slug: String, template: String? = nil) async throws -> Workspace {
        let workspace: Workspace = try withLock {
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

            let ws = Workspace(
                name: name,
                slug: slug,
                port: port,
                dataPath: dataPath
            )

            workspaces.append(ws)
            if activeWorkspace == nil {
                activeWorkspace = ws
                AppConfiguration.shared.defaultWorkspaceID = ws.id.uuidString
            }
            return ws
        }

        try await saveWorkspaces()
        return workspace
    }

    /// Delete a workspace
    /// - Parameter id: Workspace identifier
    public func delete(id: UUID) async throws {
        try withLock {
            guard let index = workspaces.firstIndex(where: { $0.id == id }) else {
                throw BrainAIError.workspaceError("Workspace not found: \(id)")
            }

            let workspace = workspaces[index]
            try FileManager.default.removeItem(at: workspace.dataPath)
            workspaces.remove(at: index)

            if activeWorkspace?.id == id {
                activeWorkspace = workspaces.first
                AppConfiguration.shared.defaultWorkspaceID = activeWorkspace?.id.uuidString ?? ""
            }
        }

        try await saveWorkspaces()
    }

    /// Mark a workspace as active and persist it as the default workspace for app launch.
    public func setActive(id: UUID) async throws {
        try withLock {
            guard let workspace = workspaces.first(where: { $0.id == id }) else {
                throw BrainAIError.workspaceError("Workspace not found: \(id)")
            }

            activeWorkspace = workspace
            AppConfiguration.shared.defaultWorkspaceID = workspace.id.uuidString
        }
    }

    /// Start a workspace's services
    /// - Parameter id: Workspace identifier
    public func start(id: UUID) async throws {
        let exists = lockedWorkspaces().contains(where: { $0.id == id })
        guard exists else {
            throw BrainAIError.workspaceError("Workspace not found: \(id)")
        }
        // Actual service starting handled by ServiceOrchestrator
    }

    /// Stop a workspace's services
    /// - Parameter id: Workspace identifier
    public func stop(id: UUID) async throws {
        let exists = lockedWorkspaces().contains(where: { $0.id == id })
        guard exists else {
            throw BrainAIError.workspaceError("Workspace not found: \(id)")
        }
        // Actual service stopping handled by ServiceOrchestrator
    }

    // MARK: - Cross-workspace Query

    /// Query all workspaces
    /// - Parameters:
    ///   - question: The question to ask
    ///   - mode: Search mode to use
    /// - Returns: Array of results from each workspace
    public func queryAll(question: String, mode: SearchMode = .hybrid) async -> [WorkspaceQueryResult] {
        let workspacesCopy = lockedWorkspaces()
        var results: [WorkspaceQueryResult] = []

        for workspace in workspacesCopy {
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
        }

        return results
    }

    // MARK: - Persistence

    /// Load workspaces from disk
    private func loadWorkspaces() async {
        let configPath = workspacesDirectory.appendingPathComponent("workspaces.json")

        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: configPath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([Workspace].self, from: data)

            withLock {
                workspaces = loaded
                activeWorkspace = Self.resolveActiveWorkspace(from: loaded)
            }
        } catch {
            withLock { workspaces = [] }
        }
    }

    /// Save workspaces to disk
    private func saveWorkspaces() async throws {
        let workspacesCopy = lockedWorkspaces()

        try workspacesDirectory.ensureDirectoryExists()

        let configPath = workspacesDirectory.appendingPathComponent("workspaces.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(workspacesCopy)
        try data.write(to: configPath)
    }

    private static func resolveActiveWorkspace(from workspaces: [Workspace]) -> Workspace? {
        let defaultID = AppConfiguration.shared.defaultWorkspaceID
        if let uuid = UUID(uuidString: defaultID),
           let workspace = workspaces.first(where: { $0.id == uuid }) {
            return workspace
        }
        return workspaces.first
    }
}
