import SwiftUI
import BrainAICore

// MARK: - Search Result Item

struct SearchResultItem: Identifiable {
    let id = UUID()
    let content: String
    let source: String?
    let relevanceScore: Float?
}

// MARK: - Search ViewModel

@Observable
final class SearchViewModel: @unchecked Sendable {
    // MARK: - State

    var searchText: String = ""
    var selectedMode: SearchMode = .hybrid
    var results: [SearchResultItem] = []
    var isSearching: Bool = false
    var topK: Int = 20

    // MARK: - Dependencies

    private let lightRAGClient: LocalLightRAGClient

    // MARK: - Initialization

    init(lightRAGClient: LocalLightRAGClient = LocalLightRAGClient()) {
        self.lightRAGClient = lightRAGClient
    }

    // MARK: - Search Method

    /// Perform semantic search
    func search() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        guard !isSearching else { return }

        isSearching = true
        results = []

        Task {
            do {
                let response = try await lightRAGClient.query(
                    query,
                    mode: selectedMode,
                    topK: topK,
                    onlyNeedContext: false
                )

                // Parse response into SearchResultItems
                let items = parseSearchResponse(response)

                await MainActor.run {
                    self.results = items
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.results = []
                    self.isSearching = false
                }
            }
        }
    }

    /// Parse QueryResponse into SearchResultItems
    private func parseSearchResponse(_ response: QueryResponse) -> [SearchResultItem] {
        var items: [SearchResultItem] = []

        // Add main response as first result
        if !response.response.isEmpty {
            items.append(SearchResultItem(
                content: response.response,
                source: nil,
                relevanceScore: nil
            ))
        }

        // Add references as additional results
        if let references = response.references {
            for reference in references {
                items.append(SearchResultItem(
                    content: reference,
                    source: nil,
                    relevanceScore: nil
                ))
            }
        }

        return items
    }
}

// MARK: - Search View

struct SearchView: View {
    @State private var viewModel = SearchViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar Section
            searchBarSection
                .padding()
                .background(SynapseColor.surfaceContainer)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(SynapseColor.outlineVariant.opacity(0.2))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                }

            // Filters Row
            filtersRow
                .padding()
                .background(SynapseColor.surfaceContainer)

            // Results Section
            if viewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .synapseRootBackground()
            } else if viewModel.results.isEmpty && !viewModel.searchText.isEmpty {
                emptyStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.results.isEmpty {
                initialStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                resultsListView
            }

            Spacer()
        }
        .synapseRootBackground()
        .navigationTitle(L10n.Nav.search)
    }

    // MARK: - Search Bar Section

    private var searchBarSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(SynapseColor.onSurfaceVariant)

                TextField("Search your knowledge base...", text: $viewModel.searchText)
                    .onSubmit {
                        viewModel.search()
                    }

                Button(action: {
                    viewModel.search()
                }) {
                    Text("Search")
                        .frame(minWidth: 60)
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .tint(SynapseColor.primaryContainer)
            }
            .padding(10)
            .background(SynapseColor.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous)
                    .stroke(SynapseColor.outlineVariant.opacity(0.2), lineWidth: 1)
            )

            // Search Mode Picker
            HStack {
                Text("Mode:")
                    .font(.caption)
                    .foregroundStyle(SynapseColor.onSurfaceVariant)

                Picker("Search Mode", selection: $viewModel.selectedMode) {
                    Text("Hybrid").tag(SearchMode.hybrid)
                    Text("Local").tag(SearchMode.local)
                    Text("Global").tag(SearchMode.global)
                    Text("Naive").tag(SearchMode.naive)
                    Text("Mix").tag(SearchMode.mix)
                }
                .pickerStyle(.segmented)

                Spacer()
            }
        }
    }

    // MARK: - Filters Row

    private var filtersRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Top-K Results")
                    .font(.caption)
                    .foregroundStyle(SynapseColor.onSurfaceVariant)

                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.topK = max(5, viewModel.topK - 1)
                    }) {
                        Image(systemName: "minus.circle")
                    }

                    Text("\(viewModel.topK)")
                        .frame(minWidth: 30, alignment: .center)
                        .font(.body.monospacedDigit())

                    Button(action: {
                        viewModel.topK = min(50, viewModel.topK + 1)
                    }) {
                        Image(systemName: "plus.circle")
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Results")
                    .font(.caption)
                    .foregroundStyle(SynapseColor.onSurfaceVariant)

                Text("\(viewModel.results.count)")
                    .font(.body.monospacedDigit())
            }

            Spacer()
        }
    }

    // MARK: - Results List View

    private var resultsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.results) { result in
                    resultCardView(for: result)
                }
            }
            .padding()
        }
    }

    // MARK: - Result Card View

    private func resultCardView(for result: SearchResultItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.content)
                .font(.body)
                .lineLimit(3)
                .foregroundStyle(SynapseColor.onSurface)

            HStack(spacing: 12) {
                if let source = result.source {
                    Label(source, systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(SynapseColor.onSurfaceVariant)
                }

                if let score = result.relevanceScore {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(SynapseColor.primary)

                        Text(String(format: "%.2f", score))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(SynapseColor.onSurfaceVariant)
                }

                Spacer()
            }
        }
        .padding()
        .synapseCardSurface(cornerRadius: SynapseLayout.cardCornerRadius)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(SynapseColor.onSurfaceVariant.opacity(0.55))

            Text("No Results Found")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(SynapseColor.onSurface)

            Text("Try refining your search query or adjusting the search mode")
                .font(.caption)
                .foregroundStyle(SynapseColor.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .synapseRootBackground()
    }

    // MARK: - Initial State View

    private var initialStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(SynapseColor.onSurfaceVariant.opacity(0.55))

            Text("Enter a Query")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(SynapseColor.onSurface)

            Text("Enter a search query to explore your knowledge base")
                .font(.caption)
                .foregroundStyle(SynapseColor.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .synapseRootBackground()
    }
}

// MARK: - Preview

#Preview {
    SearchView()
        .frame(minWidth: 600, minHeight: 400)
}
