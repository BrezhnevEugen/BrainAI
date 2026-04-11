import SwiftUI
import BrainAICore
import ServiceManagement

// MARK: - GeneralTab

struct GeneralTab: View {
    @State private var config = AppConfiguration.shared
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            // MARK: - Appearance
            Section {
                Picker("Language", selection: $config.language) {
                    Text("System").tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.en)
                    Text("Russian").tag(AppLanguage.ru)
                    Text("Ukrainian").tag(AppLanguage.uk)
                }

                Picker("Theme", selection: $config.theme) {
                    Text("System").tag(AppTheme.system)
                    Text("Light").tag(AppTheme.light)
                    Text("Dark").tag(AppTheme.dark)
                }
            } header: {
                Text("Appearance")
            }

            // MARK: - Startup
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                Picker("Auto-start services", selection: $config.workspaceStartPolicy) {
                    Text("Always").tag(WorkspaceStartPolicy.always)
                    Text("On Demand").tag(WorkspaceStartPolicy.onDemand)
                    Text("Manual").tag(WorkspaceStartPolicy.manual)
                }
                .help("Controls whether services start automatically when the app launches")
            } header: {
                Text("Startup")
            }

            // MARK: - Updates
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }

                Button("Check for Updates...") {
                    // Sparkle integration placeholder
                }
            } header: {
                Text("Updates")
            }

            // MARK: - Knowledge Graph
            Section {
                HStack {
                    Text("Chunk Size")
                    Spacer()
                    TextField("", value: $config.chunkSize, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("tokens")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Chunk Overlap")
                    Spacer()
                    TextField("", value: $config.chunkOverlap, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("tokens")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Knowledge Graph")
            } footer: {
                Text("These settings affect how documents are split before processing. Changes apply to new documents only.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .onAppear {
            loadLaunchAtLoginState()
        }
    }

    // MARK: - Private

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func loadLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = !enabled // revert on failure
            }
        }
    }
}
