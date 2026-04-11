import Foundation
import Observation
import BrainAICore

// MARK: - Knowledge Graph ViewModel

@Observable
final class KnowledgeGraphViewModel: @unchecked Sendable {

    // MARK: - Published State

    var isLoading = false
    var errorMessage: String?
    var entityLabels: [String] = []
    var relationLabels: [String] = []
    var selectedEntityTypes: Set<String> = []

    var nodeCount = 0
    var edgeCount = 0

    var selectedNode: SelectedNodeInfo?
    var connectedNodes: [ConnectedNodeInfo] = []

    var searchText = ""
    var pathSourceNode = ""
    var pathTargetNode = ""

    // MARK: - Graph Data

    private(set) var graphNodes: [(id: String, label: String, type: String, description: String?)] = []
    private(set) var graphEdges: [(source: String, target: String, description: String?, keywords: String?)] = []

    // MARK: - Private

    private let lightRAGClient: LocalLightRAGClient
    private let lock = NSLock()

    init() {
        self.lightRAGClient = LocalLightRAGClient()
    }

    // MARK: - Data Loading

    func loadGraphLabels() async {
        lock.lock()
        isLoading = true
        errorMessage = nil
        lock.unlock()

        do {
            let labels = try await lightRAGClient.getGraphLabels()
            lock.lock()
            entityLabels = labels.entityLabels
            relationLabels = labels.relationLabels
            selectedEntityTypes = Set(labels.entityLabels)
            lock.unlock()
        } catch {
            lock.lock()
            errorMessage = "Failed to load graph labels: \(error.localizedDescription)"
            lock.unlock()
        }

        lock.lock()
        isLoading = false
        lock.unlock()
    }

    func loadGraphData(forLabel label: String = "", searchText: String = "", maxItems: Int = 200) async {
        lock.lock()
        isLoading = true
        errorMessage = nil
        lock.unlock()

        do {
            // If no specific label, load for each entity type
            var allNodes: [(id: String, label: String, type: String, description: String?)] = []
            var allEdges: [(source: String, target: String, description: String?, keywords: String?)] = []
            var seenNodeIds: Set<String> = []

            let labelsToFetch = label.isEmpty ? entityLabels : [label]

            for entityLabel in labelsToFetch {
                let result = try await lightRAGClient.searchGraph(
                    label: entityLabel,
                    searchText: searchText,
                    maxItems: maxItems
                )

                for node in result.nodes {
                    if !seenNodeIds.contains(node.name) {
                        seenNodeIds.insert(node.name)
                        allNodes.append((
                            id: node.name,
                            label: node.name,
                            type: node.type ?? entityLabel,
                            description: node.description
                        ))
                    }
                }

                for edge in result.edges {
                    allEdges.append((
                        source: edge.source,
                        target: edge.target,
                        description: edge.description,
                        keywords: edge.keywords
                    ))
                }
            }

            lock.lock()
            graphNodes = allNodes
            graphEdges = allEdges
            nodeCount = allNodes.count
            edgeCount = allEdges.count
            lock.unlock()
        } catch {
            lock.lock()
            errorMessage = "Failed to load graph: \(error.localizedDescription)"
            // Provide demo data if service is unavailable
            loadDemoData()
            lock.unlock()
        }

        lock.lock()
        isLoading = false
        lock.unlock()
    }

    // MARK: - Node Selection

    func selectNode(name: String?, type: String?, description: String?) {
        if let name = name {
            lock.lock()
            selectedNode = SelectedNodeInfo(name: name, type: type ?? "Unknown", description: description)
            lock.unlock()

            // Find connected nodes
            var connected: [ConnectedNodeInfo] = []
            for edge in graphEdges {
                if edge.source == name {
                    connected.append(ConnectedNodeInfo(
                        name: edge.target,
                        relationship: edge.description ?? "related to",
                        direction: .outgoing
                    ))
                } else if edge.target == name {
                    connected.append(ConnectedNodeInfo(
                        name: edge.source,
                        relationship: edge.description ?? "related to",
                        direction: .incoming
                    ))
                }
            }
            lock.lock()
            connectedNodes = connected
            lock.unlock()
        } else {
            lock.lock()
            selectedNode = nil
            connectedNodes = []
            lock.unlock()
        }
    }

    // MARK: - Demo Data

    private func loadDemoData() {
        graphNodes = [
            (id: "Machine Learning", label: "Machine Learning", type: "Concept", description: "A subset of AI focused on learning from data"),
            (id: "Neural Network", label: "Neural Network", type: "Concept", description: "Computing system inspired by biological neural networks"),
            (id: "Deep Learning", label: "Deep Learning", type: "Concept", description: "ML using deep neural networks with many layers"),
            (id: "Transformer", label: "Transformer", type: "Architecture", description: "Attention-based neural network architecture"),
            (id: "GPT", label: "GPT", type: "Model", description: "Generative Pre-trained Transformer by OpenAI"),
            (id: "BERT", label: "BERT", type: "Model", description: "Bidirectional Encoder Representations from Transformers"),
            (id: "Attention", label: "Attention Mechanism", type: "Concept", description: "Mechanism allowing models to focus on relevant parts of input"),
            (id: "NLP", label: "Natural Language Processing", type: "Domain", description: "AI subfield dealing with human language"),
            (id: "Computer Vision", label: "Computer Vision", type: "Domain", description: "AI subfield for visual understanding"),
            (id: "CNN", label: "Convolutional Neural Network", type: "Architecture", description: "Neural network for grid-like data"),
            (id: "Transfer Learning", label: "Transfer Learning", type: "Concept", description: "Reusing pre-trained models for new tasks"),
            (id: "Embedding", label: "Embedding", type: "Concept", description: "Dense vector representation of data"),
            (id: "RAG", label: "Retrieval-Augmented Generation", type: "Technique", description: "Combining retrieval with generation for grounded responses"),
            (id: "Vector Database", label: "Vector Database", type: "Technology", description: "Database optimized for similarity search over embeddings"),
            (id: "Knowledge Graph", label: "Knowledge Graph", type: "Technology", description: "Graph-structured knowledge representation"),
        ]

        graphEdges = [
            (source: "Machine Learning", target: "Neural Network", description: "includes", keywords: nil),
            (source: "Machine Learning", target: "Deep Learning", description: "includes", keywords: nil),
            (source: "Deep Learning", target: "Neural Network", description: "uses", keywords: nil),
            (source: "Transformer", target: "Attention", description: "based on", keywords: nil),
            (source: "GPT", target: "Transformer", description: "uses architecture", keywords: nil),
            (source: "BERT", target: "Transformer", description: "uses architecture", keywords: nil),
            (source: "GPT", target: "NLP", description: "applied in", keywords: nil),
            (source: "BERT", target: "NLP", description: "applied in", keywords: nil),
            (source: "CNN", target: "Computer Vision", description: "applied in", keywords: nil),
            (source: "CNN", target: "Neural Network", description: "type of", keywords: nil),
            (source: "Transfer Learning", target: "Deep Learning", description: "technique in", keywords: nil),
            (source: "Embedding", target: "NLP", description: "used in", keywords: nil),
            (source: "Embedding", target: "Vector Database", description: "stored in", keywords: nil),
            (source: "RAG", target: "Embedding", description: "uses", keywords: nil),
            (source: "RAG", target: "Knowledge Graph", description: "can use", keywords: nil),
            (source: "RAG", target: "Vector Database", description: "retrieves from", keywords: nil),
            (source: "RAG", target: "GPT", description: "generates with", keywords: nil),
            (source: "Knowledge Graph", target: "NLP", description: "used in", keywords: nil),
        ]

        entityLabels = ["Concept", "Architecture", "Model", "Domain", "Technique", "Technology"]
        selectedEntityTypes = Set(entityLabels)
        nodeCount = graphNodes.count
        edgeCount = graphEdges.count
    }
}

// MARK: - Supporting Types

struct SelectedNodeInfo {
    let name: String
    let type: String
    let description: String?
}

struct ConnectedNodeInfo: Identifiable {
    let id = UUID()
    let name: String
    let relationship: String
    let direction: ConnectionDirection
}

enum ConnectionDirection {
    case incoming
    case outgoing

    var symbol: String {
        switch self {
        case .incoming: "arrow.left"
        case .outgoing: "arrow.right"
        }
    }
}
