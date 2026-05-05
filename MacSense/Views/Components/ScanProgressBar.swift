import SwiftUI

/// Sleek scanning progress bar that replaces the action button while a
/// scan is running. Two modes:
///   - determinate (`progress` non-nil): gradient fill grows from left.
///   - indeterminate (`progress` nil): a gradient pill sweeps across a
///     dim track on a continuous loop. Same shape and width as the
///     CTA pill it replaces, so the hero layout doesn't reflow.
struct ScanProgressBar: View {
    var progress: Double? = nil
    var label: String = "Scanning…"
    var gradient: LinearGradient = Theme.brandGradient
    var glow: Color = Theme.Palette.cyan

    @State private var sweepPhase: CGFloat = 0

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                        .frame(height: 10)

                    if let progress {
                        let clamped = max(0, min(1, progress))
                        Capsule()
                            .fill(gradient)
                            .frame(width: max(10, proxy.size.width * clamped), height: 10)
                            .shadow(color: glow.opacity(0.55), radius: 8, y: 2)
                            .animation(.easeInOut(duration: 0.4), value: progress)
                    } else {
                        let segmentWidth = proxy.size.width * 0.35
                        let travel = proxy.size.width + segmentWidth
                        Capsule()
                            .fill(gradient)
                            .frame(width: segmentWidth, height: 10)
                            .shadow(color: glow.opacity(0.6), radius: 10, y: 2)
                            .offset(x: -segmentWidth + travel * sweepPhase)
                            .onAppear {
                                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                                    sweepPhase = 1.0
                                }
                            }
                    }
                }
            }
            .frame(width: 280, height: 10)

            HStack(spacing: 6) {
                pulsingDot
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
    }

    @State private var dotPulse: Bool = false

    private var pulsingDot: some View {
        Circle()
            .fill(glow)
            .frame(width: 8, height: 8)
            .scaleEffect(dotPulse ? 1.4 : 0.85)
            .opacity(dotPulse ? 0.45 : 1.0)
            .shadow(color: glow.opacity(0.75), radius: 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever()) { dotPulse = true }
            }
    }
}
