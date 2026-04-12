import SwiftUI
import BrainAICore
import UniformTypeIdentifiers

// MARK: - Documents ViewModel

/// ViewModel for managing documents with pagination and filtering
@Observable
final class DocumentsViewModel: @unchecked Sendable {
    // MARK: - Document Data

    var documents: [DocumentInfo] = []
    var isLoading: Bool = false
    var currentPage: Int = 1
    var totalDocuments: Int = 0
    var hasMore: Bool = false

    // MARK: - Filtering

    var statusFilter: DocumentStatus? = nil

    // MARK: - State Management

    var errorMessage: String?
    var isImporting: Bool = false

    // MARK: - Dependencies

    private let lightRAGClient: LocalLightRAGClient
    private let pageSize: Int = 20

    // MARK: - Initialization

    init(lightRAGClient: LocalLightRAGClient = LocalLightRAGClient()) {
        self.lightRAGClient = lightRAGClient
    }

    // MARK: - Public Methods

    /// Load documents for current page
    func loadDocuments() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await lightRAGClient.listDocuments(
                page: currentPage,
                pageSize: pageSize,
                status: statusFilter?.rawValue
            )

            await MainActor.run {
                self.documents = response.documents
                self.totalDocuments = response.total
                self.hasMore = response.hasMore
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load documents: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    /// Load next page of documents
    func loadMore() async {
        currentPage += 1
        await loadDocuments()
    }

    /// Refresh documents (reset to page 1 and reload)
    func refresh() async {
        currentPage = 1
        await loadDocuments()
    }

    /// Import file by reading text and inserting into knowledge base
    func importFile(url: URL) async {
        isImporting = true
        errorMessage = nil

        do {
            // Read file contents
            let content = try String(contentsOf: url, encoding: .utf8)

            // Get filename for description
            let filename = url.lastPathComponent

            // Insert text into knowledge base
            _ = try await lightRAGClient.insertText(content, description: filename)

            await MainActor.run {
                self.isImporting = false
            }

            // Refresh documents list
            await refresh()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to import file: \(error.localizedDescription)"
                self.isImporting = false
            }
        }
    }

    /// Change status filter and reload
    func setStatusFilter(_ status: DocumentStatus?) async {
        statusFilter = status
        currentPage = 1
        await loadDocuments()
    }
}

// MARK: - Documents View

struct DocumentsView: View {
    @State private var viewModel = DocumentsViewModel()
    @State private var selectedStatusFilter: DocumentStatus? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Toolbar area
                toolbar

                // Main content
                if viewModel.documents.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    documentsList
                }

                // Pagination
                if viewModel.hasMore {
                    paginationFooter
                }
            }

            // Loading overlay
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SynapseColor.surface.opacity(0.45))
            }
        }
        .onDrop(of: [UTType.text, UTType.plainText, UTType.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .task {
            await viewModel.loadDocuments()
        }
        .synapseRootBackground()
        .navigationTitle(L10n.Documents.title)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Import Files button
                Button(action: openFileImporter) {
                    Label("Import Files", systemImage: "doc.badge.plus")
                }
                .help("Import text and markdown files")

                // Status filter
                Picker("Status", selection: $selectedStatusFilter) {
                    Text("All").tag(nil as DocumentStatus?)
                    Text("Pending").tag(DocumentStatus.pending as DocumentStatus?)
                    Text("Processing").tag(DocumentStatus.processing as DocumentStatus?)
                    Text("Processed").tag(DocumentStatus.processed as DocumentStatus?)
                    Text("Failed").tag(DocumentStatus.failed as DocumentStatus?)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
                .onChange(of: selectedStatusFilter) { oldValue, newValue in
                    Task {
                        await viewModel.setStatusFilter(newValue)
                    }
                }

                Spacer()

                // Refresh button
                Button(action: {
                    Task {
                        await viewModel.refresh()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh documents")

                // Document count
                Text("\(viewModel.totalDocuments) document\(viewModel.totalDocuments == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(SynapseColor.onSurfaceVariant)
            }
            .padding(12)
            .synapseToolbarStrip()

            Divider()
                .background(SynapseColor.outlineVariant.opacity(0.2))
        }
    }

    // MARK: - Documents List

    private var documentsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 12) {
                    Text("Status")
                        .frame(width: 50)
                    Text("Document ID")
                        .font(.system(.caption, design: .monospaced))
                    Text("Status")
                        .frame(width: 80)
                    Text("Created")
                        .frame(width: 100)
                    Text("Updated")
                        .frame(width: 100)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(SynapseColor.onSurfaceVariant)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()
                    .background(SynapseColor.outlineVariant.opacity(0.15))

                // Document rows
                ForEach(viewModel.documents, id: \.id) { document in
                    DocumentRow(document: document)

                    Divider()
                        .background(SynapseColor.outlineVariant.opacity(0.12))
                }
            }
            .background(SynapseColor.surfaceContainer)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(SynapseColor.onSurfaceVariant)

            VStack(spacing: 8) {
                Text("No documents yet")
                    .font(.headline)
                    .foregroundStyle(SynapseColor.onSurface)

                Text("Import files to get started")
                    .font(.subheadline)
                    .foregroundStyle(SynapseColor.onSurfaceVariant)
            }

            Button(action: openFileImporter) {
                Label("Import Files", systemImage: "doc.badge.plus")
            }
            .tint(SynapseColor.primaryContainer)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SynapseColor.surface)
    }

    // MARK: - Pagination Footer

    private var paginationFooter: some View {
        HStack(spacing: 12) {
            Spacer()

            Button(action: {
                Task {
                    await viewModel.loadMore()
                }
            }) {
                Label("Load More", systemImage: "ellipsis")
            }
            .disabled(viewModel.isLoading)

            Spacer()
        }
        .padding(12)
        .background(SynapseColor.surfaceContainer)
    }

    // MARK: - File Import

    private func openFileImporter() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        var contentTypes: [UTType] = [.plainText]
        if let mdType = UTType(filenameExtension: "md") {
            contentTypes.append(mdType)
        }
        panel.allowedContentTypes = contentTypes
        panel.message = "Select files to import"
        panel.prompt = "Import"

        let response = panel.runModal()
        if response == .OK {
            for url in panel.urls {
                Task {
                    await viewModel.importFile(url: url)
                }
            }
        }
    }

    /// Handle drag and drop of files
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // Handle file URLs
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                    if let data = data as? Data,
                       let path = String(data: data, encoding: .utf8),
                       let url = URL(string: path) {
                        Task {
                            await viewModel.importFile(url: url)
                        }
                    }
                }
                return true
            }

            // Handle text content
            if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { data, _ in
                    if let data = data as? Data,
                       let text = String(data: data, encoding: .utf8) {
                        Task {
                            let tempURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent("imported_text_\(UUID().uuidString).txt")
                            do {
                                try text.write(to: tempURL, atomically: true, encoding: .utf8)
                                await viewModel.importFile(url: tempURL)
                            } catch {
                                // Handle error silently
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}

// MARK: - Document Row Component

private struct DocumentRow: View {
    let document: DocumentInfo

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .frame(width: 50)

            // Document ID (truncated, monospaced)
            Text(document.id)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            // Status text
            Text(document.status.rawValue.capitalized)
                .frame(width: 80, alignment: .leading)
                .font(.caption)

            // Created date
            Text(formatDate(document.createdAt))
                .frame(width: 100, alignment: .leading)
                .font(.caption)
                .foregroundColor(.secondary)

            // Updated date
            Text(formatDate(document.updatedAt))
                .frame(width: 100, alignment: .leading)
                .font(.caption)
                .foregroundStyle(SynapseColor.onSurfaceVariant)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch document.status {
        case .pending:
            return SynapseColor.secondary
        case .processing:
            return SynapseColor.primaryContainer
        case .processed:
            return SynapseColor.tertiary
        case .failed:
            return SynapseColor.error
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DocumentsView()
    }
}
