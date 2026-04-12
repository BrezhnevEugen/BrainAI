import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Colors (Synapse Graphite / Stitch reference)

/// Design tokens aligned with **Synapse Graphite** (Stitch *BrainAI macOS — Neural Knowledge UI 2026*).
public enum SynapseColor {
    public static let surface = Color(red: 19 / 255, green: 19 / 255, blue: 25 / 255)
    public static let surfaceContainerLow = Color(red: 27 / 255, green: 27 / 255, blue: 33 / 255)
    public static let surfaceContainer = Color(red: 31 / 255, green: 31 / 255, blue: 37 / 255)
    public static let surfaceContainerHigh = Color(red: 42 / 255, green: 41 / 255, blue: 48 / 255)
    public static let surfaceContainerHighest = Color(red: 52 / 255, green: 52 / 255, blue: 59 / 255)
    public static let surfaceContainerLowest = Color(red: 14 / 255, green: 14 / 255, blue: 20 / 255)
    public static let surfaceVariant = Color(red: 52 / 255, green: 52 / 255, blue: 59 / 255)

    public static let onSurface = Color(red: 228 / 255, green: 225 / 255, blue: 234 / 255)
    public static let onSurfaceVariant = Color(red: 194 / 255, green: 198 / 255, blue: 214 / 255)

    public static let primary = Color(red: 175 / 255, green: 198 / 255, blue: 255 / 255)
    public static let primaryContainer = Color(red: 82 / 255, green: 141 / 255, blue: 255 / 255)
    public static let secondary = Color(red: 208 / 255, green: 188 / 255, blue: 255 / 255)
    public static let tertiary = Color(red: 123 / 255, green: 209 / 255, blue: 250 / 255)

    public static let outlineVariant = Color(red: 66 / 255, green: 71 / 255, blue: 83 / 255)
    public static let error = Color(red: 255 / 255, green: 180 / 255, blue: 171 / 255)

    /// Text on primary CTA / gradient (Stitch `on-primary-fixed` `#001a43`).
    public static let onPrimaryFixed = Color(red: 0, green: 26 / 255, blue: 67 / 255)
    public static let secondaryContainer = Color(red: 87 / 255, green: 27 / 255, blue: 193 / 255)

    /// Stitch sidebar row highlight tint (`#4F8CFF` at ~10% fill).
    public static let sidebarSelectionFill = Color(red: 79 / 255, green: 140 / 255, blue: 255 / 255)

    #if canImport(AppKit)
    /// Matches `surface` for SpriteKit / AppKit scenes.
    public static var graphBackgroundNSColor: NSColor {
        NSColor(red: 19 / 255, green: 19 / 255, blue: 25 / 255, alpha: 1)
    }
    #endif
}

// MARK: - Layout

public enum SynapseLayout {
    public static let cardCornerRadius: CGFloat = 12
    public static let grid: CGFloat = 8
}

// MARK: - Gradients

public enum SynapseStyle {
    /// Stitch `.synapse-gradient`: 135° from `#528DFF` → `#D0BCFF`.
    public static var primaryCTAGradient: LinearGradient {
        LinearGradient(
            colors: [SynapseColor.primaryContainer, SynapseColor.secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Typography (Stitch: Manrope display / Inter labels → system rounded + default)

public enum SynapseTypography {
    public static func pageTitle() -> Font {
        .system(size: 28, weight: .heavy, design: .rounded)
    }

    public static func brandTitle() -> Font {
        .system(size: 17, weight: .bold, design: .rounded)
    }

    public static func brandTagline() -> Font {
        .system(size: 10, weight: .semibold, design: .default)
    }

    public static func metricValue() -> Font {
        .system(size: 22, weight: .bold, design: .rounded)
    }

    public static func labelUppercase() -> Font {
        .system(size: 10, weight: .medium, design: .default)
    }
}

extension AppTheme {
    /// For `preferredColorScheme` in SwiftUI roots.
    public var swiftUIColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - View modifiers

public struct SynapseToolbarStripModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Rectangle().fill(SynapseColor.surfaceVariant.opacity(0.22))
                }
            }
    }
}

extension View {
    /// Main window / detail column background (`#131319`).
    public func synapseRootBackground() -> some View {
        background(SynapseColor.surface)
    }

    /// Sidebar column (`surface_container_low`).
    public func synapseSidebarChrome() -> some View {
        background(SynapseColor.surfaceContainerLow)
    }

    /// Stitch aside: `bg-surface/80` + `backdrop-blur-xl` + trailing hairline.
    public func synapseStitchSidebar() -> some View {
        background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(SynapseColor.surface.opacity(0.45))
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(SynapseColor.outlineVariant.opacity(0.2))
                .frame(width: 1)
        }
    }

    /// Stitch `.glass-panel`: `surface-variant` @ 60% + heavy blur.
    public func synapseGlassPanel(cornerRadius: CGFloat = SynapseLayout.cardCornerRadius) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(SynapseColor.surfaceVariant.opacity(0.6))
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
    }

    /// Dashboard metric tile: `surface_container_low` + ghost border (Stitch bento).
    public func synapseMetricCard(cornerRadius: CGFloat = SynapseLayout.cardCornerRadius) -> some View {
        background(
            SynapseColor.surfaceContainerLow,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(SynapseColor.outlineVariant.opacity(0.2), lineWidth: 1)
        )
    }

    /// Card: raised surface + ghost border (1pt ~20% outline).
    public func synapseCardSurface(cornerRadius: CGFloat = SynapseLayout.cardCornerRadius) -> some View {
        background(
            SynapseColor.surfaceContainerHigh,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(SynapseColor.outlineVariant.opacity(0.2), lineWidth: 1)
        )
    }

    /// Toolbar / header strip: material + Synapse tint.
    public func synapseToolbarStrip() -> some View {
        modifier(SynapseToolbarStripModifier())
    }
}

// MARK: - Stitch sidebar brand (shared main + settings)

public struct SynapseSidebarBrandHeader: View {
    private let horizontalPadding: CGFloat

    public init(horizontalPadding: CGFloat = 24) {
        self.horizontalPadding = horizontalPadding
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(SynapseStyle.primaryCTAGradient)
                    .frame(width: 32, height: 32)
                Image(systemName: "network")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SynapseColor.onPrimaryFixed)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Common.appName)
                    .font(SynapseTypography.brandTitle())
                    .foregroundStyle(SynapseColor.onSurface)
                Text(L10n.Common.brandTagline)
                    .font(SynapseTypography.brandTagline())
                    .foregroundStyle(SynapseColor.onSurfaceVariant)
                    .tracking(1)
                    .textCase(.uppercase)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}
