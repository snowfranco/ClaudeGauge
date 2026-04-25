import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Multi-Shadow Modifier

struct MultiShadow: ViewModifier {
    let shadows: [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)]

    func body(content: Content) -> some View {
        shadows.reduce(AnyView(content)) { view, s in
            AnyView(view.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y))
        }
    }
}

// MARK: - Theme System

/// Theme controls container styling only. Usage state colors (green/yellow/orange/red)
/// are always determined by UsageStore.gaugeColor — themes never override them.
struct ThemeConfig {
    let name: String

    // Compact pill
    let pillBackground: (_ accent: Color) -> AnyShapeStyle
    let pillCornerRadius: CGFloat
    let pillTextColor: (_ accent: Color) -> Color
    let pillDotColor: (_ accent: Color) -> Color
    let pillDotGlowColor: (_ accent: Color) -> Color
    let pillShadow: (_ accent: Color) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)
    let pillBorder: (_ accent: Color) -> (color: Color, width: CGFloat)?

    // Expanded card
    let cardBackground: (_ accent: Color) -> AnyShapeStyle
    let cardCornerRadius: CGFloat
    let cardBorder: (_ accent: Color) -> (color: Color, width: CGFloat)?
    let cardShadow: (_ accent: Color) -> [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)]
    let headerTextColor: Color
    let metadataTextColor: Color
    let progressTrackColor: Color
    let riskCardBackground: (_ riskColor: Color) -> AnyShapeStyle
    let badgeStyle: (_ accent: Color) -> (textColor: Color, bgColor: Color)

    static func named(_ name: String) -> ThemeConfig {
        switch name {
        case "newui": return .newUI
        default:      return .newUI
        }
    }
}

// MARK: - New UI Theme

extension ThemeConfig {

    /// Soft color tint for each usage state (New UI palette)
    static func softColor(for accent: Color) -> Color {
        // Map accent to its corresponding soft background
        if accent == Color(hex: "#22C55E") { return Color(hex: "#EAFBF1") }
        if accent == Color(hex: "#F5A400") { return Color(hex: "#FFF4D8") }
        if accent == Color(hex: "#F97316") { return Color(hex: "#FFE9D5") }
        if accent == Color(hex: "#EF4444") { return Color(hex: "#FFE4E6") }
        return Color(hex: "#EAFBF1")
    }

    static let newUI = ThemeConfig(
        name: "newui",

        // Pill: soft tinted background, accent text (high contrast)
        pillBackground: { accent in
            AnyShapeStyle(softColor(for: accent))
        },
        pillCornerRadius: 22,
        pillTextColor: { accent in accent },
        pillDotColor: { accent in accent },
        pillDotGlowColor: { accent in accent.opacity(0.3) },
        pillShadow: { accent in
            (color: accent.opacity(0.18), radius: 10, x: 0, y: 4)
        },
        pillBorder: { accent in
            (color: accent.opacity(0.2), width: 1)
        },

        // Expanded card: warm frosted glass with soft accent tint
        cardBackground: { accent in
            AnyShapeStyle(.ultraThinMaterial)
        },
        cardCornerRadius: 20,
        cardBorder: { accent in
            (color: accent.opacity(0.15), width: 1)
        },
        cardShadow: { accent in [
            (color: Color.black.opacity(0.12), radius: 20, x: 0, y: 8),
            (color: accent.opacity(0.08), radius: 24, x: 0, y: 0)
        ]},
        headerTextColor: .secondary,
        metadataTextColor: .secondary,
        progressTrackColor: Color.primary.opacity(0.08),
        riskCardBackground: { riskColor in
            AnyShapeStyle(riskColor.opacity(0.08))
        },
        badgeStyle: { accent in
            (textColor: accent, bgColor: accent.opacity(0.12))
        }
    )
}
