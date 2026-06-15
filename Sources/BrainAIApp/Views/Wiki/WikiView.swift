import SwiftUI
import BrainAICore

// MARK: - Wiki ViewModel

@Observable
final class WikiViewModel: @unchecked Sendable {
    var pages: [WikiPage] = []
    var reviewItems: [WikiReviewItem] = []
    var selectedPagePath: String?
    var searchText = ""
    var isLoading = false
    var errorMessage: String?
    var syncStatusMessage: String?

    private let workspaceManager: WorkspaceManager
    private let lightRAGClient: LocalLightRAGClient

    init(
        workspaceManager: WorkspaceManager = WorkspaceManager.shared,
        lightRAGClient: LocalLightRAGClient = LocalLightRAGClient()
    ) {
        self.workspaceManager = workspaceManager
        self.lightRAGClient = lightRAGClient
    }

    var selectedPage: WikiPage? {
        pages.first { $0.path == selectedPagePath } ?? pages.first
    }

    var filteredPages: [WikiPage] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return pages }

        return pages.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
                $0.path.localizedCaseInsensitiveContains(query) ||
                $0.markdown.localizedCaseInsensitiveContains(query)
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let store = await currentWikiStore()
            let loaded = try await store.listPages()
            let reviews = try await store.listReviewItems()
            await MainActor.run {
                self.pages = loaded
                self.reviewItems = reviews
                if let selectedPagePath = self.selectedPagePath,
                   loaded.contains(where: { $0.path == selectedPagePath }) {
                    self.selectedPagePath = selectedPagePath
                } else {
                    self.selectedPagePath = loaded.first?.path
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func refreshIndex() async {
        do {
            let store = await currentWikiStore()
            try await store.regenerateIndex()
            await load()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func updateReview(_ item: WikiReviewItem, status: WikiReviewStatus) async {
        do {
            let store = await currentWikiStore()
            try await store.updateReviewItemStatus(id: item.id, status: status)
            if status == .accepted || status == .autoAccepted {
                await syncAcceptedPage(item.pagePath, store: store)
            } else {
                await MainActor.run {
                    self.syncStatusMessage = "\(status.rawValue) \(item.pagePath)"
                }
            }
            await load()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func syncAcceptedPage(_ pagePath: String, store: WikiPageStore) async {
        do {
            let page = try await store.readPage(at: pagePath)
            if try await !store.needsLightRAGSync(page),
               let state = try await store.syncState(for: page) {
                await MainActor.run {
                    self.syncStatusMessage = "Accepted, already synced: \(page.path) (\(state.lightRAGTrackID))"
                }
                return
            }

            let response = try await lightRAGClient.insertText(
                page.markdown,
                description: "Accepted wiki page: \(page.path)"
            )
            try await store.recordLightRAGSync(page: page, trackId: response.trackId)
            await MainActor.run {
                self.syncStatusMessage = "Accepted and synced: \(page.path) (\(response.trackId))"
            }
        } catch {
            await MainActor.run {
                self.syncStatusMessage = "Accepted, but LightRAG sync failed: \(error.localizedDescription)"
            }
        }
    }

    func selectReviewItem(_ item: WikiReviewItem) {
        if pages.contains(where: { $0.path == item.pagePath }) {
            selectedPagePath = item.pagePath
        }
    }

    private func currentWikiStore() async -> WikiPageStore {
        let workspace = await MainActor.run { workspaceManager.activeWorkspace }
        if let workspace {
            return WikiPageStore(workspaceURL: workspace.dataPath)
        }
        return WikiPageStore(workspaceSlug: "default")
    }
}

// MARK: - Wiki View

struct WikiView: View {
    @State private var viewModel: WikiViewModel

    init(workspaceManager: WorkspaceManager = WorkspaceManager.shared) {
        _viewModel = State(initialValue: WikiViewModel(workspaceManager: workspaceManager))
    }

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 260, idealWidth: 310, maxWidth: 380)

            Divider()
                .background(SynapseColor.outlineVariant.opacity(0.25))

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await viewModel.load()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await viewModel.refreshIndex() }
                } label: {
                    Label("Refresh index", systemImage: "arrow.clockwise")
                }
                .help("Refresh index")
            }
        }
        .synapseRootBackground()
        .navigationTitle("Wiki")
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            searchField
                .padding(12)

            reviewSummary
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            if let syncStatus = viewModel.syncStatusMessage {
                wikiSyncStatus(syncStatus)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            reviewQueue
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $viewModel.selectedPagePath) {
                    ForEach(viewModel.filteredPages) { page in
                        pageRow(page)
                            .tag(Optional(page.path))
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .background(SynapseColor.surfaceContainerLow)
    }

    private var reviewSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .foregroundStyle(SynapseColor.onSurfaceVariant)

            Text("\(viewModel.reviewItems.filter { $0.status == .needsReview }.count) pending reviews")
                .font(.caption)
                .foregroundStyle(SynapseColor.onSurfaceVariant)

            Spacer()
        }
        .padding(8)
        .background(SynapseColor.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func wikiSyncStatus(_ status: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: status.contains("failed") ? "exclamationmark.triangle" : "arrow.triangle.2.circlepath")
                .foregroundStyle(status.contains("failed") ? .orange : SynapseColor.primary)

            Text(status)
                .font(.caption2)
                .foregroundStyle(SynapseColor.onSurfaceVariant)
                .lineLimit(2)

            Spacer()
        }
        .padding(8)
        .background(SynapseColor.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var reviewQueue: some View {
        let pending = viewModel.reviewItems.filter { $0.status == .needsReview }.prefix(3)

        return VStack(spacing: 6) {
            ForEach(Array(pending)) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)

                    Text(item.reason)
                        .font(.caption2)
                        .foregroundStyle(SynapseColor.onSurfaceVariant)
                        .lineLimit(2)

                    Button {
                        viewModel.selectReviewItem(item)
                    } label: {
                        Text(item.pagePath)
                            .font(.caption2.monospaced())
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SynapseColor.primary)

                    HStack(spacing: 8) {
                        Button {
                            Task { await viewModel.updateReview(item, status: .accepted) }
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.borderless)
                        .help("Accept")

                        Button {
                            Task { await viewModel.updateReview(item, status: .rejected) }
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.borderless)
                        .help("Reject")

                        Spacer()
                    }
                }
                .padding(8)
                .background(SynapseColor.surfaceContainer)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SynapseColor.onSurfaceVariant)

            TextField("Search wiki...", text: $viewModel.searchText)
                .textFieldStyle(.plain)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(SynapseColor.onSurfaceVariant)
            }
        }
        .padding(8)
        .background(SynapseColor.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous)
                .stroke(SynapseColor.outlineVariant.opacity(0.2), lineWidth: 1)
        )
    }

    private func pageRow(_ page: WikiPage) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon(for: page.kind))
                .foregroundStyle(SynapseColor.primary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(page.title)
                    .lineLimit(1)
                    .foregroundStyle(SynapseColor.onSurface)

                Text(page.path)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(SynapseColor.onSurfaceVariant)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage {
            ContentUnavailableView(
                "Wiki unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
            .synapseRootBackground()
        } else if let page = viewModel.selectedPage {
            pageContent(page)
        } else {
            ContentUnavailableView(
                "No wiki pages",
                systemImage: "doc.text.magnifyingglass",
                description: Text("The workspace wiki will appear here after the first memory page is created.")
            )
            .synapseRootBackground()
        }
    }

    private func pageContent(_ page: WikiPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(page.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(SynapseColor.onSurface)

                        Text(page.path)
                            .font(.caption)
                            .foregroundStyle(SynapseColor.onSurfaceVariant)
                    }

                    Spacer()

                    Text(page.kind.displayName)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(SynapseColor.surfaceContainerHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    if let status = page.frontmatter["status"] {
                        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(status == WikiReviewStatus.needsReview.rawValue ? SynapseColor.primary.opacity(0.14) : SynapseColor.surfaceContainerHigh)
                            .foregroundStyle(status == WikiReviewStatus.needsReview.rawValue ? SynapseColor.primary : SynapseColor.onSurfaceVariant)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }

                Divider()
                    .background(SynapseColor.outlineVariant.opacity(0.2))

                Text(page.markdown)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(SynapseColor.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SynapseColor.surface)
    }

    private func icon(for kind: WikiPageKind) -> String {
        switch kind {
        case .index: "list.bullet.rectangle"
        case .log: "clock.arrow.circlepath"
        case .source: "doc.text"
        case .entity: "person.crop.circle"
        case .concept: "lightbulb"
        case .synthesis: "square.stack.3d.up"
        case .decision: "checkmark.seal"
        case .contradiction: "exclamationmark.triangle"
        case .question: "questionmark.circle"
        case .user: "person.text.rectangle"
        case .inbox: "tray"
        case .unknown: "doc"
        }
    }
}

#Preview {
    WikiView()
}
