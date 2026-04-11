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

    /// Overall status of all services
    public func overallStatus() async -> ProcessStatus {
        let ollamaStatus = await ollama.status

        lock.lock()
        let instances = Array(lightRAGInstances.values)
        lock.unlock()

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
            if allGood {
                return .running
            } else {
                return .starting
            }
        }
    }

    /// Start all services
    /// - Throws: BrainAIError if any service fails to start
    public func startAll() async throws {
        try await ollama.start()

        lock.lock()
        defer { lock.unlock() }

        for (_, manager) in lightRAGInstances {
            try await manager.start()
        }
    }

    /// Stop all services
    /// - Throws: BrainAIError if any service fails to stop
    public func stopAll() async throws {
        lock.lock()
        let instancesCopy = lightRAGInstances
        lock.unlock()

        for (_, manager) in instancesCopy {
            try await manager.stop()
        }

        try await ollama.stop()
    }

    /// Start a specific workspace's LightRAG service
    /// - Parameter id: Workspace identifier
    /// - Throws: BrainAIError if workspace not found or cannot be started
    public func startWorkspace(_ id: UUID) async throws {
        lock.lock()
        let manager = lightRAGInstances[id]
        lock.unlock()

        guard let manager else {
            throw BrainAIError.workspaceError("LightRAG instance not found for workspace: \(id)")
        }

        try await manager.start()
    }

    /// Stop a specific workspace's LightRAG service
    /// - Parameter id: Workspace identifier
    /// - Throws: BrainAIError if workspace not found or cannot be stopped
    public func stopWorkspace(_ id: UUID) async throws {
        lock.lock()
        let manager = lightRAGInstances[id]
        lock.unlock()

        guard let manager else {
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
