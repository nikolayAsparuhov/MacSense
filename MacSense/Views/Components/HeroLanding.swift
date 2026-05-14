import SwiftUI

/// CleanMyMac-style center-stage layout used as the landing card for every
/// section: big hero illustration up top, title + tagline + optional small
/// secondary action in the middle, big circular CTA anchored at the bottom.
///
/// Tag lines + buttons all parameterized so each section drops in.
struct HeroLanding<Hero: View>: View {
    let title: String
    let tagline: String
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?
    let ctaTitle: String
    let ctaIcon: String?
    let ctaGradient: LinearGradient
    let ctaGlow: Color
    let ctaDisabled: Bool
    let ctaAction: () -> Void
    /// When true, the CTA disappears and a scanning progress bar takes
    /// its slot. Bar sweeps indeterminately if `progress` is nil.
    var isScanning: Bool = false
    var scanProgress: Double? = nil
    var scanLabel: String = "Scanning…"
    @ViewBuilder let hero: () -> Hero

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            hero()
                .padding(.top, 30)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                Text(tagline)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
                    .shadow(color: .black.opacity(0.30), radius: 4, y: 1)
            }
            .padding(.top, 20)

            if let secondaryActionTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryActionTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Capsule().fill(Color.white.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                        .shadow(color: .black.opacity(0.20), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .noFocusRing()
                .padding(.top, 18)
            }

            Spacer()

            ZStack {
                if isScanning {
                    HeroCompactLoader(
                        label: scanLabel,
                        gradient: ctaGradient,
                        glow: ctaGlow,
                        progress: scanProgress
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    BigCircularCTA(
                        title: ctaTitle,
                        icon: ctaIcon,
                        gradient: ctaGradient,
                        glow: ctaGlow,
                        disabled: ctaDisabled,
                        action: ctaAction
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            // Pin the slot to the CTA's natural size so the loader
            // can't push the layout upward when scanning starts.
            .frame(height: 110)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isScanning)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Compact CTA-replacement loader sized to match `BigCircularCTA`'s
/// 110pt footprint so the hero layout doesn't reflow when a scan
/// starts. Single ring + label below — no large halo.
private struct HeroCompactLoader: View {
    let label: String
    let gradient: LinearGradient
    let glow: Color
    var progress: Double? = nil

    @State private var rotate = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 4)
                    .frame(width: 70, height: 70)

                if let p = progress {
                    Circle()
                        .trim(from: 0.0, to: max(0.02, min(1.0, p)))
                        .stroke(gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.25), value: p)
                } else {
                    Circle()
                        .trim(from: 0.0, to: 0.28)
                        .stroke(gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(rotate ? 360 : 0))
                }
            }
            .shadow(color: glow.opacity(0.55), radius: 14, y: 4)

            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                .lineLimit(1)
        }
        .frame(height: 110)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                rotate = true
            }
        }
    }
}
