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
                    ScanLoader(
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
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isScanning)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
