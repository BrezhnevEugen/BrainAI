import Foundation
import Observation

// MARK: - Connection State

/// State of a remote connection
public enum RemoteConnectionState: Sendable {
    case disconnected
    case connecting
    case connected(latency: TimeInterval)
    case error(String)

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var displayString: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting..."
        case .connected(let latency): "Connected (\(Int(latency * 1000))ms)"
        case .error(let msg): "Error: \(msg)"
        }
    }
}

// MARK: - Remote Connection Configuration

/// Configuration for a remote LightRAG connection
public struct RemoteConnectionConfig: Codable, Sendable {
    public var baseURL: String
    public var authToken: String?
    public var tlsPinnedHashes: [String]
    public var healthCheckInterval: TimeInterval
    public var retryMaxAttempts: Int
    public var retryBaseDelay: TimeInterval

    public init(
        baseURL: String,
        authToken: String? = nil,
        tlsPinnedHashes: [String] = [],
        healthCheckInterval: TimeInterval = 30,
        retryMaxAttempts: Int = 3,
        retryBaseDelay: TimeInterval = 1.0
    ) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.tlsPinnedHashes = tlsPinnedHashes
        self.healthCheckInterval = healthCheckInterval
        self.retryMaxAttempts = retryMaxAttempts
        self.retryBaseDelay = retryBaseDelay
    }

    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case authToken = "auth_token"
        case tlsPinnedHashes = "tls_pinned_hashes"
        case healthCheckInterval = "health_check_interval"
        case retryMaxAttempts = "retry_max_attempts"
        case retryBaseDelay = "retry_base_delay"
    }
}

// MARK: - Remote Connection Manager

/// Manages remote LightRAG connections with health monitoring and retry logic
@Observable
public final class RemoteConnectionManager: @unchecked Sendable {

    public var connectionState: RemoteConnectionState = .disconnected
    public var lastHealthCheck: Date?
    public var lastLatency: TimeInterval = 0
    public var serverInfo: HealthResponse?

    private var config: RemoteConnectionConfig?
    private var client: RemoteLightRAGClient?
    private var healthCheckTask: Task<Void, Never>?
    private let lock = NSLock()

    public init() {}

    // MARK: - Connection Lifecycle

    /// Connect to a remote LightRAG server
    public func connect(config: RemoteConnectionConfig) async {
        applyConfig(config)

        let newClient: RemoteLightRAGClient
        if !config.tlsPinnedHashes.isEmpty {
            newClient = RemoteLightRAGClient.withTLSPinning(
                baseURL: config.baseURL,
                authToken: config.authToken,
                pinnedCertificateHashes: Set(config.tlsPinnedHashes)
            )
        } else {
            newClient = RemoteLightRAGClient(
                baseURL: config.baseURL,
                authToken: config.authToken
            )
        }

        setClient(newClient)

        // Perform initial health check
        await performHealthCheck()

        // Start periodic health monitoring
        startHealthMonitoring()
    }

    /// Disconnect from the remote server
    public func disconnect() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
        clearConnection()
    }

    /// Get the active client (if connected)
    public var activeClient: LightRAGClientProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return connectionState.isConnected ? client : nil
    }

    // MARK: - Health Monitoring

    private func startHealthMonitoring() {
        healthCheckTask?.cancel()
        healthCheckTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let interval = self.config?.healthCheckInterval ?? 30
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self.performHealthCheck()
            }
        }
    }

    public func performHealthCheck() async {
        guard let client = getClientSync() else { return }

        let startTime = Date()
        do {
            let health = try await client.healthCheck()
            let latency = Date().timeIntervalSince(startTime)
            applyHealthResult(latency: latency, health: health)
        } catch {
            applyHealthError(error.localizedDescription)
        }
    }

    // MARK: - Sync Helpers (avoid NSLock in async context)

    private func getClientSync() -> RemoteLightRAGClient? {
        lock.lock()
        defer { lock.unlock() }
        return client
    }

    private func applyConfig(_ config: RemoteConnectionConfig) {
        lock.lock()
        self.config = config
        connectionState = .connecting
        lock.unlock()
    }

    private func setClient(_ newClient: RemoteLightRAGClient) {
        lock.lock()
        client = newClient
        lock.unlock()
    }

    private func clearConnection() {
        lock.lock()
        client = nil
        config = nil
        connectionState = .disconnected
        serverInfo = nil
        lock.unlock()
    }

    private func applyHealthResult(latency: TimeInterval, health: HealthResponse) {
        lock.lock()
        lastHealthCheck = Date()
        lastLatency = latency
        serverInfo = health
        connectionState = .connected(latency: latency)
        lock.unlock()
    }

    private func applyHealthError(_ message: String) {
        lock.lock()
        connectionState = .error(message)
        lock.unlock()
    }

    // MARK: - Retry Logic

    /// Execute a remote operation with exponential backoff retry
    public func withRetry<T>(operation: @escaping () async throws -> T) async throws -> T {
        let maxAttempts = config?.retryMaxAttempts ?? 3
        let baseDelay = config?.retryBaseDelay ?? 1.0

        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch let error as HTTPClientError {
                // Don't retry auth or TLS failures
                if case .unauthorized = error { throw error }
                if case .tlsPinningFailed = error { throw error }

                lastError = error

                if attempt < maxAttempts - 1 {
                    let delay = baseDelay * pow(2.0, Double(attempt))
                    let jitter = Double.random(in: 0...0.5)
                    try await Task.sleep(for: .seconds(delay + jitter))
                }
            } catch {
                lastError = error

                if attempt < maxAttempts - 1 {
                    let delay = baseDelay * pow(2.0, Double(attempt))
                    let jitter = Double.random(in: 0...0.5)
                    try await Task.sleep(for: .seconds(delay + jitter))
                }
            }
        }

        throw lastError ?? HTTPClientError.networkError("All retry attempts exhausted")
    }
}

// MARK: - Enhanced Remote Client

extension RemoteLightRAGClient {
    /// Factory method to create a client with TLS pinning support
    public static func withTLSPinning(
        baseURL: String,
        authToken: String? = nil,
        pinnedCertificateHashes: Set<String>
    ) -> RemoteLightRAGClient {
        RemoteLightRAGClient(
            httpClient: HTTPClient(
                baseURL: baseURL,
                authToken: authToken,
                pinnedCertificateHashes: pinnedCertificateHashes
            )
        )
    }
}
