import SwiftUI

/// Bottom-of-hero loading state shown in place of `BigCircularCTA`
/// while a scan runs. Three concentric rings sweep at different
/// speeds + a soft pulsing core, all tinted by the section gradient.
/// Reads richer than the prior `ScanProgressBar` and matches the
/// CTA's footprint so the layout doesn't reflow when state flips.
struct ScanLoader: View {
    let label: String
    let gradient: LinearGradient
    let glow: Color
    /// Optional 0...1 progress. When provided, the inner ring fills
    /// proportionally; nil leaves it indeterminate.
    var progress: Double? = nil

    @State private var rotateOuter = false
    @State private var rotateMid = false
    @State private var rotateInner = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Outermost halo
                Circle()
                    .fill(RadialGradient(
                        colors: [glow.opacity(0.45), .clear],
                        center: .center, startRadius: 30, endRadius: 110
                    ))
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulse ? 1.05 : 0.95)
                    .blur(radius: 8)

                // Outer ring — slow CCW
                Circle()
                    .trim(from: 0.0, to: 0.78)
                    .stroke(gradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(rotateOuter ? -360 : 0))
                    .opacity(0.85)

                // Mid ring — fast CW
                Circle()
                    .trim(from: 0.0, to: 0.42)
                    .stroke(gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 118, height: 118)
                    .rotationEffect(.degrees(rotateMid ? 360 : 0))
                    .opacity(0.95)

                // Inner ring — either determinate (progress) or
                // indeterminate sweep.
                if let p = progress {
                    Circle()
                        .trim(from: 0.0, to: max(0.02, min(1.0, p)))
                        .stroke(gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.25), value: p)
                } else {
                    Circle()
                        .trim(from: 0.0, to: 0.25)
                        .stroke(gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(rotateInner ? 360 : 0))
                }

                // Core pulse
                Circle()
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.95), glow.opacity(0.75)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 22, height: 22)
                    .scaleEffect(pulse ? 1.25 : 0.85)
                    .shadow(color: glow.opacity(0.7), radius: 12)
            }
            .frame(width: 220, height: 220)

            HStack(spacing: 8) {
                Circle()
                    .fill(gradient)
                    .frame(width: 8, height: 8)
                    .opacity(pulse ? 1.0 : 0.4)
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                rotateOuter = true
            }
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                rotateMid = true
            }
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                rotateInner = true
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
