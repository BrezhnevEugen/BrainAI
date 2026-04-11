import SwiftUI
import BrainAICore

// MARK: - WorkspacesTab

struct WorkspacesTab: View {
    @State private var workspaceManager = WorkspaceManager()
    @State private var selectedWorkspaceID: UUID?
    @State private var showCreateSheet = false
    @State private var showDeleteConfirmation = false
    @State private var workspaceToDelete: Workspace?

    var body: some View {
        HSplitView {
            // MARK: - Workspace List
            VStack(spacing: 0) {
                List(workspaceManager.workspaces, selection: $selectedWorkspaceID) { workspace in
                    WorkspaceListRow(workspace: workspace)
                        .tag(workspace.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                workspaceToDelete = workspace
                                showDeleteConfirmation = true
                            }
                        }
                }
                .listStyle(.sidebar)

                Divider()

                HStack {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("New Workspace", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)

                    Spacer()
                }
                .padding(8)
            }
            .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)

            // MARK: - Workspace Detail
            if let id = selectedWorkspaceID,
               let workspace = workspaceManager.workspaces.first(where: { $0.id == id }) {
                WorkspaceDetailView(workspace: workspace, manager: workspaceManager)
            } else {
                ContentUnavailableView {
                    Label("No Workspace Selected", systemImage: "square.stack.3d.up")
                } description: {
                    Text("Select a workspace from the list or create a new one.")
                }
            }
        }
        .navigationTitle("Workspaces")
        .sheet(isPresented: $showCreateSheet) {
            CreateWorkspaceSheet(manager: workspaceManager, isPresented: $showCreateSheet)
        }
        .confirmationDialog(
            "Delete Workspace",
            isPresented: $showDeleteConfirmation,
            presenting: workspaceToDelete
        ) { workspace in
            Button("Delete \"\(workspace.name)\"", role: .destructive) {
                Task {
                    try? await workspaceManager.delete(id: workspace.id)
                    if selectedWorkspaceID == workspace.id {
                        selectedWorkspaceID = nil
                    }
                }
            }
        } message: { workspace in
            Text("All data in \"\(workspace.name)\" will be permanently deleted. This cannot be undone.")
        }
    }
}

// MARK: - Workspace List Row

struct WorkspaceListRow: View {
    let workspace: Workspace

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: workspace.icon)
                .foregroundStyle(Color(hex: workspace.color) ?? .gray)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name)
                    .font(.body)
                    .lineLimit(1)

                Text("\(workspace.entityCount) entities")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Workspace Detail View

struct WorkspaceDetailView: View {
    let workspace: Workspace
    let manager: WorkspaceManager

    var body: some View {
        Form {
            // Info
            Section {
                LabeledContent("Name") {
                    Text(workspace.name)
                }
                LabeledContent("Slug") {
                    Text(workspace.slug)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Port") {
                    Text("\(workspace.port)")
                        .fontDesign(.monospaced)
                }
                if let description = workspace.description {
                    LabeledContent("Description") {
                        Text(description)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Information")
            }

            // Start Policy
            Section {
                HStack {
                    Text("Start Policy")
                    Spacer()
                    Text(workspace.startPolicy.rawValue.capitalized)
                        .foregroundStyle(.secondary)
                }

                Toggle("Encrypted", isOn: .constant(workspace.isEncrypted))
                    .disabled(true)
            } header: {
                Text("Configuration")
            }

            // Provider Role Overrides
            Section {
                if let embedding = workspace.embeddingRole {
                    LabeledContent("Embedding") {
                        Text("\(embedding.providerID) / \(embedding.modelID)")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    LabeledContent("Embedding") {
                        Text("Global default")
                            .foregroundStyle(.tertiary)
                    }
                }

                if let extraction = workspace.extractionRole {
                    LabeledContent("Extraction") {
                        Text("\(extraction.providerID) / \(extraction.modelID)")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    LabeledContent("Extraction") {
                        Text("Global default")
                            .foregroundStyle(.tertiary)
                    }
                }

                if let generation = workspace.generationRole {
                    LabeledContent("Generation") {
                        Text("\(generation.providerID) / \(generation.modelID)")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    LabeledContent("Generation") {
                        Text("Global default")
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("Provider Roles")
            } footer: {
                Text("Override global provider settings for this workspace. \"Global default\" means the app-level configuration is used.")
            }

            // Statistics
            Section {
                LabeledContent("Entities") {
                    Text("\(workspace.entityCount)")
                }
                LabeledContent("Relations") {
                    Text("\(workspace.relationCount)")
                }
                LabeledContent("Documents") {
                    Text("\(workspace.documentCount)")
                }
                LabeledContent("Last Activity") {
                    Text(workspace.lastActivity, style: .relative)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Statistics")
            }

            // Actions
            Section {
                HStack {
                    Spacer()
                    Button("Start") {
                        Task { try? await manager.start(id: workspace.id) }
                    }
                    Button("Stop") {
                        Task { try? await manager.stop(id: workspace.id) }
                    }
                }

                HStack {
                    Spacer()
                    Button("Export...") {
                        // Export placeholder
                    }
                    Button("Import...") {
                        // Import placeholder
                    }
                }
            } header: {
                Text("Actions")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Create Workspace Sheet

struct CreateWorkspaceSheet: View {
    let manager: WorkspaceManager
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var slug: String = ""
    @State private var autoSlug: Bool = true
    @State private var icon: String = "folder.fill"
    @State private var color: String = "#6B7280"
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("New Workspace")
                .font(.title2)

            Form {
                TextField("Name", text: $name)
                    .onChange(of: name) { _, newValue in
                        if autoSlug {
                            slug = newValue
                                .lowercased()
                                .replacingOccurrences(of: " ", with: "-")
                                .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                        }
                    }

                TextField("Slug", text: $slug)
                    .fontDesign(.monospaced)
                    .onChange(of: slug) { _, _ in
                        autoSlug = false
                    }

                TextField("SF Symbol", text: $icon)
                    .fontDesign(.monospaced)
            }
            .formStyle(.grouped)

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createWorkspace()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || slug.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func createWorkspace() {
        Task {
            do {
                _ = try await manager.create(name: name, slug: slug)
                isPresented = false
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
