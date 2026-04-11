import SwiftUI
import BrainAICore

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date
    var ragContext: String?
    var isStreaming: Bool = false
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

    // MARK: - Dependencies

    private let lightRAGClient: LocalLightRAGClient
    private let config: AppConfiguration

    // MARK: - Initialization

    init(
        lightRAGClient: LocalLightRAGClient = LocalLightRAGClient(),
        config: AppConfiguration = AppConfiguration.shared
    ) {
        self.lightRAGClient = lightRAGClient
        self.config = config
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

            // Messages area
            messagesArea

            Divider()

            // Input area
            inputArea
        }
        .navigationTitle("AI Chat")
    }

    // MARK: - Toolbar Area

    private var toolbarArea: some View {
        HStack(spacing: 16) {
            // Model picker
            HStack(spacing: 8) {
                Image(systemName: "brain")
                    .foregroundColor(.secondary)

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
            .background(.ultraThinMaterial)
            .cornerRadius(6)

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
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear chat history")
        }
        .padding(12)
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
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(message.content)
                        .lineLimit(nil)
                        .textSelection(.enabled)

                    // Context disclosure
                    if let context = message.ragContext, !context.isEmpty {
                        DisclosureGroup("RAG Context") {
                            Text(context)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(4)
                        }
                        .font(.caption)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)

                if message.role == .user {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            // Timestamp
            Text(message.timestamp.formatted(date: .omitted, time: .standard))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain.fill")
                .font(.system(size: 14))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: 8, height: 8)
                            .scaleEffect(animatingDot(index: index))
                    }

                    Text("Generating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
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
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .lineLimit(4)
                .font(.body)

            Button(action: { viewModel.sendMessage() }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isGenerating
                                    ? Color.gray.opacity(0.5)
                                    : Color.blue
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
