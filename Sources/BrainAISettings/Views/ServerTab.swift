import SwiftUI
import BrainAICore

// MARK: - ServerTab

struct ServerTab: View {
    @State private var config = AppConfiguration.shared
    @State private var ollamaStatus: ProcessStatus = .stopped
    @State private var lightRAGStatus: ProcessStatus = .stopped
    @State private var connectionMode: ConnectionMode = .local

    // Process managers
    @State private var ollamaManager: OllamaProcessManager?
    @State private var lightRAGManager: LightRAGProcessManager?

    // Remote connection
    @State private var remoteManager = RemoteConnectionManager()
    @State private var remoteURL = ""
    @State private var remoteAuthToken = ""
    @State private var tlsPinnedHashes = ""
    @State private var testingConnection = false
    @State private var connectionTestResult: String?

    // MCP connections
    @State private var mcpManager = MCPClientManager()

    var body: some View {
        Form {
            // MARK: - Ollama Service
            Section {
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("", value: $config.ollamaPort, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    ProcessStatusBadge(status: ollamaStatus)
                }

                HStack {
                    Spacer()
                    Button("Start") {
                        Task { await startOllama() }
                    }
                    .disabled(ollamaStatus == .running || ollamaStatus == .starting)

                    Button("Stop") {
                        Task { await stopOllama() }
                    }
                    .disabled(ollamaStatus == .stopped)

                    Button("Restart") {
                        Task { await restartOllama() }
                    }
                    .disabled(ollamaStatus == .stopped)
                }
            } header: {
                Label("Ollama", systemImage: "cpu")
            }

            // MARK: - LightRAG Service
            Section {
                HStack {
                    Text("Host")
                    Spacer()
                    Text("localhost")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Default Port")
                    Spacer()
                    Text("9621")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    ProcessStatusBadge(status: lightRAGStatus)
                }

                HStack {
                    Spacer()
                    Button("Start") {
                        Task { await startLightRAG() }
                    }
                    .disabled(lightRAGStatus == .running || lightRAGStatus == .starting)

                    Button("Stop") {
                        Task { await stopLightRAG() }
                    }
                    .disabled(lightRAGStatus == .stopped)

                    Button("Restart") {
                        Task { await restartLightRAG() }
                    }
                    .disabled(lightRAGStatus == .stopped)
                }
            } header: {
                Label("LightRAG", systemImage: "externaldrive.connected.to.line.below")
            }

            // MARK: - Connection Mode
            Section {
                Picker("Mode", selection: $connectionMode) {
                    Text("Local").tag(ConnectionMode.local)
                    Text("Remote").tag(ConnectionMode.remote)
                }

                if connectionMode == .remote {
                    HStack {
                        Text("Remote URL")
                        Spacer()
                        TextField("https://lightrag.example.com", text: $remoteURL)
                            .frame(width: 260)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Auth Token")
                        Spacer()
                        SecureField("Bearer token", text: $remoteAuthToken)
                            .frame(width: 260)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("TLS Pin Hashes")
                        Spacer()
                        TextField("SHA-256 (comma-separated)", text: $tlsPinnedHashes)
                            .frame(width: 260)
                            .multilineTextAlignment(.trailing)
                    }

                    // Connection status
                    HStack {
                        Text("Status")
                        Spacer()
                        RemoteConnectionStatusView(state: remoteManager.connectionState, latency: remoteManager.lastLatency)
                    }

                    // Health info
                    if let info = remoteManager.serverInfo {
                        HStack {
                            Text("Server")
                            Spacer()
                            Text(info.status)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Spacer()

                        if remoteManager.connectionState.isConnected {
                            Button("Disconnect") {
                                remoteManager.disconnect()
                            }
                        } else {
                            Button("Connect") {
                                Task { await connectRemote() }
                            }
                            .disabled(remoteURL.isEmpty || testingConnection)
                        }

                        Button("Test") {
                            Task { await testRemoteConnection() }
                        }
                        .disabled(remoteURL.isEmpty || testingConnection)
                    }

                    if let result = connectionTestResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.hasPrefix("Success") ? Color.green : Color.red)
                    }
                }
            } header: {
                Label("Connection", systemImage: "network")
            }

            // MARK: - MCP Connections
            Section {
                if mcpManager.connections.isEmpty {
                    Text("No MCP servers connected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mcpManager.connections) { conn in
                        HStack {
                            Circle()
                                .fill(mcpStatusColor(conn.status))
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conn.serverName)
                                    .font(.callout)
                                Text("\(conn.toolCount) tools")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if case .connected = conn.status {
                                Button("Disconnect") {
                                    Task { await mcpManager.disconnect(id: conn.id) }
                                }
                                .controlSize(.small)
                            }
                        }
                    }
                }
            } header: {
                Label("MCP Servers", systemImage: "point.3.connected.trianglepath.dotted")
            } footer: {
                Text("Connect to external MCP servers to extend BrainAI with additional tools and data sources.")
            }

            // MARK: - Keep Alive
            Section {
                Picker("Ollama Keep Alive", selection: $config.ollamaKeepAlive) {
                    Text("30 seconds").tag(KeepAliveDuration.seconds(30))
                    Text("1 minute").tag(KeepAliveDuration.minutes(1))
                    Text("5 minutes").tag(KeepAliveDuration.minutes(5))
                    Text("15 minutes").tag(KeepAliveDuration.minutes(15))
                    Text("30 minutes").tag(KeepAliveDuration.minutes(30))
                    Text("Forever (-1)").tag(KeepAliveDuration.forever)
                }

                HStack {
                    Text("Workspace Idle Timeout")
                    Spacer()
                    TextField("", value: $config.workspaceIdleTimeout, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("sec")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Resource Management", systemImage: "memorychip")
            } footer: {
                Text("Keep Alive controls how long Ollama keeps models loaded in RAM after the last request. Workspace Idle Timeout controls when unused workspaces are unloaded.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Server")
        .onAppear { refreshStatuses() }
    }

    // MARK: - Remote Connection

    private func connectRemote() async {
        let hashes = tlsPinnedHashes
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let remoteConfig = RemoteConnectionConfig(
            baseURL: remoteURL,
            authToken: remoteAuthToken.isEmpty ? nil : remoteAuthToken,
            tlsPinnedHashes: hashes
        )

        await remoteManager.connect(config: remoteConfig)
    }

    private func testRemoteConnection() async {
        testingConnection = true
        connectionTestResult = nil

        let client = RemoteLightRAGClient(baseURL: remoteURL, authToken: remoteAuthToken.isEmpty ? nil : remoteAuthToken)
        let startTime = Date()

        do {
            let health = try await client.healthCheck()
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            connectionTestResult = "Success: \(health.status) (\(latency)ms)"
        } catch {
            connectionTestResult = "Failed: \(error.localizedDescription)"
        }

        testingConnection = false
    }

    private func mcpStatusColor(_ status: MCPConnectionStatus) -> Color {
        switch status {
        case .connected: return .green
        case .disconnected: return .gray
        case .error: return .red
        }
    }

    // MARK: - Actions

    private func refreshStatuses() {
        Task {
            let manager = OllamaProcessManager(port: UInt16(config.ollamaPort))
            let isHealthy = try? await manager.healthCheck()
            ollamaStatus = (isHealthy == true) ? .running : .stopped

            let lightragClient = LocalLightRAGClient()
            let health = try? await lightragClient.healthCheck()
            lightRAGStatus = (health != nil) ? .running : .stopped
        }
    }

    private func startOllama() async {
        let manager = OllamaProcessManager(port: UInt16(config.ollamaPort))
        ollamaManager = manager
        ollamaStatus = .starting
        do {
            try await manager.start()
            ollamaStatus = .running
        } catch {
            ollamaStatus = .error(error.localizedDescription)
        }
    }

    private func stopOllama() async {
        guard let manager = ollamaManager else { return }
        do {
            try await manager.stop()
            ollamaStatus = .stopped
        } catch {
            ollamaStatus = .error(error.localizedDescription)
        }
    }

    private func restartOllama() async {
        guard let manager = ollamaManager else { return }
        ollamaStatus = .starting
        do {
            try await manager.restart()
            ollamaStatus = .running
        } catch {
            ollamaStatus = .error(error.localizedDescription)
        }
    }

    private func startLightRAG() async {
        let workDir = config.workspacesDirectory
        let manager = LightRAGProcessManager(workingDirectory: workDir)
        lightRAGManager = manager
        lightRAGStatus = .starting
        do {
            try await manager.start()
            lightRAGStatus = .running
        } catch {
            lightRAGStatus = .error(error.localizedDescription)
        }
    }

    private func stopLightRAG() async {
        guard let manager = lightRAGManager else { return }
        do {
            try await manager.stop()
            lightRAGStatus = .stopped
        } catch {
            lightRAGStatus = .error(error.localizedDescription)
        }
    }

    private func restartLightRAG() async {
        guard let manager = lightRAGManager else { return }
        lightRAGStatus = .starting
        do {
            try await manager.restart()
            lightRAGStatus = .running
        } catch {
            lightRAGStatus = .error(error.localizedDescription)
        }
    }
}

// MARK: - Remote Connection Status View

struct RemoteConnectionStatusView: View {
    let state: RemoteConnectionState
    let latency: TimeInterval

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(state.displayString)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch state {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .gray
        case .error: return .red
        }
    }
}

// MARK: - Process Status Badge

struct ProcessStatusBadge: View {
    let status: ProcessStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch status {
        case .running: return .green
        case .starting: return .yellow
        case .stopped: return .gray
        case .error: return .red
        }
    }

    private var statusText: String {
        switch status {
        case .running: return "Running"
        case .starting: return "Starting..."
        case .stopped: return "Stopped"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
