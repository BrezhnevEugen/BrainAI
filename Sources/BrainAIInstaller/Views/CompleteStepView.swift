import AppKit
import SwiftUI

struct CompleteStepView: View {
    @Bindable var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success icon
            Image(systemName: viewModel.allComponentsHealthy ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(viewModel.allComponentsHealthy ? .green : .yellow)

            Text(viewModel.allComponentsHealthy ? "Installation Complete" : "Installation Finished")
                .font(.title)
                .fontWeight(.bold)

            if viewModel.allComponentsHealthy {
                Text("All components are installed and running. BrainAI is ready to use.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            } else {
                Text("Installation completed, but some components may need attention.\nYou can configure them in Settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Health status
            VStack(spacing: 8) {
                statusRow(icon: "app.badge.checkmark", title: "BrainAI Core", healthy: true)
                statusRow(icon: "server.rack", title: "LightRAG Server", healthy: viewModel.allComponentsHealthy)
                if viewModel.installOllama || viewModel.ollamaInstalled {
                    statusRow(icon: "cpu", title: "Ollama", healthy: viewModel.ollamaInstalled || viewModel.allComponentsHealthy)
                }
            }
            .padding(16)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
            .cornerRadius(12)

            // Launch at login toggle
            Toggle(isOn: $viewModel.launchAtLogin) {
                Text("Launch BrainAI at login")
                    .font(.callout)
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: 300)

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: "brainai://settings")!)
                }

                Button("Open BrainAI") {
                    NSWorkspace.shared.open(URL(string: "brainai://open")!)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func statusRow(icon: String, title: String, healthy: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.callout)

            Spacer()

            Image(systemName: healthy ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(healthy ? .green : .red)
        }
    }
}
