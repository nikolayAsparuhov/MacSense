import SwiftUI

/// CleanMyMac-style elevated card. Soft material fill with a near-invisible
/// hairline border. On hover the card lifts gently and shows a faint glow
/// in the accent color — that subtle accent on hover is the
/// distinctive feel CleanMyMac uses to make rows feel interactive without
/// shouting at the user.
struct GlossyCard<Content: View>: View {
    var accent: LinearGradient = Theme.brandGradient
    var accentColor: Color = Theme.Palette.cyan
    @ViewBuilder var content: () -> Content

    @State private var isHovering = false

    var body: some View {
        content()
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                // Hairline border. Very subtle in resting state, brighter on
                // hover. Matches how CMM rows respond to mouse movement.
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(isHovering ? 0.10 : 0.04),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: accentColor.opacity(isHovering ? 0.18 : 0.0),
                radius: isHovering ? 22 : 0,
                x: 0, y: 0
            )
            .shadow(
                color: .black.opacity(isHovering ? 0.22 : 0.10),
                radius: isHovering ? 16 : 8,
                x: 0, y: isHovering ? 6 : 3
            )
            .scaleEffect(isHovering ? 1.005 : 1.0)
            .animation(AppAnimation.cardPress, value: isHovering)
            .onHover { hovering in isHovering = hovering }
    }
}
