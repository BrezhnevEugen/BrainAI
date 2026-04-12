import SwiftUI
import BrainAICore

/// Stitch **TopNavBar**: global search strip, decorative actions, glass-tint background.
struct SynapseMainTopBar: View {
    let placeholder: String
    var onSearchCommit: () -> Void

    @State private var query = ""

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SynapseColor.onSurfaceVariant)

                TextField(placeholder, text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(SynapseColor.onSurface)
                    .onSubmit { onSearchCommit() }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: 420, alignment: .leading)
            .background(SynapseColor.surfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(SynapseColor.outlineVariant.opacity(0.2), lineWidth: 1)
            )

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                topBarIconButton("bell")
                topBarIconButton("square.grid.2x2")
                topBarIconButton("person.crop.circle")
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 48)
        .synapseToolbarStrip()
    }

    private func topBarIconButton(_ systemName: String) -> some View {
        Button(action: {}) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(SynapseColor.onSurfaceVariant)
                .frame(width: 36, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
