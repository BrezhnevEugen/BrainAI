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
            VStack(alignment: .leading, spacing: 0) {
                SynapseSidebarBrandHeader()

                List(selection: $selectedTab) {
                    ForEach(SidebarSection.allCases, id: \.self) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(Optional(section))
                            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                            .listRowBackground(sidebarRowBackground(isSelected: selectedTab == section))
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)

                Divider()
                    .background(SynapseColor.outlineVariant.opacity(0.15))

                sidebarProfileFooter
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
            .synapseStitchSidebar()
            .navigationSplitViewColumnWidth(min: 200, ideal: 256, max: 280)
        } detail: {
            Group {
                detailView
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if selectedTab != .dashboard && selectedTab != .settings {
                    SynapseMainTopBar(
                        placeholder: L10n.Chrome.archiveSearchPlaceholder,
                        onSearchCommit: { showSearchOverlay = true }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .synapseRootBackground()
        }
        .tint(SynapseColor.primary)
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

    private var sidebarProfileFooter: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(SynapseColor.outlineVariant.opacity(0.35), lineWidth: 1)
                    .background(Circle().fill(SynapseColor.surfaceContainerHigh))
                    .frame(width: 36, height: 36)
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(SynapseColor.onSurfaceVariant)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(BrainAIAppContentView.sidebarUserName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(SynapseColor.onSurface)
                    .lineLimit(1)
                Text(L10n.Sidebar.localInstance)
                    .font(.system(size: 10, weight: .medium, design: .default))
                    .foregroundStyle(SynapseColor.onSurfaceVariant.opacity(0.9))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private static var sidebarUserName: String {
        let full = NSFullUserName()
        if !full.isEmpty { return full }
        return ProcessInfo.processInfo.userName
    }

    @ViewBuilder
    private func sidebarRowBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SynapseColor.primaryContainer.opacity(0.22))
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
        } else {
            Color.clear
        }
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
            SynapseColor.surface.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    showSearchOverlay = false
                }

            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(SynapseColor.onSurfaceVariant)

                    TextField(L10n.Dashboard.quickSearchPlaceholder, text: .constant(""))
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .foregroundStyle(SynapseColor.onSurface)

                    Button {
                        showSearchOverlay = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(SynapseColor.onSurfaceVariant)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous)
                            .fill(.ultraThickMaterial)
                        RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous)
                            .fill(SynapseColor.surfaceContainer.opacity(0.45))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous)
                        .stroke(SynapseColor.outlineVariant.opacity(0.25), lineWidth: 1)
                )
                .frame(maxWidth: 500)
                .padding(.top, 100)

                Spacer()
            }
        }
    }
}
