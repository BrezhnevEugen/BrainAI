import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Colors (native macOS semantic)

/// Design tokens using macOS system-semantic colors.
/// Follows the user's Light / Dark appearance automatically.
public enum SynapseColor {
    // MARK: Surfaces — follow system window / control backgrounds
    public static let surface = Color(nsColor: .windowBackgroundColor)
    public static let surfaceContainerLow = Color(nsColor: .controlBackgroundColor)
    public static let surfaceContainer = Color(nsColor: .underPageBackgroundColor)
    public static let surfaceContainerHigh = Color(nsColor: .controlBackgroundColor)
    public static let surfaceContainerHighest = Color(nsColor: .textBackgroundColor)
    public static let surfaceContainerLowest = Color(nsColor: .windowBackgroundColor)
    public static let surfaceVariant = Color.secondary.opacity(0.08)

    // MARK: Text
    public static let onSurface = Color.primary
    public static let onSurfaceVariant = Color.secondary

    // MARK: Accent
    public static let primary = Color.accentColor
    public static let primaryContainer = Color.accentColor
    public static let secondary = Color.purple
    public static let tertiary = Color.teal

    // MARK: Borders & errors
    public static let outlineVariant = Color(nsColor: .separatorColor)
    public static let error = Color.red

    public static let onPrimaryFixed = Color.white
    public static let secondaryContainer = Color.purple.opacity(0.15)

    public static let sidebarSelectionFill = Color.accentColor

    #if canImport(AppKit)
    public static var graphBackgroundNSColor: NSColor {
        .windowBackgroundColor
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
    /// Accent gradient for CTA buttons.
    public static var primaryCTAGradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
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
            .background(.bar)
    }
}

extension View {
    /// Main window / detail column background.
    public func synapseRootBackground() -> some View {
        background(Color(nsColor: .windowBackgroundColor))
    }

    /// Sidebar column.
    public func synapseSidebarChrome() -> some View {
        background(.clear)
    }

    /// Sidebar background — transparent to let system vibrancy show.
    public func synapseStitchSidebar() -> some View {
        background(.clear)
    }

    /// Glass panel with subtle material.
    public func synapseGlassPanel(cornerRadius: CGFloat = SynapseLayout.cardCornerRadius) -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Metric card — grouped inset style.
    public func synapseMetricCard(cornerRadius: CGFloat = SynapseLayout.cardCornerRadius) -> some View {
        background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }

    /// Card: raised surface.
    public func synapseCardSurface(cornerRadius: CGFloat = SynapseLayout.cardCornerRadius) -> some View {
        background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }

    /// Toolbar / header strip.
    public func synapseToolbarStrip() -> some View {
        modifier(SynapseToolbarStripModifier())
    }
}

// MARK: - Stitch sidebar brand (shared main + settings)

public struct SynapseSidebarBrandHeader: View {
    private let horizontalPadding: CGFloat

    public init(horizontalPadding: CGFloat = 16) {
        self.horizontalPadding = horizontalPadding
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.Common.appName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(L10n.Common.brandTagline)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}
