import AppKit
import SwiftUI

struct ComponentsStepView: View {
    @Bindable var viewModel: InstallerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Select Components")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Choose which components to install. BrainAI Core is always included.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                componentRow(
                    icon: "app.badge.checkmark",
                    title: "BrainAI Core",
                    description: "Main application, tray agent, and settings",
                    size: "50 MB",
                    isOn: .constant(true),
                    isRequired: true
                )

                componentRow(
                    icon: "server.rack",
                    title: "LightRAG Server",
                    description: "Python-based knowledge graph engine with RAG support",
                    size: "~200 MB",
                    isOn: $viewModel.installLightRAG
                )

                componentRow(
                    icon: "cpu",
                    title: "Ollama Runtime",
                    description: "Local LLM inference engine for private AI processing",
                    size: "~150 MB",
                    isOn: $viewModel.installOllama,
                    detectedNote: viewModel.ollamaInstalled ? "Already installed" : nil
                )

                componentRow(
                    icon: "book",
                    title: "Sample Knowledge Base",
                    description: "Demo data to explore BrainAI features",
                    size: "~10 MB",
                    isOn: $viewModel.installSampleData
                )
            }

            Spacer()

            // Disk space estimate
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.secondary)
                Text("Estimated disk space required: ")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(viewModel.estimatedDiskSpace)
                    .font(.callout)
                    .fontWeight(.medium)
            }

            // Detected components
            if viewModel.pythonInstalled || viewModel.ollamaInstalled || viewModel.homebrewInstalled {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Detected on your system:")
                            .font(.caption)
                            .fontWeight(.medium)
                        HStack(spacing: 8) {
                            if viewModel.pythonInstalled { detectedBadge("Python 3") }
                            if viewModel.ollamaInstalled { detectedBadge("Ollama") }
                            if viewModel.homebrewInstalled { detectedBadge("Homebrew") }
                        }
                    }
                }
            }
        }
    }

    private func componentRow(
        icon: String,
        title: String,
        description: String,
        size: String,
        isOn: Binding<Bool>,
        isRequired: Bool = false,
        detectedNote: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: isOn)
                .toggleStyle(.checkbox)
                .disabled(isRequired)
                .labelsHidden()

            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.callout)
                        .fontWeight(.medium)
                    if isRequired {
                        Text("Required")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(4)
                    }
                    if let note = detectedNote {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(size)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
        .cornerRadius(8)
    }

    private func detectedBadge(_ name: String) -> some View {
        Text(name)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.green.opacity(0.15))
            .cornerRadius(4)
    }
}
