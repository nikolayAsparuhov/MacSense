import SwiftUI

/// Reusable energy-orb visualization in the CleanMyMac home-hero style.
/// Drifting blurred color circles + crisp gradient core + specular
/// highlight + breathing pulse. Sized by `diameter`. When `intensity` rises
/// the orb pulses faster and the colors orbit faster — pass the smart-scan
/// progress to drive it.
struct AnimatedOrb: View {
    /// Total orb diameter in points (the visible core, not the halo).
    var diameter: CGFloat = 168
    /// 0.0 = idle gentle drift, 1.0 = active scan (faster, brighter).
    var intensity: Double = 0.0
    /// Halo extent multiplier — pass < 1 in tight layouts.
    var haloScale: CGFloat = 1.6

    /// Allow callers to override colors per-section if they want; default
    /// is the brand cyan/azure/violet trio.
    var colors: [Color] = [Theme.Palette.cyan, Theme.Palette.azure, Theme.Palette.violet]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulseSpeed = 1.4 + intensity * 1.6
            let pulse = 1.0 + sin(t * pulseSpeed) * (0.025 + intensity * 0.04)
            let driftSpeed = 0.08 + intensity * 0.20
            let drift = t * driftSpeed
            let blob = diameter * 1.07
            let blob2 = diameter * 1.01
            let blob3 = diameter * 0.83
            let blobOffset = diameter * 0.18

            ZStack {
                // Halo
                Circle()
                    .fill(RadialGradient(
                        colors: [colors[0].opacity(0.30 + intensity * 0.20), .clear],
                        center: .center, startRadius: 0,
                        endRadius: diameter * haloScale * 0.5
                    ))
                    .frame(width: diameter * haloScale, height: diameter * haloScale)
                    .blur(radius: 30 + diameter * 0.05)

                // Drifting blurred color blobs
                Circle().fill(colors[0])
                    .frame(width: blob, height: blob)
                    .blur(radius: diameter * 0.22)
                    .offset(x: cos(drift) * blobOffset, y: sin(drift) * blobOffset)
                Circle().fill(colors[safe: 1] ?? colors[0])
                    .frame(width: blob2, height: blob2)
                    .blur(radius: diameter * 0.21)
                    .offset(x: cos(drift + .pi * 0.7) * blobOffset * 0.95,
                            y: sin(drift + .pi * 0.7) * blobOffset * 1.05)
                Circle().fill(colors[safe: 2] ?? colors[0])
                    .frame(width: blob3, height: blob3)
                    .blur(radius: diameter * 0.18)
                    .offset(x: cos(drift + .pi * 1.3) * blobOffset * 0.85,
                            y: sin(drift + .pi * 1.3) * blobOffset * 0.85)

                // Crisp gradient core
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.95),
                                colors[0].opacity(0.75),
                                (colors[safe: 1] ?? colors[0]).opacity(0.55),
                            ],
                            center: UnitPoint(x: 0.4, y: 0.3),
                            startRadius: diameter * 0.04,
                            endRadius: diameter * 0.65
                        )
                    )
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(pulse)
                    .shadow(color: colors[0].opacity(0.55), radius: diameter * 0.18, x: 0, y: 0)

                // Specular highlight
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.8), .clear],
                            center: .center, startRadius: 0,
                            endRadius: diameter * 0.14
                        )
                    )
                    .frame(width: diameter * 0.28, height: diameter * 0.28)
                    .offset(x: -diameter * 0.21, y: -diameter * 0.25)
                    .blendMode(.plusLighter)
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
