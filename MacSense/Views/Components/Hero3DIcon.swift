import SwiftUI

/// CleanMyMac-style 3D-look icon. Approximates their rendered PNG art with
/// pure SwiftUI: gradient-filled rounded rect/octagon backing, gradient
/// SF symbol overlay, specular highlight in the upper-left, soft accent
/// glow. Same component renders at 26pt for the sidebar and 220pt for
/// section heroes — pass whatever size you need.
struct Hero3DIcon: View {
    let symbol: String
    let colors: [Color]
    var shape: IconShape = .roundedRect
    var size: CGFloat = 220
    var symbolScale: CGFloat = 0.45     // symbol size relative to backing
    var glowOpacity: Double = 0.55
    var showHighlight: Bool = true

    enum IconShape { case roundedRect, octagon, capsule }

    var body: some View {
        ZStack {
            backing
                .frame(width: size, height: size)
                .shadow(color: colors.first?.opacity(glowOpacity) ?? .clear,
                        radius: size * 0.18, x: 0, y: size * 0.08)

            Image(systemName: symbol)
                .font(.system(size: size * symbolScale, weight: .bold))
                .foregroundStyle(LinearGradient(
                    colors: [.white, .white.opacity(0.85)],
                    startPoint: .top, endPoint: .bottom
                ))
                .shadow(color: .white.opacity(0.4), radius: size * 0.04)

            if showHighlight {
                Ellipse()
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.55), .clear],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: size * 0.55, height: size * 0.18)
                    .offset(x: -size * 0.05, y: -size * 0.32)
                    .blendMode(.plusLighter)
                    .blur(radius: size * 0.02)
            }
        }
    }

    @ViewBuilder
    private var backing: some View {
        let gradient = LinearGradient(
            colors: colors,
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        let strokeGradient = LinearGradient(
            colors: [.white.opacity(0.30), .white.opacity(0.05)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        switch shape {
        case .roundedRect:
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                        .strokeBorder(strokeGradient, lineWidth: size * 0.008)
                )
        case .octagon:
            Octagon()
                .fill(gradient)
                .overlay(Octagon().stroke(strokeGradient, lineWidth: size * 0.008))
        case .capsule:
            Capsule()
                .fill(gradient)
                .overlay(Capsule().strokeBorder(strokeGradient, lineWidth: size * 0.008))
        }
    }
}

/// Regular octagon path. Used by Protection-style hero icons.
struct Octagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let off = w * 0.30   // diagonal cut depth
        var p = Path()
        p.move(to: CGPoint(x: off, y: 0))
        p.addLine(to: CGPoint(x: w - off, y: 0))
        p.addLine(to: CGPoint(x: w, y: off))
        p.addLine(to: CGPoint(x: w, y: h - off))
        p.addLine(to: CGPoint(x: w - off, y: h))
        p.addLine(to: CGPoint(x: off, y: h))
        p.addLine(to: CGPoint(x: 0, y: h - off))
        p.addLine(to: CGPoint(x: 0, y: off))
        p.closeSubpath()
        return p
    }
}

// MARK: - Per-section presets

extension Hero3DIcon {
    static func forSection(_ section: AppSection, size: CGFloat = 220) -> Hero3DIcon {
        switch section {
        case .cleanup:
            return Hero3DIcon(symbol: "bubbles.and.sparkles.fill",
                              colors: [Theme.Palette.cyan, Theme.Palette.azure],
                              shape: .roundedRect, size: size, symbolScale: 0.50)
        case .performance:
            return Hero3DIcon(symbol: "bolt.fill",
                              colors: [Theme.Palette.azure, Theme.Palette.violet],
                              shape: .octagon, size: size)
        case .applications:
            return Hero3DIcon(symbol: "square.grid.2x2.fill",
                              colors: [Theme.Palette.violet, Theme.Palette.coral],
                              shape: .roundedRect, size: size)
        case .storage:
            return Hero3DIcon(symbol: "internaldrive.fill",
                              colors: [Theme.Palette.mint, Theme.Palette.cyan],
                              shape: .roundedRect, size: size)
        }
    }
}
