import AppKit
import SwiftUI

struct ModelsStepView: View {
    @Bindable var viewModel: InstallerViewModel

    private var modelOptions: [(id: String, name: String, size: String, ramLabel: String, ramGB: UInt64, peakRamNote: String)] {
        [
            ("qwen2.5:7b", InstallerL10n.Models.qwen7b, InstallerL10n.Models.size45, InstallerL10n.Models.ram8, 8, InstallerL10n.Models.peakRam7b),
            ("qwen2.5:14b", InstallerL10n.Models.qwen14b, InstallerL10n.Models.size9, InstallerL10n.Models.ram16, 16, InstallerL10n.Models.peakRam14b),
            ("qwen2.5:32b", InstallerL10n.Models.qwen32b, InstallerL10n.Models.size20, InstallerL10n.Models.ram32, 32, InstallerL10n.Models.peakRam32b),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(InstallerL10n.Models.title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(InstallerL10n.Models.ramHint(gb: viewModel.systemRAM))
                .font(.callout)
                .foregroundStyle(.secondary)

            if viewModel.isScanningOllamaModels {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(InstallerL10n.Models.scanning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(InstallerL10n.Models.scanHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // LLM Model selection
            VStack(alignment: .leading, spacing: 8) {
                Text(InstallerL10n.Models.languageSection)
                    .font(.callout)
                    .fontWeight(.medium)

                ForEach(modelOptions, id: \.id) { model in
                    modelCard(model)
                }

                Text(InstallerL10n.Models.ramDisclaimer)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Embedding model (required)
            Toggle(isOn: $viewModel.installEmbeddingModel) {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.3x3")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("nomic-embed-text")
                                .font(.callout)
                                .fontWeight(.medium)
                            Text(InstallerL10n.Models.recommended)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(4)
                            if viewModel.isOllamaModelInstalled("nomic-embed-text") {
                                Text(InstallerL10n.Models.installed)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .cornerRadius(4)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(embeddingModelSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(InstallerL10n.Models.peakRamEmbed)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .toggleStyle(.checkbox)

            Spacer()

            installPreviewFooter
        }
        .task {
            await viewModel.scanInstalledOllamaModels()
        }
    }

    @ViewBuilder
    private var installPreviewFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.secondary)
                Text(InstallerL10n.Models.approxDownload)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(viewModel.estimatedDiskSpace)
                    .font(.callout)
                    .fontWeight(.medium)
            }

            Text(InstallerL10n.Models.appNote)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text(InstallerL10n.Models.plannedSteps)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if viewModel.plannedInstallStepSummaries.isEmpty {
                Text(InstallerL10n.Models.nothingToRun)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.plannedInstallStepSummaries) { step in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "terminal")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(width: 14, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(step.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.25))
                .cornerRadius(8)
            }
        }
    }

    private var embeddingModelSubtitle: String {
        if viewModel.isOllamaModelInstalled("nomic-embed-text") {
            return InstallerL10n.Models.embeddingSubInstalled
        }
        return InstallerL10n.Models.embeddingSubPending
    }

    private func modelCard(_ model: (id: String, name: String, size: String, ramLabel: String, ramGB: UInt64, peakRamNote: String)) -> some View {
        let isRecommended = model.id == viewModel.recommendedModel
        let hasEnoughRAM = viewModel.systemRAM >= model.ramGB
        let isInstalled = viewModel.isOllamaModelInstalled(model.id)

        return Button {
            viewModel.selectedLLMModel = model.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.selectedLLMModel == model.id ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(viewModel.selectedLLMModel == model.id ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.name)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        if isRecommended {
                            Text(InstallerL10n.Models.recommended)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .cornerRadius(4)
                        }
                        if isInstalled {
                            Text(InstallerL10n.Models.installed)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .cornerRadius(4)
                        }
                    }
                    HStack(spacing: 8) {
                        Text(isInstalled ? InstallerL10n.Models.noDownload : InstallerL10n.Models.sizeLine(model.size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !isInstalled {
                            Text(InstallerL10n.Models.requiresRAM(model.ramLabel))
                                .font(.caption)
                                .foregroundStyle(hasEnoughRAM ? Color.secondary : Color.red)
                        }
                    }
                    Text(model.peakRamNote)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if !hasEnoughRAM {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }
            .padding(10)
            .background(viewModel.selectedLLMModel == model.id ? Color.accentColor.opacity(0.08) : Color(nsColor: .quaternaryLabelColor).opacity(0.2))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(viewModel.selectedLLMModel == model.id ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
