import AppKit
import SwiftUI

struct ProviderStepView: View {
    @Bindable var viewModel: InstallerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AI Provider Setup")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Choose your primary AI provider. You can change this later in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(ProviderChoice.allCases) { provider in
                    providerCard(provider)
                }
            }

            // API key input if cloud provider selected
            if viewModel.selectedProvider == .openai {
                apiKeyField(
                    title: "OpenAI API Key",
                    placeholder: "sk-...",
                    text: $viewModel.openAIKey,
                    helpURL: "https://platform.openai.com/api-keys"
                )
            } else if viewModel.selectedProvider == .anthropic {
                apiKeyField(
                    title: "Anthropic API Key",
                    placeholder: "sk-ant-...",
                    text: $viewModel.anthropicKey,
                    helpURL: "https://console.anthropic.com/settings/keys"
                )
            }

            Spacer()
        }
    }

    private func providerCard(_ provider: ProviderChoice) -> some View {
        Button {
            viewModel.selectedProvider = provider
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconForProvider(provider))
                    .font(.title3)
                    .foregroundStyle(viewModel.selectedProvider == provider ? Color.accentColor : Color.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.rawValue)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(descriptionForProvider(provider))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.selectedProvider == provider {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .background(viewModel.selectedProvider == provider ? Color.accentColor.opacity(0.08) : Color(nsColor: .quaternaryLabelColor).opacity(0.2))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(viewModel.selectedProvider == provider ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func apiKeyField(title: String, placeholder: String, text: Binding<String>, helpURL: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                Spacer()
                Link("Get API Key", destination: URL(string: helpURL)!)
                    .font(.caption)
            }

            SecureField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)

            Text("Your API key is stored securely in the macOS Keychain.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
        .cornerRadius(8)
    }

    private func iconForProvider(_ provider: ProviderChoice) -> String {
        switch provider {
        case .ollama: "desktopcomputer"
        case .openai: "globe"
        case .anthropic: "globe"
        case .skip: "arrow.right.circle"
        }
    }

    private func descriptionForProvider(_ provider: ProviderChoice) -> String {
        switch provider {
        case .ollama: "Run AI models locally on your Mac. Private and offline."
        case .openai: "Use GPT-4 and other models via cloud API."
        case .anthropic: "Use Claude models via cloud API."
        case .skip: "Configure AI provider later in application settings."
        }
    }
}
