import SwiftUI
import Observation

// MARK: - Accessibility Helpers

/// Standard accessibility identifiers for UI testing and VoiceOver
public enum AccessibilityID {

    // MARK: - Sidebar
    public static let sidebarDashboard = "sidebar.dashboard"
    public static let sidebarChat = "sidebar.chat"
    public static let sidebarDocuments = "sidebar.documents"
    public static let sidebarSearch = "sidebar.search"
    public static let sidebarNotes = "sidebar.notes"
    public static let sidebarGraph = "sidebar.graph"

    // MARK: - Chat
    public static let chatInput = "chat.input"
    public static let chatSendButton = "chat.send"
    public static let chatMessageList = "chat.messages"
    public static let chatModeSelector = "chat.mode"

    // MARK: - Documents
    public static let documentsList = "documents.list"
    public static let documentsAddButton = "documents.add"
    public static let documentsSearchField = "documents.search"

    // MARK: - Graph
    public static let graphCanvas = "graph.canvas"
    public static let graphFilterButton = "graph.filter"
    public static let graphPathFinder = "graph.pathfinder"
    public static let graphZoomFit = "graph.zoomfit"
    public static let graphRelayout = "graph.relayout"
    public static let graphReload = "graph.reload"
    public static let graphSearchField = "graph.search"
    public static let graphDetailsSidebar = "graph.details"

    // MARK: - Settings
    public static let settingsGeneralTab = "settings.general"
    public static let settingsProvidersTab = "settings.providers"
    public static let settingsServerTab = "settings.server"
    public static let settingsModelsTab = "settings.models"
    public static let settingsWorkspacesTab = "settings.workspaces"
    public static let settingsAdvancedTab = "settings.advanced"
}

// MARK: - View Extensions for Accessibility

public extension View {

    /// Add standard VoiceOver label and hint
    @ViewBuilder
    func brainAIAccessible(
        label: String,
        hint: String? = nil,
        identifier: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        let base = self
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier ?? "")
            .accessibilityAddTraits(traits)

        if let hint {
            base.accessibilityHint(hint)
        } else {
            base
        }
    }

    /// Mark as a header for VoiceOver navigation
    func brainAIHeader(_ label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isHeader)
    }

    /// Status indicator accessible to VoiceOver
    func brainAIStatus(_ status: String, isActive: Bool) -> some View {
        self
            .accessibilityLabel("\(status): \(isActive ? L10n.Tray.running : L10n.Tray.stopped)")
            .accessibilityValue(isActive ? "active" : "inactive")
    }

    /// Keyboard shortcut with accessibility hint
    func brainAIShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command, hint: String) -> some View {
        self
            .keyboardShortcut(key, modifiers: modifiers)
            .accessibilityHint(hint)
    }
}

// MARK: - Focus Management

/// Observable focus state for keyboard navigation in main app
@Observable
public final class FocusManager: @unchecked Sendable {

    public enum FocusTarget: Hashable, Sendable {
        case sidebar
        case chatInput
        case searchField
        case graphCanvas
        case documentList
        case noteEditor
    }

    public var currentFocus: FocusTarget? {
        get { lock.lock(); defer { lock.unlock() }; return _currentFocus }
        set { lock.lock(); _currentFocus = newValue; lock.unlock() }
    }

    private var _currentFocus: FocusTarget?
    private let lock = NSLock()

    public init() {}

    public func focus(_ target: FocusTarget) {
        currentFocus = target
    }

    public func clearFocus() {
        currentFocus = nil
    }
}
