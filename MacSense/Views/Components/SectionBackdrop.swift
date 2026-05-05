import SwiftUI

/// Window-spanning radial gradient that tints the whole detail pane in the
/// active section's accent color — the signature CleanMyMac touch where
/// the entire window glows pink for Protection, blue for Smart Care, etc.
///
/// Two stops: bright accent at the upper-right anchor, fading to a deep
/// near-black bottom-left. A faint noise overlay breaks up banding.
struct SectionBackdrop: View {
    let section: AppSection

    var body: some View {
        ZStack {
            // Deep base so the gradient has somewhere dark to fade into.
            Color(red: 0.06, green: 0.05, blue: 0.10)
                .ignoresSafeArea()

            // Primary radial bloom from the upper-right. Toned down vs.
            // the original CMM-mimic so the foreground content (titles,
            // CTA pills, cards) reads with strong contrast against the
            // backdrop instead of competing with it.
            RadialGradient(
                colors: [
                    Theme.accent(for: section).opacity(0.42),
                    Theme.accent(for: section).opacity(0.14),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.78, y: 0.18),
                startRadius: 60,
                endRadius: 900
            )
            .blendMode(.plusLighter)
            .ignoresSafeArea()

            // Secondary cooler bloom on the bottom-left for depth.
            RadialGradient(
                colors: [
                    Theme.accent(for: section).opacity(0.20),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.15, y: 0.85),
                startRadius: 40,
                endRadius: 500
            )
            .blendMode(.plusLighter)
            .ignoresSafeArea()

            // Vertical darkening from top to bottom — boosts readability
            // of titles and tag-lines without flattening the gradient.
            LinearGradient(
                colors: [Color.clear, .black.opacity(0.28)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
