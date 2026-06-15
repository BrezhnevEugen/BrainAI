import SwiftUI
import BrainAICore

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date
    var prompt: String?
    var ragContext: String?
    var isStreaming: Bool = false
    var savedWikiPath: String?
}

// MARK: - Chat ViewModel

@Observable
final class ChatViewModel: @unchecked Sendable {
    // MARK: - State

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isGenerating: Bool = false
    var selectedMode: SearchMode = .hybrid
    var selectedModel: String = ""
    var ragContext: String?
    var memoryStatusMessage: String?

    // MARK: - Dependencies

    private let lightRAGClient: LocalLightRAGClient
    private let config: AppConfiguration
    private let workspaceManager: WorkspaceManager

    // MARK: - Initialization

    init(
        lightRAGClient: LocalLightRAGClient = LocalLightRAGClient(),
        config: AppConfiguration = AppConfiguration.shared,
        workspaceManager: WorkspaceManager = WorkspaceManager.shared
    ) {
        self.lightRAGClient = lightRAGClient
        self.config = config
        self.workspaceManager = workspaceManager
        self.selectedModel = config.generationRole.modelID
    }

    // MARK: - Message Sending

    /// Send a message and get AI response
    func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespaces)
        guard !userMessage.isEmpty else { return }
        guard !isGenerating else { return }

        // Add user message
        let newUserMessage = ChatMessage(
            role: .user,
            content: userMessage,
            timestamp: Date()
        )
        messages.append(newUserMessage)
        inputText = ""
        isGenerating = true

        // Send in background
        Task {
            await performGeneration(userMessage: userMessage)
        }
    }

    /// Perform the generation with RAG context retrieval
    private func performGeneration(userMessage: String) async {
        do {
            // Step 1: Query LightRAG for context
            let queryResponse = try await lightRAGClient.query(
                userMessage,
                mode: selectedMode,
                topK: 10,
                onlyNeedContext: true
            )

            let contextText = queryResponse.response
            await MainActor.run {
                self.ragContext = contextText
            }

            // Step 2: Build prompt with context
            let prompt = buildPrompt(userMessage: userMessage, context: contextText)

            // Step 3: Generate response
            let baseURL = buildOllamaURL()
            let ollama = OllamaLLMProvider(ollamaAPI: OllamaAPIClient(baseURL: baseURL))
            let options = GenerateOptions(temperature: 0.7, maxTokens: 2048)

            let response = try await ollama.generate(
                prompt: prompt,
                model: selectedModel,
                options: options
            )

            // Step 4: Add assistant message
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: response,
                timestamp: Date(),
                prompt: userMessage,
                ragContext: contextText
            )

            await MainActor.run {
                self.messages.append(assistantMessage)
                self.isGenerating = false
            }
        } catch {
            // Add error message
            let errorMessage = ChatMessage(
                role: .assistant,
                content: "Error: \(error.localizedDescription)",
                timestamp: Date()
            )

            await MainActor.run {
                self.messages.append(errorMessage)
                self.isGenerating = false
            }
        }
    }

    /// Build the full prompt with RAG context
    private func buildPrompt(userMessage: String, context: String) -> String {
        if context.isEmpty {
            return userMessage
        }

        return """
        Use the following context to answer the question:

        Context:
        \(context)

        Question:
        \(userMessage)

        Answer:
        """
    }

    /// Build Ollama base URL
    private func buildOllamaURL() -> String {
        if let remoteURL = config.remoteOllamaURL {
            return remoteURL.absoluteString
        }
        return "http://localhost:\(config.ollamaPort)"
    }

    /// Clear all messages
    func clearChat() {
        messages.removeAll()
        inputText = ""
        ragContext = nil
        memoryStatusMessage = nil
    }

    func saveToWiki(_ message: ChatMessage) {
        guard message.role == .assistant, message.savedWikiPath == nil else { return }

        Task {
            do {
                let store = await currentWikiStore()
                let title = synthesisTitle(for: message)
                let page = try await store.createSynthesisPage(
                    title: title,
                    question: message.prompt ?? "Saved chat answer",
                    answer: message.content,
                    ragContext: message.ragContext,
                    model: selectedModel,
                    searchMode: selectedMode
                )
                try await store.regenerateIndex()

                await MainActor.run {
                    if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                        self.messages[index].savedWikiPath = page.path
                    }
                    self.memoryStatusMessage = "Saved to Wiki review queue: \(page.path)"
                }
            } catch {
                await MainActor.run {
                    self.memoryStatusMessage = "Failed to save Wiki synthesis: \(error.localizedDescription)"
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

    private func synthesisTitle(for message: ChatMessage) -> String {
        let prompt = message.prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = prompt.isEmpty ? message.content : prompt
        let firstLine = base.components(separatedBy: .newlines).first ?? "Chat Synthesis"
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? "Chat Synthesis" : trimmed).prefix(80))
    }
}

// MARK: - Chat View

struct ChatView: View {
    @State private var viewModel = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarArea

            Divider()
                .background(SynapseColor.outlineVariant.opacity(0.25))

            // Messages area
            messagesArea

            if let status = viewModel.memoryStatusMessage {
                memoryStatus(status)
            }

            Divider()
                .background(SynapseColor.outlineVariant.opacity(0.25))

            // Input area
            inputArea
        }
        .synapseRootBackground()
        .navigationTitle(L10n.Nav.chat)
    }

    // MARK: - Toolbar Area

    private var toolbarArea: some View {
        HStack(spacing: 16) {
            // Model picker
            HStack(spacing: 8) {
                Image(systemName: "brain")
                    .foregroundStyle(SynapseColor.onSurfaceVariant)

                Menu {
                    ForEach([
                        "mistral",
                        "neural-chat",
                        "orca-mini",
                        "zephyr",
                        "dolphin-mixtral"
                    ], id: \.self) { model in
                        Button(model) {
                            viewModel.selectedModel = model
                        }
                    }
                } label: {
                    Text(viewModel.selectedModel.isEmpty ? "Select Model" : viewModel.selectedModel)
                        .lineLimit(1)
                        .font(.caption)
                }
                .menuStyle(.automatic)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .synapseCardSurface(cornerRadius: 8)

            // Search mode picker
            Picker("Search Mode", selection: $viewModel.selectedMode) {
                Text("Local").tag(SearchMode.local)
                Text("Global").tag(SearchMode.global)
                Text("Hybrid").tag(SearchMode.hybrid)
                Text("Naive").tag(SearchMode.naive)
                Text("Mix").tag(SearchMode.mix)
            }
            .pickerStyle(.segmented)
            .font(.caption)

            Spacer()

            // Clear chat button
            Button(action: { viewModel.clearChat() }) {
                Image(systemName: "trash")
                    .foregroundStyle(SynapseColor.onSurfaceVariant)
            }
            .buttonStyle(.plain)
            .help("Clear chat history")
        }
        .padding(12)
        .synapseToolbarStrip()
    }

    // MARK: - Messages Area

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }

                    // Loading indicator
                    if viewModel.isGenerating {
                        typingIndicator
                            .id("loading")
                    }
                }
                .padding(12)
            }
            .onChange(of: viewModel.messages.count) {
                // Scroll to latest message
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isGenerating) {
                // Scroll to loading indicator
                if viewModel.isGenerating {
                    withAnimation {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Message Row

    @ViewBuilder
    private func messageRow(_ message: ChatMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            // Message bubble
            HStack(spacing: 8) {
                if message.role == .assistant {
                    Image(systemName: "brain.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(SynapseColor.primary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(message.content)
                        .lineLimit(nil)
                        .textSelection(.enabled)
                        .foregroundStyle(SynapseColor.onSurface)

                    // Context disclosure
                    if let context = message.ragContext, !context.isEmpty {
                        DisclosureGroup("RAG Context") {
                            Text(context)
                                .font(.caption)
                                .foregroundStyle(SynapseColor.onSurfaceVariant)
                                .textSelection(.enabled)
                                .padding(8)
                                .background(SynapseColor.surfaceContainerLowest)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .font(.caption)
                    }

                    if message.role == .assistant {
                        HStack(spacing: 8) {
                            Button {
                                viewModel.saveToWiki(message)
                            } label: {
                                Label(
                                    message.savedWikiPath == nil ? "Save to Wiki" : "Saved",
                                    systemImage: message.savedWikiPath == nil ? "book.pages" : "checkmark.circle"
                                )
                            }
                            .buttonStyle(.borderless)
                            .disabled(message.savedWikiPath != nil)
                            .help("Save answer to Wiki review queue")

                            if let savedWikiPath = message.savedWikiPath {
                                Text(savedWikiPath)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(SynapseColor.onSurfaceVariant)
                                    .lineLimit(1)
                            }
                        }
                        .font(.caption)
                    }
                }
                .padding(12)
                .background(
                    message.role == .user
                        ? AnyShapeStyle(SynapseColor.surfaceContainerHighest)
                        : AnyShapeStyle(SynapseColor.surfaceContainerHigh)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous)
                        .stroke(SynapseColor.outlineVariant.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous))

                if message.role == .user {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(SynapseColor.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            // Timestamp
            Text(message.timestamp.formatted(date: .omitted, time: .standard))
                .font(.caption2)
                .foregroundStyle(SynapseColor.onSurfaceVariant)
                .padding(.horizontal, 4)
        }
    }

    private func memoryStatus(_ status: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: status.hasPrefix("Failed") ? "exclamationmark.triangle" : "checkmark.circle")
                .foregroundStyle(status.hasPrefix("Failed") ? .orange : SynapseColor.primary)

            Text(status)
                .font(.caption)
                .foregroundStyle(SynapseColor.onSurfaceVariant)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(SynapseColor.surfaceContainerLow)
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain.fill")
                .font(.system(size: 14))
                .foregroundStyle(SynapseColor.primary)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(SynapseColor.primaryContainer.opacity(0.75))
                            .frame(width: 8, height: 8)
                            .scaleEffect(animatingDot(index: index))
                    }

                    Text("Generating...")
                        .font(.caption)
                        .foregroundStyle(SynapseColor.onSurfaceVariant)
                }
            }
            .padding(12)
            .synapseCardSurface(cornerRadius: SynapseLayout.cardCornerRadius)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func animatingDot(index: Int) -> CGFloat {
        return 1.0  // Static for now, animation could be added with state
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: 12) {
            TextEditor(text: $viewModel.inputText)
                .frame(minHeight: 40, maxHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(SynapseColor.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous)
                        .stroke(SynapseColor.outlineVariant.opacity(0.2), lineWidth: 1)
                )
                .lineLimit(4)
                .font(.body)
                .foregroundStyle(SynapseColor.onSurface)

            Button(action: { viewModel.sendMessage() }) {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: SynapseLayout.cardCornerRadius, style: .continuous)
                            .fill(
                                viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isGenerating
                                    ? AnyShapeStyle(SynapseColor.outlineVariant.opacity(0.45))
                                    : AnyShapeStyle(SynapseStyle.primaryCTAGradient)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(
                viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isGenerating
            )
            .keyboardShortcut(.return, modifiers: .command)
            .help("Send message (Cmd+Return)")
        }
        .padding(12)
    }
}

// MARK: - Preview

#Preview {
    ChatView()
}
