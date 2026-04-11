import SwiftUI
import SpriteKit
import BrainAICore

// MARK: - Knowledge Graph View

struct KnowledgeGraphView: View {
    @State private var viewModel = KnowledgeGraphViewModel()
    @State private var graphScene: GraphScene?
    @State private var showFilterPanel = false
    @State private var showPathFinder = false

    var body: some View {
        HSplitView {
            // Main graph area
            graphArea
                .frame(minWidth: 500)

            // Details sidebar (shown when node selected)
            if viewModel.selectedNode != nil {
                detailsSidebar
                    .frame(width: 280)
            }
        }
        .toolbar {
            toolbarContent
        }
        .task {
            await loadGraph()
        }
    }

    // MARK: - Graph Area

    private var graphArea: some View {
        ZStack {
            // SpriteKit scene
            if let scene = graphScene {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .ignoresSafeArea()
            } else {
                Color(nsColor: NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0))
            }

            // Overlay controls
            VStack {
                HStack {
                    // Search bar
                    searchBar

                    Spacer()

                    // Stats badge
                    statsBadge
                }
                .padding()

                Spacer()

                // Bottom controls
                HStack {
                    if showFilterPanel {
                        filterPanel
                    }

                    Spacer()

                    if showPathFinder {
                        pathFinderPanel
                    }
                }
                .padding()

                // Legend
                legendBar
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            // Loading overlay
            if viewModel.isLoading {
                loadingOverlay
            }

            // Error overlay
            if let error = viewModel.errorMessage {
                errorOverlay(error)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search entities...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    Task { await searchAndReload() }
                }

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                    Task { await loadGraph() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .frame(maxWidth: 300)
    }

    // MARK: - Stats Badge

    private var statsBadge: some View {
        HStack(spacing: 12) {
            Label("\(viewModel.nodeCount) nodes", systemImage: "circle.fill")
                .font(.caption)
            Label("\(viewModel.edgeCount) edges", systemImage: "line.diagonal")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(6)
    }

    // MARK: - Filter Panel

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Entity Types")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(viewModel.entityLabels, id: \.self) { label in
                Toggle(isOn: Binding(
                    get: { viewModel.selectedEntityTypes.contains(label) },
                    set: { isOn in
                        if isOn {
                            viewModel.selectedEntityTypes.insert(label)
                        } else {
                            viewModel.selectedEntityTypes.remove(label)
                        }
                        applyTypeFilter()
                    }
                )) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(nsColor: GraphColorPalette.color(for: label)))
                            .frame(width: 10, height: 10)
                        Text(label)
                            .font(.caption)
                    }
                }
                .toggleStyle(.checkbox)
            }

            Divider()

            HStack {
                Button("All") {
                    viewModel.selectedEntityTypes = Set(viewModel.entityLabels)
                    applyTypeFilter()
                }
                .font(.caption)

                Button("None") {
                    viewModel.selectedEntityTypes.removeAll()
                    applyTypeFilter()
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .frame(maxWidth: 200)
    }

    // MARK: - Path Finder Panel

    private var pathFinderPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Find Path")
                .font(.headline)

            TextField("From entity...", text: $viewModel.pathSourceNode)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            TextField("To entity...", text: $viewModel.pathTargetNode)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            HStack {
                Button("Find") {
                    graphScene?.highlightPath(
                        from: viewModel.pathSourceNode,
                        to: viewModel.pathTargetNode
                    )
                }
                .font(.caption)
                .disabled(viewModel.pathSourceNode.isEmpty || viewModel.pathTargetNode.isEmpty)

                Button("Clear") {
                    graphScene?.clearHighlight()
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .frame(maxWidth: 220)
    }

    // MARK: - Legend

    private var legendBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.entityLabels, id: \.self) { label in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(nsColor: GraphColorPalette.color(for: label)))
                            .frame(width: 8, height: 8)
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(4)
        }
    }

    // MARK: - Loading & Error Overlays

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading knowledge graph...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .frame(maxWidth: 300)
        .transition(.opacity)
    }

    // MARK: - Details Sidebar

    private var detailsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let node = viewModel.selectedNode {
                    // Node header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.name)
                            .font(.title3)
                            .fontWeight(.semibold)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(nsColor: GraphColorPalette.color(for: node.type)))
                                .frame(width: 10, height: 10)
                            Text(node.type)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let description = node.description, !description.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(description)
                                .font(.callout)
                        }
                    }

                    // Connected nodes
                    if !viewModel.connectedNodes.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Connections (\(viewModel.connectedNodes.count))")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(viewModel.connectedNodes) { connection in
                                HStack(spacing: 6) {
                                    Image(systemName: connection.direction.symbol)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 14)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(connection.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text(connection.relationship)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Navigate to connected node
                                    if let graphNode = graphScene?.graphNodes[connection.name] {
                                        graphScene?.selectNode(graphNode)
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    // Actions
                    VStack(spacing: 8) {
                        Button {
                            viewModel.pathSourceNode = node.name
                            showPathFinder = true
                        } label: {
                            Label("Set as Path Source", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.caption)
                        }

                        Button {
                            viewModel.pathTargetNode = node.name
                            showPathFinder = true
                        } label: {
                            Label("Set as Path Target", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding()
        }
        .background(.background)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button {
                showFilterPanel.toggle()
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
            .help("Toggle entity type filter")

            Button {
                showPathFinder.toggle()
            } label: {
                Label("Path Finder", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            }
            .help("Find path between entities")

            Divider()

            Button {
                graphScene?.zoomToFit()
            } label: {
                Label("Zoom to Fit", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .help("Zoom to fit all nodes")

            Button {
                graphScene?.restartSimulation()
            } label: {
                Label("Re-layout", systemImage: "arrow.triangle.2.circlepath")
            }
            .help("Restart force-directed layout")

            Button {
                Task { await loadGraph() }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .help("Reload graph data from knowledge base")
        }
    }

    // MARK: - Actions

    private func loadGraph() async {
        await viewModel.loadGraphLabels()
        await viewModel.loadGraphData(searchText: viewModel.searchText)
        setupScene()
    }

    private func searchAndReload() async {
        await viewModel.loadGraphData(searchText: viewModel.searchText)
        setupScene()
    }

    private func setupScene() {
        let scene = GraphScene(size: CGSize(width: 1200, height: 800))
        scene.scaleMode = .resizeFill

        scene.onNodeSelected = { graphNode in
            if let graphNode = graphNode {
                viewModel.selectNode(name: graphNode.label, type: graphNode.entityType, description: graphNode.description)
            } else {
                viewModel.selectNode(name: nil, type: nil, description: nil)
            }
        }

        scene.loadGraph(nodes: viewModel.graphNodes, edges: viewModel.graphEdges)

        self.graphScene = scene

        // Auto zoom to fit after a delay for simulation to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            scene.zoomToFit()
        }
    }

    private func applyTypeFilter() {
        if viewModel.selectedEntityTypes.count == viewModel.entityLabels.count {
            graphScene?.showAllTypes()
        } else {
            graphScene?.setVisibleTypes(viewModel.selectedEntityTypes)
        }
    }
}
