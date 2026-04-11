import SwiftUI
import BrainAICore

// MARK: - ProvidersTab

struct ProvidersTab: View {
    @State private var config = AppConfiguration.shared
    @State private var selectedSection: ProviderSection = .roles

    var body: some View {
        VStack(spacing: 0) {
            // Section picker
            Picker("", selection: $selectedSection) {
                Text("Roles").tag(ProviderSection.roles)
                Text("Providers").tag(ProviderSection.providers)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Content
            switch selectedSection {
            case .roles:
                RolesConfigView(config: config)
            case .providers:
                ProvidersConfigView(config: config)
            }
        }
        .navigationTitle("Providers & Roles")
    }
}

enum ProviderSection: String, CaseIterable {
    case roles
    case providers
}

// MARK: - Roles Configuration

struct RolesConfigView: View {
    @Bindable var config: AppConfiguration

    var body: some View {
        Form {
            // Embedding Role
            Section {
                RoleRow(
                    roleName: "Embedding",
                    icon: "arrow.triangle.2.circlepath",
                    providerID: config.embeddingRole.providerID,
                    modelID: config.embeddingRole.modelID,
                    endpoint: config.embeddingRole.endpoint
                )
            } header: {
                Text("Embedding Model")
            } footer: {
                Text("Converts text to vector representations. Changing this model requires full re-indexing of existing data.")
                    .foregroundStyle(.orange)
            }

            // Extraction LLM Role
            Section {
                RoleRow(
                    roleName: "Extraction",
                    icon: "doc.text.magnifyingglass",
                    providerID: config.extractionRole.providerID,
                    modelID: config.extractionRole.modelID,
                    endpoint: config.extractionRole.endpoint
                )
            } header: {
                Text("Extraction LLM")
            } footer: {
                Text("Extracts entities and relations from documents. Recommended: 32B+ parameters for quality.")
            }

            // Reranker Role (Optional)
            Section {
                if let reranker = config.rerankerRole {
                    RoleRow(
                        roleName: "Reranker",
                        icon: "arrow.up.arrow.down",
                        providerID: reranker.providerID,
                        modelID: reranker.modelID,
                        endpoint: reranker.endpoint
                    )

                    Button("Disable Reranker", role: .destructive) {
                        config.rerankerRole = nil
                    }
                } else {
                    HStack {
                        Label("Reranker is disabled", systemImage: "minus.circle")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Enable") {
                            config.rerankerRole = RoleConfig(
                                providerID: "jina",
                                modelID: "jina-reranker-v2",
                                endpoint: .cloudAPI(baseURL: "https://api.jina.ai/v1")
                            )
                        }
                    }
                }
            } header: {
                Text("Reranker (Optional)")
            } footer: {
                Text("Re-ranks search results for better relevance. Requires Jina AI or Cohere API key.")
            }

            // Generation LLM Role
            Section {
                RoleRow(
                    roleName: "Generation",
                    icon: "text.bubble",
                    providerID: config.generationRole.providerID,
                    modelID: config.generationRole.modelID,
                    endpoint: config.generationRole.endpoint
                )
            } header: {
                Text("Generation LLM")
            } footer: {
                Text("Generates answers from knowledge graph context. Can be lighter than extraction (14B is often enough).")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Providers Configuration

struct ProvidersConfigView: View {
    @Bindable var config: AppConfiguration
    @State private var ollamaStatus: ConnectionStatus = .unknown
    @State private var testingProvider: ProviderType?

    var body: some View {
        Form {
            // Ollama Local
            Section {
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("", value: $config.ollamaPort, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }

                Picker("Keep Alive", selection: $config.ollamaKeepAlive) {
                    Text("30 seconds").tag(KeepAliveDuration.seconds(30))
                    Text("1 minute").tag(KeepAliveDuration.minutes(1))
                    Text("5 minutes").tag(KeepAliveDuration.minutes(5))
                    Text("15 minutes").tag(KeepAliveDuration.minutes(15))
                    Text("30 minutes").tag(KeepAliveDuration.minutes(30))
                    Text("Forever").tag(KeepAliveDuration.forever)
                }

                StatusRow(label: "Status", status: ollamaStatus)

                Button("Test Connection") {
                    testOllamaConnection()
                }
            } header: {
                Label("Ollama Local", systemImage: "desktopcomputer")
            }

            // Ollama Remote
            Section {
                HStack {
                    Text("URL")
                    Spacer()
                    TextField("http://192.168.1.100:11434", text: remoteOllamaURLBinding)
                        .frame(width: 280)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Label("Ollama Remote", systemImage: "network")
            }

            // Cloud Providers
            Section {
                APIKeyRow(
                    provider: .openai,
                    label: "OpenAI",
                    icon: "cloud",
                    baseURLBinding: openAIBaseURLBinding
                )
            } header: {
                Label("OpenAI", systemImage: "cloud")
            }

            Section {
                APIKeyRow(
                    provider: .anthropic,
                    label: "Anthropic",
                    icon: "cloud",
                    baseURLBinding: anthropicBaseURLBinding
                )
            } header: {
                Label("Anthropic", systemImage: "cloud")
            }

            Section {
                APIKeyRow(
                    provider: .deepseek,
                    label: "DeepSeek",
                    icon: "cloud",
                    baseURLBinding: deepSeekBaseURLBinding
                )
            } header: {
                Label("DeepSeek", systemImage: "cloud")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            testOllamaConnection()
        }
    }

    // MARK: - Bindings

    private var remoteOllamaURLBinding: Binding<String> {
        Binding(
            get: { config.remoteOllamaURL?.absoluteString ?? "" },
            set: { config.remoteOllamaURL = $0.isEmpty ? nil : URL(string: $0) }
        )
    }

    private var openAIBaseURLBinding: Binding<String> {
        Binding(
            get: { config.openAIBaseURL?.absoluteString ?? "https://api.openai.com/v1" },
            set: { config.openAIBaseURL = URL(string: $0) }
        )
    }

    private var anthropicBaseURLBinding: Binding<String> {
        Binding(
            get: { config.anthropicBaseURL?.absoluteString ?? "https://api.anthropic.com" },
            set: { config.anthropicBaseURL = URL(string: $0) }
        )
    }

    private var deepSeekBaseURLBinding: Binding<String> {
        Binding(
            get: { config.deepSeekBaseURL?.absoluteString ?? "https://api.deepseek.com/v1" },
            set: { config.deepSeekBaseURL = URL(string: $0) }
        )
    }

    // MARK: - Actions

    private func testOllamaConnection() {
        ollamaStatus = .checking
        Task {
            let api = OllamaAPIClient(baseURL: "http://localhost:\(config.ollamaPort)")
            do {
                let result = try await api.healthCheck()
                ollamaStatus = result ? .connected : .disconnected
            } catch {
                ollamaStatus = .disconnected
            }
        }
    }
}

// MARK: - Supporting Views

struct RoleRow: View {
    let roleName: String
    let icon: String
    let providerID: String
    let modelID: String
    let endpoint: ProviderEndpoint

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(roleName, systemImage: icon)
                    .font(.headline)
                Spacer()
                endpointBadge
            }

            HStack(spacing: 16) {
                LabeledContent("Provider") {
                    Text(providerID)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Model") {
                    Text(modelID)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                }
            }
            .font(.callout)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var endpointBadge: some View {
        switch endpoint {
        case .local:
            Text("Local")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        case .remoteOllama:
            Text("Remote")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        case .cloudAPI:
            Text("Cloud")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.purple.opacity(0.15))
                .foregroundStyle(.purple)
                .clipShape(Capsule())
        }
    }
}

struct APIKeyRow: View {
    let provider: ProviderType
    let label: String
    let icon: String
    @Binding var baseURLBinding: String
    @State private var apiKey: String = ""
    @State private var hasKey: Bool = false
    @State private var showKey: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("API Key")
                Spacer()
                if hasKey {
                    if showKey {
                        TextField("", text: $apiKey)
                            .frame(width: 240)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(String(repeating: "*", count: 12))
                            .foregroundStyle(.secondary)
                    }
                    Button(showKey ? "Hide" : "Show") {
                        showKey.toggle()
                    }
                    .buttonStyle(.borderless)
                } else {
                    TextField("sk-...", text: $apiKey)
                        .frame(width: 240)
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack {
                Text("Base URL")
                Spacer()
                TextField("https://...", text: $baseURLBinding)
                    .frame(width: 240)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Spacer()
                if !apiKey.isEmpty && !hasKey {
                    Button("Save Key") {
                        saveAPIKey()
                    }
                }
                if hasKey {
                    Button("Delete Key", role: .destructive) {
                        deleteAPIKey()
                    }
                }
            }
        }
        .onAppear { loadAPIKey() }
    }

    private func loadAPIKey() {
        if let key = try? KeychainManager.shared.loadAPIKey(for: provider) {
            apiKey = key
            hasKey = true
        }
    }

    private func saveAPIKey() {
        try? KeychainManager.shared.saveAPIKey(apiKey, for: provider)
        hasKey = true
    }

    private func deleteAPIKey() {
        try? KeychainManager.shared.deleteAPIKey(for: provider)
        apiKey = ""
        hasKey = false
        showKey = false
    }
}

struct StatusRow: View {
    let label: String
    let status: ConnectionStatus

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                Text(status.text)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

enum ConnectionStatus {
    case unknown
    case checking
    case connected
    case disconnected

    var text: String {
        switch self {
        case .unknown: return "Unknown"
        case .checking: return "Checking..."
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        }
    }

    var color: Color {
        switch self {
        case .unknown: return .gray
        case .checking: return .yellow
        case .connected: return .green
        case .disconnected: return .red
        }
    }
}
