import AppKit
import SwiftUI

struct WelcomeStepView: View {
    @Bindable var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo / Icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text("Welcome to BrainAI")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your personal knowledge base with AI augmentation.\nThis wizard will guide you through the installation process.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            // What will be installed
            VStack(alignment: .leading, spacing: 8) {
                installItem(icon: "server.rack", title: "LightRAG Server", description: "Knowledge graph engine with vector search")
                installItem(icon: "cpu", title: "Ollama", description: "Local LLM runtime for private AI")
                installItem(icon: "brain", title: "Language Models", description: "AI models for chat and embeddings")
            }
            .padding(20)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
            .cornerRadius(12)

            // System info
            HStack(spacing: 16) {
                Label("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)", systemImage: "desktopcomputer")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("\(viewModel.systemRAM) GB RAM", systemImage: "memorychip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func installItem(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
