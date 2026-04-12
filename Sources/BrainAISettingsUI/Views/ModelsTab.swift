import SwiftUI
import BrainAICore

// MARK: - ModelsTab

struct ModelsTab: View {
    @State private var models: [OllamaModelInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pullModelName: String = ""
    @State private var isPulling = false
    @State private var pullProgress: String = ""
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: OllamaModelInfo?
    @State private var config = AppConfiguration.shared

    private var ollamaAPI: OllamaAPIClient {
        OllamaAPIClient(baseURL: "http://localhost:\(config.ollamaPort)")
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Toolbar
            HStack {
                Text("\(models.count) models installed")
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    Task { await loadModels() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
            .padding()

            Divider()

            // MARK: - Model List
            if isLoading && models.isEmpty {
                ProgressView("Loading models...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, models.isEmpty {
                ContentUnavailableView {
                    Label("Cannot Connect", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadModels() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(models, id: \.name) { model in
                        ModelRow(model: model) {
                            modelToDelete = model
                            showDeleteConfirmation = true
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // MARK: - Pull Model
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.secondary)

                TextField("Model name (e.g. llama3.2, nomic-embed-text)", text: $pullModelName)
                    .textFieldStyle(.roundedBorder)

                if isPulling {
                    ProgressView()
                        .controlSize(.small)
                    Text(pullProgress)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .frame(width: 100)
                } else {
                    Button("Pull") {
                        Task { await pullModel() }
                    }
                    .disabled(pullModelName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(SynapseColor.surface)
        .navigationTitle(L10n.Settings.models)
        .onAppear { Task { await loadModels() } }
        .confirmationDialog(
            "Delete Model",
            isPresented: $showDeleteConfirmation,
            presenting: modelToDelete
        ) { model in
            Button("Delete \(model.name)", role: .destructive) {
                Task { await deleteModel(model) }
            }
        } message: { model in
            Text("Are you sure you want to delete \(model.name)? This cannot be undone.")
        }
    }

    // MARK: - Actions

    private func loadModels() async {
        isLoading = true
        errorMessage = nil
        do {
            models = try await ollamaAPI.listModels()
            models.sort { $0.name < $1.name }
        } catch {
            errorMessage = "Failed to connect to Ollama on port \(config.ollamaPort). Is it running?"
        }
        isLoading = false
    }

    private func pullModel() async {
        let name = pullModelName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isPulling = true
        pullProgress = "Starting..."

        let stream = try? await ollamaAPI.pullModel(name: name)
        if let stream {
            for await progress in stream {
                pullProgress = progress.status
                if let total = progress.total, let completed = progress.completed, total > 0 {
                    let percent = Int(Double(completed) / Double(total) * 100)
                    pullProgress = "\(progress.status) \(percent)%"
                }
            }
        }

        isPulling = false
        pullModelName = ""
        pullProgress = ""
        await loadModels()
    }

    private func deleteModel(_ model: OllamaModelInfo) async {
        do {
            try await ollamaAPI.deleteModel(name: model.name)
            await loadModels()
        } catch {
            errorMessage = "Failed to delete model: \(error.localizedDescription)"
        }
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: OllamaModelInfo
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                    .fontDesign(.monospaced)

                HStack(spacing: 12) {
                    if let size = model.size {
                        Label(formatBytes(UInt64(size)), systemImage: "internaldrive")
                    }

                    if let family = model.details?.family {
                        Label(family, systemImage: "cpu")
                    }

                    if let paramSize = model.details?.parameterSize {
                        Label(paramSize, systemImage: "scalemass")
                    }

                    if let quant = model.details?.quantizationLevel {
                        Label(quant, systemImage: "cube")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}
