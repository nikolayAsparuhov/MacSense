import SwiftUI

/// Big circular gradient action button. CleanMyMac uses one per section,
/// anchored to the bottom-center of the detail pane: "Scan", "Run",
/// "Optimize". White label on accent gradient with a wide soft glow.
struct BigCircularCTA: View {
    let title: String
    let icon: String?
    var gradient: LinearGradient = Theme.brandGradient
    var glow: Color = Theme.Palette.cyan
    var disabled: Bool = false
    var action: () -> Void

    @State private var pressing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Dark backing under the gradient — adds contrast against
                // light backdrops and gives the rim more definition.
                Circle().fill(Color.black.opacity(0.35))

                Circle().fill(gradient)

                // Glossy top highlight — subtle inner sheen.
                Circle()
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.35), .clear],
                        startPoint: .top, endPoint: .center
                    ))
                    .blendMode(.plusLighter)

                // Two-tone rim: bright outer hairline + darker inner stroke
                // for crisp definition against any backdrop.
                Circle().strokeBorder(.white.opacity(0.45), lineWidth: 1.5)
                Circle().inset(by: 2)
                    .strokeBorder(.black.opacity(0.18), lineWidth: 1)

                VStack(spacing: 4) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .bold))
                    }
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
            }
            .frame(width: 110, height: 110)
            .shadow(color: glow.opacity(disabled ? 0.0 : 0.65), radius: 34, x: 0, y: 12)
            .shadow(color: .black.opacity(disabled ? 0.0 : 0.30), radius: 14, x: 0, y: 6)
            .scaleEffect(pressing ? 0.95 : 1.0)
            .opacity(disabled ? 0.6 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressing)
        }
        .buttonStyle(.plain)
        .noFocusRing()
        .disabled(disabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, perform: {}) { isPressing in
            pressing = isPressing
        }
    }
}
