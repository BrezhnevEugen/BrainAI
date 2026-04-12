import AppKit
import SwiftUI
import Observation
import BrainAICore
import BrainAISettingsUI

// MARK: - Sidebar Section Enum

enum SidebarSection: String, CaseIterable, Hashable, Identifiable {
    case dashboard
    case graph
    case chat
    case search
    case notes
    case documents
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: L10n.Nav.dashboard
        case .graph: L10n.Nav.graph
        case .chat: L10n.Nav.chat
        case .search: L10n.Nav.search
        case .notes: L10n.Nav.notes
        case .documents: L10n.Nav.documents
        case .settings: L10n.Nav.settings
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "house"
        case .graph: "point.3.connected.trianglepath.dotted"
        case .chat: "bubble.left.and.bubble.right"
        case .search: "magnifyingglass"
        case .notes: "note.text"
        case .documents: "doc.on.doc"
        case .settings: "gearshape"
        }
    }
}

// MARK: - Root view (hosted in NSWindow for SPM executable)

struct BrainAIAppContentView: View {
    @Bindable private var config = AppConfiguration.shared
    @State private var selectedTab: SidebarSection? = .dashboard
    @State private var settingsSectionTab: SettingsTab = .general
    @State private var showSearchOverlay = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(SidebarSection.allCases, id: \.self) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(Optional(section))
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(config.theme.swiftUIColorScheme)
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .overlay {
            if showSearchOverlay {
                searchOverlayView
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .brainAIQuickSearch)) { _ in
            showSearchOverlay.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .brainAINewNote)) { _ in
            selectedTab = .notes
        }
        .onReceive(NotificationCenter.default.publisher(for: .brainAIOpenGraph)) { _ in
            selectedTab = .graph
        }
        .onReceive(NotificationCenter.default.publisher(for: .brainAINewChat)) { _ in
            selectedTab = .chat
        }
        .onReceive(NotificationCenter.default.publisher(for: .brainAIOpenSearch)) { _ in
            showSearchOverlay = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .brainAIOpenDocuments)) { _ in
            selectedTab = .documents
        }
        .onReceive(NotificationCenter.default.publisher(for: .brainAIOpenSettings)) { _ in
            selectedTab = .settings
        }
        .id(config.language)
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView()
        case .graph:
            KnowledgeGraphView()
        case .chat:
            ChatView()
        case .search:
            SearchView()
        case .notes:
            NotesView()
        case .documents:
            DocumentsView()
        case .settings:
            SettingsContentView(selectedTab: $settingsSectionTab)
        case nil:
            DashboardView()
        }
    }

    // MARK: - Search Overlay

    private var searchOverlayView: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { showSearchOverlay = false }

            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField(L10n.Dashboard.quickSearchPlaceholder, text: .constant(""))
                        .textFieldStyle(.plain)
                        .font(.title3)

                    Button { showSearchOverlay = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
                .frame(maxWidth: 480)
                .padding(.top, 80)

                Spacer()
            }
        }
    }
}
