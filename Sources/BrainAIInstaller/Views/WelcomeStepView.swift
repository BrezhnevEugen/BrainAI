import AppKit
import SwiftUI

struct WelcomeStepView: View {
    @Bindable var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Avoid Spacer() here: in a fixed-height installer window it steals space and can
            // squeeze the shared navigation bar (Continue) out of view.
            // Logo / Icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text(InstallerL10n.Welcome.title)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(InstallerL10n.Welcome.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            // What will be installed
            VStack(alignment: .leading, spacing: 8) {
                installItem(icon: "server.rack", title: InstallerL10n.Welcome.itemLightRAGTitle, description: InstallerL10n.Welcome.itemLightRAGDesc)
                installItem(icon: "cpu", title: InstallerL10n.Welcome.itemOllamaTitle, description: InstallerL10n.Welcome.itemOllamaDesc)
                installItem(icon: "brain", title: InstallerL10n.Welcome.itemModelsTitle, description: InstallerL10n.Welcome.itemModelsDesc)
            }
            .padding(20)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
            .cornerRadius(12)

            // System info
            HStack(spacing: 16) {
                Label(InstallerL10n.Welcome.macOSVersion(ProcessInfo.processInfo.operatingSystemVersionString), systemImage: "desktopcomputer")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(InstallerL10n.Welcome.ramGB(viewModel.systemRAM), systemImage: "memorychip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
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
