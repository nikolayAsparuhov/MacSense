import SwiftUI

/// Centralized design tokens for MacSense's glossy aesthetic.
///
/// The visual language mixes:
///   - Vibrant diagonal gradients on hero/section accents.
///   - Soft elevated cards with subtle inner-glow edges.
///   - Smooth spring animations on every state transition.
///
/// All numeric values live here so re-theming touches one file.
enum Theme {
    enum Palette {
        // Midnight Aurora — bright, tech-forward. Cyan + azure primaries
        // against a deep navy backdrop. The originally-shipped CMM-style
        // theme.
        //
        // Palette names kept stable across themes so call sites don't
        // churn — only the hex values change.
        static let cyan      = Color(red: 0.00, green: 0.78, blue: 1.00) // #00C7FF
        static let azure     = Color(red: 0.20, green: 0.45, blue: 1.00) // #3373FF
        static let indigo    = Color(red: 0.36, green: 0.32, blue: 0.95) // #5C52F2
        static let violet    = Color(red: 0.62, green: 0.32, blue: 0.95) // #9F51F2
        static let coral     = Color(red: 1.00, green: 0.42, blue: 0.42) // #FF6B6B
        static let amber     = Color(red: 1.00, green: 0.74, blue: 0.30) // #FFBC4D
        static let mint      = Color(red: 0.18, green: 0.88, blue: 0.66) // #2EE0A8
        static let sky       = Color(red: 0.30, green: 0.62, blue: 1.00) // #4D9DFF

        // Section gradient extras — kept for theme compatibility.
        static let teal      = Color(red: 0.18, green: 0.88, blue: 0.66) // mint dup
        static let copper    = Color(red: 1.00, green: 0.42, blue: 0.42) // coral dup
        static let olive     = Color(red: 0.18, green: 0.88, blue: 0.66) // mint dup
        static let mauve     = Color(red: 0.62, green: 0.32, blue: 0.95) // violet dup

        // Surface tones — deep navy.
        static let surfaceDeep = Color(red: 0.05, green: 0.06, blue: 0.10) // #0D0F1A
        static let surface     = Color(red: 0.09, green: 0.10, blue: 0.14) // #171924
        static let surfaceHi   = Color(red: 0.13, green: 0.14, blue: 0.20) // #212432
    }

    /// Brand gradient — cyan to azure. Primary CTA and active-state.
    static let brandGradient = LinearGradient(
        colors: [Palette.cyan, Palette.azure],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Per-section accent. Each section has its own gradient family so the
    /// sidebar pill, hero icon, and status dot all share a personality.
    static func sectionGradient(for section: AppSection) -> LinearGradient {
        switch section {
        case .cleanup:
            return LinearGradient(colors: [Palette.cyan, Palette.indigo],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .performance:
            return LinearGradient(colors: [Palette.azure, Palette.violet],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .applications:
            return LinearGradient(colors: [Palette.violet, Palette.coral],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .storage:
            return LinearGradient(colors: [Palette.mint, Palette.cyan],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// Solid accent color per section — used for status dots and chrome
    /// where a single tone reads better than a gradient.
    static func accent(for section: AppSection) -> Color {
        switch section {
        case .cleanup:      return Palette.cyan
        case .performance:  return Palette.azure
        case .applications: return Palette.violet
        case .storage:      return Palette.mint
        }
    }

    /// Card surface — soft material that sits over the window background
    /// without overpowering the gradient hero behind it.
    static let cardMaterial: Material = .regularMaterial

    static let cardCornerRadius: CGFloat = 14
    static let heroCornerRadius: CGFloat = 22

    /// Standard inner padding for card content.
    static let cardPadding: CGFloat = 16
    /// Tighter padding for dense metric tiles (Performance grid).
    static let compactCardPadding: CGFloat = 14

    /// Stack spacing between sibling cards within a section.
    static let sectionSpacing: CGFloat = 16
    /// Tight spacing between dense metric tiles.
    static let compactSpacing: CGFloat = 12
}

/// Reusable glossy gradient text style — applies the brand gradient as a
/// foreground over the text, matching CleanMyMac's hero typography.
struct GradientText: ViewModifier {
    let gradient: LinearGradient
    func body(content: Content) -> some View {
        content
            .foregroundStyle(gradient)
    }
}

extension View {
    func gradientText(_ gradient: LinearGradient = Theme.brandGradient) -> some View {
        modifier(GradientText(gradient: gradient))
    }
}
