import SpriteKit
import Foundation
import BrainAICore

// MARK: - Graph Data Models

/// A node in the visual graph
final class GraphNode {
    let id: String
    let label: String
    let entityType: String
    let description: String?
    var position: CGPoint
    var velocity: CGPoint = .zero
    var isFixed: Bool = false
    var connectionCount: Int = 0

    var spriteNode: SKShapeNode?
    var labelNode: SKLabelNode?

    init(id: String, label: String, entityType: String, description: String? = nil, position: CGPoint = .zero) {
        self.id = id
        self.label = label
        self.entityType = entityType
        self.description = description
        self.position = position
    }
}

/// An edge in the visual graph
final class GraphEdge {
    let id: String
    let source: String
    let target: String
    let description: String?
    let keywords: String?
    var lineNode: SKShapeNode?

    init(id: String, source: String, target: String, description: String? = nil, keywords: String? = nil) {
        self.id = id
        self.source = source
        self.target = target
        self.description = description
        self.keywords = keywords
    }
}

// MARK: - Color Palette for Entity Types

struct GraphColorPalette {
    private static let colors: [NSColor] = [
        NSColor(red: 0.35, green: 0.60, blue: 0.95, alpha: 1.0),  // Blue
        NSColor(red: 0.95, green: 0.45, blue: 0.35, alpha: 1.0),  // Red-Orange
        NSColor(red: 0.30, green: 0.80, blue: 0.55, alpha: 1.0),  // Green
        NSColor(red: 0.75, green: 0.50, blue: 0.95, alpha: 1.0),  // Purple
        NSColor(red: 0.95, green: 0.70, blue: 0.25, alpha: 1.0),  // Gold
        NSColor(red: 0.45, green: 0.85, blue: 0.85, alpha: 1.0),  // Cyan
        NSColor(red: 0.95, green: 0.50, blue: 0.70, alpha: 1.0),  // Pink
        NSColor(red: 0.60, green: 0.75, blue: 0.35, alpha: 1.0),  // Lime
    ]

    private static var typeColorMap: [String: NSColor] = [:]
    private static var nextIndex = 0

    static func color(for entityType: String) -> NSColor {
        if let existing = typeColorMap[entityType] {
            return existing
        }
        let color = colors[nextIndex % colors.count]
        typeColorMap[entityType] = color
        nextIndex += 1
        return color
    }

    static func reset() {
        typeColorMap.removeAll()
        nextIndex = 0
    }
}

// MARK: - Force-Directed Graph Scene

final class GraphScene: SKScene {

    // MARK: - Configuration

    private let repulsionStrength: CGFloat = 8000.0
    private let attractionStrength: CGFloat = 0.005
    private let centeringStrength: CGFloat = 0.02
    private let dampingFactor: CGFloat = 0.85
    private let idealEdgeLength: CGFloat = 150.0
    private let maxVelocity: CGFloat = 50.0
    private let stabilizationThreshold: CGFloat = 0.5

    // MARK: - State

    private(set) var graphNodes: [String: GraphNode] = [:]
    private(set) var graphEdges: [GraphEdge] = []
    private var isSimulationRunning = true
    private var totalKineticEnergy: CGFloat = 0.0
    private var iterationCount = 0

    private var selectedNodeId: String?
    private var highlightedPath: Set<String> = []
    private var draggedNode: GraphNode?
    private var lastMousePosition: CGPoint = .zero
    private var cameraNode: SKCameraNode!
    private var currentZoom: CGFloat = 1.0

    /// Callback when a node is selected
    var onNodeSelected: ((GraphNode?) -> Void)?

    // MARK: - Setup

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = SynapseColor.graphBackgroundNSColor

        cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode
    }

    // MARK: - Graph Data Loading

    func loadGraph(nodes nodeData: [(id: String, label: String, type: String, description: String?)],
                   edges edgeData: [(source: String, target: String, description: String?, keywords: String?)]) {
        clearGraph()
        GraphColorPalette.reset()

        let centerX = size.width / 2
        let centerY = size.height / 2
        let radius = min(size.width, size.height) * 0.3

        // Create nodes in circular layout as initial positions
        for (index, data) in nodeData.enumerated() {
            let angle = (CGFloat(index) / CGFloat(nodeData.count)) * 2.0 * .pi
            let x = centerX + radius * cos(angle) + CGFloat.random(in: -30...30)
            let y = centerY + radius * sin(angle) + CGFloat.random(in: -30...30)

            let node = GraphNode(id: data.id, label: data.label, entityType: data.type,
                                 description: data.description, position: CGPoint(x: x, y: y))
            graphNodes[data.id] = node
        }

        // Create edges
        for (index, data) in edgeData.enumerated() {
            guard graphNodes[data.source] != nil, graphNodes[data.target] != nil else { continue }
            let edge = GraphEdge(id: "edge_\(index)", source: data.source, target: data.target,
                                 description: data.description, keywords: data.keywords)
            graphEdges.append(edge)

            graphNodes[data.source]?.connectionCount += 1
            graphNodes[data.target]?.connectionCount += 1
        }

        // Create sprite nodes
        createSpriteNodes()

        // Start simulation
        isSimulationRunning = true
        iterationCount = 0
    }

    private func clearGraph() {
        removeAllChildren()
        graphNodes.removeAll()
        graphEdges.removeAll()
        selectedNodeId = nil
        highlightedPath.removeAll()

        cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode
    }

    private func createSpriteNodes() {
        // Create edge lines first (behind nodes)
        for edge in graphEdges {
            let line = SKShapeNode()
            line.strokeColor = NSColor.white.withAlphaComponent(0.15)
            line.lineWidth = 1.0
            line.zPosition = 1
            line.name = "edge_\(edge.id)"
            addChild(line)
            edge.lineNode = line
        }

        // Create node circles and labels
        for (_, node) in graphNodes {
            let radius = nodeRadius(for: node)
            let color = GraphColorPalette.color(for: node.entityType)

            let circle = SKShapeNode(circleOfRadius: radius)
            circle.fillColor = color
            circle.strokeColor = color.withAlphaComponent(0.6)
            circle.lineWidth = 2.0
            circle.position = node.position
            circle.zPosition = 10
            circle.name = node.id

            // Glow effect
            circle.glowWidth = 2.0

            addChild(circle)
            node.spriteNode = circle

            // Label
            let label = SKLabelNode(text: truncatedLabel(node.label))
            label.fontSize = 10
            label.fontName = "Helvetica Neue"
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: -radius - 14)
            label.zPosition = 11
            circle.addChild(label)
            node.labelNode = label
        }
    }

    private func nodeRadius(for node: GraphNode) -> CGFloat {
        let baseRadius: CGFloat = 12.0
        let connectionBonus = min(CGFloat(node.connectionCount) * 2.0, 16.0)
        return baseRadius + connectionBonus
    }

    private func truncatedLabel(_ text: String) -> String {
        if text.count > 18 {
            return String(text.prefix(16)) + "..."
        }
        return text
    }

    // MARK: - Force-Directed Layout Simulation

    override func update(_ currentTime: TimeInterval) {
        guard isSimulationRunning else { return }

        let nodeArray = Array(graphNodes.values)
        guard nodeArray.count > 1 else {
            isSimulationRunning = false
            return
        }

        totalKineticEnergy = 0.0
        let centerX = size.width / 2
        let centerY = size.height / 2

        // Calculate forces
        for node in nodeArray {
            if node.isFixed { continue }

            var forceX: CGFloat = 0
            var forceY: CGFloat = 0

            // Repulsion from all other nodes
            for other in nodeArray where other.id != node.id {
                let dx = node.position.x - other.position.x
                let dy = node.position.y - other.position.y
                let distSq = max(dx * dx + dy * dy, 100)
                let dist = sqrt(distSq)
                let force = repulsionStrength / distSq
                forceX += force * (dx / dist)
                forceY += force * (dy / dist)
            }

            // Attraction along edges
            for edge in graphEdges {
                var other: GraphNode?
                if edge.source == node.id { other = graphNodes[edge.target] }
                else if edge.target == node.id { other = graphNodes[edge.source] }

                if let other = other {
                    let dx = other.position.x - node.position.x
                    let dy = other.position.y - node.position.y
                    let dist = sqrt(dx * dx + dy * dy)
                    let displacement = dist - idealEdgeLength
                    forceX += attractionStrength * displacement * (dx / max(dist, 1))
                    forceY += attractionStrength * displacement * (dy / max(dist, 1))
                }
            }

            // Centering force
            forceX += centeringStrength * (centerX - node.position.x)
            forceY += centeringStrength * (centerY - node.position.y)

            // Update velocity with damping
            node.velocity.x = (node.velocity.x + forceX) * dampingFactor
            node.velocity.y = (node.velocity.y + forceY) * dampingFactor

            // Clamp velocity
            let speed = sqrt(node.velocity.x * node.velocity.x + node.velocity.y * node.velocity.y)
            if speed > maxVelocity {
                let scale = maxVelocity / speed
                node.velocity.x *= scale
                node.velocity.y *= scale
            }

            totalKineticEnergy += speed * speed
        }

        // Apply velocities
        for node in nodeArray {
            if node.isFixed { continue }
            node.position.x += node.velocity.x
            node.position.y += node.velocity.y
        }

        // Update sprite positions
        updateSpritePositions()

        // Check stabilization
        iterationCount += 1
        let avgEnergy = totalKineticEnergy / CGFloat(nodeArray.count)
        if avgEnergy < stabilizationThreshold || iterationCount > 500 {
            isSimulationRunning = false
        }
    }

    private func updateSpritePositions() {
        for (_, node) in graphNodes {
            node.spriteNode?.position = node.position
        }

        for edge in graphEdges {
            guard let sourceNode = graphNodes[edge.source],
                  let targetNode = graphNodes[edge.target],
                  let lineNode = edge.lineNode else { continue }

            let path = CGMutablePath()
            path.move(to: sourceNode.position)
            path.addLine(to: targetNode.position)
            lineNode.path = path
        }
    }

    // MARK: - Mouse Interaction

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        lastMousePosition = location

        // Check if clicking on a node — use atPoint for hit testing
        let hitNode = atPoint(location)
        if let nodeId = hitNode.name, let graphNode = graphNodes[nodeId] {
            draggedNode = graphNode
            graphNode.isFixed = true
            selectNode(graphNode)
            return
        }
        // Check parent (label might be hit instead of circle)
        if let parent = hitNode.parent, let nodeId = parent.name, let graphNode = graphNodes[nodeId] {
            draggedNode = graphNode
            graphNode.isFixed = true
            selectNode(graphNode)
            return
        }

        // Clicked on background — deselect
        selectNode(nil)
    }

    override func mouseDragged(with event: NSEvent) {
        let location = event.location(in: self)

        if let draggedNode = draggedNode {
            // Drag the node
            draggedNode.position = location
            draggedNode.spriteNode?.position = location
            draggedNode.velocity = .zero
            updateSpritePositions()
        } else {
            // Pan the camera
            let dx = location.x - lastMousePosition.x
            let dy = location.y - lastMousePosition.y
            cameraNode.position.x -= dx * currentZoom
            cameraNode.position.y -= dy * currentZoom
        }

        lastMousePosition = location
    }

    override func mouseUp(with event: NSEvent) {
        if let node = draggedNode {
            node.isFixed = false
            // Briefly restart simulation to settle
            isSimulationRunning = true
            iterationCount = max(iterationCount - 50, 0)
        }
        draggedNode = nil
    }

    override func scrollWheel(with event: NSEvent) {
        let zoomDelta = event.deltaY * 0.02
        currentZoom = max(0.2, min(3.0, currentZoom + zoomDelta))
        cameraNode.setScale(currentZoom)
    }

    // MARK: - Node Selection

    func selectNode(_ node: GraphNode?) {
        // Reset previous selection
        if let prevId = selectedNodeId, let prevNode = graphNodes[prevId] {
            let color = GraphColorPalette.color(for: prevNode.entityType)
            prevNode.spriteNode?.strokeColor = color.withAlphaComponent(0.6)
            prevNode.spriteNode?.lineWidth = 2.0
            prevNode.spriteNode?.glowWidth = 2.0
        }

        // Reset highlighted edges
        for edge in graphEdges {
            edge.lineNode?.strokeColor = NSColor.white.withAlphaComponent(0.15)
            edge.lineNode?.lineWidth = 1.0
        }

        // Reset non-selected node opacity
        for (_, n) in graphNodes {
            n.spriteNode?.alpha = 1.0
            n.labelNode?.alpha = 1.0
        }

        if let node = node {
            selectedNodeId = node.id

            // Highlight selected node
            node.spriteNode?.strokeColor = .white
            node.spriteNode?.lineWidth = 3.0
            node.spriteNode?.glowWidth = 6.0

            // Find connected nodes
            var connectedIds: Set<String> = [node.id]
            for edge in graphEdges {
                if edge.source == node.id {
                    connectedIds.insert(edge.target)
                    edge.lineNode?.strokeColor = NSColor.white.withAlphaComponent(0.6)
                    edge.lineNode?.lineWidth = 2.0
                } else if edge.target == node.id {
                    connectedIds.insert(edge.source)
                    edge.lineNode?.strokeColor = NSColor.white.withAlphaComponent(0.6)
                    edge.lineNode?.lineWidth = 2.0
                }
            }

            // Dim non-connected nodes
            for (id, n) in graphNodes {
                if !connectedIds.contains(id) {
                    n.spriteNode?.alpha = 0.25
                    n.labelNode?.alpha = 0.25
                }
            }

            onNodeSelected?(node)
        } else {
            selectedNodeId = nil
            onNodeSelected?(nil)
        }
    }

    // MARK: - Path Highlighting

    func highlightPath(from sourceId: String, to targetId: String) {
        // BFS to find shortest path
        var queue: [(String, [String])] = [(sourceId, [sourceId])]
        var visited: Set<String> = [sourceId]

        // Build adjacency list
        var adjacency: [String: [(neighbor: String, edgeIndex: Int)]] = [:]
        for (index, edge) in graphEdges.enumerated() {
            adjacency[edge.source, default: []].append((edge.target, index))
            adjacency[edge.target, default: []].append((edge.source, index))
        }

        var foundPath: [String]?

        while !queue.isEmpty {
            let (current, path) = queue.removeFirst()

            if current == targetId {
                foundPath = path
                break
            }

            for (neighbor, _) in adjacency[current] ?? [] {
                if !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    queue.append((neighbor, path + [neighbor]))
                }
            }
        }

        // Reset all
        for (_, n) in graphNodes {
            n.spriteNode?.alpha = 0.2
            n.labelNode?.alpha = 0.2
        }
        for edge in graphEdges {
            edge.lineNode?.strokeColor = NSColor.white.withAlphaComponent(0.05)
            edge.lineNode?.lineWidth = 1.0
        }

        guard let path = foundPath else { return }

        // Highlight path nodes
        highlightedPath = Set(path)
        for nodeId in path {
            if let node = graphNodes[nodeId] {
                node.spriteNode?.alpha = 1.0
                node.labelNode?.alpha = 1.0
            }
        }

        // Highlight path edges
        for i in 0..<(path.count - 1) {
            let a = path[i]
            let b = path[i + 1]
            for edge in graphEdges {
                if (edge.source == a && edge.target == b) || (edge.source == b && edge.target == a) {
                    edge.lineNode?.strokeColor = NSColor(red: 0.95, green: 0.70, blue: 0.25, alpha: 0.9)
                    edge.lineNode?.lineWidth = 3.0
                }
            }
        }
    }

    func clearHighlight() {
        highlightedPath.removeAll()
        for (_, n) in graphNodes {
            n.spriteNode?.alpha = 1.0
            n.labelNode?.alpha = 1.0
        }
        for edge in graphEdges {
            edge.lineNode?.strokeColor = NSColor.white.withAlphaComponent(0.15)
            edge.lineNode?.lineWidth = 1.0
        }
    }

    // MARK: - Filtering

    func setVisibleTypes(_ types: Set<String>) {
        for (_, node) in graphNodes {
            let visible = types.contains(node.entityType)
            node.spriteNode?.isHidden = !visible
            node.labelNode?.isHidden = !visible
        }

        for edge in graphEdges {
            guard let sourceNode = graphNodes[edge.source],
                  let targetNode = graphNodes[edge.target] else { continue }
            let visible = types.contains(sourceNode.entityType) && types.contains(targetNode.entityType)
            edge.lineNode?.isHidden = !visible
        }
    }

    func showAllTypes() {
        for (_, node) in graphNodes {
            node.spriteNode?.isHidden = false
            node.labelNode?.isHidden = false
        }
        for edge in graphEdges {
            edge.lineNode?.isHidden = false
        }
    }

    // MARK: - Zoom to Fit

    func zoomToFit() {
        guard !graphNodes.isEmpty else { return }

        var minX: CGFloat = .infinity, maxX: CGFloat = -.infinity
        var minY: CGFloat = .infinity, maxY: CGFloat = -.infinity

        for (_, node) in graphNodes {
            minX = min(minX, node.position.x)
            maxX = max(maxX, node.position.x)
            minY = min(minY, node.position.y)
            maxY = max(maxY, node.position.y)
        }

        let graphWidth = maxX - minX + 100
        let graphHeight = maxY - minY + 100
        let scaleX = size.width / graphWidth
        let scaleY = size.height / graphHeight
        currentZoom = max(0.2, min(2.0, min(scaleX, scaleY)))

        cameraNode.position = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        cameraNode.setScale(currentZoom)
    }

    // MARK: - Restart Simulation

    func restartSimulation() {
        iterationCount = 0
        isSimulationRunning = true
        for (_, node) in graphNodes {
            node.velocity = CGPoint(
                x: CGFloat.random(in: -5...5),
                y: CGFloat.random(in: -5...5)
            )
        }
    }
}
