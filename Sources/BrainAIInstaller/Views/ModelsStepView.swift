import AppKit
import SwiftUI

struct ModelsStepView: View {
    @Bindable var viewModel: InstallerViewModel

    private let modelOptions: [(id: String, name: String, size: String, ramReq: String)] = [
        ("qwen2.5:7b", "Qwen 2.5 7B", "~4.5 GB", "8 GB"),
        ("qwen2.5:14b", "Qwen 2.5 14B", "~9 GB", "16 GB"),
        ("qwen2.5:32b", "Qwen 2.5 32B", "~20 GB", "32 GB"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Model Selection")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Choose a language model based on your available RAM (\(viewModel.systemRAM) GB detected).")
                .font(.callout)
                .foregroundStyle(.secondary)

            // LLM Model selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Language Model")
                    .font(.callout)
                    .fontWeight(.medium)

                ForEach(modelOptions, id: \.id) { model in
                    modelCard(model)
                }
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
                            Text("Recommended")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(4)
                        }
                        Text("Embedding model for vector search (~300 MB)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .toggleStyle(.checkbox)

            Spacer()

            // Download size estimate
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.secondary)
                Text("Total download: ")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(viewModel.estimatedDiskSpace)
                    .font(.callout)
                    .fontWeight(.medium)
            }
        }
    }

    private func modelCard(_ model: (id: String, name: String, size: String, ramReq: String)) -> some View {
        let isRecommended = model.id == viewModel.recommendedModel
        let ramGB = UInt64(model.ramReq.replacingOccurrences(of: " GB", with: "")) ?? 0
        let hasEnoughRAM = viewModel.systemRAM >= ramGB

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
                            Text("Recommended")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .cornerRadius(4)
                        }
                    }
                    HStack(spacing: 8) {
                        Text("Size: \(model.size)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Requires: \(model.ramReq) RAM")
                            .font(.caption)
                            .foregroundStyle(hasEnoughRAM ? Color.secondary : Color.red)
                    }
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
