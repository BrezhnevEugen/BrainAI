import Foundation
import Network
import Observation

// MARK: - WebSocket Server Transport

/// Server-side MCP transport over a single accepted WebSocket connection.
///
/// Each peer that connects to ``MCPWebSocketServer`` gets its own transport and
/// its own ``MCPServer`` serving loop. JSON-RPC messages are exchanged as text
/// frames.
public final class WebSocketServerTransport: MCPTransport, @unchecked Sendable {

    private let connection: NWConnection

    init(connection: NWConnection) {
        self.connection = connection
    }

    public func send(_ data: Data) async throws {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "mcp-send", metadata: [metadata])

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: data,
                contentContext: context,
                isComplete: true,
                completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(throwing: MCPServerTransportError.writeFailed(error.localizedDescription))
                    } else {
                        continuation.resume()
                    }
                }
            )
        }
    }

    public func receive() async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receiveMessage { data, _, _, error in
                if let error {
                    continuation.resume(throwing: MCPServerTransportError.writeFailed(error.localizedDescription))
                    return
                }
                guard let data, !data.isEmpty else {
                    // Empty message with no error → peer closed the connection.
                    continuation.resume(throwing: MCPServerTransportError.closed)
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    public func close() async {
        connection.cancel()
    }
}

// MARK: - MCP WebSocket Server (in-app host)

/// Hosts the BrainAI MCP server over WebSocket inside the app, so in-app and
/// LAN MCP clients can reach the knowledge base and workspace memory without a
/// spawned stdio process. Each accepted connection runs its own ``MCPServer``.
@Observable
public final class MCPWebSocketServer: @unchecked Sendable {

    /// Shared app-wide instance backing the in-app server controls.
    public static let shared = MCPWebSocketServer()

    public private(set) var isRunning = false
    public private(set) var port: UInt16
    public private(set) var activeConnections = 0
    public private(set) var lastError: String?

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private let queue = DispatchQueue(label: "com.brainai.mcp.ws-server")
    @ObservationIgnored private let makeClient: @Sendable () -> any LightRAGClientProtocol
    @ObservationIgnored private let workspaceManager: WorkspaceManager

    /// - Parameters:
    ///   - port: TCP port to listen on (default 8765).
    ///   - workspaceManager: Workspace source for memory tools.
    ///   - makeClient: Factory for a fresh LightRAG client per connection.
    public init(
        port: UInt16 = 8765,
        workspaceManager: WorkspaceManager = .shared,
        makeClient: @escaping @Sendable () -> any LightRAGClientProtocol = { LocalLightRAGClient() }
    ) {
        self.port = port
        self.workspaceManager = workspaceManager
        self.makeClient = makeClient
    }

    /// Start listening. Re-starting a running server is a no-op.
    /// - Parameter portOverride: optional port applied before binding.
    public func start(port portOverride: UInt16? = nil) throws {
        guard !isRunning else { return }
        if let portOverride { self.port = portOverride }

        let parameters = NWParameters.tcp
        let webSocketOptions = NWProtocolWebSocket.Options()
        webSocketOptions.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw MCPServerTransportError.writeFailed("Invalid port \(port)")
        }

        let listener = try NWListener(using: parameters, on: nwPort)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error), .waiting(let error):
                self?.updateState { $0.lastError = error.localizedDescription }
            default:
                break
            }
        }

        self.listener = listener
        listener.start(queue: queue)
        updateState {
            $0.isRunning = true
            $0.lastError = nil
        }
    }

    /// Stop listening and drop the listener. Active connections finish naturally.
    public func stop() {
        listener?.cancel()
        listener = nil
        updateState {
            $0.isRunning = false
            $0.activeConnections = 0
        }
    }

    // MARK: - Private

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        updateState { $0.activeConnections += 1 }

        let transport = WebSocketServerTransport(connection: connection)
        let server = MCPServer(lightRAGClient: makeClient(), workspaceManager: workspaceManager)

        Task { [weak self] in
            try? await server.start(transport: transport)
            await server.stop()
            self?.updateState { $0.activeConnections = max(0, $0.activeConnections - 1) }
        }
    }

    /// Apply observable-state mutations on the main actor so SwiftUI updates safely.
    private func updateState(_ mutate: @escaping @Sendable (MCPWebSocketServer) -> Void) {
        if Thread.isMainThread {
            mutate(self)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                mutate(self)
            }
        }
    }
}
