import SwiftUI
import BrainAICore

// MARK: - Note Model

struct Note: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String  // markdown content
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var isSynced: Bool  // whether inserted into knowledge base

    init(
        id: UUID = UUID(),
        title: String = "Untitled",
        content: String = "",
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
    }
}

// MARK: - Notes ViewModel

@Observable
final class NotesViewModel: @unchecked Sendable {
    // MARK: - State

    var notes: [Note] = []
    var selectedNoteID: UUID?
    var searchText: String = ""
    var isInserting: Bool = false
    var insertionError: String?

    // MARK: - Dependencies

    private let lightRAGClient: LocalLightRAGClient
    private let workspaceManager: WorkspaceManager

    // MARK: - Initialization

    init(
        lightRAGClient: LocalLightRAGClient = LocalLightRAGClient(),
        workspaceManager: WorkspaceManager = WorkspaceManager.shared
    ) {
        self.lightRAGClient = lightRAGClient
        self.workspaceManager = workspaceManager
    }

    // MARK: - Computed Properties

    var selectedNote: Note? {
        notes.first(where: { $0.id == selectedNoteID })
    }

    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return notes.sorted { $0.updatedAt > $1.updatedAt }
        }
        return notes
            .filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                    note.content.localizedCaseInsensitiveContains(searchText) ||
                    note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Public Methods

    func createNote() {
        let newNote = Note()
        notes.append(newNote)
        selectedNoteID = newNote.id
        saveNotes()
    }

    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
        if selectedNoteID == id {
            selectedNoteID = nil
        }
        saveNotes()
    }

    func updateNote(_ note: Note) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        var updatedNote = note
        updatedNote.updatedAt = Date()
        notes[index] = updatedNote
        saveNotes()
    }

    func insertToKnowledgeBase(note: Note) {
        guard !isInserting else { return }
        isInserting = true
        insertionError = nil

        Task {
            do {
                let response = try await lightRAGClient.insertText(
                    note.content,
                    description: note.title
                )

                do {
                    let wikiStore = await currentWikiStore()
                    try await wikiStore.createSourcePage(
                        title: note.title,
                        content: note.content,
                        sourceType: "note",
                        trackId: response.trackId
                    )
                    try await wikiStore.regenerateIndex()
                } catch {
                    await MainActor.run {
                        self.insertionError = "Inserted into knowledge base, but wiki page failed: \(error.localizedDescription)"
                    }
                }

                await MainActor.run {
                    var syncedNote = note
                    syncedNote.isSynced = true
                    self.updateNote(syncedNote)
                    self.isInserting = false
                }
            } catch {
                await MainActor.run {
                    self.insertionError = error.localizedDescription
                    self.isInserting = false
                }
            }
        }
    }

    private func currentWikiStore() async -> WikiPageStore {
        let workspace = await MainActor.run { workspaceManager.activeWorkspace }
        if let workspace {
            return WikiPageStore(workspaceURL: workspace.dataPath)
        }
        return WikiPageStore(workspaceSlug: "default")
    }

    // MARK: - File Persistence

    func loadNotes() {
        let fileURL = Self.notesFileURL()
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                notes = try decoder.decode([Note].self, from: data)
            }
        } catch {
            print("Error loading notes: \(error.localizedDescription)")
        }
    }

    func saveNotes() {
        let fileURL = Self.notesFileURL()
        do {
            // Ensure directory exists
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(notes)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Error saving notes: \(error.localizedDescription)")
        }
    }

    private static func notesFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let brainAIFolder = appSupport.appendingPathComponent("BrainAI")
        return brainAIFolder.appendingPathComponent("notes.json")
    }
}

// MARK: - Notes View

struct NotesView: View {
    @State private var viewModel: NotesViewModel

    init(workspaceManager: WorkspaceManager = WorkspaceManager.shared) {
        _viewModel = State(initialValue: NotesViewModel(workspaceManager: workspaceManager))
    }

    var body: some View {
        HSplitView {
            // Left pane: Notes list
            notesList
                .frame(minWidth: 250, maxWidth: 350)

            Divider()
                .background(SynapseColor.outlineVariant.opacity(0.25))

            // Right pane: Editor
            editorPane
        }
        .synapseRootBackground()
        .task {
            viewModel.loadNotes()
        }
        .navigationTitle(L10n.Nav.notes)
    }

    // MARK: - Left Pane: Notes List

    private var notesList: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(SynapseColor.onSurfaceVariant)

                TextField("Search notes...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(SynapseColor.onSurface)

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(SynapseColor.onSurfaceVariant)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(SynapseColor.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous)
                    .stroke(SynapseColor.outlineVariant.opacity(0.2), lineWidth: 1)
            )
            .padding(12)

            // New note button
            Button(action: { viewModel.createNote() }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("New Note")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .foregroundStyle(.white)
                .background(SynapseStyle.primaryCTAGradient, in: RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(12)

            Divider()
                .background(SynapseColor.outlineVariant.opacity(0.2))

            // Notes list
            List(selection: $viewModel.selectedNoteID) {
                ForEach(viewModel.filteredNotes) { note in
                    noteRow(note)
                        .tag(note.id)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteNote(id: note.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(SynapseColor.surfaceContainerLow)
    }

    // MARK: - Note Row

    @ViewBuilder
    private func noteRow(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                if note.isSynced {
                    Image(systemName: "checkmark.icloud.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(SynapseColor.primary)
                }
            }

            // Preview of content
            let preview = note.content.split(separator: "\n").first.map(String.init) ?? ""
            if !preview.isEmpty {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(SynapseColor.onSurfaceVariant)
                    .lineLimit(1)
            }

            // Date
            Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(SynapseColor.onSurfaceVariant)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Right Pane: Editor

    @ViewBuilder
    private var editorPane: some View {
        if let note = viewModel.selectedNote {
            editorContent(note)
        } else {
            emptyState
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundStyle(SynapseColor.onSurfaceVariant)

            Text("Select or create a note")
                .font(.title3)
                .foregroundStyle(SynapseColor.onSurface)

            Text("Create a new note to get started")
                .font(.caption)
                .foregroundStyle(SynapseColor.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .synapseRootBackground()
    }

    // MARK: - Editor Content

    @ViewBuilder
    private func editorContent(_ note: Note) -> some View {
        VStack(spacing: 12) {
            // Title field
            TextField("Untitled", text: Binding(
                get: { note.title },
                set: { newValue in
                    var updated = note
                    updated.title = newValue
                    viewModel.updateNote(updated)
                }
            ))
            .font(.system(size: 24, weight: .bold, design: .default))
            .lineLimit(2)
            .foregroundStyle(SynapseColor.onSurface)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Divider()
                .padding(.horizontal, 16)

            // Tags row
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(note.tags, id: \.self) { tag in
                            tagCapsule(tag, in: note)
                        }

                        addTagButton(for: note)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .frame(height: 32)

            Divider()
                .padding(.horizontal, 16)

            // Markdown editor
            TextEditor(text: Binding(
                get: { note.content },
                set: { newValue in
                    var updated = note
                    updated.content = newValue
                    viewModel.updateNote(updated)
                }
            ))
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(SynapseColor.surfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous)
                    .stroke(SynapseColor.outlineVariant.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 16)

            Divider()

            // Bottom toolbar
            HStack(spacing: 12) {
                // Word count
                Text("\(wordCount(note)) words")
                    .font(.caption)
                    .foregroundStyle(SynapseColor.onSurfaceVariant)

                Spacer()

                // Error message if present
                if let error = viewModel.insertionError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(SynapseColor.error)
                }

                // Synced indicator
                if note.isSynced {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Synced")
                            .font(.caption)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                        Text("Not synced")
                            .font(.caption)
                    }
                }

                // Last updated timestamp
                Text(note.updatedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(SynapseColor.onSurfaceVariant)

                Spacer()

                // Insert to Knowledge Base button
                Button(action: { viewModel.insertToKnowledgeBase(note: note) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                        Text("Insert to KB")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(SynapseColor.primaryContainer)
                .disabled(viewModel.isInserting || note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if viewModel.isInserting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(12)
        }
        .synapseRootBackground()
    }

    // MARK: - Tag Capsule

    @ViewBuilder
    private func tagCapsule(_ tag: String, in note: Note) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)

            Button(action: {
                var updated = note
                updated.tags.removeAll { $0 == tag }
                viewModel.updateNote(updated)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.2))
        .foregroundColor(.blue)
        .cornerRadius(12)
    }

    // MARK: - Add Tag Button

    @ViewBuilder
    private func addTagButton(for note: Note) -> some View {
        Menu {
            TextField("New tag", text: .constant(""))
                .onSubmit { }

            Divider()

            Button(action: { presentAddTagDialog(for: note) }) {
                Label("Add Tag", systemImage: "plus")
            }
        } label: {
            Image(systemName: "plus.circle")
                .font(.system(size: 14))
                .foregroundColor(.blue)
        }
        .menuStyle(.automatic)
    }

    // MARK: - Helper Methods

    private func wordCount(_ note: Note) -> Int {
        let words = note.content
            .split(separator: " ")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return words.count
    }

    private func presentAddTagDialog(for note: Note) {
        // This would typically be a modal or alert
        // For now, we'll use a simple approach with environment variable
        var updatedNote = note
        let newTag = "NewTag"
        if !updatedNote.tags.contains(newTag) {
            updatedNote.tags.append(newTag)
            viewModel.updateNote(updatedNote)
        }
    }
}

// MARK: - Preview

#Preview {
    NotesView()
}
