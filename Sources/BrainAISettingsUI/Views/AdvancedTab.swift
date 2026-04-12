import SwiftUI
import UniformTypeIdentifiers
import BrainAICore

// MARK: - AdvancedTab

struct AdvancedTab: View {
    @State private var config = AppConfiguration.shared
    @State private var debugLogging = false
    @State private var showResetConfirmation = false
    @State private var showExportPicker = false
    @State private var showImportPicker = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            // MARK: - Data Directories
            Section {
                PathRow(
                    label: "Workspaces Directory",
                    path: config.workspacesDirectory.path(percentEncoded: false)
                ) {
                    selectWorkspacesDirectory()
                }

                PathRow(
                    label: "Application Support",
                    path: URL.brainAIApplicationSupport.path(percentEncoded: false)
                ) {
                    NSWorkspace.shared.open(URL.brainAIApplicationSupport)
                }
            } header: {
                Label("Data Directories", systemImage: "folder")
            } footer: {
                Text("All workspace data, configurations, and graph storage are located in these directories.")
            }

            // MARK: - Python Environment
            Section {
                HStack {
                    Text("Python Path")
                    Spacer()
                    Text(pythonPath)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack {
                    Text("LightRAG Installation")
                    Spacer()
                    Text(lightRAGPath)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } header: {
                Label("Python Environment", systemImage: "terminal")
            }

            // MARK: - Debug
            Section {
                Toggle("Debug Logging", isOn: $debugLogging)
                    .help("Enables verbose logging to Console.app for troubleshooting")

                Button("Open Logs in Console") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
                }
            } header: {
                Label("Diagnostics", systemImage: "ladybug")
            }

            // MARK: - Export / Import
            Section {
                Button("Export All Data...") {
                    exportData()
                }

                Button("Import Data...") {
                    importData()
                }
            } header: {
                Label("Backup", systemImage: "arrow.down.doc")
            } footer: {
                Text("Export creates a compressed archive of all workspaces, configuration, and graph data. Import merges data into the current installation.")
            }

            // MARK: - Reset
            Section {
                Button("Reset All Settings to Defaults", role: .destructive) {
                    showResetConfirmation = true
                }
            } header: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            } footer: {
                Text("This only resets application settings. Your workspace data and knowledge graphs are not affected.")
            }

            // MARK: - Status
            if let message = statusMessage {
                Section {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(SynapseColor.surface)
        .navigationTitle(L10n.Settings.advanced)
        .confirmationDialog(
            "Reset Settings",
            isPresented: $showResetConfirmation
        ) {
            Button("Reset All Settings", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("Are you sure you want to reset all settings to their default values?")
        }
    }

    // MARK: - Computed Properties

    private var pythonPath: String {
        let paths = [
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/bin/python3",
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "Not found"
    }

    private var lightRAGPath: String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            homePath.appendingPathComponent(".local/bin/lightrag-server").path,
            "/usr/local/bin/lightrag-server",
            "/opt/homebrew/bin/lightrag-server",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "Not detected (will use uv run)"
    }

    // MARK: - Actions

    private func selectWorkspacesDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the directory for BrainAI workspaces"

        if panel.runModal() == .OK, let url = panel.url {
            config.workspacesDirectory = url
            statusMessage = "Workspaces directory updated to: \(url.path(percentEncoded: false))"
        }
    }

    private func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.archive]
        panel.nameFieldStringValue = "brainai-backup-\(dateStamp).tar.gz"
        panel.message = "Choose where to save the backup"

        if panel.runModal() == .OK, let _ = panel.url {
            statusMessage = "Export started... (not yet implemented)"
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.archive]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "Select a BrainAI backup to import"

        if panel.runModal() == .OK, let _ = panel.url {
            statusMessage = "Import started... (not yet implemented)"
        }
    }

    private func resetToDefaults() {
        // Clear UserDefaults for BrainAI keys
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier ?? "com.brainai.settings"
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
        statusMessage = "Settings reset to defaults. Restart the app for changes to take effect."
    }

    private var dateStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Path Row

struct PathRow: View {
    let label: String
    let path: String
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                action()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Open in Finder")
        }
    }
}
