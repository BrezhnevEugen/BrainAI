import Foundation

// MARK: - ManagedProcess Protocol

/// Protocol for managing long-running background processes
public protocol ManagedProcess: Sendable {
    /// Name identifier for the process
    var processName: String { get }

    /// Port the process listens on
    var port: UInt16 { get }

    /// Current status of the process
    var status: ProcessStatus { get async }

    /// Start the process
    /// - Throws: BrainAIError if process cannot be started
    func start() async throws

    /// Stop the process
    /// - Throws: BrainAIError if process cannot be stopped
    func stop() async throws

    /// Restart the process (stop then start)
    /// - Throws: BrainAIError if process cannot be restarted
    func restart() async throws

    /// Check if the process is healthy
    /// - Returns: True if process is running and healthy
    /// - Throws: BrainAIError if health check fails
    func healthCheck() async throws -> Bool
}

// MARK: - Default Restart Implementation

extension ManagedProcess {
    /// Default implementation of restart
    public func restart() async throws {
        try await stop()
        try await start()
    }
}
