import SwiftUI
import BrainAICore

// MARK: - Settings App Entry Point

@main
struct SettingsApp: App {
    @State private var selectedTab: SettingsTab = .general

    var body: some Scene {
        WindowGroup {
            SettingsContentView(selectedTab: $selectedTab)
                .frame(minWidth: 720, minHeight: 480)
                .frame(idealWidth: 800, idealHeight: 560)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 560)
    }
}

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case providers
    case server
    case models
    case workspaces
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .providers: return "Providers"
        case .server: return "Server"
        case .models: return "Models"
        case .workspaces: return "Workspaces"
        case .advanced: return "Advanced"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .providers: return "cpu"
        case .server: return "server.rack"
        case .models: return "brain"
        case .workspaces: return "square.stack.3d.up"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - Settings Content View

struct SettingsContentView: View {
    @Binding var selectedTab: SettingsTab

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    GeneralTab()
                case .providers:
                    ProvidersTab()
                case .server:
                    ServerTab()
                case .models:
                    ModelsTab()
                case .workspaces:
                    WorkspacesTab()
                case .advanced:
                    AdvancedTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
