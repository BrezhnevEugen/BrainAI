import SwiftUI
import BrainAICore

// MARK: - Settings Tab

public enum SettingsTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case general
    case providers
    case server
    case models
    case workspaces
    case advanced

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: return L10n.Settings.general
        case .providers: return L10n.Settings.providers
        case .server: return L10n.Settings.server
        case .models: return L10n.Settings.models
        case .workspaces: return L10n.Settings.workspaces
        case .advanced: return L10n.Settings.advanced
        }
    }

    public var icon: String {
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

// MARK: - Settings root (HSplitView: safe inside main-window NavigationSplitView)

public struct SettingsContentView: View {
    @Binding var selectedTab: SettingsTab
    @Bindable private var config = AppConfiguration.shared

    public init(selectedTab: Binding<SettingsTab>) {
        _selectedTab = selectedTab
    }

    public var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                SynapseSidebarBrandHeader(horizontalPadding: 16)

                List(selection: $selectedTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.icon)
                            .tag(tab)
                            .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                            .listRowBackground(settingsSidebarRowBackground(isSelected: selectedTab == tab))
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .synapseStitchSidebar()
            .frame(minWidth: 200, idealWidth: 240, maxWidth: 280)

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
            .synapseRootBackground()
        }
        .tint(SynapseColor.primary)
        .preferredColorScheme(config.theme.swiftUIColorScheme)
    }

    @ViewBuilder
    private func settingsSidebarRowBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SynapseColor.primaryContainer.opacity(0.22))
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
        } else {
            Color.clear
        }
    }
}
