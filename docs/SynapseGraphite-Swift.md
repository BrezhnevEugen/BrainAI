# Synapse Graphite → SwiftUI (BrainAI)

Design reference from **Google Stitch** project *BrainAI macOS — Neural Knowledge UI 2026* (`projects/14499223815463841914`). Use this when aligning native UI with the **Synapse Graphite** system.

## Principles

- **Surfaces:** layer with `surface` → `surface_container_low` (sidebar) → `surface_container` / `_high` / `_highest` (cards). Avoid harsh dividers; separate with tone + spacing.
- **Ghost border:** `outline_variant` (#424753) at ~20% opacity, 1pt, when a boundary must exist.
- **Primary CTA:** gradient feel from `primary_container` (#528DFF) toward `secondary` (#D0BCFF); corner radius **12** for cards and primary buttons.
- **Grid:** **8pt**; secondary text uses `on_surface_variant` (#C2C6D6).
- **Graph nodes (SpriteKit / overlays):** soft glow blue→violet, optional pulse on “active”, type-colored ring; fill references `secondary_container` / `tertiary` from tokens.

## Core color tokens (hex)

| Token | Hex | Typical use |
|--------|-----|-------------|
| `surface` | `#131319` | Window / main background |
| `surface_container_low` | `#1b1b21` | Sidebar, large panels |
| `surface_container` | `#1f1f25` | Raised panels |
| `surface_container_high` | `#2a2930` | Cards, inputs |
| `surface_container_highest` | `#34343b` | Emphasized cards, chips |
| `surface_container_lowest` | `#0e0e14` | Inset fields |
| `surface_variant` | `#34343b` | Glass fill (often with opacity) |
| `on_surface` | `#e4e1ea` | Primary text |
| `on_surface_variant` | `#c2c6d6` | Secondary text |
| `primary` | `#afc6ff` | Accent text, links |
| `primary_container` | `#528dff` | Buttons, strong accent |
| `secondary` | `#d0bcff` | Gradient partner, secondary accent |
| `tertiary` | `#7bd1fa` | Graph / status highlights |
| `outline_variant` | `#424753` | Ghost borders |
| `error` | `#ffb4ab` | Errors (dark-tuned) |

## SwiftUI example

```swift
import SwiftUI

enum SynapseColor {
    static let surface = Color(red: 0.075, green: 0.075, blue: 0.098)           // #131319
    static let surfaceSidebar = Color(red: 0.106, green: 0.106, blue: 0.129)       // #1b1b21
    static let surfaceCard = Color(red: 0.165, green: 0.165, blue: 0.188)          // #2a2930
    static let onSurface = Color(red: 0.894, green: 0.882, blue: 0.918)             // #e4e1ea
    static let onSurfaceVariant = Color(red: 0.761, green: 0.776, blue: 0.839)   // #c2c6d6
    static let primaryContainer = Color(red: 0.322, green: 0.553, blue: 1.0)       // #528dff
    static let secondaryAccent = Color(red: 0.816, green: 0.737, blue: 1.0)      // #d0bcff
}

// Card
struct SynapseCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(16)
            .background(SynapseColor.surfaceCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
```

On macOS, prefer `.ultraThinMaterial` / `Material` for toolbar overlays and combine with a low-opacity `surface_variant` tint to approximate Stitch **glass** (blur ~20pt in spec).

## Typography

- **Headlines / titles:** system rounded or custom **Manrope** if bundled; Stitch uses Manrope for display.
- **Labels / dense UI:** **Inter** or `.caption` / `.footnote` with `on_surface_variant`.

## Stitch artifacts

- Open the project in **Stitch** to view screens, HTML export, and screenshots.
- Refined frames: **Knowledge Graph Refined**, **Dashboard Refined** (session `1445610683883325567`).

## Next steps in product

- Apply tokens to `BrainAIApp` sidebar + `DashboardView` backgrounds before custom graph shaders.
- Settings app: reuse the same `SynapseColor` (or move tokens into `BrainAICore` as a small `DesignTokens` enum).
