import AppKit
import SwiftUI

struct ComponentsStepView: View {
    @Bindable var viewModel: InstallerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(InstallerL10n.Components.title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(InstallerL10n.Components.subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                componentRow(
                    icon: "app.badge.checkmark",
                    title: InstallerL10n.Components.coreTitle,
                    description: InstallerL10n.Components.coreDesc,
                    size: InstallerL10n.Components.sizeCore,
                    isOn: .constant(true),
                    isRequired: true
                )

                componentRow(
                    icon: "server.rack",
                    title: InstallerL10n.Components.lightragTitle,
                    description: InstallerL10n.Components.lightragDesc,
                    size: InstallerL10n.Components.sizeLightrag,
                    isOn: $viewModel.installLightRAG
                )

                componentRow(
                    icon: "cpu",
                    title: InstallerL10n.Components.ollamaTitle,
                    description: InstallerL10n.Components.ollamaDesc,
                    size: InstallerL10n.Components.sizeOllama,
                    isOn: $viewModel.installOllama,
                    detectedNote: viewModel.ollamaInstalled ? InstallerL10n.Components.ollamaInstalled : nil
                )

                componentRow(
                    icon: "book",
                    title: InstallerL10n.Components.sampleTitle,
                    description: InstallerL10n.Components.sampleDesc,
                    size: InstallerL10n.Components.sizeSample,
                    isOn: $viewModel.installSampleData
                )
            }

            Spacer()

            // Disk space estimate
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.secondary)
                Text(InstallerL10n.Components.estimatedPrefix + " ")
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
                        Text(InstallerL10n.Components.detectedLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                        HStack(spacing: 8) {
                            if viewModel.pythonInstalled { detectedBadge(InstallerL10n.Components.badgePython) }
                            if viewModel.ollamaInstalled { detectedBadge(InstallerL10n.Components.badgeOllama) }
                            if viewModel.homebrewInstalled { detectedBadge(InstallerL10n.Components.badgeHomebrew) }
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
                        Text(InstallerL10n.Components.required)
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
