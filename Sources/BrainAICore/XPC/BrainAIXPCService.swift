import Foundation

// MARK: - XPC Service Implementation

/// Server-side implementation of the XPC protocol
public final class BrainAIXPCService: NSObject, BrainAIXPCProtocol {

    private let orchestrator: ServiceOrchestrator
    private let workspaceManager: WorkspaceManager

    public init(orchestrator: ServiceOrchestrator, workspaceManager: WorkspaceManager) {
        self.orchestrator = orchestrator
        self.workspaceManager = workspaceManager
        super.init()
    }

    // MARK: - Service Status

    public func getOllamaStatus(withReply reply: @escaping (String) -> Void) {
        Task {
            let status = await orchestrator.ollama.status
            reply(String(describing: status))
        }
    }

    public func getLightRAGStatus(withReply reply: @escaping (String) -> Void) {
        Task {
            if let firstInstance = orchestrator.lightRAGInstances.values.first {
                let status = await firstInstance.status
                reply(String(describing: status))
            } else {
                reply("not-available")
            }
        }
    }

    // MARK: - Service Control

    public func startAllServices(withReply reply: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                try await orchestrator.startAll()
                reply(true, nil)
            } catch {
                reply(false, error.localizedDescription)
            }
        }
    }

    public func stopAllServices(withReply reply: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                try await orchestrator.stopAll()
                reply(true, nil)
            } catch {
                reply(false, error.localizedDescription)
            }
        }
    }

    public func startWorkspace(_ workspaceID: String, withReply reply: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                guard let uuid = UUID(uuidString: workspaceID) else {
                    reply(false, "Invalid workspace ID format")
                    return
                }
                try await orchestrator.startWorkspace(uuid)
                reply(true, nil)
            } catch {
                reply(false, error.localizedDescription)
            }
        }
    }

    public func stopWorkspace(_ workspaceID: String, withReply reply: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                guard let uuid = UUID(uuidString: workspaceID) else {
                    reply(false, "Invalid workspace ID format")
                    return
                }
                try await orchestrator.stopWorkspace(uuid)
                reply(true, nil)
            } catch {
                reply(false, error.localizedDescription)
            }
        }
    }

    // MARK: - Knowledge Base

    public func query(_ question: String, mode: String, topK: Int, withReply reply: @escaping (String?, String?) -> Void) {
        Task {
            do {
                let searchMode = SearchMode(rawValue: mode) ?? .hybrid
                let client = LocalLightRAGClient()
                let result = try await client.query(question, mode: searchMode, topK: topK, onlyNeedContext: false)
                reply(result.response, nil)
            } catch {
                reply(nil, error.localizedDescription)
            }
        }
    }

    public func insertText(_ text: String, description: String, withReply reply: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                let client = LocalLightRAGClient()
                _ = try await client.insertText(text, description: description)
                reply(true, nil)
            } catch {
                reply(false, error.localizedDescription)
            }
        }
    }

    // MARK: - Configuration

    public func notifyConfigurationChanged(withReply reply: @escaping () -> Void) {
        DistributedNotificationCenter.default().post(
            name: NSNotification.Name("com.brainai.configChanged"),
            object: nil
        )
        reply()
    }

    public func getServiceInfo(withReply reply: @escaping (String) -> Void) {
        Task {
            let ollamaStatus = await orchestrator.ollama.status
            var lightRAGStatus: ProcessStatus = .stopped
            if let firstInstance = orchestrator.lightRAGInstances.values.first {
                lightRAGStatus = await firstInstance.status
            }
            let workspaceCount = workspaceManager.workspaces.count

            let info: [String: Any] = [
                "ollamaStatus": String(describing: ollamaStatus),
                "lightRAGStatus": String(describing: lightRAGStatus),
                "workspaceCount": workspaceCount
            ]

            if let jsonData = try? JSONSerialization.data(withJSONObject: info),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                reply(jsonString)
            } else {
                reply("{}")
            }
        }
    }
}

// MARK: - XPC Connection Manager

/// Manages XPC connections for both listener (server) and client modes
public final class BrainAIXPCConnectionManager: NSObject, @unchecked Sendable {

    /// Shared Mach service name for the XPC connection
    public static let serviceName = "com.brainai.xpc-service"

    private var listener: NSXPCListener?
    private var connection: NSXPCConnection?
    private let lock = NSLock()

    private let orchestrator: ServiceOrchestrator?
    private let workspaceManager: WorkspaceManager?

    /// Initialize as server (used by the process that owns the services)
    public init(orchestrator: ServiceOrchestrator, workspaceManager: WorkspaceManager) {
        self.orchestrator = orchestrator
        self.workspaceManager = workspaceManager
        super.init()
    }

    /// Initialize as client (used by processes that connect to the service)
    public override init() {
        self.orchestrator = nil
        self.workspaceManager = nil
        super.init()
    }

    // MARK: - Server Mode

    /// Start listening for XPC connections (server mode)
    public func startListener() {
        let listener = NSXPCListener.anonymous()
        listener.delegate = self
        listener.resume()
        lock.lock()
        self.listener = listener
        lock.unlock()
    }

    /// Stop the XPC listener
    public func stopListener() {
        lock.lock()
        listener?.invalidate()
        listener = nil
        lock.unlock()
    }

    // MARK: - Client Mode

    /// Get a proxy to the remote XPC service
    public func remoteProxy() -> BrainAIXPCProtocol? {
        let conn = getOrCreateConnection()
        return conn.remoteObjectProxyWithErrorHandler { error in
            // Handle error silently - connection will be retried
        } as? BrainAIXPCProtocol
    }

    private func getOrCreateConnection() -> NSXPCConnection {
        lock.lock()
        defer { lock.unlock() }

        if let existing = connection {
            return existing
        }

        let conn = NSXPCConnection(serviceName: Self.serviceName)
        conn.remoteObjectInterface = NSXPCInterface(with: BrainAIXPCProtocol.self)
        conn.resume()
        self.connection = conn
        return conn
    }

    /// Disconnect from the XPC service
    public func disconnect() {
        lock.lock()
        connection?.invalidate()
        connection = nil
        lock.unlock()
    }
}

// MARK: - NSXPCListenerDelegate

extension BrainAIXPCConnectionManager: NSXPCListenerDelegate {
    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: BrainAIXPCProtocol.self)

        guard let orchestrator = orchestrator, let workspaceManager = workspaceManager else {
            return false
        }

        let service = BrainAIXPCService(orchestrator: orchestrator, workspaceManager: workspaceManager)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}
