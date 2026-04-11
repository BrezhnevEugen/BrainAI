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

            Text(viewModel.allComponentsHealthy ? InstallerL10n.Complete.titleOk : InstallerL10n.Complete.titleWarn)
                .font(.title)
                .fontWeight(.bold)

            if viewModel.allComponentsHealthy {
                Text(InstallerL10n.Complete.bodyOk)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            } else {
                Text(InstallerL10n.Complete.bodyWarn)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Health status
            VStack(spacing: 8) {
                statusRow(icon: "app.badge.checkmark", title: InstallerL10n.Complete.coreLabel, healthy: true)
                statusRow(icon: "server.rack", title: InstallerL10n.Complete.lightragLabel, healthy: viewModel.allComponentsHealthy)
                if viewModel.installOllama || viewModel.ollamaInstalled {
                    statusRow(icon: "cpu", title: InstallerL10n.Complete.ollamaLabel, healthy: viewModel.ollamaInstalled || viewModel.allComponentsHealthy)
                }
            }
            .padding(16)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
            .cornerRadius(12)

            // Launch at login toggle
            Toggle(isOn: $viewModel.launchAtLogin) {
                Text(InstallerL10n.Complete.launchLogin)
                    .font(.callout)
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: 300)

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button(InstallerL10n.Nav.openSettings) {
                    NSWorkspace.shared.open(URL(string: "brainai://settings")!)
                }

                Button(InstallerL10n.Nav.openBrainAI) {
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
