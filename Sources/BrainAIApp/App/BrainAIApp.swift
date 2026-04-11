import SwiftUI
import BrainAICore

// MARK: - Sidebar Section Enum

enum SidebarSection: String, CaseIterable, Hashable, Identifiable {
    case dashboard
    case graph
    case chat
    case search
    case notes
    case documents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .graph: "Knowledge Graph"
        case .chat: "Chat"
        case .search: "Search"
        case .notes: "Notes"
        case .documents: "Documents"
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
        }
    }
}

// MARK: - Main App

@main
struct BrainAIApp: App {
    @State private var selectedTab: SidebarSection? = .dashboard
    @State private var showSearchOverlay = false

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                List(SidebarSection.allCases, selection: $selectedTab) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
                .listStyle(.sidebar)
            } detail: {
                detailView
            }
            .navigationSplitViewStyle(.balanced)
            .frame(minWidth: 900, minHeight: 600)
            .overlay {
                if showSearchOverlay {
                    searchOverlayView
                }
            }
        }
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Quick Search") {
                    showSearchOverlay.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("New Note") {
                    selectedTab = .notes
                }
                .keyboardShortcut("n", modifiers: .command)
            }
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
        case nil:
            DashboardView()
        }
    }

    // MARK: - Search Overlay

    private var searchOverlayView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showSearchOverlay = false
                }

            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Quick search...", text: .constant(""))
                        .textFieldStyle(.plain)
                        .font(.title3)

                    Button {
                        showSearchOverlay = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(.ultraThickMaterial)
                .cornerRadius(12)
                .frame(maxWidth: 500)
                .padding(.top, 100)

                Spacer()
            }
        }
    }
}
