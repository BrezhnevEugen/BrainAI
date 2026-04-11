import Foundation

// MARK: - ServiceOrchestrator

/// Orchestrates all managed services and processes
@Observable
public final class ServiceOrchestrator: @unchecked Sendable {
    public let ollama: OllamaProcessManager
    public private(set) var lightRAGInstances: [UUID: LightRAGProcessManager]

    private let lock = NSLock()

    /// Initialize service orchestrator
    /// - Parameters:
    ///   - ollama: Ollama process manager instance
    ///   - lightRAGInstances: Dictionary of workspace ID to LightRAG process managers
    public init(
        ollama: OllamaProcessManager = OllamaProcessManager(),
        lightRAGInstances: [UUID: LightRAGProcessManager] = [:]
    ) {
        self.ollama = ollama
        self.lightRAGInstances = lightRAGInstances
    }

    // MARK: - Thread-safe accessors (sync only, never called from async)

    private func lockedInstances() -> [UUID: LightRAGProcessManager] {
        lock.lock()
        defer { lock.unlock() }
        return lightRAGInstances
    }

    private func lockedInstance(for id: UUID) -> LightRAGProcessManager? {
        lock.lock()
        defer { lock.unlock() }
        return lightRAGInstances[id]
    }

    // MARK: - Status

    /// Overall status of all services
    public func overallStatus() async -> ProcessStatus {
        let ollamaStatus = await ollama.status
        let instances = Array(lockedInstances().values)

        var lightRAGStatuses: [ProcessStatus] = []
        for instance in instances {
            let status = await instance.status
            lightRAGStatuses.append(status)
        }

        switch ollamaStatus {
        case .error(let message):
            return .error("Ollama: \(message)")
        case .starting:
            return .starting
        case .stopped:
            if lightRAGStatuses.allSatisfy({ if case .stopped = $0 { return true } else { return false } }) {
                return .stopped
            } else {
                return .starting
            }
        case .running:
            let allGood = lightRAGStatuses.allSatisfy { status in
                if case .running = status { return true }
                if case .stopped = status { return true }
                return false
            }
            return allGood ? .running : .starting
        }
    }

    // MARK: - Lifecycle

    /// Start all services
    /// - Throws: BrainAIError if any service fails to start
    public func startAll() async throws {
        try await ollama.start()

        let instances = lockedInstances()
        for (_, manager) in instances {
            try await manager.start()
        }
    }

    /// Stop all services
    /// - Throws: BrainAIError if any service fails to stop
    public func stopAll() async throws {
        let instances = lockedInstances()
        for (_, manager) in instances {
            try await manager.stop()
        }
        try await ollama.stop()
    }

    /// Start a specific workspace's LightRAG service
    /// - Parameter id: Workspace identifier
    /// - Throws: BrainAIError if workspace not found or cannot be started
    public func startWorkspace(_ id: UUID) async throws {
        guard let manager = lockedInstance(for: id) else {
            throw BrainAIError.workspaceError("LightRAG instance not found for workspace: \(id)")
        }
        try await manager.start()
    }

    /// Stop a specific workspace's LightRAG service
    /// - Parameter id: Workspace identifier
    /// - Throws: BrainAIError if workspace not found or cannot be stopped
    public func stopWorkspace(_ id: UUID) async throws {
        guard let manager = lockedInstance(for: id) else {
            throw BrainAIError.workspaceError("LightRAG instance not found for workspace: \(id)")
        }
        try await manager.stop()
    }

    /// Register a new LightRAG instance for a workspace
    /// - Parameters:
    ///   - id: Workspace identifier
    ///   - manager: LightRAG process manager instance
    public func registerWorkspace(_ id: UUID, manager: LightRAGProcessManager) {
        lock.lock()
        defer { lock.unlock() }
        lightRAGInstances[id] = manager
    }

    /// Unregister a workspace's LightRAG instance
    /// - Parameter id: Workspace identifier
    public func unregisterWorkspace(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        lightRAGInstances.removeValue(forKey: id)
    }
}
