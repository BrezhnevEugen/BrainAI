import Foundation
import Observation

// MARK: - MCP Client

/// MCP Client — connects BrainAI to a remote MCP server and invokes tools
public actor MCPClient {

    private let transport: MCPTransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var nextRequestId: Int = 1
    private var serverCapabilities: MCPServerInfo?
    private var availableTools: [MCPToolDefinition] = []
    private var isInitialized = false

    // MARK: - Initialization

    public init(transport: MCPTransport) {
        self.transport = transport
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Connection Lifecycle

    /// Initialize the MCP session with the remote server
    public func initialize() async throws -> MCPServerInfo {
        let request = MCPRequest(
            id: generateId(),
            method: "initialize",
            params: MCPParams(
                name: nil,
                arguments: [
                    "protocolVersion": .string("2024-11-05"),
                    "capabilities": .object([:]),
                    "clientInfo": .object([
                        "name": .string("BrainAI"),
                        "version": .string(BrainAIMetadata.marketingVersion)
                    ])
                ]
            )
        )

        let response = try await sendRequest(request)

        guard let resultText = response.result?.content?.first?.text else {
            throw MCPClientError.initializationFailed("No result in initialize response")
        }

        let serverInfo = try decoder.decode(MCPServerInfo.self, from: Data(resultText.utf8))
        self.serverCapabilities = serverInfo
        self.isInitialized = true

        // Send initialized notification (no id = notification)
        let notification = MCPRequest(id: nil, method: "notifications/initialized")
        let notifData = try encoder.encode(notification)
        try await transport.send(notifData)

        return serverInfo
    }

    /// Discover available tools from the remote server
    @discardableResult
    public func listTools() async throws -> [MCPToolDefinition] {
        try ensureInitialized()

        let request = MCPRequest(
            id: generateId(),
            method: "tools/list"
        )

        let response = try await sendRequest(request)

        if let tools = response.result?.tools {
            self.availableTools = tools
            return tools
        }

        return []
    }

    /// Call a tool on the remote MCP server
    public func callTool(name: String, arguments: [String: AnyCodable] = [:]) async throws -> MCPToolCallResult {
        try ensureInitialized()

        let request = MCPRequest(
            id: generateId(),
            method: "tools/call",
            params: MCPParams(name: name, arguments: arguments)
        )

        let response = try await sendRequest(request)

        if let error = response.error {
            throw MCPClientError.toolCallFailed(name, error.message)
        }

        let contents = response.result?.content ?? []
        let texts = contents.compactMap(\.text)

        return MCPToolCallResult(
            toolName: name,
            content: texts,
            isError: false
        )
    }

    /// Close the client connection
    public func close() async {
        await transport.close()
        isInitialized = false
        availableTools = []
        serverCapabilities = nil
    }

    /// Get cached list of available tools
    public var tools: [MCPToolDefinition] {
        availableTools
    }

    /// Whether the client has been initialized with the server
    public var initialized: Bool {
        isInitialized
    }

    // MARK: - Private Helpers

    private func generateId() -> Int {
        let id = nextRequestId
        nextRequestId += 1
        return id
    }

    private func ensureInitialized() throws {
        guard isInitialized else {
            throw MCPClientError.notInitialized
        }
    }

    private func sendRequest(_ request: MCPRequest) async throws -> MCPResponse {
        let requestData = try encoder.encode(request)
        try await transport.send(requestData)
        let responseData = try await transport.receive()
        return try decoder.decode(MCPResponse.self, from: responseData)
    }
}

// MARK: - MCP Client Types

/// Information about the remote MCP server
public struct MCPServerInfo: Codable, Sendable {
    public let protocolVersion: String
    public let serverInfo: MCPServerIdentity?
    public let capabilities: MCPCapabilities?

    public init(protocolVersion: String, serverInfo: MCPServerIdentity? = nil, capabilities: MCPCapabilities? = nil) {
        self.protocolVersion = protocolVersion
        self.serverInfo = serverInfo
        self.capabilities = capabilities
    }
}

/// Server identity (name + version)
public struct MCPServerIdentity: Codable, Sendable {
    public let name: String
    public let version: String?

    public init(name: String, version: String? = nil) {
        self.name = name
        self.version = version
    }
}

/// Server capabilities
public struct MCPCapabilities: Codable, Sendable {
    public let tools: [String: AnyCodable]?
    public let resources: [String: AnyCodable]?
    public let prompts: [String: AnyCodable]?

    public init(tools: [String: AnyCodable]? = nil, resources: [String: AnyCodable]? = nil, prompts: [String: AnyCodable]? = nil) {
        self.tools = tools
        self.resources = resources
        self.prompts = prompts
    }
}

/// Result of a tool call
public struct MCPToolCallResult: Sendable {
    public let toolName: String
    public let content: [String]
    public let isError: Bool

    /// Combined text content
    public var text: String {
        content.joined(separator: "\n")
    }
}

// MARK: - MCP Client Error

public enum MCPClientError: LocalizedError {
    case notInitialized
    case initializationFailed(String)
    case toolCallFailed(String, String)
    case transportError(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            "MCP client not initialized. Call initialize() first."
        case .initializationFailed(let msg):
            "MCP initialization failed: \(msg)"
        case .toolCallFailed(let tool, let msg):
            "Tool '\(tool)' call failed: \(msg)"
        case .transportError(let msg):
            "Transport error: \(msg)"
        case .timeout:
            "MCP request timed out"
        }
    }
}

// MARK: - Stdio Transport

/// MCP transport over stdin/stdout (for spawning MCP server processes)
public actor StdioTransport: MCPTransport {

    private let process: Process
    private let stdinPipe: Pipe
    private let stdoutPipe: Pipe
    private var buffer = Data()

    /// Launch an MCP server process and connect via stdio
    public init(executablePath: String, arguments: [String] = [], environment: [String: String]? = nil) throws {
        self.process = Process()
        self.stdinPipe = Pipe()
        self.stdoutPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        if let env = environment {
            var processEnv = ProcessInfo.processInfo.environment
            for (key, value) in env {
                processEnv[key] = value
            }
            process.environment = processEnv
        }

        try process.run()
    }

    public func send(_ data: Data) async throws {
        // JSON-RPC messages are newline-delimited
        var message = data
        if !message.isEmpty && message.last != UInt8(ascii: "\n") {
            message.append(UInt8(ascii: "\n"))
        }
        stdinPipe.fileHandleForWriting.write(message)
    }

    public func receive() async throws -> Data {
        // Read until we get a complete JSON-RPC message (newline-delimited)
        let handle = stdoutPipe.fileHandleForReading

        while true {
            // Check buffer for complete message
            if let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let messageData = buffer[buffer.startIndex..<newlineIndex]
                buffer = Data(buffer[(newlineIndex + 1)...])
                return Data(messageData)
            }

            // Read more data
            let chunk = handle.availableData
            if chunk.isEmpty {
                // EOF — process terminated
                throw MCPClientError.transportError("MCP server process terminated unexpectedly")
            }
            buffer.append(chunk)
        }
    }

    public func close() async {
        stdinPipe.fileHandleForWriting.closeFile()
        process.terminate()
        process.waitUntilExit()
    }
}

// MARK: - WebSocket Transport

/// MCP transport over WebSocket
public final class WebSocketTransport: MCPTransport, @unchecked Sendable {

    private let url: URL
    private let authToken: String?
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private let lock = NSLock()

    public init(url: URL, authToken: String? = nil) {
        self.url = url
        self.authToken = authToken
        self.session = URLSession(configuration: .default)
    }

    /// Connect the WebSocket
    public func connect() {
        var request = URLRequest(url: url)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        lock.lock()
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        lock.unlock()
    }

    public func send(_ data: Data) async throws {
        guard let task = getTask() else {
            throw MCPClientError.transportError("WebSocket not connected")
        }

        let message = URLSessionWebSocketTask.Message.data(data)
        try await task.send(message)
    }

    public func receive() async throws -> Data {
        guard let task = getTask() else {
            throw MCPClientError.transportError("WebSocket not connected")
        }

        let message = try await task.receive()
        switch message {
        case .data(let data):
            return data
        case .string(let text):
            return Data(text.utf8)
        @unknown default:
            throw MCPClientError.transportError("Unknown WebSocket message type")
        }
    }

    public func close() async {
        cancelAndClear()
    }

    // MARK: - Sync Helpers (avoid NSLock in async context)

    private func getTask() -> URLSessionWebSocketTask? {
        lock.lock()
        defer { lock.unlock() }
        return webSocketTask
    }

    private func cancelAndClear() {
        lock.lock()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        lock.unlock()
    }
}

// MARK: - MCP Client Manager

/// Manages multiple MCP client connections
@Observable
public final class MCPClientManager: @unchecked Sendable {

    public var connections: [MCPConnectionInfo] = []

    private var clients: [String: MCPClient] = [:]
    private let lock = NSLock()

    public init() {}

    /// Connect to an MCP server via stdio (spawning a process)
    public func connectStdio(
        id: String,
        name: String,
        executablePath: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) async throws {
        let transport = try StdioTransport(
            executablePath: executablePath,
            arguments: arguments,
            environment: environment
        )

        let client = MCPClient(transport: transport)
        let serverInfo = try await client.initialize()
        let tools = try await client.listTools()

        addConnection(id: id, client: client, info: MCPConnectionInfo(
            id: id,
            name: name,
            serverName: serverInfo.serverInfo?.name ?? name,
            serverVersion: serverInfo.serverInfo?.version,
            toolCount: tools.count,
            status: .connected
        ))
    }

    /// Connect to an MCP server via WebSocket
    public func connectWebSocket(
        id: String,
        name: String,
        url: URL,
        authToken: String? = nil
    ) async throws {
        let transport = WebSocketTransport(url: url, authToken: authToken)
        transport.connect()

        let client = MCPClient(transport: transport)
        let serverInfo = try await client.initialize()
        let tools = try await client.listTools()

        addConnection(id: id, client: client, info: MCPConnectionInfo(
            id: id,
            name: name,
            serverName: serverInfo.serverInfo?.name ?? name,
            serverVersion: serverInfo.serverInfo?.version,
            toolCount: tools.count,
            status: .connected
        ))
    }

    /// Disconnect from an MCP server
    public func disconnect(id: String) async {
        let client = removeConnection(id: id)
        await client?.close()
    }

    /// Call a tool on a specific MCP server
    public func callTool(
        connectionId: String,
        toolName: String,
        arguments: [String: AnyCodable] = [:]
    ) async throws -> MCPToolCallResult {
        guard let client = getClient(connectionId) else {
            throw MCPClientError.transportError("No connection with id '\(connectionId)'")
        }

        return try await client.callTool(name: toolName, arguments: arguments)
    }

    /// Get all tools across all connected servers
    public func allTools() async -> [(connectionId: String, tool: MCPToolDefinition)] {
        let clientsCopy = snapshotClients()

        var result: [(connectionId: String, tool: MCPToolDefinition)] = []
        for (id, client) in clientsCopy {
            let tools = await client.tools
            for tool in tools {
                result.append((connectionId: id, tool: tool))
            }
        }
        return result
    }

    /// Disconnect all servers
    public func disconnectAll() async {
        let clientsCopy = removeAllClients()

        for (_, client) in clientsCopy {
            await client.close()
        }
    }

    // MARK: - Sync Helpers (avoid NSLock in async context)

    private func addConnection(id: String, client: MCPClient, info: MCPConnectionInfo) {
        lock.lock()
        clients[id] = client
        connections.append(info)
        lock.unlock()
    }

    private func removeConnection(id: String) -> MCPClient? {
        lock.lock()
        let client = clients.removeValue(forKey: id)
        if let index = connections.firstIndex(where: { $0.id == id }) {
            connections[index].status = .disconnected
        }
        lock.unlock()
        return client
    }

    private func getClient(_ id: String) -> MCPClient? {
        lock.lock()
        defer { lock.unlock() }
        return clients[id]
    }

    private func snapshotClients() -> [String: MCPClient] {
        lock.lock()
        defer { lock.unlock() }
        return clients
    }

    private func removeAllClients() -> [String: MCPClient] {
        lock.lock()
        let copy = clients
        clients.removeAll()
        for index in connections.indices {
            connections[index].status = .disconnected
        }
        lock.unlock()
        return copy
    }
}

// MARK: - MCP Connection Info

/// Status and metadata of an MCP connection
public struct MCPConnectionInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let serverName: String
    public let serverVersion: String?
    public let toolCount: Int
    public var status: MCPConnectionStatus

    public init(
        id: String,
        name: String,
        serverName: String,
        serverVersion: String? = nil,
        toolCount: Int,
        status: MCPConnectionStatus
    ) {
        self.id = id
        self.name = name
        self.serverName = serverName
        self.serverVersion = serverVersion
        self.toolCount = toolCount
        self.status = status
    }
}

/// Connection status
public enum MCPConnectionStatus: Sendable {
    case connected
    case disconnected
    case error(String)
}
